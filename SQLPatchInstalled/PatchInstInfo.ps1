
$sqlpatchlist= Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -like "Hotfix*SQL*" -or $_.DisplayName -like "Service Pack*SQL*" } | Sort-Object InstallDate
$sqlpatchlist | select ParentKeyName,InstallDate, KBNumber,ProductId,ProductVersion,PatchProductVersion,DisplayVersion, PatchType,SPLevel,DisplayName,HelpLink |Export-Csv -Path C:\temp\patchinghistory.csv -NoTypeInformation

