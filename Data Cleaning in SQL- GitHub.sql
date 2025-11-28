-- =====================================================
-- DATA CLEANING PROJECT: LAYOFFS DATASET
-- =====================================================
-- Data Source: https://www.kaggle.com/datasets/swaptr/layoffs-2022
-- Author: Irene Vanessa Vifah

--
-- CLEANING STEPS:
-- 1. Create staging table (preserve raw data)
-- 2. Remove duplicates
-- 3. Standardize data formats
-- 4. Handle null/blank values
-- 5. Remove unnecessary columns
-- =====================================================

USE world_layoffs;

-- =====================================================
-- STEP 1: CREATE STAGING TABLE
-- =====================================================
-- Always work on a copy to preserve original data

-- Create staging table with same structure as raw data
CREATE TABLE layoffs_staging
LIKE layoffs;

-- Copy all data into staging table
INSERT INTO layoffs_staging
SELECT *
FROM layoffs;

-- Verify data copied successfully
SELECT COUNT(*) AS total_rows
FROM layoffs_staging;

-- =====================================================
-- STEP 2: REMOVE DUPLICATES
-- =====================================================

-- Create staging2 table with row_num column for duplicate detection
CREATE TABLE layoffs_staging2 (
  `company` TEXT,
  `location` TEXT,
  `industry` TEXT,
  `total_laid_off` INT DEFAULT NULL,
  `percentage_laid_off` TEXT,
  `date` TEXT,
  `stage` TEXT,
  `country` TEXT,
  `funds_raised_millions` INT DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Insert data with row numbers to identify duplicates
-- Partition by all columns to find exact duplicates
INSERT INTO layoffs_staging2
SELECT *, 
    ROW_NUMBER() OVER(
        PARTITION BY company, location, industry, total_laid_off, 
                     percentage_laid_off, `date`, stage, country, 
                     funds_raised_millions
    ) AS row_num
FROM layoffs_staging;

-- Check for duplicates (row_num > 1 indicates duplicate)
SELECT *
FROM layoffs_staging2
WHERE row_num > 1;

-- Delete duplicate rows, keeping only the first occurrence
DELETE
FROM layoffs_staging2
WHERE row_num > 1;

-- Verify all duplicates removed
SELECT *
FROM layoffs_staging2
WHERE row_num > 1;

-- =====================================================
-- STEP 3: STANDARDIZE DATA
-- =====================================================

-- 3.1 Clean company names - remove leading/trailing spaces
SELECT company, TRIM(company)
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET company = TRIM(company);

-- 3.2 Standardize industry column
-- Check for inconsistencies
SELECT DISTINCT industry
FROM layoffs_staging2
ORDER BY industry;

-- Found: "Crypto", "Cryptocurrency", "CryptoCurrency" - standardize to "Crypto"
UPDATE layoffs_staging2
SET industry = "Crypto"
WHERE industry LIKE "Crypto%";

-- 3.3 Standardize country names
-- Remove trailing periods from country names
SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_staging2
ORDER BY country;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE "United States%";

-- 3.4 Fix date column format
-- Convert date from text to proper DATE format
SELECT `date`,
    STR_TO_DATE(`date`, "%m/%d/%Y") AS converted_date
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, "%m/%d/%Y");

-- Change column type from TEXT to DATE
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- Verify date conversion
SELECT `date`
FROM layoffs_staging2
ORDER BY `date` DESC
LIMIT 5;

-- =====================================================
-- STEP 4: HANDLE NULL AND BLANK VALUES
-- =====================================================

-- 4.1 Remove rows with no usable layoff data
-- Rows where both total_laid_off AND percentage_laid_off are NULL provide no value
SELECT * 
FROM layoffs_staging2
WHERE total_laid_off IS NULL 
    AND percentage_laid_off IS NULL;

DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
    AND percentage_laid_off IS NULL;

-- 4.2 Handle null values in industry column
-- Convert blank strings to NULL for easier querying
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = "";

-- Check companies with null industry values
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL
    OR industry = "";

-- Example: Check if Airbnb has industry data in other rows
SELECT *
FROM layoffs_staging2
WHERE company = "Airbnb";

-- Populate null industry values using self-join
-- If same company has industry in other rows, copy it
UPDATE layoffs_staging2 AS t1
JOIN layoffs_staging2 AS t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL 
    AND t2.industry IS NOT NULL;

-- 4.3 Handle remaining null industries manually
-- Bally's Interactive has only 1 entry, so self-join doesn't work
SELECT *
FROM layoffs_staging2
WHERE company LIKE "Bally%";

-- After research, categorize as "Other"
UPDATE layoffs_staging2
SET industry = "Other"
WHERE company LIKE "Bally%";

-- Verify no null industries remain
SELECT DISTINCT industry
FROM layoffs_staging2
ORDER BY industry;

-- =====================================================
-- STEP 5: REMOVE UNNECESSARY COLUMNS
-- =====================================================

-- Remove row_num column (was only needed for duplicate detection)
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

-- =====================================================
-- FINAL DATA QUALITY CHECK
-- =====================================================

-- Summary statistics
SELECT 
    COUNT(*) AS total_records,
    COUNT(DISTINCT company) AS unique_companies,
    COUNT(DISTINCT industry) AS unique_industries,
    COUNT(DISTINCT country) AS unique_countries,
    MIN(`date`) AS earliest_date,
    MAX(`date`) AS latest_date
FROM layoffs_staging2;

-- Check for any remaining nulls in key columns
SELECT 
    SUM(CASE WHEN company IS NULL THEN 1 ELSE 0 END) AS null_company,
    SUM(CASE WHEN industry IS NULL THEN 1 ELSE 0 END) AS null_industry,
    SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END) AS null_country,
    SUM(CASE WHEN `date` IS NULL THEN 1 ELSE 0 END) AS null_date
FROM layoffs_staging2;

-- View sample of cleaned data
SELECT *
FROM layoffs_staging2
ORDER BY total_laid_off DESC
LIMIT 10;

-- =====================================================
-- CLEANING COMPLETE - DATA READY FOR ANALYSIS
-- =====================================================