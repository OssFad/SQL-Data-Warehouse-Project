/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
 Purpose:
   Loads raw CRM and ERP data from CSV files into the Bronze
   layer. Existing data is truncated before each full reload,
   and execution time and errors are logged for monitoring.

 Usage Example:
    EXEC bronze.load_bronze;
===============================================================================
*/

CREATE or ALTER PROCEDURE bronze.load_bronze AS
BEGIN
	DECLARE @start_time DATETIME,@end_time DATETIME,@batch_start_time DATETIME,@batch_end_time DATETIME;
	BEGIN TRY
		
		SET @batch_start_time= GETDATE();
		PRINT'=====================================================================';
		PRINT'Loading Bronze layer';
		PRINT'=====================================================================';

		PRINT'---------------------------------------------------------------------';
		PRINT'Loading CRM Tables';
		PRINT'---------------------------------------------------------------------';


		SET @start_time=GETDATE();
		PRINT'>>Truncating Table bronze.crm_cust_info';
		TRUNCATE TABLE bronze.crm_cust_info;
		PRINT'>>Inserting Data Into: bronze.crm_cust_info';
		BULK INSERT bronze.crm_cust_info
		from 'C:\Users\Ossama\Desktop\sql data warehouse project\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
		with(
			FIRSTROW=2,
			FIELDTERMINATOR=',',
			TABLOCK);

		SET @end_time=GETDATE();
		PRINT'>> Load Duration:'+ CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR)+'seconds';
		PRINT'>>-----------------------'

		SET @start_time=GETDATE();
		PRINT'>>Truncating Table bronze.crm_prd_info';
		TRUNCATE TABLE bronze.crm_prd_info;
		PRINT'>>Inserting Data Into: bronze.crm_prd_info';
		BULK INSERT bronze.crm_prd_info
		from 'C:\Users\Ossama\Desktop\sql data warehouse project\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
		with(
			FIRSTROW=2,
			FIELDTERMINATOR=',',
			TABLOCK);

		SET @end_time=GETDATE();
		PRINT'>> Load Duration:'+ CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR)+'seconds';
		PRINT'>>-----------------------'

		SET @start_time=GETDATE();
		PRINT'>>Truncating Table bronze.crm_sales_details';
		TRUNCATE TABLE bronze.crm_sales_details;
		PRINT'>>Inserting Data Into: bronze.crm_sales_details';
		BULK INSERT bronze.crm_sales_details
		from 'C:\Users\Ossama\Desktop\sql data warehouse project\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
		with(
			FIRSTROW=2,
			FIELDTERMINATOR=',',
			TABLOCK);
		SET @end_time=GETDATE();
		PRINT'>> Load Duration:'+ CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR)+'seconds';
		PRINT'>>-----------------------'

		PRINT'---------------------------------------------------------------------';
		PRINT'Loading CRM Tables';
		PRINT'---------------------------------------------------------------------';

		SET @start_time=GETDATE();
		PRINT'>> Truncating Table: bronze.erp_cust_az12';
		TRUNCATE TABLE bronze.erp_cust_az12;
		PRINT'>>Inserting Data Into: bronze.erp_cust_az12';
		BULK INSERT bronze.erp_cust_az12
		from'C:\Users\Ossama\Desktop\sql data warehouse project\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
		with(
			FIRSTROW=2,
			FIELDTERMINATOR=',',
			TABLOCK);
		SET @end_time=GETDATE();
		PRINT'>> Load Duration:'+ CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR)+'seconds';
		PRINT'>>-----------------------'

		SET @start_time=GETDATE();
		PRINT'>>Truncating Table bronze.erp_loc_a101';
		TRUNCATE TABLE bronze.erp_loc_a101;
		PRINT'>>Inserting Data Into: bronze.erp_loc_a101';
		BULK INSERT bronze.erp_loc_a101
		from 'C:\Users\Ossama\Desktop\sql data warehouse project\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
		WITH(
			FIRSTROW=2,
			FIELDTERMINATOR=',',
			TABLOCK);
		SET @end_time=GETDATE();
		PRINT'>> Load Duration:'+ CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR)+'seconds';
		PRINT'>>-----------------------'

		SET @start_time=GETDATE();
		PRINT'>>Truncating Table bronze.erp_px_cat_g1v2';
		TRUNCATE TABLE bronze.erp_px_cat_g1v2;
		PRINT'>>Inserting Data Into: bronze.erp_px_cat_g1v2';
		BULK INSERT bronze.erp_px_cat_g1v2
		from 'C:\Users\Ossama\Desktop\sql data warehouse project\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
		with(
			FIRSTROW=2,
			FIELDTERMINATOR=',',
			TABLOCK);
		SET @end_time=GETDATE();
		PRINT'>> Load Duration:'+ CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR)+'seconds';
		PRINT'>>-----------------------'

		SET @batch_end_time=GETDATE();

		PRINT'==============================================================================';
		PRINT'Loading Bronze Layer is Completed';
		PRINT'Total laod Duration'+ CAST(DATEDIFF(second,@batch_start_time,@batch_end_time) AS NVARCHAR) + 'seconds';
		PRINT'==============================================================================';
	END TRY
	BEGIN CATCH
		PRINT'=====================================================================';
		PRINT'ERROR OCCURED DURING LOADING BRONZE LAYER';
		PRINT'ERROR MESSAGE'+ ERROR_MESSAGE();
		PRINT'ERROR MESSAGE'+ CAST(ERROR_NUMBER() AS NVARCHAR(10));
		PRINT'ERROR MESSAGE'+ CAST(ERROR_STATE() AS NVARCHAR(10));
		PRINT'=====================================================================';



	END CATCH
END


