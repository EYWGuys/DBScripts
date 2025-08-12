---step 3
---create master key on job db
create master key encryption by password ='H@r1b0lo'
---step 4
---create db scopedd credential
create database scoped credential   elasticjobcredential with identity ='elasticjobuser', secrfet='H@r1b0lo'
-----validate
SELECT * FROM sys.database_scoped_credentials
---step -5 
---now create a target group . execute below qieries on job db
exec jobs.sp_add_target_group 'elasticjobtargetgroup'
----------add member sto this target group
SELECT * FROM [jobs].target_groups WHERE target_group_name = N'elasticjobtargetgroup';
----step 6 ---from portal create private end point and get it approved and then continue

----step 7
exec jobs.sp_add_target_group_member 
@target_group_name=N'elasticjobtargetgroup',
@target_type=N'SqlDatabase',
@server_name=N'<target server name>',
@database_name=N'<Tdbname>'
----validate 
SELECT * FROM [jobs].target_group_members WHERE target_group_name = N'elasticjobtargetgroup';
---step 8 --------create job
exec jobs.sp_add_job @job_name='demo', @description ='just for demo'
----step - 9 ---add steps to job
exec jobs.sp_add_jobstep
@job_name=N'Demo',
@command=N'EXEC	 [dbo].[sp_insert_demodata]',
@credential_name=N'elasticjobcredential',
@target_group_name=N'elasticjobtargetgroup'

----validate
SELECT * FROM jobs.jobs WHERE job_name = 'Demo'
-----execute job manually to test
EXEC jobs.sp_start_job 'Demo';

--View top-level execution status for the job named 'Demo'
SELECT * FROM jobs.job_executions
WHERE job_name = 'Demo' and step_id IS NULL
ORDER BY start_time DESC;

--View all top-level execution status for all jobs
SELECT * FROM jobs.job_executions WHERE step_id IS NULL
ORDER BY start_time DESC;

--View all execution statuses for job named 'Demo'
SELECT * FROM jobs.job_executions
WHERE job_name = 'Demo'
ORDER BY start_time DESC;

-- View all active executions to determine job execution id
SELECT * FROM jobs.job_executions
WHERE is_active = 1 AND job_name = 'Demo'
ORDER BY start_time DESC;
GO

-- Cancel job execution with the specified job execution id
EXEC jobs.sp_stop_job '<jobid>';

-- Delete history of a specific job's executions older than the specified date
EXEC jobs.sp_purge_jobhistory @job_name='Demo', @oldest_date='2025-07-13 00:00:00';

--Connect to the job database specified when creating the job agent to make it run every 15 mins
EXEC jobs.sp_update_job
@job_name = 'Demo',
@enabled=1,
@schedule_interval_type = 'Minutes',
@schedule_interval_count = 15;




