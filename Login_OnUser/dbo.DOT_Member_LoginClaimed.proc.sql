USE [ON_USER]
GO
/****** Object:  StoredProcedure [dbo].[DOT_Member_LoginClaimed]    Script Date: 03/25/2008 23:07:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[DOT_Member_LoginClaimed]
	@custid int,
	@TicketID int,
	@ServerID int = 0 OUTPUT,
	@IP nvarchar(15),
	@ServerIP nvarchar(15) = '',
	@URL nvarchar(200) = '',

	@Result int OUTPUT,
	@Site varchar(50) = '' OUTPUT
AS
	EXEC dbo.UserLoginClaimed_out @custid, 0, @TicketID, @Result OUTPUT
	IF @Result = 1
	BEGIN
		/* 20080129 Single Domain : Return to indicate which site members belong to */
		Declare @currency tinyint, @agSite varchar(50)
		SELECT @currency = c.currency, @agSite = ag.Site
		FROM bodb02.dbo.custinfo c (nolock)
			INNER JOIN bodb02.dbo.customer ag (nolock)
			ON c.roleid = 1 and ag.roleid = 2 and c.recommend = ag.custid
		WHERE c.custid = @custid

		IF @agSite = 'BEST-ODDS' AND @currency IN (15,22,33,34) SET @Site = 'INDO'
		ELSE IF @agSite = 'BEST-ODDS' SET @Site = 'IBC'
		ELSE SET @Site = @agSite

		-- Search for ServerID by ServerIP
		Declare @dbServerID int
		SELECT @dbServerID = ServerID
		FROM dbo.ServerLists (nolock)
		WHERE [site] = @Site AND MachineID = dbo.ip2machine(@ServerIP) AND [site] NOT IN ('spotico')

		IF @@ROWCOUNT > 0 SET @ServerID = @dbServerID

		-- First Entry check-in
		EXEC dbo.DOT_Member_CheckIn @custid, @ServerID, @IP, @Result OUTPUT

		-- Log
		Declare @LogData nvarchar(300)
		SET @LogData = 'Customer:' + CAST(@custid as nvarchar(30)) + ' enter to Server:' + CAST(@ServerID as nvarchar(30)) + '(' + @ServerIP + ') via IP:' + @IP + ' URL:' + @URL
		EXEC [LOG].bodb02.dbo.Dot_LogFile @custid, @LogData

	END


GO
GRANT EXECUTE ON [dbo].[DOT_Member_LoginClaimed] TO [Dot_Member]