ALTER PROCEDURE [dbo].[Dot_OddsUpdCS_AutoBookie] 
@OddsID int,
@Type varchar(10),
@StdStake float,
@NewOffer bit = 0 OUTPUT,
@NewStake float = 0 OUTPUT
AS
SET NOCOUNT ON

declare @cs00 float
declare @fglgodds float
declare @fglgoddsid int
set @cs00 = 0

select @fglgodds=fglg.cs00, @fglgoddsid = fglg.oddsid
from odds fglg with (nolock) 
inner join match m with (nolock) on fglg.matchid = m.matchid and fglg.bettype = 14
inner join odds with (nolock) on odds.matchid = m.matchid
where odds.oddsid = @OddsID

Update Odds with (ROWLOCK, UPDLOCK)
set 
	@cs00 = case when @Type = '0:0' and O.ChangeOdds=1 then round(cs00 - (cs00-1)*gapodds1,2) else cs00 end,
	cs00 = case when @Type = '0:0' and O.ChangeOdds=1 then round(cs00 - (cs00-1)*gapodds1,2) else cs00 end,
	cs01 = case when @Type = '0:1' and O.ChangeOdds=1 then round(cs01 - (cs01-1)*gapodds1,2) else cs01 end,
	cs02 = case when @Type = '0:2' and O.ChangeOdds=1 then round(cs02 - (cs02-1)*gapodds1,2) else cs02 end,
	cs03 = case when @Type = '0:3' and O.ChangeOdds=1 then round(cs03 - (cs03-1)*gapodds1,2) else cs03 end,
	cs04 = case when @Type = '0:4' and O.ChangeOdds=1 then round(cs04 - (cs04-1)*gapodds1,2) else cs04 end,
	cs05 = case when @Type = '0:5' and O.ChangeOdds=1 then round(cs05 - (cs05-1)*gapodds1,2) else cs05 end,
	cs10 = case when @Type = '1:0' and O.ChangeOdds=1 then round(cs10 - (cs10-1)*gapodds1,2) else cs10 end,
	cs11 = case when @Type = '1:1' and O.ChangeOdds=1 then round(cs11 - (cs11-1)*gapodds1,2) else cs11 end,
	cs12 = case when @Type = '1:2' and O.ChangeOdds=1 then round(cs12 - (cs12-1)*gapodds1,2) else cs12 end,
	cs13 = case when @Type = '1:3' and O.ChangeOdds=1 then round(cs13 - (cs13-1)*gapodds1,2) else cs13 end,
	cs14 = case when @Type = '1:4' and O.ChangeOdds=1 then round(cs14 - (cs14-1)*gapodds1,2) else cs14 end,
	cs20 = case when @Type = '2:0' and O.ChangeOdds=1 then round(cs20 - (cs20-1)*gapodds1,2) else cs20 end,
	cs21 = case when @Type = '2:1' and O.ChangeOdds=1 then round(cs21 - (cs21-1)*gapodds1,2) else cs21 end,
	cs22 = case when @Type = '2:2' and O.ChangeOdds=1 then round(cs22 - (cs22-1)*gapodds1,2) else cs22 end,
	cs23 = case when @Type = '2:3' and O.ChangeOdds=1 then round(cs23 - (cs23-1)*gapodds1,2) else cs23 end,
	cs24 = case when @Type = '2:4' and O.ChangeOdds=1 then round(cs24 - (cs24-1)*gapodds1,2) else cs24 end,
	cs30 = case when @Type = '3:0' and O.ChangeOdds=1 then round(cs30 - (cs30-1)*gapodds1,2) else cs30 end,
	cs31 = case when @Type = '3:1' and O.ChangeOdds=1 then round(cs31 - (cs31-1)*gapodds1,2) else cs31 end,
	cs32 = case when @Type = '3:2' and O.ChangeOdds=1 then round(cs32 - (cs32-1)*gapodds1,2) else cs32 end,
	cs33 = case when @Type = '3:3' and O.ChangeOdds=1 then round(cs33 - (cs33-1)*gapodds1,2) else cs33 end,
	cs34 = case when @Type = '3:4' and O.ChangeOdds=1 then round(cs34 - (cs34-1)*gapodds1,2) else cs34 end,
	cs40 = case when @Type = '4:0' and O.ChangeOdds=1 then round(cs40 - (cs40-1)*gapodds1,2) else cs40 end,
	cs41 = case when @Type = '4:1' and O.ChangeOdds=1 then round(cs41 - (cs41-1)*gapodds1,2) else cs41 end,
	cs42 = case when @Type = '4:2' and O.ChangeOdds=1 then round(cs42 - (cs42-1)*gapodds1,2) else cs42 end,
	cs43 = case when @Type = '4:3' and O.ChangeOdds=1 then round(cs43 - (cs43-1)*gapodds1,2) else cs43 end,
	cs44 = case when @Type = '4:4' and O.ChangeOdds=1 then round(cs44 - (cs44-1)*gapodds1,2) else cs44 end,
	cs50 = case when @Type = '5:0' and O.ChangeOdds=1 then round(cs50 - (cs50-1)*gapodds1,2) else cs50 end,
	bal00 = case when @Type = '0:0' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal00 else Bal00+@StdStake end else bal00 end,
	bal01 = case when @Type = '0:1' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal01 else Bal01+@StdStake end else bal01 end,
	bal02 = case when @Type = '0:2' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal02 else Bal02+@StdStake end else bal02 end,
	bal03 = case when @Type = '0:3' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal03 else Bal03+@StdStake end else bal03 end,
	bal04 = case when @Type = '0:4' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal04 else Bal04+@StdStake end else bal04 end,
	bal05 = case when @Type = '0:5' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal05 else Bal05+@StdStake end else bal05 end,
	bal10 = case when @Type = '1:0' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal10 else Bal10+@StdStake end else bal10 end,
	bal11 = case when @Type = '1:1' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal11 else Bal11+@StdStake end else bal11 end,
	bal12 = case when @Type = '1:2' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal12 else Bal12+@StdStake end else bal12 end,
	bal13 = case when @Type = '1:3' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal13 else Bal13+@StdStake end else bal13 end,
	bal14 = case when @Type = '1:4' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal14 else Bal14+@StdStake end else bal14 end,
	bal20 = case when @Type = '2:0' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal20 else Bal20+@StdStake end else bal20 end,
	bal21 = case when @Type = '2:1' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal21 else Bal21+@StdStake end else bal21 end,
	bal22 = case when @Type = '2:2' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal22 else Bal22+@StdStake end else bal22 end,
	bal23 = case when @Type = '2:3' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal23 else Bal23+@StdStake end else bal23 end,
	bal24 = case when @Type = '2:4' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal24 else Bal24+@StdStake end else bal24 end,
	bal30 = case when @Type = '3:0' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal30 else Bal30+@StdStake end else bal30 end,
	bal31 = case when @Type = '3:1' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal31 else Bal31+@StdStake end else bal31 end,
	bal32 = case when @Type = '3:2' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal32 else Bal32+@StdStake end else bal32 end,
	bal33 = case when @Type = '3:3' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal33 else Bal33+@StdStake end else bal33 end,
	bal34 = case when @Type = '3:4' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal34 else Bal34+@StdStake end else bal34 end,
	bal40 = case when @Type = '4:0' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal40 else Bal40+@StdStake end else bal40 end,
	bal41 = case when @Type = '4:1' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal41 else Bal41+@StdStake end else bal41 end,
	bal42 = case when @Type = '4:2' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal42 else Bal42+@StdStake end else bal42 end,
	bal43 = case when @Type = '4:3' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal43 else Bal43+@StdStake end else bal43 end,
	bal44 = case when @Type = '4:4' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal44 else Bal44+@StdStake end else bal44 end,
	bal50 = case when @Type = '5:0' then case when O.ChangeOdds=1 then 0 when O.NewOffer=1 then Bal50 else Bal50+@StdStake end else bal50 end,
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
						when '0:0' then bal00		when '0:1' then bal01		when '0:2' then bal02		when '0:3' then bal03		when '0:4' then bal04		when '0:5' then bal05
						when '1:0' then bal10		when '1:1' then bal11		when '1:2' then bal12		when '1:3' then bal13		when '1:4' then bal14		
						when '2:0' then bal20		when '2:1' then bal21		when '2:2' then bal22		when '2:3' then bal23		when '2:4' then bal24
						when '3:0' then bal30		when '3:1' then bal31		when '3:2' then bal32		when '3:3' then bal33		when '3:4' then bal34
						when '4:0' then bal40		when '4:1' then bal41		when '4:2' then bal42		when '4:3' then bal43		when '4:4' then bal44
						when '5:0' then bal50
					end as Bal, 
					OddsID 
				from dbo.Odds with (ROWLOCK, UPDLOCK) 
				WHERE OddsID = @OddsID
			) AS O2 ON Odds.OddsID = O2.OddsID
	where Odds.OddsID = @OddsID
) as O on Odds.OddsID = O.OddsID
where Odds.OddsID = @OddsID

if(@fglgoddsid is not null and @fglgoddsid <> 0)
begin
Update Odds with (ROWLOCK, UPDLOCK)
set 
	cs00 = @cs00,
	changetime = case when @fglgodds = @cs00 then changetime else getdate() end
end
