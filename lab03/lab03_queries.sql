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
