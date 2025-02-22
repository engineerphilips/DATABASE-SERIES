WITH TableAccess AS (
    SELECT 
        owner AS schema_name,
        table_name,
        num_rows,
        t.last_analyzed,
        s.sql_id,
        s.sql_text,
        s.executions,
        s.elapsed_time/NULLIF(s.executions, 0)/1000000 as avg_elapsed_secs,
        s.buffer_gets/NULLIF(s.executions, 0) as avg_buffer_gets,
        ts.ts#,
        ts.operation,
        ts.options,
        ts.object_alias,
        ts.access_predicates,
        ts.filter_predicates,
        CASE 
            WHEN ts.access_predicates IS NULL AND ts.filter_predicates IS NOT NULL 
            THEN 'POTENTIAL MISSING INDEX'
            ELSE 'OK'
        END as index_recommendation
    FROM 
        dba_tables t
        INNER JOIN v$sqlarea s ON UPPER(s.sql_text) LIKE '%' || UPPER(t.table_name) || '%'
        INNER JOIN v$sql_plan ts ON s.sql_id = ts.sql_id
    WHERE 
        ts.operation IN ('TABLE ACCESS', 'INDEX', 'INDEX SCAN')
        AND s.executions > 0
        AND s.parsing_schema_name = t.owner
),
IndexRecommendations AS (
    SELECT 
        schema_name,
        table_name,
        access_predicates,
        filter_predicates,
        sql_id,
        sql_text,
        executions,
        avg_elapsed_secs,
        avg_buffer_gets,
        REGEXP_REPLACE(
            REGEXP_SUBSTR(filter_predicates, '"([^"]+)"', 1, 1), 
            '"', ''
        ) as suggested_column,
        'CREATE INDEX ' || 
        table_name || '_' || 
        REGEXP_REPLACE(
            REGEXP_SUBSTR(filter_predicates, '"([^"]+)"', 1, 1), 
            '"', ''
        ) || '_IDX' ||
        ' ON ' || schema_name || '.' || table_name || 
        '(' || 
        REGEXP_REPLACE(
            REGEXP_SUBSTR(filter_predicates, '"([^"]+)"', 1, 1), 
            '"', ''
        ) || 
        ') COMPUTE STATISTICS' as create_index_statement,
        last_analyzed,
        num_rows
    FROM TableAccess
    WHERE index_recommendation = 'POTENTIAL MISSING INDEX'
        AND filter_predicates IS NOT NULL
),
PerformanceStats AS (
    SELECT 
        schema_name,
        table_name,
        suggested_column,
        COUNT(DISTINCT sql_id) as affected_queries,
        SUM(executions) as total_executions,
        ROUND(AVG(avg_elapsed_secs), 2) as avg_query_time,
        ROUND(AVG(avg_buffer_gets)) as avg_buffer_gets,
        MAX(create_index_statement) as create_index_statement,
        MAX(last_analyzed) as last_analyzed,
        MAX(num_rows) as table_rows
    FROM IndexRecommendations
    GROUP BY 
        schema_name,
        table_name,
        suggested_column
)
SELECT 
    TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') as analysis_time,
    p.*,
    ROUND(
        (avg_buffer_gets * total_executions) / 
        NULLIF(GREATEST(table_rows, 1), 0) * 100, 
        2
    ) as estimated_improvement_pct,
    ROUND(
        (table_rows * 1.5 * 
            (LENGTH(suggested_column) + 1) * 
            (1 + (table_rows/100000))
        ) / 1024, 
        2
    ) as estimated_size_kb
FROM PerformanceStats p
WHERE 
    affected_queries > 1
    AND total_executions > 100
ORDER BY 
    total_executions * avg_buffer_gets DESC,
    affected_queries DESC;
