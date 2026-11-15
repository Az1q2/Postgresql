-- Запрос 1: фильтр по цене — Seq Scan по всей таблице products (1000 строк)
EXPLAIN ANALYZE
SELECT id, title, price
FROM products
WHERE price > 95000
ORDER BY price DESC;

-- Запрос 2: JOIN трёх таблиц с фильтром по категории (до индекса idx_products_category)
EXPLAIN ANALYZE
SELECT p.id, p.title, c.name, COUNT(r.id)
FROM products p
JOIN categories c ON c.id = p.category_id
LEFT JOIN reviews r ON r.product_id = p.id
WHERE p.category_id = 4
GROUP BY p.id, p.title, c.name;