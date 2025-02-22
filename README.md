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
