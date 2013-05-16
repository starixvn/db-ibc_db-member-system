ALTER PROCEDURE [dbo].[Dot_Admin_CheckEventDateParlay]
@MatchID	INT,
@Eventdate	DATETIME,
@ErrCode	INT = 0 OUTPUT,
@ErrMsg		NVARCHAR(200)='' OUTPUT 
AS
/*
	Created by:Jamie 
	Date: 20100728
	Task: Check the max eventdate of match before updating 
	DB: DBTXN/BODB02 
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE	@MinWinlostdate	DATETIME, 
			@BalanceUpDate	DATETIME, 
			@MaxEventdate	DATETIME 

	DECLARE	@tmpRefno TABLE( refno BIGINT)
	DECLARE	@tmpMatch TABLE( matchID INT)
	
	INSERT INTO @tmpRefno(refno)
	SELECT	refno
	FROM	bettransm WITH (NOLOCK)
	WHERE	matchID = @MatchID
	
	IF @@ROWCOUNT = 0 RETURN 

	INSERT INTO @tmpMatch(matchID)
	SELECT	DISTINCT matchID 
	FROM(
		SELECT  MatchID, refno
		FROM	bettransm WITH (NOLOCK)
		UNION   
		SELECT  MatchID, refno
		FROM	bettransm14 WITH (NOLOCK)
	)bm
	INNER JOIN	@tmpRefno r ON bm.refno= r.refno 

	--Get MIN Date
	SELECT	@MinWinlostdate= MIN(eventdate)
	FROM (
		SELECT	m.matchid, m.eventdate
		FROM	match m WITH (NOLOCK) 
		UNION ALL
		SELECT	m14.matchid, m14.eventdate
		FROM	match14 m14 WITH (NOLOCK) 
	) m
	INNER JOIN	@tmpMatch t ON m.matchid = t.matchid 

	SELECT	TOP 1 @BalanceUpDate = Winlostdate 
	FROM	Bettrans WITH (NOLOCK) 
	WHERE	Bettype = 20000 AND MatchID = 0 AND custid = 3 

	-- BalanceUp Date -> Week 1 --> Week 2 ---> 
	IF	@MinWinlostDate < DATEADD(DAY,7,@BalanceUpDate) --Week 1 
		SELECT	@MaxEventDate = DATEADD(DAY,11,@BalanceUpDate)
	ELSE
	BEGIN 
		IF @MinWinlostDate < DATEADD(DAY,14,@BalanceUpDate)	--Week 2 
			SELECT	@MaxEventDate = DATEADD(DAY,18,@BalanceUpDate)
		ELSE SELECT @MaxEventDate = DATEADD(DAY,25,@BalanceUpDate)
	END 

	IF	@Eventdate > @MaxEventDate 
	BEGIN
		SELECT	@ErrCode = 100, 
				@ErrMsg = 'Event date cannot be greater than ' + CONVERT(VARCHAR(10),@MaxEventDate,120)
							 +'. Please create a new match instead! '
	END
END 
GO
GRANT EXECUTE ON [dbo].[Dot_Admin_CheckEventDateParlay] TO [Dot_Admin]
GO
GRANT EXECUTE ON [dbo].[Dot_Admin_CheckEventDateParlay] TO [vnteam]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Admin_CheckEventDateParlay] TO [vnteam] 