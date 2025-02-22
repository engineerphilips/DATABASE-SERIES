# DATABASE-SERIES
This series contains various MSSQL and ORACLE scripts to help DBA's
## 1. SQL Server Missing Indexes Analysis

## Overview
This query identifies and analyzes missing indexes in SQL Server databases by leveraging system Dynamic Management Views (DMVs). It provides actionable recommendations for index creation along with detailed performance impact estimates.

## Features
- Generates ready-to-use CREATE INDEX statements
- Calculates potential performance improvements
- Estimates storage requirements
- Provides detailed usage statistics
- Includes index recommendations with optimal settings

## Technical Details

### Data Sources
The query joins three system DMVs:
- `sys.dm_db_missing_index_groups` (mig): Contains missing index group information
- `sys.dm_db_missing_index_group_stats` (migs): Provides statistics about missing index groups
- `sys.dm_db_missing_index_details` (mid): Contains detailed information about missing indexes

### Key Metrics

1. **Improvement Measure**
   ```sql
   CONVERT(DECIMAL(28, 1), migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans))
   ```
   This composite score indicates the potential performance impact of creating the suggested index.

2. **Space Consumption Estimate**
   ```sql
   (user_seeks + user_scans) * (1.5 or 2.5) * (length_of_columns)
   ```
   Estimates the storage requirements in KB, with additional overhead for included columns.

### Output Columns

- `analysis_runtime`: Timestamp of when the analysis was run
- `database_name`: Name of the database containing the table
- `schema_name`: Schema name of the table
- `table_name`: Name of the table needing the index
- `improvement_measure`: Calculated impact score
- `estimated_improvement_percent`: Projected performance improvement
- `estimated_space_consumption_kb`: Estimated storage requirement
- `user_seeks`, `user_scans`: Number of seeks and scans that could have used the index
- `avg_total_user_cost`: Average cost of the operations that could benefit
- `last_user_seek`, `last_user_scan`: Most recent seek/scan timestamps
- `unique_compiles`: Number of unique compilations
- `create_index_statement`: Complete T-SQL statement to create the recommended index

### Filtering Criteria

- Only shows recommendations with `improvement_measure > 10`
- Limited to the current database context
- Sorted by potential impact (improvement_measure, estimated_improvement_percent, usage)

## Usage

### Prerequisites
- Requires appropriate permissions to query system DMVs
- Should be run in the context of the database you want to analyze

### Example Usage
```sql
USE YourDatabaseName;
GO
-- Run the query here
```

### Index Creation Recommendations
The generated CREATE INDEX statements include:
- Meaningful index names based on table and columns
- Online index creation option for minimal downtime
- Page-level compression for storage efficiency
- Performance impact estimates in comments

## Best Practices

1. Review recommendations carefully before implementation
2. Consider maintenance overhead of new indexes
3. Test index creation in non-production environment first
4. Monitor space requirements and performance impact
5. Schedule index creation during low-usage periods

## Notes
- The improvement estimates are based on SQL Server's internal algorithms
- Actual performance improvements may vary
- Regular monitoring and adjustment of indexes is recommended


## 2. Oracle Missing Index Analysis Query

## Overview
This query helps identify potentially missing indexes in Oracle databases by analyzing query execution patterns, table access methods, and performance metrics. Unlike SQL Server's built-in missing index recommendations, this query uses Oracle's execution statistics and plan operations to determine where indexes might be beneficial.

## Components

### 1. TableAccess CTE
```sql
WITH TableAccess AS (
    SELECT 
        owner AS schema_name,
        table_name,
        num_rows,
        t.last_analyzed,
        -- ... other columns
```
This CTE joins system tables and views to gather information about:
- Table metadata from `dba_tables`
- SQL execution statistics from `v$sqlarea`
- Execution plans from `v$sql_plan`
- Identifies potential missing indexes by analyzing access and filter predicates

### 2. IndexRecommendations CTE
```sql
IndexRecommendations AS (
    SELECT 
        schema_name,
        table_name,
        access_predicates,
        -- ... other columns
```
This CTE:
- Generates CREATE INDEX statements
- Extracts column names from filter predicates
- Associates SQL performance metrics with each recommendation
- Formats index names and definitions according to Oracle best practices

### 3. PerformanceStats CTE
```sql
PerformanceStats AS (
    SELECT 
        schema_name,
        table_name,
        suggested_column,
        -- ... other columns
```
This CTE aggregates performance metrics:
- Count of affected queries
- Total executions
- Average query time
- Buffer get statistics
- Table statistics

## Key Metrics Explained

1. **Affected Queries**
   - Number of distinct SQL statements that could benefit from the index
   - Higher numbers indicate widely beneficial indexes

2. **Buffer Gets**
   - Number of buffer gets per execution
   - High values suggest excessive block reads

3. **Estimated Improvement Percentage**
```sql
ROUND((avg_buffer_gets * total_executions) / NULLIF(GREATEST(table_rows, 1), 0) * 100, 2)
```
   - Calculates potential performance improvement
   - Based on ratio of buffer gets to table rows

4. **Estimated Size KB**
```sql
ROUND((table_rows * 1.5 * (LENGTH(suggested_column) + 1) * (1 + (table_rows/100000))) / 1024, 2)
```
   - Estimates index size based on:
     - Table row count
     - Column length
     - Overhead factor
     - Scale factor for larger tables

## Prerequisites

1. Required Privileges:
   - SELECT on DBA_TABLES
   - SELECT on V$SQLAREA
   - SELECT on V$SQL_PLAN
   - Typically requires DBA role or specific grants

2. System Requirements:
   - Oracle 11g or later
   - Gathering of execution statistics enabled
   - Recent table statistics

## Usage

1. Execute in your target database:
```sql
-- Run as DBA or user with appropriate privileges
@missing_indexes.sql
```

2. Review Results:
   - Focus on recommendations with:
     - High execution counts
     - High buffer gets
     - Multiple affected queries
   - Consider space requirements
   - Validate improvement estimates

## Output Columns

| Column | Description |
|--------|-------------|
| analysis_time | Timestamp of analysis run |
| schema_name | Schema containing the table |
| table_name | Table needing index |
| suggested_column | Column(s) recommended for indexing |
| affected_queries | Count of SQL statements affected |
| total_executions | Sum of executions for affected queries |
| avg_query_time | Average execution time in seconds |
| create_index_statement | Generated CREATE INDEX statement |
| estimated_improvement_pct | Calculated potential improvement |
| estimated_size_kb | Estimated index size |

## Best Practices

1. **Validation**
   - Test recommendations in development environment first
   - Monitor actual performance improvement
   - Consider impact on DML operations

2. **Implementation**
   - Create indexes during low-activity periods
   - Monitor tablespace space usage
   - Update statistics after index creation

3. **Maintenance**
   - Regularly monitor index usage
   - Drop unused indexes
   - Keep statistics up to date

## Limitations

1. The query:
   - Only analyzes SQL in the shared pool
   - Requires recent execution statistics
   - May not catch all access patterns

2. Recommendations:
   - Based on current workload
   - May not account for future query patterns
   - Don't consider existing indexes' impact
