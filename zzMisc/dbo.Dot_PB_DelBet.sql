 ALTER PROCEDURE [dbo].[Dot_PB_DelBet]
	@transid int,
	@UserID int, --custid of Admin
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
BEGIN
--	Phonebetting: Delete ticket (copy from account site del bet sp: Acc_BettransDelBet)

	SET NOCOUNT ON;

	DECLARE @LogData NVARCHAR(200)
	
	-- check ticket
	IF not exists (select * from bettrans with (nolock) where transid = @transid and [status] in (N'running',N'waiting'))
	BEGIN
		Select @ErrMsg = 'Invalid bet transaction!!', @ErrCode = 103
		Return
	END

	-- update odds hometotal or awaytotal
	update odds set 
		hometotal=hometotal-(case when b.betteam='h' then case when abs(b.odds)>1 then b.stake*b.virtualrate*abs(b.odds)*(1-b.tpositiontaking) else b.stake*b.virtualrate*(1-b.tpositiontaking) end  else 0 end ),
		awaytotal=awaytotal-(case when b.betteam='a' then case when abs(b.odds)>1 then b.stake*b.virtualrate*abs(b.odds)*(1-b.tpositiontaking) else b.stake*b.virtualrate*(1-b.tpositiontaking) end  else 0 end ) 
	from odds o with (nolock)
		inner join bettrans b with (nolock) on o.oddsid=b.oddsid
	where b.transid = @transid

	-- backup ticket
	INSERT INTO zzzbettrans
		(transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype)
	SELECT
		 transid, custid, CURRENT_TIMESTAMP, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype
	FROM
		bettrans with (nolock)
	WHERE
		transid = @transid
	
	-- update ticket to void
	UPDATE bettrans with (rowlock,updlock)
	SET winlost = actual_stake,
		ruben = 1,
		status = 'Void', 
		creator = @UserID,
		awinlost = 0, mwinlost = 0, swinlost = 0, 
		playercomm = 0, comm  = 0, acomm = 0, scomm = 0
	WHERE transid = @transid
	
	-- write log
	SELECT @LogData = 'PB delete transaction for transid:' + cast(@transid as varchar(10))+ ' by_login:' + cast(@UserID as varchar(10))
	EXEC WriteLog_UserLog @UserID = @UserID, @Doing = @LogData

END


GO
GRANT VIEW DEFINITION ON [dbo].[Dot_PB_DelBet] TO [vnteam]