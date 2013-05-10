
ALTER PROCEDURE [dbo].[Dot_Member_AutoBookie1]
	@custid int,
	@creator int,
	@ugroup nvarchar(20),
	@oddsid int,
	@bettype int,
	@betteam nvarchar(1),
	@hdp1 float,
	@hdp2 float,
	@odds smallmoney,
	@OriginalOdds smallmoney,
	@livehomescore tinyint,
	@liveawayscore tinyint,
	@stake money,
	@actualrate float,
	@virtualrate float,
	@autosuspend bit,
	@curr tinyint,
	@eventdate smalldatetime,
	@apositiontaking smallmoney,
	@mpositiontaking smallmoney,
	@spositiontaking smallmoney,
	@playerdiscount smallmoney,
	@adiscount smallmoney,
	@mdiscount smallmoney,
	@sdiscount smallmoney,
	@recommend int,
	@mrecommend int,
	@srecommend int,
	@site nvarchar(50),
	@sitetype nvarchar(10),
	@addspread float,
	@http_ref nvarchar(150),
	@remote_add nvarchar(20),
	@betfrom nvarchar(10),
	@BetCredit money,
	@StartTime datetime,
	@Username nvarchar(50),
	@CurrencyName nvarchar(10),
	@trans_id int OUTPUT,
	@new_odds float OUTPUT
as

SET DEADLOCK_PRIORITY  low

-----declare variable --------------
declare @transid int,@ohdp1 float,@ohdp2 float
declare @oddslivehomescore int,@oddsliveawayscore int
declare @matchdate smalldatetime,@liveindicator bit,@matchid int
declare @running int, @running_no bigint,@newoffersetup bit,@godds float
declare @temp_rowcount int, @temp_error int
declare @OddsSpreadA smallmoney, @oddsstatus nvarchar(15), @oddsautosuspend bit
declare @bdiffbalance float,@brisk float,@bstakerange float,@bcom1 float,@bcom2 float
declare @ODDS_GAP float

declare @tmp_ugroup varchar(10)
SET @tmp_ugroup = @ugroup
-- New Method : Dual Odds - ignore odds convertion/odds group
IF @OriginalOdds IS NOT NULL SELECT @sitetype = '', @ugroup = 'a'

Declare @OddsMode tinyint
-- @OddsMode = 1 : Add points
IF @sitetype IN ('ADD' , 'DECIADD')
	SET @OddsMode = 1
ELSE
	SET @OddsMode = 0


select @transid=0
--------all need to insert to bettrans variable select  
select 
	@matchid=matchid,
	@newoffersetup=odds.newoffersetup,
	@liveindicator=odds.liveindicator,
	@oddslivehomescore=odds.livehomescore,
	@oddsliveawayscore=odds.liveawayscore,
	@bettype=bettype,
	@oddsstatus=oddsstatus,
	@ohdp1=odds.hdp1,
	@ohdp2=odds.hdp2,
	@OddsSpreadA = odds.oddsspreada,
	@oddsautosuspend=IsNull(odds.autosuspend,0),
	@bdiffbalance=odds.diffbalance,
	@brisk		= CASE @betteam WHEN 'h' THEN odds.risk ELSE -odds.risk2 END,
	@bstakerange= CASE @betteam WHEN 'h' THEN odds.stakerange ELSE -odds.stakerange2 END,
	@bcom1		= CASE @betteam WHEN 'h' THEN odds.gapodds1 ELSE odds.com1 END,
	@bcom2		= CASE @betteam WHEN 'h' THEN odds.gapodds2 ELSE odds.com2 END,

	@godds=
	(case @OddsMode
	WHEN 0 THEN CASE
		when @ugroup='a' and @betteam='h' then odds1a 
		when @ugroup='b' and @betteam='h' then odds1b 
		when @ugroup='c' and @betteam='h' then odds1c 
		when @ugroup='d' and @betteam='h' then odds1d
		when @ugroup='e' and @betteam='h' then odds1e
		when @ugroup='f' and @betteam='h' then odds1f 
		when @ugroup='hka' and @betteam='h' then odds1hka
		when @ugroup='hkb' and @betteam='h' then odds1hkb
		when @ugroup='hkc' and @betteam='h' then odds1hkc
		when @ugroup='hkd' and @betteam='h' then odds1hkd
		when @ugroup='hke' and @betteam='h' then odds1hke
		when @ugroup='hkf' and @betteam='h' then odds1hkf

		when @ugroup='a' and @betteam='a' then odds2a 
		when @ugroup='b' and @betteam='a' then odds2b
		when @ugroup='c' and @betteam='a' then odds2c 
		when @ugroup='d' and @betteam='a' then odds2d
		when @ugroup='e' and @betteam='a' then odds2e 
		when @ugroup='f' and @betteam='a' then odds2f 
		when @ugroup='hka' and @betteam='a' then odds2hka
		when @ugroup='hkb' and @betteam='a' then odds2hkb
		when @ugroup='hkc' and @betteam='a' then odds2hkc
		when @ugroup='hkd' and @betteam='a' then odds2hkd
		when @ugroup='hke' and @betteam='a' then odds2hke
		when @ugroup='hkf' and @betteam='a' then odds2hkf
		END
	WHEN 1 THEN CASE
		when @ugroup in ('a','hka') and @betteam='h' then odds1a 
		when @ugroup in ('b','hkb') and @betteam='h' then odds1b 
		when @ugroup in ('c','hkc') and @betteam='h' then odds1c 
		when @ugroup in ('d','hkd') and @betteam='h' then odds1d 
		when @ugroup in ('e','hke') and @betteam='h' then odds1e 
		when @ugroup in ('f','hkf') and @betteam='h' then odds1f 
	
		when @ugroup in ('a','hka') and @betteam='a' then odds2a 
		when @ugroup in ('b','hkb') and @betteam='a' then odds2b 
		when @ugroup in ('c','hkc') and @betteam='a' then odds2c 
		when @ugroup in ('d','hkd') and @betteam='a' then odds2d 
		when @ugroup in ('e','hke') and @betteam='a' then odds2e 
		when @ugroup in ('f','hkf') and @betteam='a' then odds2f
		END
	ELSE
		0
	END )

from 
	dbo.odds with (nolock)
where 
	dbo.odds.oddsid=@oddsid
	and CASE @betfrom
	WHEN 'p' THEN 'running'
	WHEN 'h' THEN 'running'
	ELSE dbo.odds.oddsstatus END = 'running'

set @temp_rowcount=@@rowcount
set @temp_error=@@error

--- SPECIAL SITE
IF @sitetype IN ('INDO')
	--- CONVERT TO INDO ODDS
	SET @godds = -(round( 1/@godds ,2,1))
	--- CONVERT TO INDO ODDS : END
ELSE IF @sitetype IN ('ADD', 'DECIADD')
BEGIN
	--- CONVERT TO NEW ODDS (add spread)
	Declare @spread float	SET @spread=@addspread/2
	--SELECT @spread=spreada/2 from dbo.site with (nolock) where site=@site

	set @godds=round(@godds-@spread/100,3)
	
	IF (@godds<-1) SET @godds=2+@godds
	
	if @ugroup in ('hka','hkb','hkc','hkd','hke','hkf') and (@godds < 0)
	   set @godds = case when @godds < -0.75 then 2 + @godds else -1/@godds end
	--- CONVERT TO new odds : END
END
--- SPECIAL SITE : END

--- Convert HK odds to be 2 decimal
if @ugroup in ('hka','hkb','hkc','hkd','hke','hkf')
BEGIN
	Declare @todds smallmoney
	SET @todds = ROUND(@godds,2)
	IF @todds > @godds
		SET @godds = @todds - 0.01
	ELSE
		SET @godds = @todds
END
--- Convert HK odds to be 2 decimal : END

if (@temp_rowcount=0)
	set @transid=-1 --matchclose	
if (@temp_error<>0)
	set @transid=-1 --close	
--if (round(@odds,3)<>round(@godds,3))
IF @betfrom NOT IN ('p','h')
BEGIN
	Declare @AcceptGaps smallmoney -- define what is the changed value to be acceptable.
	if @ugroup in ('hka','hkb','hkc','hkd','hke','hkf')
		SET @AcceptGaps = 0.013
	ELSE
		SET @AcceptGaps = 0.003

	if ABS((round( CASE WHEN @OriginalOdds IS NULL THEN @odds ELSE @OriginalOdds END ,3)-round(@godds,3))) > @AcceptGaps
	BEGIN
		set @transid=-2 --- odds change 
		set @new_odds = round(@godds,3)
	END
	if round(@ohdp1-@ohdp2,3) <> round(@hdp1-@hdp2,3)
		set @transid=-2 --- hdp change 
	if (@oddslivehomescore <> @livehomescore) OR (@oddsliveawayscore <> @liveawayscore)
		set @transid=-2 --- score change 
END

SET @ugroup = @tmp_ugroup -- return value to @ugroup

------ START BETTING PROCEDURE
Declare @betactual_stake money,
	@zstake money, @betstake money, @tpositiontaking smallmoney, @betactualrate float
SELECT
	@zstake=@stake, @betstake = @stake, 
	@tpositiontaking = @apositiontaking + @mpositiontaking + @spositiontaking,
	@betactualrate = @actualrate, @betactual_stake = CASE WHEN @odds < 0 THEN @stake*abs(@odds) ELSE @stake END,
	@matchdate = @eventdate

if (@transid=0)
begin

declare @odds1a float,@odds2a float,@odds1b float,@odds2b float,@odds1c float,@odds2c float
declare @odds1d float,@odds2d float,@odds1e float,@odds2e float,@odds1f float,@odds2f float
declare @odds1hka float,@odds2hka float,@odds1hkb float,@odds2hkb float,@odds1hkc float,@odds2hkc float
declare @odds1hkd float,@odds2hkd float,@odds1hke float,@odds2hke float,@odds1hkf float,@odds2hkf float
declare @diffbalance float,@changetime datetime, @hometotal float,@awaytotal float, @oddsstatusnew nvarchar(15)
declare @status nvarchar(50)

if (@betfrom NOT IN ('p','h')) AND (@liveindicator=1)
begin		
	set @status='waiting'
	if (@newoffersetup=1) set @status='running'
end	
else
begin
	set @status='running'
end 


if @betteam='h' 
BEGIN
----auto bookie update ----
	select 
		@odds1a=(case when odds1a-o.gapodds1<-1 then   2-abs(odds1a-o.gapodds1)  else odds1a-o.gapodds1 end),
		@odds2a=(case when odds2a+o.gapodds1> 1 then -(2-abs(odds2a+o.gapodds1)) else odds2a+o.gapodds1 end),
		@odds1b=(case when odds1b-o.gapodds1<-1 then   2-abs(odds1b-o.gapodds1)  else odds1b-o.gapodds1 end),
		@odds2b=(case when odds2b+o.gapodds1> 1 then -(2-abs(odds2b+o.gapodds1)) else odds2b+o.gapodds1 end),
		@odds1c=(case when odds1c-o.gapodds1<-1 then   2-abs(odds1c-o.gapodds1)  else odds1c-o.gapodds1 end),
		@odds2c=(case when odds2c+o.gapodds1> 1 then -(2-abs(odds2c+o.gapodds1)) else odds2c+o.gapodds1 end),
	
		@odds1d=(case when odds1d-o.gapodds1<-1 then   2-abs(odds1d-o.gapodds1)  else odds1d-o.gapodds1 end),
		@odds2d=(case when odds2d+o.gapodds1> 1 then -(2-abs(odds2d+o.gapodds1)) else odds2d+o.gapodds1 end),
		@odds1e=(case when odds1e-o.gapodds1<-1 then   2-abs(odds1e-o.gapodds1)  else odds1e-o.gapodds1 end),
		@odds2e=(case when odds2e+o.gapodds1> 1 then -(2-abs(odds2e+o.gapodds1)) else odds2e+o.gapodds1 end),
		@odds1f=(case when odds1f-o.gapodds1<-1 then   2-abs(odds1f-o.gapodds1)  else odds1f-o.gapodds1 end),
		@odds2f=(case when odds2f+o.gapodds1> 1 then -(2-abs(odds2f+o.gapodds1)) else odds2f+o.gapodds1 end),
		
		@odds1hka=(case when odds1a-o.gapodds1<-1 then 2-abs(odds1a-o.gapodds1) else case when odds1a-o.gapodds1<0 then round(1/abs(odds1a-o.gapodds1),2,1) else odds1a-o.gapodds1 end end),
		@odds2hka=(case when odds2a+o.gapodds1> 1 then round(1/abs(-(2-abs(odds2a+o.gapodds1))),2,1) else case when odds2a+o.gapodds1<0 then round(1/abs(odds2a+o.gapodds1),2,1) else odds2a+o.gapodds1 end end),
		@odds1hkb=(case when odds1b-o.gapodds1<-1 then 2-abs(odds1b-o.gapodds1) else case when odds1b-o.gapodds1<0 then round(1/abs(odds1b-o.gapodds1),2,1) else odds1b-o.gapodds1 end end),
		@odds2hkb=(case when odds2b+o.gapodds1> 1 then round(1/abs(-(2-abs(odds2b+o.gapodds1))),2,1) else case when odds2b+o.gapodds1<0 then round(1/abs(odds2b+o.gapodds1),2,1) else odds2b+o.gapodds1 end end),
		@odds1hkc=(case when odds1c-o.gapodds1<-1 then 2-abs(odds1c-o.gapodds1) else case when odds1c-o.gapodds1<0 then round(1/abs(odds1c-o.gapodds1),2,1) else odds1c-o.gapodds1 end end),
		@odds2hkc=(case when odds2c+o.gapodds1> 1 then round(1/abs(-(2-abs(odds2c+o.gapodds1))),2,1) else case when odds2c+o.gapodds1<0 then round(1/abs(odds2c+o.gapodds1),2,1) else odds2c+o.gapodds1 end end),
		
		@odds1hkd=(case when odds1d-o.gapodds1<-1 then 2-abs(odds1d-o.gapodds1) else case when odds1d-o.gapodds1<0 then round(1/abs(odds1d-o.gapodds1),2,1) else odds1d-o.gapodds1 end end),
		@odds2hkd=(case when odds2d+o.gapodds1> 1 then round(1/abs(-(2-abs(odds2d+o.gapodds1))),2,1) else case when odds2d+o.gapodds1<0 then round(1/abs(odds2d+o.gapodds1),2,1) else odds2d+o.gapodds1 end end),
		@odds1hke=(case when odds1e-o.gapodds1<-1 then 2-abs(odds1e-o.gapodds1) else case when odds1e-o.gapodds1<0 then round(1/abs(odds1e-o.gapodds1),2,1) else odds1e-o.gapodds1 end end),
		@odds2hke=(case when odds2e+o.gapodds1> 1 then round(1/abs(-(2-abs(odds2e+o.gapodds1))),2,1) else case when odds2e+o.gapodds1<0 then round(1/abs(odds2e+o.gapodds1),2,1) else odds2e+o.gapodds1 end end),
		@odds1hkf=(case when odds1f-o.gapodds1<-1 then 2-abs(odds1f-o.gapodds1) else case when odds1f-o.gapodds1<0 then round(1/abs(odds1f-o.gapodds1),2,1) else odds1f-o.gapodds1 end end),
		@odds2hkf=(case when odds2f+o.gapodds1> 1 then round(1/abs(-(2-abs(odds2f+o.gapodds1))),2,1) else case when odds2f+o.gapodds1<0 then round(1/abs(odds2f+o.gapodds1),2,1) else odds2f+o.gapodds1 end end),
		
		@diffbalance=o.diffbalance,
		@changetime=o.changetime,
		@oddsstatusnew=(case when abs(odds1a)<minodds then 'closed' else oddsstatus end),
		@hometotal=(@zstake*(1-(@tpositiontaking))*@virtualrate*case when abs(@odds)>1 then abs(@odds) else 1 end ),
		@awaytotal=0,
		@ODDS_GAP = o.gapodds1
	from
	dbo.odds with (rowlock),
	(select 
		(case
			when @betfrom IN ('p','h')
				then 0 
	     	when @stake*(1-@tpositiontaking)*@virtualrate+IsNull(diffbalance, 0) >=risk+((stakerange-risk)/2)
				then gapodds1
			when @stake*(1-@tpositiontaking)*@virtualrate+IsNull(diffbalance, 0) >=risk
				then gapodds2
	     	else
				0
			end) gapodds1,
		(case
			when @betfrom IN ('p','h')
				then 0 --  @stake*(1-@tpositiontaking)*@actualrate
	     	when @stake*(1-@tpositiontaking)*@virtualrate+IsNull(diffbalance, 0) >=risk+((stakerange-risk)/2)
				then 0
	     	when @stake*(1-@tpositiontaking)*@virtualrate+IsNull(diffbalance, 0) >=risk
				then 0
	     	else
				@stake*(1-@tpositiontaking)*@virtualrate
	    	end) diffbalance,
		(case
			when @betfrom IN ('p','h')
				then changetime 
	     	when @stake*(1-@tpositiontaking)*@virtualrate+IsNull(diffbalance, 0) >=risk+((stakerange-risk)/2)
				then CURRENT_TIMESTAMP --dateadd(ss,120,getdate())
	     	when @stake*(1-@tpositiontaking)*@virtualrate+IsNull(diffbalance, 0) >=risk
				then CURRENT_TIMESTAMP --dateadd(ss,120,getdate())
	     	else
				changetime --getdate()
	    	end) changetime,
		oddsid
		
	from dbo.odds with (rowlock)
	-----check all the variable -----
	where 
		dbo.odds.oddsid=@oddsid 
		) o 
	where o.oddsid=odds.oddsid 

	set @temp_error =@@error

END
ELSE
BEGIN
----auto bookie update ----
	select 
		@odds2a=(case when odds2a-o.gapodds1<-1 then   2-abs(odds2a-o.gapodds1)  else odds2a-o.gapodds1 end),
		@odds1a=(case when odds1a+o.gapodds1> 1 then -(2-abs(odds1a+o.gapodds1)) else odds1a+o.gapodds1 end),
		@odds2b=(case when odds2b-o.gapodds1<-1 then   2-abs(odds2b-o.gapodds1)  else odds2b-o.gapodds1 end),
		@odds1b=(case when odds1b+o.gapodds1> 1 then -(2-abs(odds1b+o.gapodds1)) else odds1b+o.gapodds1 end),
		@odds2c=(case when odds2c-o.gapodds1<-1 then   2-abs(odds2c-o.gapodds1)  else odds2c-o.gapodds1 end),
		@odds1c=(case when odds1c+o.gapodds1> 1 then -(2-abs(odds1c+o.gapodds1)) else odds1c+o.gapodds1 end),
	
		@odds2d=(case when odds2d-o.gapodds1<-1 then   2-abs(odds2d-o.gapodds1)  else odds2d-o.gapodds1 end),
		@odds1d=(case when odds1d+o.gapodds1> 1 then -(2-abs(odds1d+o.gapodds1)) else odds1d+o.gapodds1 end),
		@odds2e=(case when odds2e-o.gapodds1<-1 then   2-abs(odds2e-o.gapodds1)  else odds2e-o.gapodds1 end),
		@odds1e=(case when odds1e+o.gapodds1> 1 then -(2-abs(odds1e+o.gapodds1)) else odds1e+o.gapodds1 end),
		@odds2f=(case when odds2f-o.gapodds1<-1 then   2-abs(odds2f-o.gapodds1)  else odds2f-o.gapodds1 end),
		@odds1f=(case when odds1f+o.gapodds1> 1 then -(2-abs(odds1f+o.gapodds1)) else odds1f+o.gapodds1 end),
		
		@odds2hka=(case when odds2a-o.gapodds1<-1 then 2-abs(odds2a-o.gapodds1) else case when odds2a-o.gapodds1<0 then round(1/abs(odds2a-o.gapodds1),2,1) else odds2a-o.gapodds1 end end),
		@odds1hka=(case when odds1a+o.gapodds1> 1 then round(1/abs(-(2-abs(odds1a+o.gapodds1))),2,1) else case when odds1a+o.gapodds1<0 then round(1/abs(odds1a+o.gapodds1),2,1) else odds1a+o.gapodds1 end end),
		@odds2hkb=(case when odds2b-o.gapodds1<-1 then 2-abs(odds2b-o.gapodds1) else case when odds2b-o.gapodds1<0 then round(1/abs(odds2b-o.gapodds1),2,1) else odds2b-o.gapodds1 end end),
		@odds1hkb=(case when odds1b+o.gapodds1> 1 then round(1/abs(-(2-abs(odds1b+o.gapodds1))),2,1) else case when odds1b+o.gapodds1<0 then round(1/abs(odds1b+o.gapodds1),2,1) else odds1b+o.gapodds1 end end),
		@odds2hkc=(case when odds2c-o.gapodds1<-1 then 2-abs(odds2c-o.gapodds1) else case when odds2c-o.gapodds1<0 then round(1/abs(odds2c-o.gapodds1),2,1) else odds2c-o.gapodds1 end end),
		@odds1hkc=(case when odds1c+o.gapodds1> 1 then round(1/abs(-(2-abs(odds1c+o.gapodds1))),2,1) else case when odds1c+o.gapodds1<0 then round(1/abs(odds1c+o.gapodds1),2,1) else odds1c+o.gapodds1 end end),
	
		@odds2hkd=(case when odds2d-o.gapodds1<-1 then 2-abs(odds2d-o.gapodds1) else case when odds2d-o.gapodds1<0 then round(1/abs(odds2d-o.gapodds1),2,1) else odds2d-o.gapodds1 end end),
		@odds1hkd=(case when odds1d+o.gapodds1> 1 then round(1/abs(-(2-abs(odds1d+o.gapodds1))),2,1) else case when odds1d+o.gapodds1<0 then round(1/abs(odds1d+o.gapodds1),2,1) else odds1d+o.gapodds1 end end),
		@odds2hke=(case when odds2e-o.gapodds1<-1 then 2-abs(odds2e-o.gapodds1) else case when odds2e-o.gapodds1<0 then round(1/abs(odds2e-o.gapodds1),2,1) else odds2e-o.gapodds1 end end),
		@odds1hke=(case when odds1e+o.gapodds1> 1 then round(1/abs(-(2-abs(odds1e+o.gapodds1))),2,1) else case when odds1e+o.gapodds1<0 then round(1/abs(odds1e+o.gapodds1),2,1) else odds1e+o.gapodds1 end end),
		@odds2hkf=(case when odds2f-o.gapodds1<-1 then 2-abs(odds2f-o.gapodds1) else case when odds2f-o.gapodds1<0 then round(1/abs(odds2f-o.gapodds1),2,1) else odds2f-o.gapodds1 end end),
		@odds1hkf=(case when odds1f+o.gapodds1> 1 then round(1/abs(-(2-abs(odds1f+o.gapodds1))),2,1) else case when odds1f+o.gapodds1<0 then round(1/abs(odds1f+o.gapodds1),2,1) else odds1f+o.gapodds1 end end),
		
		@diffbalance=o.diffbalance,
		@changetime=o.changetime,
		@oddsstatusnew=(case when abs(odds1b)<minodds then 'closed' else oddsstatus end),
		@hometotal=0,
		@awaytotal=(@zstake*(1-(@tpositiontaking))*@virtualrate*case when abs(@odds)>1 then abs(@odds) else 1 end ),
		@ODDS_GAP = o.gapodds1
	from
	odds with (rowlock),
	(select 
		(case
			when @betfrom IN ('p','h')
				then 0 
	     	when @stake*(1-@tpositiontaking)*@virtualrate-IsNull(diffbalance, 0) >=risk2+((stakerange2-risk2)/2)
				then com1
			when @stake*(1-@tpositiontaking)*@virtualrate-IsNull(diffbalance, 0) >=risk2
				then com2
	     	else
				0
			end) gapodds1,
		(case 
			when @betfrom IN ('p','h')
				then 0 --  -@stake*(1-@tpositiontaking)*@actualrate
	     	when @stake*(1-@tpositiontaking)*@virtualrate-IsNull(diffbalance, 0) >=risk2+((stakerange2-risk2)/2)
				then 0
	     	when @stake*(1-@tpositiontaking)*@virtualrate-IsNull(diffbalance, 0) >=risk2 
				then 0
	     	else
				-@stake*(1-@tpositiontaking)*@virtualrate
	    	end) diffbalance,
		(case 
			when @betfrom IN ('p','h')
				then changetime
	     	when @stake*(1-@tpositiontaking)*@virtualrate-IsNull(diffbalance, 0) >=risk2+((stakerange2-risk2)/2)
				then CURRENT_TIMESTAMP --dateadd(ss,120,getdate())
	     	when @stake*(1-@tpositiontaking)*@virtualrate-IsNull(diffbalance, 0) >=risk2
				then CURRENT_TIMESTAMP --dateadd(ss,120,getdate())
	     	else
				changetime --getdate()
	    	end) changetime,
		oddsid
		
	from dbo.odds with (rowlock)
	-----check all the variable -----
	where 
		dbo.odds.oddsid=@oddsid 
		) o 
	where o.oddsid=dbo.odds.oddsid
	
	set @temp_error =@@error

END

end 

if (@@error=0 and @transid=0 and @temp_error=0)
begin

	declare @grefno bigint select @grefno=100000000000

	IF (@autosuspend = 1) AND (@oddsautosuspend = 1) SET @oddsstatusnew = 'suspend'

	update odds with (rowlock, updlock)
	set 
	odds1a=@odds1a, odds2a=@odds2a,	odds1hka=@odds1hka, odds2hka=@odds2hka,
	odds1b=@odds1b, odds2b=@odds2b,	odds1hkb=@odds1hkb, odds2hkb=@odds2hkb,
	odds1c=@odds1c, odds2c=@odds2c,	odds1hkc=@odds1hkc, odds2hkc=@odds2hkc,
	odds1d=@odds1d, odds2d=@odds2d,	odds1hkd=@odds1hkd, odds2hkd=@odds2hkd,
	odds1e=@odds1e, odds2e=@odds2e,	odds1hke=@odds1hke, odds2hke=@odds2hke,
	odds1f=@odds1f, odds2f=@odds2f,	odds1hkf=@odds1hkf, odds2hkf=@odds2hkf,

	diffbalance=CASE WHEN IsNull(@ODDS_GAP, 0) > 0 THEN 0 ELSE IsNull(diffbalance,0) + IsNull(@diffbalance,0) END,
	changetime=@changetime,
	oddsstatus= 
		CASE
		WHEN @odds1a < 0 AND @odds1a > maxodds THEN 'closed'
		WHEN @odds2a < 0 AND @odds2a > maxodds THEN 'closed'
		WHEN @odds1a > 0 AND @odds1a < minodds THEN 'closed'
		WHEN @odds2a > 0 AND @odds2a < minodds THEN 'closed'
		when  autobookie=0 and @odds1a<>odds1a then 'suspend' 
		ELSE @oddsstatusnew END,
--@oddsstatusnew,
	hometotal=hometotal+@hometotal,
	awaytotal=awaytotal+@awaytotal
	where oddsid=@oddsid

	EXEC dbo.Dot_Member_BetCreditChange @custid, @betactual_stake

	insert bettrans 
	( 
	custid, oddsid, oddsspread, hdp1, hdp2,odds, stake, status, livehomescore, liveawayscore, liveindicator, betfrom, 
	betteam, creator, refno, tpositiontaking, apositiontaking, mpositiontaking, spositiontaking,
	playerdiscount, discount, adiscount, sdiscount, actualrate, virtualrate,
	matchid, recommend, mrecommend, srecommend, scomm, swinlost,
	bettype, currency, actual_stake, winlostdate, transdesc, ip, Username, CurrencyName, betcheck) 
	values 
	(
	@custid ,@oddsid, 
	0, @hdp1, @hdp2,@odds,
	@betstake, @status,  @livehomescore, @liveawayscore,
	@liveindicator, @betfrom, @betteam,  @creator, @grefno ,
	@tpositiontaking, @apositiontaking, @mpositiontaking, @spositiontaking,
	@playerdiscount, @adiscount, @mdiscount, @sdiscount, @betactualrate, @virtualrate,
	@matchid,@recommend,@mrecommend,@srecommend, 0, 0,
	@bettype,@curr, @betactual_stake, 
	@matchdate, @http_ref, @remote_add, @Username, @CurrencyName,
	'df(' + convert(nvarchar(20), CAST(IsNull(@bdiffbalance,-55) as money)) + ')(' + convert(nvarchar(10), IsNull(@brisk,-55)) + '/' + convert(nvarchar(10), IsNull(@bstakerange,-55)) + '/' + convert(nvarchar(10), IsNull(@bcom1,-1)) + ':' + convert(nvarchar(10), IsNull(@bcom2,-1)) + ')'
	); select @transid=scope_identity()

	--COMMIT TRANSACTION

	-- MoneyLine update odds/spread
/*
	IF @bettype = 20 AND IsNull(@ODDS_GAP, 0) > 0 -- odds changed
	BEGIN
		declare @MLSpread smallmoney, @newodds smallmoney
		SET @newodds = CASE @betteam WHEN 'h' THEN @odds1a ELSE @odds2a END

		SELECT @MLSpread = pointSpread 
			from dbo.Dot_Admin_MoneyLineScale with (nolock)
			where startSpread = @OddsSpreadA and (@newodds between downPrice and upPrice)

		IF @MLSpread <> @OddsSpreadA
		BEGIN
			Declare @n1a float, @n2a float, @n1hka float, @n2hka float,
					@n1f float, @n2f float
			Declare @diffspread smallmoney, @osf float
			SET @diffspread = @OddsSpreadA - @MLSpread

			UPDATE odds with (rowlock, updlock) 
			SET
			oddsspreada = @MLSpread,
			oddsspreadb = @MLSpread,
			oddsspreadc = @MLSpread,
			oddsspreadd = @MLSpread,
			oddsspreade = @MLSpread,
			@osf = oddsspreadf = oddsspreadf - @diffspread,

			@n1a = odds1a = ROUND(CASE @betteam WHEN 'H' THEN @odds1a ELSE case when @odds2a + @MLSpread > 1 then 2 - @odds2a - @MLSpread else -(@odds2a + @MLSpread) end END, 3),
			@n2a = odds2a = ROUND(CASE @betteam WHEN 'A' THEN @odds2a ELSE case when @odds1a + @MLSpread > 1 then 2 - @odds1a - @MLSpread else -(@odds1a + @MLSpread) end END, 3),

			@n1hka = odds1hka = ROUND(CASE WHEN @n1a > 0 THEN @n1a ELSE -1/@n1a END,3),
			@n2hka = odds2hka = ROUND(CASE WHEN @n2a > 0 THEN @n2a ELSE -1/@n2a END,3),

			odds1b = @n1a, odds2b = @n2a, odds1hkb = @n1hka, odds2hkb = @n2hka,
			odds1c = @n1a, odds2c = @n2a, odds1hkc = @n1hka, odds2hkc = @n2hka,
			odds1d = @n1a, odds2d = @n2a, odds1hkd = @n1hka, odds2hkd = @n2hka,
			odds1e = @n1a, odds2e = @n2a, odds1hke = @n1hka, odds2hke = @n2hka,
		
			@n1f = odds1f = ROUND(CASE WHEN @n1a - (@osf/2) < -1 THEN 2 + @n1a - (@osf/2) ELSE @n1a - (@osf/2) END, 3),
			@n2f = odds2f = ROUND(CASE WHEN @n1f + @osf > 1 THEN 2 - @n1f - @osf ELSE -(@n1f + @osf) END, 3),
			odds1hkf = ROUND(CASE WHEN @n1f > 0 THEN @n1f ELSE -1/@n1f END,3),
			odds2hkf = ROUND(CASE WHEN @n2f > 0 THEN @n2f ELSE -1/@n2f END,3)

			WHERE oddsid = @oddsid
		END
	END
*/

	declare @from nvarchar(50)
	SELECT @from = CASE @betfrom 
		WHEN 'p' THEN 'phone'
		WHEN 'h' THEN 'phone-hedge'
		when 'd' THEN 'deposit'
		WHEN 'w' THEN 'wap'
		WHEN 'i' THEN 'internet'
		ELSE 'unknown (' + @betfrom + ')' END

	Declare @extra nvarchar(50)
	IF @Odds <> @OriginalOdds
		SET @extra = N' (org:' + CONVERT(nvarchar(10),CAST(isnull(@OriginalOdds,0) as float)) + ')'
	ELSE SET @extra = ''

	declare @str nvarchar(500)
	select @str=@from + N' betting custid:' + cast(isnull( @custid,'x') as nvarchar(10)) + N' insert bet oddsid:' +  cast(isnull( @oddsid,'x') as nvarchar(10)) 
		+ N' at ' + CONVERT(nvarchar(10),CAST(isnull(@odds,0) as float)) + '(' + @ugroup + ')' + @extra + ' bet ' + cast(isnull(@betteam,'x') as nvarchar(10))
		+ N' stake:' + CONVERT(nvarchar(50),isnull(@stake,0)) 
		+ N' transid:' +cast(isnull( @transid,'x') as nvarchar(10)) 
		+ N' ip:' + cast(isnull(@remote_add,'x') as nvarchar(16)) 
		+ N' NBC:' + CAST(@BetCredit - @betactual_stake as nvarchar(50)) 
		+ N' (' + CAST(DATEDIFF(millisecond, @StartTime, CURRENT_TIMESTAMP) as nvarchar(50)) + ' ms) ' + @site
	exec logfile @custid, @str

	IF IsNull(@ODDS_GAP, 0) > 0
	BEGIN
		select @str = 'Autobookie_Activated matchid:' + CAST(@matchid as nvarchar(50)) + ' oddsid:' + CAST(@oddsid as nvarchar(50)) + ' bettype:' + CAST(@bettype as nvarchar(20)) + ' betteam:' + @betteam + ' gap:' + CONVERT(nvarchar(10), @ODDS_GAP) + ' odds1:' + CONVERT(nvarchar(10), @odds1a) + ' odds2:' + CONVERT(nvarchar(10), @odds2a)
		exec logfile @custid, @str
	END

	-- Added : (by Joe)
	-- requested by Adrian
	-- 20070501 copy ticket for 6666bp509 to 8RMBJ ( x5 of real value : exchange concern )
	-- 20070929 copy ticket for 6666eu055 to 8rm6666eu055 ( x5 of stake , ignore exchange )
	-- 20071108 copy ticket for 818bp to 8RM818BP ( x1 of real value : exchange concern )
	-- 20071208 copy ticket for 818bp to 8RM818BP ( x0.5 of real value : exchange concern )
	declare @copytransid int, @cAG int, @cMA int, @cSA int
	IF @custid = 8495 AND @betfrom NOT IN ('p','h')
	BEGIN
		SELECT @cAG = recommend, @cMA = mrecommend, @cSA = srecommend, @virtualrate = IsNull(VirtualMultiplier, 1)
		FROM custinfo (nolock) where custid = 379295

		insert bettrans 
		(		custid, oddsid, oddsspread, hdp1, hdp2,odds, stake, status, livehomescore, liveawayscore, liveindicator, betfrom, 
		betteam, creator, refno, tpositiontaking, apositiontaking, mpositiontaking, spositiontaking,
		playerdiscount, discount, adiscount, sdiscount, actualrate, virtualrate,
		matchid, recommend, mrecommend, srecommend, scomm, swinlost,
		bettype, currency, actual_stake, winlostdate, transdesc, ip, Username, CurrencyName, betcheck) 
		values 
		(
		379295 ,@oddsid, 
		0, @hdp1, @hdp2, @odds,
		(@betstake * @betactualrate * 5), @status,  @livehomescore, @liveawayscore,
		@liveindicator, @betfrom, @betteam,  379295, @grefno ,
		0, 0, 0, 0,
		0, 0, 0.00250000, 0.00250000, 1, @virtualrate,
		@matchid, @cAG, @cMA, @cSA, 0, 0,
		@bettype, 2, (@betactual_stake * @betactualrate * 5), 
		@matchdate, 'Copy from 6666bp509 BetID:' + CAST(@transid as nvarchar(50)), '',  '8RMBJ', 'RM', ''
		); select @copytransid=scope_identity()

		select @str=@from + N' betting custid:379295 insert bet oddsid:' +  cast(isnull( @oddsid,'x') as nvarchar(10)) + N' at ' + CONVERT(nvarchar(10),CAST(isnull(@odds,0) as float)) + '(' + @ugroup + ') bet ' + cast(isnull(@betteam,'x') as nvarchar(10))  +  N' stake:' + CONVERT(nvarchar(50),isnull((@stake * @betactualrate * 5),0)) + N' transid:' +cast(isnull( @copytransid,'x') as nvarchar(10)) + ' COPIED'
		exec logfile  379295, @str
	END -- end copy ticket process
	ELSE IF @custid = 606236 AND @betfrom NOT IN ('p','h')
	BEGIN
		SELECT @cAG = recommend, @cMA = mrecommend, @cSA = srecommend, @virtualrate = IsNull(VirtualMultiplier, 1)
		FROM custinfo (nolock) where custid = 642654

		insert bettrans 
		(		custid, oddsid, oddsspread, hdp1, hdp2,odds, stake, status, livehomescore, liveawayscore, liveindicator, betfrom, 
		betteam, creator, refno, tpositiontaking, apositiontaking, mpositiontaking, spositiontaking,
		playerdiscount, discount, adiscount, sdiscount, actualrate, virtualrate,
		matchid, recommend, mrecommend, srecommend, scomm, swinlost,
		bettype, currency, actual_stake, winlostdate, transdesc, ip, Username, CurrencyName, betcheck) 
		values 
		(
		642654 ,@oddsid, 
		0, @hdp1, @hdp2, @odds,
		(@betstake * 1), @status,  @livehomescore, @liveawayscore,
		@liveindicator, @betfrom, @betteam,  642654, @grefno ,
		0, 0, 0, 0,
		0, 0, 0.00250000, 0.00250000, 1, @virtualrate,
		@matchid, @cAG, @cMA, @cSA, 0, 0,
		@bettype, 2, (@betactual_stake * 1), 
		@matchdate, 'Copy from 6666EU055 BetID:' + CAST(@transid as nvarchar(50)), '',  '8RM6666EU055', 'RM', ''
		); select @copytransid=scope_identity()

		select @str=@from + N' betting custid:642654 insert bet oddsid:' +  cast(isnull( @oddsid,'x') as nvarchar(10)) + N' at ' + CONVERT(nvarchar(10),CAST(isnull(@odds,0) as float)) + '(' + @ugroup + ') bet ' + cast(isnull(@betteam,'x') as nvarchar(10))  +  N' stake:' + CONVERT(nvarchar(50),isnull((@stake * 5),0)) + N' transid:' +cast(isnull( @copytransid,'x') as nvarchar(10)) + ' COPIED'
		exec logfile  642654, @str
	END -- end copy ticket process
	ELSE IF @custid = 37415 AND @betfrom NOT IN ('p','h')
	BEGIN
		SELECT @cAG = recommend, @cMA = mrecommend, @cSA = srecommend, @virtualrate = IsNull(VirtualMultiplier, 1)
		FROM custinfo (nolock) where custid = 373790

		insert bettrans 
		(		custid, oddsid, oddsspread, hdp1, hdp2,odds, stake, status, livehomescore, liveawayscore, liveindicator, betfrom, 
		betteam, creator, refno, tpositiontaking, apositiontaking, mpositiontaking, spositiontaking,
		playerdiscount, discount, adiscount, sdiscount, actualrate, virtualrate,
		matchid, recommend, mrecommend, srecommend, scomm, swinlost,
		bettype, currency, actual_stake, winlostdate, transdesc, ip, Username, CurrencyName, betcheck) 
		values 
		(
		373790 ,@oddsid, 
		0, @hdp1, @hdp2, @odds,
		(@betstake * @betactualrate * 0.5), @status,  @livehomescore, @liveawayscore,
		@liveindicator, @betfrom, @betteam,  373790, @grefno ,
		0, 0, 0, 0,
		0, 0, 0.00250000, 0.00250000, 1, @virtualrate,
		@matchid, @cAG, @cMA, @cSA, 0, 0,
		@bettype, 2, (@betactual_stake * @betactualrate * 0.5), 
		@matchdate, 'Copy from 818BP BetID:' + CAST(@transid as nvarchar(50)), '',  '8RM818BP', 'RM', ''
		); select @copytransid=scope_identity()

		select @str=@from + N' betting custid:373790 insert bet oddsid:' +  cast(isnull( @oddsid,'x') as nvarchar(10)) + N' at ' + CONVERT(nvarchar(10),CAST(isnull(@odds,0) as float)) + '(' + @ugroup + ') bet ' + cast(isnull(@betteam,'x') as nvarchar(10))  +  N' stake:' + CONVERT(nvarchar(50),isnull((@stake * @betactualrate * 0.5),0)) + N' transid:' +cast(isnull( @copytransid,'x') as nvarchar(10)) + ' COPIED'
		exec logfile  373790, @str
	END -- end copy ticket process

	IF @betfrom IN ('p','h') EXEC dbo.Task_TotalRecal_Match @matchid, @bettype
end 

select @trans_id = @transid



GO
GRANT EXECUTE ON [dbo].[Dot_Member_AutoBookie1] TO [Dot_Member]