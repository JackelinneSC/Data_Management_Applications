--****PART A: 
--Business question: What are the sales registered by our stores for
--the first quarter of the year 2007?

--****PART B:
--Create detailed table
DROP TABLE IF EXISTS quarterly_sales;
CREATE TABLE quarterly_sales(
	sales_id SERIAL PRIMARY KEY,
	rental_id integer,
	store_code text,
	payment_amount numeric(5,2),
	payment_date TIMESTAMP WITHOUT TIME ZONE
);
-- To view empty detailed table
SELECT * FROM quarterly_sales;

--Create summary table
DROP TABLE IF EXISTS summary_sales;
CREATE TABLE summary_sales(
	total_sales_id SERIAL PRIMARY KEY,
	store_code text,
	amount_sold numeric
);
-- To view empty detailed table
SELECT * FROM summary_sales;

--****PART D:
--Function to perform a custom transformation. This function concatenates the word
-- 'Store #' with the store_id to provide an understable way to read the reports.
-- For example 'Store # 1'
CREATE OR REPLACE FUNCTION get_store_code(current_staff_id smallint)
RETURNS text
LANGUAGE plpgsql
AS
$$
	DECLARE
	store_id integer;
	store_code text;
	BEGIN
	SELECT staff.store_id into store_id FROM staff WHERE current_staff_id = staff.staff_id;
	SELECT CONCAT('Store # ', store_id) into store_code;
RETURN store_code;
END;
$$;

--****PART C: 
--Extract raw data from dvdrental db into detailed table
INSERT INTO quarterly_sales(
	rental_id,
	store_code,
	payment_amount,
	payment_date
)
SELECT 
	r.rental_id, store_code,pmt.amount, pmt.payment_date
FROM 
	rental AS r INNER JOIN payment AS pmt USING(rental_id),
LATERAL get_store_code(pmt.staff_id) store_code
WHERE (SELECT EXTRACT (QUARTER FROM payment_date) = 1);

-- To view contents of detailed table 
SELECT * FROM quarterly_sales;

--Evaluate data accuracy.
--	Extracts the number of movies rented for the first quarter of 2007. 
--	The number of rows of the detailed table should be the same as the result of
--	this statement. (7660 rows).
SELECT
	COUNT (rental_id)
FROM
	rental INNER JOIN payment USING(rental_id) WHERE (SELECT EXTRACT (QUARTER FROM payment_date) = 1);

--Compare the result with the detailed table
SELECT COUNT(*) FROM quarterly_sales;

--Insert values to the summary table (with aggregation)
INSERT INTO summary_sales(
	store_code,
	amount_sold
) 
SELECT 
	q.store_code, SUM(q.payment_amount) AS total 
FROM 
	quarterly_sales q 
GROUP BY 
	q.store_code ;

-- To view contents of summary table 
SELECT * FROM summary_sales;

--Evaluate data accuracy.
--	Extracts the total retail sales for the first quarter of 2007 grouped by store.
--	The result of this statement should be the same as the summary table. 
SELECT
	store_id, SUM(amount)
FROM
	payment INNER JOIN staff USING(staff_id) WHERE (SELECT EXTRACT (QUARTER FROM payment_date) = 1)
GROUP BY
	store_id;

--****PART E:
--Create function to update the summary table when data is added to the detailed table.
CREATE OR REPLACE FUNCTION sales_summary_update()
RETURNS TRIGGER AS $sales_summary_update$
DECLARE
	new_amount_cost numeric(15,2);
	new_store_code text;
BEGIN
	new_amount_cost = NEW.payment_amount;
	new_store_code = NEW.store_code;
	--Update the summary row with the new values
	UPDATE summary_sales
	SET amount_sold = amount_sold + new_amount_cost
	WHERE store_code = new_store_code;
	RETURN NULL;
END;
$sales_summary_update$ LANGUAGE PLPGSQL;

-- Create trigger on detailed table
CREATE OR REPLACE TRIGGER sales_summary_update
AFTER INSERT ON quarterly_sales
FOR EACH ROW EXECUTE FUNCTION sales_summary_update();

-- To view contents of summary table before the update trigger 
SELECT * FROM summary_sales;
--Test trigger functionality.
--Insert 2 new rows to modify the total sales on the summary table.
INSERT INTO quarterly_sales(
	rental_id,
	store_code,
	payment_amount,
	payment_date
)
VALUES(
	5052, 'Store # 1', 3.59, LOCALTIMESTAMP
);

INSERT INTO quarterly_sales(
	rental_id,
	store_code,
	payment_amount,
	payment_date
)
VALUES(
	5051, 'Store # 2', 7.99, LOCALTIMESTAMP
);

-- To view contents of summary table after creating the update trigger
SELECT * FROM summary_sales;

--****PART F:
--Create stored procedure to refresh data in both detailed and summary tables.
CREATE OR REPLACE PROCEDURE refresh_reports(quarter int)
AS $$
BEGIN
	--Refresh detailed table
	DELETE FROM quarterly_sales;
	INSERT INTO quarterly_sales(
		rental_id,
		store_code,
		payment_amount,
		payment_date
	)
	SELECT 
		r.rental_id, store_code, pmt.amount, pmt.payment_date
	FROM 
		rental AS r INNER JOIN payment AS pmt USING(rental_id),
		LATERAL get_store_code(pmt.staff_id) store_code
	WHERE 
		(SELECT EXTRACT (QUARTER FROM payment_date) = quarter);
	--Refresh summary table
	DELETE FROM summary_sales;
	INSERT INTO summary_sales(
		store_code,
		amount_sold
	)
	SELECT 
		fq.store_code, SUM(fq.payment_amount) AS Total 
	FROM 
		quarterly_sales fq 
	GROUP BY 
		fq.store_code;
END;
$$ LANGUAGE PLPGSQL;

--Call stored procedure. The objective of this report is to depict the quarterly retail sales of DVD rentals.  
--Since this report will be run after each quarter of the current year, I will recommend to execute
--this action at the end of each month to have updated data. Furthermore, it will provide us with a 
-- overview of our sales, in case we need to meet an accountable goal by the following quarter.
CALL refresh_reports(3);

--View results
SELECT * from quarterly_sales;
Select * from summary_sales;





