-- ============================================================
-- 渠道 × 品类交叉分析
-- 口径：GMV / 客单价只算支付订单；退款率 = 退款订单数 / 支付订单数；
--       支付订单数 < 50 的组合样本太小，剔除。
-- ============================================================

SELECT channel_name,
       main_category,
       COUNT(DISTINCT CASE WHEN status = 'paid' THEN order_id END) AS paid_orders,
       ROUND(SUM(CASE WHEN status = 'paid' THEN total_amount END), 2) AS gmv,
       ROUND(SUM(CASE WHEN status = 'paid' THEN total_amount END)
             / COUNT(DISTINCT CASE WHEN status = 'paid' THEN order_id END), 2) AS aov,
       ROUND(COUNT(DISTINCT CASE WHEN status = 'refunded' THEN order_id END)
             / COUNT(DISTINCT CASE WHEN status = 'paid' THEN order_id END), 4) AS refund_rate
FROM v_orders_clean
GROUP BY channel_name, main_category
HAVING COUNT(DISTINCT CASE WHEN status = 'paid' THEN order_id END) >= 50
ORDER BY channel_name, gmv DESC;
