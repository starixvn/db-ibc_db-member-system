USE [ON_USER]
GO
/****** Object:  StoredProcedure [dbo].[DOT_Member_LoginRecord]    Script Date: 03/25/2008 23:03:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[DOT_Member_LoginRecord]
	@custid int,
	@site nvarchar(10),
	@Domain nvarchar(50),

	@TicketID int = 0 OUTPUT,
	@RedirHOST nvarchar(100) = '' OUTPUT
AS
	Declare @_ServerID int,
			@_URL nvarchar(100)

	IF @site NOT IN ('k111', 'spotico', '12bet')
	BEGIN
		Declare @currency tinyint, @agSite varchar(50)
		SELECT @currency = c.currency, @agSite = ag.Site
		FROM bodb02.dbo.custinfo c (nolock)
			INNER JOIN bodb02.dbo.customer ag (nolock)
			ON c.roleid = 1 and ag.roleid = 2 and c.recommend = ag.custid
		WHERE c.custid = @custid

		IF @agSite = 'BEST-ODDS' AND @currency IN (15,22,33,34) SET @Site = 'INDO'
		ELSE IF @agSite = 'BEST-ODDS' SET @Site = 'IBC'
		ELSE SET @Site = @agSite
	END

	EXEC dbo.LoadBalancerDomain_out @Site, @Domain,
			@_ServerID OUTPUT, @_URL OUTPUT,
			@RedirHOST OUTPUT

	IF @_ServerID = -1 and @site NOT IN ('12bet')
		SET @TicketID = 0
	ELSE
		EXEC dbo.UserLoginRecord_out @custid, 0, @TicketID OUTPUT

GO
GRANT CONTROL ON [dbo].[DOT_Member_LoginRecord] TO [Dot_Member]
GO
GRANT EXECUTE ON [dbo].[DOT_Member_LoginRecord] TO [Dot_Member]