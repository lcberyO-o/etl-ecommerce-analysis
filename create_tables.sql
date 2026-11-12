-- ============================================================
-- 模拟电商订单项目：建库建表（安全版）
-- MySQL 8.0+
-- 用法：在 DBeaver / Navicat 里整段执行，然后再导入 CSV。
--
-- 【安全性说明】
-- 本脚本用 CREATE TABLE IF NOT EXISTS，重复执行不会删除已有数据。
-- 表已存在时会静默跳过，不会覆盖、不会清空。
--
-- 【确实要从零重建时】
-- 下面"重建模式"块里的 5 行 DROP 默认是注释掉的。确需重建再取消注释，
-- 但那会清空 5 张表的所有数据 —— 执行前务必先备份：
--   mysqldump -u root -proot --default-character-set=utf8mb4 xiaomi_practice > backup_xiaomi_practice.sql
--
-- 注意：orders.order_id 不设唯一键，因为原始数据里有重复订单，
--       去重放在 ETL 阶段做（见 sql/02_clean_view.sql）。
-- ============================================================

CREATE DATABASE IF NOT EXISTS xiaomi_practice
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE xiaomi_practice;

-- ------------------------------------------------------------
-- 重建模式（危险，默认关闭）
-- 取消下面 5 行的注释 = 清空 5 张表全部数据，请先备份
-- ------------------------------------------------------------
-- DROP TABLE IF EXISTS order_items;
-- DROP TABLE IF EXISTS orders;
-- DROP TABLE IF EXISTS products;
-- DROP TABLE IF EXISTS users;
-- DROP TABLE IF EXISTS channels;

CREATE TABLE IF NOT EXISTS channels (
  channel_id   INT PRIMARY KEY,
  channel_name VARCHAR(32) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS users (
  user_id       INT PRIMARY KEY,
  register_date DATE,
  city          VARCHAR(32),
  age           INT,
  gender        VARCHAR(8),
  channel_id    INT,
  KEY idx_users_channel (channel_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS products (
  product_id INT PRIMARY KEY,
  category   VARCHAR(32),
  price      DECIMAL(12, 2),
  cost       DECIMAL(12, 2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS orders (
  id           BIGINT AUTO_INCREMENT PRIMARY KEY,
  order_id     INT NOT NULL,
  user_id      INT,
  order_date   DATE,
  channel_id   INT,
  total_amount DECIMAL(12, 2),
  status       VARCHAR(16),
  KEY idx_orders_order (order_id),
  KEY idx_orders_user (user_id),
  KEY idx_orders_date (order_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS order_items (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  order_id    INT NOT NULL,
  product_id  INT,
  quantity    INT,
  unit_price  DECIMAL(12, 2),
  line_amount DECIMAL(12, 2),
  KEY idx_items_order (order_id),
  KEY idx_items_product (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
