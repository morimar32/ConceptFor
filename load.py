#!/usr/bin/env python3
"""Load en-conceptnet-assertions-5.7.0.csv into SQLite (one table per relation).

Reads schema.sql, creates tables, streams the CSV with batched inserts,
then creates indexes. Stdlib only — no external dependencies.
"""

import argparse
import json
import os
import sqlite3
import sys
import time

# ── Relation URI → (table, start_column, end_column) ────────────────────────

RELATION_MAP = {
    # Symmetric relations
    "/r/RelatedTo":               ("related_to",                "concept_a",    "concept_b"),
    "/r/Synonym":                 ("synonym",                   "term_a",       "term_b"),
    "/r/Antonym":                 ("antonym",                   "term",         "opposite"),
    "/r/DistinctFrom":            ("distinct_from",             "concept_a",    "concept_b"),
    "/r/LocatedNear":             ("located_near",              "entity_a",     "entity_b"),
    "/r/SimilarTo":               ("similar_to",                "concept_a",    "concept_b"),
    "/r/EtymologicallyRelatedTo": ("etymologically_related_to", "word_a",       "word_b"),
    # Taxonomy & classification
    "/r/IsA":                     ("is_a",                      "instance",     "type"),
    "/r/FormOf":                  ("form_of",                   "inflection",   "root"),
    "/r/MannerOf":                ("manner_of",                 "specific",     "general"),
    "/r/DefinedAs":               ("defined_as",                "term",         "definition"),
    # Part-whole & composition
    "/r/PartOf":                  ("part_of",                   "part",         "whole"),
    "/r/HasA":                    ("has_a",                     "whole",        "possession"),
    "/r/MadeOf":                  ("made_of",                   "object",       "material"),
    # Properties & attributes
    "/r/HasProperty":             ("has_property",              "entity",       "property"),
    "/r/SymbolOf":                ("symbol_of",                 "symbol",       "meaning"),
    # Spatial
    "/r/AtLocation":              ("at_location",               "entity",       "location"),
    # Capabilities & agency
    "/r/CapableOf":               ("capable_of",                "agent",        "action"),
    "/r/ReceivesAction":          ("receives_action",           "patient",      "action"),
    "/r/CreatedBy":               ("created_by",                "creation",     "creator"),
    # Purpose & function
    "/r/UsedFor":                 ("used_for",                  "tool",         "purpose"),
    # Causation & events
    "/r/Causes":                  ("causes",                    "cause",        "effect"),
    "/r/HasSubevent":             ("has_subevent",              "event",        "subevent"),
    "/r/HasFirstSubevent":        ("has_first_subevent",        "event",        "first_subevent"),
    "/r/HasLastSubevent":         ("has_last_subevent",         "event",        "last_subevent"),
    "/r/HasPrerequisite":         ("has_prerequisite",          "action",       "prerequisite"),
    # Desires & goals
    "/r/Desires":                 ("desires",                   "agent",        "desire"),
    "/r/CausesDesire":            ("causes_desire",             "stimulus",     "desire"),
    "/r/MotivatedByGoal":         ("motivated_by_goal",         "action",       "goal"),
    # Lexical & usage context
    "/r/HasContext":              ("has_context",               "term",         "context"),
    # Etymology
    "/r/EtymologicallyDerivedFrom": ("etymologically_derived_from", "derived_word", "source_word"),
    "/r/DerivedFrom":             ("derived_from",              "derivative",   "origin"),
    # Deprecated relations
    "/r/InstanceOf":              ("instance_of",               "instance",     "class"),
    "/r/Entails":                 ("entails",                   "action",       "entailed_action"),
    "/r/NotDesires":              ("not_desires",               "agent",        "undesired"),
    "/r/NotCapableOf":            ("not_capable_of",            "agent",        "action"),
    "/r/NotHasProperty":          ("not_has_property",          "entity",       "property"),
    # DBpedia relations
    "/r/dbpedia/capital":         ("dbpedia_capital",           "entity",       "capital"),
    "/r/dbpedia/field":           ("dbpedia_field",             "person",       "field"),
    "/r/dbpedia/genre":           ("dbpedia_genre",             "work",         "genre"),
    "/r/dbpedia/genus":           ("dbpedia_genus",             "species",      "genus"),
    "/r/dbpedia/influencedBy":    ("dbpedia_influenced_by",     "subject",      "influencer"),
    "/r/dbpedia/knownFor":        ("dbpedia_known_for",         "person",       "achievement"),
    "/r/dbpedia/language":        ("dbpedia_language",           "entity",       "language"),
    "/r/dbpedia/leader":          ("dbpedia_leader",            "entity",       "leader"),
    "/r/dbpedia/occupation":      ("dbpedia_occupation",        "person",       "occupation"),
    "/r/dbpedia/product":         ("dbpedia_product",           "company",      "product"),
}

BATCH_SIZE = 50_000
PROGRESS_INTERVAL = 500_000


def parse_schema(schema_path):
    """Split schema.sql into CREATE TABLE and CREATE INDEX statements."""
    with open(schema_path) as f:
        sql = f.read()

    creates = []
    indexes = []
    for stmt in sql.split(";"):
        stmt = stmt.strip()
        if not stmt:
            continue
        upper = stmt.upper()
        if "CREATE TABLE" in upper:
            creates.append(stmt + ";")
        elif "CREATE INDEX" in upper:
            indexes.append(stmt + ";")
    return creates, indexes


def build_insert_sql():
    """Build per-table INSERT OR IGNORE statements."""
    stmts = {}
    for rel, (table, start_col, end_col) in RELATION_MAP.items():
        stmts[rel] = (
            f"INSERT OR IGNORE INTO {table} "
            f"(uri, {start_col}, {end_col}, weight, surface_text, surface_start, surface_end) "
            f"VALUES (?, ?, ?, ?, ?, ?, ?)"
        )
    return stmts


def load(csv_path, db_path, schema_path):
    creates, indexes = parse_schema(schema_path)
    insert_stmts = build_insert_sql()

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    # Performance PRAGMAs for bulk load
    cur.execute("PRAGMA synchronous = OFF")
    cur.execute("PRAGMA cache_size = -512000")
    cur.execute("PRAGMA temp_store = MEMORY")
    cur.execute("PRAGMA mmap_size = 1073741824")
    cur.execute("PRAGMA journal_mode = WAL")

    # Create tables (not indexes yet)
    for stmt in creates:
        cur.execute(stmt)
    conn.commit()

    # Check if already loaded
    cur.execute("SELECT COUNT(*) FROM related_to")
    if cur.fetchone()[0] > 0:
        print("Database already loaded — exiting.")
        conn.close()
        return

    # Per-table row buffers and counters
    buffers = {rel: [] for rel in RELATION_MAP}
    counts = {rel: 0 for rel in RELATION_MAP}
    skipped = 0
    total = 0

    def flush(rel):
        if buffers[rel]:
            cur.executemany(insert_stmts[rel], buffers[rel])
            buffers[rel].clear()

    def flush_all():
        for rel in buffers:
            flush(rel)

    t0 = time.monotonic()
    cur.execute("BEGIN TRANSACTION")

    with open(csv_path, encoding="utf-8") as f:
        for line in f:
            total += 1
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 5:
                skipped += 1
                print(f"WARNING: row {total}: expected 5 fields, got {len(parts)}", file=sys.stderr)
                continue

            uri, relation, start, end, meta_json = parts

            if relation not in RELATION_MAP:
                skipped += 1
                print(f"WARNING: row {total}: unknown relation {relation!r}", file=sys.stderr)
                continue

            try:
                meta = json.loads(meta_json)
            except (json.JSONDecodeError, ValueError):
                skipped += 1
                print(f"WARNING: row {total}: bad JSON", file=sys.stderr)
                continue

            weight = meta.get("weight", 1.0)
            surface_text = meta.get("surfaceText")
            surface_start = meta.get("surfaceStart")
            surface_end = meta.get("surfaceEnd")

            buffers[relation].append((uri, start, end, weight, surface_text, surface_start, surface_end))
            counts[relation] += 1

            if len(buffers[relation]) >= BATCH_SIZE:
                flush(relation)

            if total % PROGRESS_INTERVAL == 0:
                elapsed = time.monotonic() - t0
                rate = total / elapsed if elapsed > 0 else 0
                print(f"  {total:>10,} rows  {elapsed:6.1f}s  {rate:,.0f} rows/s")

    flush_all()
    conn.commit()

    # Create indexes after all data is loaded
    print("Creating indexes...")
    t_idx = time.monotonic()
    for stmt in indexes:
        cur.execute(stmt)
    conn.commit()
    print(f"Indexes created in {time.monotonic() - t_idx:.1f}s")

    # Restore safe PRAGMAs
    cur.execute("PRAGMA synchronous = NORMAL")
    conn.close()

    # Summary
    elapsed = time.monotonic() - t0
    loaded = sum(counts.values())
    print(f"\nDone in {elapsed:.1f}s — {loaded:,} rows loaded, {skipped:,} skipped")
    print(f"\nPer-table counts:")
    for rel in sorted(counts, key=lambda r: counts[r], reverse=True):
        if counts[rel] > 0:
            table = RELATION_MAP[rel][0]
            print(f"  {table:<35} {counts[rel]:>10,}")


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description="Load ConceptNet CSV into SQLite")
    parser.add_argument("--csv", default=os.path.join(script_dir, "data", "en-conceptnet-assertions-5.7.0.csv"))
    parser.add_argument("--db", default=os.path.join(script_dir, "conceptnet.db"))
    parser.add_argument("--schema", default=os.path.join(script_dir, "schema.sql"))
    args = parser.parse_args()

    print(f"CSV:    {args.csv}")
    print(f"DB:     {args.db}")
    print(f"Schema: {args.schema}")
    print()

    load(args.csv, args.db, args.schema)


if __name__ == "__main__":
    main()
