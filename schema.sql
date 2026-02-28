-- schema.sql — SQLite3 schema for English-only ConceptNet 5.7.0
-- Input: en-conceptnet-assertions-5.7.0.csv (3,423,004 rows)
--
-- Design: one table per relationship type (42 tables), with columns
-- named for the semantic roles of each concept in that relationship.
-- Concept values are stored with the /c/en/ prefix stripped.
-- Uniqueness is enforced by UNIQUE(start_col, end_col).

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

------------------------------------------------------------------------
-- Relationship tables — one table per relationship type (42 total)
--
-- Each table stores the assertions for one relationship type.
-- Column names reflect the semantic role of start/end concepts.
-- Common columns on every table:
--   id, <start_role>, <end_role>,
--   weight, surface_text, surface_start, surface_end
------------------------------------------------------------------------

-- ======================================================================
-- Similarity (5): bidirectional associations
-- ======================================================================

-- "A is related to B" — general topical association (1.7M rows)
CREATE TABLE IF NOT EXISTS similarity_related_to (
    id            INTEGER PRIMARY KEY,
    concept_a     TEXT    NOT NULL,
    concept_b     TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (concept_a, concept_b)
);

-- "A means the same as B" — synonymy (222K rows)
CREATE TABLE IF NOT EXISTS similarity_synonym (
    id            INTEGER PRIMARY KEY,
    term_a        TEXT    NOT NULL,
    term_b        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (term_a, term_b)
);

-- "A is the opposite of B" — antonymy (19K rows)
CREATE TABLE IF NOT EXISTS similarity_antonym (
    id            INTEGER PRIMARY KEY,
    term          TEXT    NOT NULL,
    opposite      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (term, opposite)
);

-- "A is similar to B" — resemblance weaker than synonymy (30K rows)
CREATE TABLE IF NOT EXISTS similarity_similar_to (
    id            INTEGER PRIMARY KEY,
    concept_a     TEXT    NOT NULL,
    concept_b     TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (concept_a, concept_b)
);

-- "A is distinct from B" — same category but not the same (3.3K rows)
CREATE TABLE IF NOT EXISTS similarity_distinct_from (
    id            INTEGER PRIMARY KEY,
    concept_a     TEXT    NOT NULL,
    concept_b     TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (concept_a, concept_b)
);

-- ======================================================================
-- Taxonomy (4): categorical hierarchies
-- Three tables get word/POS columns for polysemy-aware queries.
-- ======================================================================

-- "A is a B" — hyponymy / taxonomy (230K rows)
-- e.g. "cat is a animal"
CREATE TABLE IF NOT EXISTS taxonomy_is_a (
    id              INTEGER PRIMARY KEY,
    instance        TEXT    NOT NULL,
    instance_word   TEXT    NOT NULL,
    instance_pos    TEXT    CHECK (instance_pos IN ('n','v','a','r') OR instance_pos IS NULL),
    type            TEXT    NOT NULL,
    type_word       TEXT    NOT NULL,
    type_pos        TEXT    CHECK (type_pos IN ('n','v','a','r') OR type_pos IS NULL),
    weight          REAL    NOT NULL DEFAULT 1.0,
    surface_text    TEXT,
    surface_start   TEXT,
    surface_end     TEXT,
    UNIQUE (instance, type)
);

-- "A is a form of B" — inflection/conjugation (379K rows)
-- e.g. "running is a form of run"
CREATE TABLE IF NOT EXISTS taxonomy_form_of (
    id              INTEGER PRIMARY KEY,
    inflection      TEXT    NOT NULL,
    inflection_word TEXT    NOT NULL,
    inflection_pos  TEXT    CHECK (inflection_pos IN ('n','v','a','r') OR inflection_pos IS NULL),
    root            TEXT    NOT NULL,
    root_word       TEXT    NOT NULL,
    root_pos        TEXT    CHECK (root_pos IN ('n','v','a','r') OR root_pos IS NULL),
    weight          REAL    NOT NULL DEFAULT 1.0,
    surface_text    TEXT,
    surface_start   TEXT,
    surface_end     TEXT,
    UNIQUE (inflection, root)
);

-- "A is a specific way to B" — verb-level hyponymy (13K rows)
-- e.g. "sprint is a manner of run"
CREATE TABLE IF NOT EXISTS taxonomy_manner_of (
    id              INTEGER PRIMARY KEY,
    specific        TEXT    NOT NULL,
    specific_word   TEXT    NOT NULL,
    specific_pos    TEXT    CHECK (specific_pos IN ('n','v','a','r') OR specific_pos IS NULL),
    general         TEXT    NOT NULL,
    general_word    TEXT    NOT NULL,
    general_pos     TEXT    CHECK (general_pos IN ('n','v','a','r') OR general_pos IS NULL),
    weight          REAL    NOT NULL DEFAULT 1.0,
    surface_text    TEXT,
    surface_start   TEXT,
    surface_end     TEXT,
    UNIQUE (specific, general)
);

-- "A is defined as B" — explanatory equivalence (2.2K rows)
CREATE TABLE IF NOT EXISTS taxonomy_defined_as (
    id            INTEGER PRIMARY KEY,
    term          TEXT    NOT NULL,
    definition    TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (term, definition)
);

-- ======================================================================
-- Composition (3): part-whole relationships
-- ======================================================================

-- "A is part of B" — meronymy (13K rows)
-- e.g. "wheel is part of car"
CREATE TABLE IF NOT EXISTS composition_part_of (
    id            INTEGER PRIMARY KEY,
    part          TEXT    NOT NULL,
    whole         TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (part, whole)
);

-- "A has B" — possession / holonymy (5.5K rows)
-- e.g. "car has wheels"
CREATE TABLE IF NOT EXISTS composition_has_a (
    id            INTEGER PRIMARY KEY,
    whole         TEXT    NOT NULL,
    possession    TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (whole, possession)
);

-- "A is made of B" — material composition (545 rows)
-- e.g. "table is made of wood"
CREATE TABLE IF NOT EXISTS composition_made_of (
    id            INTEGER PRIMARY KEY,
    object        TEXT    NOT NULL,
    material      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (object, material)
);

-- ======================================================================
-- Attribute (2): properties and symbols
-- ======================================================================

-- "A has property B" — descriptive attribute (8.4K rows)
-- e.g. "ice has property cold"
CREATE TABLE IF NOT EXISTS attribute_has_property (
    id            INTEGER PRIMARY KEY,
    entity        TEXT    NOT NULL,
    property      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (entity, property)
);

-- "A symbolizes B" — symbolic representation (4 rows)
-- e.g. "dove symbolizes peace"
CREATE TABLE IF NOT EXISTS attribute_symbol_of (
    id            INTEGER PRIMARY KEY,
    symbol        TEXT    NOT NULL,
    meaning       TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (symbol, meaning)
);

-- ======================================================================
-- Spatial (2): location relationships
-- ======================================================================

-- "A is typically found at B" — typical location (28K rows)
-- e.g. "book is at location library"
CREATE TABLE IF NOT EXISTS spatial_at_location (
    id            INTEGER PRIMARY KEY,
    entity        TEXT    NOT NULL,
    location      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (entity, location)
);

-- "A is near B" — typical spatial proximity (49 rows)
CREATE TABLE IF NOT EXISTS spatial_located_near (
    id            INTEGER PRIMARY KEY,
    entity_a      TEXT    NOT NULL,
    entity_b      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (entity_a, entity_b)
);

-- ======================================================================
-- Agency (4): capabilities, actions, and purpose
-- ======================================================================

-- "A is capable of B" — typical ability (23K rows)
-- e.g. "bird is capable of fly"
CREATE TABLE IF NOT EXISTS agency_capable_of (
    id            INTEGER PRIMARY KEY,
    agent         TEXT    NOT NULL,
    action        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (agent, action)
);

-- "A can have B done to it" — passivity (6K rows)
-- e.g. "ball receives action thrown"
CREATE TABLE IF NOT EXISTS agency_receives_action (
    id            INTEGER PRIMARY KEY,
    patient       TEXT    NOT NULL,
    action        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (patient, action)
);

-- "A is created by B" — authorship/creation (263 rows)
CREATE TABLE IF NOT EXISTS agency_created_by (
    id            INTEGER PRIMARY KEY,
    creation      TEXT    NOT NULL,
    creator       TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (creation, creator)
);

-- "A is used for B" — functional purpose (40K rows)
-- e.g. "knife is used for cutting"
CREATE TABLE IF NOT EXISTS agency_used_for (
    id            INTEGER PRIMARY KEY,
    tool          TEXT    NOT NULL,
    purpose       TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (tool, purpose)
);

-- ======================================================================
-- Causation (5): causal and event relationships
-- ======================================================================

-- "A causes B" — causal relationship (17K rows)
-- e.g. "fire causes smoke"
CREATE TABLE IF NOT EXISTS causation_causes (
    id            INTEGER PRIMARY KEY,
    cause         TEXT    NOT NULL,
    effect        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (cause, effect)
);

-- "A includes sub-event B" — event decomposition (25K rows)
CREATE TABLE IF NOT EXISTS causation_has_subevent (
    id            INTEGER PRIMARY KEY,
    event         TEXT    NOT NULL,
    subevent      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (event, subevent)
);

-- "A begins with B" — first step (3.3K rows)
CREATE TABLE IF NOT EXISTS causation_has_first_subevent (
    id              INTEGER PRIMARY KEY,
    event           TEXT    NOT NULL,
    first_subevent  TEXT    NOT NULL,
    weight          REAL    NOT NULL DEFAULT 1.0,
    surface_text    TEXT,
    surface_start   TEXT,
    surface_end     TEXT,
    UNIQUE (event, first_subevent)
);

-- "A ends with B" — last step (2.9K rows)
CREATE TABLE IF NOT EXISTS causation_has_last_subevent (
    id              INTEGER PRIMARY KEY,
    event           TEXT    NOT NULL,
    last_subevent   TEXT    NOT NULL,
    weight          REAL    NOT NULL DEFAULT 1.0,
    surface_text    TEXT,
    surface_start   TEXT,
    surface_end     TEXT,
    UNIQUE (event, last_subevent)
);

-- "A requires B first" — precondition (23K rows)
-- e.g. "cook requires have ingredients"
CREATE TABLE IF NOT EXISTS causation_has_prerequisite (
    id            INTEGER PRIMARY KEY,
    action        TEXT    NOT NULL,
    prerequisite  TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (action, prerequisite)
);

-- ======================================================================
-- Motivation (3): desires and goals
-- ======================================================================

-- "A wants B" — desire of a sentient agent (3.2K rows)
-- e.g. "dog desires bone"
CREATE TABLE IF NOT EXISTS motivation_desires (
    id            INTEGER PRIMARY KEY,
    agent         TEXT    NOT NULL,
    desire        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (agent, desire)
);

-- "A makes you want B" — stimulus creating desire (4.7K rows)
-- e.g. "hunger causes desire eat"
CREATE TABLE IF NOT EXISTS motivation_causes_desire (
    id            INTEGER PRIMARY KEY,
    stimulus      TEXT    NOT NULL,
    desire        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (stimulus, desire)
);

-- "You would A because you want B" — goal-driven action (9.5K rows)
CREATE TABLE IF NOT EXISTS motivation_motivated_by_goal (
    id            INTEGER PRIMARY KEY,
    action        TEXT    NOT NULL,
    goal          TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (action, goal)
);

-- ======================================================================
-- Context (1): lexical and usage context — word/POS on start side
-- ======================================================================

-- "A is used in the context of B" — domain/topic (233K rows)
-- e.g. "scalpel has context medicine"
CREATE TABLE IF NOT EXISTS context_has_context (
    id              INTEGER PRIMARY KEY,
    term            TEXT    NOT NULL,
    term_word       TEXT    NOT NULL,
    term_pos        TEXT    CHECK (term_pos IN ('n','v','a','r') OR term_pos IS NULL),
    context         TEXT    NOT NULL,
    weight          REAL    NOT NULL DEFAULT 1.0,
    surface_text    TEXT,
    surface_start   TEXT,
    surface_end     TEXT,
    UNIQUE (term, context)
);

-- ======================================================================
-- Etymology (3): word origins
-- ======================================================================

-- "A is derived from B" — lexical derivation (325K rows)
-- e.g. "unhappy is derived from happy"
CREATE TABLE IF NOT EXISTS etymology_derived_from (
    id            INTEGER PRIMARY KEY,
    derivative    TEXT    NOT NULL,
    origin        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (derivative, origin)
);

-- "A is etymologically derived from B" — directed etymology (71 rows)
CREATE TABLE IF NOT EXISTS etymology_etymologically_derived_from (
    id            INTEGER PRIMARY KEY,
    derived_word  TEXT    NOT NULL,
    source_word   TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (derived_word, source_word)
);

-- "A and B share an etymological origin" (32K rows)
CREATE TABLE IF NOT EXISTS etymology_etymologically_related_to (
    id            INTEGER PRIMARY KEY,
    word_a        TEXT    NOT NULL,
    word_b        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (word_a, word_b)
);

-- ======================================================================
-- Entity (10): structured knowledge from DBpedia
-- ======================================================================

-- "A has capital B" (459 rows)
CREATE TABLE IF NOT EXISTS entity_capital (
    id            INTEGER PRIMARY KEY,
    entity        TEXT    NOT NULL,
    capital       TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (entity, capital)
);

-- "A works in field B" (643 rows)
CREATE TABLE IF NOT EXISTS entity_field (
    id            INTEGER PRIMARY KEY,
    person        TEXT    NOT NULL,
    field         TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (person, field)
);

-- "A belongs to genre B" (3.8K rows)
CREATE TABLE IF NOT EXISTS entity_genre (
    id            INTEGER PRIMARY KEY,
    work          TEXT    NOT NULL,
    genre         TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (work, genre)
);

-- "A belongs to genus B" — biological taxonomy (2.9K rows)
CREATE TABLE IF NOT EXISTS entity_genus (
    id            INTEGER PRIMARY KEY,
    species       TEXT    NOT NULL,
    genus         TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (species, genus)
);

-- "A was influenced by B" (1.3K rows)
CREATE TABLE IF NOT EXISTS entity_influenced_by (
    id            INTEGER PRIMARY KEY,
    subject       TEXT    NOT NULL,
    influencer    TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (subject, influencer)
);

-- "A is known for B" (607 rows)
CREATE TABLE IF NOT EXISTS entity_known_for (
    id            INTEGER PRIMARY KEY,
    person        TEXT    NOT NULL,
    achievement   TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (person, achievement)
);

-- "A uses language B" (916 rows)
CREATE TABLE IF NOT EXISTS entity_language (
    id            INTEGER PRIMARY KEY,
    entity        TEXT    NOT NULL,
    language      TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (entity, language)
);

-- "A is led by B" (84 rows)
CREATE TABLE IF NOT EXISTS entity_leader (
    id            INTEGER PRIMARY KEY,
    entity        TEXT    NOT NULL,
    leader        TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (entity, leader)
);

-- "A has occupation B" (1K rows)
CREATE TABLE IF NOT EXISTS entity_occupation (
    id            INTEGER PRIMARY KEY,
    person        TEXT    NOT NULL,
    occupation    TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (person, occupation)
);

-- "A produces product B" (519 rows)
CREATE TABLE IF NOT EXISTS entity_product (
    id            INTEGER PRIMARY KEY,
    company       TEXT    NOT NULL,
    product       TEXT    NOT NULL,
    weight        REAL    NOT NULL DEFAULT 1.0,
    surface_text  TEXT,
    surface_start TEXT,
    surface_end   TEXT,
    UNIQUE (company, product)
);

------------------------------------------------------------------------
-- Indexes (64 total)
------------------------------------------------------------------------

-- Similarity (10)
CREATE INDEX IF NOT EXISTS idx_similarity_related_to_concept_a       ON similarity_related_to(concept_a);
CREATE INDEX IF NOT EXISTS idx_similarity_related_to_concept_b       ON similarity_related_to(concept_b);
CREATE INDEX IF NOT EXISTS idx_similarity_synonym_term_a             ON similarity_synonym(term_a);
CREATE INDEX IF NOT EXISTS idx_similarity_synonym_term_b             ON similarity_synonym(term_b);
CREATE INDEX IF NOT EXISTS idx_similarity_antonym_term               ON similarity_antonym(term);
CREATE INDEX IF NOT EXISTS idx_similarity_antonym_opposite           ON similarity_antonym(opposite);
CREATE INDEX IF NOT EXISTS idx_similarity_similar_to_concept_a       ON similarity_similar_to(concept_a);
CREATE INDEX IF NOT EXISTS idx_similarity_similar_to_concept_b       ON similarity_similar_to(concept_b);
CREATE INDEX IF NOT EXISTS idx_similarity_distinct_from_concept_a    ON similarity_distinct_from(concept_a);
CREATE INDEX IF NOT EXISTS idx_similarity_distinct_from_concept_b    ON similarity_distinct_from(concept_b);

-- Taxonomy (13)
CREATE INDEX IF NOT EXISTS idx_taxonomy_is_a_instance                ON taxonomy_is_a(instance);
CREATE INDEX IF NOT EXISTS idx_taxonomy_is_a_type                    ON taxonomy_is_a(type);
CREATE INDEX IF NOT EXISTS idx_taxonomy_is_a_instance_word           ON taxonomy_is_a(instance_word);
CREATE INDEX IF NOT EXISTS idx_taxonomy_is_a_type_word               ON taxonomy_is_a(type_word);
CREATE INDEX IF NOT EXISTS idx_taxonomy_form_of_inflection           ON taxonomy_form_of(inflection);
CREATE INDEX IF NOT EXISTS idx_taxonomy_form_of_root                 ON taxonomy_form_of(root);
CREATE INDEX IF NOT EXISTS idx_taxonomy_form_of_inflection_word      ON taxonomy_form_of(inflection_word);
CREATE INDEX IF NOT EXISTS idx_taxonomy_form_of_root_word            ON taxonomy_form_of(root_word);
CREATE INDEX IF NOT EXISTS idx_taxonomy_manner_of_specific           ON taxonomy_manner_of(specific);
CREATE INDEX IF NOT EXISTS idx_taxonomy_manner_of_general            ON taxonomy_manner_of(general);
CREATE INDEX IF NOT EXISTS idx_taxonomy_manner_of_specific_word      ON taxonomy_manner_of(specific_word);
CREATE INDEX IF NOT EXISTS idx_taxonomy_manner_of_general_word       ON taxonomy_manner_of(general_word);
CREATE INDEX IF NOT EXISTS idx_taxonomy_defined_as_term              ON taxonomy_defined_as(term);

-- Composition (5)
CREATE INDEX IF NOT EXISTS idx_composition_part_of_part              ON composition_part_of(part);
CREATE INDEX IF NOT EXISTS idx_composition_part_of_whole             ON composition_part_of(whole);
CREATE INDEX IF NOT EXISTS idx_composition_has_a_whole               ON composition_has_a(whole);
CREATE INDEX IF NOT EXISTS idx_composition_has_a_possession          ON composition_has_a(possession);
CREATE INDEX IF NOT EXISTS idx_composition_made_of_object            ON composition_made_of(object);

-- Attribute (1)
CREATE INDEX IF NOT EXISTS idx_attribute_has_property_entity         ON attribute_has_property(entity);

-- Spatial (4)
CREATE INDEX IF NOT EXISTS idx_spatial_at_location_entity            ON spatial_at_location(entity);
CREATE INDEX IF NOT EXISTS idx_spatial_at_location_location          ON spatial_at_location(location);
CREATE INDEX IF NOT EXISTS idx_spatial_located_near_entity_a         ON spatial_located_near(entity_a);
CREATE INDEX IF NOT EXISTS idx_spatial_located_near_entity_b         ON spatial_located_near(entity_b);

-- Agency (4)
CREATE INDEX IF NOT EXISTS idx_agency_capable_of_agent               ON agency_capable_of(agent);
CREATE INDEX IF NOT EXISTS idx_agency_receives_action_patient        ON agency_receives_action(patient);
CREATE INDEX IF NOT EXISTS idx_agency_used_for_tool                  ON agency_used_for(tool);
CREATE INDEX IF NOT EXISTS idx_agency_used_for_purpose               ON agency_used_for(purpose);

-- Causation (6)
CREATE INDEX IF NOT EXISTS idx_causation_causes_cause                ON causation_causes(cause);
CREATE INDEX IF NOT EXISTS idx_causation_causes_effect               ON causation_causes(effect);
CREATE INDEX IF NOT EXISTS idx_causation_has_subevent_event          ON causation_has_subevent(event);
CREATE INDEX IF NOT EXISTS idx_causation_has_first_subevent_event    ON causation_has_first_subevent(event);
CREATE INDEX IF NOT EXISTS idx_causation_has_last_subevent_event     ON causation_has_last_subevent(event);
CREATE INDEX IF NOT EXISTS idx_causation_has_prerequisite_action     ON causation_has_prerequisite(action);

-- Motivation (3)
CREATE INDEX IF NOT EXISTS idx_motivation_desires_agent              ON motivation_desires(agent);
CREATE INDEX IF NOT EXISTS idx_motivation_causes_desire_stimulus     ON motivation_causes_desire(stimulus);
CREATE INDEX IF NOT EXISTS idx_motivation_motivated_by_goal_action   ON motivation_motivated_by_goal(action);

-- Context (3)
CREATE INDEX IF NOT EXISTS idx_context_has_context_term              ON context_has_context(term);
CREATE INDEX IF NOT EXISTS idx_context_has_context_context           ON context_has_context(context);
CREATE INDEX IF NOT EXISTS idx_context_has_context_term_word         ON context_has_context(term_word);

-- Etymology (5)
CREATE INDEX IF NOT EXISTS idx_etymology_derived_from_derivative     ON etymology_derived_from(derivative);
CREATE INDEX IF NOT EXISTS idx_etymology_derived_from_origin         ON etymology_derived_from(origin);
CREATE INDEX IF NOT EXISTS idx_etymology_etymologically_derived_from_derived_word ON etymology_etymologically_derived_from(derived_word);
CREATE INDEX IF NOT EXISTS idx_etymology_etymologically_related_to_word_a ON etymology_etymologically_related_to(word_a);
CREATE INDEX IF NOT EXISTS idx_etymology_etymologically_related_to_word_b ON etymology_etymologically_related_to(word_b);

-- Entity (10)
CREATE INDEX IF NOT EXISTS idx_entity_capital_entity                 ON entity_capital(entity);
CREATE INDEX IF NOT EXISTS idx_entity_field_person                   ON entity_field(person);
CREATE INDEX IF NOT EXISTS idx_entity_genre_work                     ON entity_genre(work);
CREATE INDEX IF NOT EXISTS idx_entity_genus_species                  ON entity_genus(species);
CREATE INDEX IF NOT EXISTS idx_entity_influenced_by_subject          ON entity_influenced_by(subject);
CREATE INDEX IF NOT EXISTS idx_entity_known_for_person               ON entity_known_for(person);
CREATE INDEX IF NOT EXISTS idx_entity_language_entity                ON entity_language(entity);
CREATE INDEX IF NOT EXISTS idx_entity_leader_entity                  ON entity_leader(entity);
CREATE INDEX IF NOT EXISTS idx_entity_occupation_person              ON entity_occupation(person);
CREATE INDEX IF NOT EXISTS idx_entity_product_company                ON entity_product(company);
