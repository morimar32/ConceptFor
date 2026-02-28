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

This project extracts the **English-only subset** and loads it into a **single ~800 MB SQLite file** with one table per relationship type:

| | |
|---|---|
| **Assertions loaded** | ~3,417,577 |
| **Distinct concepts** | ~1,630,000 |
| **Relationship types** | 42 tables |
| **Indexes** | 64 |

### The 42 Relationship Types

**Similarity** (5) — bidirectional associations:

| Table | Meaning | Rows |
|-------|---------|------|
| `similarity_related_to` | General topical association | 1,703,582 |
| `similarity_synonym` | Means the same as | 222,156 |
| `similarity_similar_to` | Resemblance (weaker than synonym) | 30,280 |
| `similarity_antonym` | Opposite meaning | 19,066 |
| `similarity_distinct_from` | Same category, different thing | 3,315 |

**Taxonomy** (4) — categorical hierarchies (`_word`/`_pos` columns on 3 tables):

| Table | Meaning | Example | Rows |
|-------|---------|---------|------|
| `taxonomy_form_of` | Inflected form of a root word | ran → run | 378,859 |
| `taxonomy_is_a` | Hyponymy / "is a kind of" | cat → animal | 230,137 |
| `taxonomy_manner_of` | Specific way to do something | sprint → run | 12,715 |
| `taxonomy_defined_as` | Explanatory equivalence | — | 2,173 |

**Composition** (3): `composition_part_of` (13K), `composition_has_a` (5.5K), `composition_made_of` (545)

**Attribute** (2): `attribute_has_property` (8.4K), `attribute_symbol_of` (4)

**Spatial** (2): `spatial_at_location` (28K), `spatial_located_near` (49)

**Agency** (4): `agency_capable_of` (23K), `agency_used_for` (40K), `agency_receives_action` (6K), `agency_created_by` (263)

**Causation** (5): `causation_causes` (17K), `causation_has_subevent` (25K), `causation_has_prerequisite` (23K), `causation_has_first_subevent` (3.3K), `causation_has_last_subevent` (2.9K)

**Motivation** (3): `motivation_motivated_by_goal` (9.5K), `motivation_causes_desire` (4.7K), `motivation_desires` (3.2K)

**Context** (1): `context_has_context` (233K) — maps terms to domains like medicine, slang, computing (`_word`/`_pos` columns)

**Etymology** (3): `etymology_derived_from` (325K), `etymology_etymologically_related_to` (32K), `etymology_etymologically_derived_from` (71)

**Entity** (10): `entity_capital`, `entity_field`, `entity_genre`, `entity_genus`, `entity_influenced_by`, `entity_known_for`, `entity_language`, `entity_leader`, `entity_occupation`, `entity_product`

For column names, example values, weight distributions, surface text coverage, and querying tips, see the full **[Data Dictionary](DATADICTIONARY.md)**.

## Concepts

Concepts are stored with the `/c/en/` prefix stripped:

```
cat              ← bare word
cat/n            ← word + POS (noun)
cat/n/wn/pet     ← word + POS + WordNet sense
```

Multi-word concepts use underscores: `ice_cream`, `new_york`.

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
# → conceptnet.db (~800 MB, ~20 seconds)
```

Re-running `load.py` on an already-loaded database exits immediately.

### Querying

```bash
sqlite3 conceptnet.db
```

```sql
-- What is a cat?
SELECT type, weight FROM taxonomy_is_a
WHERE instance = 'cat/n'
ORDER BY weight DESC;
-- felis, non_person_animal

-- What can a bird do?
SELECT action, weight FROM agency_capable_of
WHERE agent LIKE 'bird%'
ORDER BY weight DESC;

-- Synonyms of "happy" (symmetric — check both sides)
SELECT term_b FROM similarity_synonym WHERE term_a LIKE 'happy%'
UNION
SELECT term_a FROM similarity_synonym WHERE term_b LIKE 'happy%';

-- What is a knife used for?
SELECT purpose, weight FROM agency_used_for
WHERE tool LIKE 'knife%'
ORDER BY weight DESC;

-- What causes fire?
SELECT cause, weight FROM causation_causes
WHERE effect LIKE 'fire%'
ORDER BY weight DESC;

-- Word/POS lookup: all senses of "bank"
SELECT instance, instance_word, instance_pos, type, type_word, weight
FROM taxonomy_is_a WHERE instance_word = 'bank'
ORDER BY weight DESC;
```

## Project Structure

```
ConceptFor/
├── README.md                  ← this file
├── DATADICTIONARY.md          ← full schema reference (all 42 tables)
├── english_export.sh          ← phase 1: filter CSV to English-only
├── schema.sql                 ← phase 2: SQLite schema (42 tables, 64 indexes)
├── load.py                    ← phase 3: CSV → SQLite loader
├── conceptnet.db              (~800 MB, not committed)
└── data/
    └── en-conceptnet-assertions-5.7.0.csv  (968 MB, not committed)
```

## Design Decisions

**One table per relationship** — Instead of a single edges table with a `relation` column, each of the 42 relationship types gets its own table. This means column names describe the semantic role: `taxonomy_is_a` has `instance` and `type`, `causation_causes` has `cause` and `effect`, `agency_capable_of` has `agent` and `action`. Queries read naturally and don't need joins or lookups.

**Category prefixes** — Table names are prefixed with their semantic category (`similarity_`, `taxonomy_`, `causation_`, etc.). This groups related tables together in schema browsers and makes `SELECT name FROM sqlite_master` self-documenting.

**Stripped concept values** — The `/c/en/` prefix is stripped at load time. Values like `cat/n` instead of `/c/en/cat/n` are shorter, easier to type in queries, and still preserve the full path (word, POS, sense).

**Word/POS columns** — Four tables (`taxonomy_is_a`, `taxonomy_form_of`, `taxonomy_manner_of`, `context_has_context`) add `_word` and `_pos` columns extracted from the concept path. This enables exact word lookups across all senses without LIKE patterns: `WHERE instance_word = 'bank'` instead of `WHERE instance LIKE 'bank%'`.

**No normalization** — Concept values are stored as text directly in every row. This trades some disk space for query simplicity: no concept-ID lookup tables, no joins for basic queries.

**Deferred indexing** — During the load, tables are created without indexes. All rows are inserted in a single transaction, then the 64 indexes are built afterward. This is roughly 3x faster than indexing during insertion.

**Idempotent loading** — `load.py` checks if data already exists and exits early. Uses `INSERT OR IGNORE` to handle duplicate concept pairs gracefully, making partial re-runs safe.
