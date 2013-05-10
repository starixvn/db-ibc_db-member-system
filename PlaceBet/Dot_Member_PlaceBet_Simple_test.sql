USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Member_PlaceBet_Simple]    Script Date: 03/20/2010 04:29:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Dot_Member_PlaceBet_Simple]
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
	SET NOCOUNT ON
	if @betfrom NOT IN ('p','h') SET @creator = @custid
	Declare @temp_rowcount int, @temp_error int
	Declare @continue tinyint SET @continue = 1
	Declare @result varchar(50), @transid int, @newodds float, @DBOdds smallmoney
	Declare @newoffer bit, @newstake money, @stdstake money
	Declare @NewOdds1a float,@NewOdds2a float
	Declare @thdp1 float, @thdp2 float
	Declare @tlivehomescore tinyint,@tliveawayscore tinyint
	Declare @leagueid int, @teamid int, @oddsclosed tinyint
	Declare @eventdate smalldatetime, @actual_stake float,@hometotal float,@awaytotal float
	Declare @sitetype nvarchar(10), @addspread float, @stake_to_company float,@diffbalance float,@betstake float,@gapodds float
	Declare @oddsstatusnew nvarchar(50),@odds1a float,@odds2a float,@newoffersetup bit,@status nvarchar(12)
	Declare @starttime datetime,@risk float,@stakerange float,@com1 float,@com2 float
	Declare @str nvarchar(500)

	Declare @oldchangetime datetime
	Declare @newchangetime datetime
	Declare @gapodds1 float
	Declare @gapodds2 float
	Declare @allowance2 float --autobookie gapodds: bet team home - bet team away
	set @oldchangetime = CURRENT_TIMESTAMP
	set @newchangetime = CURRENT_TIMESTAMP
	set @gapodds1 = 0
	set @gapodds2 = 0
	set @allowance2 = 0

-- Special requirement
-- Vivi@2009-3-27: input parameter not correct(when open 2 browser use 2 account), re-get data again, when RD tem find out reason will remove.
	select @username=username, @autosuspend=isnull(autosuspend,0), @currency=currency,
		@srecommend=isnull(srecommend,0), @mrecommend=isnull(mrecommend,0), @recommend=isnull(recommend,0)
	from custinfo with (nolock) where custid = @custid;

--Thien@2009-08-06: fix the wrong inputted time '12:00:00' into winlostdate field on Member Wap system
set @matchdate = convert(varchar(10), @matchdate, 120)


set @transid=0
set @gapodds=0
set @temp_error=0
set @starttime=CURRENT_TIMESTAMP
Declare
		@apos smallmoney, @mpos smallmoney, 
		@spos smallmoney, @tpos smallmoney,
		@minbet money, @maxbet money,
		@playerdiscount decimal(9,8), @adiscount decimal(9,8), 
		@mdiscount decimal(9,8), @sdiscount decimal(9,8)

Declare @CustSettingBettype tinyint
Declare @CustSettingSporttype tinyint

		set @CustSettingBettype = case 
										WHEN @bettype=12 then 2  --20080620: Get Fulltime OE for 1st OE (Thien)
										WHEN @sporttype in (3,26) and @bettype = 7 then 1 --Football don't have 1st half setting, get from Fulltime
										WHEN @sporttype in (3,26) and @bettype = 8 then 3
										WHEN @sporttype = 11 and @bettype = 3 then 1 --Motorsport (11) don't have OverUnder (3) setting, get from HDP (1)
										WHEN @bettype = 22 THEN 1 --20090205: Next Goal(22) don't have setting, get from HDP (1) vivi
										WHEN @bettype NOT IN (1,2,3,4,5,6,7,8,9,10,20,21,22) THEN 2
										else @bettype end
		set @CustSettingSporttype = CASE WHEN @sporttype=26 THEN 3 
			WHEN @sporttype NOT IN (1,2,3,5,8,10,11,26) THEN 99
							 ELSE @sporttype END
	SELECT
		@apos = IsNull(CASE @sporttype WHEN 1 THEN case @liveindicator when 1 then CASE @bettype WHEN 2 THEN apositiontaking ELSE alivepositiontaking END else apositiontaking end ELSE apositiontaking END,0),		@mpos = IsNull(CASE @sporttype WHEN 1 THEN case @liveindicator when 1 then CASE @bettype WHEN 2 THEN mpositiontaking ELSE mlivepositiontaking END else mpositiontaking end ELSE mpositiontaking END,0),
		@spos = CASE
				WHEN @srecommend <= 100 THEN 0
				ELSE IsNull(CASE @sporttype WHEN 1 THEN case @liveindicator when 1 then CASE @bettype WHEN 2 THEN spositiontaking ELSE slivepositiontaking END else spositiontaking end ELSE spositiontaking END,0)
				END,
		@minbet = IsNull(minbet,0),
		@maxbet = IsNull(maxbet,0),
		@playerdiscount = IsNull(playerdiscount,0),
		@adiscount = IsNull(discount,0),
		@mdiscount = IsNull(adiscount,0),
		@sdiscount = IsNull(CASE WHEN @srecommend <= 100 THEN adiscount ELSE sdiscount END,0)
	FROM dbo.custsetting (nolock)
	WHERE custid =@custid 
		AND bettype=@CustSettingBettype		
		AND sporttype=@CustSettingSporttype 
if (@@rowcount=0 or @@error<>0) 
begin
	set @transid=-1
	set @result='userinfonotfound'
end
else
	begin
		if @betfrom NOT IN ('p','h')
		begin
			IF @bettype NOT IN (1,3,7,8)	set @minbet = @minbet / 3
			if @stake > @maxbet or @stake < @minbet
			begin
				set @transid=-1
				set @result='stakeproblem'
			end
		end
	end



--select @transid=-9
/*----Special requirement---------------------------by Boss-----------------------------------


	IF @srecommend = 185849 AND @bettype IN (1, 2)
		SELECT
			@minbet = CASE WHEN @minbet < 1000 THEN 100 ELSE @minbet END,
			@maxbet = CASE WHEN @maxpermatch <= 200000 THEN @maxpermatch
				WHEN @maxbet > 200000 THEN 200000
				ELSE @maxbet END
------------*/
------------------------------------------------------------------------------

-- 2009-4-5(Michael): Virtual Currency to apply only to these bettype  1,3,7,8,5,15,20 (Vivi)
if @bettype in (2,12)
begin
	set @virtualrate = @actualrate
end
else
begin
	set @virtualrate = @virtualrate * @actualrate
end

set @tpos=@apos+@mpos+@spos
if (@tpos>0.95)
	begin
		set @transid=-2
		set @result='positiontakingproblem'
	end
set @stake_to_company=@stake*(1-@tpos)*@virtualrate   
 
if @transid = 0
begin
	if @betteam='h'       
	begin      
	 ----auto bookie update ----    
		  update odds with (rowlock,updlock)       
		  set 
			@gapodds1 = gapodds1,
			@gapodds2 = gapodds2,
			--@allowance2 = allowance2,
			@gapodds = CASE
	     	when @betfrom IN ('p','h')
				then 0 
			when @stake_to_company + IsNull(diffbalance, 0) >= risk + ((stakerange-risk)/2)
				then gapodds1
			when @stake_to_company + IsNull(diffbalance, 0) >= risk
				then gapodds2
	     	else
				0
			end,
		   @Odds1a=odds1a=(case     
			  when abs(odds1a-@gapodds)>1 then 2-abs(odds1a-@gapodds) else odds1a-@gapodds   
			 end),      
		   @Odds2a=odds2a=(case       
			  when abs(odds2a+@gapodds)>1 then -(2-abs(odds2a+@gapodds)) else odds2a+@gapodds
			 end), 
			@Oldchangetime = changetime,
			@Newchangetime = changetime =	CASE 
									when @betfrom IN ('p','h') then changetime
									when @stake_to_company+diffbalance>=risk then CURRENT_TIMESTAMP
		     						else changetime
								end,
		   @DiffBalance = diffbalance=	case 
											when @betfrom IN ('p','h') and @currency <> 20 then 0
											when @stake_to_company+diffbalance>=risk then 0 
											else diffbalance+@stake_to_company 
										end,
			--allowance=case when  @stake_to_company+diffbalance>=risk then  diffbalance+@stake_to_company else 0 end,      
		@oddsstatusnew = oddsstatus = CASE 
			when (@odds1a >= 0 AND @odds1a < 0.02) OR (@OriginalOdds >= 0 AND @odds1a < 0) then 'closed' 
			when @odds1a < 0 AND @odds1a > maxodds then 'closed' 
			when @odds2a < 0 AND @odds2a > maxodds then 'closed' 
			when @odds1a >= 0 AND @odds1a < minodds then 'closed' 
			when @odds2a >= 0 AND @odds2a < minodds then 'closed' 
			when autobookie  = 0 AND @gapodds > 0 then 'suspend' 
			when autosuspend = 1 AND @autosuspend = 1 then 'suspend' 
			else oddsstatus END,
			@hometotal=hometotal=hometotal+@stake_to_company*case when 
		   abs(@odds)>1 then abs(@odds) else 1 end , 
		  @newoffersetup=newoffersetup 
		  where 
		   oddsid=@oddsid and round(@OriginalOdds,3)=round(odds1a,3)

		   set @temp_rowcount=@@rowcount      
		   set @temp_error =@@error
			set @newodds=@Odds1a      
	   		if (@temp_rowcount=0)      
			begin
				set @transid=-2
				set @result='Odds-changed'
			end
		
	end        
	else      
	begin      
		  
		   update odds with (rowlock,updlock)       
		   set  
			@gapodds1 = com1,
			@gapodds2 = com2,
			--@allowance2 = allowance2,
			@gapodds = CASE
	     	when @betfrom IN ('p','h')
				then 0
			when @stake_to_company - IsNull(diffbalance, 0) >= risk2 + ((stakerange2-risk2)/2)
				then com1
			when @stake_to_company - IsNull(diffbalance, 0) >= risk2
				then com2
	     	else
				0
			end,    
		   @Odds2a = odds2a=(case       
				when abs(odds2a-@gapodds)>1 then 2-abs(odds2a-@gapodds) else odds2a-@gapodds  end),      
		   @Odds1a = odds1a=(case       
				when abs(odds1a+@gapodds)>1 then -(2-abs(odds1a+@gapodds)) else odds1a+@gapodds end),   
			@Oldchangetime = changetime,
			@Newchangetime = changetime = CASE 
							when @betfrom IN ('p','h') then changetime
							when @stake_to_company-diffbalance>=risk2 then CURRENT_TIMESTAMP
		     				else changetime
						 end,    
			@DiffBalance = diffbalance=	case 
											when @betfrom IN ('p','h') and @currency <> 20 then 0
											when (@stake_to_company-diffbalance)>=risk2 then 0 
											else diffbalance-@stake_to_company 
										end,
			--allowance2=case when (@stake_to_company-diffbalance)>=risk2 then  diffbalance-@stake_to_company else 0 end,      
			@oddsstatusnew=oddsstatus = CASE
					when (@odds2a >= 0 AND @odds2a < 0.02) OR (@OriginalOdds >= 0 AND @odds2a < 0) then 'closed'
					when @odds1a < 0 AND @odds1a > maxodds then 'closed'
					when @odds2a < 0 AND @odds2a > maxodds then 'closed'
					when @odds1a >= 0 AND @odds1a < minodds then 'closed'
					when @odds2a >= 0 AND @odds2a < minodds then 'closed'
					when autobookie  = 0 AND @gapodds <> 0 then 'suspend'
					when autosuspend = 1 AND @autosuspend = 1 then 'suspend'
					else oddsstatus end,
	 		@awaytotal=awaytotal=awaytotal+@stake_to_company*case when abs(@odds)>1 then abs(@odds) else 1 end,
	 		@newoffersetup=newoffersetup      
	   		where       
	    		oddsid=@oddsid        
	    		and round(@OriginalOdds,3)=round(odds2a,3)       
			 
	    		set @temp_rowcount=@@rowcount      
	    		set @temp_error =@@error  
				set @newodds=@Odds2a    
	    	if (@temp_rowcount=0)      
			begin
				set @transid=-2
				set @result='Odds-changed'
			end     
		
	end 
end

-- autobookie
/*
IF IsNull(@gapodds, 0) <> 0 and (@liveindicator=1)
BEGIN
	-- if odds change in more than one second
	IF DATEDIFF(s, @Oldchangetime, @Newchangetime) > 1
	BEGIN
		-- reset allowance2
		update odds with (rowlock,updlock)       
		set allowance2 = CASE WHEN @betteam='h' THEN @gapodds ELSE @gapodds*-1 END
		where oddsid = @oddsid
	END
	ELSE
	BEGIN
		IF (ABS(@allowance2+CASE WHEN @betteam='h' THEN @gapodds ELSE @gapodds*-1 END) >= (@gapodds1*2+@gapodds2))
		BEGIN
			-- suspend odds, clear allowance2, write log
			update odds with (rowlock,updlock)       
			set allowance2 = 0, oddsstatus = 'suspend'
			where oddsid = @oddsid

			select @str = 'Autobookie_Activated and suspend b/c too many autobookie in 1 sec matchid:' + CAST(@matchid as nvarchar(50)) + ' oddsid:' + CAST(@oddsid as nvarchar(50))
			exec dbo.logfile @custid, @str
		END
		ELSE
		BEGIN
			update odds with (rowlock,updlock)       
			set allowance2 = allowance2 + CASE WHEN @betteam='h' THEN @gapodds ELSE @gapodds*-1 END
			where oddsid = @oddsid
		END
	END
END
*/

-- vivi@2010-3-4
-- autobookie check, either odds go lower than 0.02, or odds been switch between positive to negative
IF CASE 
	when @betteam = 'h' AND ( (@odds1a >= 0 AND @odds1a < 0.02) OR (@OriginalOdds >= 0 AND (@odds1a < 0)) ) THEN 1
	when @betteam = 'a' AND ( (@odds2a >= 0 AND @odds2a < 0.02) OR (@OriginalOdds >= 0 AND (@odds2a < 0)) ) THEN 1
	ELSE 0 END
	= 1
BEGIN
	UPDATE odds with (rowlock, updlock)
	SET
		odds1a = 0, odds2a = 0,
		changetime = CURRENT_TIMESTAMP
	WHERE oddsid = @oddsid
	
	select @str = 'Autobookie matchid:' + CAST(@matchid as nvarchar(50)) + ' oddsid:' + CAST(@oddsid as nvarchar(50)) + ' either odds go lower than 0.02, or odds been switch between positive to negative, update odds1a,odds2a to zero'
	exec dbo.logfile @custid, @str
END

IF IsNull(@gapodds, 0) <> 0
BEGIN
	select @str = 'Autobookie_Activated matchid:' + CAST(@matchid as nvarchar(50)) + ' oddsid:' + CAST(@oddsid as nvarchar(50)) + ' bettype:' + CAST(@bettype as nvarchar(20)) + ' betteam:' + @betteam + ' gap:' + CONVERT(nvarchar(10), @gapodds) + ' odds1:' + CONVERT(nvarchar(10), @Odds1a) + ' odds2:' + CONVERT(nvarchar(10), @Odds2a) + ' status:' + @oddsstatusnew
	exec dbo.logfile @custid, @str
	
	----Autosuspend 1st odds, dead ball only	
	UPDATE odds with (rowlock,updlock)
		SET oddsstatus = 'suspend'
	WHERE matchid = @matchid 
		AND bettype = CASE @bettype WHEN 1 THEN 7 WHEN 3 THEN 8 ELSE 0 END
		AND liveindicator = 0
		AND ISNULL(autoreject,1) = 1
		AND oddsstatus NOT IN ('closed','closeprice','internal')
		
		if (@@ROWCOUNT > 0)
		BEGIN
			select @str = 'Auto suspend 1st odds by ft autobookie matchid:' + CAST(@matchid as nvarchar(50)) + ' ft oddsid:' + CAST(@oddsid as nvarchar(50)) + ' bettype:' + CAST(@bettype as nvarchar(20))
			exec dbo.logfile @custid, @str
		END
END

if (@transid=0 and @temp_error=0)      
begin      
	set @temp_error=@@error      
	if (@temp_error<>0)      
		set @http_ref='error update'

	if (@temp_error=0 and @odds<>0)      
	begin      
		declare @err int  
		if (@betfrom NOT IN ('p','h') and @liveindicator=1)       
		begin       
			set @status= case when @newoffersetup=1 then 'running' else 'waiting' end      
		end       
		else      
		begin      
			set @status='running'      
		end       

		SET @actual_stake = CASE WHEN @odds < 0 THEN ABS(@odds) * @stake ELSE @stake END


		insert bettrans 
		( 
		custid, oddsid, oddsspread, hdp1, hdp2,odds, stake, status, livehomescore, liveawayscore, liveindicator, betfrom, 
		betteam, creator, refno, tpositiontaking, apositiontaking, mpositiontaking, spositiontaking,
		playerdiscount, discount, adiscount, sdiscount, actualrate, virtualrate,
		matchid, recommend, mrecommend, srecommend, scomm, swinlost,
		bettype, currency, actual_stake, winlostdate, transdesc, ip, Username, CurrencyName, betcheck, oddstype) 
		values 
		(
		@custid ,@oddsid, 
		0, @hdp1, @hdp2,@odds,
		@stake, @status,  @livehomescore, @liveawayscore,
		@liveindicator, @betfrom, @betteam,  @creator, 100000000000 ,
		@tpos, @apos, @mpos, @spos,
		@playerdiscount, @adiscount, @mdiscount, @sdiscount, @actualrate, @virtualrate,
		@matchid,@recommend,@mrecommend,@srecommend, 0, 0,
		@bettype,@currency, @actual_stake, 
		@matchdate, @http_ref, @Bet_ip, @Username, @CurrencyName,
		'df(' + convert(nvarchar(20), CAST(IsNull(@diffbalance,-55) as money)) + ')(' + convert(nvarchar(10), IsNull(@risk,-55)) + '/' + convert(nvarchar(10), IsNull(@stakerange,-55)) + '/' + convert(nvarchar(10), IsNull(@com1,-1)) + ':' + convert(nvarchar(10), IsNull(@com2,-1)) + ')',
		@oddstype
		); set @err=@@error;      
		select @transid=scope_identity() 
       
		if (@err<>0)      
		begin      
			update odds with (rowlock,updlock)      
			set       
			hometotal=hometotal-@hometotal,      
			awaytotal=awaytotal-@awaytotal      
			where oddsid=@oddsid;      
    
			set @transid=-3
			set @result='failed-bet'       
		end       
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
		WHEN 'h' THEN 'phone-hedge'
		WHEN 'w' THEN 'wap'
		when 'd' THEN 'deposit'
		WHEN 'm' THEN 'dep-wap'
		WHEN 'i' THEN 'internet'
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

--==========================
FINISH:
--==========================

SELECT
	IsNull(@result,'') result, @transid transid, @newodds newodds, @liveindicator liveindicator

	SET NOCOUNT OFF

GO
GRANT EXECUTE ON [dbo].[Dot_Member_PlaceBet_Simple] TO [Dot_Member]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_PlaceBet_Simple] TO [ITTim]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_PlaceBet_Simple] TO [ITVivi]
GO
GRANT ALTER ON [dbo].[Dot_Member_PlaceBet_Simple] TO [twteam]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_PlaceBet_Simple] TO [vnteam]