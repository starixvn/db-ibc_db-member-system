ALTER PROCEDURE [dbo].[Dot_Member_PlaceBet_Simple_25_27]
	@custid int,
	@username nvarchar(30),
	@currencyname nvarchar(8),
	@currency int,
	@actualrate float,
	@virtualrate float,
	@ugroup nvarchar(12),
	@oddsid int,
	@matchid int,
	@sporttype int,
	@matchdate datetime,
	@betteam nvarchar(10),
	@bettype int,
	@hdp1 float,
	@hdp2 float,
	@odds smallmoney,
	@livehomescore tinyint,
	@liveawayscore tinyint,
	@liveindicator bit,
	@stake money,
	@HTTP_REF nvarchar(150),
	@BET_IP nvarchar(20),
	@site nvarchar(50),
	@betfrom nvarchar(11) = 'i',
	@creator int = 0,
	@OriginalOdds float,
	@srecommend int,
	@mrecommend int,
	@recommend int,
	@autosuspend bit,
	@betcredit float,
	@oddsmaxbet float,
	@maxpermatch float,
	@oddstype tinyint = 1
AS
BEGIN

	SET NOCOUNT ON;
	
	/*
		@bettype: 
			25: Draw no bet (DNB)
			27: To win to nil
	*/
	
	IF @betfrom NOT IN ('p') SET @creator = @custid
	Declare @temp_error int
	Declare @result varchar(50), @transid bigint, @newodds float
	Declare @actual_stake float, @hometotal float, @awaytotal float
	Declare @stake_to_company float
	Declare @newoffersetup bit, @status nvarchar(12), @statusID tinyint
	Declare @risk float, @stakerange float, @com1 float, @com2 float

	-- Scott@2010-6-17: Get actualrate from exchange table.
	SELECT @actualrate = actualrate 
	FROM dbo.exchange WITH (NOLOCK) 
	WHERE exchangeid = @currency

	-- Vivi@2009-3-27: input parameter not correct(when open 2 browser use 2 account), re-get data again, when RD team find out reason will remove.
	select @username=username, @autosuspend=isnull(autosuspend,0), @currency=currency,
		@srecommend=isnull(srecommend,0), @mrecommend=isnull(mrecommend,0), @recommend=isnull(recommend,0)
	from custinfo with (nolock) where custid = @custid;

	--Thien@2009-08-06: fix the wrong inputted time '12:00:00' into winlostdate field on Member Wap system
	set @matchdate = convert(varchar(10), @matchdate, 120)

	-- for write log
	Declare @str nvarchar(500)
	Declare @starttime datetime 
	Declare @diffbalance float
	SET @starttime = CURRENT_TIMESTAMP

	SET @transid = 0
	SET @temp_error = 0

	-- get custsetting data
	Declare
		@apos smallmoney, @mpos smallmoney, 
		@spos smallmoney, @tpos smallmoney,
		@minbet money, @maxbet money,
		@playerdiscount decimal(9,8), @adiscount decimal(9,8), 
		@mdiscount decimal(9,8), @sdiscount decimal(9,8)
	
	SELECT 
		@apos = IsNull(CASE @sporttype WHEN 1 THEN CASE @liveindicator when 1 then CASE @bettype WHEN 2 THEN apositiontaking ELSE alivepositiontaking END else apositiontaking end ELSE apositiontaking END,0),		@mpos = IsNull(CASE @sporttype WHEN 1 THEN CASE @liveindicator when 1 then CASE @bettype WHEN 2 THEN mpositiontaking ELSE mlivepositiontaking END else mpositiontaking end ELSE mpositiontaking END,0),
		@spos = CASE WHEN @srecommend <= 100 THEN 0 ELSE IsNull(CASE @sporttype WHEN 1 THEN CASE @liveindicator when 1 then CASE @bettype WHEN 2 THEN spositiontaking ELSE slivepositiontaking END else spositiontaking end ELSE spositiontaking END,0) END,
		@minbet = IsNull(minbet,0),
		@maxbet = IsNull(maxbet,0),
		@playerdiscount = IsNull(playerdiscount,0),
		@adiscount = IsNull(discount,0),
		@mdiscount = IsNull(adiscount,0),
		@sdiscount = IsNull(CASE WHEN @srecommend <= 100 THEN adiscount ELSE sdiscount END,0)
	FROM dbo.custsetting with (nolock)
	WHERE custid = @custid AND bettype = 1 AND sporttype = 1

	IF (@@rowcount = 0 or @@error <> 0) 
	BEGIN
		SET @transid = -1
		SET @result = 'userinfonotfound'
	END
	ELSE
	BEGIN
		IF @betfrom NOT IN ('p')
		BEGIN
			IF @bettype NOT IN (1,3,7,8) SET @minbet = @minbet / 3
			IF @stake > @maxbet or @stake < @minbet
			BEGIN
				SET @transid = -1
				SET @result = 'stakeproblem'
			END
		END
	END
	
	SET @tpos = @apos + @mpos + @spos
	IF (@tpos > 0.95)
	BEGIN
		SET @transid = -2
		SET @result = 'positiontakingproblem'
	END
	
	-- input parameter @virtualrate = CustSetting.VirtualMultiplier
	SET @virtualrate = @virtualrate * @actualrate  
	
	SET @stake_to_company = @stake * (1-@tpos) * @virtualrate   


	/*
		@betteam:
			25: h/a (keep total bet in hometotal/awaytotal)
			27: h/a (keep total bet in hometotal/awaytotal)
	*/	
	IF @betteam='h'
	BEGIN
		UPDATE dbo.odds with (rowlock,updlock)
		SET
			@DiffBalance = diffbalance = 
				CASE 
					WHEN @betfrom IN ('p') and @currency <> 20 THEN 0
					WHEN @stake_to_company + diffbalance >= risk THEN 0 
				ELSE diffbalance + @stake_to_company END,
			@hometotal = hometotal = hometotal + @stake_to_company * CASE WHEN abs(@odds)>1 THEN abs(@odds) ELSE 1 END,
			@newoffersetup = newoffersetup
		WHERE oddsid = @OddsID

	END
	ELSE IF @betteam='a'
	BEGIN
		UPDATE dbo.odds with (rowlock,updlock)
		SET
			@DiffBalance = diffbalance=	
				CASE 
					WHEN @betfrom IN ('p') and @currency <> 20 THEN 0
					WHEN (@stake_to_company-diffbalance) >= risk2 THEN 0 
				ELSE diffbalance-@stake_to_company END,
			@awaytotal = awaytotal = awaytotal + @stake_to_company * CASE WHEN abs(@odds)>1 THEN abs(@odds) ELSE 1 END,
			@newoffersetup = newoffersetup 
		WHERE oddsid = @OddsID
	END
	
	--======================================
	-- insert bettrans
	--======================================
	IF (@transid=0 and @temp_error=0)
	BEGIN      
		SET @temp_error=@@error      
		IF (@temp_error<>0) SET @http_ref='error update'

		IF (@temp_error=0 and @odds<>0) 
		BEGIN      
			Declare @err int  
			IF (@betfrom NOT IN ('p') and @liveindicator=1)
			BEGIN
				SET @status= CASE WHEN @newoffersetup=1 THEN 'running' ELSE 'waiting' END
			END
			ELSE
			BEGIN
				SET @status='running'
			END
			SET @statusID= CASE WHEN @status='running' THEN 0 ELSE 1 END

			SET @actual_stake = CASE WHEN @odds < 0 THEN ABS(@odds) * @stake ELSE @stake END

			insert bettrans 
			( 
			custid, oddsid, oddsspread, hdp1, hdp2,odds, stake, status, livehomescore, liveawayscore, liveindicator, betfrom, 
			betteam, creator, refno, tpositiontaking, apositiontaking, mpositiontaking, spositiontaking,
			playerdiscount, discount, adiscount, sdiscount, actualrate, virtualrate,
			matchid, recommend, mrecommend, srecommend, scomm, swinlost,
			bettype, currency, actual_stake, winlostdate, transdesc, ip, Username, CurrencyName, betcheck, oddstype, statusID) 
			values 
			(
			@custid ,@oddsid,
			0, @hdp1, @hdp2,@odds,
			@stake, @status,  @livehomescore, @liveawayscore,
			@liveindicator, @betfrom, @betteam,  @creator, 100000000000 ,
			@tpos, @apos, @mpos, @spos,
			@playerdiscount, @adiscount, @mdiscount, @sdiscount, @actualrate, @virtualrate,
			@matchid, @recommend, @mrecommend, @srecommend, 0, 0,
			@bettype, @currency, @actual_stake, 
			@matchdate, @http_ref, @Bet_ip, @Username, @CurrencyName,
			'df(' + convert(nvarchar(20), CAST(IsNull(@diffbalance,-55) as money)) + ')(' + convert(nvarchar(10), IsNull(@risk,-55)) + '/' + convert(nvarchar(10), IsNull(@stakerange,-55)) + '/' + convert(nvarchar(10), IsNull(@com1,-1)) + ':' + convert(nvarchar(10), IsNull(@com2,-1)) + ')',
			@oddstype, @statusID
			); 
			SET @err=@@error;
			SELECT @transid=scope_identity() 
	       
			IF (@err<>0)
			BEGIN 
				SET @transid=-3
				SET @result='failed-bet'
			END
		END
		ELSE
		BEGIN
			SET @transid=-2
			SET @result='odds-changed'
		END
	END  

	--======================================
	-- write log
	--======================================
	SELECT @str =
		CASE @betfrom 
		WHEN 'i' THEN 'internet'
		WHEN 'p' THEN 'phone'
		WHEN 'h' THEN 'mobile'
		WHEN 'w' THEN 'wap'
		WHEN 'd' THEN 'deposit'
		WHEN 'm' THEN 'dep-wap'
		WHEN 't' THEN 'test'
		ELSE 'unknown (' + @betfrom + ')' END
		+ N' betting custid:' + cast(isnull( @custid,0) as nvarchar(10))
		+ N' insert bet oddsid:' +  cast(isnull( @oddsid,0) as nvarchar(10)) 
		+ N' at ' + CONVERT(nvarchar(10),CAST(isnull(@odds,0) as float)) + '(' + @ugroup + ')'
		+ N' (org:' + CONVERT(nvarchar(10),CAST(isnull(@OriginalOdds,0) as float)) + ')'
		+ N' bet ' + cast(isnull(@betteam,'x') as nvarchar(10))
		+ N' stake:' + CONVERT(nvarchar(50),isnull(@stake,0)) 
		+ N' transid:' +cast(isnull( @transid,0) as nvarchar(10)) 
		+ N' ip:' + cast(isnull(@BET_IP,'x') as nvarchar(16)) 
		+ N' NBC:' + CAST(@BetCredit - @actual_stake as nvarchar(50)) 
		+ N' DF:' + CAST(@DiffBalance as nvarchar(50))
		+ N' (' + CAST(DATEDIFF(millisecond, @StartTime, CURRENT_TIMESTAMP) as nvarchar(50)) + ' ms) ' + @site
		+ N' creatorid:' + cast(isnull( @creator,0) as nvarchar(10))
	exec dbo.logfile @custid, @str


	--======================================
	-- return result
	--======================================
	SELECT IsNull(@result,'') result, @transid transid, @newodds newodds, @liveindicator liveindicator

	SET NOCOUNT OFF;
END

GO
GRANT EXECUTE ON [dbo].[Dot_Member_PlaceBet_Simple_25_27] TO [Dot_Member] 