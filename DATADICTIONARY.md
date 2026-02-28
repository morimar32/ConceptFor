# Data Dictionary — `conceptnet.db`

SQLite database derived from ConceptNet 5.7.0 (English-only subset).

- **Source CSV**: `data/en-conceptnet-assertions-5.7.0.csv` (3,423,004 rows, 968 MB)
- **Database size**: 808 MB
- **Tables**: 47 (one per relationship type)
- **Indexes**: 62
- **Total rows**: 3,423,004
- **Distinct concepts**: ~1,630,000 (across the five largest tables)

---

## Concept URI Format

Every concept is stored as a text string in the ConceptNet URI scheme:

```
/c/en/<word>[/<pos>[/<sense_source>/<sense_label>]]
```

| Segment | Description | Example |
|---------|-------------|---------|
| `/c/en/` | Fixed prefix (English) | — |
| `<word>` | Lemma, underscores for spaces | `cat`, `ice_cream`, `24_hour_clock` |
| `<pos>` | Optional part-of-speech tag | `n`, `v`, `a`, `r` |
| `<sense>` | Optional sense disambiguation | `wn/artifact`, `wp/decade`, `wikt/en_1` |

### POS tags

| Tag | Meaning | Prevalence (in `related_to`) |
|-----|---------|------------------------------|
| `n` | Noun | 1,091,152 (64%) |
| `a` | Adjective | 223,893 (13%) |
| `v` | Verb | 142,425 (8%) |
| `r` | Adverb | 27,917 (2%) |
| *(none)* | No POS specified | 218,195 (13%) |

### Sense disambiguation sources

When present, the sense suffix identifies which knowledge source disambiguated the concept:

| Source | Prefix | Example | Count (in `related_to`) |
|--------|--------|---------|-------------------------|
| Wiktionary | `wikt/` | `/c/en/accelerator/n/wikt/en_1` | 72,537 |
| Wikipedia | `wp/` | `/c/en/1900s/n/wp/decade` | 377 |
| WordNet | `wn/` | `/c/en/accelerator/n/wn/artifact` | 205 |
| *(none)* | — | `/c/en/cat/n` | 1,630,463 |

Most concepts (95.7%) have no sense suffix — just the word or word/POS.

### Multi-word encoding

Multi-word concepts use underscores: `/c/en/ice_cream`, `/c/en/24_hour_clock`. No concepts contain literal spaces.

---

## Common Columns

Every table shares this column structure:

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY | Auto-incrementing row ID |
| `uri` | TEXT NOT NULL UNIQUE | Assertion URI (see below) |
| *start role* | TEXT NOT NULL | Start concept (column name varies by table) |
| *end role* | TEXT NOT NULL | End concept (column name varies by table) |
| `weight` | REAL NOT NULL DEFAULT 1.0 | Confidence/strength score |
| `surface_text` | TEXT (nullable) | Natural language template with `[[brackets]]` |
| `surface_start` | TEXT (nullable) | Plain-text form of start concept |
| `surface_end` | TEXT (nullable) | Plain-text form of end concept |

### Assertion URI

Format: `/a/[/<relation>/,/<start>/,/<end>/]`

Example: `/a/[/r/IsA/,/c/en/cat/n/,/c/en/animal/]`

This is a unique identifier for each assertion. The `UNIQUE(uri)` constraint prevents duplicates.

### Weight

Confidence score derived from the number and reliability of contributing sources.

| Range | Meaning | Count | Pct |
|-------|---------|-------|-----|
| `< 0.5` | Low confidence (few/weak sources) | 132,055 | 4.0% |
| `0.5` | DBpedia default / single source | 85,095 | 2.6% |
| `0.5 < w < 1.0` | Moderate confidence | 14,430 | 0.4% |
| `1.0` | Standard (single reliable source) | 2,806,008 | 85.5% |
| `1.0 < w < 2.0` | Above average (multiple sources) | 7,823 | 0.2% |
| `2.0 – 4.99` | High confidence (many sources) | 232,823 | 7.1% |
| `5.0+` | Very high confidence | 1,965 | 0.1% |

Global range: **0.1 – 22.891**. The highest-weighted assertion is "baseball is a sport" (22.891 in `is_a`).

All DBpedia tables use a fixed weight of **0.5**.

### Surface Text

Natural language expression of the assertion, with `[[double brackets]]` marking the concept spans.

```
[[a trophy]] is a symbol of [[victory]]
[[bird]] is capable of [[fly]]
Sometimes [[acting in a play]] causes [[attention]]
```

`surface_start` and `surface_end` are the plain-text (un-bracketed) forms of the start and end concepts. When present, all three fields are always populated together.

**Coverage varies widely by table** — see each table's entry below.

---

## Tables by Category

### Symmetric Relations (7 tables)

Order of the two concepts is arbitrary — "A related to B" and "B related to A" are equivalent. Both concept columns are indexed for bidirectional lookup.

#### `related_to` — General topical association

| Column | Role | Example |
|--------|------|---------|
| `concept_a` | First concept | `/c/en/wool` |
| `concept_b` | Second concept | `/c/en/sheep` |

- **Rows**: 1,703,582 (49.8% of all data)
- **Distinct `concept_a`**: 554,837 | **Distinct `concept_b`**: 275,852 | **Union**: 806,310
- **Weight range**: 0.1 – 15.414
- **Surface text**: 157,513 rows (9.2%)
- **Top concepts by degree**: farm (525), dance (512), plate (504), squirrel (499), cake (482)
- **Highest weight**: wool→sheep (15.4), cake→birthday (15.2), bed→sleeping (14.6)
- **Indexes**: `idx_related_to_a`, `idx_related_to_b`

#### `synonym` — Synonymy ("means the same as")

| Column | Role | Example |
|--------|------|---------|
| `term_a` | First term | `/c/en/happy` |
| `term_b` | Second term | `/c/en/glad` |

- **Rows**: 222,156
- **Weight range**: 0.5 – 3.464
- **Surface text**: 88,524 rows (39.9%)
- **Indexes**: `idx_synonym_a`, `idx_synonym_b`

#### `antonym` — Antonymy ("is the opposite of")

| Column | Role | Example |
|--------|------|---------|
| `term` | Word | `/c/en/12_hour_clock/n` |
| `opposite` | Antonym | `/c/en/24_hour_clock` |

- **Rows**: 19,066
- **Weight range**: 0.5 – (not surveyed high end)
- **Surface text**: 5,385 rows (28.3%)
- **Indexes**: `idx_antonym_term`, `idx_antonym_opposite`

#### `distinct_from` — Same category but not the same

| Column | Role | Example |
|--------|------|---------|
| `concept_a` | First concept | `/c/en/cat` |
| `concept_b` | Second concept | `/c/en/dog` |

- **Rows**: 3,315
- **Surface text**: 2,277 rows (68.7%)
- **Indexes**: `idx_distinct_from_a`, `idx_distinct_from_b`

#### `located_near` — Typical spatial proximity

| Column | Role | Example |
|--------|------|---------|
| `entity_a` | First entity | `/c/en/chair` |
| `entity_b` | Second entity | `/c/en/table` |

- **Rows**: 49
- **Surface text**: 49 rows (100%)
- **Indexes**: `idx_located_near_a`, `idx_located_near_b`

#### `similar_to` — Resemblance (weaker than synonymy)

| Column | Role | Example |
|--------|------|---------|
| `concept_a` | First concept | `/c/en/happy` |
| `concept_b` | Second concept | `/c/en/cheerful` |

- **Rows**: 30,280
- **Surface text**: 21,244 rows (70.1%)
- **Indexes**: `idx_similar_to_a`, `idx_similar_to_b`

#### `etymologically_related_to` — Shared etymological origin

| Column | Role | Example |
|--------|------|---------|
| `word_a` | First word | `/c/en/aqua` |
| `word_b` | Second word | `/c/en/water` |

- **Rows**: 32,075
- **Surface text**: 0 rows (0%)
- **Indexes**: `idx_etymologically_related_to_a`, `idx_etymologically_related_to_b`

---

### Taxonomy & Classification (4 tables)

#### `is_a` — Hyponymy/taxonomy ("A is a B")

| Column | Role | Example |
|--------|------|---------|
| `instance` | Hyponym / instance | `/c/en/cat/n` |
| `type` | Hypernym / category | `/c/en/animal` |

- **Rows**: 230,137
- **Weight range**: 0.5 – 22.891 (highest in entire DB)
- **Surface text**: 97,079 rows (42.2%)
- **Highest weight**: baseball→sport (22.9), yo_yo→toy (19.4), polo→game (15.6)
- **POS breakdown**: 75.4% nouns, 24.4% no POS, <1% other
- **Indexes**: `idx_is_a_instance`, `idx_is_a_type`

#### `form_of` — Inflection/conjugation ("A is a form of B")

| Column | Role | Example |
|--------|------|---------|
| `inflection` | Inflected form | `/c/en/ran` |
| `root` | Lemma / root form | `/c/en/run/v` |

- **Rows**: 378,859
- **Weight range**: 1.0 – 4.899
- **Surface text**: 0 rows (0%) — purely lexical data from Wiktionary
- **Indexes**: `idx_form_of_inflection`, `idx_form_of_root`
- **Note**: Connects conjugated/declined forms to base words (e.g., ran→run, cats→cat)

#### `manner_of` — Verb-level hyponymy ("A is a specific way to B")

| Column | Role | Example |
|--------|------|---------|
| `specific` | Specific manner | `/c/en/sprint` |
| `general` | General action | `/c/en/run` |

- **Rows**: 12,715
- **Surface text**: 12,702 rows (99.9%)
- **Indexes**: `idx_manner_of_specific`, `idx_manner_of_general`

#### `defined_as` — Explanatory equivalence

| Column | Role | Example |
|--------|------|---------|
| `term` | Term being defined | `/c/en/0_degrees_celcius` |
| `definition` | Definition text | `/c/en/temperature_at_which_water_freezes` |

- **Rows**: 2,173
- **Surface text**: (not surveyed, likely high)
- **Index**: `idx_defined_as_term`

---

### Part-Whole & Composition (3 tables)

#### `part_of` — Meronymy ("A is part of B")

| Column | Role | Example |
|--------|------|---------|
| `part` | Component | `/c/en/wheel` |
| `whole` | Container / whole | `/c/en/car` |

- **Rows**: 13,077
- **Surface text**: 10,676 rows (81.6%)
- **Indexes**: `idx_part_of_part`, `idx_part_of_whole`

#### `has_a` — Possession/holonymy ("A has B")

| Column | Role | Example |
|--------|------|---------|
| `whole` | Possessor | `/c/en/car` |
| `possession` | Possessed thing | `/c/en/wheel` |

- **Rows**: 5,545
- **Surface text**: 5,545 rows (100%)
- **Indexes**: `idx_has_a_whole`, `idx_has_a_possession`
- **Note**: Inverse perspective of `part_of` — but the actual pairs differ

#### `made_of` — Material composition ("A is made of B")

| Column | Role | Example |
|--------|------|---------|
| `object` | Physical object | `/c/en/anchor` |
| `material` | Material | `/c/en/iron` |

- **Rows**: 545
- **Surface text**: 545 rows (100%)
- **Index**: `idx_made_of_object`

---

### Properties & Attributes (2 tables)

#### `has_property` — Descriptive attribute ("A has property B")

| Column | Role | Example |
|--------|------|---------|
| `entity` | Thing described | `/c/en/0_degress_farenheit` |
| `property` | Property / quality | `/c/en/very_cold` |

- **Rows**: 8,433
- **Weight range**: 1.0 – 9.798
- **Surface text**: 8,433 rows (100%)
- **Index**: `idx_has_property_entity`

#### `symbol_of` — Symbolic representation

| Column | Role | Example |
|--------|------|---------|
| `symbol` | Symbol | `/c/en/four_leaf_clover` |
| `meaning` | What it represents | `/c/en/luck` |

- **Rows**: 4 (smallest table)
- **Surface text**: 4 rows (100%)
- **All entries**: four_leaf_clover→luck, giving_rose→love, trophy→victory, tux→linux

---

### Spatial (1 table)

#### `at_location` — Typical location ("A is found at B")

| Column | Role | Example |
|--------|------|---------|
| `entity` | Thing | `/c/en/book` |
| `location` | Place | `/c/en/library` |

- **Rows**: 27,797
- **Weight range**: 0.5 – 11.489
- **Surface text**: 25,662 rows (92.3%)
- **Indexes**: `idx_at_location_entity`, `idx_at_location_location`

---

### Capabilities & Agency (3 tables)

#### `capable_of` — Typical ability ("A can B")

| Column | Role | Example |
|--------|------|---------|
| `agent` | Actor | `/c/en/bird` |
| `action` | Ability | `/c/en/fly` |

- **Rows**: 22,677
- **Weight range**: 1.0 – 16.0
- **Surface text**: 22,677 rows (100%)
- **Index**: `idx_capable_of_agent`

#### `receives_action` — Passivity ("A can have B done to it")

| Column | Role | Example |
|--------|------|---------|
| `patient` | Recipient | `/c/en/ball` |
| `action` | Action received | `/c/en/thrown` |

- **Rows**: 6,037
- **Surface text**: 6,037 rows (100%)
- **Index**: `idx_receives_action_patient`

#### `created_by` — Authorship/creation

| Column | Role | Example |
|--------|------|---------|
| `creation` | Created thing | `/c/en/art` |
| `creator` | Creator / process | `/c/en/artist` |

- **Rows**: 263
- **Surface text**: 263 rows (100%)

---

### Purpose & Function (1 table)

#### `used_for` — Functional purpose ("A is used for B")

| Column | Role | Example |
|--------|------|---------|
| `tool` | Instrument / thing | `/c/en/knife` |
| `purpose` | Function / use | `/c/en/cutting` |

- **Rows**: 39,790
- **Weight range**: 1.0 – 9.381
- **Surface text**: 39,790 rows (100%)
- **Indexes**: `idx_used_for_tool`, `idx_used_for_purpose`

---

### Causation & Events (5 tables)

#### `causes` — Causal relationship ("A causes B")

| Column | Role | Example |
|--------|------|---------|
| `cause` | Cause | `/c/en/fire` |
| `effect` | Effect | `/c/en/smoke` |

- **Rows**: 16,801
- **Weight range**: 1.0 – 12.961
- **Surface text**: 16,801 rows (100%)
- **Indexes**: `idx_causes_cause`, `idx_causes_effect`

#### `has_subevent` — Event decomposition ("A includes sub-event B")

| Column | Role | Example |
|--------|------|---------|
| `event` | Parent event | `/c/en/act_in_play` |
| `subevent` | Component event | `/c/en/dancing` |

- **Rows**: 25,238
- **Surface text**: 25,238 rows (100%)
- **Index**: `idx_has_subevent_event`

#### `has_first_subevent` — First step ("A begins with B")

| Column | Role | Example |
|--------|------|---------|
| `event` | Event | `/c/en/cook` |
| `first_subevent` | Opening step | `/c/en/get_ingredients` |

- **Rows**: 3,347
- **Surface text**: (survey pending)
- **Index**: `idx_has_first_subevent_event`

#### `has_last_subevent` — Last step ("A ends with B")

| Column | Role | Example |
|--------|------|---------|
| `event` | Event | `/c/en/bake_cake` |
| `last_subevent` | Final step | `/c/en/eat` |

- **Rows**: 2,874
- **Index**: `idx_has_last_subevent_event`

#### `has_prerequisite` — Precondition ("A requires B first")

| Column | Role | Example |
|--------|------|---------|
| `action` | Goal action | `/c/en/cook` |
| `prerequisite` | Required precondition | `/c/en/have_ingredients` |

- **Rows**: 22,710
- **Surface text**: 22,710 rows (100%)
- **Index**: `idx_has_prerequisite_action`

---

### Desires & Goals (3 tables)

#### `desires` — Agent desire ("A wants B")

| Column | Role | Example |
|--------|------|---------|
| `agent` | Sentient agent | `/c/en/dog` |
| `desire` | Desired thing | `/c/en/bone` |

- **Rows**: 3,170
- **Surface text**: 3,170 rows (100%)
- **Index**: `idx_desires_agent`

#### `causes_desire` — Stimulus creating desire ("A makes you want B")

| Column | Role | Example |
|--------|------|---------|
| `stimulus` | Triggering condition | `/c/en/hunger` |
| `desire` | Resulting desire | `/c/en/eat` |

- **Rows**: 4,688
- **Surface text**: 4,688 rows (100%)
- **Index**: `idx_causes_desire_stimulus`

#### `motivated_by_goal` — Goal-driven action ("you would A because you want B")

| Column | Role | Example |
|--------|------|---------|
| `action` | Motivated action | `/c/en/accomplish` |
| `goal` | Underlying goal | `/c/en/tried` |

- **Rows**: 9,489
- **Surface text**: 9,489 rows (100%)
- **Index**: `idx_motivated_by_goal_action`

---

### Lexical & Usage Context (1 table)

#### `has_context` — Domain/topic ("A is used in the context of B")

| Column | Role | Example |
|--------|------|---------|
| `term` | Word or phrase | `/c/en/scalpel` |
| `context` | Domain / register | `/c/en/medicine` |

- **Rows**: 232,935
- **Distinct contexts**: 7,387
- **Surface text**: 7,835 rows (3.4%)
- **Indexes**: `idx_has_context_term`, `idx_has_context_context`

**Top 15 context values:**

| Context | Count |
|---------|-------|
| `/c/en/slang` | 10,911 |
| `/c/en/us` | 7,568 |
| `/c/en/medicine` | 6,726 |
| `/c/en/zoology` | 6,649 |
| `/c/en/chemistry` | 6,174 |
| `/c/en/historical` | 5,927 |
| `/c/en/organic_compound` | 5,673 |
| `/c/en/uk` | 5,404 |
| `/c/en/anatomy` | 5,321 |
| `/c/en/computing` | 5,208 |
| `/c/en/organic_chemistry` | 5,124 |
| `/c/en/mineral` | 4,269 |
| `/c/en/physics` | 4,120 |
| `/c/en/biology` | 4,040 |
| `/c/en/botany` | 3,825 |

---

### Etymology (2 tables)

#### `etymologically_derived_from` — Directed etymology

| Column | Role | Example |
|--------|------|---------|
| `derived_word` | Derived word | `/c/en/aquatic` |
| `source_word` | Etymological source | `/c/en/aqua` |

- **Rows**: 71
- **Surface text**: 0 rows (0%)
- **Index**: `idx_etymologically_derived_from_der`

#### `derived_from` — Lexical derivation ("A is derived from B")

| Column | Role | Example |
|--------|------|---------|
| `derivative` | Derived word | `/c/en/happiness` |
| `origin` | Source word | `/c/en/happy` |

- **Rows**: 325,374
- **Weight range**: 1.0 – 2.828
- **Surface text**: 0 rows (0%) — purely lexical data
- **Indexes**: `idx_derived_from_derivative`, `idx_derived_from_origin`
- **Note**: Includes prefixation (unhappy←happy), suffixation (happiness←happy), compounding

---

### Deprecated Relations (5 tables)

These relations are retained for completeness but were deprecated in later ConceptNet versions.

#### `instance_of` — Deprecated (merged into `is_a`)

| Column | Role | Example |
|--------|------|---------|
| `instance` | Instance | `/c/en/16` |
| `class` | Class | `/c/en/siege_engine` |

- **Rows**: 1,480
- **Surface text**: 2 rows (0.1%)
- **Index**: `idx_instance_of_instance`

#### `entails` — Deprecated (replaced by `has_prerequisite`/`manner_of`)

| Column | Role | Example |
|--------|------|---------|
| `action` | Action | `/c/en/abort/v/wn/body` |
| `entailed_action` | Entailed action | `/c/en/conceive/v/wn/body` |

- **Rows**: 405
- **Surface text**: 405 rows (100%)
- **Index**: `idx_entails_action`
- **Note**: Exclusively uses WordNet-disambiguated concepts

#### `not_desires` — Deprecated (negative relation)

| Column | Role | Example |
|--------|------|---------|
| `agent` | Agent | `/c/en/actor` |
| `undesired` | Undesired thing | `/c/en/bad_review` |

- **Rows**: 2,886
- **Surface text**: 2,886 rows (100%)
- **Index**: `idx_not_desires_agent`

#### `not_capable_of` — Deprecated (negative relation)

| Column | Role | Example |
|--------|------|---------|
| `agent` | Agent | `/c/en/above_tree_line_trees` |
| `action` | Impossible action | `/c/en/grow` |

- **Rows**: 329
- **Surface text**: 329 rows (100%)
- **Index**: `idx_not_capable_of_agent`

#### `not_has_property` — Deprecated (negative relation)

| Column | Role | Example |
|--------|------|---------|
| `entity` | Entity | `/c/en/3_hole_punch` |
| `property` | Negated property | `/c/en/alive` |

- **Rows**: 327
- **Surface text**: 327 rows (100%)
- **Index**: `idx_not_has_property_entity`

---

### DBpedia Relations (10 tables)

Structured knowledge imported from DBpedia. All rows have a fixed weight of **0.5**. None have surface text. Concept URIs frequently include Wikipedia sense disambiguation (e.g., `/c/en/ada/n/wp/programming_language`).

#### `dbpedia_capital` — "A has capital B"

| Column | Role | Example |
|--------|------|---------|
| `entity` | Country / region | `/c/en/afghanistan` |
| `capital` | Capital city | `/c/en/kabul` |

- **Rows**: 459
- **Index**: `idx_dbpedia_capital_entity`

#### `dbpedia_field` — "A works in field B"

| Column | Role | Example |
|--------|------|---------|
| `person` | Person | `/c/en/alan_turing` |
| `field` | Academic field | `/c/en/computer_science` |

- **Rows**: 643
- **Index**: `idx_dbpedia_field_person`

#### `dbpedia_genre` — "A belongs to genre B"

| Column | Role | Example |
|--------|------|---------|
| `work` | Creative work / artist | `/c/en/213/n/wp/group` |
| `genre` | Genre | `/c/en/rapping` |

- **Rows**: 3,824
- **Index**: `idx_dbpedia_genre_work`

#### `dbpedia_genus` — Biological taxonomy ("A belongs to genus B")

| Column | Role | Example |
|--------|------|---------|
| `species` | Species | `/c/en/abies_alba` |
| `genus` | Genus | `/c/en/fir` |

- **Rows**: 2,937
- **Index**: `idx_dbpedia_genus_species`

#### `dbpedia_influenced_by` — "A was influenced by B"

| Column | Role | Example |
|--------|------|---------|
| `subject` | Influenced entity | `/c/en/adam_smith` |
| `influencer` | Influencer | `/c/en/aristotle` |

- **Rows**: 1,273
- **Index**: `idx_dbpedia_influenced_by_subject`

#### `dbpedia_known_for` — "A is known for B"

| Column | Role | Example |
|--------|------|---------|
| `person` | Person | `/c/en/alan_turing` |
| `achievement` | Achievement | `/c/en/turing_test` |

- **Rows**: 607
- **Index**: `idx_dbpedia_known_for_person`

#### `dbpedia_language` — "A uses language B"

| Column | Role | Example |
|--------|------|---------|
| `entity` | Entity / region | `/c/en/australia` |
| `language` | Language | `/c/en/english` |

- **Rows**: 916
- **Index**: `idx_dbpedia_language_entity`

#### `dbpedia_leader` — "A is led by B"

| Column | Role | Example |
|--------|------|---------|
| `entity` | Organization / nation | `/c/en/australia` |
| `leader` | Leader | `/c/en/elizabeth_ii` |

- **Rows**: 84
- **Index**: `idx_dbpedia_leader_entity`

#### `dbpedia_occupation` — "A has occupation B"

| Column | Role | Example |
|--------|------|---------|
| `person` | Person | `/c/en/agatha_christie` |
| `occupation` | Occupation | `/c/en/playwright` |

- **Rows**: 1,043
- **Index**: `idx_dbpedia_occupation_person`

#### `dbpedia_product` — "A produces product B"

| Column | Role | Example |
|--------|------|---------|
| `company` | Company | `/c/en/adidas` |
| `product` | Product | `/c/en/sports_equipment` |

- **Rows**: 519
- **Index**: `idx_dbpedia_product_company`

---

## Table Size Summary

| Rank | Table | Rows | % of Total | Category |
|------|-------|------|------------|----------|
| 1 | `related_to` | 1,703,582 | 49.8% | Symmetric |
| 2 | `form_of` | 378,859 | 11.1% | Taxonomy |
| 3 | `derived_from` | 325,374 | 9.5% | Etymology |
| 4 | `has_context` | 232,935 | 6.8% | Lexical |
| 5 | `is_a` | 230,137 | 6.7% | Taxonomy |
| 6 | `synonym` | 222,156 | 6.5% | Symmetric |
| 7 | `used_for` | 39,790 | 1.2% | Purpose |
| 8 | `etymologically_related_to` | 32,075 | 0.9% | Symmetric |
| 9 | `similar_to` | 30,280 | 0.9% | Symmetric |
| 10 | `at_location` | 27,797 | 0.8% | Spatial |
| 11 | `has_subevent` | 25,238 | 0.7% | Causation |
| 12 | `has_prerequisite` | 22,710 | 0.7% | Causation |
| 13 | `capable_of` | 22,677 | 0.7% | Capabilities |
| 14 | `antonym` | 19,066 | 0.6% | Symmetric |
| 15 | `causes` | 16,801 | 0.5% | Causation |
| 16 | `part_of` | 13,077 | 0.4% | Part-whole |
| 17 | `manner_of` | 12,715 | 0.4% | Taxonomy |
| 18 | `motivated_by_goal` | 9,489 | 0.3% | Desires |
| 19 | `has_property` | 8,433 | 0.2% | Properties |
| 20 | `receives_action` | 6,037 | 0.2% | Capabilities |
| 21 | `has_a` | 5,545 | 0.2% | Part-whole |
| 22 | `causes_desire` | 4,688 | 0.1% | Desires |
| 23 | `dbpedia_genre` | 3,824 | 0.1% | DBpedia |
| 24 | `has_first_subevent` | 3,347 | 0.1% | Causation |
| 25 | `distinct_from` | 3,315 | 0.1% | Symmetric |
| 26 | `desires` | 3,170 | 0.1% | Desires |
| 27 | `dbpedia_genus` | 2,937 | 0.1% | DBpedia |
| 28 | `not_desires` | 2,886 | 0.1% | Deprecated |
| 29 | `has_last_subevent` | 2,874 | 0.1% | Causation |
| 30 | `defined_as` | 2,173 | 0.1% | Taxonomy |
| 31 | `instance_of` | 1,480 | <0.1% | Deprecated |
| 32 | `dbpedia_influenced_by` | 1,273 | <0.1% | DBpedia |
| 33 | `dbpedia_occupation` | 1,043 | <0.1% | DBpedia |
| 34 | `dbpedia_language` | 916 | <0.1% | DBpedia |
| 35 | `dbpedia_field` | 643 | <0.1% | DBpedia |
| 36 | `dbpedia_known_for` | 607 | <0.1% | DBpedia |
| 37 | `made_of` | 545 | <0.1% | Part-whole |
| 38 | `dbpedia_product` | 519 | <0.1% | DBpedia |
| 39 | `dbpedia_capital` | 459 | <0.1% | DBpedia |
| 40 | `entails` | 405 | <0.1% | Deprecated |
| 41 | `not_capable_of` | 329 | <0.1% | Deprecated |
| 42 | `not_has_property` | 327 | <0.1% | Deprecated |
| 43 | `created_by` | 263 | <0.1% | Capabilities |
| 44 | `dbpedia_leader` | 84 | <0.1% | DBpedia |
| 45 | `etymologically_derived_from` | 71 | <0.1% | Etymology |
| 46 | `located_near` | 49 | <0.1% | Symmetric |
| 47 | `symbol_of` | 4 | <0.1% | Properties |

---

## Surface Text Coverage Summary

| Coverage | Tables |
|----------|--------|
| **100%** | `capable_of`, `causes`, `causes_desire`, `created_by`, `desires`, `entails`, `has_a`, `has_prerequisite`, `has_property`, `has_subevent`, `located_near`, `made_of`, `motivated_by_goal`, `not_capable_of`, `not_desires`, `not_has_property`, `receives_action`, `symbol_of`, `used_for` |
| **50–99%** | `distinct_from` (69%), `manner_of` (>99%), `similar_to` (70%), `at_location` (92%), `part_of` (82%) |
| **1–49%** | `is_a` (42%), `synonym` (40%), `antonym` (28%), `related_to` (9%), `has_context` (3%) |
| **0%** | `derived_from`, `form_of`, `etymologically_related_to`, `etymologically_derived_from`, all 10 `dbpedia_*` tables, `instance_of` (~0%) |

---

## Querying Tips

```sql
-- Find what a concept "is a"
SELECT type, weight FROM is_a WHERE instance = '/c/en/cat/n' ORDER BY weight DESC;

-- Find synonyms (check both sides for symmetric tables)
SELECT term_b FROM synonym WHERE term_a = '/c/en/happy'
UNION
SELECT term_a FROM synonym WHERE term_b = '/c/en/happy';

-- High-confidence assertions only
SELECT * FROM capable_of WHERE weight >= 2.0 ORDER BY weight DESC;

-- Strip POS for fuzzy matching
SELECT * FROM is_a WHERE instance LIKE '/c/en/cat%';

-- Cross-table exploration: everything about "dog"
SELECT 'is_a' as rel, type as related FROM is_a WHERE instance LIKE '/c/en/dog%'
UNION ALL
SELECT 'capable_of', action FROM capable_of WHERE agent LIKE '/c/en/dog%'
UNION ALL
SELECT 'has_property', property FROM has_property WHERE entity LIKE '/c/en/dog%'
UNION ALL
SELECT 'at_location', location FROM at_location WHERE entity LIKE '/c/en/dog%';
```
