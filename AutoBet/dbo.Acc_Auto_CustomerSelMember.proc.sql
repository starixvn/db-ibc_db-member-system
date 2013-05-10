/****** Object:  StoredProcedure [dbo].[ Acc_Auto_CustomerSelMember]    Script Date: 09/30/2008 09:31:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Tong Hoang Dung
-- Create date: Sep 19 2008
-- Description:	Get All Members of an agent or master or supper
-- DB : DB02.bodb02
-- =============================================
ALTER PROCEDURE [dbo].[Acc_Auto_CustomerSelMember]
	@CustID int
AS
BEGIN	
	SET NOCOUNT ON;
	declare @RoleId int
	
	select @RoleId=roleid from customer with (nolock) where custid=@CustID 
	if(@RoleId in (2,3,4))
	begin		    
		select c.custid,c.ugroup,coalesce(c.site,'BEST-ODDS') as [site],cc.betcredit
		from customer c with (nolock) 
			 inner join custInfo i with(nolock) on (c.custid=i.custid) 
			 inner join custBetCredit cc with(nolock) on (cc.custid=i.custid)
		where @CustID=(case @RoleId  
							   when 2 then  c.recommend 
							   when 3 then c.mrecommend 
							   when 4 then c.srecommend 
							else -1 end) 
			  and isnull(i.reject,1)<>1 
			  and isnull(i.enabled,0)<>0 
			  and i.closed<>1 
			  and c.roleid=1 
			  and cc.betcredit>10 --and i.currency=20
   end  
END

GO
GRANT EXECUTE ON [dbo].[Acc_Auto_CustomerSelMember] TO [Dot_Member]
GO