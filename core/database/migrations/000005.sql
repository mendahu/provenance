CREATE TABLE source_types (
	id          BLOB PRIMARY KEY,
	key         TEXT NOT NULL,
	origin      TEXT NOT NULL,
	label       TEXT NOT NULL,
	description TEXT,

	UNIQUE (key, origin)
) STRICT;

CREATE TABLE source_metadata_fields (
	id          BLOB PRIMARY KEY,
	key         TEXT NOT NULL,
	origin      TEXT NOT NULL,
	label       TEXT NOT NULL,
	data_type   TEXT NOT NULL DEFAULT 'text',
	description TEXT,

	UNIQUE (key, origin),
	CHECK (data_type IN ('text', 'date'))
) STRICT;

CREATE TABLE source_type_metadata_fields (
	source_type_id  BLOB NOT NULL REFERENCES source_types(id) ON DELETE CASCADE,
	field_id        BLOB NOT NULL REFERENCES source_metadata_fields(id) ON DELETE CASCADE,
	sort_order      INTEGER,

	PRIMARY KEY (source_type_id, field_id)
) STRICT;
