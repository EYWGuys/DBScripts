Write-Output "Starting Job run"

$SQLServerName = "<ServerName>"    # Azure SQL logical server name  
$DatabaseName = "<DBname>"     # Azure SQL database name 
try {
    $queryParameter = "?resource=https://database.windows.net/" 
    $url = $env:IDENTITY_ENDPOINT + $queryParameter
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
    $Headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
    $Headers.Add("Metadata", "True") 
    $content =[System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing -Uri $url -Method 'GET' -Headers $Headers).RawContentStream.ToArray()) | ConvertFrom-Json 
    $Token = $content.access_token 
    Write-Output  "Create SQL connection string" 
    $conn = New-Object System.Data.SqlClient.SQLConnection  
    $conn.ConnectionString = "Data Source=$SQLServerName.database.windows.net;Initial Catalog=$DatabaseName;Connect Timeout=60" 
    $conn.AccessToken = $Token 
    Write-Output  "Connect to database" 
    $conn.Open()
    Write-Output  "Connection Opened" 
    #################update it to your query
    $ddlstmt = "Select @@servername"
    Write-Output  "going to execute below command:" 
    $ddlstmt 
    #################
    $command = New-Object -TypeName System.Data.SqlClient.SqlCommand($ddlstmt, $conn) 
    Write-Output  "results" 
    $command.ExecuteNonQuery() 
    $conn.Close()
}
catch {
    Write-Output "Exception occured:"
    Write-Output $_
}
