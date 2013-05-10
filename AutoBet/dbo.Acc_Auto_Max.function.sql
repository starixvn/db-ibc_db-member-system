CREATE FUNCTION [dbo].[Acc_Auto_Max]
(
	@param1 float, 
	@param2 float
)
RETURNS float
AS
BEGIN
	if(@param1>@param2) 
		RETURN @param1
	RETURN @param2	
END

Go
	GRANT EXECUTE ON [dbo].[Acc_Auto_Max] TO [Dot_Member]
Go