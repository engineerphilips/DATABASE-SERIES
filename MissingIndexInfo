WITH MissingIndexInfo AS (
    SELECT 
        database_id,
        database_name = DB_NAME(database_id),
        [schema_name] = OBJECT_SCHEMA_NAME(mid.[object_id], database_id),
        table_name = OBJECT_NAME(mid.[object_id], database_id),
        CONVERT(DECIMAL(28, 1), 
            migs.avg_total_user_cost * 
            migs.avg_user_impact * 
            (migs.user_seeks + migs.user_scans)
        ) AS improvement_measure,
        migs.avg_user_impact,
        migs.avg_total_user_cost,
        migs.user_seeks,
        migs.user_scans,
        migs.last_user_seek,
        migs.last_user_scan,
        migs.unique_compiles,
        estimated_improvement_percent = CONVERT(DECIMAL(5,2), migs.avg_user_impact),
        estimated_space_consumption_kb = 
            CONVERT(DECIMAL(19,2), 
                (migs.user_seeks + migs.user_scans) * 
                CASE 
                    WHEN mid.included_columns IS NOT NULL THEN 2.5 
                    ELSE 1.5 
                END * 
                (LEN(mid.equality_columns) + LEN(mid.inequality_columns))
            ),
        mig.index_group_handle,
        mid.index_handle,
        'CREATE INDEX [IX_' + 
            OBJECT_NAME(mid.[object_id], database_id) + '_' + 
            REPLACE(REPLACE(
                ISNULL(mid.equality_columns, '') + 
                CASE 
                    WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL 
                    THEN '_' 
                    ELSE '' 
                END + 
                ISNULL(mid.inequality_columns, ''),
                ']', ''),
                '[', '') + '_' + 
            CONVERT(VARCHAR(64), NEWID()) + '] ON ' +
            mid.statement + ' (' + 
            ISNULL(mid.equality_columns, '') + 
            CASE 
                WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL 
                THEN ',' 
                ELSE '' 
            END + 
            ISNULL(mid.inequality_columns, '') + ')' + 
            ISNULL(' INCLUDE (' + mid.included_columns + ')', '') + 
            ' WITH (ONLINE = ON, DATA_COMPRESSION = PAGE)' + 
            ' -- Estimated Improvement: ' + 
            CONVERT(VARCHAR(10), CONVERT(DECIMAL(5,2), migs.avg_user_impact)) + '%' AS create_index_statement
    FROM sys.dm_db_missing_index_groups mig
    INNER JOIN sys.dm_db_missing_index_group_stats migs 
        ON migs.group_handle = mig.index_group_handle
    INNER JOIN sys.dm_db_missing_index_details mid 
        ON mig.index_handle = mid.index_handle
)
SELECT 
    CONVERT(VARCHAR(30), GETDATE(), 126) AS analysis_runtime,
    database_name,
    schema_name,
    table_name,
    improvement_measure,
    estimated_improvement_percent,
    estimated_space_consumption_kb,
    user_seeks,
    user_scans,
    avg_total_user_cost,
    CONVERT(VARCHAR(30), last_user_seek, 126) AS last_user_seek,
    CONVERT(VARCHAR(30), last_user_scan, 126) AS last_user_scan,
    unique_compiles,
    create_index_statement
FROM MissingIndexInfo
WHERE improvement_measure > 10
    AND database_id = DB_ID() -- Only current database
ORDER BY 
    improvement_measure DESC,
    estimated_improvement_percent DESC,
    user_seeks + user_scans DESC;
