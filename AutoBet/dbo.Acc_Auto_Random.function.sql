CREATE FUNCTION [dbo].[Acc_Auto_Random]
(
	@Lower float, 
	@Upper float
)
RETURNS float
AS
BEGIN
	RETURN ROUND(((@Upper - @Lower -1) * RAND() + @Lower), 0)

END

Go
	GRANT EXECUTE ON [dbo].[Acc_Auto_Random] TO [Dot_Member]
Go