USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Acc_Auto_BetInsertMixParlay]    Script Date: 11/12/2008 09:32:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Acc_Auto_BetInsertMixParlay]
	@custid int,			-- Customer ID
	-- BetInfo ------------------------------------------
	@matchIdInfo varchar(1000),     -- Match ID list
	@oddIdInfo varchar(1000),       -- Odd ID list	
	@betTeamInfo varchar(1000),
	@stake money,     
	-----------------------------------------------------	
	@creator nvarchar(50),
	@NumOfBet int, 			-- in asp code : iCnt = request.form("count")
	@fail bit out,
	@creditcheck nvarchar(10) output,	-- in asp code : creditcheck.asp,
	@ErrMsg nvarchar(500) output,
	@refno bigint out,
	@sporttype tinyint = 0
AS
SET NOCOUNT ON
BEGIN

	declare  @mixodds float, @custid_get int, @betcheck nvarchar(50),@oddValueInfo varchar(1000)
	--Get the latest odds value into @oddValueInfo
	
	CREATE TABLE #temp_odds
	(
		oddsval smallmoney,
		oddsid int,
		betteam varchar(7),
		rank int	
	) 

	Insert into #temp_odds
	Select 0,oid.val,bt.val ,bt.rank
	from dbo.strsplit(@oddIdInfo,',') as oid inner join dbo.strsplit(@betTeamInfo,',') as bt on oid.rank=bt.rank
	
	update #temp_odds set oddsval=dbo.Acc_Auto_GetOddsInfoParlay(oddsid,betteam)
	select @oddValueInfo=''
	
	select @oddValueInfo=@oddValueInfo + cast(o.oddsval as nvarchar( 4000)) + ','
	from #temp_odds o inner join dbo.strsplit(@oddIdInfo,',') oid on oid.rank=o.rank
	if (len(@oddValueInfo)>0)
	    select @oddValueInfo=substring(@oddValueInfo,1,len(@oddValueInfo)-1)      
	
	drop table #temp_odds
	
	--------------------------------------------------------------------------------------------------------------
	
	set @mixodds = 1
	select @mixodds = @mixodds * round(val,2) from dbo.strSplit(@oddValueInfo,',')
	set @fail = 0
	set @ErrMsg = ''

	declare @date datetime 
	set @date = convert(datetime, convert(varchar(20),getdate(),101))

----------------------------------------------------------------------------------------------------------
-- Credit check
----------------------------------------------------------------------------------------------------------
	declare @finalbalance float, @latestbettime datetime
	select @custid_get = null, @creditcheck = '', @finalbalance = 0

	select @custid_get = ci.custid, @finalbalance = isnull(sum(isnull(b.winlost, 0) - isnull(b.actual_stake, 0) + isnull(b.playercomm, 0)), 0) + isnull(ci.Credit, 0)
	from 
		custinfo as ci with (nolock)
		left join bettrans as b with (nolock) on ci.custid=b.custid  
	where ci.custid=  @custid and ci.closed=0 
	group by ci.custid, ci.credit
	
	select @latestbettime=max(transdate)
	from bettrans with (NOLOCK)
	where custid = @custid and bettype=9

	if @latestbettime is not null and @latestbettime>dateadd(ss,-2,getdate())
	begin

		select @ErrMsg = 'Sorry. Odds changed.'				
		set @fail = 1	
		return
	end

	if (@custid_get is null)	
	begin
		set @ErrMsg = 'This customer cannot bet.'		
		set @fail = 1
		return 
	end

	if (@finalbalance - @stake >0)
		set @creditcheck = 'ok'
	else
	begin

		select @ErrMsg = 'Sorry, You are having credit problem. This is due to insufficient fund or you have exceeded your credit limit.'		
		set @creditcheck = 'failed'	
		set @fail = 1	
		return
	end

----------------------------------------------------------------------------------------------------------
-- Get Customer Info
----------------------------------------------------------------------------------------------------------
	declare @recommend int,
		@mrecommend int,
		@srecommend int,
		@actualrate float,
		@virtualrate float,
		@otpositiontaking float,
		@oapositiontaking float,
		@ompositiontaking float,
		@ospositiontaking float,
		@sdiscount float,
		@discount float,
		@adiscount float,
		@playerdiscount float,
		@currency int,
		@MinPayout float,
		@MaxPerMatch money

-------------------------------
--Thien@20080124: Fixing MixParlay Basketball
Select @sporttype = 1
if exists(select 1
	from dbo.strsplit(@matchIdInfo,',') as mi
		inner join match m with (nolock) on mi.val=m.matchid		
	where m.sporttype = 2)
BEGIN
	Select @sporttype = 2
END
--------------------------------
	select 
		@recommend = ci.recommend,
		@mrecommend = ci.mrecommend,
		@srecommend = ci.srecommend,
		@actualrate = exchange.actualrate,
		@virtualrate = exchange.actualrate * IsNull(ci.VirtualMultiplier, 1),
		@oapositiontaking = cs.apositiontaking,
	    	@ompositiontaking = cs.mpositiontaking,
	    	@ospositiontaking = cs.spositiontaking,
		@sdiscount = case when srecommend<=100 then cs.adiscount else cs.sdiscount end,
		@discount = cs.discount ,
		@adiscount = cs.adiscount ,
		@playerdiscount = cs.playerdiscount,
		@currency = ci.currency,
		@minpayout = (case when exchange.minbet<cs.minbet then cs.minbet else exchange.minbet end)/4,
		@MaxPerMatch = ci.maxpermatch
	from 
		custinfo as ci with (nolock) 
		inner join custsetting as cs with (nolock) on ci.custid = cs.custid and cs.bettype=9 and cs.sporttype=@sporttype
		inner join  exchange with (nolock) on ci.currency=exchange.exchangeid 
	where ci.custid=@custid

/*
EXTRA CONDITION
2008-04-18 (wan) : Denied all bets from listed agent
*/
IF @mrecommend = 43803
begin
	select @fail = 1
	select @ErrMsg = 'Odds changed 1.'		
	return
end	
/*
EXTRA CONDITION : END
*/

----------------------------------------------------------------------------------------------------------
-- Check Before Inserting Bet List to bettransm
----------------------------------------------------------------------------------------------------------
--begin tran


---------------------- Check whether include this ticket will exceed max per match -----------------------------
Declare @RunningStake money
SELECT @RunningStake = SUM(stake) FROM bettrans (nolock) WHERE bettype = 9 AND custid = @custid AND ruben = 0
-- System Maximum is 100k RM
IF IsNull(@MaxPerMatch, 0) * @actualrate > 100000 SET @MaxPerMatch = 100000 * @actualrate
IF (IsNull(@RunningStake, 0) + @Stake) > IsNull(@MaxPerMatch, 0)
begin
	select @fail = 1
	select @ErrMsg = 'Over max-per-match'
	return
end	

---------------------- Check whether matchs and odds closed ----------------------------------------------------

if(exists(select match.matchid
	      from match with (nolock) inner join dbo.strSplit(@matchIdInfo,',') as m on match.matchid = m.val 
			 inner join dbo.strSplit(@oddIdInfo,',') as o on m.rank = o.rank
			 inner join odds on o.val=odds.oddsid
	      where match.eventstatus<>'running' or odds.oddsstatus<>'running' or 
		    match.kickofftime<getdate() or odds.liveindicator=1 or match.multiple=0))
	begin
		select @fail = 1
		select @ErrMsg = 'This match was closed'
		return
	end	
if exists(
	select 1
	from dbo.strSplit(@matchIdInfo,',') as m left join match with (nolock) on match.matchid = m.val 
	group by m.val
	having count(m.val)>1 or count(match.matchid) =0
)
	
	begin
		select @fail = 1
		select @ErrMsg = 'Invalid match combination.'
		return
	end	

if exists(
	select 1
	from dbo.strSplit(@oddIdInfo,',') as o left join odds with (nolock) on odds.oddsid = o.val 
	group by o.val
	having count(o.val)>1 or count(odds.oddsid) =0
)
	
	begin
		select @fail = 1
		select @ErrMsg = 'Invalid odds combination.'
		return
	end	

if exists(
	select 1
	from dbo.strSplit(@oddIdInfo,',') as o inner join odds with (nolock) on odds.oddsid = o.val inner join dbo.strSplit(@betteamInfo,',') as bt on bt.rank = o.rank
	where 
		NOT (
		(odds.bettype IN (1,2,3,7,8,12,17,18,20) AND bt.val in ('h','a')) OR
		(odds.bettype in (5,15) AND bt.val in ('1','x','2')) OR
		(odds.bettype in (16, 14) AND bt.val in ('1:1','1:2','1:0','2:1','2:2','2:0','0:1','0:2','0:0')) OR
		(odds.bettype = 6 AND bt.val in ('0-1','2-3','4-6','7-over')) OR
		(odds.bettype = 4 AND bt.val in ('0:0','0:1','0:2','0:3','0:4','0:5',
			'1:0','1:1','1:2','1:3','1:4',
			'2:0','2:1','2:2','2:3','2:4',
			'3:0','3:1','3:2','3:3','3:4',
			'4:0','4:1','4:2','4:3','4:4','5:0')) OR
		(odds.bettype IN (9,10))
))
	
	begin
		select @fail = 1
		select @ErrMsg = 'Invalid bet-team.'
		return
	end	
---------------------- Check MaxBet and MinBet -------------------------------------------------------

declare @MaxPayout float, @BetAmount float,@MaxOdds float

select @MaxPayout = VValue from SystemSettings with (nolock) where VName = 'MMaxPayout'

if (@stake < @MinPayout )
begin
	select @fail = 1
	select @ErrMsg = 'The stake is less than the minimum bet allowed {' + convert(varchar(30), @MinPayout) + N'.'	
	return
end

if (@stake*@actualrate*@mixodds > @MaxPayout )
begin
	select @fail = 1
	select @ErrMsg = 'The stake exceeded maximum payout.' 				
	rollback tran
	return
end		

---------------------- Check for odd value changed ----------------------------------------------------
declare @cnt int
select @cnt=count(*)
from dbo.strsplit(@matchIdInfo,',') as m
inner join dbo.strsplit(@oddIdInfo,',') as o on m.rank=o.rank
inner join dbo.strsplit(@oddValueInfo,',') as ov on m.rank=ov.rank
inner join dbo.strsplit(@betTeamInfo,',') as b on m.rank=b.rank
inner join odds on odds.oddsid=convert(int,o.val)
where round(ov.val,2) = round((case replace(lower(b.val),'''','') 	when 'h' then 1+odds1hkf		when 'a' then 1+odds2hkf
								when '1' then Com1		when '2' then Com2	when 'X' then ComX
								when '0-1' then cs00		when '2-3' then cs01	when '4-6' then cs10	when '7-over' then cs11

								--Thien@20080122: Add HTFT, use same as CS 1:1; 2:1
								/*
								when '11' then cs11		when '12' then cs12	when '10' then cs10
								when '21' then cs21		when '22' then cs22	when '20' then cs20
								when '01' then cs01		when '02' then cs02	when '00' then cs00
								*/
								--Vinh@20071126: add correct score
								when '0:0' then cs00	when '0:1' then cs01	when '0:2' then cs02	when '0:3' then cs03	when '0:4' then cs04	when '0:5' then cs05
								when '1:0' then cs10	when '1:1' then cs11	when '1:2' then cs12	when '1:3' then cs13	when '1:4' then cs14		
								when '2:0' then cs20	when '2:1' then cs21	when '2:2' then cs22	when '2:3' then cs23	when '2:4' then cs24
								when '3:0' then cs30	when '3:1' then cs31	when '3:2' then cs32	when '3:3' then cs33	when '3:4' then cs34
								when '4:0' then cs40	when '4:1' then cs41	when '4:2' then cs42	when '4:3' then cs43	when '4:4' then cs44
								when '5:0' then cs50

		end),2)

if (@cnt <> @NumOfBet)
begin
	select @fail = 1
	set @ErrMsg = 'Odds changed 2.'			
	return
end	

BEGIN TRANSACTION
	declare @refn int
	UPDATE ref with (rowlock,updlock) SET @refn=refno=refno+1  WHERE  refid='refno'
	set @refno = @refn + 100000000000
COMMIT TRANSACTION


BEGIN TRANSACTION
	----------------------- Insert Bet Infomation into table Bettransm ---------------------------------

	insert INTO bettransm (custid , oddsid , hdp1 , hdp2 , odds , betteam , stake ,
		status,refno,creator, tpositiontaking,apositiontaking,mpositiontaking,
		discount,playerdiscount,adiscount,actualrate,comstatus,	matchid,matchdate, bettype) 
	--Thien@13-Dec-2007: Store @hdp1 = left(@betteam, 1), @hdp2 = right(@betteam, 1) for Correct Score, 20080122: HTFT 
	select @custid, o.val as oddsid, case when bettype in (4,16) then left(replace(lower(b.val),'''',''), 1) else isnull(odds.hdp1,0.0) end,
		case when bettype in (4,16) then right(replace(lower(b.val),'''',''), 1) else isnull(odds.hdp2,0.0) end, convert(smallmoney,ov.val) as odds, replace(lower(b.val),'''',''), 
		@stake, 'running', @refno, @creator, @otpositiontaking, @oapositiontaking, @ompositiontaking,
		@discount , @playerdiscount , @adiscount , @actualrate , @refno , m.val, match.eventdate, odds.bettype

	from dbo.strsplit(@matchIdInfo,',') as m
	inner join dbo.strsplit(@oddIdInfo,',') as o on m.rank=o.rank
	inner join dbo.strsplit(@oddValueInfo,',') as ov on m.rank=ov.rank
	inner join dbo.strsplit(@betteamInfo,',') as b on m.rank=b.rank
	inner join odds on odds.oddsid=convert(int,o.val)
	inner join match on match.matchid = convert(int,m.val)

	-------------------------------------- Check Error -----------------------------------------------

	if (@@rowcount =0 or @@error <> 0)
	begin
		select @fail = 1
		CLOSE CUR_BetList
		DEALLOCATE CUR_BetList
			set @ErrMsg = 'Betting transaction is failed. Please try again...'		
		rollback tran
		return
	end
	select @otpositiontaking = isnull(@ospositiontaking, 0) + isnull(@ompositiontaking, 0) + isnull(@oapositiontaking, 0)
	if (@NumOfBet > 1 )
	begin

		----------------- Insert into table Bettrans --------------------------------------
		select @betcheck = 'm'+convert(varchar(20), @NumOfBet)
		insert bettrans (custid,oddsid,hdp1,hdp2,odds,betteam,stake,status,
			refno,creator, tpositiontaking,apositiontaking,mpositiontaking,
			discount,playerdiscount,adiscount,actualrate,virtualrate,comstatus,matchid,
			winlostdate,recommend,mrecommend,bettype, currency, srecommend, sdiscount, spositiontaking, actual_stake, betcheck)  		
		select @custid, '0', 0.0, 0.0,
			@mixodds, 'a', @stake, 'running',
			@refno, @creator, @otpositiontaking, @oapositiontaking, @ompositiontaking,
			@discount ,@playerdiscount ,@adiscount ,@actualrate ,@virtualrate, 'm',0,
			@date,@recommend ,@mrecommend ,9, @currency,  @srecommend, @sdiscount, @ospositiontaking, @stake, @betcheck
	
		------------------------ Check Error -----------------------------------------------

		if (@@rowcount =0 or @@error <> 0)
		begin
			select @fail = 1
			set @ErrMsg = 'Betting transaction is failed. Please try again...'
			rollback transaction
			return
		end
	end
	else	
	begin
		select @fail = 1
	end
	if (@fail = 1)
	begin
		rollback tran	
	end
	else
	begin
		commit tran
	end
END

GO
GRANT EXECUTE ON [dbo].[Acc_Auto_BetInsertMixParlay] TO [Dot_Member]
GO