"""Classify baby names into themes with an LLM (LangChain) and save to BigQuery.

Reads distinct names from example-501820.babynames.names_all, asks Claude to tag each
name as 'nature', 'religion' or 'other', and writes the results to
example-501820.babynames.name_themes. Names already in name_themes are skipped, so the
script can be re-run safely to resume or to extend --min-count downward.

Setup:
    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
    export ANTHROPIC_API_KEY=...   # set in your terminal; never commit it

Usage:
    .venv/bin/python classify_names.py --dry-run            # show what would be classified
    .venv/bin/python classify_names.py --limit 100          # small test run
    .venv/bin/python classify_names.py                      # all names with >= 1000 babies
"""

import argparse
import os
import sys
from typing import Literal

from google.cloud import bigquery
from langchain_anthropic import ChatAnthropic
from langchain_core.prompts import ChatPromptTemplate
from pydantic import BaseModel, Field

PROJECT = "example-501820"
SOURCE_TABLE = f"{PROJECT}.babynames.names_all"
THEMES_TABLE = f"{PROJECT}.babynames.name_themes"

SYSTEM_PROMPT = """You classify US baby first names by the origin or inspiration of the name.

Themes:
- nature: the name is a plant, flower, tree, animal, bird, weather, season, body of water,
  landscape feature, or celestial/natural phenomenon (e.g. Rose, Willow, River, Autumn, Wolf).
- religion: the name is a figure, place, or term from a religious tradition (Bible, Quran,
  Hindu, Buddhist, other faiths, saints) or a religious concept (e.g. Mary, Elijah, Fatima,
  Faith, Trinity, Nevaeh, Krishna).
- other: neither (e.g. surnames, invented names, names of non-religious origin).

Rules:
- Pick the single best theme based on the name's most direct meaning or origin.
- If a name is both (e.g. Eden, Lily), choose the stronger origin and say so in the reason.
- confidence is 0-1: how sure you are about the theme.
- Keep reason under 12 words.
- Return exactly one result per input name, spelled exactly as given."""


class NameTheme(BaseModel):
    name: str
    theme: Literal["nature", "religion", "other"]
    confidence: float = Field(ge=0, le=1)
    reason: str


class Batch(BaseModel):
    results: list[NameTheme]


def fetch_names(client, min_count, limit):
    query = f"""
        SELECT name, SUM(count) AS total_babies
        FROM `{SOURCE_TABLE}`
        GROUP BY name
        HAVING SUM(count) >= @min_count
           AND name NOT IN (SELECT name FROM `{THEMES_TABLE}`)
        ORDER BY total_babies DESC
        {"LIMIT " + str(limit) if limit else ""}
    """
    config = bigquery.QueryJobConfig(
        query_parameters=[bigquery.ScalarQueryParameter("min_count", "INT64", min_count)]
    )
    return [row["name"] for row in client.query(query, job_config=config).result()]


def ensure_table(client):
    schema = [
        bigquery.SchemaField("name", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("theme", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("confidence", "FLOAT64"),
        bigquery.SchemaField("reason", "STRING"),
        bigquery.SchemaField("model", "STRING"),
    ]
    client.create_table(bigquery.Table(THEMES_TABLE, schema=schema), exists_ok=True)


def classify_batch(chain, names):
    out = chain.invoke({"names": "\n".join(names)})
    by_name = {r.name: r for r in out.results}
    return [by_name[n] for n in names if n in by_name]


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--min-count", type=int, default=1000,
                        help="only classify names with at least this many babies total")
    parser.add_argument("--limit", type=int, default=None, help="cap number of names (testing)")
    parser.add_argument("--batch-size", type=int, default=50)
    parser.add_argument("--model", default="claude-haiku-4-5")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    client = bigquery.Client(project=PROJECT)
    ensure_table(client)
    names = fetch_names(client, args.min_count, args.limit)
    print(f"{len(names)} names to classify (min_count={args.min_count})")
    if args.dry_run or not names:
        print(names[:20])
        return

    if not os.environ.get("ANTHROPIC_API_KEY"):
        sys.exit("ANTHROPIC_API_KEY is not set. Run: export ANTHROPIC_API_KEY=...")

    prompt = ChatPromptTemplate.from_messages(
        [("system", SYSTEM_PROMPT), ("human", "Classify these names:\n{names}")]
    )
    llm = ChatAnthropic(model=args.model, temperature=0, max_retries=5)
    chain = prompt | llm.with_structured_output(Batch)

    done = 0
    for i in range(0, len(names), args.batch_size):
        batch = names[i:i + args.batch_size]
        results = classify_batch(chain, batch)
        rows = [{"name": r.name, "theme": r.theme, "confidence": r.confidence,
                 "reason": r.reason, "model": args.model} for r in results]
        errors = client.insert_rows_json(THEMES_TABLE, rows)
        if errors:
            sys.exit(f"BigQuery insert failed: {errors[:3]}")
        done += len(rows)
        missed = len(batch) - len(rows)
        print(f"{done}/{len(names)} saved" + (f" ({missed} missed, will retry on next run)" if missed else ""))


if __name__ == "__main__":
    main()
