---The following query returns the tempdb space used by user objects, internal objects and version stores:
Select
SUM (user_object_reserved_page_count)*8/1024 as user_objects_Mb,
SUM (internal_object_reserved_page_count)*8/1024 as internal_objects_Mb,
SUM (version_store_reserved_page_count)*8/1024 as version_store_Mb,
SUM (unallocated_extent_page_count)*8/1024 as freespace_Mb
From sys.dm_db_file_space_usage
Where database_id = 2
----The following query returns the five transactions that have been running the longest and that depend on the versions in the version store.
SELECT top 5 transaction_id, transaction_sequence_num,
elapsed_time_seconds
FROM sys.dm_tran_active_snapshot_database_transactions
ORDER BY elapsed_time_seconds DESC
--------- Below query would show current size of TempDB files -----------
SELECT  name         ,size*8.0/1024 'Current Size in MB' FROM    tempdb.sys.database_files 
--------- Below query would show Iniial size of TempDB files -----------
SELECT  name         ,size*8.0/1024  'Initial Size in MB' FROM master.sys.sysaltfiles WHERE dbid = 2  
---OBJECTS IN TEMPDB
select * from tempdb.sys.objects where type_desc not like 'system%' and type_desc not like 'internal%'
--SPACE USAGE IN TEMPDB
SELECT * FROM sys.dm_db_file_space_usage;
---SESSIONWISE PAGE ALLOCATED AND DEALLOCATED
SELECT
	SessionId						= SessionSpaceUsage.session_id ,
	UserObjectsAllocPageCount		= SessionSpaceUsage.user_objects_alloc_page_count + SUM (TaskSpaceUsage.user_objects_alloc_page_count) ,
	UserObjectsDeallocPageCount		= SessionSpaceUsage.user_objects_dealloc_page_count + SUM (TaskSpaceUsage.user_objects_dealloc_page_count) ,
	InternalObjectsAllocPageCount	= SessionSpaceUsage.internal_objects_alloc_page_count + SUM (TaskSpaceUsage.internal_objects_alloc_page_count) ,
	InternalObjectsDeallocPageCount	= SessionSpaceUsage.internal_objects_dealloc_page_count + SUM (TaskSpaceUsage.internal_objects_dealloc_page_count)
FROM
	sys.dm_db_session_space_usage AS SessionSpaceUsage
INNER JOIN
	sys.dm_db_task_space_usage AS TaskSpaceUsage
ON
	SessionSpaceUsage.session_id = TaskSpaceUsage.session_id
GROUP BY
	SessionSpaceUsage.session_id ,
	SessionSpaceUsage.user_objects_alloc_page_count ,
	SessionSpaceUsage.user_objects_dealloc_page_count ,
	SessionSpaceUsage.internal_objects_alloc_page_count ,
	SessionSpaceUsage.internal_objects_dealloc_page_count
ORDER BY
	SessionId ASC; 
---If there is a currently running large query that consumes a lot of space in tempdb due to internal objects
SELECT
	SessionId						= TasksSpaceUsage.SessionId ,
	RequestId						= TasksSpaceUsage.RequestId ,
	InternalObjectsAllocPageCount	= TasksSpaceUsage.InternalObjectsAllocPageCount ,
	InternalObjectsDeallocPageCount	= TasksSpaceUsage.InternalObjectsDeallocPageCount ,
	RequestText						= RequestsText.text ,
	RequestPlan						= RequestsPlan.query_plan
FROM
	(
		SELECT
			SessionId						= session_id ,
			RequestId						= request_id ,
			InternalObjectsAllocPageCount	= SUM (internal_objects_alloc_page_count) ,
			InternalObjectsDeallocPageCount	= SUM (internal_objects_dealloc_page_count)
		FROM
			sys.dm_db_task_space_usage
		GROUP BY
			session_id ,
			request_id
	)
	AS
		TasksSpaceUsage
INNER JOIN
	sys.dm_exec_requests AS Requests
ON
	TasksSpaceUsage.SessionId = Requests.session_id
AND
	TasksSpaceUsage.RequestId = Requests.request_id
OUTER APPLY
	sys.dm_exec_sql_text (Requests.sql_handle) AS RequestsText
OUTER APPLY
	sys.dm_exec_query_plan (Requests.plan_handle) AS RequestsPlan
ORDER BY
	SessionId	ASC ,
	RequestId	ASC;
	-----VERSION STORE USAGE
	SELECT * FROM sys.dm_tran_version_store


	--Identify sessions causing version store retention
	DECLARE @version_store_size_total_threshold BIGINT = 25 * POWER(2.0, 30); --GB
DECLARE @version_store_size_per_db_threshold BIGINT = 10 * POWER(2.0, 30); --GB

-------------------------------------------------------------

DECLARE @version_store_reserved_size_exceeded BIT = 0;

DECLARE @total_version_store_size BIGINT = 0;
DECLARE @largest_db_version_store_size BIGINT = 0;

-------------------------------------------------------------
--Check if the version store reserved size exceeds our threshold
--If it does not, the in-use size cannot possibly exceed them, so bail early

IF OBJECT_ID('sys.dm_tran_version_store_space_usage') IS NOT NULL
BEGIN;
    --Utilize the summary DMV introduced in SQL2017 / SQL2016SP2 / SQL2014SP3
    SELECT
        @total_version_store_size = SUM(reserved_space_kb) * 1024
        , @largest_db_version_store_size = MAX(reserved_space_kb) * 1024
    FROM sys.dm_tran_version_store_space_usage
    ;

    IF @total_version_store_size > @version_store_size_total_threshold
            OR @largest_db_version_store_size > @version_store_size_per_db_threshold
        SET @version_store_reserved_size_exceeded = 1;
END;
ELSE
BEGIN;
    --If the DMV is not available, use the system-wide perfmon counter.
    SET @total_version_store_size = (
        SELECT pc.cntr_value * 1024
        FROM sys.dm_os_performance_counters pc
        WHERE pc.counter_name = 'Version Store Size (KB)'
    );

    --The perfmon counter does not allow per-db reserved size identification
    --So we pessimistically assume one DB is responsible for all of it
    --The detailed analysis later in the script will still filter appropriately
    IF @total_version_store_size > @version_store_size_total_threshold
            OR @total_version_store_size > @version_store_size_per_db_threshold
        SET @version_store_reserved_size_exceeded = 1;
END;

-------------------------------------------------------------

IF (@version_store_reserved_size_exceeded = 1)
BEGIN;
    CREATE TABLE #version_store_tail_size (
        database_id SMALLINT
        , transaction_sequence_num BIGINT
        , sequence_num_discrete_size_bytes BIGINT
        , sequence_num_tail_size_bytes BIGINT INDEX ix_version_store_tail_size_tail NONCLUSTERED
        , recoverable_space_global BIGINT
        , recoverable_space_per_db BIGINT
        , CONSTRAINT PK_version_store_tail_size PRIMARY KEY CLUSTERED (database_id, transaction_sequence_num)
    );

    CREATE TABLE #database_sequence_num_watermark (
        database_id SMALLINT INDEX ix_database_sequence_num_watermark_id CLUSTERED
        , transaction_sequence_num BIGINT INDEX ix_database_sequence_num_watermark_tsn NONCLUSTERED
    );

    /*
     * Examining the detailed values in the version store can take a significant amount of time
     * The processing speed is in the neighborhood of 5-15 GB/min 
     */

	;WITH version_store_sequence_sums AS (
		SELECT
			  tvs.database_id
			, tvs.transaction_sequence_num
			, SUM(CONVERT(BIGINT, tvs.record_length_first_part_in_bytes + tvs.record_length_second_part_in_bytes)) AS [sequence_size_bytes]
		FROM sys.dm_tran_version_store tvs
		GROUP BY tvs.database_id, tvs.transaction_sequence_num
	), version_store_tail_size AS (
		SELECT
			  vsss.database_id
			, vsss.transaction_sequence_num
            , vsss.sequence_size_bytes
			, SUM(vsss.sequence_size_bytes) OVER (PARTITION BY vsss.database_id ORDER BY vsss.transaction_sequence_num DESC RANGE UNBOUNDED PRECEDING) AS [tail_size_bytes]
		FROM version_store_sequence_sums vsss
	), version_store_recoverable_space AS (
        SELECT
            vsts.database_id
            , vsts.transaction_sequence_num
            , vsts.sequence_size_bytes
            , vsts.tail_size_bytes
            , SUM(vsts.sequence_size_bytes) OVER (ORDER BY vsts.tail_size_bytes DESC RANGE UNBOUNDED PRECEDING) recoverable_space_global
            , SUM(vsts.sequence_size_bytes) OVER (PARTITION BY vsts.database_id ORDER BY vsts.tail_size_bytes DESC RANGE UNBOUNDED PRECEDING) recoverable_space_per_db
        FROM version_store_tail_size vsts
    )

	INSERT #version_store_tail_size (database_id, transaction_sequence_num, sequence_num_discrete_size_bytes, sequence_num_tail_size_bytes, recoverable_space_global, recoverable_space_per_db)
	SELECT vsrs.database_id, vsrs.transaction_sequence_num, vsrs.sequence_size_bytes, vsrs.tail_size_bytes, vsrs.recoverable_space_global, vsrs.recoverable_space_per_db
	FROM version_store_recoverable_space vsrs
    ;

    INSERT #database_sequence_num_watermark (database_id, transaction_sequence_num)
    SELECT
        vsts.database_id
        , MAX(vsts.transaction_sequence_num)
    FROM #version_store_tail_size vsts
    WHERE
        vsts.recoverable_space_global > @version_store_size_total_threshold
        OR vsts.recoverable_space_per_db > @version_store_size_per_db_threshold
    GROUP BY vsts.database_id
    ;

    --Final output
    SELECT
          SYSDATETIME() AS [runtime]
        , s.[last_request_start_time] AS [last_batch]
        , s.[host_name]
        , s.[login_name]
        , s.[program_name]
        , tasdt.session_id
        , tasdt.transaction_sequence_num
        , tdt.database_id
        --, vsts.recoverable_space_global AS [version_store_recoverable_space_bytes]
        , CONVERT(NUMERIC(8,3), vsts.recoverable_space_global / (POWER(2.0, 30))) AS [version_store_recoverable_space_gb]
        , CASE ROW_NUMBER() OVER (PARTITION BY tasdt.session_id ORDER BY tdt.database_id)
            WHEN 1 THEN N'KILL ' + CONVERT(NVARCHAR(20), tasdt.session_id) + N';'
            ELSE ''
        END AS [kill_command]
    FROM [sys].[dm_tran_active_snapshot_database_transactions] [tasdt]
        INNER JOIN sys.dm_tran_database_transactions tdt
            ON tdt.transaction_id = tasdt.transaction_id
        INNER JOIN #database_sequence_num_watermark dsnw
            ON dsnw.database_id = tdt.database_id
            AND (
                dsnw.transaction_sequence_num >= tasdt.first_snapshot_sequence_num
                OR dsnw.transaction_sequence_num >= tasdt.transaction_sequence_num
            )
        INNER JOIN #version_store_tail_size vsts
            ON vsts.database_id = dsnw.database_id
            AND vsts.transaction_sequence_num = dsnw.transaction_sequence_num
        INNER JOIN sys.dm_exec_sessions s
            ON s.session_id = tasdt.session_id
    ;

    DROP TABLE #database_sequence_num_watermark;
    DROP TABLE #version_store_tail_size;

END;
