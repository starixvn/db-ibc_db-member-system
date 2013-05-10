ALTER PROCEDURE [dbo].[Dot_BetInsMixParlay]
	@custid int,			-- Customer ID
	-- BetInfo ------------------------------------------
	@matchIdInfo varchar(1000),     -- Match ID list
	@oddIdInfo varchar(1000),       -- Odd ID list
	@oddValueInfo varchar(1000),    -- Odd's value list
	@OrgValueInfo varchar(1000),    -- Original Odd's value list
	@betTeamInfo varchar(1000),     -- Betted team list
	-----------------------------------------------------
	@stake float,                   -- Stake
	@creator nvarchar(50),
	@NumOfBet int, 			-- in asp code : iCnt = request.form("count")
	@BetFrom nvarchar(1)='i',
	@language nvarchar(10),
	@BET_IP nvarchar(20),
	@oddstype tinyint = 1,
	@fail bit output,
	@creditcheck nvarchar(10) output,	-- in asp code : creditcheck.asp,
	@ErrMsg nvarchar(500) output,
	@refno bigint output
AS
/*	
Task: main SP for Place Bet Mix Parlay

History:
	- 20101026@Thien: Apply new Mix-Sport setting
	- 20110305@Thien: to add more check: number of combination must be greater than 2	
		
*/
SET NOCOUNT ON
BEGIN

	declare  @mixodds float, @custid_get int, @betcheck nvarchar(50)
	set @mixodds = 1
	select @mixodds = @mixodds * round(val,2) from dbo.strSplit(@oddValueInfo,',')
	set @fail = 0
	set @ErrMsg = ''

	declare @date datetime 
	set @date = convert(datetime, convert(varchar(20),getdate(),101))
	
	declare @cnt int
    declare @transid bigint 
    set @transid = 0
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

		select @ErrMsg = case @Language 
				when 'E' then 'Sorry. Odds changed.'
				when 'J' then N'Sorry. Odds changed.'
				when 'CS' then N'Sorry. Odds changed.'
				else N'Sorry. Odds changed.'
				end
		set @fail = 1 
		return
	end

	if (@custid_get is null)	
	begin

		if (@language = 'E') 
			set @ErrMsg = 'This customer cannot bet.'
		else 
			set @ErrMsg = 'This customer cannot bet.'
		set @fail = 1 
		return 
	end

	if (@finalbalance - @stake >= 0)
		set @creditcheck = 'ok'
	else
	begin

		select @ErrMsg = case @Language 
				when 'E' then 'Sorry, You are having credit problem. This is due to insufficient fund or you have exceeded your credit limit.'
				when 'J' then N'ベットポイントはベット可能Ptsより多きため受付けられません。'
				when 'CS' then N'Sorry, You are having credit problem. This is due to insufficient fund or you have exceeded your credit limit.'
				else N'Sorry, You are having credit problem. This is due to insufficient fund or you have exceeded your credit limit.'
				end
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
		@MaxPerMatch money,
		@reject bit,
		@username nvarchar(50),
		@CurrencyName nvarchar(10),
		@SettingSporttype tinyint,
		@Maxsporttype tinyint

-------------------------------------------------------------
			---Apply new Mix-Sport setting---
---------------------------VVVV------------------------------
--For Mix Parlay tickets that players bet on different sports or any single sport except Soccer,
--then Mix Sports Parlay setting will be applied. 
--For Mix Parlay tickets of that players bet on Soccer only, please refer to Soccer Mix Parlay setting.

select @Maxsporttype = max(sporttype)
from dbo.strsplit(@matchIdInfo,',') as mi
	inner join match m with (nolock) on mi.val=m.matchid

IF @Maxsporttype > 1	 
	SET @SettingSporttype = 99
ELSE
	SET @SettingSporttype = 1
------------------------^^^^^-------------------------------
	select
		@username = ci.username,
		@recommend = ci.recommend,
		@mrecommend = ci.mrecommend,
		@srecommend = ci.srecommend,
		@actualrate = exchange.actualrate,
		--@virtualrate = exchange.actualrate * IsNull(ci.VirtualMultiplier, 1),
		@virtualrate = exchange.actualrate, ---- 2009-3-9(Michael): withdraw virtual currency on mix parlay, correct score & total goal.(Vivi)	
		@oapositiontaking = cs.apositiontaking,
	    @ompositiontaking = cs.mpositiontaking,
	    @ospositiontaking = case when srecommend <= 100 then 0 else cs.spositiontaking end,
		@sdiscount = case when srecommend<=100 then cs.adiscount else cs.sdiscount end,
		@discount = cs.discount ,
		@adiscount = cs.adiscount ,
		@playerdiscount = cs.playerdiscount,
		@currency = ci.currency,
		@minpayout = (case when exchange.minbet<cs.minbet then cs.minbet else exchange.minbet end)/4,
		@maxpermatch = IsNull(CASE @SettingSporttype 
			WHEN 1 THEN ci.maxpermatch 								
			ELSE MaxPerMatch99MP END, 0),--Apply new Mix-Sport setting
		@reject = reject,
		@CurrencyName = exchange.currency
	from 
		custinfo as ci with (nolock) 
		inner join custsetting as cs with (nolock) on ci.custid = cs.custid and cs.bettype=9 and cs.sporttype=@SettingSporttype
		inner join  exchange with (nolock) on ci.currency=exchange.exchangeid 
	where ci.custid=@custid



--set @minpayout = 1 for 12Bet, asiabet88, mansion88, alog site
if exists(select 1 from customer with (nolock) where custid = @srecommend and site in ('12Bet', 'asiabet88', 'mansion88', 'alog', 'TLC', 'spondemo', 'Suncity', 'Mayfair', 'DELA'))
BEGIN
	select @minpayout = 1
END
----------------------------------------------------------------------------------------------------------
-- Check Before Inserting Bet List to bettransm
----------------------------------------------------------------------------------------------------------

--2008-06-12: Suspend feature (Thien)
IF @reject = 1
BEGIN
	select @fail = 1
	select @ErrMsg = 'Odds suspended'
	return
END	
-------------

---------------------- Check whether include this ticket will exceed max per match -----------------------------
Declare @RunningStake money
SELECT @RunningStake = SUM(stake) FROM bettrans (nolock)
WHERE bettype = 9 AND custid = @custid AND ruben = 0
	and oddsid = @SettingSporttype --Apply new Mix-Sport setting

-- System Maximum is 100k RM
IF IsNull(@MaxPerMatch, 0) * @actualrate > 100000 SET @MaxPerMatch = 100000 / @actualrate
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
		(odds.bettype IN (1,2,3,7,8,12,20,21) AND bt.val in ('h','a')) OR
		(odds.bettype in (5, 15) AND bt.val in ('1','x','2')) OR
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

------------------------20081117 check odds belong to matchs---------------------- 
select @cnt = count(1)
from odds (nolock) inner join dbo.strSplit(@oddIdInfo,',') as o on odds.oddsid = o.val
full join dbo.strSplit(@matchIdInfo,',') as m on odds.matchid = m.val
if (@cnt <> @NumOfBet) OR (@cnt < 3)
begin
	select @fail = 1
	select @ErrMsg = 'Invalid odds and matches combination.'
	return
end	

---------------------- Check MaxBet and MinBet -------------------------------------------------------

declare @MaxPayout float, @BetAmount float,@MaxOdds float

select @MaxPayout = VValue from SystemSettings with (nolock) where VName = 'MMaxPayout'

if (@stake < @MinPayout )
begin
	select @fail = 1
	select @ErrMsg = case @Language 
				when 'E' then 'The stake is less than the minimum bet allowed {' + convert(varchar(30), @MinPayout) + N'.'
				when 'J' then N'ベットポイントがミニマムベットより低いです{' + convert(varchar(30), @MinPayout) + N'}'
				when 'CS' then N'The stake is less than the minimum bet allowed {' + convert(varchar(30), @MinPayout) + N'.'
				else N'The stake is less than the minimum bet allowed {' + convert(varchar(30), @MinPayout) + N'.'
			end
	return
end

if (@stake*@actualrate*@mixodds > @MaxPayout )
begin
	select @fail = 1
	select @ErrMsg = case @Language 
				when 'E' then 'The stake exceeded maximum payout.' 
				when 'J' then N'  ベットポイントがマックスベットより大きいです{'+ convert(nvarchar(30), convert(money, @MaxPayOut/@mixodds/@actualrate)) +N'}'
				when 'CS' then N'The stake exceeded maximum payout.' 
				else N'The stake exceeded maximum payout.' 
			end
	return
end		

---------------------- Check for odd value changed ----------------------------------------------------

select @cnt=count(*)
from dbo.strsplit(@matchIdInfo,',') as m
inner join dbo.strsplit(@oddIdInfo,',') as o on m.rank=o.rank
inner join dbo.strsplit(@OrgValueInfo,',') as ov on m.rank=ov.rank
inner join dbo.strsplit(@betTeamInfo,',') as b on m.rank=b.rank
inner join odds on odds.oddsid=convert(int,o.val)
where round(ov.val,2) = round((case replace(lower(b.val),'''','') 	when 'h' then odds1a		when 'a' then odds2a
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
	if (@language = 'E' )	set @ErrMsg = 'Odds changed.'		
	else			set @ErrMsg = 'Odds changed.'
	return
end	

BEGIN TRANSACTION
	declare @refn int
	UPDATE ref with (rowlock,updlock) SET @refn=refno=refno+1  WHERE  refid='refno'
	set @refno = @refn + 100000000000
COMMIT TRANSACTION

--Thien@20091217: Revert to update MAX winlostdate to solve winlostdate problem of early market
select @date = MAX(eventdate)
from dbo.strsplit(@matchIdInfo,',') as mi
inner join match m with (nolock) on mi.val=m.matchid

BEGIN TRANSACTION
	----------------------- Insert Bet Infomation into table Bettransm ---------------------------------

	insert INTO bettransm (custid , oddsid , hdp1 , hdp2 , odds , betteam , stake ,
		status,refno,creator,betfrom, tpositiontaking,apositiontaking,mpositiontaking,
		discount,playerdiscount,adiscount,actualrate,comstatus,	matchid,matchdate, bettype, statusID) 
	--Thien@13-Dec-2007: Store @hdp1 = left(@betteam, 1), @hdp2 = right(@betteam, 1) for Correct Score, 20080122: HTFT 
	select @custid, o.val as oddsid, case when bettype in (4,16) then left(replace(lower(b.val),'''',''), 1) else isnull(odds.hdp1,0.0) end,
		case when bettype in (4,16) then right(replace(lower(b.val),'''',''), 1) else isnull(odds.hdp2,0.0) end, convert(smallmoney,ov.val) as odds, replace(lower(b.val),'''',''), 
		@stake, 'running', @refno, @creator,@BetFrom, @otpositiontaking, @oapositiontaking, @ompositiontaking,
		@discount , @playerdiscount , @adiscount , @actualrate , @refno , m.val, match.eventdate, odds.bettype, 0

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
		if (@language = 'E' )	
		BEGIN
			set @ErrMsg = 'Betting transaction is failed. Please try again...'
		END
		else
		BEGIN
			set @ErrMsg = 'Betting transaction is failed. Please try again...'
		END
		rollback tran
		return
	end
	select @otpositiontaking = isnull(@ospositiontaking, 0) + isnull(@ompositiontaking, 0) + isnull(@oapositiontaking, 0)
	if (@NumOfBet > 1 )
	begin

		----------------- Insert into table Bettrans --------------------------------------		
		--Thien@20101026: change to insert @SettingSporttype in OddsID to check the max per match based on Sports (for Apply new Mix-Sport setting)
		select @betcheck = 'm'+convert(varchar(20), @NumOfBet)
		insert bettrans (custid,oddsid,hdp1,hdp2,odds,betteam,stake,status,
			refno,creator,betfrom, tpositiontaking,apositiontaking,mpositiontaking,
			discount,playerdiscount,adiscount,actualrate,virtualrate,comstatus,matchid,
			winlostdate,recommend,mrecommend,bettype, currency, srecommend, sdiscount, spositiontaking, actual_stake,ip, betcheck, username, currencyName, oddstype, statusID)  		
		select @custid, @SettingSporttype, 0.0, 0.0,
			@mixodds, 'a', @stake, 'running',
			@refno, @creator,@BetFrom, @otpositiontaking, @oapositiontaking, @ompositiontaking,
			@discount ,@playerdiscount ,@adiscount ,@actualrate ,@virtualrate, 'm',9,
			@date,@recommend ,@mrecommend ,9, @currency,  @srecommend, @sdiscount, @ospositiontaking, @stake, @BET_IP,@betcheck, @username, @currencyName, @oddstype, 0
	
		------------------------ Check Error -----------------------------------------------

		if (@@rowcount =0 or @@error <> 0)
		begin
			select @fail = 1
			if (@language = 'E' )	
			begin
				set @ErrMsg = 'Betting transaction is failed. Please try again...'
				-- old message: Insert into Bettrans. Unsucessful....
			end
			else
			begin
				set @ErrMsg = 'Betting transaction is failed. Please try again...'
			end
			rollback transaction
			return
		end
		else
		begin
            select @transid = scope_identity()
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

------------------------ 20081117 write log ------------------------ 
declare @from nvarchar(50), @str nvarchar(500)
SELECT @from = CASE @betfrom 
	WHEN 'p' THEN 'phone'
	WHEN 'h' THEN 'mobile'
	when 'd' THEN 'deposit'
	WHEN 'w' THEN 'wap'
	WHEN 'm' THEN 'dep-wap'
	WHEN 'i' THEN 'internet'
	ELSE 'unknown (' + isnull(@betfrom,'') + ')' END
select @str=left(@from + N' PARLAY betting custid:' + cast(isnull( @custid,'x') as nvarchar(10)) + N' insert bet oddsid:' +  isnull( @oddIdInfo,'x')  
	+ N' at ' + isnull(@oddValueInfo,'x') + ' bet ' + isnull(@betTeamInfo,'x')
	+ N' matchid: ' + isnull(@matchIdInfo,'x') 
	+ N' stake:' + CONVERT(nvarchar(50),isnull(@stake,0)) 
	+ N' refno:' +cast(isnull( @refno,'x') as nvarchar(12)) 
	+ N' ip:' + cast(isnull(@BET_IP,'x') as nvarchar(16)), 300) 
exec logfile @custid, @str

select @transid as TransID

GO
GRANT EXECUTE ON [dbo].[Dot_BetInsMixParlay] TO [Dot_Member]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_BetInsMixParlay] TO [ITTim]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_BetInsMixParlay] TO [ITVivi]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_BetInsMixParlay] TO [vnteam]