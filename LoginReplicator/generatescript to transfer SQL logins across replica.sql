SELECT N'CREATE LOGIN ['+sp.[name]+'] WITH PASSWORD=0x'+
    CONVERT(nvarchar(max), l.password_hash, 2)+N' HASHED, '+
    N'SID=0x'+CONVERT(nvarchar(max), sp.[sid], 2)+N';'
FROM master.sys.server_principals AS sp
INNER JOIN master.sys.sql_logins AS l ON sp.[sid]=l.[sid]
WHERE sp.name='<SQLID>'