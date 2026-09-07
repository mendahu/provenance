CREATE TABLE files (
	id                BLOB PRIMARY KEY,
	checksum_sha256   TEXT NOT NULL UNIQUE,
	original_filename TEXT,
	media_type        TEXT,
	byte_size         INTEGER NOT NULL
) STRICT;
