ALTER FUNCTION [dbo].[Acc_Auto_GetOddsInfoParlay]
(	@oddsid int,
	@betteam varchar(7)	
)
RETURNS smallmoney
AS
Begin   	
	DECLARE @currentOdds smallmoney
	Select @currentOdds=null
    select @currentOdds= case @betteam
						--1,2,3,7,8,12,17,18,20
						when 'h' then 1 + odds1hkf		
						when 'a' then 1 + odds2hkf
						--1x2
						when '1' then Com1	when '2' then Com2	when 'X' then ComX
						when '0-1' then cs00 when '2-3' then cs01	when '4-6' then cs10	when '7-over' then cs11

						--Add HTFT, use same as CS 1:1; 2:1						
						when '11' then cs11		when '12' then cs12	when '10' then cs10
						when '21' then cs21		when '22' then cs22	when '20' then cs20
						when '01' then cs01		when '02' then cs02	when '00' then cs00						
						--add correct score
						when '0:0' then cs00	when '0:1' then cs01	when '0:2' then cs02	when '0:3' then cs03	when '0:4' then cs04	when '0:5' then cs05
						when '1:0' then cs10	when '1:1' then cs11	when '1:2' then cs12	when '1:3' then cs13	when '1:4' then cs14		
						when '2:0' then cs20	when '2:1' then cs21	when '2:2' then cs22	when '2:3' then cs23	when '2:4' then cs24
						when '3:0' then cs30	when '3:1' then cs31	when '3:2' then cs32	when '3:3' then cs33	when '3:4' then cs34
						when '4:0' then cs40	when '4:1' then cs41	when '4:2' then cs42	when '4:3' then cs43	when '4:4' then cs44
						when '5:0' then cs50 end			
    
    from odds (nolock)
	where oddsid=@oddsid	
	select @currentOdds=isnull(@currentOdds,0)
RETURN @currentOdds

end

Go
	GRANT EXECUTE ON [dbo].[Acc_Auto_GetOddsInfoParlay] TO [Dot_Member]
Go