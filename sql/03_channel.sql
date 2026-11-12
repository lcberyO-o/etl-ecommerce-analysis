SELECT channel_name,
       COUNT(DISTINCT order_id) AS orders,
       COUNT(DISTINCT user_id) AS buyers,
       ROUND(SUM(total_amount), 2) AS gmv,
       ROUND(SUM(total_amount) / COUNT(DISTINCT order_id), 2) AS aov
FROM v_orders_clean
WHERE status = 'paid'
GROUP BY channel_name
ORDER BY gmv DESC;