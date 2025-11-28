# Layoffs Data Cleaning in SQL Project

## Project Overview
This is a comprehensive SQL data cleaning project that transforms raw, messy layoff data into a clean, analysis-ready dataset. This project demonstrates systematic data cleaning techniques including removing duplicates, data standardization, null value handling, and quality validation.

## Dataset Information
- **Source**: [Kaggle - Layoffs 2022](https://www.kaggle.com/datasets/swaptr/layoffs-2022)
- **Topic**: Company layoffs across multiple industries (2020-2023)
- **Original Records**: ~2,361 entries
- **Final Clean Records**: 1,994 entries

### Key Columns
- `company` - Company name
- `location` - Office location
- `industry` - Industry sector
- `total_laid_off` - Number of employees laid off
- `percentage_laid_off` - Percentage of workforce affected
- `date` - Date of layoff event
- `stage` - Company funding stage
- `country` - Country location
- `funds_raised_millions` - Total funding raised

## Cleaning Methodology

### 1. Create Staging Table
**Goal**: Preserve original data integrity

Created a staging table (`layoffs_staging2`) as a working copy of the raw data. This ensures the original dataset remains untouched and can be referenced or restored if needed during the cleaning process.

```sql
CREATE TABLE layoffs_staging LIKE layoffs;
INSERT INTO layoffs_staging SELECT * FROM layoffs;
```

**Why this matters**: Industry best practice for data cleaning - never work directly on raw data.

---

### 2. Remove Duplicates
**Goal**: Eliminate redundant records

**Method**:
- Used `ROW_NUMBER()` window function partitioned by all columns to identify exact duplicates
- Created `layoffs_staging2` table with additional `row_num` column
- Deleted all rows where `row_num > 1`

```sql
INSERT INTO layoffs_staging2
SELECT *, 
    ROW_NUMBER() OVER(
        PARTITION BY company, location, industry, total_laid_off, 
                     percentage_laid_off, date, stage, country, 
                     funds_raised_millions
    ) AS row_num
FROM layoffs_staging;

DELETE FROM layoffs_staging2
WHERE row_num > 1;
```

**Result**: Successfully removed all duplicate entries while preserving unique records.

---

### 3. Standardize Data
**Goal**: Ensure consistency across all fields

#### Company Names
- **Issue**: Leading and trailing spaces in company names
- **Solution**: Applied `TRIM()` function to remove whitespace
- **Impact**: Ensures accurate company matching and grouping

#### Industry Classification
- **Issue**: Found 3 variations of cryptocurrency industry:
  - "Crypto"
  - "Cryptocurrency"
  - "Crypto Currency"
- **Solution**: Standardized all variations to "Crypto"
- **Impact**: Consistent industry categorization for analysis

```sql
UPDATE layoffs_staging2
SET industry = "Crypto"
WHERE industry LIKE "Crypto%";
```

#### Country Names
- **Issue**: "United States" appeared with and without trailing period ("United States.")
- **Solution**: Removed trailing periods using `TRIM(TRAILING '.')`
- **Impact**: Prevents duplicate country entries in analysis

#### Date Format
- **Issue**: Date stored as TEXT in format "mm/dd/yyyy"
- **Solution**: 
  1. Converted strings to DATE format using `STR_TO_DATE()`
  2. Modified column datatype from TEXT to DATE
- **Impact**: Enables proper date-based sorting, filtering, and time-series analysis

```sql
UPDATE layoffs_staging2
SET date = STR_TO_DATE(date, "%m/%d/%Y");

ALTER TABLE layoffs_staging2
MODIFY COLUMN date DATE;
```

---

### 4. Handle Null and Blank Values
**Goal**: Remove unusable data and populate missing values where possible

#### Unusable Records
- **Issue**: 127 rows had NULL values in BOTH `total_laid_off` AND `percentage_laid_off`
- **Decision**: Deleted these rows as they provide no analytical value
- **Rationale**: Records with no layoff data cannot contribute to analysis

```sql
DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL 
    AND percentage_laid_off IS NULL;
```

#### Missing Industry Data - Automated Solution
- **Issue**: Some companies had blank/NULL industry values
- **Solution**: Used self-join to populate missing industries based on the same company's other entries
- **Example**: If "Airbnb" had NULL industry in one row but "Travel" in another, the NULL was populated with "Travel"

```sql
UPDATE layoffs_staging2 AS t1
JOIN layoffs_staging2 AS t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL 
    AND t2.industry IS NOT NULL;
```

**Impact**: Automatically fixed most null industry values without manual research.

#### Missing Industry Data - Manual Research
- **Challenge**: Bally's Interactive had only one entry, making self-join ineffective
- **Solution**: Conducted external research on the company
  - **Finding**: Bally's Interactive is an iGaming/online betting platform
  - **Decision**: Categorized as "Other" (no specific gambling industry category existed)
  - **Alternative Considered**: Creating a new "Gaming" industry category, but a single entry didn't justify it

```sql
UPDATE layoffs_staging2
SET industry = "Other"
WHERE company LIKE "Bally%";
```

**Why this approach**: Demonstrates real-world data cleaning where automation has limits and domain research is necessary.

---

### 5. Remove Unnecessary Columns
**Goal**: Clean up helper columns

Removed the `row_num` column as it was only needed for duplicate detection and serves no purpose in the final dataset.

```sql
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;
```

---

## Data Quality Validation

Final checks performed to ensure data integrity:

```sql
-- Summary statistics
SELECT 
    COUNT(*) AS total_records,
    COUNT(DISTINCT company) AS unique_companies,
    COUNT(DISTINCT industry) AS unique_industries,
    COUNT(DISTINCT country) AS unique_countries,
    MIN(date) AS earliest_date,
    MAX(date) AS latest_date
FROM layoffs_staging2;
```

### Final Dataset Quality
- No duplicate records
- Consistent data formats across all columns
- Proper data types (DATE for dates, INT for numbers)
- No NULL values in critical columns (company, country, date)
- Standardized industry and country classifications
- All records contain usable layoff data

### Final Dataset Statistics
- **Total Records**: 1,994
- **Unique Companies**: 1,628 (some companies had multiple layoff events)
- **Industries**: 30
- **Countries**: 51
- **Date Range**: March 11, 2020 - March 6, 2023 (3-year span covering COVID-19 era and post-pandemic tech adjustments)

---

## Key Skills Demonstrated

### SQL Techniques
- Window functions (`ROW_NUMBER()`, `PARTITION BY`)
- Common Table Expressions (CTEs)
- Self-joins for data imputation
- String manipulation (`TRIM()`, `LIKE`)
- Date formatting and type conversion
- Table structure modification (`ALTER TABLE`)
- Data validation queries

### Data Cleaning Principles
- Creating staging environments to preserve raw data
- Systematic approach to data quality issues
- Automation where possible, manual research when necessary
- Comprehensive documentation of decisions
- Quality validation at each step

### Problem-Solving
- Identifying data quality issues through exploratory queries
- Developing automated solutions (self-join for missing values)
- Adapting when automation fails (manual research for edge cases)
- Balancing data completeness vs. data quality

---

## Project Structure
```
layoffs-data-cleaning/
├── README.md                    # Project documentation
├── data_cleaning.sql            # Complete cleaning script
└── screenshots/                 # Visual documentation
    ├── clean_data_sample.png
    └── summary_statistics.png
```

---

## Results & Impact

### Cleaning Impact
- **Starting records**: ~2,361
- **Final records**: 1,994 (100% usable)
- **Data quality improvement**: Eliminated inconsistencies across all fields

### Dataset Now Ready For
- Trend analysis (layoffs over time)
- Industry comparison analysis
- Geographic analysis (by country/location)
- Company stage analysis (startup vs. established)
- Correlation analysis (funding vs. layoffs)

---

## Next Steps

Potential analysis directions with this cleaned dataset:
1. **Temporal Analysis**: Identify peak layoff periods and seasonal trends
2. **Industry Impact**: Which industries were hit hardest?
3. **Geographic Patterns**: Regional differences in layoff rates
4. **Company Characteristics**: Relationship between funding stage and layoff likelihood
5. **Predictive Modeling**: Can company characteristics predict layoff risk?

---

## Tools Used
- **Database**: MySQL
- **Techniques**: Window functions, Self-joins, String manipulation, Type conversion
- **Development**: MySQL Workbench

---

## Lessons Learned
1. **Always stage your data**: Working on a copy prevents irreversible mistakes
2. **Automation has limits**: Some data quality issues require human judgment and research
3. **Documentation matters**: Comments and version control make your work reproducible
4. **Quality over completeness**: Sometimes deleting unusable records is the right choice
5. **Systematic approach wins**: Following a structured methodology catches more issues than ad-hoc cleaning

---

## Author
**Irene Vanessa Vifah**

Connect with me: [LinkedIn](www.linkedin.com/in/irenevanessavifah) | [GitHub](https://github.com/irene-vanessa)

---

## License
This project is open source and available under the MIT License.

---

## Acknowledgments
- Dataset provided by [Kaggle](https://www.kaggle.com/datasets/swaptr/layoffs-2022)
- Inspired by real-world data engineering practices
