USE [ON_USER]
GO
/****** Object:  StoredProcedure [dbo].[UserLoginRecord_out]    Script Date: 03/25/2008 23:42:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[UserLoginRecord_out]
	@custid int,
	@sessionid int,

	@LogID int = 0 OUTPUT
AS
	DELETE FROM userlogin with (rowlock) WHERE custid = @custid
	INSERT INTO userlogin (custid, sessionid) VALUES (@custid, @sessionid)

	SELECT @LogID = SCOPE_IDENTITY()

GO
GRANT EXECUTE ON [dbo].[UserLoginRecord_out] TO [bodbExAdminNet]
GO
GRANT EXECUTE ON [dbo].[UserLoginRecord_out] TO [Dot_Admin]
GO
GRANT EXECUTE ON [dbo].[UserLoginRecord_out] TO [Dot_Member]