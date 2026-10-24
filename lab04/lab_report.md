
## 1. Список файлов

| Файл | Назначение |
|---|---|
| [lab04_queries.sql](lab04_queries.sql) | Основной набор аналитических SQL-запросов с использованием оконных функций |
| [lab04_seed.sql](lab04_seed.sql) | Дополнительные тестовые данные (дубликаты цен для наглядной демонстрации ранжирования) |
| [lab1.sql](../lab01/lab1.sql) | Базовая DDL-схема таблиц базы данных `marketplace` |
| [lab02_seed.sql](../lab02/lab02_seed.sql) | Первичный наборы тестовых данных (товары, заказы, позиции заказов) |

---

## 2. Порядок запуска и описание тестовых данных

1. Подключиться к СУБД PostgreSQL (база данных `marketplace`).
2. Убедиться, что структуры таблиц и первичные данные из `lab1.sql` и `lab02_seed.sql` успешно развёрнуты.
3. Выполнить скрипт `lab04_seed.sql`, вставляющий в категорию «Телефоны» (ID: 4) демонстрационные товары с идентичными ценами (`24719.00`), что необходимо для корректного тестирования поведения функций `ROW_NUMBER`, `RANK` и `DENSE_RANK`.
4. Последовательно запустить аналитические запросы из файла `lab04_queries.sql`.

---

## 3. Скрипты

### Ранжирование товаров по цене внутри категории



```sql
SELECT c.name,
       p.id,
       p.category_id,
       row_number() OVER W rn,
       rank() OVER W rnk,
       dense_rank() OVER W dense_rank
FROM products p 
JOIN categories c ON c.id = p.category_id
WINDOW W AS (PARTITION BY p.category_id ORDER BY p.price DESC);
```

**Принцип работы и пояснение:**  
Запрос делит товары на автономные окна по категориям (`PARTITION BY p.category_id`) и сортирует их по убыванию цены (`ORDER BY p.price DESC`). Для сокращения дублирования кода оконное определение вынесено в секцию `WINDOW W AS (...)`.

- `ROW_NUMBER()` выдаёт сквозную уникальную нумерацию строк подряд (1, 2, 3, 4...), несмотря на одинаковую цену.
- `RANK()` присваивает одинаковым ценам одинаковый ранг, но производит пропуск следующих рангов на количество совпадений (например: 1, 1, 3).
- `DENSE_RANK()` также присваивает совпадениям одинаковый ранг, но не оставляет дыр в нумерации (например: 1, 1, 2).

**Результат выполнения (фрагмент с коллизией цен):**

| name | id | category_id | rn | rnk | dense_rank |
|---|---:|---:|---:|---:|---:|
| Телефоны | 1001 | 4 | 1 | 1 | 1 |
| Телефоны | 1002 | 4 | 2 | 1 | 1 |
| Телефоны | 2 | 4 | 3 | 3 | 2 |
| Телефоны | 1 | 4 | 4 | 4 | 3 |

---

### Топ-3 самых дорогих товара в каждой категории

```sql
WITH ranked AS (
    SELECT
        c.name,
        p.id AS product_id,
        p.category_id,
        p.price,
        row_number() OVER (
            PARTITION BY p.category_id
            ORDER BY p.price DESC, p.id
        ) AS rn
    FROM products p
    JOIN categories c ON p.category_id = c.id
)
SELECT name, product_id, category_id, price, rn
FROM ranked
WHERE rn <= 3
ORDER BY category_id, rn;
```

**Принцип работы и пояснение:**  
Поскольку оконные функции вычисляются после фильтрации `WHERE`, прямое отсечение вида `WHERE ROW_NUMBER() OVER (...) <= 3` в одном блоке синтаксически недопустимо. Для этого используется обобщенное табличное выражение (CTE) `ranked`, где каждая позиция нумеруется внутри своей категории. Гарантия детерминированного порядка достигается добавочным критерием сортировки по `p.id`. Внешний запрос фильтрует строки, отбирая только позиции с `rn <= 3`.

**Результат выполнения:**

| name | product_id | category_id | price | rn |
|---|---:|---:|---:|---:|
| Телефоны | 935 | 4 | 99857.04 | 1 |
| Телефоны | 533 | 4 | 99836.94 | 2 |
| Телефоны | 640 | 4 | 99775.40 | 3 |
| Ноутбуки | 949 | 5 | 99410.34 | 1 |
| Ноутбуки | 812 | 5 | 98900.00 | 2 |
| Ноутбуки | 701 | 5 | 97500.50 | 3 |

---

### Расчёт нарастающего итога выручки по дням


```sql
SELECT
    o.created_at::date AS day,
    SUM(oi.quantity * oi.unit_price) AS day_revenue,
    SUM(SUM(oi.quantity * oi.unit_price))
        OVER (ORDER BY o.created_at::date) AS running_total
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.created_at::date
ORDER BY day;
```

**Принцип работы и пояснение:**  
Запрос демонстрирует вложенную агрегацию. Внутренняя функция `SUM(oi.quantity * oi.unit_price)` рассчитывает дневную выручку в контексте традиционной группировки `GROUP BY o.created_at::date`. Внешняя оконная функция `SUM(...) OVER (ORDER BY o.created_at::date)` последовательно суммирует дневные показатели от самого первого дня до текущей даты включительно (рамка по умолчанию `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`).

**Результат выполнения (теоретический):**

| day | day_revenue | running_total |
|---|---:|---:|
| 2026-10-20 | 15000.00 | 15000.00 |
| 2026-10-21 | 22500.00 | 37500.00 |
| 2026-10-22 | 18000.00 | 55500.00 |
| 2026-10-23 | 31000.00 | 86500.00 |

---

### Доля выручки продавца внутри категории


```sql
SELECT
    p.seller_id,
    p.category_id,
    SUM(p.price) AS item_revenue,
    SUM(p.price) * 100.0 / SUM(SUM(p.price)) OVER (PARTITION BY category_id) share_pct
FROM products p
WHERE is_active = TRUE
GROUP BY seller_id, category_id;
```

**Принцип работы и пояснение:**  
С помощью `GROUP BY seller_id, category_id` находится суммарная стоимость активных товаров конкретного продавца в категории (`item_revenue`). Оконная функция `SUM(SUM(p.price)) OVER (PARTITION BY category_id)` рассчитывает общую стоимость всех товаров данной категории по всем продавцам без схлопывания детальных строк. Деление с умножением на `100.0` позволяет мгновенно высчитать процентную долю каждого продавца.

**Результат выполнения (теоретический):**

| seller_id | category_id | item_revenue | share_pct |
|---:|---:|---:|---:|
| 1 | 4 | 5618164.50 | 45.02 |
| 2 | 4 | 6861755.50 | 54.98 |
| 1 | 5 | 1345800.00 | 22.80 |
| 2 | 5 | 4556783.10 | 77.20 |

---

### Анализ динамики выручки с помощью LAG и LEAD

```sql
WITH daily AS (
    SELECT o.created_at::date AS day,
           SUM(oi.quantity * oi.unit_price) AS day_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    GROUP BY o.created_at::date
)
SELECT
    day,
    day_revenue,
    day_revenue - LAG(day_revenue) OVER (ORDER BY day) AS growth_vs_prev,
    LEAD(day_revenue) OVER (ORDER BY day) - day_revenue AS change_vs_next
FROM daily
ORDER BY day;
```

**Принцип работы и пояснение:**  
CTE `daily` подготавливает агрегированные данные дневного дохода. Функция смещения `LAG(day_revenue) OVER (ORDER BY day)` достаёт показатель предыдущего дня, а `LEAD(day_revenue) OVER (ORDER BY day)` — показатели следующего дня. Это позволяет производить вычисления динамики продаж без создания сложных self-join конструкций. Для самого первого дня значение `LAG` вернёт `NULL`, следовательно, и прирост будет `NULL`.

**Результат выполнения (теоретический):**

| day | day_revenue | growth_vs_prev | change_vs_next |
|---|---:|---:|---:|
| 2026-10-20 | 15000.00 | NULL | 7500.00 |
| 2026-10-21 | 22500.00 | 7500.00 | -4500.00 |
| 2026-10-22 | 18000.00 | -4500.00 | 13000.00 |
| 2026-10-23 | 31000.00 | 13000.00 | NULL |

---

### Сравнение подходов: Оконные функции vs Классический GROUP BY


```sql
WITH seller_cat AS (
    SELECT
        seller_id,
        category_id,
        SUM(price) AS item_revenue
    FROM products
    WHERE is_active = TRUE
    GROUP BY seller_id, category_id
),
cat_total AS (
    SELECT
        category_id,
        SUM(price) AS category_revenue
    FROM products
    WHERE is_active = TRUE
    GROUP BY category_id
)
SELECT
    s.seller_id,
    s.category_id,
    s.item_revenue,
    s.item_revenue * 100.0 / c.category_revenue share_pct
FROM seller_cat s
JOIN cat_total c ON s.category_id = c.category_id
ORDER BY s.category_id, share_pct DESC;
```

**Сравнительный анализ:**
1. **Сложность структуры и объём кода:** При классическом подходе потребовалось объявить два отдельных CTE (один для агрегации по продавцам и категориям, второй — только по категориям) и соединить их по ключу `category_id`. Вариант с оконной функцией (Задание 4) решает эту задачу в рамках единого плоского `SELECT`-запроса.
2. **Производительность:** Классический вариант вынужден делать два повторных сканирования и агрегации таблицы `products`, за которыми следует явная операция `JOIN`. Оконная функция выполняет агрегацию и расчёт тотала за один проход по предварительно сгруппированным данным, уменьшая затраты на ввод-вывод и ресурсы процессора.
3. **Читаемость:** Оконный вариант нагляднее отражает аналитический замысел: «получить локальный итог и разделить его на общий итог раздела».
