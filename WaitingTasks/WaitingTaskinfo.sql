select isnull(cast(x.blocking_session_id as char(6))+' blocked '+cast(x.session_id as char(6)),' Blocker ') blockingchain_id,* from (
select 
w.[waiting_task_address]
      ,w.[session_id]
	  ,w.[blocking_session_id]
	  ,(select event_info from sys.dm_exec_input_buffer(w.session_id, NULL)) sqltext
      ,isnull((select event_info from sys.dm_exec_input_buffer(w.blocking_session_id, NULL)),'') blockingsqltext
      ,w.[exec_context_id]
      ,w.[wait_duration_ms]
      ,w.[wait_type]
      ,w.[resource_address]
      ,w.[blocking_task_address]
      ,w.[blocking_exec_context_id]
      ,w.[resource_description]
	  FROM 
  sys.dm_os_waiting_tasks as w 
WHERE blocking_session_id IS NOT NULL 
union
select 
	   w.[waiting_task_address]
      ,w.[session_id]
	  ,w.[blocking_session_id]
	  ,(select event_info from sys.dm_exec_input_buffer(w.session_id, NULL)) sqltext
      ,isnull((select event_info from sys.dm_exec_input_buffer(w.blocking_session_id, NULL)),'') blockingsqltext
      ,w.[exec_context_id]
      ,w.[wait_duration_ms]
      ,w.[wait_type]
      ,w.[resource_address]
      ,w.[blocking_task_address]
      ,w.[blocking_exec_context_id]
      ,w.[resource_description]
  FROM 
  sys.dm_os_waiting_tasks as w 
WHERE blocking_session_id IS NULL and SESSION_ID in  (select  blocking_session_id  FROM sys.dm_os_waiting_tasks where blocking_session_id  is not null )
) as x  where SESSION_ID is not null and session_id >50 
order by 1
