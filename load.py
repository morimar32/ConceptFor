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
    # Similarity
    "/r/RelatedTo":               ("similarity_related_to",                "concept_a",    "concept_b"),
    "/r/Synonym":                 ("similarity_synonym",                   "term_a",       "term_b"),
    "/r/Antonym":                 ("similarity_antonym",                   "term",         "opposite"),
    "/r/SimilarTo":               ("similarity_similar_to",                "concept_a",    "concept_b"),
    "/r/DistinctFrom":            ("similarity_distinct_from",             "concept_a",    "concept_b"),
    # Taxonomy
    "/r/IsA":                     ("taxonomy_is_a",                        "instance",     "type"),
    "/r/FormOf":                  ("taxonomy_form_of",                     "inflection",   "root"),
    "/r/MannerOf":                ("taxonomy_manner_of",                   "specific",     "general"),
    "/r/DefinedAs":               ("taxonomy_defined_as",                  "term",         "definition"),
    # Composition
    "/r/PartOf":                  ("composition_part_of",                  "part",         "whole"),
    "/r/HasA":                    ("composition_has_a",                    "whole",        "possession"),
    "/r/MadeOf":                  ("composition_made_of",                  "object",       "material"),
    # Attribute
    "/r/HasProperty":             ("attribute_has_property",               "entity",       "property"),
    "/r/SymbolOf":                ("attribute_symbol_of",                  "symbol",       "meaning"),
    # Spatial
    "/r/AtLocation":              ("spatial_at_location",                  "entity",       "location"),
    "/r/LocatedNear":             ("spatial_located_near",                 "entity_a",     "entity_b"),
    # Agency
    "/r/CapableOf":               ("agency_capable_of",                    "agent",        "action"),
    "/r/ReceivesAction":          ("agency_receives_action",               "patient",      "action"),
    "/r/CreatedBy":               ("agency_created_by",                    "creation",     "creator"),
    "/r/UsedFor":                 ("agency_used_for",                      "tool",         "purpose"),
    # Causation
    "/r/Causes":                  ("causation_causes",                     "cause",        "effect"),
    "/r/HasSubevent":             ("causation_has_subevent",               "event",        "subevent"),
    "/r/HasFirstSubevent":        ("causation_has_first_subevent",         "event",        "first_subevent"),
    "/r/HasLastSubevent":         ("causation_has_last_subevent",          "event",        "last_subevent"),
    "/r/HasPrerequisite":         ("causation_has_prerequisite",           "action",       "prerequisite"),
    # Motivation
    "/r/Desires":                 ("motivation_desires",                   "agent",        "desire"),
    "/r/CausesDesire":            ("motivation_causes_desire",             "stimulus",     "desire"),
    "/r/MotivatedByGoal":         ("motivation_motivated_by_goal",         "action",       "goal"),
    # Context
    "/r/HasContext":              ("context_has_context",                  "term",         "context"),
    # Etymology
    "/r/DerivedFrom":             ("etymology_derived_from",              "derivative",   "origin"),
    "/r/EtymologicallyDerivedFrom": ("etymology_etymologically_derived_from", "derived_word", "source_word"),
    "/r/EtymologicallyRelatedTo": ("etymology_etymologically_related_to", "word_a",       "word_b"),
    # Entity (DBpedia)
    "/r/dbpedia/capital":         ("entity_capital",                      "entity",       "capital"),
    "/r/dbpedia/field":           ("entity_field",                        "person",       "field"),
    "/r/dbpedia/genre":           ("entity_genre",                        "work",         "genre"),
    "/r/dbpedia/genus":           ("entity_genus",                        "species",      "genus"),
    "/r/dbpedia/influencedBy":    ("entity_influenced_by",                "subject",      "influencer"),
    "/r/dbpedia/knownFor":        ("entity_known_for",                    "person",       "achievement"),
    "/r/dbpedia/language":        ("entity_language",                     "entity",       "language"),
    "/r/dbpedia/leader":          ("entity_leader",                       "entity",       "leader"),
    "/r/dbpedia/occupation":      ("entity_occupation",                   "person",       "occupation"),
    "/r/dbpedia/product":         ("entity_product",                      "company",      "product"),
}

# Tables that get word/POS extraction — maps table name to tuple of column
# names whose values should be parsed into <col>_word and <col>_pos pairs.
TABLES_WITH_WORD_POS = {
    "taxonomy_is_a":       ("instance", "type"),
    "taxonomy_form_of":    ("inflection", "root"),
    "taxonomy_manner_of":  ("specific", "general"),
    "context_has_context": ("term",),
}

BATCH_SIZE = 50_000
PROGRESS_INTERVAL = 500_000


def parse_concept(stripped):
    """Parse a stripped concept into (word, pos).

    'cat/n/wn/pet' -> ('cat', 'n')
    'ice_cream'    -> ('ice_cream', None)
    """
    parts = stripped.split('/')
    word = parts[0]
    pos = parts[1] if len(parts) > 1 and parts[1] in ('n', 'v', 'a', 'r') else None
    return word, pos


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
        wp = TABLES_WITH_WORD_POS.get(table)
        if wp is None:
            # Standard table: 6 placeholders
            stmts[rel] = (
                f"INSERT OR IGNORE INTO {table} "
                f"({start_col}, {end_col}, weight, surface_text, surface_start, surface_end) "
                f"VALUES (?, ?, ?, ?, ?, ?)"
            )
        elif len(wp) == 2:
            # Both columns get word/pos: 10 placeholders
            s_word = f"{wp[0]}_word"
            s_pos = f"{wp[0]}_pos"
            e_word = f"{wp[1]}_word"
            e_pos = f"{wp[1]}_pos"
            stmts[rel] = (
                f"INSERT OR IGNORE INTO {table} "
                f"({start_col}, {s_word}, {s_pos}, {end_col}, {e_word}, {e_pos}, "
                f"weight, surface_text, surface_start, surface_end) "
                f"VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            )
        else:
            # Start column only gets word/pos: 8 placeholders
            s_word = f"{wp[0]}_word"
            s_pos = f"{wp[0]}_pos"
            stmts[rel] = (
                f"INSERT OR IGNORE INTO {table} "
                f"({start_col}, {s_word}, {s_pos}, {end_col}, "
                f"weight, surface_text, surface_start, surface_end) "
                f"VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
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
    cur.execute("SELECT COUNT(*) FROM similarity_related_to")
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

            _uri, relation, start, end, meta_json = parts

            if relation not in RELATION_MAP:
                skipped += 1
                continue

            try:
                meta = json.loads(meta_json)
            except (json.JSONDecodeError, ValueError):
                skipped += 1
                print(f"WARNING: row {total}: bad JSON", file=sys.stderr)
                continue

            # Strip /c/en/ prefix
            start = start[6:]
            end = end[6:]

            weight = meta.get("weight", 1.0)
            surface_text = meta.get("surfaceText")
            surface_start = meta.get("surfaceStart")
            surface_end = meta.get("surfaceEnd")

            table = RELATION_MAP[relation][0]
            wp = TABLES_WITH_WORD_POS.get(table)

            if wp is None:
                row = (start, end, weight, surface_text, surface_start, surface_end)
            elif len(wp) == 2:
                s_word, s_pos = parse_concept(start)
                e_word, e_pos = parse_concept(end)
                row = (start, s_word, s_pos, end, e_word, e_pos,
                       weight, surface_text, surface_start, surface_end)
            else:
                s_word, s_pos = parse_concept(start)
                row = (start, s_word, s_pos, end,
                       weight, surface_text, surface_start, surface_end)

            buffers[relation].append(row)
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
            print(f"  {table:<50} {counts[rel]:>10,}")


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
