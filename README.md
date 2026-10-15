# CFPB Consumer Financial Complaints Analytics Pipeline

A modern data engineering project that ingests, transforms, and analyzes consumer complaint data from the [Consumer Financial Protection Bureau (CFPB)](https://www.consumerfinance.gov/data-research/consumer-complaints/) using the **Snowflake + dbt** stack.

The pipeline focuses on major financial institutions — Capital One, Navy Federal Credit Union, JPMorgan Chase, Bank of America, and others — producing analytics-ready datasets that surface patterns in complaint volume, response quality, and consumer dispute rates.

## Architecture

```
CFPB REST API
     │
     ▼
┌──────────────────┐
│  Python Ingester  │   Extract + Load (EL)
│  (requests →      │   Paginated API calls per company
│   write_pandas)   │   Bulk load via PUT + COPY INTO
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Snowflake        │
│  RAW schema       │   Landing zone — append-only
└────────┬─────────┘
         │  dbt
         ▼
┌──────────────────┐
│  STAGING          │   Clean, cast, standardize
│  (views)          │   Boolean normalization, response-time calc
└────────┬─────────┘
         │  dbt
         ▼
┌──────────────────┐
│  INTERMEDIATE     │   Business logic aggregations
│  (tables)         │   Company metrics, product trends, response analysis
└────────┬─────────┘
         │  dbt
         ▼
┌──────────────────┐
│  MARTS            │   Analytics-ready tables
│  (tables)         │   Fact/dimension tables, company scorecard report
└──────────────────┘
```

## Tech Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Extract & Load | Python + `snowflake-connector-python` | Paginated API ingestion with `write_pandas` bulk loading |
| Storage | Snowflake | Cloud data warehouse with multi-schema architecture |
| Transform | dbt | SQL-based transformations with testing and documentation |
| Orchestration | CLI (argparse) | Full and incremental load modes |
| Version Control | Git + GitHub | Source control with `.gitignore` for secrets |

## Project Structure

```
cfpb-financial-complaints-pipeline/
├── config/
│   └── .env.example              # Snowflake credentials template
├── scripts/
│   ├── snowflake_setup.sql       # DDL for warehouse, database, schemas, tables
│   └── ingest_cfpb_complaints.py # Python EL pipeline
├── dbt_project/
│   ├── dbt_project.yml           # dbt configuration
│   ├── profiles.yml.example      # dbt connection profile template
│   ├── models/
│   │   ├── staging/
│   │   │   ├── src_cfpb.yml          # Source definitions + tests
│   │   │   ├── stg_complaints.sql    # Cleaning & standardization
│   │   │   └── stg_complaints.yml    # Column-level tests
│   │   ├── intermediate/
│   │   │   ├── int_company_complaint_metrics.sql
│   │   │   ├── int_product_complaint_trends.sql
│   │   │   ├── int_response_time_analysis.sql
│   │   │   └── intermediate.yml
│   │   └── marts/
│   │       ├── fct_complaints.sql        # Fact table
│   │       ├── dim_companies.sql         # Company dimension
│   │       ├── dim_products.sql          # Product dimension
│   │       ├── rpt_company_scorecard.sql # Interview-ready scorecard
│   │       └── marts.yml
│   └── macros/
│       └── rate_calculation.sql  # Reusable safe_rate macro
├── requirements.txt
├── .gitignore
└── README.md
```

## Key Features

### Data Ingestion
- **Paginated API extraction** with configurable date ranges and company filters
- **Incremental loading** — only fetch new complaints since the last run
- **Bulk loading** via Snowflake's `write_pandas` (PUT + COPY INTO pattern)
- **Dry-run mode** to preview data as CSV before loading

### dbt Transformations
- **Staging layer**: Type casting, boolean standardization, whitespace trimming, response-time calculation (`days_to_forward`)
- **Intermediate layer**: Monthly company metrics, product complaint trends, percentile-based response time analysis (p50/p90/p95)
- **Marts layer**: Star-schema fact/dimension tables plus an interview-ready company scorecard with trailing-12-month trend indicators

### Data Quality
- dbt tests on primary keys (`unique`, `not_null`), required fields, and business logic
- Source freshness definitions
- Documented models with column-level descriptions

## Setup

### Prerequisites
- Python 3.10+
- A [Snowflake account](https://signup.snowflake.com/) (free trial works)
- Git

### 1. Clone and install dependencies

```bash
git clone https://github.com/YOUR_USERNAME/cfpb-financial-complaints-pipeline.git
cd cfpb-financial-complaints-pipeline
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Configure Snowflake credentials

```bash
cp config/.env.example config/.env
# Edit config/.env with your Snowflake account details
```

### 3. Create Snowflake objects

Run `scripts/snowflake_setup.sql` in the Snowflake web UI or via SnowSQL to create the warehouse, database, schemas, and tables.

### 4. Ingest data

```bash
# Full load — all complaints for target companies since 2020
python scripts/ingest_cfpb_complaints.py --mode full

# Incremental — only complaints from the last 7 days
python scripts/ingest_cfpb_complaints.py --mode incremental --date-from 2024-01-01

# Dry run — preview without loading
python scripts/ingest_cfpb_complaints.py --mode full --dry-run
```

### 5. Run dbt transformations

```bash
cd dbt_project
cp profiles.yml.example ~/.dbt/profiles.yml
# Edit ~/.dbt/profiles.yml with your credentials

dbt debug        # Verify connection
dbt run           # Build all models
dbt test          # Run data quality tests
dbt docs generate # Generate documentation site
dbt docs serve    # Browse the documentation locally
```

## Sample Insights

The `rpt_company_scorecard` model produces output like:

| Company | Total Complaints | Timely Response % | Dispute Rate % | 12-Mo Trend |
|---------|-----------------|-------------------|---------------|-------------|
| CAPITAL ONE | 125,000 | 97.2% | 8.1% | IMPROVING |
| NAVY FEDERAL CREDIT UNION | 18,500 | 95.8% | 6.3% | STABLE |
| JPMORGAN CHASE | 210,000 | 98.1% | 7.5% | IMPROVING |

## Target Companies

This pipeline specifically tracks complaints filed against:
- Capital One
- Navy Federal Credit Union
- WEX Bank
- JPMorgan Chase & Co.
- Bank of America
- Wells Fargo
- Citibank
- Discover
- Synchrony Financial
- American Express

## License

MIT
