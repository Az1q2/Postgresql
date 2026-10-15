-- Уникальные сочетания категории и активности товаров
SELECT DISTINCT
    category_id category_number,
    is_active available
FROM products
ORDER BY category_number, available;

-- Активные телефоны до 20000 и ноутбуки до 40000
SELECT id, title, category_id, price, is_active
FROM products
WHERE is_active = TRUE
  AND (
      (category_id = 4 AND price <= 20000)
      OR
      (category_id = 5 AND price <= 40000)
  )
ORDER BY id;