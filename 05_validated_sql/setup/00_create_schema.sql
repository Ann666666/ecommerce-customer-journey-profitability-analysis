/*
Purpose: Create the MySQL schema used by the validated portfolio analysis.
Dialect: MySQL 8.0+
Notes:
  - Load source files in this order: customers, products, sessions, orders,
    events, order_items, reviews.
  - order_items intentionally has no synthetic primary key because the source
    file does not provide a stable order_item_id.
*/

CREATE DATABASE IF NOT EXISTS commerce_practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE commerce_practice;

CREATE TABLE IF NOT EXISTS customers (
    customer_id BIGINT NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    country CHAR(2) NOT NULL,
    age SMALLINT NOT NULL,
    signup_date DATE NOT NULL,
    marketing_opt_in BOOLEAN NOT NULL,
    PRIMARY KEY (customer_id),
    UNIQUE KEY uq_customers_email (email)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS products (
    product_id BIGINT NOT NULL,
    category VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    price_usd DECIMAL(12, 2) NOT NULL,
    cost_usd DECIMAL(12, 2) NOT NULL,
    margin_usd DECIMAL(12, 2) NOT NULL,
    PRIMARY KEY (product_id),
    KEY idx_products_category (category)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS sessions (
    session_id BIGINT NOT NULL,
    customer_id BIGINT NOT NULL,
    start_time DATETIME NOT NULL,
    device VARCHAR(20) NOT NULL,
    source VARCHAR(30) NOT NULL,
    country CHAR(2) NOT NULL,
    PRIMARY KEY (session_id),
    KEY idx_sessions_customer (customer_id),
    KEY idx_sessions_source_device (source, device),
    CONSTRAINT fk_sessions_customer
      FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS orders (
    order_id BIGINT NOT NULL,
    customer_id BIGINT NOT NULL,
    order_time DATETIME NOT NULL,
    payment_method VARCHAR(30) NOT NULL,
    discount_pct DECIMAL(5, 2) NOT NULL,
    subtotal_usd DECIMAL(14, 2) NOT NULL,
    total_usd DECIMAL(14, 2) NOT NULL,
    country CHAR(2) NOT NULL,
    device VARCHAR(20) NOT NULL,
    source VARCHAR(30) NOT NULL,
    PRIMARY KEY (order_id),
    KEY idx_orders_customer_time (customer_id, order_time),
    KEY idx_orders_time (order_time),
    CONSTRAINT fk_orders_customer
      FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS events (
    event_id BIGINT NOT NULL,
    session_id BIGINT NOT NULL,
    `timestamp` DATETIME NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    product_id BIGINT NULL,
    qty INT NULL,
    cart_size INT NULL,
    payment VARCHAR(30) NULL,
    discount_pct DECIMAL(5, 2) NULL,
    amount_usd DECIMAL(14, 2) NULL,
    PRIMARY KEY (event_id),
    KEY idx_events_session_type_time (session_id, event_type, `timestamp`),
    KEY idx_events_product (product_id),
    CONSTRAINT fk_events_session
      FOREIGN KEY (session_id) REFERENCES sessions (session_id),
    CONSTRAINT fk_events_product
      FOREIGN KEY (product_id) REFERENCES products (product_id)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS order_items (
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    unit_price_usd DECIMAL(12, 2) NOT NULL,
    quantity INT NOT NULL,
    line_total_usd DECIMAL(14, 2) NOT NULL,
    KEY idx_order_items_order (order_id),
    KEY idx_order_items_product (product_id),
    CONSTRAINT fk_order_items_order
      FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_order_items_product
      FOREIGN KEY (product_id) REFERENCES products (product_id)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS reviews (
    review_id BIGINT NOT NULL,
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    rating SMALLINT NOT NULL,
    review_text TEXT NOT NULL,
    review_time DATETIME NOT NULL,
    PRIMARY KEY (review_id),
    KEY idx_reviews_order_product (order_id, product_id),
    CONSTRAINT fk_reviews_order
      FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_reviews_product
      FOREIGN KEY (product_id) REFERENCES products (product_id)
) ENGINE = InnoDB;

