ALTER PROCEDURE [dbo].[Dot_Admin_UpdateEvent]
	@matchid int,
	@eventstatus nvarchar(50),
	@showtime nvarchar(50),
	@matchcode nvarchar(50),
	@eventdate datetime = null,
	@kickofftime datetime = null,
	@displaymode tinyint = 0,
	@IsNeutral bit = 0,
	@GlobalShowTime smalldatetime = null,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT 
AS
BEGIN
	SET NOCOUNT ON;
	
	-- 20100728@Jamie: Check the max eventdate of match before updating 
	IF @eventdate IS NOT NULL 
	BEGIN
		EXEC [dbo].[Dot_Admin_CheckEventDateParlay] @MatchID=@matchid, @Eventdate=@eventdate, @ErrCode =@ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT 
		IF @ErrCode <> 0 RETURN
	END 

	UPDATE match with (UPDLOCK, ROWLOCK)
	SET eventstatus=@eventstatus,
		showtime=@showtime,
		matchcode=@matchcode,
		eventdate=CASE WHEN @eventdate is null then eventdate else @eventdate end,
		kickofftime=CASE WHEN @kickofftime is null then kickofftime else @kickofftime end,
		displaymode=@displaymode,
		IsNeutral=@IsNeutral,
		GlobalShowTime=CASE WHEN @GlobalShowTime is null then kickofftime else @GlobalShowTime end
	WHERE matchid=@matchid
	
END
GO
GRANT EXECUTE ON [dbo].[Dot_Admin_UpdateEvent] TO [Dot_Admin]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Admin_UpdateEvent] TO [vnteam]