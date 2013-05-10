ALTER PROCEDURE [dbo].[Dot_Admin_UpdateWinlostDateParlay]
@matchID INT,
@newEventdate DATETIME 
AS
/*	Created by:Jamie
	Date: 20100731
	Task: Update the event date of Parlay tickets when the match's event date updated 
	DB: DB02.BODB02
*/
BEGIN
	SET NOCOUNT ON
	DECLARE	@tmpRefno TABLE (refno BIGINT PRIMARY KEY)
	
	INSERT INTO @tmpRefno(refno)
	SELECT	refno
	FROM	bettransm WITH (NOLOCK)
	WHERE	matchid = @matchID 

	IF @@ROWCOUNT = 0 RETURN
	
	CREATE TABLE #tmpBettrans(
		transID		INT PRIMARY KEY,
		isUpdate	BIT		
	)

	INSERT INTO	#tmpBettrans(
		transID,
		isUpdate
	)
	SELECT	transID,
			CASE WHEN winlostdate < @newEventdate THEN 1 ELSE 0 END 
	FROM	bettrans b WITH (NOLOCK) 	
			INNER JOIN @tmpRefno r ON b.refno = r.refno 
	WHERE	b.bettype = 9 
			AND b.matchid = 9 
			AND b.statusID = 0 

	UPDATE	bettrans WITH (UPDLOCK,ROWLOCK)
	SET		winlostdate = @newEventdate 
	FROM	#tmpBettrans t WITH (NOLOCK) 
	WHERE	bettrans.transid = t.transid 
			AND t.isUpdate = 1 

	DROP TABLE #tmpBettrans
	
END
GO
GRANT EXECUTE ON [dbo].[Dot_Admin_UpdateWinlostDateParlay] TO [Dot_Admin]
GO
GRANT EXECUTE ON [dbo].[Dot_Admin_UpdateWinlostDateParlay] TO [vnteam]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Admin_UpdateWinlostDateParlay] TO [vnteam] 