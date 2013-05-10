ALTER PROCEDURE [dbo].[Dot_OddsUpdFGLG_AutoBookie] 
@OddsID int,
@Type varchar(10),
@StdStake float,
@NewOffer bit = 0 OUTPUT,
@NewStake float = 0 OUTPUT
AS
SET NOCOUNT ON

declare @cs00 float
declare @csodds float
declare @csoddsid int
set @cs00 = 0

select @csodds = cs.cs00,  @csoddsid = cs.oddsid
from odds cs with (nolock) 
inner join match m with (nolock) on cs.matchid = m.matchid and cs.bettype = 4
inner join odds with (nolock) on odds.matchid = m.matchid
where odds.oddsid = @OddsID

Update Odds with (ROWLOCK, UPDLOCK)
set 
	@cs00 = case when @Type = '0:0' and O.ChangeOdds=1 then round(@csodds - (@csodds-1)*gapodds1,2) else @csodds end,
	cs00 = case when @Type = '0:0' and O.ChangeOdds=1 then round(@csodds - (@csodds-1)*gapodds1,2) else @csodds end,
	cs11 = case when @Type = '1:1' and O.ChangeOdds=1 then round(cs11 - (cs11-1)*gapodds1,2) else cs11 end,
	cs12 = case when @Type = '1:2' and O.ChangeOdds=1 then round(cs12 - (cs12-1)*gapodds1,2) else cs12 end,
	cs21 = case when @Type = '2:1' and O.ChangeOdds=1 then round(cs21 - (cs21-1)*gapodds1,2) else cs21 end,
	cs22 = case when @Type = '2:2' and O.ChangeOdds=1 then round(cs22 - (cs22-1)*gapodds1,2) else cs22 end,
	bal00 = case when @Type = '0:0' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal00 else Bal00+@StdStake end else bal00 end,
	bal11 = case when @Type = '1:1' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal11 else Bal11+@StdStake end else bal11 end,
	bal12 = case when @Type = '1:2' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal12 else Bal12+@StdStake end else bal12 end,
	bal21 = case when @Type = '2:1' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal21 else Bal21+@StdStake end else bal21 end,
	bal22 = case when @Type = '2:2' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal22 else Bal22+@StdStake end else bal22 end,
	changetime = case when O.ChangeOdds = 1 then dateadd(ss,0,getdate()) when O.NewOffer = 1 then ChangeTime else getdate() end,
	@NewOffer = O.NewOffer,
	@NewStake = O.NewStake
from dbo.Odds INNER JOIN
(
	Select
		case when (@StdStake + bal >= Risk and @StdStake + bal <= Risk + StakeRange) or (@StdStake + bal > Risk + StakeRange and Risk - Bal <10) or (@StdStake + bal < Risk and Risk - (Bal + @StdStake) <10) then 1 else 0 end as ChangeOdds,
		(case when @StdStake + bal > Risk + StakeRange then 1 else 0 end) as NewOffer,
		(case when @StdStake + bal > Risk + StakeRange then case when Risk-bal>=10 then Risk - abs(Bal) + StakeRange else @StdStake end else 0 end) as NewStake,
		Odds.OddsID 
	From 
		dbo.Odds with (ROWLOCK, UPDLOCK)
		INNER JOIN 
			(
				Select case @Type			
						when '0:0' then bal00
						when '1:1' then bal11		when '1:2' then bal12
						when '2:1' then bal21		when '2:2' then bal22
					end as Bal, 
					OddsID 
				from dbo.Odds with (ROWLOCK, UPDLOCK) 
				WHERE OddsID = @OddsID
			) AS O2 ON Odds.OddsID = O2.OddsID
	where Odds.OddsID = @OddsID
) as O on Odds.OddsID = O.OddsID
where Odds.OddsID = @OddsID

update Odds with (ROWLOCK, UPDLOCK)
set cs00 = @cs00,
	changetime = case when @csodds = @cs00 then changetime else getdate() end
where Odds.OddsID = @csoddsid


