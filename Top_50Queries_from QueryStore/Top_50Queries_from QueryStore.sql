DECLARE @interval_end_time DATETIME2 = (SELECT GETDATE())
DECLARE @interval_start_time DATETIME2 = (SELECT DATEADD(HOUR, -48, GETDATE()))    
DECLARE @results_row_count INT = 50



;With wait_stats AS
(
SELECT
    ws.plan_id plan_id,
    ws.wait_category,
    ROUND(CONVERT(float, SUM(ws.total_query_wait_time_ms)/SUM(ws.total_query_wait_time_ms/ws.avg_query_wait_time_ms))*1,2) avg_query_wait_time,
    ROUND(CONVERT(float, SQRT( SUM(ws.stdev_query_wait_time_ms*ws.stdev_query_wait_time_ms*(ws.total_query_wait_time_ms/ws.avg_query_wait_time_ms))/SUM(ws.total_query_wait_time_ms/ws.avg_query_wait_time_ms)))*1,2) stdev_query_wait_time,
    CAST(ROUND(SUM(ws.total_query_wait_time_ms/ws.avg_query_wait_time_ms),0) AS BIGINT) count_executions,
    MAX(itvl.end_time) last_execution_time,
    MIN(itvl.start_time) first_execution_time
FROM sys.query_store_wait_stats ws
    JOIN sys.query_store_runtime_stats_interval itvl ON itvl.runtime_stats_interval_id = ws.runtime_stats_interval_id
WHERE NOT (itvl.start_time > @interval_end_time OR itvl.end_time < @interval_start_time)
GROUP BY ws.plan_id, ws.runtime_stats_interval_id, ws.wait_category
),
top_wait_stats AS
(
SELECT 
    p.query_id query_id,
    q.object_id object_id,
    ISNULL(OBJECT_NAME(q.object_id),'''') object_name,
    qt.query_sql_text query_sql_text,
    ROUND(CONVERT(float, SUM(ws.avg_query_wait_time*ws.count_executions))*1,2) total_query_wait_time,
	 ROUND(CONVERT(float, SUM(ws.avg_query_wait_time*ws.count_executions/ws.count_executions))*1,2) avg_query_wait_time,
    MAX(ws.count_executions) count_executions,
    COUNT(distinct p.plan_id) num_plans
FROM wait_stats ws
    JOIN sys.query_store_plan p ON p.plan_id = ws.plan_id
    JOIN sys.query_store_query q ON q.query_id = p.query_id
    JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
WHERE NOT (ws.first_execution_time > @interval_end_time OR ws.last_execution_time < @interval_start_time)
GROUP BY p.query_id, qt.query_sql_text, q.object_id
),
top_other_stats AS
(
SELECT 
    p.query_id query_id,
    q.object_id object_id,
    ISNULL(OBJECT_NAME(q.object_id),'''') object_name,
    qt.query_sql_text query_sql_text,
	MIN(rs.first_execution_time) AS [First_Execution_Time],
	MAX(rs.last_execution_time) AS [Last_Execution_Time],
	ROUND(CONVERT(float,MAX(rs.max_duration))*0.001,2) AS [max_duration],
	ROUND(CONVERT(float,MAX(rs.max_cpu_time))*0.001,2) AS [max_cpu_duration],
	ROUND(CONVERT(float,avg(rs.avg_duration))*0.001,2) AS [avg_duration],
    ROUND(CONVERT(float, SUM(rs.avg_duration*rs.count_executions))*0.001,2) total_duration,
    ROUND(CONVERT(float, SUM(rs.avg_cpu_time*rs.count_executions))*0.001,2) total_cpu_time,
    ROUND(CONVERT(float, SUM(rs.avg_logical_io_reads*rs.count_executions))*8,2) total_logical_io_reads,
    ROUND(CONVERT(float, SUM(rs.avg_logical_io_writes*rs.count_executions))*8,2) total_logical_io_writes,
    ROUND(CONVERT(float, SUM(rs.avg_physical_io_reads*rs.count_executions))*8,2) total_physical_io_reads,
    ROUND(CONVERT(float, SUM(rs.avg_clr_time*rs.count_executions))*0.001,2) total_clr_time,
    ROUND(CONVERT(float, SUM(rs.avg_dop*rs.count_executions))*1,0) total_dop,
    ROUND(CONVERT(float, SUM(rs.avg_query_max_used_memory*rs.count_executions))*8,2) total_query_max_used_memory,
    ROUND(CONVERT(float, SUM(rs.avg_rowcount*rs.count_executions))*1,0) total_rowcount,
    ROUND(CONVERT(float, SUM(rs.avg_log_bytes_used*rs.count_executions))*0.0009765625,2) total_log_bytes_used,
    ROUND(CONVERT(float, SUM(rs.avg_tempdb_space_used*rs.count_executions))*8,2) total_tempdb_space_used,
    SUM(rs.count_executions) count_executions,
    COUNT(distinct p.plan_id) num_plans,
	rs.execution_type_desc,
	p.query_plan,
	p.plan_id
FROM sys.query_store_runtime_stats rs
    JOIN sys.query_store_plan p ON p.plan_id = rs.plan_id
    JOIN sys.query_store_query q ON q.query_id = p.query_id
    JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
WHERE NOT (rs.first_execution_time > @interval_end_time OR rs.last_execution_time < @interval_start_time)
GROUP BY p.query_id, qt.query_sql_text, q.object_id, rs.execution_type_desc, p.plan_id, p.query_plan
)
SELECT TOP (@results_row_count)
    A.query_id query_id,
    --A.object_id object_id,
    A.object_name object_name,
    A.query_sql_text query_sql_text,
	a.first_execution_time,
	a.last_execution_time,
	case
		  WHEN (A.max_duration ) < 1000 THEN
               CONVERT(VARCHAR, CAST(ROUND((A.max_duration ),2) AS NUMERIC (36,2))) + ' ms'

           WHEN (A.max_duration / 1000. ) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.max_duration / 1000.),2) AS NUMERIC (36,2))
                      ) + ' secs'
           WHEN (A.max_duration / 60000.) > 1
                AND ((A.max_duration / 60000)) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.max_duration / 60000.),2) AS NUMERIC (36,2))
                      ) + ' min'
           WHEN (A.max_duration /3600000.)  > 1 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.max_duration / 3600000.),2) AS NUMERIC (36,2))
                      ) + ' hours'
       END AS [max_duration_calculated],
	   	case
		  WHEN (A.max_cpu_duration ) < 1000 THEN
               CONVERT(VARCHAR, CAST(ROUND((A.max_cpu_duration ),2) AS NUMERIC (36,2))) + ' ms'

           WHEN (A.max_cpu_duration / 1000. ) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.max_cpu_duration / 1000000.),2) AS NUMERIC (36,2))
                      ) + ' secs'
           WHEN (A.max_cpu_duration / 60000.) > 1
                AND ((A.max_cpu_duration / 60000)) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.max_cpu_duration / 60000.),2) AS NUMERIC (36,2))
                      ) + ' min'
           WHEN (A.max_cpu_duration /3600000.)  > 1 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.max_cpu_duration / 3600000.),2) AS NUMERIC (36,2))
                      ) + ' hours'
       END AS [max_cpu_duration_calculated],
	   A.max_duration,
	   	case
		  WHEN (A.avg_duration ) < 1000 THEN
               CONVERT(VARCHAR, CAST(ROUND((A.avg_duration ),2) AS NUMERIC (36,2))) + ' ms'

           WHEN (A.avg_duration / 1000. ) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.avg_duration / 1000000.),2) AS NUMERIC (36,2))
                      ) + ' secs'
           WHEN (A.avg_duration / 60000.) > 1
                AND ((A.avg_duration / 60000)) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.avg_duration / 60000.),2) AS NUMERIC (36,2))
                      ) + ' min'
           WHEN (A.avg_duration /3600000.)  > 1 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.avg_duration / 3600000.),2) AS NUMERIC (36,2))
                      ) + ' hours'
       END AS [avg_duration_calculated],
	case
		  WHEN (A.total_duration ) < 1000 THEN
               CONVERT(VARCHAR, CAST(ROUND((A.total_duration ),2) AS NUMERIC (36,2))) + ' ms'

           WHEN (A.total_duration / 1000. ) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.total_duration / 1000000.),2) AS NUMERIC (36,2))
                      ) + ' secs'
           WHEN (A.total_duration / 60000.) > 1
                AND ((A.total_duration / 60000)) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.total_duration / 60000.),2) AS NUMERIC (36,2))
                      ) + ' min'
           WHEN (A.total_duration /3600000.)  > 1 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.total_duration / 3600000.),2) AS NUMERIC (36,2))
                      ) + ' hours'
       END AS [total_duration_calculated],
	case
		  WHEN (A.total_cpu_time ) < 1000 THEN
               CONVERT(VARCHAR, CAST(ROUND((A.total_cpu_time ),2) AS NUMERIC (36,2))) + ' ms'

           WHEN (A.total_cpu_time / 1000. ) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.total_cpu_time / 1000000.),2) AS NUMERIC (36,2))
                      ) + ' secs'
           WHEN (A.total_cpu_time / 60000.) > 1
                AND ((A.total_cpu_time / 60000)) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.total_cpu_time / 60000.),2) AS NUMERIC (36,2))
                      ) + ' min'
           WHEN (A.total_cpu_time /3600000.)  > 1 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((A.total_cpu_time / 3600000.),2) AS NUMERIC (36,2))
                      ) + ' hours'
       END AS [total_cpu_time_calculated],
	 
    A.total_logical_io_reads total_logical_io_reads,
    A.total_logical_io_writes total_logical_io_writes,
    A.total_physical_io_reads total_physical_io_reads,
    A.total_clr_time total_clr_time,
    A.total_dop total_dop,
    A.total_query_max_used_memory total_query_max_used_memory,
    A.total_rowcount total_rowcount,
    A.total_log_bytes_used total_log_bytes_used,
    A.total_tempdb_space_used total_tempdb_space_used,
    ISNULL(B.total_query_wait_time,0) total_query_wait_time,
	case
		  WHEN (b.total_query_wait_time ) < 1000 THEN
               CONVERT(VARCHAR, CAST(ROUND((b.total_query_wait_time ),2) AS NUMERIC (36,2))) + ' ms'

           WHEN (b.total_query_wait_time / 1000. ) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((b.total_query_wait_time / 1000000.),2) AS NUMERIC (36,2))
                      ) + ' secs'
           WHEN (b.total_query_wait_time / 60000.) > 1
                AND ((b.total_query_wait_time / 60000)) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((b.total_query_wait_time / 60000.),2) AS NUMERIC (36,2))
                      ) + ' min'
           WHEN (b.total_query_wait_time /3600000.)  > 1 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((b.total_query_wait_time / 3600000.),2) AS NUMERIC (36,2))
                      ) + ' hours'
       END AS [total_wait_time_calculated],
	   case
		  WHEN (b.avg_query_wait_time ) < 1000 THEN
               CONVERT(VARCHAR, CAST(ROUND((b.avg_query_wait_time ),2) AS NUMERIC (36,2))) + ' ms'

           WHEN (b.avg_query_wait_time / 1000. ) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((b.avg_query_wait_time / 1000000.),2) AS NUMERIC (36,2))
                      ) + ' secs'
           WHEN (b.avg_query_wait_time / 60000.) > 1
                AND ((b.avg_query_wait_time / 60000)) < 60 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((b.avg_query_wait_time / 60000.),2) AS NUMERIC (36,2))
                      ) + ' min'
           WHEN (b.avg_query_wait_time /3600000.)  > 1 THEN
               CONVERT(
                          VARCHAR,
                          CAST(ROUND((b.avg_query_wait_time / 3600000.),2) AS NUMERIC (36,2))
                      ) + ' hours'
       END AS [avg_wait_time_calculated],
    A.count_executions count_executions,
    A.num_plans num_plans,
	A.execution_type_desc,
	A.plan_id,
	TRY_CONVERT(XML, A.query_plan) AS [plan]
FROM top_other_stats A LEFT JOIN top_wait_stats B on A.query_id = B.query_id and A.query_sql_text = B.query_sql_text and A.object_id = B.object_id
WHERE A.num_plans >= 1
AND A.object_name = 'QS_Test'
--AND A.query_sql_text LIKE '%SELECT        EodDate, InternalPortfolioName%'
ORDER BY total_duration DESC
