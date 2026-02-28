# ConceptFor

| | | | | | | |
|-|-|-|-|-|-|-|
|-|-|-|-|-|-|-|
|-|-|-|-|-|-|-|
|-|-|-|-|-|-|-|
|-|-|-|🟡|-|-|-|
|-|-|🟡|🔴|🟡|-|-|
|-|🟡|🔴|🔴|🔴|-|-|

A pipeline to take the [**Concept**Net 5.7.0](https://conceptnet.io/) knowledge graph and prepare it **_For_** use in downstream systems. The raw 34M-assertion multilingual dump is filtered, structured, and loaded into a single SQLite database with semantically named tables — no dependencies beyond Python's standard library.

## What's Inside

ConceptNet is a freely available semantic network: a graph of general knowledge where nodes are words/phrases and edges are labeled relationships like "is a", "used for", "causes", and "part of". It draws from expert resources (WordNet, Wiktionary, DBpedia) and crowdsourced data (Open Mind Common Sense).

This project extracts the **English-only subset** and loads it into a **single 808 MB SQLite file** with one table per relationship type:

| | |
|---|---|
| **Assertions** | 3,423,004 |
| **Distinct concepts** | ~1,630,000 |
| **Relationship types** | 47 tables |
| **Indexes** | 62 |
| **Database size** | 808 MB |

### The 47 Relationship Types

**Symmetric** (7) — bidirectional, order doesn't matter:

| Table | Meaning | Rows |
|-------|---------|------|
| `related_to` | General topical association | 1,703,582 |
| `synonym` | Means the same as | 222,156 |
| `etymologically_related_to` | Shared etymological origin | 32,075 |
| `similar_to` | Resemblance (weaker than synonym) | 30,280 |
| `antonym` | Opposite meaning | 19,066 |
| `distinct_from` | Same category, different thing | 3,315 |
| `located_near` | Typical spatial proximity | 49 |

**Taxonomy & Classification** (4) — categorical hierarchies:

| Table | Meaning | Example | Rows |
|-------|---------|---------|------|
| `form_of` | Inflected form of a root word | ran → run | 378,859 |
| `is_a` | Hyponymy / "is a kind of" | cat → animal | 230,137 |
| `manner_of` | Specific way to do something | sprint → run | 12,715 |
| `defined_as` | Explanatory equivalence | — | 2,173 |

**Part-Whole** (3): `part_of` (13K), `has_a` (5.5K), `made_of` (545)

**Properties** (2): `has_property` (8.4K), `symbol_of` (4)

**Spatial** (1): `at_location` (28K)

**Capabilities** (3): `capable_of` (23K), `receives_action` (6K), `created_by` (263)

**Purpose** (1): `used_for` (40K)

**Causation & Events** (5): `causes` (17K), `has_subevent` (25K), `has_first_subevent` (3.3K), `has_last_subevent` (2.9K), `has_prerequisite` (23K)

**Desires & Goals** (3): `desires` (3.2K), `causes_desire` (4.7K), `motivated_by_goal` (9.5K)

**Lexical Context** (1): `has_context` (233K) — maps terms to domains like medicine, slang, computing

**Etymology** (2): `derived_from` (325K), `etymologically_derived_from` (71)

**DBpedia** (10): `dbpedia_capital`, `dbpedia_field`, `dbpedia_genre`, `dbpedia_genus`, `dbpedia_influenced_by`, `dbpedia_known_for`, `dbpedia_language`, `dbpedia_leader`, `dbpedia_occupation`, `dbpedia_product`

**Deprecated** (5): `instance_of`, `entails`, `not_desires`, `not_capable_of`, `not_has_property`

For column names, example values, weight distributions, surface text coverage, and querying tips, see the full **[Data Dictionary](DATADICTIONARY.md)**.

## Concepts

Concepts are stored as ConceptNet URI strings:

```
/c/en/cat            ← bare word
/c/en/cat/n          ← word + POS (noun)
/c/en/cat/n/wn/pet   ← word + POS + WordNet sense
```

Multi-word concepts use underscores: `/c/en/ice_cream`, `/c/en/new_york`.

## Weight

Each assertion has a `weight` (REAL) reflecting confidence — higher means more sources agree. Ranges from 0.1 to 22.9. The vast majority (85.5%) sit at exactly 1.0. The strongest assertion in the entire database: *"baseball is a sport"* at 22.9.

## Quick Start

### Prerequisites

- Python 3.6+
- ~10.5 GB disk space (CSV + database)
- The ConceptNet assertions dump: [conceptnet-assertions-5.7.0.csv.gz](https://s3.amazonaws.com/conceptnet/downloads/2019/edges/conceptnet-assertions-5.7.0.csv.gz)

### Pipeline

```bash
# 1. Download and decompress the full ConceptNet dump into data/
#    (34M rows, ~4 GB decompressed)

# 2. Filter to English-only (both concepts must be /c/en/)
./english_export.sh
# → data/en-conceptnet-assertions-5.7.0.csv (3,423,004 rows, 968 MB)

# 3. Load into SQLite
python load.py
# → conceptnet.db (808 MB, ~20 seconds)
```

Re-running `load.py` on an already-loaded database exits immediately.

### Querying

```bash
sqlite3 conceptnet.db
```

```sql
-- What is a cat?
SELECT type, weight FROM is_a
WHERE instance = '/c/en/cat/n'
ORDER BY weight DESC;
-- felis, non_person_animal

-- What can a bird do?
SELECT action, weight FROM capable_of
WHERE agent LIKE '/c/en/bird%'
ORDER BY weight DESC;

-- Synonyms of "happy" (symmetric — check both sides)
SELECT term_b FROM synonym WHERE term_a LIKE '/c/en/happy%'
UNION
SELECT term_a FROM synonym WHERE term_b LIKE '/c/en/happy%';

-- What is a knife used for?
SELECT purpose, weight FROM used_for
WHERE tool LIKE '/c/en/knife%'
ORDER BY weight DESC;

-- What causes fire?
SELECT cause, weight FROM causes
WHERE effect LIKE '/c/en/fire%'
ORDER BY weight DESC;
```

## Project Structure

```
ConceptFor/
├── README.md                  ← this file
├── DATADICTIONARY.md          ← full schema reference (all 47 tables)
├── english_export.sh          ← phase 1: filter CSV to English-only
├── schema.sql                 ← phase 2: SQLite schema (47 tables, 62 indexes)
├── load.py                    ← phase 3: CSV → SQLite loader
├── conceptnet.db              (808 MB, not committed)
└── data/
    └── en-conceptnet-assertions-5.7.0.csv  (968 MB, not committed)
```

## Design Decisions

**One table per relationship** — Instead of a single edges table with a `relation` column, each of the 47 relationship types gets its own table. This means column names describe the semantic role: `is_a` has `instance` and `type`, `causes` has `cause` and `effect`, `capable_of` has `agent` and `action`. Queries read naturally and don't need joins or lookups.

**No normalization** — Concept URIs are stored as text directly in every row. This trades some disk space for query simplicity: no concept-ID lookup tables, no joins for basic queries.

**Deferred indexing** — During the load, tables are created without indexes. All 3.4M rows are inserted in a single transaction, then the 62 indexes are built afterward. This is roughly 3x faster than indexing during insertion.

**Idempotent loading** — `load.py` checks if data already exists and exits early. Uses `INSERT OR IGNORE` to handle duplicate URIs gracefully, making partial re-runs safe.

