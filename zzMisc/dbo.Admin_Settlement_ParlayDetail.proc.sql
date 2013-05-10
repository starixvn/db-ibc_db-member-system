ALTER PROCEDURE [dbo].[Admin_Settlement_ParlayDetail]
	@matchid int,
	@fth int, @fta int,
	@hth int, @hta int,
	@matchdate datetime
AS

Declare @modds smallmoney

UPDATE dbo.bettransm with (updlock)
SET bettype=o.bettype 
FROM dbo.odds o with (nolock)
WHERE o.oddsid=bettransm.oddsid
	and bettransm.matchid=@matchid and o.matchid=@matchid
	and bettransm.bettype <> o.bettype

UPDATE dbo.bettransm with (updlock)
SET
	@modds =
		CASE bettype
			when 1 then
				case betteam
				when 'h'
				then (@fth + (hdp2-hdp1)) - @fta
				else (@fta + (hdp1-hdp2)) - @fth
				end
				/*when 'h' then (@fth + (hdp2+liveawayscore-hdp1-livehomescore)) - @fta
				else (@fta + (hdp1+livehomescore-hdp2-liveawayscore)) - @fth end */
			
			when 7 then
				case betteam
				when 'h'
				then (@hth + (hdp2-hdp1)) - @hta
				else (@hta + (hdp1-hdp2)) - @hth
			end

			when 3 then
				case betteam when 'h' then (@fth+@fta) - hdp1 else hdp1 - (@fth+@fta) end
			
			when 8 then
				case betteam when 'h' then (@hth+@hta) - hdp1 else hdp1 - (@hth+@hta) end

			when 2 then
				case 
				when (betteam = N'h') AND ((@fth+@fta)&1 = 1) then 1
				when (betteam = N'a') AND ((@fth+@fta)&1 = 0) then 1
				else -1
				end
			when 4 then
				case
				when betteam = ( CAST(@fth as varchar(4)) + ':' + CAST(@fta as varchar(4)) ) THEN 1
				when betteam = '5:0' AND (@fth - @fta) >=  5 THEN 1
				when betteam = '0:5' AND (@fth - @fta) <= -5 THEN 1
				else -1
				end
			when 16 then
				case
				when betteam =
					CASE WHEN @hth = @hta THEN '0' WHEN @hth > @hta THEN '1' ELSE '2' END + ':' +
					CASE WHEN @fth = @fta THEN '0' WHEN @fth > @fta THEN '1' ELSE '2' END
					THEN 1
				else -1
				end

			when 5 then
				case
				when (betteam = N'1') AND (@fth > @fta) then 1
				when (betteam = N'2') AND (@fta > @fth) then 1
				when (betteam = N'x') AND (@fth = @fta) then 1
				else -1
				end
			when 15 then
				case 
				when (betteam = N'1') AND (@hth > @hta) then 1
				when (betteam = N'2') AND (@hta > @hth) then 1
				when (betteam = N'x') AND (@hth = @hta) then 1
				else -1
				end

			when 6 then
				case when (
						@fth+@fta >= cast(left(betteam,1)as int) and
						@fth+@fta <= (
								case when right(betteam,1) = 'r' then 999 else 
								cast(right(betteam,1) as int) end
								)
						)  
				then 1 else -1 end
					
		END, -- CASE bettype
-- ========================
	ruben=1,
	winlostdate=@matchdate,
	[status]=
		case
			when @modds=0 then N'DRAW'
			when @modds<0 then N'LOSE'
			when @modds>0 then N'WON'
		end ,
	statuswinlost=
		case
			when @modds<=-0.5 then 4 -- LOSE
			when @modds>=0.5 then 2 -- WIN
			when @modds>0 then 1 -- Half WIN
			when @modds<0 then 3 -- Half LOSE
			else 0	-- DRAW
		end
-- ========================
FROM dbo.bettransm with (INDEX=IX_matchid)
WHERE matchid = @matchid
