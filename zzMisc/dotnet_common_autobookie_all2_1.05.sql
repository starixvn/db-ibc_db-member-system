


--- Modified By : Ei Han
--- Date        : 26th NOV 2007
--- Ticket      : 3802
--- Version     : V 1.05
--- Details     : To replace dotnet_autobookie_all2
---               Only to retrieve username and currencystr from customer and exchange table and add in bettrans table

CREATE  proc [dbo].[dotnet_common_autobookie_all2_1.05]
@oddsid int,
@ugroup nvarchar(5),
@hdp1 float,
@hdp2 float,
@odds float,
@actual_odds float,
@livehomescore int,
@liveawayscore int,
@stake int,
@betteam nvarchar(1),
@custid int,
@betstake  int, 
@creator int,
@bettype  int,
@betactual_stake float,
@http_ref nvarchar(150), 
@remote_add nvarchar(20),
@betfrom nvarchar(1),
@betdaqid bigint = null
as
set nocount on; 
declare @actualrate float
declare @curr int
declare @betactualrate float
declare @positiontaking float
declare @apositiontaking float
declare @mpositiontaking float
declare @spositiontaking float
declare @status nvarchar(20)   
declare @tpositiontaking float
declare @sdiscount  float
declare @discount  float
declare @playerdiscount float
declare @adiscount  float
declare @recommend  int
declare @mrecommend int
declare @srecommend int
declare @aptlive1 float
declare @mptlive1 float
declare @sptlive1 float
declare @aptlive3 float
declare @mptlive3 float
declare @sptlive3 float
declare @username nvarchar(20)
declare @currstr nvarchar(20)

select @curr=customer.currency,
  @positiontaking=positiontaking, 
  @apositiontaking=apositiontaking,
  @mpositiontaking=mpositiontaking,
  @spositiontaking=spositiontaking,
  @sdiscount=sdiscount,
  @discount=discount,
  @playerdiscount=playerdiscount,
  @adiscount=adiscount,
  @recommend=recommend, 
  @mrecommend=mrecommend, 
  @srecommend=srecommend,
  @sptlive1=sptlive1,
  @sptlive3=sptlive3,
  @mptlive1=mptlive1,
  @mptlive3=mptlive3,
  @aptlive1=aptlive1,
  @aptlive3=aptlive3,
  @actualrate=exchange.actualrate,
  @username=customer.username,
  @currstr=exchange.currency 
from customer with (nolock), 
  exchange with (nolock)
where customer.custid=@custId 
  and exchange.exchangeid = customer.currency

set @betactualrate=@actualrate
if (@odds<0)
 set @betactual_stake = @betstake*abs(@odds)
else
 set @betactual_stake = @betstake

-----declare variable --------------
declare @transid int,@ohdp1 float,@ohdp2 float
declare @stake_to_company float,@hometotal float, @awaytotal float
declare @oddslivehomescore int,@oddsliveawayscore int
declare @matchdate datetime,@liveindicator bit,@matchid int
declare @running int, @running_no bigint,@newoffersetup bit,@godds float
declare @finalbalance float,@totalbet float,@temp_rowcount int, @temp_error int
declare @oddsstatus nvarchar(100)
--declare @oddsstatus2 nvarchar(100) -- odds status in oddsstatus table
declare @maxbet float
select @transid=0
select @finalbalance=0
select @totalbet=0
--------all need to insert to bettrans variable select  
select 
 @matchid=odds.matchid,
 @maxbet=odds.maxbet,
 @matchdate=match.eventdate,
 @newoffersetup=odds.newoffersetup,
 @liveindicator=odds.liveindicator,
 @bettype=bettype,
 @oddsstatus=oddsstatus,
 @ohdp1=odds.hdp1,
 @ohdp2=odds.hdp2,
 @oddslivehomescore=odds.livehomescore,
 @oddsliveawayscore=odds.liveawayscore,
@godds=
 (case when @betteam='h' then odds1a
       when @betteam='a' then odds2a 
       else 0 end )
from 
 odds with (nolock),match with (nolock)
where 
 odds.matchid=match.matchid and
 odds.oddsid=@oddsid and 
 ((match.kickofftime>=getdate() and odds.liveindicator=0) or odds.liveindicator=1) and
 match.eventstatus='running' and
 odds.oddsstatus='running' and 
 odds.bettype in (1,2,3,7,9,12)
set @temp_rowcount=@@rowcount
set @temp_error=@@error
if (@temp_rowcount=0)
 set @transid=-1 --matchclose 
if (@temp_error<>0)
 set @transid=-1 --close 
if (round(@actual_odds,3)<>round(@godds,3))
 set @transid=-2 --- odds change 
if (round(@ohdp1-@ohdp2,3)<>round(@hdp1-@hdp2,3))
 set @transid=-2 --- hdp change 
if (@oddslivehomescore<>@livehomescore or @oddsliveawayscore<>@liveawayscore)
 set @transid=-2
if (@matchid is null or @matchdate is null)
 set @transid=-2

if not (@betteam='h' or @betteam='a')
begin
 set @transid=2
end 
 
if (@maxbet<@stake*@actualrate)
 set @transid=2

/*
if (@liveindicator=1)
begin
 select @oddsstatus2 = oddsstatus
 from OddsExtraInfo with (nolock)
 where oddsid = @oddsid

 if @@rowcount = 0
  set @oddsstatus2 = @oddsstatus
 if (@transid=0 and @oddsstatus2 <> 'running')
  set @transid=-1 -- match close or suspend
 if (@transid <> 0  and @oddsstatus2 <> @oddsstatus)
 begin
  update odds with (rowlock)
  set oddsstatus = @oddsstatus2
  where oddsid = @oddsid
 end
end
else if (@transid=0 and @oddsstatus <> 'running')
begin
 set @transid=-1 -- match close or suspend
end
*/
if (@transid=0)
begin
 --------------- set total position taking---------------------------------------
 declare @apt2 float, @mpt2 float, @spt2 float
 declare @apttype nvarchar(20),@mpttype nvarchar(20),@spttype nvarchar(20)
 set @apttype = N'default'
 set @mpttype = N'default'
 set @spttype = N'default'

 select 
  @apt2 = (case when @liveindicator=1 then (case when (@bettype = 1 or @bettype = 7) then apthdplive else aptoulive end) else apt5050mkt end), 
  @mpt2 = (case when @liveindicator=1 then (case when (@bettype = 1 or @bettype = 7) then mpthdplive else mptoulive end) else mpt5050mkt end), 
  @spt2 = (case when @liveindicator=1 then (case when (@bettype = 1 or @bettype = 7) then spthdplive else sptoulive end) else spt5050mkt end)
 from
  allagentpt with (nolock),
  odds with (nolock),
  match with (nolock)
 where
  odds.matchid = match.matchid 
  and odds.oddsid = @oddsid
  and match.leagueid = allagentpt.typeid
  and allagentpt.type = 1  -- 1 stands for league
  and allagentpt.custid = @custid


 if @@error = 0 and @@rowcount = 1
 begin
  if @apt2 >= 0
   set @apttype = N'league'
  if @mpt2 >= 0
   set @mpttype = N'league'
  if @spt2 >= 0
   set @spttype = N'league'
 end


 if (@liveindicator=1) 
 begin  
  set @status= case when @newoffersetup=1 then 'running' else 'waiting' end
  
  if (@bettype =1 or @bettype =7) 
  begin
   set @apositiontaking = @aptlive1
   set @mpositiontaking = @mptlive1
   set @spositiontaking = @sptlive1
  end
  else
  begin
   set @apositiontaking = @aptlive3
   set @mpositiontaking = @mptlive3
   set @spositiontaking = @sptlive3
  end 
 end 
 else
 begin
  set @status='running'
 end 

 if @apttype <> N'default'
  set @apositiontaking = @apt2
 if @mpttype <> N'default'
  set @mpositiontaking = @mpt2
 if @spttype <> N'default'
  set @spositiontaking = @spt2

 set @tpositiontaking = @apositiontaking + @mpositiontaking + @spositiontaking
 if (@tpositiontaking > 1)
 begin
  select -3 as result
  return
 end 

 set @stake_to_company=@stake*(1-@tpositiontaking)*@actualrate

 if @betteam='h' 
 begin
  ----auto bookie update ----
  update odds with (rowlock,updlock) set 
   
   odds1a=(case when @stake_to_company+diffbalance>=risk+((stakerange-risk)/2) then 
      case when abs(odds1a-gapodds1)>1 then 2-abs(odds1a-gapodds1) else odds1a-gapodds1 end
      when @stake_to_company+diffbalance>=risk then 
      case when abs(odds1a-gapodds2)>1 then 2-abs(odds1a-gapodds2) else odds1a-gapodds2 end
      else odds1a
      end),
   odds2a=(case when @stake_to_company+diffbalance>=risk+((stakerange-risk)/2) then 
      case when abs(odds2a+gapodds1)>1 then -(2-abs(odds2a+gapodds1)) else odds2a+gapodds1 end
      when @stake_to_company+diffbalance>=risk then 
      case when abs(odds2a+gapodds2)>1 then -(2-abs(odds2a+gapodds2)) else odds2a+gapodds2 end
      else odds2a
      end),
   diffbalance=case when @stake_to_company+diffbalance>=risk then 0 else diffbalance+@stake_to_company end,
   allowance=case when @stake_to_company+diffbalance>=risk then  diffbalance+@stake_to_company else 0 end,
   oddsstatus=(case when autobookie=0 and @stake_to_company+diffbalance>=risk then 'suspend' else  case when abs(odds1a)<abs(minodds) then 'closed' else oddsstatus end end),
   @hometotal=hometotal=hometotal+@stake_to_company*case when abs(@odds)>1 then abs(@odds) else 1 end 
   

  where oddsid=@oddsid and round(@actual_odds,3)=round(odds1a,3) and oddsstatus='running'
  set @temp_rowcount=@@rowcount
  set @temp_error =@@error

  if (@temp_rowcount=0)
   set @transid=-2
 end
 else
 begin
  ----auto bookie update ----
  update odds with (rowlock,updlock) set 
   
   odds2a=(case when (@stake_to_company-diffbalance)>=risk2+((stakerange2-risk2)/2) then 
      case when abs(odds2a-com1)>1 then 2-abs(odds2a-com1) else odds2a-com1 end
      when (@stake_to_company-diffbalance)>=risk2 then 
      case when abs(odds2a-com2)>1 then 2-abs(odds2a-com2) else odds2a-com2 end
      else odds2a
      end),
   odds1a=(case when (@stake_to_company-diffbalance)>=risk2+((stakerange2-risk2)/2) then 
      case when abs(odds1a+com1)>1 then -(2-abs(odds1a+com1)) else odds1a+com1 end
      when (@stake_to_company-diffbalance)>=risk2 then 
      case when abs(odds1a+com2)>1 then -(2-abs(odds1a+com2)) else odds1a+com2 end
      else odds1a
      end),
   diffbalance=case when (@stake_to_company-diffbalance)>=risk2 then 0 else diffbalance-@stake_to_company end ,
   allowance2=case when (@stake_to_company-diffbalance)>=risk2 then  diffbalance-@stake_to_company else 0 end,
   oddsstatus=(case when autobookie=0 and (@stake_to_company-diffbalance)>=risk2 then 'suspend' else  case when abs(odds2a)<abs(minodds) then 'closed' else  oddsstatus  end end ),
   @awaytotal=awaytotal=awaytotal+@stake_to_company*case when abs(@odds)>1 then abs(@odds) else 1 end 
   

  where oddsid=@oddsid  and round(@actual_odds,3)=round(odds2a,3) and oddsstatus='running'


  set @temp_rowcount=@@rowcount
  set @temp_error =@@error
  if (@temp_rowcount=0)
   set @transid=-2

 end
end 
if (@@error=0 and @transid=0 and @temp_error=0)
begin
 set @temp_error=@@error
 if (@temp_error<>0)
 begin
  set @http_ref='error update'
 end 
 if (@temp_error=0 and @odds<>0)
 begin
/*
  if (@liveindicator = 1 and @oddsstatus <> @oddsstatus2)
  begin
   update OddsExtraInfo with (rowlock)
   set oddsstatus=@oddsstatus
   where oddsid = @oddsid
  end
*/
  declare @err int
  insert bettrans 
  ( 
  custid, oddsid, oddsspread, hdp1, hdp2,odds, stake, status, livehomescore, liveawayscore, liveindicator, 
  betteam, creator, refno, tpositiontaking, apositiontaking, mpositiontaking,  spositiontaking, 
  discount, playerdiscount, adiscount,sdiscount, actualrate, matchid, recommend, mrecommend, srecommend,
  bettype, currency, actual_stake, winlostdate, transdesc, ip,betfrom, betdaqid, username, currencystr) 
  values 
  (
  @custid ,@oddsid, 
  0, @hdp1, @hdp2,@odds,
  @betstake, @status,  @oddslivehomescore, @oddsliveawayscore,
  @liveindicator  ,@betteam,  @creator, 100000000000 ,
  @tpositiontaking, @apositiontaking, @mpositiontaking, @spositiontaking, 
  @discount, @playerdiscount, @adiscount,@sdiscount,@betactualrate, 
  @matchid,@recommend,@mrecommend,@srecommend,@bettype,@curr, @betactual_stake, 
  @matchdate, @http_ref, @remote_add,@betfrom, @betdaqid, @username, @currstr); set @err=@@error;
  select @transid=scope_identity()

  if (@err<>0)
  begin
   update odds with (rowlock,updlock)
   set 
   hometotal=hometotal-@hometotal,
   awaytotal=awaytotal-@awaytotal
  where oddsid=@oddsid;
  set @transid=-1 
 end 
 else
 begin
  declare @str nvarchar(500)
  select @str=N'internet betting custid' + cast(isnull( @custid,'x') as nvarchar(10)) + N' insert bet oddsid ' +  cast(isnull( @oddsid,'x') as nvarchar(10)) + N' at ' + cast(isnull( @odds,'x') as nvarchar(10)) + N' bet ' + cast(isnull(@betteam,'x') as nvarchar(10))  +  N' stake ' + cast(isnull(@stake,'x') as nvarchar(10)) + N' and transid= ' +cast(isnull( @transid,'x') as nvarchar(10)) + N' Ip' + cast(isnull(@remote_add,'x') as nvarchar(16)) + N' aptType: ' + @apttype + N' mptType: ' + @mpttype + N' sptType: ' + @spttype
  exec logfile  @creator,@str
 end 
end 
else 
 set @transid=-1
end 
select @transid as result,@liveindicator as live





GO
