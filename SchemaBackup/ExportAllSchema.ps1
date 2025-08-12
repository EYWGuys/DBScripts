# Usage: 
# step 1: Open Powershell as an admin. 
# Start Script
Set-ExecutionPolicy RemoteSigned
# Set-ExecutionPolicy -ExecutionPolicy:Unrestricted -Scope:LocalMachine
#function SqlServerSchemaBackup([string]$serverName, [string]$dbname, [string]$scriptpath)
#{
############update this section
$serverName="SqlServer"
$dbname="AdventureWorks2014" # optional for single db
$scriptpath="D:\Output"
################
  [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
  [System.Reflection.Assembly]::LoadWithPartialName("System.Data") | Out-Null
  $srv = new-object "Microsoft.SqlServer.Management.SMO.Server" $serverName
  $srv.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.View], "IsSystemObject")
  $SMOserver = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $serverName
  $db = New-Object "Microsoft.SqlServer.Management.SMO.Database"
  $databases = $srv.Databases
  $db = $srv.Databases[$dbname]
  $scr = New-Object "Microsoft.SqlServer.Management.Smo.Scripter"
  #scriptr
  $deptype = New-Object "Microsoft.SqlServer.Management.Smo.DependencyType"
  $scr.Server = $srv
  $options = New-Object "Microsoft.SqlServer.Management.SMO.ScriptingOptions"
  $options.AllowSystemObjects = $false
  $options.IncludeDatabaseContext = $true
  $options.IncludeIfNotExists = $false
  $options.ClusteredIndexes = $true
  $options.Default = $true
  $options.DriAll = $true
  $options.Indexes = $true
  $options.NonClusteredIndexes = $true
  $options.IncludeHeaders = $false
  $options.ToFileOnly = $true
  $options.AppendToFile = $true
  $options.ScriptDrops = $false 

  # Set options for SMO.Scripter
  $scr.Options = $options
  
  $BaseSavePath = $scriptpath + $sql_server + "\"

  #Remove existing objects.
  Remove-Item $BaseSavePath -Recurse

 #Script server-level objects.
$ServerSavePath = $BaseSavePath
$ServerObjects = $SMOserver.BackupDevices
$ServerObjects += $SMOserver.Endpoints
$ServerObjects += $SMOserver.JobServer.Jobs
$ServerObjects += $SMOserver.LinkedServers
$ServerObjects += $SMOserver.Triggers

foreach ($ScriptThis in $ServerObjects | Where-Object { !($_.IsSystemObject) }) {
    #Need to Add Some mkDirs for the different $Fldr=$ScriptThis.GetType().Name
    $scriptr = new-object ('Microsoft.SqlServer.Management.Smo.Scripter') ($SMOserver)
    $scriptr.Options.AppendToFile = $True
    $scriptr.Options.AllowSystemObjects = $False
    $scriptr.Options.ClusteredIndexes = $True
    $scriptr.Options.DriAll = $True
    $scriptr.Options.ScriptDrops = $False
    $scriptr.Options.IncludeHeaders = $False
    $scriptr.Options.ToFileOnly = $True
    $scriptr.Options.Indexes = $True
    $scriptr.Options.Permissions = $True
    $scriptr.Options.WithDependencies = $False

    <#Script the Drop too#>
    $ScriptDrop = new-object ('Microsoft.SqlServer.Management.Smo.Scripter') ($SMOserver)
    $ScriptDrop.Options.AppendToFile = $True
    $ScriptDrop.Options.AllowSystemObjects = $False
    $ScriptDrop.Options.ClusteredIndexes = $True
    $ScriptDrop.Options.DriAll = $True
    $ScriptDrop.Options.ScriptDrops = $True
    $ScriptDrop.Options.IncludeHeaders = $False
    $ScriptDrop.Options.ToFileOnly = $True
    $ScriptDrop.Options.Indexes = $True
    $ScriptDrop.Options.WithDependencies = $False

    <#This section builds folder structures.  Remove the date folder if you want to overwrite#>
    $TypeFolder = $ScriptThis.GetType().Name
    if ((Test-Path -Path "$ServerSavePath\$TypeFolder") -eq "true") `
    { "Scripting Out $TypeFolder $ScriptThis" } `
        else { new-item -type directory -name "$TypeFolder"-path "$ServerSavePath" }
    $ScriptFile = $ScriptThis -replace ":", "-" -replace "\\", "-"
    $ScriptDrop.Options.FileName = $ServerSavePath + "\" + $TypeFolder + "\" + $ScriptFile.Replace("]", "").Replace("[", "") + ".sql"
    $scriptr.Options.FileName = $ServerSavePath + "\" + $TypeFolder + "\" + $ScriptFile.Replace("]", "").Replace("[", "") + ".sql"

    #This is where each object actually gets scripted one at a time.
    $ScriptDrop.Script($ScriptThis)
    $scriptr.Script($ScriptThis)
} #This ends the object scripting loop at the server level.

 #Script database-level objects.
foreach ($db in $databases) {
   # If ($db.Name -eq $dbname)   #Remove or comment this line to run the script for all dbs
   # { 
    $DatabaseObjects = $db.ApplicationRoles
    $DatabaseObjects += $db.Assemblies
    $DatabaseObjects += $db.ExtendedStoredProcedures
    $DatabaseObjects += $db.ExtendedProperties
    $DatabaseObjects += $db.PartitionFunctions
    $DatabaseObjects += $db.PartitionSchemes
    $DatabaseObjects += $db.Roles
    $DatabaseObjects += $db.Rules
    $DatabaseObjects += $db.Schemas
    $DatabaseObjects += $db.StoredProcedures
    $DatabaseObjects += $db.Synonyms
    $DatabaseObjects += $db.Tables
    $DatabaseObjects += $db.Triggers
    $DatabaseObjects += $db.UserDefinedAggregates
    $DatabaseObjects += $db.UserDefinedDataTypes
    $DatabaseObjects += $db.UserDefinedFunctions
    $DatabaseObjects += $db.UserDefinedTableTypes
    $DatabaseObjects += $db.UserDefinedTypes
    $DatabaseObjects += $db.Users
    $DatabaseObjects += $db.Views
#Build this portion of the directory structure out here.  Remove the existing directory and its contents first.
#$DatabaseSavePath = $BaseSavePath + "Databases\" + $db.Name
$DatabaseSavePath = $scriptpath + "\" + $db.Name
new-item -type directory -path "$DatabaseSavePath"
foreach ($ScriptThis in $DatabaseObjects | Where-Object { !($_.IsSystemObject) }) {
    #Need to Add Some mkDirs for the different $Fldr=$ScriptThis.GetType().Name
    $scriptr = new-object ('Microsoft.SqlServer.Management.Smo.Scripter') ($SMOserver)    
    $scriptr.Server = $srv
    $scriptr.Options.AppendToFile = $True
    $scriptr.Options.AllowSystemObjects = $False
    $scriptr.Options.ClusteredIndexes = $True
    $scriptr.Options.DriAll = $True
    $scriptr.Options.ScriptDrops = $False
    $scriptr.Options.IncludeHeaders = $False
    $scriptr.Options.ToFileOnly = $True
    $scriptr.Options.Indexes = $True
    $scriptr.Options.Permissions = $True
    $scriptr.Options.WithDependencies = $False

    <#Script the Drop too#>
    $ScriptDrop = new-object ('Microsoft.SqlServer.Management.Smo.Scripter') ($SMOserver)
    $ScriptDrop.Options.AppendToFile = $True
    $ScriptDrop.Options.AllowSystemObjects = $False
    $ScriptDrop.Options.ClusteredIndexes = $True
    $ScriptDrop.Options.DriAll = $True
    $ScriptDrop.Options.ScriptDrops = $True
    $ScriptDrop.Options.IncludeHeaders = $False
    $ScriptDrop.Options.ToFileOnly = $True
    $ScriptDrop.Options.Indexes = $True
    $ScriptDrop.Options.WithDependencies = $False

    <#This section builds folder structures.  Remove the date folder if you want to overwrite#>
    $TypeFolder = $ScriptThis.GetType().Name
    if ((Test-Path -Path "$DatabaseSavePath\$TypeFolder") -eq "true") `
    { "Scripting Out $TypeFolder $ScriptThis" } `
        else { new-item -type directory -name "$TypeFolder"-path "$DatabaseSavePath" }
    $ScriptFile = $ScriptThis -replace ":", "-" -replace "\\", "-"
    $ScriptDrop.Options.FileName = $DatabaseSavePath + "\" + $TypeFolder + "\" + $ScriptFile.Replace("]", "").Replace("[", "") + ".sql"
    $scriptr.Options.FileName = $DatabaseSavePath + "\" + $TypeFolder + "\" + $ScriptFile.Replace("]", "").Replace("[", "") + ".sql"

    #This is where each object actually gets scripted one at a time.
    $ScriptDrop.Script($ScriptThis)
    $scriptr.Script($ScriptThis)

} #This ends the object scripting loop.
} #This ends the database loop.
#}

   

#}




#=============
# Execute
#=============
ExportAllSchema SQL 'LAPTOP-KH184A0P\MSSQLSERVER_AS' c:\temp
#ExportAllSchema $args[0] $args[1] $args[2]
