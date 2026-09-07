CREATE TABLE file_derivatives (
	id              BLOB PRIMARY KEY,
	source_file_id  BLOB NOT NULL REFERENCES files(id),
	derived_file_id BLOB NOT NULL REFERENCES files(id),
	derivative_type TEXT NOT NULL,
	UNIQUE (source_file_id, derivative_type),
	CHECK (source_file_id <> derived_file_id)
) STRICT;
