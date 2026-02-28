-- schema.sql — SQLite3 schema for English-only ConceptNet 5.7.0
-- Input: en-conceptnet-assertions-5.7.0.csv (3,423,004 rows)
--
-- Design: one table per relationship type (47 tables), with columns
-- named for the semantic roles of each concept in that relationship.
-- Concept values are stored as text strings (the /c/en/... URIs)
-- directly — no join tables needed for querying.

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

------------------------------------------------------------------------
-- Relationship tables — one table per relationship type (47 total)
--
-- Each table stores the assertions for one relationship type.
-- Column names reflect the semantic role of start/end concepts.
-- Common columns on every table:
--   id, uri, <start_role>, <end_role>,
--   weight, surface_text, surface_start, surface_end
------------------------------------------------------------------------

-- ======================================================================
-- Symmetric relations (7): order of concepts is arbitrary
-- ======================================================================

-- "A is related to B" — general topical association (1.7M rows)
CREATE TABLE IF NOT EXISTS related_to (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    concept_a     TEXT    NOT NULL,
    concept_b     TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A means the same as B" — synonymy (222K rows)
CREATE TABLE IF NOT EXISTS synonym (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    term_a        TEXT    NOT NULL,
    term_b        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A is the opposite of B" — antonymy (19K rows)
CREATE TABLE IF NOT EXISTS antonym (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    term          TEXT    NOT NULL,
    opposite      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A is distinct from B" — same category but not the same (3.3K rows)
CREATE TABLE IF NOT EXISTS distinct_from (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    concept_a     TEXT    NOT NULL,
    concept_b     TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A is near B" — typical spatial proximity (49 rows)
CREATE TABLE IF NOT EXISTS located_near (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    entity_a      TEXT    NOT NULL,
    entity_b      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A is similar to B" — resemblance weaker than synonymy (30K rows)
CREATE TABLE IF NOT EXISTS similar_to (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    concept_a     TEXT    NOT NULL,
    concept_b     TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A and B share an etymological origin" (32K rows)
CREATE TABLE IF NOT EXISTS etymologically_related_to (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    word_a        TEXT    NOT NULL,
    word_b        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- ======================================================================
-- Taxonomy & classification
-- ======================================================================

-- "A is a B" — hyponymy / taxonomy (230K rows)
-- e.g. "cat is a animal"
CREATE TABLE IF NOT EXISTS is_a (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    instance      TEXT    NOT NULL,
    type          TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A is a form of B" — inflection/conjugation (379K rows)
-- e.g. "running is a form of run"
CREATE TABLE IF NOT EXISTS form_of (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    inflection    TEXT    NOT NULL,
    root          TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A is a specific way to B" — verb-level hyponymy (13K rows)
-- e.g. "sprint is a manner of run"
CREATE TABLE IF NOT EXISTS manner_of (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    specific      TEXT    NOT NULL,
    general       TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A is defined as B" — explanatory equivalence (2.2K rows)
CREATE TABLE IF NOT EXISTS defined_as (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    term          TEXT    NOT NULL,
    definition    TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- ======================================================================
-- Part-whole & composition
-- ======================================================================

-- "A is part of B" — meronymy (13K rows)
-- e.g. "wheel is part of car"
CREATE TABLE IF NOT EXISTS part_of (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    part          TEXT    NOT NULL,
    whole         TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A has B" — possession / holonymy (5.5K rows)
-- e.g. "car has wheels"
CREATE TABLE IF NOT EXISTS has_a (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    whole         TEXT    NOT NULL,
    possession    TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A is made of B" — material composition (545 rows)
-- e.g. "table is made of wood"
CREATE TABLE IF NOT EXISTS made_of (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    object        TEXT    NOT NULL,
    material      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- ======================================================================
-- Properties & attributes
-- ======================================================================

-- "A has property B" — descriptive attribute (8.4K rows)
-- e.g. "ice has property cold"
CREATE TABLE IF NOT EXISTS has_property (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    entity        TEXT    NOT NULL,
    property      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A symbolizes B" — symbolic representation (4 rows)
-- e.g. "dove symbolizes peace"
CREATE TABLE IF NOT EXISTS symbol_of (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    symbol        TEXT    NOT NULL,
    meaning       TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- ======================================================================
-- Spatial
-- ======================================================================

-- "A is typically found at B" — typical location (28K rows)
-- e.g. "book is at location library"
CREATE TABLE IF NOT EXISTS at_location (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    entity        TEXT    NOT NULL,
    location      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- ======================================================================
-- Capabilities & agency
-- ======================================================================

-- "A is capable of B" — typical ability (23K rows)
-- e.g. "bird is capable of fly"
CREATE TABLE IF NOT EXISTS capable_of (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    agent         TEXT    NOT NULL,
    action        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A can have B done to it" — passivity (6K rows)
-- e.g. "ball receives action thrown"
CREATE TABLE IF NOT EXISTS receives_action (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    patient       TEXT    NOT NULL,
    action        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A is created by B" — authorship/creation (263 rows)
CREATE TABLE IF NOT EXISTS created_by (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    creation      TEXT    NOT NULL,
    creator       TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- ======================================================================
-- Purpose & function
-- ======================================================================

-- "A is used for B" — functional purpose (40K rows)
-- e.g. "knife is used for cutting"
CREATE TABLE IF NOT EXISTS used_for (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    tool          TEXT    NOT NULL,
    purpose       TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- ======================================================================
-- Causation & events
-- ======================================================================

-- "A causes B" — causal relationship (17K rows)
-- e.g. "fire causes smoke"
CREATE TABLE IF NOT EXISTS causes (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    cause         TEXT    NOT NULL,
    effect        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A includes sub-event B" — event decomposition (25K rows)
CREATE TABLE IF NOT EXISTS has_subevent (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    event         TEXT    NOT NULL,
    subevent      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A begins with B" — first step (3.3K rows)
CREATE TABLE IF NOT EXISTS has_first_subevent (
    id              INTEGER PRIMARY KEY,
    uri             TEXT    NOT NULL UNIQUE,
    event           TEXT    NOT NULL,
    first_subevent  TEXT    NOT NULL,
    weight          REAL    NOT NULL DEFAULT 1.0,
    surface_text    TEXT,
    surface_start   TEXT,
    surface_end     TEXT
);

-- "A ends with B" — last step (2.9K rows)
CREATE TABLE IF NOT EXISTS has_last_subevent (
    id              INTEGER PRIMARY KEY,
    uri             TEXT    NOT NULL UNIQUE,
    event           TEXT    NOT NULL,
    last_subevent   TEXT    NOT NULL,
    weight          REAL    NOT NULL DEFAULT 1.0,
    surface_text    TEXT,
    surface_start   TEXT,
    surface_end     TEXT
);

-- "A requires B first" — precondition (23K rows)
-- e.g. "cook requires have ingredients"
CREATE TABLE IF NOT EXISTS has_prerequisite (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    action        TEXT    NOT NULL,
    prerequisite  TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- ======================================================================
-- Desires & goals
-- ======================================================================

-- "A wants B" — desire of a sentient agent (3.2K rows)
-- e.g. "dog desires bone"
CREATE TABLE IF NOT EXISTS desires (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    agent         TEXT    NOT NULL,
    desire        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A makes you want B" — stimulus creating desire (4.7K rows)
-- e.g. "hunger causes desire eat"
CREATE TABLE IF NOT EXISTS causes_desire (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    stimulus      TEXT    NOT NULL,
    desire        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "You would A because you want B" — goal-driven action (9.5K rows)
CREATE TABLE IF NOT EXISTS motivated_by_goal (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    action        TEXT    NOT NULL,
    goal          TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- ======================================================================
-- Lexical & usage context
-- ======================================================================

-- "A is used in the context of B" — domain/topic (233K rows)
-- e.g. "scalpel has context medicine"
CREATE TABLE IF NOT EXISTS has_context (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    term          TEXT    NOT NULL,
    context       TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- ======================================================================
-- Etymology
-- ======================================================================

-- "A is etymologically derived from B" — directed etymology (71 rows)
CREATE TABLE IF NOT EXISTS etymologically_derived_from (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    derived_word  TEXT    NOT NULL,
    source_word   TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A is derived from B" — lexical derivation (325K rows)
-- e.g. "unhappy is derived from happy"
CREATE TABLE IF NOT EXISTS derived_from (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    derivative    TEXT    NOT NULL,
    origin        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- ======================================================================
-- Deprecated relations (kept for completeness of source data)
-- ======================================================================

-- DEPRECATED: merged into is_a (1.5K rows)
CREATE TABLE IF NOT EXISTS instance_of (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    instance      TEXT    NOT NULL,
    class         TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- DEPRECATED: replaced by has_prerequisite or manner_of (405 rows)
CREATE TABLE IF NOT EXISTS entails (
    id              INTEGER PRIMARY KEY,
    uri             TEXT    NOT NULL UNIQUE,
    action          TEXT    NOT NULL,
    entailed_action TEXT    NOT NULL,
    weight          REAL    NOT NULL DEFAULT 1.0,
    surface_text    TEXT,
    surface_start   TEXT,
    surface_end     TEXT
);

-- DEPRECATED: negative relation (2.9K rows)
CREATE TABLE IF NOT EXISTS not_desires (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    agent         TEXT    NOT NULL,
    undesired     TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- DEPRECATED: negative relation (329 rows)
CREATE TABLE IF NOT EXISTS not_capable_of (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    agent         TEXT    NOT NULL,
    action        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- DEPRECATED: negative relation (327 rows)
CREATE TABLE IF NOT EXISTS not_has_property (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    entity        TEXT    NOT NULL,
    property      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- ======================================================================
-- DBpedia relations (10): structured knowledge from DBpedia
-- ======================================================================

-- "A has capital B" (459 rows)
CREATE TABLE IF NOT EXISTS dbpedia_capital (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    entity        TEXT    NOT NULL,
    capital       TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A works in field B" (643 rows)
CREATE TABLE IF NOT EXISTS dbpedia_field (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    person        TEXT    NOT NULL,
    field         TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A belongs to genre B" (3.8K rows)
CREATE TABLE IF NOT EXISTS dbpedia_genre (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    work          TEXT    NOT NULL,
    genre         TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A belongs to genus B" — biological taxonomy (2.9K rows)
CREATE TABLE IF NOT EXISTS dbpedia_genus (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    species       TEXT    NOT NULL,
    genus         TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A was influenced by B" (1.3K rows)
CREATE TABLE IF NOT EXISTS dbpedia_influenced_by (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    subject       TEXT    NOT NULL,
    influencer    TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A is known for B" (607 rows)
CREATE TABLE IF NOT EXISTS dbpedia_known_for (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    person        TEXT    NOT NULL,
    achievement   TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A uses language B" (916 rows)
CREATE TABLE IF NOT EXISTS dbpedia_language (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    entity        TEXT    NOT NULL,
    language      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A is led by B" (84 rows)
CREATE TABLE IF NOT EXISTS dbpedia_leader (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    entity        TEXT    NOT NULL,
    leader        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A has occupation B" (1K rows)
CREATE TABLE IF NOT EXISTS dbpedia_occupation (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    person        TEXT    NOT NULL,
    occupation    TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

-- "A produces product B" (519 rows)
CREATE TABLE IF NOT EXISTS dbpedia_product (
    id            INTEGER PRIMARY KEY,
    uri           TEXT    NOT NULL UNIQUE,
    company       TEXT    NOT NULL,
    product       TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT
);

------------------------------------------------------------------------
-- Indexes
------------------------------------------------------------------------

-- Symmetric relations: index both sides for bidirectional traversal
CREATE INDEX IF NOT EXISTS idx_related_to_a                    ON related_to(concept_a);
CREATE INDEX IF NOT EXISTS idx_related_to_b                    ON related_to(concept_b);
CREATE INDEX IF NOT EXISTS idx_synonym_a                       ON synonym(term_a);
CREATE INDEX IF NOT EXISTS idx_synonym_b                       ON synonym(term_b);
CREATE INDEX IF NOT EXISTS idx_antonym_term                    ON antonym(term);
CREATE INDEX IF NOT EXISTS idx_antonym_opposite                ON antonym(opposite);
CREATE INDEX IF NOT EXISTS idx_distinct_from_a                 ON distinct_from(concept_a);
CREATE INDEX IF NOT EXISTS idx_distinct_from_b                 ON distinct_from(concept_b);
CREATE INDEX IF NOT EXISTS idx_located_near_a                  ON located_near(entity_a);
CREATE INDEX IF NOT EXISTS idx_located_near_b                  ON located_near(entity_b);
CREATE INDEX IF NOT EXISTS idx_similar_to_a                    ON similar_to(concept_a);
CREATE INDEX IF NOT EXISTS idx_similar_to_b                    ON similar_to(concept_b);
CREATE INDEX IF NOT EXISTS idx_etymologically_related_to_a     ON etymologically_related_to(word_a);
CREATE INDEX IF NOT EXISTS idx_etymologically_related_to_b     ON etymologically_related_to(word_b);

-- Taxonomy & classification
CREATE INDEX IF NOT EXISTS idx_is_a_instance                   ON is_a(instance);
CREATE INDEX IF NOT EXISTS idx_is_a_type                       ON is_a(type);
CREATE INDEX IF NOT EXISTS idx_form_of_inflection              ON form_of(inflection);
CREATE INDEX IF NOT EXISTS idx_form_of_root                    ON form_of(root);
CREATE INDEX IF NOT EXISTS idx_manner_of_specific              ON manner_of(specific);
CREATE INDEX IF NOT EXISTS idx_manner_of_general               ON manner_of(general);
CREATE INDEX IF NOT EXISTS idx_defined_as_term                 ON defined_as(term);

-- Part-whole & composition
CREATE INDEX IF NOT EXISTS idx_part_of_part                    ON part_of(part);
CREATE INDEX IF NOT EXISTS idx_part_of_whole                   ON part_of(whole);
CREATE INDEX IF NOT EXISTS idx_has_a_whole                     ON has_a(whole);
CREATE INDEX IF NOT EXISTS idx_has_a_possession                ON has_a(possession);
CREATE INDEX IF NOT EXISTS idx_made_of_object                  ON made_of(object);

-- Properties
CREATE INDEX IF NOT EXISTS idx_has_property_entity             ON has_property(entity);

-- Spatial
CREATE INDEX IF NOT EXISTS idx_at_location_entity              ON at_location(entity);
CREATE INDEX IF NOT EXISTS idx_at_location_location            ON at_location(location);

-- Capabilities & agency
CREATE INDEX IF NOT EXISTS idx_capable_of_agent                ON capable_of(agent);
CREATE INDEX IF NOT EXISTS idx_receives_action_patient         ON receives_action(patient);

-- Purpose
CREATE INDEX IF NOT EXISTS idx_used_for_tool                   ON used_for(tool);
CREATE INDEX IF NOT EXISTS idx_used_for_purpose                ON used_for(purpose);

-- Causation & events
CREATE INDEX IF NOT EXISTS idx_causes_cause                    ON causes(cause);
CREATE INDEX IF NOT EXISTS idx_causes_effect                   ON causes(effect);
CREATE INDEX IF NOT EXISTS idx_has_subevent_event              ON has_subevent(event);
CREATE INDEX IF NOT EXISTS idx_has_first_subevent_event        ON has_first_subevent(event);
CREATE INDEX IF NOT EXISTS idx_has_last_subevent_event         ON has_last_subevent(event);
CREATE INDEX IF NOT EXISTS idx_has_prerequisite_action         ON has_prerequisite(action);

-- Desires & goals
CREATE INDEX IF NOT EXISTS idx_desires_agent                   ON desires(agent);
CREATE INDEX IF NOT EXISTS idx_causes_desire_stimulus          ON causes_desire(stimulus);
CREATE INDEX IF NOT EXISTS idx_motivated_by_goal_action        ON motivated_by_goal(action);

-- Lexical & context
CREATE INDEX IF NOT EXISTS idx_has_context_term                ON has_context(term);
CREATE INDEX IF NOT EXISTS idx_has_context_context             ON has_context(context);

-- Etymology
CREATE INDEX IF NOT EXISTS idx_etymologically_derived_from_der ON etymologically_derived_from(derived_word);
CREATE INDEX IF NOT EXISTS idx_derived_from_derivative         ON derived_from(derivative);
CREATE INDEX IF NOT EXISTS idx_derived_from_origin             ON derived_from(origin);

-- Deprecated
CREATE INDEX IF NOT EXISTS idx_instance_of_instance            ON instance_of(instance);
CREATE INDEX IF NOT EXISTS idx_entails_action                  ON entails(action);
CREATE INDEX IF NOT EXISTS idx_not_desires_agent               ON not_desires(agent);
CREATE INDEX IF NOT EXISTS idx_not_capable_of_agent            ON not_capable_of(agent);
CREATE INDEX IF NOT EXISTS idx_not_has_property_entity         ON not_has_property(entity);

-- DBpedia
CREATE INDEX IF NOT EXISTS idx_dbpedia_capital_entity          ON dbpedia_capital(entity);
CREATE INDEX IF NOT EXISTS idx_dbpedia_field_person            ON dbpedia_field(person);
CREATE INDEX IF NOT EXISTS idx_dbpedia_genre_work              ON dbpedia_genre(work);
CREATE INDEX IF NOT EXISTS idx_dbpedia_genus_species           ON dbpedia_genus(species);
CREATE INDEX IF NOT EXISTS idx_dbpedia_influenced_by_subject   ON dbpedia_influenced_by(subject);
CREATE INDEX IF NOT EXISTS idx_dbpedia_known_for_person        ON dbpedia_known_for(person);
CREATE INDEX IF NOT EXISTS idx_dbpedia_language_entity         ON dbpedia_language(entity);
CREATE INDEX IF NOT EXISTS idx_dbpedia_leader_entity           ON dbpedia_leader(entity);
CREATE INDEX IF NOT EXISTS idx_dbpedia_occupation_person        ON dbpedia_occupation(person);
CREATE INDEX IF NOT EXISTS idx_dbpedia_product_company         ON dbpedia_product(company);
