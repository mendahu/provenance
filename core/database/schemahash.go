package database

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"fmt"
	"strings"
)

// expectedSchemaHash is the SHA-256 hex digest of sqlite_schema after applying
// embedded migrations to an empty database. Set once from migrate init — there
// is no committed golden constant to bump when adding NNNNNN.sql.
var expectedSchemaHash string

func initExpectedSchemaHash() error {
	db, err := openDBURI(":memory:")
	if err != nil {
		return fmt.Errorf("schema hash: open memory: %w", err)
	}
	defer db.Close()
	if err := migrate(db); err != nil {
		return fmt.Errorf("schema hash: migrate: %w", err)
	}
	digest, err := schemaDigest(db)
	if err != nil {
		return fmt.Errorf("schema hash: digest: %w", err)
	}
	expectedSchemaHash = digest
	return nil
}

// schemaDigest returns a stable SHA-256 hex digest of the catalog DDL shape.
func schemaDigest(db *sql.DB) (string, error) {
	rows, err := db.Query(`SELECT type, name, tbl_name, sql FROM sqlite_schema ORDER BY name COLLATE NOCASE`)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	h := sha256.New()
	for rows.Next() {
		var typ, name, tbl string
		var sqlText sql.NullString
		if err := rows.Scan(&typ, &name, &tbl, &sqlText); err != nil {
			return "", err
		}
		sqlVal := ""
		if sqlText.Valid {
			sqlVal = sqlText.String
		}
		// Unit separator keeps fields unambiguous; null sql is empty.
		line := strings.Join([]string{typ, name, tbl, sqlVal}, "\x1f")
		_, _ = h.Write([]byte(line))
		_, _ = h.Write([]byte{'\n'})
	}
	if err := rows.Err(); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func verifySchema(db *sql.DB) error {
	got, err := schemaDigest(db)
	if err != nil {
		return err
	}
	if got != expectedSchemaHash {
		return ErrSchemaMismatch
	}
	return nil
}
