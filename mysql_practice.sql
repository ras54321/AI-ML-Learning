-- MySQL Practice: Transactions, Joins, Subqueries, Views, Indexes, Procedures
-- Run the complete file in MySQL Workbench or the mysql command-line client.
-- DELIMITER is a client command supported by these tools.
-- Example: mysql -u root -p < mysql_practice.sql
--
-- SETUP: This script creates a separate practice database. Run it once in a
-- fresh database; for another run, change BOTH database names below to a new
-- name. Stop if setup fails. Existing databases are not deleted or reset.
-- These are learning examples, not a production banking implementation.

CREATE DATABASE sigma_sql_practice;
USE sigma_sql_practice;

-- ---------------------------------------------------------------------------
-- 1. Transactions: COMMIT, SAVEPOINT, and ROLLBACK TO SAVEPOINT
-- ---------------------------------------------------------------------------

CREATE TABLE accounts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50),
    balance DECIMAL(10, 2)
) ENGINE = InnoDB;

INSERT INTO accounts (name, balance)
VALUES
    ('Adam', 500.00),
    ('Bob', 300.00),
    ('Charlie', 1000.00);

SELECT * FROM accounts ORDER BY id;

-- Transfer 50.00 from Adam to Bob and commit both updates.
-- A comment such as "-- ERROR" does not cause an SQL error or a rollback.
START TRANSACTION;

UPDATE accounts
SET balance = balance - 50.00
WHERE id = 1;

UPDATE accounts
SET balance = balance + 50.00
WHERE id = 2;

COMMIT;

-- Expected balances: Adam = 450.00, Bob = 350.00, Charlie = 1000.00.
SELECT * FROM accounts ORDER BY id;

-- Keep the 1000.00 top-up but undo the subsequent 10.00 adjustment.
START TRANSACTION;

UPDATE accounts
SET balance = balance + 1000.00
WHERE id = 1;

SAVEPOINT after_wallet_topup;

UPDATE accounts
SET balance = balance + 10.00
WHERE id = 1;

ROLLBACK TO SAVEPOINT after_wallet_topup;
COMMIT;

-- Expected Adam balance: 1450.00.
SELECT * FROM accounts ORDER BY id;

-- ---------------------------------------------------------------------------
-- 2. Sample data for joins and subqueries
-- ---------------------------------------------------------------------------

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    name VARCHAR(30),
    city VARCHAR(20)
) ENGINE = InnoDB;

INSERT INTO customers (customer_id, name, city)
VALUES
    (1, 'Alice', 'Mumbai'),
    (2, 'Bob', 'Delhi'),
    (3, 'Charlie', 'Bangalore'),
    (4, 'David', 'Mumbai');

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    amount INT
) ENGINE = InnoDB;

-- Customer 5 intentionally has no matching customer row so outer joins
-- demonstrate unmatched orders. No foreign key is defined for this exercise.
INSERT INTO orders (order_id, customer_id, amount)
VALUES
    (101, 1, 500),
    (102, 1, 900),
    (103, 2, 300),
    (104, 5, 700);

-- ---------------------------------------------------------------------------
-- 3. Joins
-- ---------------------------------------------------------------------------

-- INNER JOIN: only matching customers and orders (3 rows).
SELECT c.customer_id, c.name, o.order_id, o.amount
FROM customers AS c
INNER JOIN orders AS o
    ON c.customer_id = o.customer_id;

-- LEFT JOIN: all customers, including those without orders (5 rows).
SELECT c.customer_id, c.name, o.order_id, o.amount
FROM customers AS c
LEFT JOIN orders AS o
    ON c.customer_id = o.customer_id;

-- RIGHT JOIN: all orders, including those without a matching customer (4 rows).
SELECT c.customer_id, c.name, o.customer_id AS order_customer_id,
       o.order_id, o.amount
FROM customers AS c
RIGHT JOIN orders AS o
    ON c.customer_id = o.customer_id;

-- FULL OUTER JOIN emulation: MySQL has no FULL OUTER JOIN operator.
-- Combine the left join with only unmatched orders to avoid double-counting
-- matches. UNION ALL preserves duplicates in the projected results (6 rows).
SELECT c.customer_id, c.name, o.customer_id AS order_customer_id,
       o.order_id, o.amount
FROM customers AS c
LEFT JOIN orders AS o
    ON c.customer_id = o.customer_id
UNION ALL
SELECT c.customer_id, c.name, o.customer_id AS order_customer_id,
       o.order_id, o.amount
FROM customers AS c
RIGHT JOIN orders AS o
    ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL;

-- CROSS JOIN: every customer paired with every order (4 x 4 = 16 rows).
SELECT c.customer_id, c.name, o.order_id, o.amount
FROM customers AS c
CROSS JOIN orders AS o;

-- SELF JOIN: find different customers in the same city.
-- The ID comparison excludes self-matches and reversed duplicate pairs.
-- Expected pair: Alice and David in Mumbai.
SELECT a.name AS customer_1, b.name AS customer_2, a.city
FROM customers AS a
INNER JOIN customers AS b
    ON a.city = b.city
   AND a.customer_id < b.customer_id;

-- LEFT EXCLUSIVE JOIN: customers without orders (Charlie and David).
SELECT c.customer_id, c.name, c.city
FROM customers AS c
LEFT JOIN orders AS o
    ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;

-- RIGHT EXCLUSIVE JOIN: orders without a matching customer (order 104).
SELECT o.order_id, o.customer_id, o.amount
FROM customers AS c
RIGHT JOIN orders AS o
    ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL;

-- ---------------------------------------------------------------------------
-- 4. Subqueries
-- ---------------------------------------------------------------------------

-- WHERE subquery: orders above the overall average amount of 600.00.
-- Expected order IDs: 102 and 104.
SELECT order_id, customer_id, amount
FROM orders
WHERE amount > (
    SELECT AVG(amount)
    FROM orders
);

-- SELECT subquery: count orders for each customer (correlated subquery).
SELECT c.name,
       (
           SELECT COUNT(*)
           FROM orders AS o
           WHERE o.customer_id = c.customer_id
       ) AS order_count
FROM customers AS c;

-- FROM subquery: use a derived table of average order amounts per customer ID.
SELECT summary.customer_id, summary.avg_amount
FROM (
    SELECT customer_id, AVG(amount) AS avg_amount
    FROM orders
    GROUP BY customer_id
) AS summary;

-- ---------------------------------------------------------------------------
-- 5. Views
-- ---------------------------------------------------------------------------

CREATE VIEW customer_details AS
SELECT customer_id, name
FROM customers;

SELECT * FROM customer_details;

CREATE VIEW customer_orders AS
SELECT c.customer_id, c.name, o.order_id
FROM customers AS c
INNER JOIN orders AS o
    ON c.customer_id = o.customer_id;

SELECT * FROM customer_orders;

-- ---------------------------------------------------------------------------
-- 6. Indexes
-- ---------------------------------------------------------------------------

CREATE TABLE accounts1 (
    account_id INT PRIMARY KEY,
    name VARCHAR(50),
    balance DECIMAL(10, 2),
    branch VARCHAR(50)
) ENGINE = InnoDB;

INSERT INTO accounts1 (account_id, name, balance, branch)
VALUES
    (1, 'Adam', 500.00, 'Mumbai'),
    (2, 'Bob', 300.00, 'Delhi'),
    (3, 'Charlie', 700.00, 'Bangalore'),
    (4, 'David', 1000.00, 'Noida');

SELECT * FROM accounts1 ORDER BY account_id;

-- Single-column index.
CREATE INDEX idx_branch ON accounts1 (branch);
SHOW INDEX FROM accounts1;

-- Composite index: column order matters.
CREATE INDEX idx_branch_balance ON accounts1 (branch, balance);
SHOW INDEX FROM accounts1;

-- Remove the composite index; keep idx_branch.
DROP INDEX idx_branch_balance ON accounts1;
SHOW INDEX FROM accounts1;

-- ---------------------------------------------------------------------------
-- 7. Stored procedures: IN and OUT parameters
-- ---------------------------------------------------------------------------
-- Different names keep both examples available after the script completes.

DELIMITER $$

-- IN parameter: return the matching balance as a result set.
CREATE PROCEDURE check_balance(IN p_account_id INT)
BEGIN
    SELECT balance
    FROM accounts1
    WHERE account_id = p_account_id;
END $$

-- IN + OUT parameters: assign the balance to an output variable.
-- A scalar subquery returns NULL when the account does not exist.
CREATE PROCEDURE check_balance_out(
    IN p_account_id INT,
    OUT p_balance DECIMAL(10, 2)
)
BEGIN
    SET p_balance = (
        SELECT balance
        FROM accounts1
        WHERE account_id = p_account_id
    );
END $$

DELIMITER ;

CALL check_balance(1);

CALL check_balance_out(1, @balance);
SELECT @balance AS account_balance;

-- Both procedure examples return 500.00 from accounts1.
