ALTER PROCEDURE [dbo].[Dot_Member_Confirm3rd]
	@transid int,
	@IsSuccess bit,		-- 0:failed (reject), 1:accept (running)
	@refno bigint = 0,	-- reference id return from 3rd party
	@LogMsg nvarchar(200) = '',	-- for log 3rd party reject message
	@refno2 bigint = 0,	-- reference id return from 3rd party (bettype 43 place)
	@refno3 varchar(20) = '' -- reference id return from 3rd party (open tote)
AS
BEGIN
	SET NOCOUNT ON;

	Declare @custid int, @bettype tinyint
	
	IF @IsSuccess = 1
	BEGIN		
		UPDATE dbo.bettrans with (ROWLOCK, UPDLOCK)
		SET
			@custid = custid,
			[status] = N'running', 
			refno = CASE @refno WHEN 0 THEN refno ELSE @refno END,
			ruben = 0,
			betid = case when @refno2 = 0 then betid else @refno2 end,
			betcheck = case when @refno3 = '' then betcheck else @refno3 end
		WHERE transid = @transid AND [status] in (N'waiting', N'reject')
	END
	ELSE
	BEGIN
		UPDATE dbo.bettrans with (ROWLOCK, UPDLOCK)
		SET
			@custid = custid,
			@bettype = bettype,
			[status] = N'reject',
			winlost = actual_stake,
			awinlost = 0, mwinlost = 0, swinlost = 0,
			playercomm = 0, comm = 0, acomm = 0, scomm = 0,
			ruben = 1,
			transdesc = @LogMsg + ' ' + transdesc
		WHERE
			transid = @transid AND [status] = N'waiting'

		IF @bettype IN (33, 43)
			UPDATE dbo.bettransm with (ROWLOCK, UPDLOCK)
			SET [status] = N'reject', winlost = stake, ruben = 1
			WHERE refno = @transid AND custid = @custid
	END

	Declare @LogData nvarchar(300)
	SET @LogData = '3rd_Result transid:' + CAST(@transid as nvarchar(20)) 
		+ ' Success:' + CAST(@IsSuccess as nvarchar(10)) 
		+ ' FailedMsg:' + @LogMsg
		+ ' RefNo:' + CAST(@refno as nvarchar(30))
		+ ' RefNo2:' + CAST(@refno2 as nvarchar(30))
		+ ' RefNo3:' + CAST(@refno3 as varchar(20))
	EXEC dbo.LogFile @custid, @LogData
END

GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_Confirm3rd] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[Dot_Member_Confirm3rd] TO [Dot_Member]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_Confirm3rd] TO [ITTim]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_Confirm3rd] TO [ITVivi]