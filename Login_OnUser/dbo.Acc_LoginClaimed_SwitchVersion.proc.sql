USE [ON_USER]
GO
/****** Object:  StoredProcedure [dbo].[Acc_LoginClaimed_SwitchVersion]    Script Date: 03/09/2010 15:37:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Alter PROCEDURE [dbo].[Acc_LoginClaimed_SwitchVersion]
	@custid int,
	@sessionid varchar(30),
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
     - 20100309@Shifu: check user session when swapping between AccV1 and AccV2
	
Param's Explanation:
• @Result:
    = 0: Invalid logid or sesseionid (didn't login from TW Admin Site or from AccV2)
    = 1: Valid User
    

*/

Declare @db_sessionid varchar(30), @db_logtime datetime

	SELECT @db_sessionid = netsessionid, @db_logtime = reload_time
	FROM on_user with (nolock) WHERE custid = @custid
	
IF @@ROWCOUNT = 0
	SET @Result = 0
ELSE
BEGIN
	-- ticket recorded longer than 10 seconds
	IF DATEDIFF(second, @db_logtime, CURRENT_TIMESTAMP) > 40
		SET @Result = 0
	-- logid not matched  or SessionID not matched
	ELSE IF (@db_sessionid <> @sessionid)
		SET @Result = 0
	ELSE
		SET @Result = 1
		
	DELETE FROM on_user with (rowlock) WHERE custid = @custid
	
END

GO
GRANT EXECUTE ON [dbo].[Acc_LoginClaimed_SwitchVersion] TO [bodbAdminNet]
GRANT VIEW DEFINITION ON [dbo].[Acc_LoginClaimed_SwitchVersion] TO [vnteam]