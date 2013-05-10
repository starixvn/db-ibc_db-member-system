declare @p4 int
set @p4=47836244
declare @p5 varchar(100)
set @p5='99ry4.ibcbet.com'
exec dbo.Dot_Member_LoginRecord @custid=78761,@site=N'ibc',@domain=N'ibcbet.com',@TicketID=@p4 output,@RedirHOST=@p5 output
select @p4, @p5
go
declare @p7 int
set @p7=178708486
declare @p8 varchar(50)
set @p8='IBC'
exec dbo.Dot_Member_LoginClaimed @custid=78761,@TicketID=47836244,@ServerID=101001,@IP=N'202.78.228.8',@ServerIP=N'10.4.115.2',@URL=N'http://99ry4.ibcbet.com',@Result=@p7 output,@Site=@p8 output
select @p7, @p8
go
