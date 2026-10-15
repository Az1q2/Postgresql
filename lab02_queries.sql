-- Уникальные сочетания категории и активности товаров
SELECT DISTINCT
    category_id category_number,
    is_active available
FROM products
ORDER BY category_number, available;
