-- Новая таблица без индексов
CREATE TABLE IF NOT EXISTS test_no_index (
    id    BIGINT,
    val   NUMERIC,
    label TEXT
);

\timing on

INSERT INTO test_no_index
SELECT
    g,
    round((random() * 1000)::numeric, 2),
    'item_' || g
FROM generate_series(1, 100000) g;

\timing off

-- Новая таблица с индексами
CREATE TABLE IF NOT EXISTS test_with_index (
    id    BIGINT,
    val   NUMERIC,
    label TEXT
);

CREATE INDEX IF NOT EXISTS idx_twi_val   ON test_with_index (val);
CREATE INDEX IF NOT EXISTS idx_twi_label ON test_with_index (label);

\timing on

INSERT INTO test_with_index
SELECT
    g,
    round((random() * 1000)::numeric, 2),
    'item_' || g
FROM generate_series(1, 100000) g;

\timing off

-- Очистка
DROP TABLE IF EXISTS test_no_index;
DROP TABLE IF EXISTS test_with_index;
