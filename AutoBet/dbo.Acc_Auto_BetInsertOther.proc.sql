
USE [bodb02]
GO
/****** Object:  StoredProcedure [Acc_Auto_BetInsertOther]    Script Date: 11/13/2008 10:13:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--'odds-suspend'	: odds is suspend
--'userinfonotfound'	: not found record in custinfo
--'customer-closed'	: customer status is closed
--'oversystemmaxbet'	: stake is more than odds' maxbet
--'match-closed'	: event closed
--'overmaxpermatch'	: member already bet more than maxpermatch
--'creditproblem'	: not enough bet credit
--'stakeproblem'	: stake is not in range of minbet/maxbet
--'data-mismatch'	: bettype -vs- betteam is not in the correct format
--'bet-in-process'	: suspect to be duplicate bet, ignore it.
CREATE PROCEDURE [dbo].[Acc_Auto_BetInsertOther]
	@custid int,
	@ugroup nvarchar(12),
	@oddsid int,
	@betteam nvarchar(10),	
	@stake money,
	@HTTP_REF nvarchar(150),
	@BET_IP nvarchar(20),
	@site nvarchar(50),
	@betfrom nvarchar(10) = 'i',
	@creator int = 0	
AS
	SET NOCOUNT ON
-------Get the latest info @odds,@hdp1,@hdp2,@livehomescore,@liveawayscore
	declare @hdp1 float,@hdp2 float,@odds smallmoney,@livehomescore tinyint,@liveawayscore tinyint,@OriginalOdds smallmoney
	select @hdp1=0.00,@hdp2=0.00,@odds=0,@livehomescore=0,@liveawayscore=0,@OriginalOdds=0
	if(@betteam='outright')
		select @odds=dbo.Acc_Auto_GetOddsInfoOutright(@oddsid)
	else
		exec dbo.Acc_Auto_GetOddsInfoOthers @oddsid,@ugroup,@site,@betteam,@odds output,@hdp1 output,@hdp2 output,@livehomescore output,@liveawayscore output
		
	select @OriginalOdds=@odds	
--------------------------------------------------------------------------		
	Declare @StartTime datetime SET @StartTime = CURRENT_TIMESTAMP
	IF @betfrom NOT IN ('p','h') SET @creator = @custid

	Declare @continue tinyint SET @continue = 1
	Declare @result nvarchar(50), @transid int, @newodds smallmoney, @DBOdds smallmoney
	Declare @newoffer bit, @newstake money, @stdstake money

	Declare @matchid int, @sporttype tinyint, @oddsstatus nvarchar(50), @liveindicator bit, @oddsmaxbet money, @bettype tinyint, @autobookie bit
	Declare @leagueid int, @teamid int, @oddsclosed tinyint
	Declare @eventdate smalldatetime
	Declare @sitetype nvarchar(10), @addspread float
	

IF @betfrom NOT IN ('p','h') AND @stake < 0 SELECT @continue = 0, @result = 'stakeproblem'
IF @odds = 0 SELECT @continue = 0, @result = 'odds-suspend'
-- Get Odds Information
IF @continue = 1
BEGIN
	SELECT
		@sitetype = IsNull([type], ''),
		@addspread = CASE
			WHEN @ugroup IN ('a','hka') THEN spreada
			WHEN @ugroup IN ('b','hkb') THEN spreadb
			WHEN @ugroup IN ('c','hkc') THEN spreadc
			WHEN @ugroup IN ('d','hkd') THEN spreadd
			WHEN @ugroup IN ('e','hke') THEN spreade
			WHEN @ugroup IN ('f','hkf') THEN spreadf END
	FROM dbo.site (nolock) WHERE [site] = @site
	IF @sitetype IS NULL SET @sitetype = ''

	IF @betteam = 'outright'
		SELECT @eventdate = eventdate, @leagueid = leagueid, @teamid = teamid, @oddsstatus = oddsstatus, @oddsmaxbet = maxbet, @bettype = 10, @sporttype = 1, @liveindicator = 0, @oddsclosed = CASE WHEN DATEADD(second,-10,kickofftime) < CURRENT_TIMESTAMP THEN 1 ELSE 0 END
		FROM dbo.outright with (nolock) WHERE orid = @oddsid
	ELSE IF @bettype IN (1, 2, 3, 7, 8, 20)
	BEGIN
		SELECT @matchid = matchid, @sporttype = sporttype, @oddsstatus = oddsstatus, @liveindicator = liveindicator, @oddsmaxbet = maxbet, @bettype = bettype
		FROM dbo.odds (nolock) WHERE oddsid = @oddsid
		print @bettype
		print @matchid
	END
	ELSE
		SELECT @matchid = matchid, @sporttype = sporttype, @oddsstatus = oddsstatus, @liveindicator = liveindicator, @oddsmaxbet = maxbet, @bettype = bettype, @autobookie = autobookie,
			@DBOdds = CASE
			WHEN bettype IN (4, 16, 14) THEN
				CASE @betteam
				WHEN '00' THEN cs00 WHEN '01' THEN cs01 WHEN '02' THEN cs02 WHEN '03' THEN cs03 WHEN '04' THEN cs04 WHEN '05' THEN cs05
				WHEN '10' THEN cs10 WHEN '11' THEN cs11 WHEN '12' THEN cs12 WHEN '13' THEN cs13 WHEN '14' THEN cs14
				WHEN '20' THEN cs20 WHEN '21' THEN cs21 WHEN '22' THEN cs22 WHEN '23' THEN cs23 WHEN '24' THEN cs24
				WHEN '30' THEN cs30 WHEN '31' THEN cs31 WHEN '32' THEN cs32 WHEN '33' THEN cs33 WHEN '34' THEN cs34
				WHEN '40' THEN cs40 WHEN '41' THEN cs41 WHEN '42' THEN cs42 WHEN '43' THEN cs43 WHEN '44' THEN cs44
				WHEN '50' THEN cs50
				END
			WHEN bettype IN (5, 15) THEN
				CASE @betteam
				WHEN '1' THEN com1
				WHEN 'X' THEN comX
				WHEN '2' THEN com2
				END
			WHEN bettype = 6 THEN
				CASE @betteam
				WHEN '0-1' THEN cs00
				WHEN '2-3' THEN cs01
				WHEN '4-6' THEN cs10
				ELSE cs11 END
			END
		FROM dbo.odds (nolock) WHERE oddsid = @oddsid
	

	IF @@ROWCOUNT = 0 SELECT @continue = 0, @result = 'odds-suspend'
	IF (@betfrom NOT IN ('p','h')) AND (@oddsstatus <> 'running') SELECT @continue = 0, @result = 'odds-suspend'
	IF @bettype = 10 AND @oddsclosed = 1 SELECT @continue = 0, @result = 'match-closed'
END

IF @continue = 1
BEGIN
	IF NOT (
	(@bettype IN (1, 2, 3, 7, 8, 20) AND @betteam in ('h','a')) OR
	(@bettype IN (5, 15) AND @betteam in ('1','x','2')) OR
	(@bettype = 6 AND @betteam in ('0-1','2-3','4-6','7-over')) OR
	(@bettype IN (4, 16, 14) AND @betteam in ('00','01','02','03','04','05',
		'10','11','12','13','14',
		'20','21','22','23','24',
		'30','31','32','33','34',
		'40','41','42','43','44','50')) OR
	(@bettype IN (9, 10))
	)
		SELECT @continue = 0, @result = 'data-mismatch'
END

-- Get User Information
IF @continue = 1
BEGIN
	Declare @closed bit, @credit money, @autosuspend bit, @maxpermatch money, @matchlimit smallmoney, @currency tinyint,
		@recommend int, @mrecommend int, @srecommend int, @Username nvarchar(50), @VirtualMultiplier smallmoney, @virtualrate float,
		@reject bit

	SELECT
		@Username = username,
		@closed = IsNull(closed,1), @credit = IsNull(credit,0), @autosuspend = IsNull(autosuspend,0), @currency = currency,
		@recommend = IsNull(recommend,0), @mrecommend = IsNull(mrecommend,0), @srecommend = IsNull(srecommend,0),
		@matchlimit = IsNull(matchlimit, 1),
		@VirtualMultiplier = IsNull(VirtualMultiplier, 1),
		--Thien@20080109: New MaxPerMatch
		@maxpermatch = IsNull(CASE @sporttype 
			WHEN 1 THEN maxpermatch 
			WHEN 2 THEN maxpermatch2
			WHEN 3 THEN maxpermatch3
			WHEN 5 THEN maxpermatch5
			WHEN 8 THEN maxpermatch8
			WHEN 10 THEN maxpermatch10
			WHEN 11 THEN maxpermatch11
			WHEN 12 THEN maxpermatch12
			ELSE maxpermatch99 END, 0),
		@reject = reject
	FROM dbo.custinfo (nolock)
	WHERE custid = @custid AND roleid = 1
	IF @@ROWCOUNT = 0 SELECT @continue = 0, @result = 'userinfonotfound'

	Declare @actualrate float, @eminbet money, @CurrencyName nvarchar(10)
	SELECT
		@CurrencyName = currency,
		@actualrate = actualrate,
		@virtualrate = CASE
			WHEN @betfrom IN ('p','h') THEN actualrate
			ELSE @VirtualMultiplier * actualrate END,
		@eminbet = CASE @liveindicator WHEN 1 THEN minbetlive ELSE minbet END
	FROM dbo.exchange (nolock) WHERE exchangeid = @currency

	IF @betfrom NOT IN ('p','h') AND @closed = 1 SELECT @continue = 0, @result = 'customer-closed'
	IF @currency IN (25,26,27,28,29) SELECT @oddsmaxbet = @oddsmaxbet / 2 -- half rate currency
	--IF @bettype IN (1,3,7,8,10) AND 
	IF @betfrom NOT IN ('p','h') AND (@stake * @actualrate) > @oddsmaxbet SELECT @continue = 0, @result = 'oversystemmaxbet' 
END

IF @continue = 1 AND (
	   @recommend in (805700, 175009, 105561)
	or @mrecommend in (43803, 495957, 577857) 
	or @srecommend in (584472, 824789, 324565, 546837, 838269, 837894, 888286)
	or (@srecommend = 450036 AND NOT (
		@mrecommend IN (689003,761965,805562,894197,724002,937440) OR
		@recommend  IN (776687,833343,664484,937427,855323,854339)
		)) -- 05/24 (yuan)
)
	SELECT @continue = 0, @result = 'odds-suspend'


--2008-06-12: Suspend feature (Thien)
IF @continue = 1 AND @reject = 1
	SELECT @continue = 0, @result = 'odds-suspend'
-------------

Declare @NewWay bit -- NewWay = 1 uses BetCredit, = 0 uses normal way
SET @NewWay = 1

	-- new credit check
Declare @BetCredit money

IF @continue = 1 AND @NewWay = 1
BEGIN
	IF ABS(@actualrate * @stake) > 5000
		EXEC dbo.Dot_Member_BetCreditRecal @custid, @BetCredit OUTPUT
	ELSE
		EXEC dbo.Dot_Member_BetCreditCheck @custid, @BetCredit OUTPUT

	IF (@betfrom NOT IN ('p','h')) AND 
		(@BetCredit - CASE 
			WHEN @odds < 0 THEN @stake * ABS(@odds)
			ELSE @stake
			END < 0)
		SELECT @continue = 0, @result = 'creditproblem'
END

	-- match check (max per match)
IF @continue = 1 and @betfrom NOT IN ('p','h')
BEGIN
	Declare @LimitValue money
	
	IF @bettype = 10
		EXEC dbo.Dot_Member_MatchCheck_Outright
			@custid, @stake, @maxpermatch,
			@leagueid,
			@continue OUTPUT, @result OUTPUT
	ELSE
	BEGIN
		Declare @effectiveStake money
		SET @effectiveStake = CASE WHEN @odds < -1 THEN ABS(@odds) ELSE 1 END * @stake

		EXEC dbo.Dot_Member_MatchCheck 
			@custid, @effectiveStake, @maxpermatch,
			@matchid, @liveindicator,
			@continue OUTPUT, @result OUTPUT, @eventdate OUTPUT
	END

END
ELSE
BEGIN
	IF @bettype <> 10 SELECT @eventdate = eventdate FROM match WHERE matchid = @matchid
END

	-- credit check
IF @continue = 1 AND @betfrom NOT IN ('p','h') AND @NewWay = 0
BEGIN
	SELECT @BetCredit = IsNull(@credit,0) + IsNull(SUM(winlost - actual_stake + playercomm),0) FROM dbo.bettrans (nolock) WHERE custid = @custid

	IF IsNull(@BetCredit,0) - CASE WHEN @odds < 0 THEN @stake * ABS(@odds) ELSE @stake END < 0
		SELECT @continue = 0, @result = 'creditproblem'
END

-- Get Agent Setting for this ticket
IF @continue = 1
BEGIN
	Declare
		@apos smallmoney, @mpos smallmoney, @spos smallmoney, @tpos smallmoney,
		@minbet money, @maxbet money,
		@playerdiscount decimal(9,8), @adiscount decimal(9,8), @mdiscount decimal(9,8), @sdiscount decimal(9,8)

	SELECT
		@apos = IsNull(CASE WHEN (@sporttype=1 AND  @liveindicator=1 AND @bettype<>2) then alivepositiontaking 		                   ELSE apositiontaking                                                     END,0),		@mpos = IsNull(CASE WHEN (@sporttype=1 AND  @liveindicator=1 AND @bettype<>2) then mlivepositiontaking 		                   ELSE mpositiontaking                           
                         END,0),
		@spos = CASE
				WHEN @srecommend <= 100 THEN 0
				ELSE IsNull(CASE WHEN (@sporttype=1 AND  @liveindicator=1 AND @bettype<>2) then slivepositiontaking 		                   ELSE spositiontaking                           
                              END,0)
				END,
		@minbet = IsNull(minbet,0),
		@maxbet = IsNull(maxbet,0),
		@playerdiscount = IsNull(playerdiscount,0),
		@adiscount = IsNull(discount,0),
		@mdiscount = IsNull(adiscount,0),
		@sdiscount = IsNull(CASE WHEN @srecommend <= 100 THEN adiscount ELSE sdiscount END,0)
	FROM dbo.custsetting (nolock)
	WHERE custid = @custid 
		--Thien@20080109: New Position taking 
		AND bettype = CASE
						WHEN @bettype = 15 then 5 --Get Fulltime 1x2 for 1st 1x2
						WHEN @bettype = 16 then 4 --Get Correct Score for HTFT
						WHEN @bettype = 14 then 4 --Get Correct Score for FGLG
						
						WHEN @sporttype = 3 and @bettype = 7 then 1 --Football don't have 1st half setting, get from Fulltime
						WHEN @sporttype = 3 and @bettype = 8 then 3
						
						WHEN @sporttype = 11 and @bettype = 3 then 1 --Motorsport (11) don't have OverUnder (3) setting, get from HDP (1)

						WHEN @sporttype >= 2 AND @bettype in (5,15) THEN 2
						WHEN @bettype NOT IN (1,2,3,4,5,6,7,8,9,10,20,21,22) THEN 2
						ELSE @bettype END
		AND sporttype = CASE WHEN @sporttype NOT IN (1,2,3,5,8,10,11,12) THEN 99
							 ELSE @sporttype END
	

	IF @@ROWCOUNT = 0 SELECT @continue = 0, @result = 'userinfonotfound'

-- special requirement from SI superagent , control minbet to 100,000 maxbet to 200,000,000
	IF @srecommend = 185849 AND @bettype IN (1, 2, 3, 7, 8, 20)
		SELECT
			@minbet = CASE WHEN @minbet < 1000 THEN 100 ELSE @minbet END,
			@maxbet = CASE
				WHEN @maxpermatch <= 200000 THEN @maxpermatch
				WHEN @maxbet > 200000 THEN 200000
				ELSE @maxbet END
END

IF @continue = 1
BEGIN
	IF @bettype NOT IN (1,3,7,8) -- 2006/09/01 From: steven by Mr.Phua -- from /2 to /4
		SELECT @minbet = @minbet / 4, @eminbet = @eminbet / 4
	IF @eminbet > @minbet AND @betfrom not in ('d','m') --Not check eminbet for 12Bet, asiabet88 - deposit site
		SET @minbet = @eminbet  -- if system minbet is grater than agent's minbet --> change minbet to system minbet
	IF @maxbet < @minbet and @maxbet>0 SET @maxbet = @minbet -- if maxbet is lower than minbet (should cause by System Minbet) --> change maxbet to minbet

	IF @betfrom NOT IN ('p','h') AND ((@stake < @minbet) OR (@stake > @maxbet)) SELECT @continue = 0, @result = 'stakeproblem'
END

IF @continue = 1
BEGIN
	IF @bettype IN (1, 2, 3, 7, 8)
	BEGIN
	-- autobookie call
		
			EXEC dbo.Dot_Member_AutoBookie3
			@custid, @creator, @ugroup, @oddsid, @bettype, @betteam, @hdp1, @hdp2, 
			@odds, @OriginalOdds, @livehomescore, @liveawayscore, @stake,
			@actualrate, @virtualrate, @autosuspend, @currency, @eventdate,
			@apos, @mpos, @spos,
			@playerdiscount, @adiscount, @mdiscount, @sdiscount,
			@recommend, @mrecommend, @srecommend,
			@site, @sitetype, @addspread, @HTTP_REF, @BET_IP, @betfrom, @BetCredit, @StartTime,
			@Username, @CurrencyName,
			@transid OUTPUT, @newodds OUTPUT
		
	END
	ELSE IF @bettype = 20
	BEGIN
	-- autobookie call
		EXEC dbo.Dot_Member_AutoBookie20
		@custid, @creator, @ugroup, @oddsid, @bettype, @betteam, @hdp1, @hdp2, 
		@odds, @OriginalOdds, @livehomescore, @liveawayscore, @stake,
		@actualrate, @virtualrate, @autosuspend, @currency, @eventdate,
		@apos, @mpos, @spos,
		@playerdiscount, @adiscount, @mdiscount, @sdiscount,
		@recommend, @mrecommend, @srecommend,
		@site, @sitetype, @addspread, @HTTP_REF, @BET_IP, @betfrom, @BetCredit, @StartTime,
		@Username, @CurrencyName,
		@transid OUTPUT, @newodds OUTPUT
	END
	ELSE IF @bettype = 10
	BEGIN
		EXEC dbo.Dot_Member_Autobookie_Outright
		@custid, @oddsid, @odds, @stake, @actualrate, @virtualrate, @currency, @eventdate,
		@apos, @mpos, @spos,
		@playerdiscount, @adiscount, @mdiscount, @sdiscount,
		@recommend, @mrecommend, @srecommend,
		@HTTP_REF, @BET_IP, @betfrom, @creator,
		@transid OUTPUT, @newodds OUTPUT
	END
	ELSE -- IF @bettype IN (4,5,6)
	BEGIN
		SET @DBOdds = ROUND( @DBOdds ,2,1)

		IF @bettype IN (4, 16, 14)
			SELECT
				@hdp1 = left(@betteam, 1), @hdp2 = right(@betteam, 1),
				@betteam = left(@betteam,1) + ':' + right(@betteam,1)

		SELECT @stdstake = @Stake * (1 - (@apos + @mpos + @spos)) * @virtualrate --@actualrate

		IF @betfrom NOT IN ('p','h') AND (ABS( @Odds - @DBOdds ) > 0.003) -- compare odds
			SELECT @transid = -2, @newodds = round(@DBOdds, 3)
		ELSE
		BEGIN 
			IF @bettype IN (4, 16) EXEC dbo.Dot_OddsUpdCS_AutoBookie @oddsid, @betteam, @stdstake, @newoffer OUTPUT, @newstake OUTPUT
			ELSE IF @bettype = 14 EXEC dbo.Dot_OddsUpdFGLG_AutoBookie @oddsid, @betteam, @stdstake, @newoffer OUTPUT, @newstake OUTPUT
			
			ELSE IF @bettype IN (5, 15) AND @betteam IN ('1','X','2') EXEC dbo.Dot_OddsUpd1x2_AutoBookie @oddsid, @stdstake, @betteam, @newoffer OUTPUT, @newstake OUTPUT
			ELSE IF @bettype = 6 EXEC dbo.Dot_OddsUpdTotalGoal_AutoBookie @oddsid, @betteam, @stdstake, @newoffer OUTPUT, @newstake OUTPUT

			IF @newoffer = 1 AND @betfrom NOT IN ('p','h')
			BEGIN
				SELECT @transid = -2
								
				IF @newstake <> @stdstake SELECT @newstake = Round(@newstake/@virtualrate/(1 - (@apos + @mpos + @spos)),-2,1)

				-- Get New Odds From Database
					SELECT @DBOdds = CASE
					WHEN bettype IN (4, 16, 14) THEN
						CASE @betteam
						WHEN '0:0' THEN cs00 WHEN '0:1' THEN cs01 WHEN '0:2' THEN cs02 WHEN '0:3' THEN cs03 WHEN '0:4' THEN cs04 WHEN '0:5' THEN cs05
						WHEN '1:0' THEN cs10 WHEN '1:1' THEN cs11 WHEN '1:2' THEN cs12 WHEN '1:3' THEN cs13 WHEN '1:4' THEN cs14
						WHEN '2:0' THEN cs20 WHEN '2:1' THEN cs21 WHEN '2:2' THEN cs22 WHEN '2:3' THEN cs23 WHEN '2:4' THEN cs24
						WHEN '3:0' THEN cs30 WHEN '3:1' THEN cs31 WHEN '3:2' THEN cs32 WHEN '3:3' THEN cs33 WHEN '3:4' THEN cs34
						WHEN '4:0' THEN cs40 WHEN '4:1' THEN cs41 WHEN '4:2' THEN cs42 WHEN '4:3' THEN cs43 WHEN '4:4' THEN cs44
						WHEN '5:0' THEN cs50
						END
					WHEN bettype IN (5, 15) THEN
						CASE @betteam
						WHEN '1' THEN com1
						WHEN 'X' THEN comX
						WHEN '2' THEN com2
						END
					WHEN bettype = 6 THEN
						CASE @betteam
						WHEN '0-1' THEN cs00
						WHEN '2-3' THEN cs01
						WHEN '4-6' THEN cs10
						ELSE cs11 END
					END
				FROM dbo.odds (nolock) WHERE oddsid = @oddsid

				SELECT @newodds = @DBOdds
			END
			ELSE -- INSERT BET
			BEGIN
				Declare @betactual_stake money -- actual_stake
				SELECT @betactual_stake = CASE WHEN @odds < 0 THEN ABS(@Odds) * @stake ELSE @Stake END

				EXEC dbo.Dot_Member_BetCreditChange @custid, @betactual_stake

				insert bettrans 
				( 				custid, oddsid, oddsspread, hdp1, hdp2,odds, stake, status, livehomescore, liveawayscore, liveindicator, betfrom, 
				betteam, creator, refno, tpositiontaking, apositiontaking, mpositiontaking, spositiontaking,
				playerdiscount, discount, adiscount, sdiscount, actualrate, virtualrate, matchid, recommend, mrecommend, srecommend, scomm, swinlost,
				bettype, currency, actual_stake, winlostdate, transdesc, ip, betcheck) 
				values 
				(
				@custid ,@oddsid, 
				0, IsNull(@hdp1, 0), IsNull(@hdp2, 0), @odds,
				@stake, 'running',  0, 0,
				0, @betfrom, @betteam,  @creator, 100000000000 ,
				(@apos + @mpos + @spos), @apos, @mpos, @spos,
				@playerdiscount, @adiscount, @mdiscount, @sdiscount, @actualrate, @virtualrate,
				@matchid, @recommend, @mrecommend, @srecommend, 0, 0,
				@bettype, @currency, @betactual_stake, 
				@eventdate, @HTTP_REF, @BET_IP, 
				''
				); select @transid=scope_identity()

				--COMMIT TRANSACTION

				declare @from nvarchar(50)
				SELECT @from = CASE @betfrom 
					WHEN 'p' THEN 'phone'
					WHEN 'h' THEN 'phone-hedge'
					WHEN 'w' THEN 'wap'
					WHEN 'd' THEN 'deposit'
					WHEN 'm' THEN 'dep-wap'
					WHEN 'i' THEN 'internet'
					ELSE 'unknow (' + @betfrom + ')' END

				declare @str nvarchar(500)
				select @str=@from + N' betting custid:' + cast(isnull( @custid,'x') as nvarchar(10)) + N' insert bet oddsid:' +  cast(isnull( @oddsid,'x') as nvarchar(10)) + N' at ' + CONVERT(nvarchar(10),CAST(isnull(@odds,0) as float)) + '(' + @ugroup + ') bet ' + cast(isnull(@betteam,'x') as nvarchar(10))  +  N' stake:' + CONVERT(nvarchar(50),isnull(@stake,0)) + N' transid:' +cast(isnull( @transid,'x') as nvarchar(10)) + N' ip:' + cast(isnull(@BET_IP,'x') as nvarchar(16)) + N' NBC:' + CAST(@BetCredit - @betactual_stake as nvarchar(50)) + ' (' + CAST(DATEDIFF(millisecond, @StartTime, CURRENT_TIMESTAMP) as nvarchar(50)) + ' ms) ' + @site
				exec logfile  @custid,@str
			END -- new offer OR insert bet
		END -- odds changed OR continues (to autobookie)
	END -- bettype selection of CONTINUE
END	

IF @bettype IN (1, 2, 3, 7, 8, 20)
	SELECT
		IsNull(@result,'') result, @transid transid, @newodds newodds, @liveindicator liveindicator
ELSE
	SELECT
		IsNull(@result,'') result, @transid transid, @newodds newodds, @liveindicator liveindicator,
		@newoffer NewOffer, @newstake NewStake

SET NOCOUNT OFF
GO
GRANT EXECUTE ON [dbo].[Acc_Auto_BetInsertOther] TO [Dot_Member]
GO





