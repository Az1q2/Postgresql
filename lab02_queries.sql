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

-- Товары в диапазоне цен от 10000 до 20000
SELECT id, title, price
FROM products
WHERE price BETWEEN 10000 AND 20000
ORDER BY id;

-- Товары выбранных категорий
SELECT id, title, category_id
FROM products
WHERE category_id IN (4, 5)
ORDER BY id;

-- Телефоны без описания
SELECT id, title, description
FROM products
WHERE title ILIKE '%телефон%'
  AND description IS NULL
ORDER BY id;

-- По цене по убыванию, при равной цене — по названию
SELECT id, title, price
FROM products
ORDER BY price DESC, title ASC;