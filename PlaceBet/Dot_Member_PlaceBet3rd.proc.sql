USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Member_PlaceBet3rd]    Script Date: 04/25/2011 23:10:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-------------------------------------------------------------------
--'odds-suspend'	: odds is suspend
--'userinfonotfound': not found record in custinfo
--'customer-closed'	: customer status is closed
--'oversystemmaxbet': stake is more than odds' maxbet
--'match-closed'	: event closed
--'overmaxpermatch'	: member already bet more than maxpermatch
--'creditproblem'	: not enough bet credit
--'stakeproblem'	: stake is not in range of minbet/maxbet
--'data-mismatch'	: bettype -vs- betteam is not in the correct format
--'disablebetproblem'	: custinfo disable flag is true
-------------------------------------------------------------------
ALTER PROCEDURE [dbo].[Dot_Member_PlaceBet3rd]
	@custid int,
	@SportType tinyint,	--151(horse racing)/201(finance)
	@BetType tinyint,	--31(win)/32(place)/33(winplace)/51-56(5,15,30,45,60,end of day OU)/61-66(OE)
	@oddsid int,	--151(orid)/201(input 0)
	@betteam nvarchar(10),	--horse/h(call)/a(put)
	@hdp1 float = 0, --43 (win odds)
	@hdp2 float = 0, --43 (place odds)
	@odds smallmoney,
	@livehomescore tinyint = 0,
	@liveawayscore tinyint = 0,
	@stake money,
	@HTTP_REF nvarchar(150),
	@BET_IP nvarchar(20),
	@site nvarchar(50),
	@betfrom nvarchar(10) = 'i',
	@creator int = 0,
	@CommID tinyint = 0, --151(input to get custsetting data)/201(no input)
	@matchid int = 0, --151(no input)/201(input bet matchid)
	@srcodds float = 0, --151(no input)/201(input 3rd party source odds save in bettrans.transdesc)
	@SrcOddsTimestamp bigint = 0, --151(no input)/201(input 3rd party source odds timestamp save in bettrans.betid)
	@transdate datetime = null, --151(no input)/201(input)
	@oddstype tinyint = 1,
	@refno bigint = 0	--151(no input)/201(input 3rd party reference id)
AS
/*
	--20110426@Thien: remove Yen, NTD, $US, IRR from the hard-code of House/Phu's PT.
*/
	SET NOCOUNT ON
	Declare @transid bigint
	Declare @StartTime datetime SET @StartTime = CURRENT_TIMESTAMP
	Declare @result varchar(50) SET @result = ''
	Declare @rowcnt int

	IF NOT (
			(@bettype BETWEEN 51 AND 66 AND @betteam in ('h','a')) OR
			(@bettype IN (31,32,33,41,42,43))
			)
	SET @Result = 'data-mismatch'

----BLOCK FIXED ODDS EACH WAY BETTYPE TEMPORARILY
--IF @bettype = 43
--	SET @Result = 'data-mismatch'
----------------------------------------
--==========================  
IF @result <> '' GOTO FINISH  
--==========================  
	IF @betfrom NOT IN ('p') SET @creator = @custid
	IF @transdate IS null SET @transdate=getdate()

	Declare @leagueid int, @raceno varchar(20), @ProgramID varchar(10)
	Declare @credit money, @maxpermatch money, @Balance money, @TotalBet money
	Declare @liveindicator bit, @eventdate smalldatetime
	Declare @EventStatus nvarchar(50)		--for get Financals EventStatus
	Declare	@winlostdate smalldatetime 	--for get Financals winlostdate = @transdate + Time Range
	
	Declare @reject bit, @DisableBet bit
	set @reject=0
	set @DisableBet=0

SET @result = CASE
	WHEN @betfrom NOT IN ('p') AND @stake < 0 THEN 'stakeproblem'
	WHEN @odds = 0 and @bettype not in (31,32,33,43) THEN 'odds-suspend'
	WHEN @oddsid = 0 and @bettype in (31,32,33,41,42,43) THEN 'odds-suspend'
	WHEN @matchid = 0 and @bettype between 51 and 66 THEN 'odds-suspend'
	ELSE @result END

--==========================  
IF @result <> '' GOTO FINISH  
--==========================  

	IF @sporttype = 151
	BEGIN

		SELECT @leagueid = leagueid, @raceno = groupmatch, @eventdate = eventdate , @ProgramID = ProgramID
		FROM dbo.outright with (nolock) WHERE orid = @oddsid

		IF IsNumeric(@ProgramID) = 1   --20100427: for OpenTote maxpermatch
		BEGIN
			SELECT
				@credit = c.credit, @maxpermatch = IsNull(c.maxpermatch151_OT, 0),
				@Balance  = SUM(winlost - actual_stake + playercomm),
				@TotalBet = SUM(CASE WHEN leagueid = @leagueid AND groupmatch = @raceno AND winlostdate = @eventdate AND b.[status] <> N'reject' THEN actual_stake ELSE 0 END),
				@reject = c.reject, 
				@DisableBet = c.DisableOpenTote
			FROM
				dbo.custinfo c with (nolock)
				LEFT OUTER JOIN dbo.bettrans b with (nolock) ON c.custid = b.custid
				LEFT OUTER JOIN dbo.outright o with (nolock) ON b.matchid = o.orid
			WHERE
				c.custid = @custid
				AND c.closed = 0 --AND c.reject = 0 AND c.DisableOpenTote = 0
			GROUP BY
				c.credit, c.maxpermatch151_OT, c.reject, c.DisableOpenTote

			set @rowcnt = @@ROWCOUNT 
		END 
		ELSE
		BEGIN
			SELECT
				@credit = c.credit, @maxpermatch = IsNull(c.maxpermatch151, 0),
				@Balance  = SUM(winlost - actual_stake + playercomm),
				@TotalBet = SUM(CASE WHEN leagueid = @leagueid AND groupmatch = @raceno AND winlostdate = @eventdate AND b.[status] <> N'reject' THEN actual_stake ELSE 0 END),
				@reject = c.reject, 
				@DisableBet = c.DisableHorseRacing
			FROM
				dbo.custinfo c with (nolock)
				LEFT OUTER JOIN dbo.bettrans b with (nolock) ON c.custid = b.custid
				LEFT OUTER JOIN dbo.outright o with (nolock) ON b.matchid = o.orid
			WHERE
				c.custid = @custid
				AND c.closed = 0 --AND c.reject = 0 AND c.DisableHorseRacing = 0
			GROUP BY
				c.credit, c.maxpermatch151, c.reject, c.DisableHorseRacing

			set @rowcnt = @@ROWCOUNT 
		END
		
	END
	IF @sporttype = 201 -- Financial
	BEGIN
		IF EXISTS(SELECT 1 FROM bettrans with (nolock) WHERE matchid=@matchid and bettype between 51 and 66 and refno=@refno)
		BEGIN
			SET @result = 'ticket-has-exists'
			GOTO FINISH
		END
		
		-- Get winlostdate for Financials
		SET @winlostdate = DATEADD(minute, CASE WHEN @BetType IN (51,61) THEN 5 
								 WHEN @BetType IN (52,62) THEN 15 
								 WHEN @BetType IN (53,63) THEN 30 
								 WHEN @BetType IN (54,64) THEN 45 
								 WHEN @BetType IN (55,65) THEN 60 END, @transdate)

		SET @winlostdate = CONVERT(VARCHAR(10), @winlostdate, 120) -- Clear Time


		SELECT
			@credit = c.credit, @maxpermatch = IsNull(c.maxpermatch201, 0),
			@Balance  = SUM(winlost - actual_stake + playercomm),
			@TotalBet = SUM(CASE matchid WHEN @matchid THEN actual_stake ELSE 0 END),
			@reject = c.reject, 
			@DisableBet = c.DisableFinancial
		FROM
			dbo.custinfo c with (nolock)
			LEFT OUTER JOIN dbo.bettrans b with (nolock) ON c.custid = b.custid
		WHERE
			c.custid = @custid
			AND c.closed = 0 --AND c.reject = 0 AND c.DisableFinancial = 0
		GROUP BY
			c.credit, c.maxpermatch201, c.reject, c.DisableFinancial 

		set @rowcnt = @@ROWCOUNT
	END

	SET @result = CASE
		WHEN @rowcnt = 0 THEN 'customer-closed'
		WHEN @reject = 1 THEN 'odds-suspend'
		WHEN @DisableBet = 1 THEN 'disablebetproblem'
		WHEN IsNull(@TotalBet, 0) + @stake > @maxpermatch THEN 'overmaxpermatch'
		WHEN IsNull(@credit, 0) + IsNull(@Balance, 0) < @stake THEN 'creditproblem'
		ELSE @result END
  
--==========================  
IF @result <> '' GOTO FINISH  
--==========================  


-- Get User Information
	Declare @currency tinyint, @recommend int, @mrecommend int, @srecommend int,
			@Username nvarchar(50), @actualrate float, @eminbet money, @CurrencyName nvarchar(10)
	Declare	@apos smallmoney, @mpos smallmoney, @spos smallmoney, @tpos smallmoney,
			@playerdiscount decimal(9,8), @adiscount decimal(9,8), @mdiscount decimal(9,8), @sdiscount decimal(9,8),
			@minbet money, @maxbet money,
			@apos2 smallmoney, @mpos2 smallmoney, @spos2 smallmoney, @tpos2 smallmoney,
			@playerdiscount2 decimal(9,8), @adiscount2 decimal(9,8), @mdiscount2 decimal(9,8), @sdiscount2 decimal(9,8),
			@ibcauto smallmoney, @ibcpos smallmoney, @ibcpos2 smallmoney, @maxpos smallmoney,
			@btapos smallmoney, @btmpos smallmoney, @btspos smallmoney, @bttpos smallmoney, @btibcpos smallmoney

	Declare @SettingBetType tinyint
	SET @SettingBetType = CASE		
		WHEN @bettype IN (31, 32, 41, 42) THEN @bettype --@SportType = 151 THEN 30 + @CommID
		WHEN @bettype IN (33, 43) THEN @bettype - 2
		WHEN @bettype between 51 and 56 THEN 3	--Get Over/Under for Financial bettype from 51 to 56 (Thien)
		WHEN @bettype between 61 and 66 THEN 2	--Get Odd/Even for Financial bettype from 61 to 66 (Thien)
		END	

	--20100427: OpenTote in CustSetting_3rd, bettype is '41,42'
	IF @sporttype = 151 and IsNumeric(@ProgramID) = 1
	BEGIN
		IF @SettingBetType IN (31,32) SET @SettingBetType = @SettingBetType + 10
	END

	Declare @SettingSportType tinyint
	SET @SettingSportType = @SportType	

	--20081211: Financial: do the hard-code to get the setting from Basketball-HDP for Financial (Thien)
	--if @bettype BETWEEN 51 AND 66 select @SettingBetType  = 1, @SettingSportType = 2
	--if @bettype BETWEEN 51 AND 66 select @SettingBetType  = 1, @SettingSportType = 2
	--20091216: Get setting from CustSetting3rd table (Jamie)
	--20100511: Get virtualrate from exchange table (Sylvia)
	SELECT
		@Username = c.username, @currency = c.currency,
		@recommend = IsNull(recommend,0), @mrecommend = IsNull(mrecommend,0), @srecommend = IsNull(srecommend,0),
		@CurrencyName = e.currency,
		@actualrate = e.actualrate,
		@eminbet = e.minbet,
		@apos = apositiontaking,
		@mpos = mpositiontaking,
		@spos = CASE
				WHEN @srecommend <= 100 THEN 0
				ELSE spositiontaking
				END,
		@tpos = @apos + @mpos + @spos,
		@minbet = IsNull(s.minbet,0),
		@maxbet = IsNull(s.maxbet,0),
		@playerdiscount = IsNull(playerdiscount,0),
		@adiscount = IsNull(discount,0),
		@mdiscount = IsNull(adiscount,0),
		@sdiscount = IsNull(CASE WHEN @srecommend <= 100 THEN adiscount ELSE sdiscount END,0)
	FROM dbo.custinfo c with (nolock)
		INNER JOIN dbo.exchange e with (nolock) ON c.currency = e.exchangeid
		INNER JOIN dbo.custsetting3rd s with (nolock) ON c.custid = s.custid
	WHERE
		c.custid = @custid
		AND s.custid = @custid AND s.sporttype = @SettingSportType AND s.bettype = @SettingBetType

	IF @@ROWCOUNT = 0 SET @result = 'userinfonotfound'

	IF @SportType = 151
	BEGIN
		-- disable UUS to place bet for Horse (Since ticket will always reject)
		-- IF @currency = 20 SET @result = 'overmaxpermatch'
		-- load IBC auto setting, open tote using fixed setting
		SELECT @ibcauto = CASE
			WHEN @SettingBetType IN (31,32) THEN AutoIBCPositionTaking_Tote
			ELSE AutoIBCPositionTaking_Fixed END
		FROM dbo.custSuper with (nolock)
		WHERE custid = @srecommend
		
		Declare @PoolCurrency int, @PoolCurrencyName varchar(10), @virtualrate float
		IF @SettingBetType IN (31,32)
		BEGIN
			SELECT @virtualrate = @actualrate, @PoolCurrency = NULL
		END
		ELSE
		BEGIN
			-- Get Horse Racing PoolCurrency and virtualrate
			SELECT @PoolCurrency = h.PoolCurrency,
				   @PoolCurrencyName = e.currency
			FROM HorseMeeting h with (nolock)
				inner join exchange e with (nolock) on h.PoolCurrency = e.exchangeid
			WHERE h.MeetingID = @leagueid

			SELECT @virtualrate =
					CASE 
						WHEN @PoolCurrencyName='AUD' THEN ISNULL(AUDRate,0)
						WHEN @PoolCurrencyName='ZAR' THEN ISNULL(ZARRate,0)
						WHEN @PoolCurrencyName='GBP' THEN ISNULL(GBPRate,0)
						WHEN @PoolCurrencyName='EURO' THEN ISNULL(EURORate,0)
						WHEN @PoolCurrencyName='US$' THEN ISNULL(US$Rate,0)
						ELSE 0
					END
			FROM exchange with (nolock) 
			WHERE exchangeid = @currency
		END		
	END

	-- Get PositionTaking for Place (when member bet on WP)
	IF @bettype IN (33, 43)
	SELECT
		@apos2 = apositiontaking,
		@mpos2 = mpositiontaking,
		@spos2 = CASE
				WHEN @srecommend <= 100 THEN 0
				ELSE spositiontaking
				END,
		@tpos2 = @apos2 + @mpos2 + @spos2,
		@playerdiscount2 = IsNull(playerdiscount,0),
		@adiscount2 = IsNull(discount,0),
		@mdiscount2 = IsNull(adiscount,0),
		@sdiscount2 = IsNull(CASE WHEN @srecommend <= 100 THEN adiscount ELSE sdiscount END,0)
	FROM dbo.custsetting3rd s with (nolock)
	WHERE s.custid = @custid AND s.sporttype = @SettingSportType
		AND s.bettype = @bettype - 1
	
--==========================  
IF @result <> '' GOTO FINISH  
--==========================  
	--IF @SportType = 151 set @minbet=1
	IF @betfrom NOT IN ('p') AND ((@stake < @minbet) OR (@stake > @maxbet)) SELECT @result = 'stakeproblem'


--==========================  
IF @result <> '' GOTO FINISH  
--========================== 
	IF @SportType = 151
	BEGIN
		Declare @OverallMaxPT smallmoney -- Max of (IBCPos + TPos)
		--Thien@20100521:	+ Phumelela: for (THB, IN, IND, IDD, IDR) members, IBC MUST take 10% PT, MIN PT to Phumelela is 40%
		--					+ OpenTote: For members in ALL currencies, MIN PT to 3rd Party is ALWAYS 50%
		select 
			@OverallMaxPT = CASE
								WHEN @currency in (43, 15, 22, 33, 34, 47) and @SettingBetType in (31,32) then 0.6 --for (THB, $US, IRR, NTD, Yen, IN, IND, IDD, IDR) members, IBC MUST take 10% PT, MIN PT to Phumelela is 40%
								ELSE 0.5 --in first month, Phu will take at least 50%
							END

		SELECT
			@liveindicator = 0,
			-- calculate IBC positiontaking value
			@ibcpos  = (@OverallMaxPT - @tpos + @ibcauto - ABS(@OverallMaxPT - @tpos - @ibcauto)) / 2,
			@ibcpos2 = (@OverallMaxPT - @tpos2 + @ibcauto - ABS(@OverallMaxPT - @tpos2- @ibcauto)) / 2,
			-- calculate MAX value of total positiontaking (include IBC)
			@maxpos  = (@ibcpos + @tpos + @ibcpos2 + @tpos2 + ABS(@ibcpos + @tpos - @ibcpos2 - @tpos2)) / 2

		IF @bettype IN (33, 43)
		BEGIN
			-- if position is not equal, adjust IBCpos to make it equal
			IF (@tpos + @ibcpos) <> (@tpos2 + @ibcpos2)
				SELECT @ibcpos = @maxpos - @tpos, @ibcpos2 = @maxpos - @tpos2

			SELECT
				@btapos = (@apos + @apos2) / 2,
				@btmpos = (@mpos + @mpos2) / 2,
				@btspos = (@spos + @spos2) / 2,
				@bttpos = (@tpos + @tpos2) / 2,
				@btibcpos = (@ibcpos + @ibcpos2) / 2
		END
		ELSE
			SELECT @btapos = @apos, @btmpos = @mpos, @btspos = @spos, @bttpos = @tpos, @btibcpos = @ibcpos

	END
ELSE IF @SportType = 201
BEGIN
	SELECT @liveindicator = 1, @eventdate = eventdate, @EventStatus = eventstatus FROM dbo.match with (nolock) WHERE matchid = @matchid
	
	-- Check the match eventstatus
	IF @EventStatus='suspend' 
	BEGIN
		SET @result = 'match-suspend'
	END
	
	-- IF winlostdate < transdate
	IF NOT (CONVERT(varchar(10), CURRENT_TIMESTAMP, 120) BETWEEN CONVERT(varchar(10), @eventdate, 120) AND CONVERT(varchar(10), DATEADD(d,1,@eventdate), 120))
	BEGIN
		SET @result = 'match-problem'
	END
END

--==========================  
IF @result <> '' GOTO FINISH  
--========================== 

	Declare @betactual_stake money
	SET @betactual_stake = @stake

	-- PLACE BET
	IF @SportType = 151
	BEGIN
		insert bettrans 
		(   
		custid, oddsid, hdp1, hdp2,odds, stake, [status], livehomescore, liveawayscore, liveindicator, betfrom,   
		betteam, creator, refno, tpositiontaking, apositiontaking, mpositiontaking, spositiontaking, oddsspread, 
		playerdiscount, discount, adiscount, sdiscount, actualrate, virtualrate,  
		matchid, recommend, mrecommend, srecommend, scomm, swinlost,
		bettype, currency, actual_stake, winlostdate, transdesc, ip, Username, CurrencyName, betcheck, oddstype, modds, currency2, statusID)   
		values 
		(
		@custid, @oddsid, @hdp1, @hdp2, @odds, @stake, N'waiting', @livehomescore, @liveawayscore, @liveindicator, @betfrom,
		@betteam, @creator, 0, @bttpos, @btapos, @btmpos, @btspos, @btibcpos,
		@playerdiscount, @adiscount, @mdiscount, @sdiscount, @actualrate, @virtualrate,  
		@oddsid, @recommend, @mrecommend, @srecommend, 0, 0, 
		@bettype, @currency, @betactual_stake, @eventdate, @http_ref, @BET_IP, @Username, @CurrencyName, '', @oddstype, @odds, @PoolCurrency, 1);
		SELECT @transid=SCOPE_IDENTITY()

		IF @bettype IN (33, 43)
		BEGIN
			-- 31, 41
			INSERT INTO dbo.bettransm
			(
			custid, oddsid, hdp1, hdp2, odds, stake, status,
			livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus,
			winlostdate, betfrom, matchid, matchdate, statuswinlost, ruben, bettype,
			apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, oddsspread,
			playerdiscount, discount, adiscount, sdiscount,
			winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, finalodds, -- keep bet 43, win source odds
			statusID
			) VALUES
			(
			@custid, @oddsid, @hdp1, @hdp2, @odds, @stake/2, N'running',
			@livehomescore, @liveawayscore, @liveindicator, @betteam, @creator, @transid, @transid,
			@eventdate, @betfrom, @oddsid, @eventdate, 0, 0, (@bettype - 2),
			@apos, @mpos, @spos, @tpos, @ibcpos, @playerdiscount, @adiscount, @mdiscount, @sdiscount,
			0, 0, 0, 0, 0, 0, 0, 0, @hdp1, --win odds
			0)
			
			-- 32, 42
			INSERT INTO dbo.bettransm
			(
			custid, oddsid, hdp1, hdp2, odds, stake, status,
			livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus,
			winlostdate, betfrom, matchid, matchdate, statuswinlost, ruben, bettype,
			apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, oddsspread,
			playerdiscount, discount, adiscount, sdiscount,
			winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, finalodds, -- keep bet 43, place source odds
			statusID
			) VALUES
			(
			@custid, @oddsid, @hdp1, @hdp2, @odds, @stake/2, N'running',
			@livehomescore, @liveawayscore, @liveindicator, @betteam, @creator, @transid, @transid,
			@eventdate, @betfrom, @oddsid, @eventdate, 0, 0, (@bettype - 1),
			@apos2, @mpos2, @spos2, @tpos2, @ibcpos2, @playerdiscount2, @adiscount2, @mdiscount2, @sdiscount2,
			0, 0, 0, 0, 0, 0, 0, 0, @hdp2, --place odds
			0)
		END
	END
	ELSE IF @SportType = 201
	BEGIN
		--financal Game to get agent site name, coz from 3rdparty not give site name
		SELECT @site=ag.site FROM customer ag with (nolock) 
		WHERE ag.custid=@recommend

		-- keep 3rd source odds in transdesc column prefix
		SET @http_ref =  CONVERT(nvarchar(10),CAST(@srcodds as float)) + ',' + @http_ref
		insert bettrans 
		(
		custid, transdate, oddsid, oddsspread, hdp1, hdp2,odds, stake, [status], livehomescore, liveawayscore, liveindicator, betfrom,   
		betteam, creator, refno, tpositiontaking, apositiontaking, mpositiontaking, spositiontaking,
		playerdiscount, discount, adiscount, sdiscount, actualrate, virtualrate,
		matchid, recommend, mrecommend, srecommend, scomm, swinlost,
		bettype, currency, actual_stake, winlostdate, transdesc, ip, Username, CurrencyName, betcheck, betid, oddstype, statusID)
		values 
		(  
		@custid, @transdate, @oddsid, 0, @hdp1, @hdp2, @odds, @stake, N'running', @livehomescore, @liveawayscore, @liveindicator, @betfrom,
		@betteam, @creator, @refno, @tpos, @apos, @mpos, @spos, 
		@playerdiscount, @adiscount, @mdiscount, @sdiscount, @actualrate, @actualrate,
		@matchid, @recommend, @mrecommend, @srecommend, 0, 0, 
		@bettype, @currency, @betactual_stake, @winlostdate, @http_ref, @BET_IP, @Username, @CurrencyName, '', @SrcOddsTimestamp, @oddstype, 0
		);
		SELECT @transid=SCOPE_IDENTITY() 
	END
  
	declare @str nvarchar(500)  
	declare @from nvarchar(50)  
	SELECT @from = CASE @betfrom   
		WHEN 'p' THEN 'phone'  
		WHEN 'h' THEN 'mobile'  
		WHEN 'w' THEN 'wap'  
		when 'd' THEN 'deposit'  
		WHEN 'm' THEN 'dep-wap'  
		WHEN 'i' THEN 'internet'  
		WHEN 't' THEN 'test'  
		ELSE 'unknown (' + @betfrom + ')' END  
  
	select @str=@from + N' betting (3rd) custid:' + cast(isnull( @custid,'x') as nvarchar(10)) + N' insert bet '
	+ CASE @sporttype WHEN 151 THEN '151' WHEN 201 THEN '201' ELSE '' END
	+ N' at ' + CONVERT(nvarchar(10),CAST(isnull(@odds,0) as float)) + ' bet ' + cast(isnull(@betteam,'x') as nvarchar(10))  
	+ N' stake:' + CONVERT(nvarchar(50),isnull(@stake,0))
	+ N' transid:' +cast(isnull( @transid,'x') as nvarchar(20))   
	+ N' ip:' + cast(isnull(@BET_IP,'x') as nvarchar(16))   
	+ N' NBC:' + CAST(@Credit + @Balance - @betactual_stake as nvarchar(50))   
	+ N' (' + CAST(DATEDIFF(millisecond, @StartTime, CURRENT_TIMESTAMP) as nvarchar(50)) + ' ms) ' + @site  
	exec dbo.logfile @custid, @str  

FINISH:
	IF @SportType = 151
		SELECT
			IsNull(@result,'') result, @transid transid, (isnull(@tpos,0) + isnull(@ibcpos,0)) positiontaking
	ELSE IF @SportType = 201
		SELECT
			IsNull(@result,'') result, @transid transid, @tpos positiontaking, @sdiscount ComRate, 
			@currency currencyID, @actualrate currencyRate,@minbet minbet,@maxbet maxbet,@maxpermatch maxpermatch,(IsNull(@credit, 0) + IsNull(@Balance, 0)) credit


GO
GRANT EXECUTE ON [dbo].[Dot_Member_PlaceBet3rd] TO [Dot_3rdparty]
GO
GRANT EXECUTE ON [dbo].[Dot_Member_PlaceBet3rd] TO [Dot_Member]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_PlaceBet3rd] TO [ITTim]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_PlaceBet3rd] TO [ITVivi]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_PlaceBet3rd] TO [vnteam]