SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Tong Hoang Dung
-- Create date: Sep 19 2008
-- Description:	Get All Sportype and their bettype that are running
-- =============================================
ALTER PROCEDURE [dbo].[Acc_Auto_OddsSelSportBettype]
	@IsGetParlay bit=0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    if(@IsGetParlay=1) 
		begin
		  select distinct m.sporttype,o.bettype from (select bettype,matchid from odds with(nolock) where bettype in (1,2,3,5,6,7,8,12,15,17,18,20) and oddsstatus='running' and liveindicator=0) o  inner join (select sporttype,matchid from match with (nolock) where eventstatus='running'  and multiple=1 AND DATEADD(second,-10,kickofftime) < CURRENT_TIMESTAMP) m  on (o.matchid=m.matchid) order by m.sporttype
		end
	else
		begin
		   select distinct m.sporttype,o.bettype from (select bettype,matchid from odds with(nolock) where bettype in (1,2,3,4,5,6,7,8,14,15,16,20) and oddsstatus='running') o  inner join (select sporttype,matchid from match with (nolock) where eventstatus='running'  and multiple<>1 AND DATEADD(second,-10,kickofftime) < CURRENT_TIMESTAMP) m  on (o.matchid=m.matchid) order by m.sporttype
		end
END
 
 
GO
GRANT EXECUTE ON [dbo].[Acc_Auto_OddsSelSportBettype] TO [Dot_Member]
GO