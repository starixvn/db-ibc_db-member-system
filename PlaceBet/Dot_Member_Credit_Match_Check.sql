ALTER PROCEDURE [dbo].[Dot_Member_Credit_Match_Check]
 --@custid=98632, @matchid=411062,@sporttype=1
@custid int,
@matchid int,
@sporttype int
as

select	
		c.credit credit, c.virtualmultiplier virtualrate,
		c.autosuspend, c.currency,c.closed,
		isnull(c.reject,0) as reject,
		(isnull(sum(winlost-actual_stake+playercomm),0)) as finalbalance,
		(case when @sporttype=1 then c.maxpermatch else c.maxpermatch2 end) maxpermatch,
		IsNull(SUM(case when (matchid=@matchid and bettrans.status not in ('reject','void')) then (CASE WHEN odds < -1 THEN ABS(odds) ELSE 1 END * stake) else 0 end),0) as totalbetpermatch
		
from	
		custinfo  c (nolock) left outer join 	
			bettrans with (nolock) on 
				c.custid=bettrans.custid and c.custid=@custid 
where c.custid=@custid

group by 
		c.custid, c.credit,c.maxpermatch,c.maxpermatch2,c.virtualmultiplier, c.autosuspend, c.currency,c.closed,c.reject

GO
GRANT EXECUTE ON [dbo].[Dot_Member_Credit_Match_Check] TO [Dot_Member]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_Credit_Match_Check] TO [ITTim]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_Credit_Match_Check] TO [ITVivi]
GO
GRANT ALTER ON [dbo].[Dot_Member_Credit_Match_Check] TO [twteam]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Member_Credit_Match_Check] TO [vnteam]