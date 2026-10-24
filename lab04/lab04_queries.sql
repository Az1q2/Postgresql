SELECT c.name,
       p.id,
       p.category_id,
       row_number() OVER W rn,
       rank() OVER W rnk,
       dense_rank() OVER W dense_rank
FROM products p JOIN categories c ON c.id = p.category_id
WINDOW W AS (PARTITION BY p.category_id ORDER BY p.price DESC);

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

