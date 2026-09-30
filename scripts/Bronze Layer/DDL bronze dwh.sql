if OBJECT_ID('bronze.crm_cust_info','U') is not null
	Drop table bronze.crm_cust_info;
Go
create table bronze.crm_cust_info(
	cst_id int,
	cst_key nvarchar(50),
	cst_firstname nvarchar(50),
	cst_lastname nvarchar(50),
	cst_marital_status nvarchar (50),
	cst_gndr nvarchar (50),
	cst_create_date date
	);
go