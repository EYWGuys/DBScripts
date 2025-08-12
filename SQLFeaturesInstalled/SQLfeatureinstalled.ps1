$setup = Get-ChildItem -Recurse -Include setup.exe -Path "$env:ProgramFiles\Microsoft SQL Server" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match 'Setup Bootstrap\\SQL' -or $_.FullName -match 'Bootstrap\\Release\\Setup.exe' -or $_.FullName -match 'Bootstrap\\Setup.exe' } |
            Sort-Object FullName -Descending | Select-Object -First 1
            if ($setup) {
                $null = Start-Process -FilePath $setup.FullName -ArgumentList "/Action=RunDiscovery /q" -Wait
                $parent = Split-Path (Split-Path $setup.Fullname)
                $xmlfile = Get-ChildItem -Recurse -Include SqlDiscoveryReport.xml -Path $parent | Sort-Object LastWriteTime -Descending | Select-Object -First 1

                if ($xmlfile) {
                    $xml = [xml](Get-Content -Path $xmlfile)
                    $xml.ArrayOfDiscoveryInformation.DiscoveryInformation
                }
            }



