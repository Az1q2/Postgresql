-- запрос с внутренним соединением трёх таблиц (товар — категория — продавец)
SELECT
    p.id,
    p.title,
    c.name category,
    s.store_name seller,
    p.price
FROM products p
INNER JOIN categories c ON c.id = p.category_id
INNER JOIN sellers s ON s.id = p.seller_id
ORDER BY p.id;


-- Товары без отзывов: LEFT ANTI JOIN
SELECT
    p.id,
    p.title,
    r.score,
    r.comment,
    p.price
FROM products p
LEFT JOIN reviews r ON r.product_id = p.id
WHERE r.id IS NULL
ORDER BY p.id;

-- Количество товаров и средняя цена по каждой категории, включая категории без товаров
SELECT
    c.id,
    c.name category,
    COUNT(p.id) products_count,
    AVG(p.price) avg_price
FROM categories c
LEFT JOIN products p ON p.category_id = c.id
GROUP BY c.id, c.name
ORDER BY c.id;

-- Категории со средней ценой активных товаров выше 30000: WHERE фильтрует строки, HAVING — группы
SELECT
    c.id,
    c.name category,
    COUNT(p.id) products_count,
    AVG(p.price) avg_price
FROM categories c
INNER JOIN products p ON p.category_id = c.id
WHERE p.is_active = TRUE
GROUP BY c.id, c.name
HAVING AVG(p.price) > 30000
ORDER BY avg_price DESC, c.id;

-- Скалярный подзапрос: товары дороже средней цены по всему каталогу
SELECT
    p.id,
    p.title,
    p.price
FROM products p
WHERE p.price > (
    SELECT AVG(price)
    FROM products
)
ORDER BY p.price DESC, p.id;

-- Подзапрос с IN: товары в дочерних категориях
SELECT
    p.id,
    p.title,
    p.category_id,
    p.price
FROM products p
WHERE p.category_id IN (
    SELECT c.id
    FROM categories c
    WHERE c.parent_id IS NOT NULL
)
ORDER BY p.id;

-- Коррелированный подзапрос с EXISTS: магазины, у которых есть хотя бы один товар
SELECT
    s.id,
    s.store_name
FROM sellers s
WHERE EXISTS (
    SELECT 1
    FROM products p
    WHERE p.seller_id = s.id
)
ORDER BY s.id;
