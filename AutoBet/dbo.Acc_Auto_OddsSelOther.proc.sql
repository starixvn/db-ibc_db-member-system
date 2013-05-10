SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Acc_Auto_OddsSelOther]
	--@RequestType nvarchar(10) = 't', --t: today market, l : live market, e: early market, '': all market
	@SportType tinyint = 0,
	@BetType nvarchar(50)	
AS

SET NOCOUNT ON
SELECT  m.matchid, o.oddsid,o.bettype 
FROM 
  (SELECT matchid
	FROM dbo.match with (nolock)		
	WHERE eventstatus = 'running'
		AND sporttype=@SportType
		AND DATEADD(second,-15,CURRENT_TIMESTAMP) < kickofftime  
   ) m
   INNER JOIN 
	(select oddsid,matchid,bettype 
	   from dbo.odds with (nolock) 
	   WHERE oddsstatus='running' AND 
	         bettype in (SELECT val FROM dbo.StrSplit(@BetType, ','))	         
	)o 
 ON m.matchid = o.matchid	
GO
GRANT EXECUTE ON [dbo].[Acc_Auto_OddsSelOther] TO [Dot_Member]
GO