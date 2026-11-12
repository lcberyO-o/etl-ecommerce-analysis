-- ============================================================
-- 月度 GMV 与环比
-- 口径：GMV 只算 status = 'paid'；环比 = (本月 - 上月) / 上月 * 100。
-- 注意：首月没有上月，LAG 返回 NULL，环比留空。
-- ============================================================

WITH monthly AS (
  SELECT DATE_FORMAT(order_date, '%Y-%m') AS ym,
         SUM(total_amount)                AS gmv
  FROM v_orders_clean
  WHERE status = 'paid'
  GROUP BY ym
)
SELECT ym,
       ROUND(gmv, 2)                                              AS gmv,
       ROUND(LAG(gmv) OVER (ORDER BY ym), 2)                      AS prev_gmv,
       ROUND((gmv - LAG(gmv) OVER (ORDER BY ym))
             / LAG(gmv) OVER (ORDER BY ym) * 100, 2)              AS mom_pct
FROM monthly
ORDER BY ym;
