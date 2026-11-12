-- ============================================================
-- 品类退款率
-- 口径：退款率 = 退款订单数 / 支付订单数（都按 order_id 去重）；
--       按主品类（订单金额最大的品类）分组；
--       支付订单数 < 100 的品类样本太小，不参与排名。
-- 输出：完整排名（第 1~3 行即退款率 Top3），便于画图。
-- ============================================================

SELECT main_category,
       COUNT(DISTINCT CASE WHEN status = 'paid'     THEN order_id END) AS paid_orders,
       COUNT(DISTINCT CASE WHEN status = 'refunded' THEN order_id END) AS refunded_orders,
       ROUND(COUNT(DISTINCT CASE WHEN status = 'refunded' THEN order_id END)
             / COUNT(DISTINCT CASE WHEN status = 'paid' THEN order_id END), 4) AS refund_rate
FROM v_orders_clean
GROUP BY main_category
HAVING COUNT(DISTINCT CASE WHEN status = 'paid' THEN order_id END) >= 100
ORDER BY refund_rate DESC;
