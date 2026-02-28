# Data Dictionary — `conceptnet.db`

SQLite database derived from ConceptNet 5.7.0 (English-only subset).

- **Source CSV**: `data/en-conceptnet-assertions-5.7.0.csv` (3,423,004 rows, 968 MB)
- **Database size**: ~800 MB
- **Tables**: 42 (one per relationship type)
- **Indexes**: 64
- **Total rows loaded**: ~3,417,577
- **Distinct concepts**: ~1,630,000 (across the five largest tables)

---

## Concept Format

Every concept is stored as a text string with the `/c/en/` prefix stripped:

```
<word>[/<pos>[/<sense_source>/<sense_label>]]
```

| Segment | Description | Example |
|---------|-------------|---------|
| `<word>` | Lemma, underscores for spaces | `cat`, `ice_cream`, `24_hour_clock` |
| `<pos>` | Optional part-of-speech tag | `n`, `v`, `a`, `r` |
| `<sense>` | Optional sense disambiguation | `wn/artifact`, `wp/decade`, `wikt/en_1` |

### POS tags

| Tag | Meaning | Prevalence (in `similarity_related_to`) |
|-----|---------|------------------------------|
| `n` | Noun | 1,091,152 (64%) |
| `a` | Adjective | 223,893 (13%) |
| `v` | Verb | 142,425 (8%) |
| `r` | Adverb | 27,917 (2%) |
| *(none)* | No POS specified | 218,195 (13%) |

### Sense disambiguation sources

When present, the sense suffix identifies which knowledge source disambiguated the concept:

| Source | Prefix | Example | Count (in `similarity_related_to`) |
|--------|--------|---------|-------------------------|
| Wiktionary | `wikt/` | `accelerator/n/wikt/en_1` | 72,537 |
| Wikipedia | `wp/` | `1900s/n/wp/decade` | 377 |
| WordNet | `wn/` | `accelerator/n/wn/artifact` | 205 |
| *(none)* | — | `cat/n` | 1,630,463 |

Most concepts (95.7%) have no sense suffix — just the word or word/POS.

### Multi-word encoding

Multi-word concepts use underscores: `ice_cream`, `24_hour_clock`. No concepts contain literal spaces.

---

## Common Columns

Every table shares this column structure:

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY | Auto-incrementing row ID |
| *start role* | TEXT NOT NULL | Start concept (column name varies by table) |
| *end role* | TEXT NOT NULL | End concept (column name varies by table) |
| `weight` | REAL NOT NULL DEFAULT 1.0 | Confidence/strength score |
| `surface_text` | TEXT (nullable) | Natural language template with `[[brackets]]` |
| `surface_start` | TEXT (nullable) | Plain-text form of start concept |
| `surface_end` | TEXT (nullable) | Plain-text form of end concept |

Uniqueness is enforced by `UNIQUE(start_col, end_col)` on every table.

### Word & POS Columns

Four tables add extracted word and POS columns for polysemy-aware queries:

| Table | Word/POS columns |
|-------|-----------------|
| `taxonomy_is_a` | `instance_word`, `instance_pos`, `type_word`, `type_pos` |
| `taxonomy_form_of` | `inflection_word`, `inflection_pos`, `root_word`, `root_pos` |
| `taxonomy_manner_of` | `specific_word`, `specific_pos`, `general_word`, `general_pos` |
| `context_has_context` | `term_word`, `term_pos` |

- `*_word` (TEXT NOT NULL) — the bare word extracted from the concept path (first segment before `/`)
- `*_pos` (TEXT, nullable) — the POS tag if present (`n`, `v`, `a`, `r`), otherwise NULL

Example: concept `bank/n/wn/act` → `_word = 'bank'`, `_pos = 'n'`

These columns are indexed, enabling exact word lookups across all senses without LIKE patterns.

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

Global range: **0.1 – 22.891**. The highest-weighted assertion is "baseball is a sport" (22.891 in `taxonomy_is_a`).

All Entity tables use a fixed weight of **0.5**.

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

### Similarity (5 tables)

Bidirectional associations — order of the two concepts is arbitrary. Both concept columns are indexed.

#### `similarity_related_to` — General topical association

| Column | Role | Example |
|--------|------|---------|
| `concept_a` | First concept | `wool` |
| `concept_b` | Second concept | `sheep` |

- **Rows**: 1,703,582 (49.8% of all data)
- **Distinct `concept_a`**: 554,837 | **Distinct `concept_b`**: 275,852 | **Union**: 806,310
- **Weight range**: 0.1 – 15.414
- **Surface text**: 157,513 rows (9.2%)
- **Top concepts by degree**: farm (525), dance (512), plate (504), squirrel (499), cake (482)
- **Highest weight**: wool→sheep (15.4), cake→birthday (15.2), bed→sleeping (14.6)
- **Indexes**: `idx_similarity_related_to_concept_a`, `idx_similarity_related_to_concept_b`

#### `similarity_synonym` — Synonymy ("means the same as")

| Column | Role | Example |
|--------|------|---------|
| `term_a` | First term | `happy` |
| `term_b` | Second term | `glad` |

- **Rows**: 222,156
- **Weight range**: 0.5 – 3.464
- **Surface text**: 88,524 rows (39.9%)
- **Indexes**: `idx_similarity_synonym_term_a`, `idx_similarity_synonym_term_b`

#### `similarity_antonym` — Antonymy ("is the opposite of")

| Column | Role | Example |
|--------|------|---------|
| `term` | Word | `12_hour_clock/n` |
| `opposite` | Antonym | `24_hour_clock` |

- **Rows**: 19,066
- **Weight range**: 0.5 – (not surveyed high end)
- **Surface text**: 5,385 rows (28.3%)
- **Indexes**: `idx_similarity_antonym_term`, `idx_similarity_antonym_opposite`

#### `similarity_similar_to` — Resemblance (weaker than synonymy)

| Column | Role | Example |
|--------|------|---------|
| `concept_a` | First concept | `happy` |
| `concept_b` | Second concept | `cheerful` |

- **Rows**: 30,280
- **Surface text**: 21,244 rows (70.1%)
- **Indexes**: `idx_similarity_similar_to_concept_a`, `idx_similarity_similar_to_concept_b`

#### `similarity_distinct_from` — Same category but not the same

| Column | Role | Example |
|--------|------|---------|
| `concept_a` | First concept | `cat` |
| `concept_b` | Second concept | `dog` |

- **Rows**: 3,315
- **Surface text**: 2,277 rows (68.7%)
- **Indexes**: `idx_similarity_distinct_from_concept_a`, `idx_similarity_distinct_from_concept_b`

---

### Taxonomy (4 tables)

Three tables (`taxonomy_is_a`, `taxonomy_form_of`, `taxonomy_manner_of`) include `_word` and `_pos` columns for polysemy-aware queries.

#### `taxonomy_is_a` — Hyponymy/taxonomy ("A is a B")

| Column | Role | Example |
|--------|------|---------|
| `instance` | Hyponym / instance | `cat/n` |
| `instance_word` | Bare word | `cat` |
| `instance_pos` | POS tag | `n` |
| `type` | Hypernym / category | `animal` |
| `type_word` | Bare word | `animal` |
| `type_pos` | POS tag | NULL |

- **Rows**: 230,137
- **Weight range**: 0.5 – 22.891 (highest in entire DB)
- **Surface text**: 97,079 rows (42.2%)
- **Highest weight**: baseball→sport (22.9), yo_yo→toy (19.4), polo→game (15.6)
- **POS breakdown**: 75.4% nouns, 24.4% no POS, <1% other
- **Indexes**: `idx_taxonomy_is_a_instance`, `idx_taxonomy_is_a_type`, `idx_taxonomy_is_a_instance_word`, `idx_taxonomy_is_a_type_word`

#### `taxonomy_form_of` — Inflection/conjugation ("A is a form of B")

| Column | Role | Example |
|--------|------|---------|
| `inflection` | Inflected form | `ran` |
| `inflection_word` | Bare word | `ran` |
| `inflection_pos` | POS tag | NULL |
| `root` | Lemma / root form | `run/v` |
| `root_word` | Bare word | `run` |
| `root_pos` | POS tag | `v` |

- **Rows**: 378,859
- **Weight range**: 1.0 – 4.899
- **Surface text**: 0 rows (0%) — purely lexical data from Wiktionary
- **Indexes**: `idx_taxonomy_form_of_inflection`, `idx_taxonomy_form_of_root`, `idx_taxonomy_form_of_inflection_word`, `idx_taxonomy_form_of_root_word`
- **Note**: Connects conjugated/declined forms to base words (e.g., ran→run, cats→cat)

#### `taxonomy_manner_of` — Verb-level hyponymy ("A is a specific way to B")

| Column | Role | Example |
|--------|------|---------|
| `specific` | Specific manner | `sprint` |
| `specific_word` | Bare word | `sprint` |
| `specific_pos` | POS tag | NULL |
| `general` | General action | `run` |
| `general_word` | Bare word | `run` |
| `general_pos` | POS tag | NULL |

- **Rows**: 12,715
- **Surface text**: 12,702 rows (99.9%)
- **Indexes**: `idx_taxonomy_manner_of_specific`, `idx_taxonomy_manner_of_general`, `idx_taxonomy_manner_of_specific_word`, `idx_taxonomy_manner_of_general_word`

#### `taxonomy_defined_as` — Explanatory equivalence

| Column | Role | Example |
|--------|------|---------|
| `term` | Term being defined | `0_degrees_celcius` |
| `definition` | Definition text | `temperature_at_which_water_freezes` |

- **Rows**: 2,173
- **Surface text**: (not surveyed, likely high)
- **Index**: `idx_taxonomy_defined_as_term`

---

### Composition (3 tables)

#### `composition_part_of` — Meronymy ("A is part of B")

| Column | Role | Example |
|--------|------|---------|
| `part` | Component | `wheel` |
| `whole` | Container / whole | `car` |

- **Rows**: 13,077
- **Surface text**: 10,676 rows (81.6%)
- **Indexes**: `idx_composition_part_of_part`, `idx_composition_part_of_whole`

#### `composition_has_a` — Possession/holonymy ("A has B")

| Column | Role | Example |
|--------|------|---------|
| `whole` | Possessor | `car` |
| `possession` | Possessed thing | `wheel` |

- **Rows**: 5,545
- **Surface text**: 5,545 rows (100%)
- **Indexes**: `idx_composition_has_a_whole`, `idx_composition_has_a_possession`
- **Note**: Inverse perspective of `composition_part_of` — but the actual pairs differ

#### `composition_made_of` — Material composition ("A is made of B")

| Column | Role | Example |
|--------|------|---------|
| `object` | Physical object | `anchor` |
| `material` | Material | `iron` |

- **Rows**: 545
- **Surface text**: 545 rows (100%)
- **Index**: `idx_composition_made_of_object`

---

### Attribute (2 tables)

#### `attribute_has_property` — Descriptive attribute ("A has property B")

| Column | Role | Example |
|--------|------|---------|
| `entity` | Thing described | `0_degress_farenheit` |
| `property` | Property / quality | `very_cold` |

- **Rows**: 8,433
- **Weight range**: 1.0 – 9.798
- **Surface text**: 8,433 rows (100%)
- **Index**: `idx_attribute_has_property_entity`

#### `attribute_symbol_of` — Symbolic representation

| Column | Role | Example |
|--------|------|---------|
| `symbol` | Symbol | `four_leaf_clover` |
| `meaning` | What it represents | `luck` |

- **Rows**: 4 (smallest table)
- **Surface text**: 4 rows (100%)
- **All entries**: four_leaf_clover→luck, giving_rose→love, trophy→victory, tux→linux

---

### Spatial (2 tables)

#### `spatial_at_location` — Typical location ("A is found at B")

| Column | Role | Example |
|--------|------|---------|
| `entity` | Thing | `book` |
| `location` | Place | `library` |

- **Rows**: 27,797
- **Weight range**: 0.5 – 11.489
- **Surface text**: 25,662 rows (92.3%)
- **Indexes**: `idx_spatial_at_location_entity`, `idx_spatial_at_location_location`

#### `spatial_located_near` — Typical spatial proximity

| Column | Role | Example |
|--------|------|---------|
| `entity_a` | First entity | `chair` |
| `entity_b` | Second entity | `table` |

- **Rows**: 49
- **Surface text**: 49 rows (100%)
- **Indexes**: `idx_spatial_located_near_entity_a`, `idx_spatial_located_near_entity_b`

---

### Agency (4 tables)

#### `agency_capable_of` — Typical ability ("A can B")

| Column | Role | Example |
|--------|------|---------|
| `agent` | Actor | `bird` |
| `action` | Ability | `fly` |

- **Rows**: 22,677
- **Weight range**: 1.0 – 16.0
- **Surface text**: 22,677 rows (100%)
- **Index**: `idx_agency_capable_of_agent`

#### `agency_receives_action` — Passivity ("A can have B done to it")

| Column | Role | Example |
|--------|------|---------|
| `patient` | Recipient | `ball` |
| `action` | Action received | `thrown` |

- **Rows**: 6,037
- **Surface text**: 6,037 rows (100%)
- **Index**: `idx_agency_receives_action_patient`

#### `agency_created_by` — Authorship/creation

| Column | Role | Example |
|--------|------|---------|
| `creation` | Created thing | `art` |
| `creator` | Creator / process | `artist` |

- **Rows**: 263
- **Surface text**: 263 rows (100%)

#### `agency_used_for` — Functional purpose ("A is used for B")

| Column | Role | Example |
|--------|------|---------|
| `tool` | Instrument / thing | `knife` |
| `purpose` | Function / use | `cutting` |

- **Rows**: 39,790
- **Weight range**: 1.0 – 9.381
- **Surface text**: 39,790 rows (100%)
- **Indexes**: `idx_agency_used_for_tool`, `idx_agency_used_for_purpose`

---

### Causation (5 tables)

#### `causation_causes` — Causal relationship ("A causes B")

| Column | Role | Example |
|--------|------|---------|
| `cause` | Cause | `fire` |
| `effect` | Effect | `smoke` |

- **Rows**: 16,801
- **Weight range**: 1.0 – 12.961
- **Surface text**: 16,801 rows (100%)
- **Indexes**: `idx_causation_causes_cause`, `idx_causation_causes_effect`

#### `causation_has_subevent` — Event decomposition ("A includes sub-event B")

| Column | Role | Example |
|--------|------|---------|
| `event` | Parent event | `act_in_play` |
| `subevent` | Component event | `dancing` |

- **Rows**: 25,238
- **Surface text**: 25,238 rows (100%)
- **Index**: `idx_causation_has_subevent_event`

#### `causation_has_first_subevent` — First step ("A begins with B")

| Column | Role | Example |
|--------|------|---------|
| `event` | Event | `cook` |
| `first_subevent` | Opening step | `get_ingredients` |

- **Rows**: 3,347
- **Surface text**: (survey pending)
- **Index**: `idx_causation_has_first_subevent_event`

#### `causation_has_last_subevent` — Last step ("A ends with B")

| Column | Role | Example |
|--------|------|---------|
| `event` | Event | `bake_cake` |
| `last_subevent` | Final step | `eat` |

- **Rows**: 2,874
- **Index**: `idx_causation_has_last_subevent_event`

#### `causation_has_prerequisite` — Precondition ("A requires B first")

| Column | Role | Example |
|--------|------|---------|
| `action` | Goal action | `cook` |
| `prerequisite` | Required precondition | `have_ingredients` |

- **Rows**: 22,710
- **Surface text**: 22,710 rows (100%)
- **Index**: `idx_causation_has_prerequisite_action`

---

### Motivation (3 tables)

#### `motivation_desires` — Agent desire ("A wants B")

| Column | Role | Example |
|--------|------|---------|
| `agent` | Sentient agent | `dog` |
| `desire` | Desired thing | `bone` |

- **Rows**: 3,170
- **Surface text**: 3,170 rows (100%)
- **Index**: `idx_motivation_desires_agent`

#### `motivation_causes_desire` — Stimulus creating desire ("A makes you want B")

| Column | Role | Example |
|--------|------|---------|
| `stimulus` | Triggering condition | `hunger` |
| `desire` | Resulting desire | `eat` |

- **Rows**: 4,688
- **Surface text**: 4,688 rows (100%)
- **Index**: `idx_motivation_causes_desire_stimulus`

#### `motivation_motivated_by_goal` — Goal-driven action ("you would A because you want B")

| Column | Role | Example |
|--------|------|---------|
| `action` | Motivated action | `accomplish` |
| `goal` | Underlying goal | `tried` |

- **Rows**: 9,489
- **Surface text**: 9,489 rows (100%)
- **Index**: `idx_motivation_motivated_by_goal_action`

---

### Context (1 table)

Includes `_word` and `_pos` columns on the term side (context values are domain labels, not words with POS).

#### `context_has_context` — Domain/topic ("A is used in the context of B")

| Column | Role | Example |
|--------|------|---------|
| `term` | Word or phrase | `scalpel` |
| `term_word` | Bare word | `scalpel` |
| `term_pos` | POS tag | NULL |
| `context` | Domain / register | `medicine` |

- **Rows**: 232,935
- **Distinct contexts**: 7,387
- **Surface text**: 7,835 rows (3.4%)
- **Indexes**: `idx_context_has_context_term`, `idx_context_has_context_context`, `idx_context_has_context_term_word`

**Top 15 context values:**

| Context | Count |
|---------|-------|
| `slang` | 10,911 |
| `us` | 7,568 |
| `medicine` | 6,726 |
| `zoology` | 6,649 |
| `chemistry` | 6,174 |
| `historical` | 5,927 |
| `organic_compound` | 5,673 |
| `uk` | 5,404 |
| `anatomy` | 5,321 |
| `computing` | 5,208 |
| `organic_chemistry` | 5,124 |
| `mineral` | 4,269 |
| `physics` | 4,120 |
| `biology` | 4,040 |
| `botany` | 3,825 |

---

### Etymology (3 tables)

#### `etymology_derived_from` — Lexical derivation ("A is derived from B")

| Column | Role | Example |
|--------|------|---------|
| `derivative` | Derived word | `happiness` |
| `origin` | Source word | `happy` |

- **Rows**: 325,374
- **Weight range**: 1.0 – 2.828
- **Surface text**: 0 rows (0%) — purely lexical data
- **Indexes**: `idx_etymology_derived_from_derivative`, `idx_etymology_derived_from_origin`
- **Note**: Includes prefixation (unhappy←happy), suffixation (happiness←happy), compounding

#### `etymology_etymologically_derived_from` — Directed etymology

| Column | Role | Example |
|--------|------|---------|
| `derived_word` | Derived word | `aquatic` |
| `source_word` | Etymological source | `aqua` |

- **Rows**: 71
- **Surface text**: 0 rows (0%)
- **Index**: `idx_etymology_etymologically_derived_from_derived_word`

#### `etymology_etymologically_related_to` — Shared etymological origin

| Column | Role | Example |
|--------|------|---------|
| `word_a` | First word | `aqua` |
| `word_b` | Second word | `water` |

- **Rows**: 32,075
- **Surface text**: 0 rows (0%)
- **Indexes**: `idx_etymology_etymologically_related_to_word_a`, `idx_etymology_etymologically_related_to_word_b`

---

### Entity Relations (10 tables)

Structured knowledge imported from DBpedia. All rows have a fixed weight of **0.5**. None have surface text. Concept values frequently include Wikipedia sense disambiguation (e.g., `ada/n/wp/programming_language`).

#### `entity_capital` — "A has capital B"

| Column | Role | Example |
|--------|------|---------|
| `entity` | Country / region | `afghanistan` |
| `capital` | Capital city | `kabul` |

- **Rows**: 459
- **Index**: `idx_entity_capital_entity`

#### `entity_field` — "A works in field B"

| Column | Role | Example |
|--------|------|---------|
| `person` | Person | `alan_turing` |
| `field` | Academic field | `computer_science` |

- **Rows**: 643
- **Index**: `idx_entity_field_person`

#### `entity_genre` — "A belongs to genre B"

| Column | Role | Example |
|--------|------|---------|
| `work` | Creative work / artist | `213/n/wp/group` |
| `genre` | Genre | `rapping` |

- **Rows**: 3,824
- **Index**: `idx_entity_genre_work`

#### `entity_genus` — Biological taxonomy ("A belongs to genus B")

| Column | Role | Example |
|--------|------|---------|
| `species` | Species | `abies_alba` |
| `genus` | Genus | `fir` |

- **Rows**: 2,937
- **Index**: `idx_entity_genus_species`

#### `entity_influenced_by` — "A was influenced by B"

| Column | Role | Example |
|--------|------|---------|
| `subject` | Influenced entity | `adam_smith` |
| `influencer` | Influencer | `aristotle` |

- **Rows**: 1,273
- **Index**: `idx_entity_influenced_by_subject`

#### `entity_known_for` — "A is known for B"

| Column | Role | Example |
|--------|------|---------|
| `person` | Person | `alan_turing` |
| `achievement` | Achievement | `turing_test` |

- **Rows**: 607
- **Index**: `idx_entity_known_for_person`

#### `entity_language` — "A uses language B"

| Column | Role | Example |
|--------|------|---------|
| `entity` | Entity / region | `australia` |
| `language` | Language | `english` |

- **Rows**: 916
- **Index**: `idx_entity_language_entity`

#### `entity_leader` — "A is led by B"

| Column | Role | Example |
|--------|------|---------|
| `entity` | Organization / nation | `australia` |
| `leader` | Leader | `elizabeth_ii` |

- **Rows**: 84
- **Index**: `idx_entity_leader_entity`

#### `entity_occupation` — "A has occupation B"

| Column | Role | Example |
|--------|------|---------|
| `person` | Person | `agatha_christie` |
| `occupation` | Occupation | `playwright` |

- **Rows**: 1,043
- **Index**: `idx_entity_occupation_person`

#### `entity_product` — "A produces product B"

| Column | Role | Example |
|--------|------|---------|
| `company` | Company | `adidas` |
| `product` | Product | `sports_equipment` |

- **Rows**: 519
- **Index**: `idx_entity_product_company`

---

## Table Size Summary

| Rank | Table | Rows | % of Total | Category |
|------|-------|------|------------|----------|
| 1 | `similarity_related_to` | 1,703,582 | 49.8% | Similarity |
| 2 | `taxonomy_form_of` | 378,859 | 11.1% | Taxonomy |
| 3 | `etymology_derived_from` | 325,374 | 9.5% | Etymology |
| 4 | `context_has_context` | 232,935 | 6.8% | Context |
| 5 | `taxonomy_is_a` | 230,137 | 6.7% | Taxonomy |
| 6 | `similarity_synonym` | 222,156 | 6.5% | Similarity |
| 7 | `agency_used_for` | 39,790 | 1.2% | Agency |
| 8 | `etymology_etymologically_related_to` | 32,075 | 0.9% | Etymology |
| 9 | `similarity_similar_to` | 30,280 | 0.9% | Similarity |
| 10 | `spatial_at_location` | 27,797 | 0.8% | Spatial |
| 11 | `causation_has_subevent` | 25,238 | 0.7% | Causation |
| 12 | `causation_has_prerequisite` | 22,710 | 0.7% | Causation |
| 13 | `agency_capable_of` | 22,677 | 0.7% | Agency |
| 14 | `similarity_antonym` | 19,066 | 0.6% | Similarity |
| 15 | `causation_causes` | 16,801 | 0.5% | Causation |
| 16 | `composition_part_of` | 13,077 | 0.4% | Composition |
| 17 | `taxonomy_manner_of` | 12,715 | 0.4% | Taxonomy |
| 18 | `motivation_motivated_by_goal` | 9,489 | 0.3% | Motivation |
| 19 | `attribute_has_property` | 8,433 | 0.2% | Attribute |
| 20 | `agency_receives_action` | 6,037 | 0.2% | Agency |
| 21 | `composition_has_a` | 5,545 | 0.2% | Composition |
| 22 | `motivation_causes_desire` | 4,688 | 0.1% | Motivation |
| 23 | `entity_genre` | 3,824 | 0.1% | Entity |
| 24 | `causation_has_first_subevent` | 3,347 | 0.1% | Causation |
| 25 | `similarity_distinct_from` | 3,315 | 0.1% | Similarity |
| 26 | `motivation_desires` | 3,170 | 0.1% | Motivation |
| 27 | `entity_genus` | 2,937 | 0.1% | Entity |
| 28 | `causation_has_last_subevent` | 2,874 | 0.1% | Causation |
| 29 | `taxonomy_defined_as` | 2,173 | 0.1% | Taxonomy |
| 30 | `entity_influenced_by` | 1,273 | <0.1% | Entity |
| 31 | `entity_occupation` | 1,043 | <0.1% | Entity |
| 32 | `entity_language` | 916 | <0.1% | Entity |
| 33 | `entity_field` | 643 | <0.1% | Entity |
| 34 | `entity_known_for` | 607 | <0.1% | Entity |
| 35 | `composition_made_of` | 545 | <0.1% | Composition |
| 36 | `entity_product` | 519 | <0.1% | Entity |
| 37 | `entity_capital` | 459 | <0.1% | Entity |
| 38 | `agency_created_by` | 263 | <0.1% | Agency |
| 39 | `entity_leader` | 84 | <0.1% | Entity |
| 40 | `etymology_etymologically_derived_from` | 71 | <0.1% | Etymology |
| 41 | `spatial_located_near` | 49 | <0.1% | Spatial |
| 42 | `attribute_symbol_of` | 4 | <0.1% | Attribute |

---

## Surface Text Coverage Summary

| Coverage | Tables |
|----------|--------|
| **100%** | `agency_capable_of`, `causation_causes`, `motivation_causes_desire`, `agency_created_by`, `motivation_desires`, `composition_has_a`, `causation_has_prerequisite`, `attribute_has_property`, `causation_has_subevent`, `spatial_located_near`, `composition_made_of`, `motivation_motivated_by_goal`, `agency_receives_action`, `attribute_symbol_of`, `agency_used_for` |
| **50–99%** | `similarity_distinct_from` (69%), `taxonomy_manner_of` (>99%), `similarity_similar_to` (70%), `spatial_at_location` (92%), `composition_part_of` (82%) |
| **1–49%** | `taxonomy_is_a` (42%), `similarity_synonym` (40%), `similarity_antonym` (28%), `similarity_related_to` (9%), `context_has_context` (3%) |
| **0%** | `etymology_derived_from`, `taxonomy_form_of`, `etymology_etymologically_related_to`, `etymology_etymologically_derived_from`, all 10 `entity_*` tables |

---

## Querying Tips

```sql
-- Find what a concept "is a"
SELECT type, weight FROM taxonomy_is_a WHERE instance = 'cat/n' ORDER BY weight DESC;

-- Find synonyms (check both sides for symmetric tables)
SELECT term_b FROM similarity_synonym WHERE term_a = 'happy'
UNION
SELECT term_a FROM similarity_synonym WHERE term_b = 'happy';

-- High-confidence assertions only
SELECT * FROM agency_capable_of WHERE weight >= 2.0 ORDER BY weight DESC;

-- Strip POS for fuzzy matching
SELECT * FROM taxonomy_is_a WHERE instance LIKE 'cat%';

-- Word/POS lookup: all senses of "bank" (no LIKE needed)
SELECT instance, instance_word, instance_pos, type, type_word, weight
FROM taxonomy_is_a WHERE instance_word = 'bank'
ORDER BY weight DESC;

-- Cross-table exploration: everything about "dog"
SELECT 'is_a' as rel, type as related FROM taxonomy_is_a WHERE instance LIKE 'dog%'
UNION ALL
SELECT 'capable_of', action FROM agency_capable_of WHERE agent LIKE 'dog%'
UNION ALL
SELECT 'has_property', property FROM attribute_has_property WHERE entity LIKE 'dog%'
UNION ALL
SELECT 'at_location', location FROM spatial_at_location WHERE entity LIKE 'dog%';
```
