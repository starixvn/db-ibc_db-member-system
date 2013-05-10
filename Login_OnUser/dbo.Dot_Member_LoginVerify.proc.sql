USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Member_LoginVerify]    Script Date: 04/21/2010 10:01:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Dot_Member_LoginVerify]
	@username varchar(50),
	@password nvarchar(50),
	@Site nvarchar(50),
	@ServerID int,
	@IP nvarchar(15),
	@from nvarchar(200),
	@Country nvarchar(2) = NULL,

	@_CustID int = 0 OUTPUT,
	@_ResCode tinyint = 0 OUTPUT,
	@_Result nvarchar(150) = '' OUTPUT,
	@_UseNickName bit = 0 OUTPUT	-- indicate whether use nickname to login or not
AS
SET NOCOUNT ON
/* ResCode Table
0  : Success
10 : User_Not_Found
30 : Not_Customer (roleid <> 1)
20 : A/C_Closed (closed = 1)
25 : Wrong_Domain (@Site <> @AgSite)
40 : Wrong Password
45 : Too_Often
50 : IP_Denied
*/
	Declare @custid int, @recommend int, @mrecommend int, @srecommend int,
			@roleid tinyint, @currency tinyint, @ugroup nvarchar(5),
			@closed bit, @AgSite nvarchar(50)
	Declare @db_userpwd nvarchar(50), @failedcount tinyint, @LastLogin datetime
	Declare @ResCode tinyint, @Result nvarchar(150), @LogData nvarchar(300)
	Declare @on_sessionid int
	Declare @IsAllow bit, @IsException bit,
		@countryShort nvarchar(2), @countryLong nvarchar(64)
	Declare @UseNickName bit -- for @_UseNickName
	
	SELECT @ResCode = 0, @Result = '', @IsAllow = 1, @IsException = 0, @UseNickName=0

	-- Get custid + other information (seek by username)
	
if @site not in ('12bet','asiabet88')
		SELECT
			@custid = i.custid,
			@closed = i.closed,
			@recommend = i.recommend, @mrecommend = i.mrecommend, @srecommend = i.srecommend,
			@currency = i.currency,
			@roleid = IsNull(i.roleid, 0),
			@db_userpwd = IsNull(c.userpwd,''),
			@ugroup = c.ugroup,
			@failedcount = IsNull(c.logincount,0),
			@LastLogin = IsNull(c.lastlogged, DATEADD(hour, -1, CURRENT_TIMESTAMP))
			,@UseNickName = CASE @username WHEN i.username THEN 0 ELSE 1 END
		FROM dbo.custinfo i with (nolock) inner join dbo.customer c with (nolock)
		on i.custid=c.custid
		where (c.username = @username or c.username2 = @username) 
				and isnull(i.srecommend,-9999) not in (select custid from dbo.f_DepSuper_1('ALL')) --exclude deposit users
	else
		SELECT
			@custid = i.custid,
			@closed = i.closed,
			@recommend = i.recommend, @mrecommend = i.mrecommend, @srecommend = i.srecommend,
			@currency = i.currency,
			@roleid = IsNull(i.roleid, 0),
			@db_userpwd = IsNull(c.userpwd,''),
			@ugroup = c.ugroup,
			@failedcount = IsNull(c.logincount,0),
			@LastLogin = IsNull(c.lastlogged, DATEADD(hour, -1, CURRENT_TIMESTAMP))
			,@UseNickName = CASE @username WHEN i.username THEN 0 ELSE 1 END
		FROM dbo.custinfo i with (nolock) inner join dbo.customer c with (nolock)
		on i.custid=c.custid
		where (i.username = @username)
			--and isnull(i.srecommend,-9999) in (select custid from dbo.f_DepSuper_1(@site)) -- include deposit users

	-- username not found
	IF @@ROWCOUNT = 0
		SELECT
			@ResCode = 10, @Result = 'Username not found. Please check your spelling.',
			@custid = 0,
			@LogData = 'Customer:' + @username + ' IP:' + @IP + ' Failed(User_Not_Found) SID:' + CAST(@ServerID as nvarchar(20)) + ' From:' + @From
	-- verify Role, closed status, Site, password, Often Login
	ELSE IF @roleid <> 1
		SELECT
			@ResCode = 30, @Result = 'This is not your place.',
			@custid = 0,
			@LogData = 'Customer:' + @username + ' IP:' + @IP + ' Failed(Not_Customer) SID:' + CAST(@ServerID as nvarchar(20)) + ' From:' + @From
	ELSE IF IsNull(@closed, 1) = 1
		SELECT
			@ResCode = 20, @Result = '<b>Your A/C was Closed</b>, Please contact your Agent.',
			@LogData = 'Customer:' + @username + ' IP:' + @IP + ' Failed(A/C_Closed) SID:' + CAST(@ServerID as nvarchar(20)) + ' From:' + @From

	-- Check IP/Country Control
	SELECT @AgSite = Site
	FROM dbo.customer with (nolock)
	WHERE custid = @recommend

	IF @ResCode = 0
	BEGIN
		IF (@currency = 20) -- UUS test currency , allow from everywhere
			Set @countrySHORT = '--'
		ELSE IF LEFT(@IP, 10) IN ('202.78.231','202.78.228') -- VN Office, Full Allow
			Set @countrySHORT = 'VN'
		ELSE IF LEFT(@IP, 10) = '61.28.176.' -- PH Office, Allowed  : Added 20070526 by Joe
			SET @countrySHORT = 'PH'
		ELSE
		BEGIN
			IF @Country IS NULL
				EXEC IPDB.dbo.GetIPInfo_out @IP, @countrySHORT OUTPUT, @countryLONG OUTPUT
			ELSE
				SET @countrySHORT = @Country

		-- COUNTRY CONTROL RULES PLACE HERE : Check to "Deny" (Set @IsAllow = 0)

			/* COUNTRY CHECK RULE : Default value is @IsAllow = 1 */
			SET @IsAllow = CASE
				WHEN @countrySHORT = '--' THEN 0-- no country info in database.
			WHEN @custid = 328018 AND @countrySHORT = 'MY' AND CURRENT_TIMESTAMP < '06 MAY 2010' THEN 1 -- request by Mr.Lam
			WHEN @custid = 2065115 AND @IP = '219.134.230.252' AND CURRENT_TIMESTAMP < '3 March 2010' THEN 1 -- Allow until 3 March (58.61.117.227/58.61.40.157)
			WHEN @custid = 2143339 AND @countrySHORT IN ('SG','MY') THEN 1 -- Joe requested MP4RMB71827 (permanent) 6 Feb 10
			WHEN @custid = 1825650 AND @countrySHORT = 'SG' THEN 1 --KR9701888 : Wan, allow SG:20081014
			WHEN @custid = 1640060 AND @countrySHORT = 'HK' THEN 1 -- exception of 755
			WHEN @custid = 172721 AND @IP = '124.122.121.222' THEN 1 -- CSD111 Requested on 20 Feb 2010 (Banana)
			WHEN @custid = 2065115 AND @IP = '58.60.31.183' THEN 1 -- Chris (CSD) Requested on 19 March 2010 until 25 March 2010
			WHEN @currency IN (4,43) AND @AgSite = '755555' AND @countrySHORT IN ('TH','LA','MM') THEN 1
			WHEN @currency IN (4,43) AND @AgSite = '611111' AND @countrySHORT IN ('CN','HK','MO') THEN 1
			WHEN @currency IN (4,43) AND @AgSite = '755555' AND @countrySHORT NOT IN ('TH','LA','MM') THEN 0
			WHEN @currency IN (4,43) AND @AgSite = '611111' AND @countrySHORT NOT IN ('CN','HK','MO') THEN 0

			WHEN @countrySHORT = 'SG' AND @mrecommend IN (161627,125373,288827) THEN 1
			WHEN @countrySHORT = 'SG' AND @srecommend IN (726562,726571,726579,1164457,1238537,194355,194356)
	THEN 1
				-- Block from Thailand
			WHEN @countrySHORT = 'TH' AND @currency NOT IN (4,43)
	THEN 0 --block all other currencies, except for Thai currencies
/*--Thien@20100421: comment it out, put one single condition to block all super under other currencies
			WHEN @countrySHORT = 'TH' AND @srecommend IN 
(726562,726571,726579,1164457,238537,194355,712272,194356,391601,951650,1071794,1246023,1349148,
961020,883411,497469,301152,1329464)
	THEN 0 -- Denied from TH for super of HK$
			WHEN @countrySHORT = 'TH' AND @srecommend IN
(642291,897588,1372998,1373748,747037,641918,712439,689767,812045,643456,919892,1349398,1524078,
1177375,981129,1504835,867735,1386293,656135,1124040,720475)
	THEN 0 -- Denied from TH for super of IDD
			WHEN @countrySHORT = 'TH' AND @srecommend IN
(550945,835418,549191)
	THEN 0 -- Denied from TH for super of IN
			WHEN @countrySHORT = 'TH' AND @srecommend IN
(524760,1397026,510159,185849)
	THEN 0 -- Denied from TH for super of IND
			WHEN @countrySHORT = 'TH' AND @srecommend IN
(1407085,1389689,400973,726582,194354,727340,877777,395075,507226,1179547,1300688,1211024,404941,
408317,1456420,1452602,211566,405391,443008,1492016,426131,405017,405422,365484,405975,1016771,
430524,1342397,1317514,1448199,691884,994666,1355380,398615,410722,398437,787938,398467,420966,
407649,753624,796555,1247148,405586,932456,755409,490037,1211237,754114)
	THEN 0 -- Denied from TH for super of RM
			WHEN @countrySHORT = 'TH' AND @srecommend IN
(1146496,898449,1053179,1435492,467362,1148278,842030,266413,344472,800262,687425,942131,479867,
356942,1004318,665985,220846,1402421,477659,447479,1010899,546837,888286,944721,1194834,955286,
946542,1140623,261421,1131889,884262,261425,1136637,450036,457623)
	THEN 0 -- Denied from TH for super of RMB
			WHEN @countrySHORT = 'TH' AND @srecommend IN
(1437908,1248383,976536,194357,394310,433306,409524,431696,1207541,406935,365483,404986,1111902,
1108229,831604,918522,398636,410800,399208,430735,1211027,407731,960134,933476,409422,406808)
	THEN 0 -- Denied from SG for super of SD$
--Thien@20100421*/

				WHEN @countrySHORT =  'PH' AND @srecommend = 1091678 THEN 1 -- Michael : S5P : allowed from PH : 20080918
				WHEN @countrySHORT <> 'PH' AND @srecommend = 1091678 THEN 0 -- Michael : S5P : denied from NOT PH : 20080918
				WHEN @countrySHORT <> 'PH' AND @AgSite = '033333' THEN 0 -- Michael : site 033333 : denied from NOT PH : 20080919
				WHEN @AgSite = 'asiabet88' THEN 1 -- Eddie: do not check county for asiabet88,already check in loginprocess
				WHEN @countrySHORT = 'US' THEN 0

				WHEN @countrySHORT = 'VN'  AND @AgSite <> '789Y' AND @site<>'12bet' THEN 0
				WHEN @countrySHORT <> 'TH' AND @srecommend IN (1190555, 1211966) THEN 0 -- Michael (SBT:20081115), Wan (S222T:20081129) : allowed from TH only
				WHEN @countrySHORT = 'SG'  AND @mrecommend IN (267700,256011,79819,165404,198316,288798,239216,249332,79881,164959,660140,301246,223476,169566,253659) THEN 1
				WHEN @countrySHORT <> 'TH' AND @srecommend IN (938136, 194359) THEN 0 -- Wan : KAT, KT : Allowed only from TH : 20081106
				WHEN @countrySHORT IN ('MY','SG') AND @mrecommend IN (256011,79819,374052,272369,288802 -- Wan : master KR90/M9NC/KR153 : Allowed only from MY/SG (over right below super rule)
				,80380, 164828, 171624, 79861, 161626, 161624, 79811, 79809,138977 -- Wan : master M9E1C/M9F2C/M9O2C/M9OC/M9B2C/M9IC/M9GC/M9R1C : Allowed from MY/SG
				,1212751 -- Wan:SPH11:20081204
				,288836,79877 -- Wan:KR138,M9XC:20090410
				,291151,140805 -- Wan:KR36,M9U1C:20090429
				,79768 -- Wan:M9HH:20091105
				)	THEN 1
				WHEN @countrySHORT <> 'MY' AND @srecommend IN (1164457,726571,726579,194355,194356) THEN 0 -- Wan : KBR/KCR/KDR/KH/KR : Allowed only from MY : 20081106
				WHEN @countrySHORT NOT IN ('HK','CN') AND @srecommend = 712272 THEN 0 -- Wan : KHK : Allowed only from HK/CN : 20081106
				WHEN @countrySHORT NOT IN ('HK','CN','MO') AND @srecommend = 391601 THEN 0 -- Michael : KRC : Allowed only from Macau, Hong Kong & China : 20091231 (Vivi)
				/* commend by Vivi: 20091230
				WHEN @countrySHORT NOT IN ('MY','SG') AND @srecommend IN (726582,726562,896708,913628,395075,1069029,674248,194354,727340,877777,394310)
					THEN 0 -- Wan : KAM/KAR/KHAH/KHBH/KHCH/KHH/KM/KMAM/KMBM/KMM/KSD : Allowed only from MY/SG : 20081106
				*/
				WHEN @countrySHORT NOT IN ('MY','SG','BN') AND @srecommend IN (194354, 194355, 194356, 394310, 395075, 674248 , 726562, 726571, 726579, 726582, 727340, 877777, 896708, 913628, 1069029, 1164457, 1238537)
					THEN 0 -- Wan : kar/kbr/kcr/kdr/ker/kr/ksd/khh/kh/khah/khbh/khch/km/kam/kmm/kmam/kmbm : Allowed only from MY/SG/BN : 20091230 (Vivi)
				WHEN @srecommend IN (1078280, 905146) AND @countrySHORT IN ('SG', 'MY') THEN 0 -- Wan : S56TB, CKT : denied from SG/MY : 20080912
				WHEN @srecommend = 642291 AND @countrySHORT = 'RU' THEN 0
				WHEN @srecommend = 951650 AND @countrySHORT NOT IN ('HK','CN') THEN 0
				WHEN @srecommend IN (985909 ,985911 ,985912 ,987490 ,995996) AND @countrySHORT NOT IN ('TH', 'LA') THEN 0
				WHEN @srecommend IN (1041778,1045966,1517030) AND @countrySHORT IN ('MY', 'SG') THEN 0
				WHEN @mrecommend IN (165404 ,157989)  AND @countrySHORT = 'MY' THEN 1
				WHEN @mrecommend = 161626 AND @countrySHORT = 'SG' THEN 1 -- Wan : M9D2C : allowed from SG : 20080913
				WHEN @custid IN (224718,733072,1174455) AND @IP = '202.151.35.238' THEN 1 --Jane: Fix IP using in office: 20100212 (Vivi)
				WHEN @mrecommend = 674254 AND @IP =   '123.252.80.253' THEN 1
				WHEN @mrecommend = 674254 AND @IP IN ('220.128.103.10','220.128.103.11') THEN 1
				WHEN @mrecommend = 724768 and @IP IN ('202.146.184.226','202.146.184.227','202.146.184.228','202.146.184.229','202.146.184.230','210.4.98.54') THEN 1
				WHEN @IP IN ('211.20.218.93','203.91.135.192') THEN 1 -- request by Fong (tw and hk)
				WHEN @IP IN ('122.117.10.183','122.117.14.20','124.10.211.10','122.117.25.248','122.117.241.99') THEN 1 -- Wan : for TW Agent : 20081016 (Joe)
				WHEN @IP = '202.146.184.194' THEN 1 -- Mr.Bee
				WHEN @IP = '63.218.163.94' THEN 1 -- Bernard office in SG (Fong/Banana 9 June 08)
				WHEN @countrySHORT <> 'TH' AND @srecommend IN (905146, 912272) THEN 0 -- 0506 Michael : allow only from Thailand
				WHEN @countrySHORT IN ('MY', 'SG') AND @recommend = 105561 THEN 1
				WHEN @IP IN ('202.151.35.248','202.151.35.163') THEN 1 -- Erica: mptrmb02001(@mrecommend=561153) is fix ip and login in office at our rcbc floor ,202.151.35.248 kindly add this ip into your list: 20100104(Vivi)
				WHEN @countrySHORT IN ('VN', 'PH', 'TW', 'US', 'MY', 'SG') AND @mrecommend IN (
724768	,480648	,727659	,21048	,199988	,122491	,120909	,301160	,262188	,432310	,
17282	,11910	,674254	,41355	,371646	,97430	,227625	,7019	,7020	,37457	,
664858	,711935	,48410	,252122	,497645	,498725	,121405	,41917	,608443	,563523	,
215478	,691593	,166896	,409843	,587827	,70893	,78703	,216531	,393459	,393463	,
470393	,582134	,674259	,79832	,8009	,166087	,198898	,660994	,5279	,5858	,
660140	,4403	,4691	,4747	,561153	,207739	,6321	,13946	,4357	,4501	,
378259
			)		THEN 0
				WHEN @countrySHORT = 'MY' AND @mrecommend IN (937440, 1230078) THEN 1 -- this rule override rule below for srecommend = 450036
				WHEN @countrySHORT = 'MY' AND @recommend IN (1100619, 1493560) THEN 1 -- over right below rule for srecommend = 301152 :: wan 20080926
				WHEN @countrySHORT IN ('VN', 'PH', 'TW', 'US', 'MY', 'SG') AND @srecommend IN (
467362	,266413	,335748	,463659	,484809	,211568	,344472	,576984	,687425	,479867	,
729244	,356942	,665985	,657896	,220846	,523974	,477659	,447479	,546837	,261421	,
399130	,497469	,301152	,261425	,636678	,711945	,614746	,450036	,457623
			)		THEN 0
				-- Regular Site/Country Control
				WHEN @AgSite IN ('611111', '822222') AND @countrySHORT IN ('MY', 'SG', 'VN') THEN 0 -- for China
				--WHEN @countrySHORT = 'TW' THEN 0
				--WHEN @countrySHORT = 'PH' THEN 0
			ELSE 1 END
		-- END : COUNTRY CONTROL RULES PLACE HERE

			-- If IP Is Bloced, check for exception
			/*
			If @IsAllow = 0
			BEGIN				EXEC IPDB.dbo.Member_CheckException_out @username, @IP, @countrySHORT, @IsException OUTPUT

				IF @IsException = 1 -- IP not Allow, also no Exception
					SET @IsAllow = 1
			END
			*/
			IF @IsAllow = 0
				SELECT	@ResCode = 50,
					@Result = 'You login from unallowed location. [IP:' + @IP + ']',
					@LogData = 'Customer:' + @username + ' IP:' + @IP + ' Failed(IP_Denied:' + @countrySHORT + ') SID:' + CAST(@ServerID as nvarchar(20)) + ',A:' + @AgSite + ',M:' + @Site + ' From:' + @From

		END
	END

	-- check Validity of Site
	IF @ResCode = 0
	BEGIN
		-- Determine if SP is called from WAP login (Dot_WS_Member_ProcessLogin_Out)
		IF LEFT(@from,4) = 'WAP:' AND @AgSite = 'BEST-ODDS' AND @currency IN (15,22,33,34) SET @Site = 'INDO'

		-- comment by Vivi, 2009-12-25 Merry X'mas.
		/*IF (@AgSite IN ('789y', 'spotico') AND @AgSite <> @Site AND @currency <> 20) OR
		   (@AgSite <> '789y' AND @Site = '789y' AND @currency <> 20)
		*/ 
		IF (@AgSite IN ('789y', 'spotico', '033333') AND @AgSite <> @Site AND @currency <> 20) OR
			(@AgSite NOT IN ('789y', 'spotico','033333') AND @Site IN ('789y', 'spotico','033333') AND @currency <> 20)
			SELECT
				@ResCode = 25, @Result = 'Your account not belong to this domain. Please contact your agent for correct web address. ', --(Try ' + CASE @AgSite WHEN 'BEST-ODDS' THEN 'ibcbet' ELSE @AgSite END + '.com)',
				@LogData = 'Customer:' + @username + ' IP:' + @IP + ' Failed(Wrong_Domain,A:' + @AgSite + ',M:' + @Site + ') SID:' + CAST(@ServerID as nvarchar(20)) + ' From:' + @From
	END

	-- check password
	IF @ResCode = 0
	BEGIN
		IF @db_userpwd <> @password
		BEGIN
			SELECT
				@ResCode = 40, @Result = 'Wrong Password. Failed count = ' + CAST(@failedcount as nvarchar(2)),
				@failedcount = @failedcount + 1,
				@LogData = 'Customer:' + @username + ' IP:' + @IP + ' Failed(Password) SID:' + CAST(@ServerID as nvarchar(20)) + ' From:' + @From

			IF @failedcount > 5
				UPDATE custinfo with (UPDLOCK,rowlock) SET closed = 1 WHERE custid = @custid
			ELSE
				UPDATE customer with (UPDLOCK,rowlock) SET logincount = @failedcount WHERE custid = @custid
		END
		ELSE IF DATEDIFF(second, @LastLogin, CURRENT_TIMESTAMP) < 30
			SELECT
				@ResCode = 45, @Result = '',
				@LogData = 'Customer:' + @username + ' IP:' + @IP + ' Failed(Too_Often) SID:' + CAST(@ServerID as nvarchar(20)) + ' From:' + @From
	END

	IF @ResCode = 0 -- not face any error
	BEGIN
		-- Record/Replace ON_USER
		--EXEC [ON].on_user.dbo.Dot_SessionMember @custid, @SessionID, @ServerID, 'F'
		--EXEC [ON].on_user.dbo.DOT_Member_CheckIn @custid, @ServerID, @IP, @_SessionID OUTPUT

		-- Update Customer Record
		UPDATE customer with (UPDLOCK,rowlock)
		SET logincount = 0, iplogin = @IP, lastlogged = CURRENT_TIMESTAMP
		WHERE custid = @custid

		SET @LogData = 'Customer:' + @username + ' IP:' + @IP + ':' + @countrySHORT + CASE @IsException WHEN 1 THEN '(E)' ELSE '' END + ' Success SID:' + CAST(@ServerID as nvarchar(20)) + ',A:' + @AgSite +  ',M:' + @Site +  ' From:' + @From

		-- Add Extra INFO back to RESULT for WAP Login SP (Dot_WS_Member_ProcessLogin_Out) to identify INDO member
		IF LEFT(@From,4) = 'WAP:' AND @Site = 'INDO' SET @Result = 'INDO'
	END

	EXEC dbo.logfile @custid, @LogData
	SELECT	@_ResCode = @ResCode,
		@_CustID = @custid,
		@_Result = @Result,
		@_UseNickName = @UseNickName



GO
GRANT EXECUTE ON [dbo].[Dot_Member_LoginVerify] TO [Dot_Member]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_LoginVerify] TO [ITTim]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_LoginVerify] TO [ITVivi]
GO
GRANT ALTER ON [dbo].[Dot_Member_LoginVerify] TO [twteam]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_LoginVerify] TO [vnteam]