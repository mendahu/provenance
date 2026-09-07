CREATE TABLE artifacts (
	id          BLOB PRIMARY KEY,
	ref         TEXT UNIQUE NOT NULL,
	source_id   BLOB NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
	file_id     BLOB REFERENCES files(id),
	description TEXT
) STRICT;
