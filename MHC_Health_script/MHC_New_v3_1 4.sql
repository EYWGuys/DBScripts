


--ver 8 added
use master
go 
begin

IF object_id('tempdb..#tmp') is not null
    drop table #tmp
IF object_id('tempdb..#sqlaudit') is not null
    drop table #sqlaudit
IF object_id('tempdb..#TUser') is not null
    drop table #TUser
IF object_id('tempdb..#TSym') is not null
    drop table #TSym
IF object_id('tempdb..#TASym') is not null
    drop table #TASym
IF object_id('tempdb..#Tsafeasm') is not null
    drop table #Tsafeasm

IF OBJECT_ID('tempdb..#GuestUsersReport') IS NOT NULL
    DROP TABLE #GuestUsersReport
IF OBJECT_ID('tempdb..#orphanusers') IS NOT NULL
    DROP TABLE #orphanusers

IF OBJECT_ID('tempdb..#tusercdb  ') IS NOT NULL
   drop table #tusercdb  

create table #tusercdb  (dbname sysname, dbuser sysname)
insert into #tusercdb (dbname, dbuser )
exec sp_MSforeachdb 
'
use [?] ; 
if exists(select name from sys.databases where containment=0) 
begin 
SELECT db_name() dbname,name AS DBUser
FROM sys.database_principals
WHERE name NOT IN (''dbo'',''Information_Schema'',''sys'',''guest'')
AND type IN (''U'',''S'',''G'')
AND authentication_type = 2;
end;'


create table #orphanusers (
DBNM sysname,
name sysname,
id int
)

insert into #orphanusers (DBNM,name,id)
exec sp_MSforeachdb  '
use [?] ; 
select db_name() DBNM, p.name,p.sid
from sys.database_principals p
where p.type in (''G'',''S'',''U'')
and p.sid not in (select sid from sys.server_principals)
and p.name not in (
    ''dbo'',
    ''guest'',
    ''INFORMATION_SCHEMA'',
    ''sys'',
    ''MS_DataCollectorInternalUser'' ) ;'



DECLARE @test varchar(20), @key varchar(100)
declare @sqlportnumber as varchar(10)
declare @offportnumber as varchar(10)

SELECT @offportnumber=cast(value_data as varchar)
FROM sys.dm_server_registry
WHERE value_name like '%Tcp%' and value_data='1433'

if charindex('\',@@servername,0) <>0
begin
SET @key = 'SOFTWARE\MICROSOFT\Microsoft SQL Server\'+@@servicename+'\MSSQLServer\Supersocketnetlib\TCP'
end
else
begin
SET @key = 'SOFTWARE\MICROSOFT\MSSQLServer\MSSQLServer\Supersocketnetlib\TCP'
end
EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',@key=@key,@value_name='Tcpport',@value=@test OUTPUT
SELECT @sqlportnumber =convert(varchar(10),@test)

declare @instancehidden int
DECLARE @getValue INT;
EXEC master.sys.xp_instance_regread
 @rootkey = N'HKEY_LOCAL_MACHINE',
 @key = N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib',
 @value_name = N'HideInstance',
 @value = @instancehidden OUTPUT;
---SELECT @getValue;


DECLARE @First [smallint]
    ,@Last [smallint]
    ,@DBName [varchar] (200)
    ,@SQLCommand [varchar] (500)
    ,@DBWithGuestAccess [nvarchar] (4000)
 
IF OBJECT_ID('tempdb..#GuestUsersReport') IS NOT NULL
    DROP TABLE #GuestUsersReport
 
CREATE TABLE #GuestUsersReport (
    [DBName] [varchar](256)
    ,[UserName] [varchar](256)
    ,[HasDbAccess] [varchar](10)
    )
 
DECLARE @DatabaseList TABLE (
    [RowNo] [smallint] identity(1, 1)
    ,[DBName] [varchar](200)
    )
 
INSERT INTO @DatabaseList
SELECT d1.[name]
FROM [master]..[sysdatabases] d1 WITH (NOLOCK)
JOIN [sys].databases d2 on d1.dbid = d2.database_id
WHERE d1.[name] NOT IN ('master', 'tempdb', 'msdb')
AND d2.state_desc = 'ONLINE'
ORDER BY d1.[name]
 
SELECT @First = MIN([RowNo])
FROM @DatabaseList
 
SELECT @Last = MAX([RowNo])
FROM @DatabaseList
 
WHILE @First <= @Last
BEGIN
    SELECT @DBName = [DBName]
    FROM @DatabaseList
    WHERE [RowNo] = @First
 
    SET @SQLCommand = 'INSERT INTO #GuestUsersReport ([DBName], [UserName], [HasDbAccess])' + CHAR(13) + 'SELECT ' + CHAR(39) + @DBName + CHAR(39) + ' ,[name], CASE [hasdbaccess] WHEN 0 THEN ''N'' WHEN 1 THEN ''Y'' END ' + CHAR(13) + 'FROM [' + @DBName + ']..[sysusers] WHERE [name] LIKE ''guest'' AND [hasdbaccess] = 1'
 
    EXEC (@SQLCommand)
 
    SET @First = @First + 1
END
 
declare @SQLVerNo int;
SET @SQLVerNo = cast(substring(cast(serverproperty('ProductVersion') as varchar(50)) 
,0,charindex('.',cast(serverproperty('ProductVersion') as varchar(50)) ,0)) as int);
--SELECT name, permission_SET_desc FROM sys.assemblies WHERE is_user_defined = 1;
create table #Tsafeasm (
  DBName        sysname,
  Assm_name sysname, 
  permission_SET_desc varchar(5000)
)

create table #TSym (
  DBName        sysname,
  symkeyname sysname, 
  algo_desc varchar(5000),
  symmetrickeys int
)
create table #TASym (
  DBName        sysname,
  Asymkeyname sysname,
  algo_desc varchar(5000),
  Asymmetrickeys int
)
create table #TUser (
  DBName        sysname,
 hasdbaccess int)
 
IF @SQLVerNo >= 9
begin
  insert into #TSym ( DBName,symkeyname,algo_desc, symmetrickeys)
  exec sp_MSforeachdb
 '   select ''?'' as DBName,name,algorithm_desc, key_length  from [?].sys.symmetric_keys '
 
 insert into #Tsafeasm (DBName ,Assm_name ,permission_SET_desc )
 exec sp_MSforeachdb
 'select ''?'' as DBName, name, permission_SET_desc from  [?].sys.assemblies WHERE is_user_defined = 1' 

 insert into #TASym ( DBName,Asymkeyname, algo_desc,Asymmetrickeys)
  exec sp_MSforeachdb
 '  select ''?'' as DBName, name,algorithm_desc, key_length from  [?].sys.asymmetric_keys ' 
  end

select
S.name as 'Audit Name'
, CASE S.is_state_enabled
WHEN 1 THEN 'Y'
WHEN 0 THEN 'N' END as 'Audit Enabled'
, S.type_desc as 'Write Location'
, SA.name as 'Audit Specification Name'
, CASE SA.is_state_enabled
WHEN 1 THEN 'Y'
WHEN 0 THEN 'N' END as 'Audit Specification Enabled'
, SAD.audit_action_name
, SAD.audited_result into #sqlaudit
from sys.server_audit_specification_details as SAD
join sys.server_audit_specifications as SA
ON SAD.server_specification_id = SA.server_specification_id
join sys.server_audits as S
ON SA.audit_guid = S.audit_guid
WHERE SAD.audit_action_id IN ('CNAU', 'LGFL', 'LGSD');


 declare @NumErrorLogs int;
 exec master.sys.xp_instance_regread
 N'HKEY_LOCAL_MACHINE',
 N'Software\Microsoft\MSSQLServer\MSSQLServer',
 N'NumErrorLogs',
 @NumErrorLogs OUTPUT;
 create table #tmp (name varchar(50), config_value varchar(50))
 insert into #tmp (name, config_value)
 exec xp_loginconfig 'audit level'
 select getdate() Rundate,
  serverproperty('MachineName') as ComputerName,
   serverproperty('ServerName') as InstanceName, 
   serverproperty('Edition') as Edition,
   serverproperty('ProductVersion') as ProductVersion,  
   serverproperty('ProductLevel') as ProductLevel,
   @sqlportnumber as SQLPortNumber,
   @offportnumber as PortNumber,----older version this mayt not work
   case @instancehidden when 1 then 'Yes' else 'No' end as InstanceHidden,
 CASE 
   WHEN CONVERT(varchar(128), serverproperty ('productversion')) like '8%' THEN 'SQL2000'
   WHEN CONVERT(varchar(128), serverproperty ('productversion')) like '9%' THEN 'SQL2005'
   WHEN CONVERT(varchar(128), serverproperty ('productversion')) like '10.0%' THEN 'SQL2008'
   WHEN CONVERT(varchar(128), serverproperty ('productversion')) like '10.5%' THEN 'SQL2008 R2'
   WHEN CONVERT(varchar(128), serverproperty ('productversion')) like '11%' THEN 'SQL2012'
   WHEN CONVERT(varchar(128), serverproperty ('productversion')) like '12%' THEN 'SQL2014'
   WHEN CONVERT(varchar(128), serverproperty ('productversion')) like '13%' THEN 'SQL2016'     
   WHEN CONVERT(varchar(128), serverproperty ('productversion')) like '14%' THEN 'SQL2017'
   WHEN CONVERT(varchar(128), serverproperty ('productversion')) like '15%' THEN 'SQL2019'
   WHEN CONVERT(varchar(128), serverproperty ('productversion')) like '16%' THEN 'SQL2022' 
   ELSE 'unknown'
   END as MajorVersion,
   (isnull((select (@DBName+':'+Name+':'+cast(id as varchar))+'|' from #orphanusers FOR XML PATH('') ),'No Orphan uer found'  )) [Orphaned Users Values],
   (select case count(1) when 0 then 'Set' else 'Violation' end  from #orphanusers ) [Orphaned Users],
 (select name+':IsMustChangeEnabled:'+(case LOGINPROPERTY(name,'IsMustChange') when 1 then 'yes' else 'no' end )+'|'  from sys.sql_logins where LOGINPROPERTY(name,'IsMustChange')<>1 and is_disabled=0 FOR XML PATH('')) [MustChangePassword Values],
  (select case  when count(1)= 0 then 'Set' else 'Violation' End from sys.sql_logins where LOGINPROPERTY(name,'IsMustChange')<>1 and is_disabled=0) [MustChangePassword],
  (select (select (name+':'+'is_expiration_checked:'+cast(is_expiration_checked as varchar))+'|' from sys.sql_logins where is_disabled <>1  FOR XML PATH('')))  as IsExpirationcheckforAllValues,
 (select case  when count(name) > 0 then 'Violation' else 'SET' end  from sys.sql_logins WHERE is_expiration_checked = 0) IsExpirationcheckforAll,
 (select (select (name+':'+'Is_Policy_checked:'+cast(is_policy_checked as varchar))+'|' from sys.sql_logins where is_disabled <>1  FOR XML PATH('')))  as IspolicycheckforAllValues,
 (select case  when count(name) > 0 then 'Violation' else 'SET' end  from sys.sql_logins WHERE is_policy_checked = 0) IspolicycheckforAll,
 (SELECT case Count(1) when 0 then 'SA Named Id Does not exist' else 'SA Named exist' end  FROM sys.server_principals WHERE name = 'sa') [SA Named not Exist], 
 (select name from sys.server_principals WHERE sid = 0x01 ) as SARenamedValue ,
 (select case name when 'SA' then 'No' else 'Yes' end from sys.server_principals WHERE sid = 0x01 ) as SARenamed ,
 (select (select (name+'-is_disabled:'+ cast(is_disabled as varchar))+'|' from sys.server_principals WHERE sid = 0x01  FOR XML PATH(''))) as SADisabledValue  ,
 (select case is_disabled when 1 then 'Yes' else 'No' end  from sys.server_principals WHERE sid = 0x01  ) as SADisabled ,
 (select (select (name+'-is_policy_checked:'+ cast(is_policy_checked  as varchar))+'|' from sys.sql_logins WHERE sid = 0x01   FOR XML PATH(''))) as SAPasswordPolicyCheckedValue,
 (select case is_policy_checked  when 1 then 'Yes' else 'No' end from sys.sql_logins WHERE sid = 0x01  ) as SAPasswordPolicyChecked,
 (select upper(config_value) from #tmp ) LoginAuditLevel,
   case when ISNULL(@NumErrorLogs, -1) = -1 then 6 else @NumErrorLogs end as [NumberOfSQLErrorLogFiles],
  isnull((select (name+':'+cast(is_disabled as varchar)+'|') from sys.sql_logins WHERE upper(name)='SQLDEBUGGER' FOR XML PATH('')),'SQLDebugger Does not exist') as SQLDebuggerIdExistsValue  ,
(select  case  when count(name) > 0 then 'Violation' else 'SET' end  from sys.sql_logins WHERE upper(name)='SQLDEBUGGER') SQLDebuggerIdExists,
  isnull((select  name+':hasaccess-'+ cast(hasaccess as varchar)+':denylogin-'+cast(denylogin as varchar) from sys.syslogins WHERE upper(name)='builtin\administrators'),'builtin\administrators Does Not exist') BuiltinAdminExistValue,
    (select case when count(1) >0 then 'Violation' else 'SET' End from sys.syslogins where lower(name)='builtin\administrators') BuiltinAdminExist,
 isnull((select (DBName +':'+UserName+':'+HasDbAccess+'|')  from #GuestUsersReport FOR XML PATH('')),'Guest Does not exist') [Guest Permission Values],  
 (select  case when count(1) >0 then 'Violation' else 'SET' End from #GuestUsersReport) [Guest Permission],  
(select  VALUE_IN_use  from sys.configurations WHERE NAME ='remote admin connections') [remote admin connections],
(select  VALUE_IN_use  from sys.configurations WHERE NAME ='remote access') [remote access],
(select  VALUE_IN_use  from sys.configurations WHERE NAME ='scan for startup procs') [scan for startup procs],
(select  VALUE_IN_use  from sys.configurations WHERE NAME ='Ad Hoc Distributed Queries') [Ad Hoc Distributed Queries],
isnull((select  VALUE_IN_use  from sys.configurations WHERE NAME ='clr strict security'),'Setting Does not exist') [clr strict security],
(SELECT  case value_in_use when 1 then 'Enabled' else 'Disabled' end FROM sys.configurations WHERE name = 'xp_cmdshell') [XP_CmdShell],
(select  case value_in_use when 1 then 'Enabled' else 'Disabled' end   from sys.configurations WHERE NAME ='clr enabled') [clr enabled],
(SELECT   value_in_use FROM sys.configurations WHERE name = 'clr strict security' ) [clr strict security enabled],
(select  VALUE_IN_use  from sys.configurations WHERE NAME ='default trace enabled') [default trace enabled],
(select  VALUE_IN_use  from sys.configurations WHERE NAME ='Ole Automation Procedures') [Ole Automation Procedures],
(select  VALUE_IN_use  from sys.configurations WHERE NAME ='Allow cross db ownership chaining') [Cross Database Permissions],
(select VALUE_IN_use from sys.configurations WHERE NAME ='Database Mail XPs') [Database Mail XPs] ,
isnull((select (DbName+' Assembly Name:'+Assm_name+' Permission Set:'+permission_SET_desc+'|') from #Tsafeasm where DBName not in ('master','msdb' ,'tempdb','model')  FOR XML PATH('')),'Assembly Does not exist') [CLR Safe Assembly Values],
(select case when count(1) >0 then 'Violation' else 'SET' End  from #Tsafeasm where DBName not in ('master','msdb' ,'tempdb','model') and  permission_SET_desc <>'SAFE_ACCESS'  ) [CLR Safe Assembly],
isnull((select (DbName+' KeyName:'+symkeyname+' Algo Desc:'+Algo_desc+'|') from #TSym where DBName not in ('master','msdb' ,'tempdb','model')  FOR XML PATH('')),'Key Does not exist') [Symmetric Key Encryption Levels Values],
(select case when count(1) >0 then 'Violation' else 'SET' End  from #TSym where DBName not in ('master','msdb' ,'tempdb','model') and  symmetrickeys <128  ) [Symmetric Key Encryption Levels],

isnull((select (DbName+' KeyName:'+symkeyname+' Algo Desc:'+Algo_desc+'|') from #TSym where DBName not in ('master','msdb' ,'tempdb','model')  FOR XML PATH('')),'Key Does not exist') [Symmetric Key Size Values] ,
(select case when count(1) >0 then 'Violation' else 'SET' End  from #TSym where DBName not in ('master','msdb' ,'tempdb','model') and  symmetrickeys <128  ) [Symmetric Key Size],

isnull((select (DbName+' KeyName:'+Asymkeyname+' Algo Desc:'+Algo_desc+'|') from #TASym where DBName not in ('master','msdb' ,'tempdb','model')  FOR XML PATH('')),'Key Does not exist')  [Asymmetric Key Encryption Level Values] ,
(select case when count(1) >0 then 'Violation' else 'SET' End  from #TASym where DBName not in ('master','msdb' ,'tempdb','model') and  Asymmetrickeys <2048   ) [Asymmetric Key Encryption Level],

isnull((select (DbName+' KeyName:'+Asymkeyname+' Algo Desc:'+Algo_desc+'|') from #TASym where DBName not in ('master','msdb' ,'tempdb','model')  FOR XML PATH('')),'Key Does not exist') [Asymmetric Key Size Values] ,
(select case when count(1) >0 then 'Violation' else 'SET' End  from #TASym where DBName not in ('master','msdb' ,'tempdb','model') and  Asymmetrickeys <2048) [AAsymmetric Key Size],

isnull((select (s.name+':'+sad.audited_result+':'+cast(sa.is_state_enabled as varchar)+'|') from sys.server_audit_specification_details as SAD
join sys.server_audit_specifications as SA ON SAD.server_specification_id = SA.server_specification_id
join sys.server_audits as S ON SA.audit_guid = S.audit_guid WHERE SAD.audit_action_id IN ('CNAU', 'LGFL', 'LGSD') and SA.is_state_enabled =1 FOR XML PATH('')),'No Audit Configured') SQLAUDITValues,
(select case  when count(1) > 0 then 'SET' else 'Violation'   end
from sys.server_audit_specification_details as SAD
join sys.server_audit_specifications as SA
ON SAD.server_specification_id = SA.server_specification_id
join sys.server_audits as S
ON SA.audit_guid = S.audit_guid
WHERE SAD.audit_action_id IN ('CNAU', 'LGFL', 'LGSD')
and SA.is_state_enabled =1) SQLAUDIT,

isnull((select (name+':is_trustworthy_on:'+cast(is_trustworthy_on as varchar)+'|') from sys.databases WHERE is_trustworthy_on = 1 AND name != 'msdb'FOR XML PATH('')),'No Such DB exist') [TrustworthyValues],
(select case when count(1) >0 then 'Violation' else 'SET' End  from sys.databases WHERE is_trustworthy_on = 1 AND name != 'msdb') [Trustworthy],

(select (name+':is_auto_close_on:'+cast(is_auto_close_on as varchar)+'|') from sys.databases WHERE containment <> 0 and is_auto_close_on = 1 FOR XML PATH('')) [AutoCloseValues],
(select case when count(1) >0 then 'Violation' else 'SET' End  from sys.databases WHERE containment <> 0 and is_auto_close_on = 1) [AutoClose],

isnull((select (sp.name+'|') from msdb.dbo.sysproxylogin spl join sys.database_principals dp ON dp.sid = spl.sid join msdb..sysproxies sp ON sp.proxy_id = spl.proxy_id WHERE principal_id = USER_ID('public') FOR XML PATH('')),'Does not exist') [Public agent proxies Values] ,
(select case when count(1) >0 then 'Violation' else 'SET' End from msdb.dbo.sysproxylogin spl join sys.database_principals dp ON dp.sid = spl.sid join msdb..sysproxies sp ON sp.proxy_id = spl.proxy_id WHERE principal_id = USER_ID('public')) [Public agent proxies] ,

isnull((SELECT pr.[name] +'|'+ pe.[permission_name]+'|'+ pe.[state_desc] FROM master.sys.server_principals pr JOIN master.sys.server_permissions pe ON pr.[principal_id] = pe.[grantee_principal_id] WHERE pr.[type_desc] = 'WINDOWS_GROUP' AND pr.[name] like CAST(SERVERPROPERTY('MachineName') AS nvarchar) + '%' FOR XML PATH('')),'Does Not exist') [Windows local groups Values],

(select case when count(1) >0 then 'Violation' else 'SET' End from sys.server_principals pr join sys.server_permissions pe ON pr.[principal_id] = pe.[grantee_principal_id] WHERE pr.[type_desc] = 'WINDOWS_GROUP' AND pr.[name] like cast(serverproperty('MachineName') as nvarchar) + '%') [Windows local groups],

isnull((select (class_desc+':'+permission_name+':'+cast(major_id as varchar)+'|') from master.sys.server_permissions WHERE (grantee_principal_id = SUSER_SID(N'public') and state_desc LIKE 'GRANT%') FOR XML PATH('')),'Does not exist')  [Public access levels Values],
(select case when count(1) >0 then 'Violation' else 'SET' End from master.sys.server_permissions 
WHERE (grantee_principal_id = SUSER_SID(N'public') and state_desc LIKE 'GRANT%') AND NOT (state_desc = 'GRANT' and [permission_name] = 'VIEW ANY DATABASE' and class_desc = 'SERVER') AND 
NOT (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and class_desc = 'ENDPOINT' and major_id = 2) AND 
NOT (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and class_desc = 'ENDPOINT' and major_id = 3) AND NOT (state_desc = 'GRANT' 
and [permission_name] = 'CONNECT' and class_desc = 'ENDPOINT' and major_id = 4) AND NOT (state_desc = 'GRANT' and [permission_name] = 'CONNECT' 
and class_desc = 'ENDPOINT' and major_id = 5))  [Public access levels],
isnull((SELECT pr.[name], pe.[permission_name], pe.[state_desc] FROM sys.server_principals pr JOIN sys.server_permissions pe ON pr.principal_id = pe.grantee_principal_id WHERE pr.name like 'BUILTIN%'  FOR XML PATH('')),'Does Not exist') [Windows Builtin ID Values],
(select case when count(1) >0 then 'Violation' else 'SET' End FROM sys.server_principals pr JOIN sys.server_permissions pe ON pr.principal_id = pe.grantee_principal_id WHERE pr.name like 'BUILTIN%') [Windows Builtin ID],
isnull((SELECT DBname+':'+DBuser+'|' FROM #tusercdb FOR XML PATH('')),'Does Not exist') [Contained Database SQL Auth not used Values],
(select case when count(1) >0 then 'Violation' else 'SET' End  from #tusercdb ) [Contained Database SQL Auth not used]
END