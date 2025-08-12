
import-module -name sqlserver
if (get-module |select name | Where-Object {$_.Name -like "sqlserver"}) 
{
    write-host "assessing"
} 
else 
{
    "Required module is still missing. can not continue"
    break
}
#get recommendations for named instance
get-sqlinstance -ServerInstance "LAPTOP-KH184A0P\MSSQLSERVER_AS" | Invoke-SqlAssessment

#get recommendations for master database on named instance 
Get-SqlDatabase -ServerInstance "LAPTOP-KH184A0P\MSSQLSERVER_AS" -database master | Invoke-SqlAssessment

#save that to database 
get-sqlinstance -ServerInstance "LAPTOP-KH184A0P" | Invoke-SqlAssessment -FlattenOutput | 
         Write-SqlTableData -ServerInstance "LAPTOP-KH184A0P" -DatabaseName "dba_tools" -SchemaName "dbo" -TableName "AssemetResults" -Force
         ###https://github.com/microsoft/sql-server-samples/tree/master/samples/manage/sql-assessment-api
         ##https://github.com/microsoft/sql-server-samples/tree/master/samples/manage/sql-assessment-api/notebooks

 
 


#get all rules by a specific tag
get-sqlinstance -ServerInstance "LAPTOP-KH184A0P\MSSQLSERVER_AS" | get-SqlAssessmentitem -check backup |select targetobject, description, diplayname, helplink, enabled, lebvel, message

#get all rules 
get-sqlinstance -ServerInstance "LAPTOP-KH184A0P" | get-SqlAssessmentitem |select targetobject, description, diplayname, helplink, enabled, lebvel, message


