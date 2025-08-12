SELECT      TOP ( 10 )
            dbname     = DB_NAME( qt.dbid )
          , qt.objectid
          , qs.execution_count
          , query_text = SUBSTRING(
                           qt.text, qs.statement_start_offset / 2 + 1
                         , ( CASE
                               WHEN qs.statement_end_offset = -1 THEN LEN( CONVERT( nvarchar(MAX), qt.text )) * 2
                               ELSE qs.statement_end_offset
                             END - qs.statement_start_offset ) / 2 )
          , avg_worker_time   = qs.total_worker_time /qs.execution_count, qs.total_worker_time, qs.last_worker_time, qs.min_worker_time, qs.max_worker_time -- CPU TIME - in microseconds (but only accurate to milliseconds)
          , avg_elapsed_time   = qs.total_elapsed_time /qs.execution_count, qs.total_elapsed_time, qs.last_elapsed_time, qs.min_elapsed_time, qs.max_elapsed_time -- DURATION - in microseconds (but only accurate to milliseconds)
          , qs.total_grant_kb, qs.last_grant_kb, qs.min_grant_kb, qs.max_grant_kb
          , qs.total_used_grant_kb, qs.last_used_grant_kb, qs.min_used_grant_kb, qs.max_used_grant_kb
FROM        sys.dm_exec_query_stats               AS qs
CROSS APPLY sys.dm_exec_sql_text( qs.sql_handle ) AS qt
ORDER BY    qs.total_grant_kb DESC -- Total GRANT memory