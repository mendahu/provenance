ALTER TABLE artifacts ADD COLUMN label TEXT NOT NULL DEFAULT '';

UPDATE artifacts
SET label = CASE
	WHEN trim(COALESCE(description, '')) != '' THEN trim(description)
	ELSE ref
END
WHERE label = '';

CREATE TABLE source_credibility_grades (
	id         BLOB PRIMARY KEY,
	key        TEXT NOT NULL,
	origin     TEXT NOT NULL,
	label      TEXT NOT NULL,
	sort_order INTEGER NOT NULL,
	UNIQUE (key, origin)
) STRICT;

CREATE TABLE source_credibility_assessments (
	id                   BLOB PRIMARY KEY,
	source_id            BLOB NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
	credibility_grade_id BLOB NOT NULL REFERENCES source_credibility_grades(id),
	argument             TEXT,
	UNIQUE (source_id)
) STRICT;
