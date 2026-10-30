-- Задание 1.1: Успешная транзакция (COMMIT)
SELECT product_id, quantity FROM stock WHERE product_id = 495;

BEGIN;

INSERT INTO orders (user_id, status, total_amount)
VALUES (10, 'new', 49904.34)
RETURNING id;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (1018, 495, 1, 49904.34);

UPDATE stock
SET quantity = quantity - 1
WHERE product_id = 495;

COMMIT;

SELECT * FROM orders WHERE id = 1018;
SELECT * FROM order_items WHERE order_id = 1018;
SELECT * FROM stock WHERE product_id = 495;

-- Задание 1.2: Транзакция с ошибкой и отменой (ROLLBACK)
SELECT product_id, quantity FROM stock WHERE product_id = 495;

BEGIN;

INSERT INTO orders (user_id, status, total_amount)
VALUES (11, 'new', 999999.00)
RETURNING id;

UPDATE stock
SET quantity = quantity - 999999
WHERE product_id = 495;

ROLLBACK;

SELECT * FROM orders WHERE user_id = 11 AND total_amount = 999999.00;
SELECT * FROM stock WHERE product_id = 495;
