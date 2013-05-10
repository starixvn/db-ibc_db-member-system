ALTER PROCEDURE [dbo].[Dot_Member_Credit_Match_Check_Thien]
 --@custid=98632, @matchid=411062,@sporttype=1
	@custid int,
	@matchid int,
	@sporttype int
as
declare @finalbalance money,
		@totalbetpermatch money
select	
		@finalbalance = (isnull(sum(winlost-actual_stake+playercomm),0)),
		@totalbetpermatch = IsNull(SUM(case when (matchid=@matchid and bettrans.ruben not in (2,3)) then (CASE WHEN odds < -1 THEN ABS(odds) ELSE 1 END * stake) else 0 end),0)
from bettrans with (nolock) 
where bettrans.custid=@custid
group by bettrans.custid

select	
		c.credit credit, c.virtualmultiplier virtualrate,c.autosuspend, c.currency,c.closed,isnull(c.reject,0) as reject,
		(case when @sporttype=1 then c.maxpermatch else c.maxpermatch2 end) maxpermatch,
		@finalbalance as finalbalance, @totalbetpermatch as totalbetpermatch
from	custinfo  c (nolock)		
where c.custid=@custid