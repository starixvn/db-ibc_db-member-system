CREATE PROCEDURE [dbo].[Acc_Auto_GetOddsInfoOthers]
	@oddsid int, 
	@ugroup nvarchar(12),
	@site nvarchar(50),	
	@betteam nvarchar(10),
	@odds smallmoney output,
	@hdp1 float output,
	@hdp2 float output,
	@livehomescore int output,
	@liveawayscore int output
AS
begin
	Declare @OddsMode tinyint,@sitetype nvarchar(10)	
	SELECT	@sitetype = IsNull([type], '')
	FROM dbo.site (nolock) WHERE [site] = @site	
	-- @OddsMode = 1 : Add points
	IF @sitetype IN ('ADD' , 'DECIADD')
		SET @OddsMode = 1
	ELSE
		SET @OddsMode = 0
		
	SELECT @livehomescore=Isnull(livehomescore,0),@liveawayscore=Isnull(liveawayscore,0),@hdp1=Isnull(hdp1,0),@hdp2=Isnull(hdp2,0),
		@odds=(case 
		           when bettype in(1,2,3,7,8,12,17,18,20) then
						case @OddsMode
							WHEN 0 THEN CASE
								when @ugroup='a' and @betteam='h' then odds1a 
								when @ugroup='b' and @betteam='h' then odds1b 
								when @ugroup='c' and @betteam='h' then odds1c 
								when @ugroup='d' and @betteam='h' then odds1d
								when @ugroup='e' and @betteam='h' then odds1e
								when @ugroup='f' and @betteam='h' then odds1f 
								when @ugroup='hka' and @betteam='h' then odds1hka
								when @ugroup='hkb' and @betteam='h' then odds1hkb
								when @ugroup='hkc' and @betteam='h' then odds1hkc
								when @ugroup='hkd' and @betteam='h' then odds1hkd
								when @ugroup='hke' and @betteam='h' then odds1hke
								when @ugroup='hkf' and @betteam='h' then odds1hkf

								when @ugroup='a' and @betteam='a' then odds2a 
								when @ugroup='b' and @betteam='a' then odds2b
								when @ugroup='c' and @betteam='a' then odds2c 
								when @ugroup='d' and @betteam='a' then odds2d
								when @ugroup='e' and @betteam='a' then odds2e 
								when @ugroup='f' and @betteam='a' then odds2f 
								when @ugroup='hka' and @betteam='a' then odds2hka
								when @ugroup='hkb' and @betteam='a' then odds2hkb
								when @ugroup='hkc' and @betteam='a' then odds2hkc
								when @ugroup='hkd' and @betteam='a' then odds2hkd
								when @ugroup='hke' and @betteam='a' then odds2hke
								when @ugroup='hkf' and @betteam='a' then odds2hkf
								END
							WHEN 1 THEN CASE
								when @ugroup in ('a','hka') and @betteam='h' then odds1a 
								when @ugroup in ('b','hkb') and @betteam='h' then odds1b 
								when @ugroup in ('c','hkc') and @betteam='h' then odds1c 
								when @ugroup in ('d','hkd') and @betteam='h' then odds1d 
								when @ugroup in ('e','hke') and @betteam='h' then odds1e 
								when @ugroup in ('f','hkf') and @betteam='h' then odds1f 
							
								when @ugroup in ('a','hka') and @betteam='a' then odds2a 
								when @ugroup in ('b','hkb') and @betteam='a' then odds2b 
								when @ugroup in ('c','hkc') and @betteam='a' then odds2c 
								when @ugroup in ('d','hkd') and @betteam='a' then odds2d 
								when @ugroup in ('e','hke') and @betteam='a' then odds2e 
								when @ugroup in ('f','hkf') and @betteam='a' then odds2f
								END
							ELSE
								0
					   END
		           WHEN bettype IN (5, 15) THEN 
					   CASE @betteam
							WHEN '1' THEN com1
							WHEN 'X' THEN comX
							WHEN '2' THEN com2
					   END
		           WHEN bettype = 6 THEN
						CASE @betteam
							WHEN '0-1' THEN cs00
							WHEN '2-3' THEN cs01
							WHEN '4-6' THEN cs10
							ELSE cs11 
						END
		           WHEN bettype IN (4, 16,14) THEN
						CASE @betteam
							WHEN '00' THEN cs00 WHEN '01' THEN cs01 WHEN '02' THEN cs02 WHEN '03' THEN cs03 WHEN '04' THEN cs04 WHEN '05' THEN cs05
							WHEN '10' THEN cs10 WHEN '11' THEN cs11 WHEN '12' THEN cs12 WHEN '13' THEN cs13 WHEN '14' THEN cs14
							WHEN '20' THEN cs20 WHEN '21' THEN cs21 WHEN '22' THEN cs22 WHEN '23' THEN cs23 WHEN '24' THEN cs24
							WHEN '30' THEN cs30 WHEN '31' THEN cs31 WHEN '32' THEN cs32 WHEN '33' THEN cs33 WHEN '34' THEN cs34
							WHEN '40' THEN cs40 WHEN '41' THEN cs41 WHEN '42' THEN cs42 WHEN '43' THEN cs43 WHEN '44' THEN cs44
							WHEN '50' THEN cs50							
						END 
		       end)    
	from dbo.odds with(nolock)
	where @oddsid=oddsid		
    select @odds=isnull(@odds,0)
end

GO
GRANT EXECUTE ON [dbo].[Acc_Auto_GetOddsInfoOthers] TO [Dot_Member]
GO