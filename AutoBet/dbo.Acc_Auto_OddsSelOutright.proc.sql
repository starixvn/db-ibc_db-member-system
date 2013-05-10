SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Acc_Auto_OddsSelOutright]
	
AS
	SET NOCOUNT ON
	SELECT o.orid
	FROM outright o with (nolock)		
	WHERE o.oddsstatus = 'running' AND DATEADD(second,-15,CURRENT_TIMESTAMP) < o.kickofftime
	

GO
GRANT EXECUTE ON [dbo].[Acc_Auto_OddsSelOutright] TO [Dot_Member]
GO