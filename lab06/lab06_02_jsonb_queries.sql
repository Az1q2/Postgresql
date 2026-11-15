-- 2.1 Извлечь бренд, RAM и цвет у телефонов
SELECT
    id,
    title,
    attributes->>'brand'      AS brand,
    (attributes->>'ram_gb')::int AS ram_gb,
    attributes->>'color'      AS color
FROM products
WHERE category_id = 4
ORDER BY id
LIMIT 10;

-- 2.2 Фильтр через @>: только телефоны с RAM = 8 ГБ
SELECT id, title, attributes->>'ram_gb' AS ram_gb
FROM products
WHERE attributes @> '{"ram_gb": 8}';

-- 2.3 Ноутбуки на Linux с 16 ГБ RAM
SELECT id, title, attributes
FROM products
WHERE attributes @> '{"os": "Linux", "ram_gb": 16}';

-- 2.4 Проверка наличия ключа оператором ?
SELECT id, title
FROM products
WHERE attributes ? 'screen_inch'
ORDER BY ID;

-- 2.5 Товары по бренду Samsung
SELECT id, title, attributes->>'brand' AS brand
FROM products
WHERE attributes @> '{"brand": "Samsung"}';
