/*
Purpose: Load the raw Kaggle CSV files after running 00_create_schema.sql.
Dialect: MySQL 8.0+
Run from the repository root with LOCAL INFILE enabled.
The raw CSVs remain unchanged in 01_raw_data/.
*/

USE commerce_practice;

SET FOREIGN_KEY_CHECKS = 0;

LOAD DATA LOCAL INFILE '01_raw_data/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(customer_id, name, email, country, age, signup_date, @marketing_opt_in)
SET marketing_opt_in = CASE
    WHEN LOWER(TRIM(@marketing_opt_in)) = 'true' THEN 1
    ELSE 0
END;

LOAD DATA LOCAL INFILE '01_raw_data/products.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '01_raw_data/sessions.csv'
INTO TABLE sessions
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '01_raw_data/orders.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '01_raw_data/events.csv'
INTO TABLE events
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(event_id, session_id, `timestamp`, event_type, @product_id, @qty, @cart_size,
 @payment, @discount_pct, @amount_usd)
SET product_id = NULLIF(@product_id, ''),
    qty = NULLIF(@qty, ''),
    cart_size = NULLIF(@cart_size, ''),
    payment = NULLIF(@payment, ''),
    discount_pct = NULLIF(@discount_pct, ''),
    amount_usd = NULLIF(@amount_usd, '');

LOAD DATA LOCAL INFILE '01_raw_data/order_items.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '01_raw_data/reviews.csv'
INTO TABLE reviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

SET FOREIGN_KEY_CHECKS = 1;

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'sessions', COUNT(*) FROM sessions
UNION ALL SELECT 'events', COUNT(*) FROM events
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'reviews', COUNT(*) FROM reviews;
