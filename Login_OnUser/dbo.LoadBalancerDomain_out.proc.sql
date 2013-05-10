USE [ON_USER]
GO
/****** Object:  StoredProcedure [dbo].[LoadBalancerDomain_out]    Script Date: 03/25/2008 23:43:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[LoadBalancerDomain_out]
	@site nvarchar(10),
	@Domain nvarchar(50),

	@_ServerID int OUTPUT,
	@_URL nvarchar(50) OUTPUT,
	@_DomainURL nvarchar(50) OUTPUT
AS

IF @Site = 'IBCBET' SET @Site = 'IBC'

IF LEN(SUBSTRING(@Domain,PATINDEX('%.%',@Domain),100)) <= 5
	SET @Domain = 'www.' + @Domain

Declare @Target nvarchar(50)
--IF EXISTS (SELECT * FROM ServerDomains with (nolock) WHERE [domain] = SUBSTRING(@Domain,PATINDEX('%.%',@Domain) + 1,100) AND site = @site)
SELECT @Target = IsNull(Target, [Domain])
FROM ServerDomains with (nolock)
WHERE 
	[domain] = SUBSTRING(@Domain,PATINDEX('%.%',@Domain) + 1,100)
	AND ((site = @site) OR (site = 'ALL' and @site not in ('k111')))

IF @@ROWCOUNT <> 0
	SELECT
		@_ServerID = ServerID,
		@_URL = URL, 
		@_DomainURL = LEFT(URL,PATINDEX('%.%',URL)) + @Target
	FROM dbo.LoadBalance with (nolock)
	WHERE site = @site

/*	SELECT top 1 q2.ServerID, q2.URL, LEFT(q2.URL,PATINDEX('%.%',q2.URL)) + @Target DOMAINURL FROM (
	SELECT sl.MachineID, SUM(ous.TotalOnline) cnt FROM
	on_user_sum ous with (nolock) INNER JOIN ServerLists sl with (nolock) ON ous.ServerID = sl.ServerID
	GROUP BY sl.MachineID) q1 INNER JOIN 
	(SELECT MachineID, ServerID, URL FROM ServerLists with (nolock) WHERE Site = @Site AND Enabled = 1) q2
	 ON q1.MachineID = q2.MachineID
	ORDER BY q1.cnt
*/
ELSE
	SELECT @_ServerID = -1, @_URL = 'www.google.com', @_DomainURL = 'www.google.com'

GO
GRANT EXECUTE ON [dbo].[LoadBalancerDomain_out] TO [Dot_Member]