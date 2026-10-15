"""
CFPB Consumer Complaints Data Ingestion Pipeline
=================================================
Extracts complaint data from the CFPB public API and loads it
into a Snowflake RAW_COMPLAINTS table. Supports both full-load
and incremental modes.

Data source: https://www.consumerfinance.gov/data-research/consumer-complaints/
API docs:    https://cfpb.github.io/api/ccdb/

Author: Ryan Frazier
"""

import os
import sys
import time
from datetime import datetime, timedelta

import pandas as pd
import requests
import snowflake.connector
from dotenv import load_dotenv
from loguru import logger

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

load_dotenv(os.path.join(os.path.dirname(__file__), "..", "config", ".env"))

SNOWFLAKE_CONFIG = {
    "account": os.getenv("SNOWFLAKE_ACCOUNT"),
    "user": os.getenv("SNOWFLAKE_USER"),
    "password": os.getenv("SNOWFLAKE_PASSWORD"),
    "role": os.getenv("SNOWFLAKE_ROLE", "SYSADMIN"),
    "warehouse": os.getenv("SNOWFLAKE_WAREHOUSE", "CFPB_WH"),
    "database": os.getenv("SNOWFLAKE_DATABASE", "CFPB_ANALYTICS"),
    "schema": os.getenv("SNOWFLAKE_SCHEMA", "RAW"),
}

CFPB_API_URL = os.getenv(
    "CFPB_API_BASE_URL",
    "https://www.consumerfinance.gov/data-research/consumer-complaints/search/api/v1/",
)
BATCH_SIZE = int(os.getenv("CFPB_BATCH_SIZE", "10000"))

# Target financial companies — the ones you're applying to + peers
TARGET_COMPANIES = [
    "CAPITAL ONE FINANCIAL CORPORATION",
    "NAVY FEDERAL CREDIT UNION",
    "WEX BANK",
    "JPMORGAN CHASE & CO.",
    "BANK OF AMERICA, NATIONAL ASSOCIATION",
    "WELLS FARGO & COMPANY",
    "CITIBANK, N.A.",
    "DISCOVER BANK",
    "SYNCHRONY FINANCIAL",
    "AMERICAN EXPRESS COMPANY",
]

# Configure logging
logger.remove()
logger.add(sys.stderr, level="INFO", format="{time:HH:mm:ss} | {level:<7} | {message}")
logger.add(
    os.path.join(os.path.dirname(__file__), "..", "logs", "ingestion_{time}.log"),
    rotation="10 MB",
    level="DEBUG",
)


# ---------------------------------------------------------------------------
# CFPB API extraction
# ---------------------------------------------------------------------------


def fetch_complaints(
    date_from: str = "2020-01-01",
    date_to: str | None = None,
    company: str | None = None,
) -> pd.DataFrame:
    """
    Pull complaints from the CFPB API with pagination.

    Parameters
    ----------
    date_from : str
        Start date in YYYY-MM-DD format.
    date_to : str, optional
        End date. Defaults to today.
    company : str, optional
        Filter to a single company name.

    Returns
    -------
    pd.DataFrame
    """
    if date_to is None:
        date_to = datetime.today().strftime("%Y-%m-%d")

    all_records: list[dict] = []
    offset = 0

    params = {
        "date_received_min": date_from,
        "date_received_max": date_to,
        "size": BATCH_SIZE,
        "no_aggs": "true",
        "sort": "created_date_desc",
    }
    if company:
        params["company"] = company

    while True:
        params["frm"] = offset
        logger.info(f"Fetching records {offset} to {offset + BATCH_SIZE}...")

        try:
            resp = requests.get(CFPB_API_URL, params=params, timeout=120)
            resp.raise_for_status()
        except requests.RequestException as exc:
            logger.error(f"API request failed: {exc}")
            break

        data = resp.json()
        hits = data.get("hits", {}).get("hits", [])

        if not hits:
            logger.info("No more records to fetch.")
            break

        for hit in hits:
            src = hit.get("_source", {})
            all_records.append(
                {
                    "complaint_id": src.get("complaint_id"),
                    "date_received": src.get("date_received"),
                    "product": src.get("product"),
                    "sub_product": src.get("sub_product"),
                    "issue": src.get("issue"),
                    "sub_issue": src.get("sub_issue"),
                    "consumer_complaint_narrative": src.get(
                        "complaint_what_happened"
                    ),
                    "company_public_response": src.get("company_public_response"),
                    "company": src.get("company"),
                    "state": src.get("state"),
                    "zip_code": src.get("zip_code"),
                    "tags": src.get("tags"),
                    "consumer_consent_provided": src.get(
                        "consumer_consent_provided"
                    ),
                    "submitted_via": src.get("submitted_via"),
                    "date_sent_to_company": src.get("date_sent_to_company"),
                    "company_response": src.get("company_response_to_consumer"),
                    "timely_response": src.get("timely"),
                    "consumer_disputed": src.get("consumer_disputed"),
                }
            )

        offset += BATCH_SIZE

        # CFPB API caps at 10,000 with offset; use date windowing for more
        if offset >= 10000:
            logger.warning(
                "Hit CFPB API 10k offset limit. Use date windowing for full extraction."
            )
            break

        time.sleep(0.5)  # Be polite to the API

    df = pd.DataFrame(all_records)
    logger.info(f"Fetched {len(df):,} complaint records total.")
    return df


def fetch_all_target_companies(
    date_from: str = "2020-01-01",
) -> pd.DataFrame:
    """Fetch complaints for all target companies, bypassing the 10k limit."""
    frames: list[pd.DataFrame] = []

    for company in TARGET_COMPANIES:
        logger.info(f"--- Fetching complaints for: {company} ---")
        df = fetch_complaints(date_from=date_from, company=company)
        if not df.empty:
            frames.append(df)

    if not frames:
        return pd.DataFrame()

    combined = pd.concat(frames, ignore_index=True).drop_duplicates(
        subset=["complaint_id"]
    )
    logger.info(f"Total unique complaints across all targets: {len(combined):,}")
    return combined


# ---------------------------------------------------------------------------
# Snowflake loading
# ---------------------------------------------------------------------------


def get_snowflake_connection() -> snowflake.connector.SnowflakeConnection:
    """Create and return a Snowflake connection."""
    logger.info(f"Connecting to Snowflake account: {SNOWFLAKE_CONFIG['account']}")
    conn = snowflake.connector.connect(**SNOWFLAKE_CONFIG)
    logger.info("Connected to Snowflake successfully.")
    return conn


def load_to_snowflake(df: pd.DataFrame, mode: str = "append") -> int:
    """
    Load a DataFrame into RAW_COMPLAINTS.

    Parameters
    ----------
    df : pd.DataFrame
        Complaint data to load.
    mode : str
        'append' for incremental, 'replace' for full refresh.

    Returns
    -------
    int
        Number of rows loaded.
    """
    if df.empty:
        logger.warning("Empty DataFrame — nothing to load.")
        return 0

    conn = get_snowflake_connection()
    cursor = conn.cursor()

    try:
        if mode == "replace":
            logger.info("Full refresh mode: truncating RAW_COMPLAINTS...")
            cursor.execute("TRUNCATE TABLE IF EXISTS RAW.RAW_COMPLAINTS")

        # Use write_pandas for efficient bulk loading via PUT + COPY INTO
        from snowflake.connector.pandas_tools import write_pandas

        success, num_chunks, num_rows, _ = write_pandas(
            conn=conn,
            df=df,
            table_name="RAW_COMPLAINTS",
            schema="RAW",
            database="CFPB_ANALYTICS",
            overwrite=False,
            quote_identifiers=False,
        )

        logger.info(f"Loaded {num_rows:,} rows in {num_chunks} chunk(s).")
        return num_rows

    except Exception as exc:
        logger.error(f"Snowflake load failed: {exc}")
        raise
    finally:
        cursor.close()
        conn.close()


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------


def main():
    """Run the full extract-load pipeline."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Ingest CFPB complaints into Snowflake"
    )
    parser.add_argument(
        "--mode",
        choices=["full", "incremental"],
        default="incremental",
        help="full = truncate + reload; incremental = append recent data",
    )
    parser.add_argument(
        "--date-from",
        default=None,
        help="Start date (YYYY-MM-DD). Defaults to 2020-01-01 for full, last 30 days for incremental.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Fetch data but don't load to Snowflake (saves to local CSV instead).",
    )
    args = parser.parse_args()

    # Determine date range
    if args.date_from:
        date_from = args.date_from
    elif args.mode == "full":
        date_from = "2020-01-01"
    else:
        date_from = (datetime.today() - timedelta(days=30)).strftime("%Y-%m-%d")

    logger.info(f"Pipeline mode: {args.mode} | date_from: {date_from}")

    # Extract
    df = fetch_all_target_companies(date_from=date_from)

    if df.empty:
        logger.warning("No data extracted. Exiting.")
        return

    # Type casting
    df["date_received"] = pd.to_datetime(df["date_received"]).dt.date
    df["date_sent_to_company"] = pd.to_datetime(
        df["date_sent_to_company"], errors="coerce"
    ).dt.date
    df["complaint_id"] = pd.to_numeric(df["complaint_id"], errors="coerce")

    # Rename columns to uppercase for Snowflake
    df.columns = [col.upper() for col in df.columns]

    if args.dry_run:
        out_path = os.path.join(
            os.path.dirname(__file__), "..", "data", "complaints_extract.csv"
        )
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        df.to_csv(out_path, index=False)
        logger.info(f"Dry run: saved {len(df):,} rows to {out_path}")
    else:
        load_mode = "replace" if args.mode == "full" else "append"
        rows = load_to_snowflake(df, mode=load_mode)
        logger.info(f"Pipeline complete. {rows:,} rows loaded to Snowflake.")


if __name__ == "__main__":
    main()
