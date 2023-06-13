Create table dbo.requestypes
(
	requesttypeid tinyint primary key,
	requestype varchar(20) not null
);

insert into dbo.requestypes(requesttypeid, requestype) values (1,'Leave')

insert into dbo.requestypes(requesttypeid, requestype) values (2,'Inventory')

insert into dbo.requestypes(requesttypeid, requestype) values (3,'laptop')

select * from dbo.requestypes

create table dbo.employees
(
	EmpID int primary key,
	EmpName varchar(50) Not null,
	Email Varchar(30) not null,
)

Insert into dbo.employees( EmpID, EmpName, Email) values ( 1,'Noraiz','user1@gmail.com.pk')

Insert into dbo.employees( EmpID, EmpName, Email) values ( 2,'Shahid','user2@gmail.com.pk')

Insert into dbo.employees( EmpID, EmpName, Email) values ( 3,'Bilal','user13gmail.com.pk')

Insert into dbo.employees( EmpID, EmpName, Email) values ( 4,'Aslam','user14gmail.com.pk')

Insert into dbo.employees( EmpID, EmpName, Email) values ( 5,'shanawz','user5@gmail.com.pk')

Insert into dbo.employees( EmpID, EmpName, Email) values ( 6,'khuram','user6@gmail.com.pk')

Insert into dbo.employees( EmpID, EmpName, Email) values ( 7,'bosal','user7@gmail.com.pk')

Insert into dbo.employees( EmpID, EmpName, Email) values ( 8,'yousaf','user8@gmail.com.pk')


Create table dbo.requesttypeapprovers
(
	ID int identity(1,1) primary key,
	requesttypeid tinyint not null,
	approverid int not null,
	approvalorder tinyint
)
-- for leave 
insert into dbo.requesttypeapprovers(requesttypeid,approverid,approvalorder) select 1,3,1
insert into dbo.requesttypeapprovers(requesttypeid,approverid,approvalorder) select 1,4,2
insert into dbo.requesttypeapprovers(requesttypeid,approverid,approvalorder) select 1,5,3

 -- For inventory 

insert into dbo.requesttypeapprovers(requesttypeid,approverid,approvalorder) select 2,3,1
insert into dbo.requesttypeapprovers(requesttypeid,approverid,approvalorder) select 2,4,2


--- For laptop
insert into dbo.requesttypeapprovers(requesttypeid,approverid,approvalorder) select 3,1,1
insert into dbo.requesttypeapprovers(requesttypeid,approverid,approvalorder) select 3,6,2

select * from dbo.requesttypeapprovers


create table dbo.requests
(
	requestid int identity (1,1) primary key,
	Requestype tinyint not null,
	requesttitle varchar(100) not null,
	requesterid int not null,
	createdon datetime not null,
	requeststatus tinyint not null,
	lastmodifedon datetime
)

create table dbo.requestworkflow(
workflow bigint identity(1,1) primary key,
requestID int,
approverid tinyint,
approvalorder tinyint,
workflowstatus tinyint,
lastmodifiedon datetime,
remarks varchar(100)
);
Go
Create Procedure dbo.createnewrequest
(
@requesttype tinyint,
@requesttitle varchar(100),
@userid int 
)
As
Begin 
	
	-- STEP 1 : ADD new Request 

	declare @requestid int 
	Insert into dbo.requests(Requestype, requesttitle, requesterid,createdon,requeststatus)
	select @requesttype,@requesttitle,@userid,GETDATE(),1

	select @requestid = SCOPE_IDENTITY()

	--Step 2 Get approver for this request type and add in workflow table

	insert into dbo.requestworkflow(requestID,approverid,approvalorder,lastmodifiedon,workflowstatus)
	select @requestid, approverid, approvalorder,GETDATE(),4 from dbo.requesttypeapprovers 
	where requesttypeid = @requesttype
	order by approvalorder asc;

	--Step 3 Find first approver and made its status to 1 = pending 
	with d As
	(	
		select workflowstatus,lastmodifiedon,ROW_NUMBER() over (order by approvalorder asc) as RowNumber
		from dbo.requestworkflow where requestID = @requestid
	)
	update d set workflowstatus =1, lastmodifiedon = GETDATE()
	where d.RowNumber =1


	--- return auto generated request id 
	select @requestid
END
go
execute dbo.createnewrequest 1,'Testing',1
execute dbo.createnewrequest 2,'secondid',2

go 

create procedure dbo.approverejectrequest
(
	@Requestid int,
	@approverid int,
	@workflowstatus tinyint,
	@remarks varchar(100)
)
as
begin 
	declare @workflowid int
	select  @workflowid = requestID from dbo.requestworkflow 
	where 
	requestID = @Requestid and approverid = @approverid and workflowstatus = 1

	--- step 2 check if a value came in our variable 

	if isnull(@workflowid,0)>0 and (@workflowstatus =2 or @workflowstatus =3)
	Begin 
	 -- step 3 update statius of current workflow
	 update requestworkflow
	 set workflowstatus = @workflowstatus,
	 lastmodifiedon = getdate(),
	 remarks = @remarks
	 where Requestid = @workflowid 
	 

	 -- check if user has rejected or accepted it 

	 if @workflowstatus =2 
	 begin 
	  with d as 
	  (
		select workflowstatus, lastmodifiedon, ROW_NUMBER() over (order by approvalorder asc) as  RowNumber 
		from dbo.requestworkflow where requestID = @Requestid and workflowstatus =4
	  )
	  update d
	  set workflowstatus = 1, lastmodifiedon = GETDATE()
	  where d.RowNumber =1
	  end 
	  -- check if there is no entry pending in workflow status 
	  if( select count(*) from dbo.requestworkflow where workflowstatus in(1,4)) = 0
	  Begin 
	  Update dbo.requests set requeststatus = 2, lastmodifedon = GETDATE()
	  where requesterid = @Requestid
	  end
	  end 
	  else  -- means rejected case 
	  begin 
	  --All remaining unassigned workflows will become rejected 
	  update  dbo.requestworkflow 
	  set workflowstatus =3,
	  lastmodifiedon = GETDATE(),
	  remarks = ' Rejected'
	  where requestid = @Requestid and workflowstatus =4 

	  update dbo.requests
	  set requeststatus = 3,
	  lastmodifedon = GETDATE()
	  where requesterid = @Requestid
	  end
End 
End 


Go
Create Procedure dbo.searchrequest
(	
	@requesttype tinyint,
	@requesttitle varchar(50),
	@requeststatus tinyint,
	@startdate Date,
	@enddate date
)
As
Begin
	 select* from dbo.requests
	 where Requestype = (case when @requesttype > 0 then @requesttype else Requestype end)
	 and requesttitle like '%' + @requesttitle + '%'
	 and requeststatus = (case when @requeststatus > 0 then @requeststatus else requeststatus end)
	 and createdon between  @startdate and @enddate
End
 select* from dbo.requests
execute dbo.searchrequest 1,'',0,'2017-08-01 ',' 2099-12-31'