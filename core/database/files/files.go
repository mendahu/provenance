// Package files accesses the content-addressed files catalog table.
package files

import (
	"database/sql"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/mattn/go-sqlite3"
	"github.com/mendahu/provenencia/core/apperr"
	"github.com/mendahu/provenencia/core/database"
)

var ErrInvalid = apperr.New(apperr.CodeFilesInvalid, apperr.KindUser)

const (
	sqlInsert = `INSERT INTO files (id, checksum_sha256, original_filename, media_type, byte_size)
		VALUES (?, ?, ?, ?, ?)`
	sqlLookup = `SELECT id, checksum_sha256, COALESCE(original_filename, ''), COALESCE(media_type, ''), byte_size
		FROM files WHERE id = ?`
	sqlLookupChecksum = `SELECT id, checksum_sha256, COALESCE(original_filename, ''), COALESCE(media_type, ''), byte_size
		FROM files WHERE checksum_sha256 = ?`
)

// File is one files row. Storage path is derived from ChecksumSHA256, not stored.
type File struct {
	ID               []byte
	ChecksumSHA256   string
	OriginalFilename string
	MediaType        string
	ByteSize         int64
}

// StorageRelPath returns objects/{hh}/{hh}/{fullhex} for a 64-char lowercase hex checksum.
func StorageRelPath(checksumHex string) (string, error) {
	checksumHex = strings.TrimSpace(checksumHex)
	if len(checksumHex) != 64 || !isLowerHex(checksumHex) {
		return "", ErrInvalid
	}
	return "objects/" + checksumHex[0:2] + "/" + checksumHex[2:4] + "/" + checksumHex, nil
}

// Lookup returns a File by id, or sql.ErrNoRows.
func Lookup(c *database.Catalog, id []byte) (File, error) {
	db, err := c.DB()
	if err != nil {
		return File{}, err
	}
	if len(id) != 16 {
		return File{}, ErrInvalid
	}
	return scanFile(db.QueryRow(sqlLookup, id))
}

// LookupByChecksum returns a File by SHA-256 hex, or sql.ErrNoRows.
func LookupByChecksum(c *database.Catalog, checksumHex string) (File, error) {
	db, err := c.DB()
	if err != nil {
		return File{}, err
	}
	checksumHex = strings.TrimSpace(checksumHex)
	if len(checksumHex) != 64 || !isLowerHex(checksumHex) {
		return File{}, ErrInvalid
	}
	return scanFile(db.QueryRow(sqlLookupChecksum, checksumHex))
}

// Insert writes a new files row on tx. ID must be 16 bytes; checksum lowercase hex.
func Insert(tx *sql.Tx, f File) error {
	if tx == nil {
		return ErrInvalid
	}
	f.ChecksumSHA256 = strings.TrimSpace(f.ChecksumSHA256)
	f.OriginalFilename = strings.TrimSpace(f.OriginalFilename)
	f.MediaType = strings.TrimSpace(f.MediaType)
	if len(f.ID) != 16 || len(f.ChecksumSHA256) != 64 || !isLowerHex(f.ChecksumSHA256) || f.ByteSize < 0 {
		return ErrInvalid
	}
	_, err := tx.Exec(
		sqlInsert,
		f.ID,
		f.ChecksumSHA256,
		nullStr(f.OriginalFilename),
		nullStr(f.MediaType),
		f.ByteSize,
	)
	if err != nil {
		return mapConstraint(err)
	}
	return nil
}

// NewID mints a UUIDv7 id for a new File row.
func NewID() ([]byte, error) {
	id, err := uuid.NewV7()
	if err != nil {
		return nil, err
	}
	return id[:], nil
}

func scanFile(row interface{ Scan(dest ...any) error }) (File, error) {
	var f File
	if err := row.Scan(&f.ID, &f.ChecksumSHA256, &f.OriginalFilename, &f.MediaType, &f.ByteSize); err != nil {
		return File{}, err
	}
	return f, nil
}

func nullStr(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func isLowerHex(s string) bool {
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= '0' && c <= '9' || c >= 'a' && c <= 'f' {
			continue
		}
		return false
	}
	return true
}

func IsUniqueConflict(err error) bool {
	var se sqlite3.Error
	return errors.As(err, &se) && se.ExtendedCode == sqlite3.ErrConstraintUnique
}

func mapConstraint(err error) error {
	if IsUniqueConflict(err) {
		return err
	}
	var se sqlite3.Error
	if errors.As(err, &se) && se.Code == sqlite3.ErrConstraint {
		return ErrInvalid
	}
	return err
}
