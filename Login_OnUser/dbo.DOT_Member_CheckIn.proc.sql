USE [ON_USER]
GO
/****** Object:  StoredProcedure [dbo].[DOT_Member_CheckIn]    Script Date: 03/25/2008 23:41:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[DOT_Member_CheckIn]
	@custid int,
	@ServerID int,
	@IP nvarchar(15),
	@SessionID int = 0 OUTPUT
AS
	SET NOCOUNT ON

	Declare @on_userid int
	DELETE FROM dbo.ON_USER WHERE custid = @custid
	INSERT INTO dbo.ON_USER (on_sessionid, custid, serverid, IP)
	VALUES (0, @custid, @ServerID, @IP)
	SELECT @SessionID = scope_identity()

	UPDATE dbo.ON_USER
	SET on_sessionid = @SessionID
	WHERE custid = @custid

GO
GRANT EXECUTE ON [dbo].[DOT_Member_CheckIn] TO [Dot_Member]