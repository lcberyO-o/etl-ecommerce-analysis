# results 目录说明

`sql/` 下每个脚本执行一次的输出，一个文件 = 一张表：**UTF-8（带 BOM）、Tab 分隔、第一行是表头**。

## 文件与列

| 文件 | 列 |
|---|---|
| `01_quality.tsv` | 问题类型、行数（15 类数据质量问题的汇总） |
| `02_clean_view.tsv` | 指标、数值（去重 / 清洗 / 状态分布 / GMV） |
| `03_channel.tsv` | channel_name、orders、buyers、gmv、aov |
| `04_repeat.tsv` | channel_name、buyers、repeat_buyers、repeat_rate |
| `05_monthly.tsv` | ym、gmv、prev_gmv、mom_pct（首月无上月，为空） |
| `06_refund.tsv` | main_category、paid_orders、refunded_orders、refund_rate |
| `07_top_products.tsv` | category、product_id、gmv、rk |
| `08_cohort_30d.tsv` | users_with_first_order、repeat_30d_users、repeat_rate_30d |
| `09_latest_order.tsv` | user_id、order_id、order_date、total_amount（前 20 行示例） |
| `10_consecutive_3m.tsv` | user_id、start_ym、months（前 20 行示例） |
| `11_channel_category.tsv` | channel_name、main_category、paid_orders、gmv、aov、refund_rate |

## 用 DBeaver 打开

- 直接 **File → Open File**（或把文件拖进编辑器）：DBeaver 会把 `.tsv` 识别成表格，分隔符 Tab、编码 UTF-8。
- 如果走 **导入向导（Import Data）**：分隔符选 **Tab**，编码选 **UTF-8**，勾选「第一行为列名」；否则所有内容会挤在一列里。

## 用 Excel 打开

双击即可。若中文乱码，用「数据 → 从文本/CSV」，文件原始格式选 **65001: Unicode (UTF-8)**。
