CREATE TABLE source_metadata_layout (
	source_id  BLOB NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
	field_id   BLOB NOT NULL REFERENCES source_metadata_fields(id) ON DELETE CASCADE,
	sort_order INTEGER NOT NULL,
	dismissed  INTEGER NOT NULL DEFAULT 0 CHECK (dismissed IN (0, 1)),

	PRIMARY KEY (source_id, field_id)
) STRICT;
