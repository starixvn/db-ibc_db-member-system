USE [ON_USER]
GO
/****** Object:  StoredProcedure [dbo].[UserLoginClaimed_out]    Script Date: 03/25/2008 23:42:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[UserLoginClaimed_out]
	@custid int,
	@sessionid varchar(30),
	@logid int,

	@Result bit OUTPUT
AS
	-- @Result
	-- 0 = claim failed
	-- 1 = claim successful
	
/*
Created:
Task : Validate sessionid and logid of one user when moving from one site to another without login
DB: DB03.ON_USER
Original:

Revisions:
    - 20100305@Shifu: Check sessionid for swapping version between AccV1 and AccV2	
	
Param's Explanation:
• @Result:
    = 0: Invalid logid or sesseionid (didn't login from TW Admin Site or from AccV2)
    = 1: Valid User
    

*/

Declare @db_logid int, @db_sessionid varchar(30), @db_logtime datetime

IF (@sessionid = '0')
BEGIN
	SELECT @db_logid = LogID, @db_sessionid = SessionID, @db_logtime = LogTime
	FROM userlogin with (nolock) WHERE custid = @custid
END
ELSE
BEGIN
	SELECT @db_logid = 0, @db_sessionid = netsessionid, @db_logtime = reload_time
	FROM on_user with (nolock) WHERE custid = @custid
END

IF @@ROWCOUNT = 0
	SET @Result = 0
ELSE
BEGIN
	-- ticket recorded longer than 10 seconds
	IF DATEDIFF(second, @db_logtime, CURRENT_TIMESTAMP) > 40
		SET @Result = 0
	-- logid not matched  or SessionID not matched
	ELSE IF (@db_logid <> @logid) OR (@db_sessionid <> @sessionid)
		SET @Result = 0
	ELSE
		SET @Result = 1
	
	IF(@sessionid = '0')
	BEGIN
		DELETE FROM userlogin with (rowlock) WHERE custid = @custid
	END
	ELSE
	BEGIN
		DELETE FROM on_user with (rowlock) WHERE custid = @custid AND netsessionid = @sessionid
	END
END

GO
GRANT EXECUTE ON [dbo].[UserLoginClaimed_out] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[UserLoginClaimed_out] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[UserLoginClaimed_out] TO [Dot_Admin]