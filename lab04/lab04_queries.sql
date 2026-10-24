SELECT c.name,
       p.id,
       p.category_id,
       row_number() OVER W rn,
       rank() OVER W rnk,
       dense_rank() OVER W dense_rank
FROM products p JOIN categories c ON c.id = p.category_id
WINDOW W AS (PARTITION BY p.category_id ORDER BY p.price DESC)
