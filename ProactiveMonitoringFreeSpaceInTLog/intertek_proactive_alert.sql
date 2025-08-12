set nocount on 
IF OBJECT_ID('tempdb..#tempx') IS NOT NULL DROP TABLE #tempx
 create table #tempx (
 databaseName varchar(255) not null, 
 logsizemb decimal (15,4), 
 logspaceused_percentage decimal (15,4),
 status int)
 insert into #tempx (databaseName,logsizemb,logspaceused_percentage,status) 
  exec ('dbcc sqlperf(logspace);');
  declare @count int
 select @count= count(1) from #tempx where logspaceused_percentage >75
 if @count >0 
 begin 
 EXEC sp_addmessage @msgnum = 99075,
    @severity = 10,
    @msgtext = N'Custom Event: 99075. TLOG space usage is high. Please take action as soon as possible'

RAISERROR (99075, -- Message ID.
    10, -- Severity,
    1, -- State,
    N'abcde') with log ; -- First argument supplies the string.
-- The message text returned is: <<    abc>>.

EXEC sp_dropmessage @msgnum = 99075;

declare @query as varchar(8000)
SET @query=' select databaseName, logspaceused_percentage from #tempx where logspaceused_percentage >75    ';
EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'abc'
    , @recipients = 'recipients@company.com'
    , @subject = 'High Tlog space usage'
    , @body= 'For more details please look into attached file.'
    , @body_format = 'TEXT'
    , @query = @query
    , @execute_query_database = 'tempdb'  
    , @attach_query_result_as_file = 1
    , @query_attachment_filename='warning.csv'
    , @query_result_header = 1
    , @query_result_width = 80
    , @query_result_separator = ' '
    , @exclude_query_output = 0
    , @append_query_error = 1
    , @query_no_truncate = 0
    , @query_result_no_padding = 0;
 end
