set nocount on
go
select @@servername
go
select
SERVERPROPERTY('MachineName') ServerName,CASE RIGHT(SUBSTRING(@@VERSION, CHARINDEX('Windows NT', @@VERSION), 14), 3)
   WHEN '5.0' THEN 'Windows 2000'
   WHEN '5.1' THEN 'Windows XP'
   WHEN '5.2' THEN 'Windows Server 2003/2003 R2'
   WHEN '6.0' THEN 'Windows Server 2008/Windows Vista'
   WHEN '6.1' THEN 'Windows Server 2008 R2/Windows 7'
   WHEN '6.2' THEN 'Windows Server 2012/Windows 8'
   WHEN '6.3' THEN 'Windows Server 2012 r2'
   WHEN '10.' THEN 'Windows Server 2016 and above'
   else 'Unknown'
  END AS [WindowsVersionBuild],
SERVERPROPERTY('ServerName') AS [SQLServerName]
, SERVERPROPERTY('ProductVersion') AS [SQLProductVersion]
, isnull(SERVERPROPERTY('InstanceName'),'Default') InstanceName
, CASE LEFT(CONVERT(VARCHAR, SERVERPROPERTY('ProductVersion')),4)
   WHEN '8.00' THEN 'SQL Server 2000'
   WHEN '9.00' THEN 'SQL Server 2005'
   WHEN '10.0' THEN 'SQL Server 2008'
   WHEN '10.5' THEN 'SQL Server 2008 R2'
   WHEN '11.0' THEN 'SQL Server 2012'
   WHEN '12.0' THEN 'SQL Server 2014'
   WHEN '13.0' THEN 'SQL Server 2016'
   WHEN '14.0' THEN 'SQL Server 2017'
   WHEN '12.0' THEN 'SQL Server 2019'
   ELSE 'Unknown'
  END AS [SQLVersionBuild]
, SERVERPROPERTY('ProductLevel') AS [SQLServicePack]
, SERVERPROPERTY('Edition') AS [SQLEdition]
, RIGHT(SUBSTRING(@@VERSION, CHARINDEX('Windows NT', @@VERSION), 14), 3) as [WindowsVersionNumber]
,
case SERVERPROPERTY('IsClustered') when 0 then 'No' else 'Yes' end IsClustered,
x.database_name DBName,
DATABASEPROPERTYEX(x.database_name, 'RECOVERY') RecoveryModel,
 case x.backuptype
 when 'D' then 'Full'
 when 'L' then 'Tlog'
 when 'I' then 'Diff'
 else 'Unknown'
 end backuptype ,
x.lastBackupDate,
case x.is_snapshot
when 0 then 'No' else 'Yes'
end SnapshotBackup,
(xx.backup_size/(1024*1024)) BackupSizeinMB,
case x.device_type
when 2 then 'Disk'
when 7 then 'Virtual Disk'
else 'Others'
end MediaType,
z.physical_device_name BackupLocation
from master..sysdatabases(nolock) d inner join
(select
bs.database_name,
bs.type backuptype,
bs.is_snapshot,
mf.device_type,
max(bs.backup_finish_date) lastBackupDate
from msdb.dbo.backupset(nolock) bs inner join msdb.dbo.backupmediafamily(nolock) mf on bs.media_set_id= mf.media_set_id
group by database_name,type, device_type, is_snapshot
) x
on d.name = x.database_name
inner join msdb.[dbo].backupset(nolock) xx on xx.database_name=x.database_name and
xx.type=x.backuptype and
xx.backup_finish_date=x.lastBackupDate and
xx.is_snapshot=x.is_snapshot
inner join msdb.[dbo].[backupmediafamily](nolock) z on z.media_set_id= xx.media_set_id
order by DBName,backuptype