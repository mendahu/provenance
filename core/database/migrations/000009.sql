CREATE TABLE source_metadata (
	id            BLOB PRIMARY KEY,
	source_id     BLOB NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
	field_id      BLOB NOT NULL REFERENCES source_metadata_fields(id),
	value_text    TEXT,
	date_value_id BLOB REFERENCES date_values(id),
	UNIQUE (source_id, field_id)
) STRICT;
