## Файлы

| Файл | Назначение |
|---|---|
| [lab05_01_transactions.sql](lab05_01_transactions.sql) | Демонстрация работы транзакций: успешная фиксация (COMMIT) и откат при ошибке (ROLLBACK) |
| [lab05_02_place_order.sql](lab05_02_place_order.sql) | Хранимая функция `place_order` на PL/pgSQL для атомарного оформления заказа |
| [lab05_03_seller_revenue.sql](lab05_03_seller_revenue.sql) | Хранимая функция `get_seller_revenue` для расчёта сводной выручки продавца |
| [lab05_04_price_audit.sql](lab05_04_price_audit.sql) | Таблица `product_price_audit` и AFTER UPDATE триггер логирования истории цен |
| [lab05_05_rating_trigger.sql](lab05_05_rating_trigger.sql) | Денормализованное поле `rating` и AFTER триггер автоматического пересчёта рейтинга |
| [lab1.sql](../lab01/lab1.sql) | Базовая структура таблиц маркетплейса |
| [lab02_seed.sql](../lab02/lab02_seed.sql) | Первичный набор тестовых данных маркетплейса |

---

## 1. Порядок запуска

1. Подключиться к PostgreSQL-базе `marketplace` через SQL-клиент (PyCharm / DBeaver / pgAdmin).
2. Убедиться, что структуры таблиц и данные из первых лабораторных работ развёрнуты.
3. Последовательно выполнять скрипты:
   - `lab05_01_transactions.sql`: пошаговый запуск сценариев фиксации и отката.
   - `lab05_02_place_order.sql`: компиляция функции `place_order` и вызовы тестовых сценариев.
   - `lab05_03_seller_revenue.sql`: компиляция функции `get_seller_revenue` и запуск расчётов.
   - `lab05_04_price_audit.sql`: создание таблицы аудита, триггерной функции и триггера, выполнение тестов избирательности.
   - `lab05_05_rating_trigger.sql`: добавление поля `rating`, создание триггера и проверка пересчёта на товаре №2.

---

## 2. Демонстрация работы транзакций (ACID)


### 2.1. Успешный сценарий (COMMIT)

```sql
SELECT product_id, quantity FROM stock WHERE product_id = 495;

BEGIN;

INSERT INTO orders (user_id, status, total_amount)
VALUES (10, 'new', 49904.34)
RETURNING id;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (1018, 495, 1, 49904.34);

UPDATE stock
SET quantity = quantity - 1
WHERE product_id = 495;

COMMIT;

SELECT * FROM orders WHERE id = 1018;
SELECT * FROM order_items WHERE order_id = 1018;
SELECT * FROM stock WHERE product_id = 495;
```

**Принцип работы и пояснение:**  
Команда `BEGIN` переводит сессию в режим явного управления транзакцией. `INSERT INTO orders` создаёт заказ и с помощью `RETURNING id` возвращает сгенерированный идентификатор (`1018`). Второй шаг добавляет позицию в `order_items`, связывая её с созданным заказом. Третий шаг уменьшает остаток товара на складе. Инструкция `COMMIT` атомарно фиксирует все три взаимосвязанных изменения.

**Результат выполнения:**
- В таблице `orders` появилась запись о заказе `id = 1018` с суммой `49904.34`.
- В таблице `order_items` добавлена позиция с товаром 495.
- В таблице `stock` остаток товара 495 уменьшился с 20 до 19 единиц.

| product_id | quantity |
|---:|---:|
| 495 | 19 |

---

### 2.2. Сценарий с намеренной ошибкой (ROLLBACK)

```sql
SELECT product_id, quantity FROM stock WHERE product_id = 495;

BEGIN;

INSERT INTO orders (user_id, status, total_amount)
VALUES (11, 'new', 999999.00)
RETURNING id;

UPDATE stock
SET quantity = quantity - 999999
WHERE product_id = 495;

ROLLBACK;

SELECT * FROM orders WHERE user_id = 11 AND total_amount = 999999.00;
SELECT * FROM stock WHERE product_id = 495;
```

**Принцип работы и пояснение:**  
Внутри транзакции формируется предварительный заказ, после чего инициируется попытка списать со склада заведомо недопустимый объём товара (`- 999999`). На уровне схемы срабатывает ограничение `CHECK (quantity >= 0)`, и PostgreSQL переводит транзакцию в состояние ошибки (`ERROR: check_violation`). Инструкция `ROLLBACK` выполняет полный откат всех изменений, произведённых с момента `BEGIN`.

**Результат выполнения:**
- Заказ для пользователя 11 не был сохранён в таблице `orders` (запрос возвращает 0 строк).
- Остаток товара 495 на складе не изменился и остался равен 19 единицам.

| product_id | quantity |
|---:|---:|
| 495 | 19 |

---

## 3. Функция атомарного оформления заказа (place_order)

```sql
CREATE OR REPLACE FUNCTION place_order(
    p_user_id BIGINT,
    p_product_id BIGINT,
    p_quantity INT
)
RETURNS BIGINT AS $$
DECLARE
    v_order_id BIGINT;
    v_unit_price NUMERIC(12,2);
    v_current_stock INT;
    v_total NUMERIC(12,2);
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Количество товара должно быть больше нуля (передано: %)', p_quantity;
    END IF;

    SELECT price INTO v_unit_price
    FROM products
    WHERE id = p_product_id;

    IF v_unit_price IS NULL THEN
        RAISE EXCEPTION 'Товар с id=% не найден', p_product_id;
    END IF;

    SELECT quantity INTO v_current_stock
    FROM stock
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF v_current_stock IS NULL OR v_current_stock < p_quantity THEN
        RAISE EXCEPTION 'Недостаточно товара на складе (id=%). Доступно: %, запрошено: %',
            p_product_id, COALESCE(v_current_stock, 0), p_quantity;
    END IF;

    v_total := v_unit_price * p_quantity;

    INSERT INTO orders (user_id, status, total_amount)
    VALUES (p_user_id, 'new', v_total)
    RETURNING id INTO v_order_id;

    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product_id, p_quantity, v_unit_price);

    UPDATE stock
    SET quantity = quantity - p_quantity,
        updated_at = now()
    WHERE product_id = p_product_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;
```

**Принцип работы и пояснение:**  
1. Проверяется корректность запрашиваемого количества (`p_quantity > 0`).
2. Извлекается цена товара. Если товар отсутствует, возбуждается исключение.
3. Блок `SELECT ... FOR UPDATE` накладывает эксклюзивную блокировку на строку складского остатка в таблице `stock`. Это предотвращает состояние гонки (race condition) при одновременных заказах одного и того же товара.
4. При недостатке остатка вызывается `RAISE EXCEPTION`, что автоматически приводит к откату всех незафиксированных действий функции.
5. При наличии остатка формируется заказ, создаётся строка позиции в `order_items`, списывается складской остаток, и функция возвращает сгенерированный `id` заказа.

**Результаты проверок:**
- Успешный вызов `SELECT place_order(10, 495, 2);` возвращает новый ID заказа (например, `1019`), остаток на складе уменьшается с 19 до 17.
- Негативный вызов `SELECT place_order(10, 495, 999999);` завершается ошибкой `RAISE EXCEPTION`, остаток на складе остаётся равным 17.

---

## 4. Функция расчёта выручки продавца (get_seller_revenue)


```sql
CREATE OR REPLACE FUNCTION get_seller_revenue(
    p_seller_id BIGINT,
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS NUMERIC(12,2) AS $$
DECLARE
    v_seller_exists BOOLEAN;
    v_total_revenue NUMERIC(12,2) := 0;
BEGIN
    SELECT EXISTS (SELECT 1 FROM sellers WHERE id = p_seller_id)
    INTO v_seller_exists;

    IF NOT v_seller_exists THEN
        RAISE EXCEPTION 'Продавец с id=% не найден', p_seller_id;
    END IF;

    SELECT COALESCE(SUM(oi.quantity * oi.unit_price), 0.00)
    INTO v_total_revenue
    FROM order_items oi
    JOIN products p ON p.id = oi.product_id
    JOIN orders o ON o.id = oi.order_id
    WHERE p.seller_id = p_seller_id
      AND o.status <> 'cancelled'
      AND (p_start_date IS NULL OR o.created_at >= p_start_date)
      AND (p_end_date IS NULL OR o.created_at <= p_end_date);

    RETURN v_total_revenue;
END;
$$ LANGUAGE plpgsql;
```

**Принцип работы и пояснение:**  
1. Валидация: через предикат `EXISTS` проверяется наличие магазина продавца в таблице `sellers`. При отсутствии продавца генерируется исключение.
2. Соединение `order_items` с `products` и `orders` позволяет вычислить суммарный доход именно по товарам конкретного магазина, исключая отменённые заказы (`status <> 'cancelled'`).
3. Параметры даты `p_start_date` и `p_end_date` имеют значения по умолчанию `NULL`. Если они не переданы, условие фильтрации опускается, и считается выручка за всё время.
4. Обертка `COALESCE(..., 0.00)` гарантирует возврат числового нуля вместо `NULL`, если у продавца пока нет продаж.

---

## 5. Триггер аудита изменения цены товара

```sql
CREATE TABLE IF NOT EXISTS product_price_audit (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    old_price NUMERIC(12,2) NOT NULL,
    new_price NUMERIC(12,2) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION audit_product_price_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.price <> NEW.price THEN
        INSERT INTO product_price_audit (product_id, old_price, new_price, changed_at)
        VALUES (OLD.id, OLD.price, NEW.price, now());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_audit_product_price
AFTER UPDATE OF price ON products
FOR EACH ROW
EXECUTE FUNCTION audit_product_price_change();
```

**Принцип работы и пояснение:**  
- Для хранения истории создана отдельная таблица `product_price_audit`.
- Триггер настроен как `AFTER UPDATE OF price ON products FOR EACH ROW`. Это означает, что он активируется только при изменении столбца `price`.
- Внутри функции проверяется условие `OLD.price <> NEW.price`. Если цена фактически не изменилась, запись в журнал не дублируется.
- При реальной смене цены триггер автоматически извлекает старое значение из псевдозаписи `OLD` и новое значение из `NEW`, фиксируя дату через `now()`.

**Результат проверки избирательности:**

```sql
-- Изменение цены товара 1
UPDATE products SET price = price + 500 WHERE id = 1;

-- Изменение не связанного с ценой поля
UPDATE products SET description = 'Обновлённое описание' WHERE id = 1;

-- Проверка журнала аудита
SELECT product_id, old_price, new_price, changed_at FROM product_price_audit WHERE product_id = 1;
```

| product_id | old_price | new_price | changed_at |
|---:|---:|---:|---|
| 1 | 17698.34 | 18198.34 | 2026-10-31 01:00:15+03 |

*Журнал зафиксировал ровно одну запись при смене цены. Обновление описания не привело к добавлению лишних строк в аудит.*

---

## 6. Триггер поддержки денормализованного рейтинга

```sql
ALTER TABLE products ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2) DEFAULT NULL;

UPDATE products p
SET rating = sub.avg_score
FROM (
    SELECT product_id, ROUND(AVG(score)::numeric, 2) AS avg_score
    FROM reviews
    GROUP BY product_id
) sub
WHERE p.id = sub.product_id;

CREATE OR REPLACE FUNCTION refresh_product_rating()
RETURNS TRIGGER AS $$
DECLARE
    v_product_id BIGINT;
BEGIN
    v_product_id := COALESCE(NEW.product_id, OLD.product_id);

    UPDATE products
    SET rating = (
        SELECT ROUND(AVG(score)::numeric, 2)
        FROM reviews
        WHERE product_id = v_product_id
    )
    WHERE id = v_product_id;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_refresh_product_rating
AFTER INSERT OR UPDATE OF score OR DELETE ON reviews
FOR EACH ROW
EXECUTE FUNCTION refresh_product_rating();
```

**Принцип работы и пояснение:**  
- Денормализация (хранение вычисляемого среднего рейтинга прямо в `products`) устраняет необходимость ресурсоёмкого расчёта `AVG(score)` при каждом показе каталога товаров покупателям.
- Триггер `trg_refresh_product_rating` привязан к событиям `INSERT`, `UPDATE OF score` и `DELETE` таблицы `reviews`.
- Использование `COALESCE(NEW.product_id, OLD.product_id)` обеспечивает корректную работу при любых операциях: при добавлении отзыва ID товара берётся из `NEW`, при удалении — из `OLD`.
- Функция вычисляет среднее арифметическое оценок для затронутого товара и обновляет столбец `products.rating`.

**Результат проверки динамического пересчёта (товар №2):**

```sql
-- 1. До добавления отзывов
SELECT id, title, rating FROM products WHERE id = 2; -- rating = NULL

-- 2. Пользователь 1 ставит оценку 5
INSERT INTO reviews (user_id, product_id, score, comment) VALUES (1, 2, 5, 'Отличный ноутбук!');

-- 3. Пользователь 2 ставит оценку 3
INSERT INTO reviews (user_id, product_id, score, comment) VALUES (2, 2, 3, 'Обычный ноутбук');

-- 4. Пользователь 2 исправляет оценку на 5
UPDATE reviews SET score = 5 WHERE user_id = 2 AND product_id = 2;
```

| Этап | Действие | Рейтинг товара 2 (`rating`) |
|---|---|---:|
| 1. Исходное состояние | Нет отзывов | `NULL` |
| 2. Добавление отзыва | Оценка 5 | `5.00` |
| 3. Второй отзыв | Оценка 3 | `4.00` |
| 4. Корректировка оценки | Оценка обновлена на 5 | `5.00` |

---

## 7. Размещение логики: СУБД vs Приложение


| Критерий | Серверная логика в СУБД (PL/pgSQL, триггеры) | Логика в приложении (Backend: Python, Go, Java) |
|---|---|---|
| **Гарантия целостности данных** | **Абсолютная.** Правило выполняется независимо от того, какое приложение или скрипт обращается к БД (бэкенд, консоль psql, аналитики). | **Ограниченная.** Если к одной БД подключено несколько сервисов, правило нужно дублировать в каждом из них. |
| **Сетевые накладные расходы** | **Минимальные (Data Locality).** Вычисления производятся на самом сервере БД без пересылки сотен строк по сети туда и обратно. | **Высокие.** Требуется отправка запросов и перегон наборов данных по сети. |
| **Масштабируемость** | **Сложная (вертикальная).** Сервер базы данных сложнее и дороже масштабировать, его процессор быстро становится узким местом. | **Простая (горизонтальная).** Stateless-сервисы приложений легко масштабируются добавлением новых контейнеров/нод. |
| **Тестирование и CI/CD** | **Сложное.** Юнит-тестирование процедурного SQL требует разворачивания БД; миграции и отладка PL/pgSQL менее удобны. | **Отличное.** Богатые экосистемы фреймворков для юнит- и интеграционного тестирования, линтеры, моки, развитые IDE. |
| **Переносимость кода** | **Низкая (Vendor Lock-in).** PL/pgSQL специфичен для PostgreSQL и не переносим на MySQL или Oracle без полной переработки. | **Высокая.** Код на Python/Java/Go не зависит от конкретного диалекта SQL при использовании ORM или абстракций. |
