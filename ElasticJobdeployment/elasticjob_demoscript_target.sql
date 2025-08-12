----------------create logical server
--------------create demo db
-----create demo table and stored proc in it
-----go and create elastic job agent and during that create job db also

----step[1] ----create below table and stored proc on target db


USE [test]
GO

/****** Object:  Table [dbo].[demotable]    Script Date: 7/12/2025 12:35:49 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[demotable](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[NAME] [varchar](50) NOT NULL
) ON [PRIMARY]
GO


--------------
-- =============================================
CREATE PROCEDURE [dbo].[sp_insert_demodata]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	INSERT INTO [dbo].[demotable]
           ([NAME])
     VALUES
           (cast(getdate() as varchar(30)))
END
GO


----step 2
---on all servers create logins and  user
create login elasticjobuser with password ='H@r1b0lo'

--create db user in all dbs (job and target()
create user elasticjobuser for login elasticjobuser with default_schema =dbo
---give appropriate rights
exec sp_addrolemember N'db_owner', N'elasticjobuser'
