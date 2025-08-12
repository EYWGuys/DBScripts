---select * from sys.partition_functions
---select * from sys.partition_range_values
---select * from testp.sys.partition_schemesif not exists(select * from sys.partition_range_values where value =1+datepart(YYYY,getdate()))
declare @prt as int

select @prt = count(1) from Corp_Audit_Prd.sys.partition_range_values where value = YEAR(getdate()) + 1
if @prt = 0 
begin
declare @dbnm as varchar(255)='Corp_Audit_Prd'
DECLARE @filegroup NVARCHAR(MAX) = ''
DECLARE @file NVARCHAR(MAX) = ''
DECLARE @PScheme NVARCHAR(MAX) = ''
DECLARE @PFunction NVARCHAR(MAX) = ''
declare @NewFileGroup varchar(255)=''
declare @FileName varchar(4000) =''
declare @File_Path varchar(4000) ='I:\SQLDATA\CorpAuditPrdData\'
declare @PartitionScheme varchar(255)='PrSch_FYPartition'
declare @PartitionFunction varchar(255)='PrFunc_FYPartition'
declare @NewRange varchar(255) = ltrim(rtrim(str(1+datepart(YYYY,getdate()))))set @FileName ='FG_FY_'+@NewRange
set @NewFileGroup='FG_FY_'+@NewRange
SELECT @filegroup = @filegroup +
    CONCAT('IF NOT EXISTS(SELECT 1 FROM '+@dbnm+'.sys.filegroups WHERE name = ''',@NewFileGroup,''')
    BEGIN
      ALTER DATABASE '+@dbnm+' ADD FileGroup ',@NewFileGroup,'
    END;'),
    @file = @file + CONCAT('IF NOT EXISTS(SELECT 1 FROM '+@dbnm+'.sys.database_files WHERE name = ''',@FileName,''')
    BEGIN
    ALTER DATABASE '+@dbnm+' ADD FILE
    (NAME = ''',@FileName,''',
    FILENAME = ''',@File_Path,@FileName,'.ndf'',
    SIZE = 5MB, MAXSIZE = UNLIMITED,
    FILEGROWTH = 10MB )
    TO FILEGROUP ',@NewFileGroup, '
    END;'),
    @PScheme = @PScheme + CONCAT('use '+@dbnm+'; ALTER PARTITION SCHEME ', @PartitionScheme, ' NEXT USED ',@NewFileGroup,';'),
    @PFunction = @PFunction + CONCAT('use '+@dbnm+';ALTER PARTITION FUNCTION ', @PartitionFunction, '() SPLIT RANGE (''',@NewRange,''');')
--FROM #generateScriptEXEC (@filegroup)
EXEC (@filegroup)
EXEC (@file)
EXEC (@PScheme)
EXEC (@PFunction)
---RAISERROR(@filegroup, 11,1) WITH LOG
---RAISERROR(@file, 11,1) WITH LOG
---RAISERROR(@PScheme, 11,1) WITH LOG
---RAISERROR(@PFunction, 11,1) WITH LOG
end

