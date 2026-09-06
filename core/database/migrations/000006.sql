CREATE TABLE sources (
	id              BLOB PRIMARY KEY,
	ref             TEXT UNIQUE NOT NULL,
	source_type_id  BLOB NOT NULL REFERENCES source_types(id),
	title           TEXT,
	description     TEXT
) STRICT;

CREATE TABLE source_notes (
	id         BLOB PRIMARY KEY,
	source_id  BLOB NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
	body       TEXT NOT NULL
) STRICT;
