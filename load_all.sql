-- 一键清空并重新导入 5 张表（MySQL 8.0+）
-- 用法：双击同目录的“一键导入.bat”，输入 root 密码。

USE xiaomi_practice;
SET GLOBAL local_infile = 1;
SET SESSION local_infile = 1;

TRUNCATE TABLE channels;
LOAD DATA LOCAL INFILE 'C:/Users/33079/AppData/Local/Temp/xiaomi_csv/channels.csv'
INTO TABLE channels
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(channel_id, channel_name);

TRUNCATE TABLE users;
LOAD DATA LOCAL INFILE 'C:/Users/33079/AppData/Local/Temp/xiaomi_csv/users.csv'
INTO TABLE users
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(user_id, register_date, city, age, gender, channel_id);

TRUNCATE TABLE products;
LOAD DATA LOCAL INFILE 'C:/Users/33079/AppData/Local/Temp/xiaomi_csv/products.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, category, price, cost);

TRUNCATE TABLE orders;
LOAD DATA LOCAL INFILE 'C:/Users/33079/AppData/Local/Temp/xiaomi_csv/orders.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, user_id, order_date, channel_id, total_amount, status);

TRUNCATE TABLE order_items;
LOAD DATA LOCAL INFILE 'C:/Users/33079/AppData/Local/Temp/xiaomi_csv/order_items.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, product_id, quantity, unit_price, line_amount);
