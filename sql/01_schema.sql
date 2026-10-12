-- 01_schema.sql  |  MySQL 8.0+
-- Star schema: 3 dimensions + 1 fact, plus a staging table for raw data.

DROP DATABASE IF EXISTS pharma_sales;
CREATE DATABASE pharma_sales CHARACTER SET utf8mb4;
USE pharma_sales;

-- ---------- Dimensions ----------
CREATE TABLE dim_region (
    region_id   INT PRIMARY KEY,
    region_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE dim_drug (
    drug_id    INT PRIMARY KEY,
    drug_name  VARCHAR(100) NOT NULL UNIQUE,
    category   VARCHAR(50)  NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL
);

CREATE TABLE dim_rep (
    rep_id    INT PRIMARY KEY,
    rep_name  VARCHAR(100) NOT NULL UNIQUE,
    region_id INT NOT NULL,
    FOREIGN KEY (region_id) REFERENCES dim_region(region_id)
);

-- ---------- Staging (raw, everything text so nothing fails on load) ----------
CREATE TABLE stg_sales_raw (
    txn_id       VARCHAR(20),
    sale_date    VARCHAR(20),
    region       VARCHAR(50),
    drug_name    VARCHAR(100),
    rep_name     VARCHAR(100),
    units_sold   VARCHAR(20),
    unit_price   VARCHAR(20),
    discount_pct VARCHAR(20)
);

-- ---------- Fact ----------
CREATE TABLE fact_sales (
    sale_id       BIGINT AUTO_INCREMENT PRIMARY KEY,
    txn_id        VARCHAR(20)  NOT NULL UNIQUE,
    sale_date     DATE         NOT NULL,
    region_id     INT          NOT NULL,
    drug_id       INT          NOT NULL,
    rep_id        INT          NOT NULL,
    units_sold    INT          NOT NULL CHECK (units_sold > 0),
    unit_price    DECIMAL(10,2) NOT NULL,
    discount_pct  DECIMAL(5,2) NOT NULL DEFAULT 0,
    gross_revenue DECIMAL(14,2) GENERATED ALWAYS AS (units_sold * unit_price) STORED,
    net_revenue   DECIMAL(14,2) GENERATED ALWAYS AS (units_sold * unit_price * (1 - discount_pct/100)) STORED,
    FOREIGN KEY (region_id) REFERENCES dim_region(region_id),
    FOREIGN KEY (drug_id)   REFERENCES dim_drug(drug_id),
    FOREIGN KEY (rep_id)    REFERENCES dim_rep(rep_id),
    INDEX idx_date   (sale_date),
    INDEX idx_region (region_id),
    INDEX idx_drug   (drug_id),
    INDEX idx_rep    (rep_id)
);
