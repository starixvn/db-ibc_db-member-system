SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Acc_Auto_OddsSelParlay]
	--@RequestType nvarchar(10) = 't',
	@SportType tinyint = 0,
	@BetType nvarchar(50)
	--@LastChange datetime = NULL OUTPUT
AS

SET NOCOUNT ON
SELECT m.matchid,o.oddsid,o.bettype
from 
	(select matchid (nolock)
	 from match 
	 where sporttype=@SportType and multiple<>0 and DATEADD(second,-15,CURRENT_TIMESTAMP) < kickofftime and eventstatus='running') m
	 inner join 
	 (select oddsid,matchid,bettype
	  from odds	(nolock)  
	  where liveindicator=0 and bettype in (SELECT val FROM dbo.StrSplit(@BetType, ',')) and oddsstatus='running') o	  
	  on m.matchid=o.matchid


GO
GRANT EXECUTE ON [dbo].[Acc_Auto_OddsSelParlay] TO [Dot_Member]
GO