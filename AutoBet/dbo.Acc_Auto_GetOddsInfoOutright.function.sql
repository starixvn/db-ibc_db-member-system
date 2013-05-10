CREATE FUNCTION [dbo].[Acc_Auto_GetOddsInfoOutright]
(
	@orid int 	
)
RETURNS smallmoney
AS
begin	
	DECLARE @currentOdds smallmoney
	Select @currentOdds=0
    select @currentOdds=isnull(odds,0)
	FROM outright with (nolock)		
	WHERE orid=@orid
	return 	@currentOdds
end	
GO
GRANT EXECUTE ON [dbo].[Acc_Auto_GetOddsInfoOutright] TO [Dot_Member]
GO