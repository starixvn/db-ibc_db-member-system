ALTER PROCEDURE [dbo].[Dot_Admin_UpdateWinlostDate] 
	@matchid int = 0,
	@neweventdate nvarchar(50) = NULL
AS
-- admin page
-- event/updatestatus.asp
IF @matchid <> 0
BEGIN
	UPDATE bettrans
	SET winlostdate = match.eventdate
	FROM match
	WHERE
		bettrans.matchid = @matchid AND
		bettrans.matchid = match.matchid AND
		winlostdate <> match.eventdate

	--20100731@Jamie:Update Parlay tickets 
	EXEC [dbo].[Dot_Admin_UpdateWinlostDateParlay] @matchID=@matchID, @newEventdate=@newEventdate
END

GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Admin_UpdateWinlostDate] TO [vnteam]