## Файлы

| Файл | Назначение |
|---|---|
| [lab06_01_jsonb_seed.sql](lab06_01_jsonb_seed.sql) | Добавление столбца `attributes JSONB` к таблице `products` и генерация разнородных характеристик |
| [lab06_02_jsonb_queries.sql](lab06_02_jsonb_queries.sql) | Извлечение полей (`->`, `->>`), проверка ключей (`?`) и поиск по фрагментам (`@>`) |
| [lab06_03_explain_before.sql](lab06_03_explain_before.sql) | Базовые планы `EXPLAIN ANALYZE` до создания индексов (Seq Scan, сортировка, фильтрация) |
| [lab06_04_btree_indexes.sql](lab06_04_btree_indexes.sql) | Создание B-tree индексов (`price`, `category_id`) и анализ планов после оптимизации |
| [lab06_05_gin_index.sql](lab06_05_gin_index.sql) | Создание GIN-индекса по `attributes` и демонстрация работы `Bitmap Index Scan` |
| [lab06_06_insert_benchmark.sql](lab06_06_insert_benchmark.sql) | Бенчмарк массовой вставки 100 000 строк: сравнение накладных расходов таблицы с индексами и без |
| [lab1.sql](../lab01/lab1.sql) | Базовая DDL-структура таблиц маркетплейса |
| [lab02_seed.sql](../lab02/lab02_seed.sql) | Первичный сид тестовых данных |

---

## 1. Порядок запуска

1. Подключиться к PostgreSQL-базе данных `marketplace`.
2. Последовательно выполнять скрипты:
   - `lab06_01_jsonb_seed.sql` — расширение схемы столбцом `attributes` и наполнение характеристиками телефонов и ноутбуков.
   - `lab06_02_jsonb_queries.sql` — выполнение запросов к слабоструктурированным данным JSONB.
   - `lab06_03_explain_before.sql` — фиксация планов выполнения и времени «до» оптимизации.
   - `lab06_04_btree_indexes.sql` — создание B-tree индексов и фиксация планов «после» оптимизации.
   - `lab06_05_gin_index.sql` — создание GIN-индекса по JSONB и проверка планов `Bitmap Index Scan`.
   - `lab06_06_insert_benchmark.sql` — запуск бенчмарка вставки 100 000 строк и замер накладных расходов.

---

## 2. Использование JSONB для слабоструктурированных характеристик

### 2.1. Добавление столбца и наполнение данными

В реляционных базах сложно хранить свойства товаров, сильно различающихся по категориям (у телефонов — диагональ и цвет, у ноутбуков — накопитель и ОС). Использование типа `JSONB` позволяет не раздувать таблицу пустыми столбцами.

```sql
ALTER TABLE products ADD COLUMN IF NOT EXISTS attributes JSONB;

-- Наполнение телефонов (category_id = 4)
UPDATE products
SET attributes = jsonb_build_object(
    'brand',       (ARRAY['Samsung', 'Apple', 'Xiaomi', 'Huawei'])[id % 4 + 1],
    'screen_inch', round((6.1 + (id % 5) * 0.15)::numeric, 2),
    'ram_gb',      (ARRAY[4, 6, 8, 12])[id % 4 + 1],
    'color',       (ARRAY['black', 'white', 'blue', 'red'])[id % 4 + 1]
)
WHERE category_id = 4;

-- Наполнение ноутбуков (category_id = 5)
UPDATE products
SET attributes = jsonb_build_object(
    'brand',       (ARRAY['Lenovo', 'ASUS', 'Dell', 'HP'])[id % 4 + 1],
    'ram_gb',      (ARRAY[8, 16, 32])[id % 3 + 1],
    'storage_gb',  (ARRAY[256, 512, 1024])[id % 3 + 1],
    'os',          (ARRAY['Linux', 'Windows', 'Linux'])[id % 3 + 1]
)
WHERE category_id = 5;
```

---

### 2.2. Запросы к данным JSONB

```sql
-- 1. Извлечение полей оператором ->> (в текстовом виде для отображения и CAST)
SELECT id, title, attributes->>'brand' AS brand, (attributes->>'ram_gb')::int AS ram_gb
FROM products
WHERE category_id = 4
LIMIT 5;

-- 2. Фильтрация по вхождению JSON-фрагмента оператором @>
SELECT id, title, attributes->>'ram_gb' AS ram_gb
FROM products
WHERE attributes @> '{"ram_gb": 8}';

-- 3. Проверка наличия ключа оператором ?
SELECT id, title
FROM products
WHERE attributes ? 'screen_inch';
```

**Разница операторов:**
- `->` возвращает значение как элемент `jsonb` (в кавычках).
- `->>` извлекает значение как `text` (пригодно для фильтров, сортировок и приведения типов `::int`).
- `@>` проверяет, содержит ли левый JSON-документ фрагмент справа.
- `?` проверяет физическое присутствие ключа в документе.

---

## 3. Анализ планов выполнения до создания индексов

Планы получены командой `EXPLAIN ANALYZE` на «горячем кэше» без пользовательских индексов.

### Запрос 1: Фильтрация по цене и сортировка
```sql
EXPLAIN ANALYZE
SELECT id, title, price
FROM products
WHERE price > 95000
ORDER BY price DESC;
```
* **План:** `Seq Scan on products` $\rightarrow$ `Filter: (price > 95000::numeric)` $\rightarrow$ `Sort Method: quicksort`.
* **Пояснение:** База была вынуждена прочитать всю таблицу (1000 строк), отбросить неподходящие строки и загрузить оставшиеся 25 строк в оперативную память для сортировки алгоритмом Quicksort.

### Запрос 2: Соединение трёх таблиц
```sql
EXPLAIN ANALYZE
SELECT p.id, p.title, c.name, COUNT(r.id)
FROM products p
JOIN categories c ON c.id = p.category_id
LEFT JOIN reviews r ON r.product_id = p.id
WHERE p.category_id = 4
GROUP BY p.id, p.title, c.name;
```
* **План:** `Hash Join` по `categories`, `HashAggregate` для группировки, `Seq Scan` по `products` и `reviews`.
* **Пояснение:** Полные таблицы сканируются линейно, формируя хэш-таблицы в оперативной памяти для соединения.

### Запрос 3: Поиск внутри JSONB
```sql
EXPLAIN ANALYZE
SELECT id, title
FROM products
WHERE attributes @> '{"ram_gb": 8}';
```
* **План:** `Seq Scan on products` с проверкой предиката `(attributes @> '{"ram_gb": 8}'::jsonb)` для каждой строки на лету.

---

## 4. Оптимизация B-tree индексами

Созданы B-tree индексы по наиболее частым предикатам фильтрации:
```sql
CREATE INDEX idx_products_price ON products (price);
CREATE INDEX idx_products_category ON products (category_id);
```

### Сравнение планов «До и После»:

| Параметр | До индексации (Файл 03) | После индексации (Файл 04) |
|---|---|---|
| **Тип сканирования (Запрос 1)** | `Seq Scan on products` | **`Index Scan using idx_products_price`** |
| **Операция сортировки** | `Sort: quicksort` в RAM | **Отсутствует (Zero-cost sort)** |
| **Обращение к страницам** | Сканирование всех страниц таблицы | Прямой спуск по B-дереву в обратном порядке |

**Выводы по B-tree:**
1. Индекс полностью устранил накладные расходы на сортировку `ORDER BY price DESC`: база читает данные из индекса уже в готовом отсортированном виде (`Index Scan Backward`).
2. Для таблицы `reviews` (всего 102 строки, 2 страницы в памяти) оптимизатор сохраняет выбор `Seq Scan` (стоимость 3.28 против 8.30 у индекса), что демонстрирует порог рентабельности индексов: на микро-таблицах линейное чтение страниц дешевле накладных расходов на обход дерева. При принудительном `SET enable_seqscan = off;` план успешно задействует `Index Scan using idx_reviews_product`.

---

## 5. Оптимизация поиска в JSONB с помощью GIN-индекса

B-tree неприменим для поиска внутри составных документов. Создан GIN (Generalized Inverted Index):
```sql
CREATE INDEX idx_products_attributes_gin ON products USING GIN (attributes);
```

```sql
SET enable_seqscan = off;

EXPLAIN ANALYZE
SELECT id, title, attributes
FROM products
WHERE attributes @> '{"brand": "Apple", "screen_inch": 6.7}';

SET enable_seqscan = on;
```

### Анализ плана выполнения:
* **Тип доступа:** `Bitmap Heap Scan on products`
* **Индексный узел:** `-> Bitmap Index Scan on idx_products_attributes_gin`
* **Принцип работы:** 
  1. GIN-индекс разбирает JSONB на отдельные пары «ключ-значение» и формирует списки идентификаторов строк (Posting Lists).
  2. При выполнении оператора `@>` происходит пересечение списков (побитовое `AND`) в оперативной памяти без обращения к самой таблице.
  3. `Bitmap Heap Scan` точечно обращается к диску только за подтверждёнными строками, исключая лишний ввод-вывод.

---

## 6. Обратная сторона индексов: бенчмарк массовой вставки

Замерено время пакетной вставки **100 000 строк** в «чистую» таблицу и таблицу с двумя индексами:

```sql
-- Таблица без индексов
CREATE TABLE test_no_index (id BIGINT, val NUMERIC, label TEXT);
INSERT INTO test_no_index SELECT g, round((random() * 1000)::numeric, 2), 'item_' || g FROM generate_series(1, 100000) g;

-- Таблица с двумя B-tree индексами
CREATE TABLE test_with_index (id BIGINT, val NUMERIC, label TEXT);
CREATE INDEX idx_twi_val ON test_with_index (val);
CREATE INDEX idx_twi_label ON test_with_index (label);
INSERT INTO test_with_index SELECT g, round((random() * 1000)::numeric, 2), 'item_' || g FROM generate_series(1, 100000) g;
```

### Результаты измерений:

| Конфигурация таблицы | Количество строк | Время выполнения | Замедление |
|---|---:|---:|---:|
| **Без индексов (`test_no_index`)** | 100 000 | **~140–180 мс** | Базовое (1.0x) |
| **С двумя индексами (`test_with_index`)** | 100 000 | **~540–600 мс** | **~3.5 – 4.0x медленнее** (+400 мс) |

**Физическое объяснение:**
- При вставке без индексов СУБД выполняет последовательную потоковую запись страниц на диск (Append-only).
- При наличии двух индексов на **каждую** из 100 000 строк СУБД обязана:
  1. Записать кортеж в саму таблицу (Heap).
  2. Рассчитать ключ B-дерева и произвести вставку в индекс `idx_twi_val` (с возможным расщеплением страниц `Split`).
  3. Рассчитать ключ B-дерева и произвести вставку в индекс `idx_twi_label`.
- **Практический вывод:** Индексы ускоряют чтение ценой замедления записи и расхода дискового пространства. При массовой миграции или пакетной загрузке данных (ETL) индексы рекомендуется временно удалять (`DROP INDEX`) и воссоздавать заново после завершения загрузки.
