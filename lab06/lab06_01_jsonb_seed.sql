ALTER TABLE products ADD COLUMN IF NOT EXISTS attributes JSONB;

-- Телефоны (category_id = 4): диагональ, RAM, цвет, бренд
UPDATE products
SET attributes = jsonb_build_object(
    'brand', (ARRAY['Samsung', 'Apple', 'Xiaomi', 'Huawei'])[id % 4 + 1],
    'screen_inch', round((6.1 + (id % 5) * 0.15)::numeric, 2),
    'ram_gb', (ARRAY[4, 6, 8, 12])[id % 4 + 1],
    'color', (ARRAY['black', 'white', 'blue', 'red'])[id % 4 + 1]
)
WHERE category_id = 4;

-- Ноутбуки (category_id = 5): RAM, диск, ОС, бренд
UPDATE products
SET attributes = jsonb_build_object(
    'brand', (ARRAY['Lenovo', 'ASUS', 'Dell', 'HP'])[id % 4 + 1],
    'ram_gb', (ARRAY[8, 16, 32])[id % 3 + 1],
    'storage_gb', (ARRAY[256, 512, 1024])[id % 3 + 1],
    'os', (ARRAY['Linux', 'Windows', 'Linux'])[id % 3 + 1]
)
WHERE category_id = 5;

-- Проверка: несколько строк с атрибутами
SELECT id, title, attributes
FROM products
WHERE attributes IS NOT NULL
ORDER BY id
LIMIT 5;
