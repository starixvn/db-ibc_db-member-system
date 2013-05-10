ALTER PROCEDURE [dbo].[Dot_Member_PlaceBet_Simple_13_24_26_28]
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
	@livehomescore tinyint = 0,
	@liveawayscore tinyint = 0,	
	@liveindicator bit,
	@stake money,
	@HTTP_REF nvarchar(150),
	@BET_IP nvarchar(20),
	@site nvarchar(50),
	@betfrom nvarchar(11) = 'i',
	@creator int = 0,
	@OriginalOdds float = NULL,
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
	SET NOCOUNT ON

	/*
		@bettype: 
			13: Clean sheet
			24: Double Chance
			26: Both/One/Neither team to score
			28: 3-way handicap
	*/

	if @betfrom NOT IN ('p') SET @creator = @custid
	Declare @temp_error int
	Declare @result varchar(50), @transid bigint, @newodds float
	Declare @actual_stake float
	Declare @stake_to_company float
	Declare @oddsstatusnew nvarchar(50),@newoffersetup bit,@status nvarchar(12),@statusID tinyint
	Declare @starttime datetime
	Declare @autobookie bit
	Declare @str nvarchar(500)

	SET @oddstype = 1
	SET @autobookie=0

	-- Scott@2010-6-17: Get actualrate from exchange table.
	SELECT @actualrate = actualrate 
	FROM dbo.exchange WITH (NOLOCK) 
	WHERE exchangeid = @currency

	-- Vivi@2009-3-27: input parameter not correct(when open 2 browser use 2 account), re-get data again, when RD tem find out reason will remove.
	SELECT @username=username, @autosuspend=isnull(autosuspend,0), @currency=currency,
		@srecommend=isnull(srecommend,0), @mrecommend=isnull(mrecommend,0), @recommend=isnull(recommend,0)
	FROM custinfo with (nolock) where custid = @custid;

	--Thien@2009-08-06: fix the wrong inputted time '12:00:00' into winlostdate field on Member Wap system
	SET @matchdate = convert(varchar(10), @matchdate, 120)

	SET @transid=0

	SET @temp_error=0
	SET @starttime=CURRENT_TIMESTAMP
	
	-- get custsetting data
	Declare
			@apos smallmoney, @mpos smallmoney, 
			@spos smallmoney, @tpos smallmoney,
			@minbet money, @maxbet money,
			@playerdiscount decimal(9,8), @adiscount decimal(9,8), 
			@mdiscount decimal(9,8), @sdiscount decimal(9,8)

	SELECT
		@apos = IsNull(apositiontaking,0),
		@mpos = IsNull(mpositiontaking,0),
		@spos = CASE
				WHEN @srecommend <= 100 THEN 0
				ELSE IsNull(spositiontaking,0)
				END,
		@minbet = IsNull(minbet,0),
		@maxbet = IsNull(maxbet,0),
		@playerdiscount = IsNull(playerdiscount,0),
		@adiscount = IsNull(discount,0),
		@mdiscount = IsNull(adiscount,0),
		@sdiscount = IsNull(CASE WHEN @srecommend <= 100 THEN adiscount ELSE sdiscount END,0)
	FROM dbo.custsetting (nolock)
	WHERE custid =@custid AND bettype=1	AND sporttype=1 
	IF (@@rowcount=0 or @@error<>0) 
	BEGIN
		SET @transid=-1
		SET @result='userinfonotfound'
	END
	ELSE
	BEGIN
		IF @betfrom NOT IN ('p')
		BEGIN
			IF @maxbet < @minbet and @maxbet>0 SET @maxbet = @minbet -- if maxbet is lower than minbet (should cause by System Minbet) --> change maxbet to minbet
			IF @stake > @maxbet or @stake < (@minbet/3)
			BEGIN
				SET @transid=-1
				SET @result='stakeproblem'
			END
		END
	END
	
	SET @virtualrate=@virtualrate*@actualrate  
	SET @tpos=@apos+@mpos+@spos

	IF (@tpos>0.95)
	BEGIN
		SET @transid=-2
		SET @result='positiontakingproblem'
	END
	
	SET @stake_to_company=@stake*(1-@tpos)*@virtualrate   

	/*
		@betteam:
			13: HY/HN/AY/AN (keep total bet in bal11/bal10/bal21/bal20)
			24: 1X/12/2X (keep total bet in com1total/comxtotal/com2total)
			26: b/o/n( keep total bet in com1total/comxtotal/com2total)
			28: 1/X/2 (keep total bet in com1total/comxtotal/com2total)
	*/	
	IF UPPER(@betteam) in ('1X', 'B', '1')
	BEGIN
		UPDATE dbo.odds WITH (ROWLOCK, UPDLOCK) 
		SET	
			@autobookie = 0,
			com1total = CASE 
				WHEN @betfrom IN ('p') THEN com1total 
				WHEN @autobookie = 1 THEN 0 
				WHEN @odds <= 1.5 THEN com1total+@stake_to_company
				ELSE com1total+@stake_to_company*(@odds-1) END
		WHERE oddsid = @OddsID
	END
	ELSE IF UPPER(@betteam) in ('12', 'O', 'X')
	BEGIN
		UPDATE dbo.odds with (ROWLOCK, UPDLOCK)
		SET 
			@autobookie = 0,
			comxtotal = CASE 
						WHEN @betfrom IN ('p') THEN comxtotal 
						WHEN @autobookie = 1 THEN 0 
						WHEN @odds <= 1.5 THEN comxtotal+@stake_to_company
						ELSE comxtotal+@stake_to_company*(@odds-1) END
		WHERE oddsid = @OddsID
		
	END
	ELSE IF UPPER(@betteam) in ('2X', 'N', '2')
	BEGIN
		UPDATE dbo.odds with (ROWLOCK, UPDLOCK)
		SET 
			@autobookie = 0,
			com2total = CASE 
						WHEN @betfrom IN ('p') THEN com2total 
						WHEN @autobookie = 1 THEN 0 
						WHEN @odds <= 1.5 THEN com2total+@stake_to_company
						ELSE com2total+@stake_to_company*(@odds-1) END
		WHERE oddsid = @OddsID
	END
	ELSE IF UPPER(@betteam) in ('HY', 'HN', 'AY', 'AN') --HY/HN/AY/AN  bal11/bal10/bal21/bal20)
	BEGIN
		UPDATE dbo.odds with (ROWLOCK, UPDLOCK)
		SET 
			bal11 = CASE WHEN @betteam='HY' THEN bal11+@stake_to_company ELSE bal11 END,
			bal10 = CASE WHEN @betteam='HN' THEN bal10+@stake_to_company ELSE bal10 END,
			bal21 = CASE WHEN @betteam='AY' THEN bal21+@stake_to_company ELSE bal21 END,
			bal20 = CASE WHEN @betteam='AN' THEN bal20+@stake_to_company ELSE bal20 END
		WHERE oddsid = @OddsID

	END
	
	IF (@transid=0 and @temp_error=0)
	BEGIN
		SET @temp_error=@@error
		IF (@temp_error<>0)
		BEGIN
			set @http_ref='error update'
		END
		if (@temp_error=0 and @odds<>0) 
		begin      

			declare @err int  
			if (@betfrom NOT IN ('p') and @liveindicator=1) 
			begin       
				set @status= case when @newoffersetup=1 then 'running' else 'waiting' end 
			end 
			else 
			begin 
				set @status='running'
			end 
			set @statusID = case when @status='running' then 0 else 1 end       

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
			0, isnull(@hdp1,0), isnull(@hdp2,0), CASE WHEN @betfrom = 'p' THEN round(@odds,3) ELSE round(@odds,2) END,
			@stake, @status,  @livehomescore, @liveawayscore,
			@liveindicator, @betfrom, @betteam,  @creator, 100000000000 ,
			@tpos, @apos, @mpos, @spos,
			@playerdiscount, @adiscount, @mdiscount, @sdiscount, @actualrate, @virtualrate,
			@matchid,@recommend,@mrecommend,@srecommend, 0, 0,
			@bettype,@currency, @actual_stake, 
			@matchdate, @http_ref, @Bet_ip, @Username, @CurrencyName,
			'', @oddstype, @statusID
			);
			set @err=@@error;
			select @transid=scope_identity() 
		end       
		else      
		begin      
			set @transid=-2
			set @result='odds-changed'
		end      
	end


SELECT @str =
		CASE @betfrom 
		WHEN 'p' THEN 'phone'
		WHEN 'h' THEN 'mobile'
		WHEN 'w' THEN 'wap'
		when 'd' THEN 'deposit'
		WHEN 'm' THEN 'dep-wap'
		WHEN 'i' THEN 'internet'
		WHEN 't' THEN 'test'
		ELSE 'unknown (' + @betfrom + ')' END
		+ N' betting custid:' + cast(isnull( @custid,0) as nvarchar(10))
		+ N' insert bet oddsid:' +  cast(isnull( @oddsid,0) as nvarchar(10)) 
		+ N' at ' + CASE WHEN @betfrom = 'p' THEN CONVERT(nvarchar(10),CAST(round(isnull(@odds,0),3) as float)) 
					ELSE CONVERT(nvarchar(10),CAST(round(isnull(@odds,0),2) as float)) END + '(' + @ugroup + ')'
		+ N' (org:' + CONVERT(nvarchar(10),CAST(isnull(@OriginalOdds,0) as float)) + ')'
		+ N' bet ' + cast(isnull(@betteam,'x') as nvarchar(10))
		+ N' stake:' + CONVERT(nvarchar(50),isnull(@stake,0)) 
		+ N' transid:' +cast(isnull( @transid,0) as nvarchar(10)) 
		+ N' ip:' + cast(isnull(@BET_IP,'x') as nvarchar(16)) 
		+ N' NBC:' + CAST(@BetCredit - @actual_stake as nvarchar(50)) 
		+ N' (' + CAST(DATEDIFF(millisecond, @StartTime, CURRENT_TIMESTAMP) as nvarchar(50)) + ' ms) ' + @site
		+ N' creatorid:' + cast(isnull( @creator,0) as nvarchar(10))
	exec dbo.logfile @custid, @str

--==========================
FINISH:
--==========================

SELECT
	IsNull(@result,'') result, @transid transid, @newodds newodds, @liveindicator liveindicator

	SET NOCOUNT OFF
END

GO
GRANT EXECUTE ON [dbo].[Dot_Member_PlaceBet_Simple_13_24_26_28] TO [Dot_Member]