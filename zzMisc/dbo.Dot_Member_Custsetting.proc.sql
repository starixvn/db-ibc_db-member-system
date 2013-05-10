USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Member_Custsetting]    Script Date: 12/16/2009 01:12:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Dot_Member_Custsetting]
	@custid int,
	@sporttype int,
	@bettype int
AS
-- WS: Dot_WS_Member_Custsetting

	SET NOCOUNT ON

--IF @@SERVERNAME = 'DB02'
--	EXEC DB04_LINK.bodb02.dbo.Dot_member_custsetting @custid, @sporttype, @bettype
--ELSE
BEGIN -- host selection

	Declare @CustSettingSporttype tinyint
	Declare @CustSettingBettype tinyint

	SET @CustSettingSporttype = case		
		when @sporttype = 26 then 3		-- Football(3) for Rugby(26) (Vivi)
		when @sporttype NOT IN (1,2,3,5,8,10,11,151,201) then 99
		else @sporttype end

	SET @CustSettingBettype = case
		when @bettype between 51 and 56 then 3						--Get Over/Under for Financial bettype from 51 to 56 (Thien)
		when @bettype between 61 and 66 then 2						--Get Odd/Even for Financial bettype from 61 to 66 (Thien)
		
		when @sporttype in (3,26) AND @bettype = 7 then 1	--Get Fulltime Handicap for 1st Handicap
		when @sporttype in (3,26) AND @bettype = 8 then 3	--Get Fulltime Over/Under for 1st Over/Under
		when @sporttype = 11 AND @bettype = 3 then 1	--Motorsport (11) don't have OverUnder (3) setting, get from HDP (1)
		when @bettype = 15 then 5						--Get Fulltime 1x2 for 1st 1x2
		when @bettype = 12 then 2						--20080620: Get Fulltime OE for 1st OE (Thien)
		when @bettype in (16,14) then 4					--Get CorrectScore for HTFT, FGLG
		when @bettype in (32,33) then 31				--20081223_Thien: Get WIN for PLACE and WIN/PLACE for HorseRacing TOTE
		when @bettype in (42,43) then 41				--20090811_Thien: Get WIN for PLACE and WIN/PLACE for HorseRacing FIXED ODDS
		when @bettype = 22 then 1						--20090205_Vivi:  don't have Next Goal (22) setting, get from HDP (1)
		else @bettype end

	SET  @CustSettingBettype = case
		when @sporttype = 26 and @bettype = 5 then 1	--20090317_Vivi: don't have Rugby(26) FT.1X2 setting, get from Footbal(3)+HDP(1)
		when @CustSettingSporttype >= 2 AND @CustSettingBettype = 5 then 2
		when @CustSettingBettype not in (1,2,3,4,5,6,7,8,9,10,20,21,22,31,41) then 2
		else @CustSettingBettype end

	IF @sporttype IN (151,201) --20091216_Jamie:Get 3rd setting from CustSetting3rd 
	BEGIN
		SELECT
			cs.minbet, cs.maxbet, cs.apositiontaking,
			cs.mpositiontaking, cs.spositiontaking, cs.playerdiscount,
			cs.discount, cs.adiscount, cs.sdiscount 			
		FROM dbo.custsetting3rd cs with (nolock)
		WHERE cs.custid = @custid AND bettype = @CustSettingBettype AND sporttype = @CustSettingSporttype		
	END
	ELSE 
	BEGIN
		SELECT
			cs.minbet, cs.maxbet, cs.apositiontaking,
			cs.mpositiontaking, cs.spositiontaking, cs.playerdiscount,
			cs.discount, cs.adiscount, cs.sdiscount 			
		FROM dbo.custsetting cs with (nolock)
		WHERE cs.custid = @custid AND bettype = @CustSettingBettype AND sporttype = @CustSettingSporttype
	END
END -- host selection
