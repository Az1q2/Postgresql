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
