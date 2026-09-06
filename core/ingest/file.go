// Package ingest copies opaque local files into a project’s content-addressed
// object store. Checksum reuse returns the existing File and is not a research
// event (no create_file audit). Ingest does not decode or execute file content.
package ingest

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
	"github.com/mendahu/provenencia/core/apperr"
	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/audit"
	"github.com/mendahu/provenencia/core/database/files"
	"github.com/mendahu/provenencia/core/database/project"
)

var ErrInvalid = apperr.New(apperr.CodeIngestInvalid, apperr.KindUser)

// MaxBytes is the largest source file ingest accepts (512 MiB).
const MaxBytes int64 = 512 << 20

// maxBytes is overridden in tests.
var maxBytes = MaxBytes

// Result is an ingested or reused File plus its project-relative object path.
type Result struct {
	File    files.File
	RelPath string
}

// File reads absPath into the catalog object store. Same bytes reuse the existing
// File row without rewriting the object or recording audit.
func File(c *database.Catalog, absPath string, userID []byte) (Result, error) {
	if _, err := c.DB(); err != nil {
		return Result{}, err
	}
	absPath = strings.TrimSpace(absPath)
	if absPath == "" {
		return Result{}, ErrInvalid
	}
	if err := requireUserID(userID); err != nil {
		return Result{}, err
	}

	info, err := os.Lstat(absPath)
	if err != nil {
		if os.IsNotExist(err) {
			return Result{}, ErrInvalid
		}
		return Result{}, err
	}
	if info.Mode()&os.ModeSymlink != 0 {
		return Result{}, ErrInvalid
	}
	if !info.Mode().IsRegular() {
		return Result{}, ErrInvalid
	}
	if info.Size() > maxBytes {
		return Result{}, ErrInvalid
	}

	src, err := openSource(absPath)
	if err != nil {
		return Result{}, mapOpenErr(err)
	}
	defer src.Close()

	// Re-check after open: reject if size grew past the limit while reading.
	limited := io.LimitReader(src, maxBytes+1)
	data, err := io.ReadAll(limited)
	if err != nil {
		return Result{}, err
	}
	if int64(len(data)) > maxBytes {
		return Result{}, ErrInvalid
	}

	sum := sha256.Sum256(data)
	checksum := hex.EncodeToString(sum[:])
	relPath, err := files.StorageRelPath(checksum)
	if err != nil {
		return Result{}, err
	}

	if existing, err := files.LookupByChecksum(c, checksum); err == nil {
		return Result{File: existing, RelPath: relPath}, nil
	} else if !errors.Is(err, sql.ErrNoRows) {
		return Result{}, err
	}

	objPath := filepath.Join(c.Dir(), filepath.FromSlash(relPath))
	if err := writeObjectIfAbsent(objPath, data); err != nil {
		return Result{}, err
	}

	filename := filepath.Base(absPath)
	mediaType := http.DetectContentType(data)
	if mediaType == "" {
		mediaType = "application/octet-stream"
	}

	id, err := files.NewID()
	if err != nil {
		return Result{}, err
	}
	row := files.File{
		ID:               id,
		ChecksumSHA256:   checksum,
		OriginalFilename: filename,
		MediaType:        mediaType,
		ByteSize:         int64(len(data)),
	}

	db, err := c.DB()
	if err != nil {
		return Result{}, err
	}
	tx, err := db.Begin()
	if err != nil {
		return Result{}, err
	}
	defer func() { _ = tx.Rollback() }()

	if err := files.Insert(tx, row); err != nil {
		if files.IsUniqueConflict(err) {
			_ = tx.Rollback()
			existing, lookupErr := files.LookupByChecksum(c, checksum)
			if lookupErr != nil {
				return Result{}, lookupErr
			}
			return Result{File: existing, RelPath: relPath}, nil
		}
		return Result{}, err
	}

	uid, err := uuid.FromBytes(id)
	if err != nil {
		return Result{}, err
	}
	fields := map[string]audit.FieldDiff{
		"id":              {Old: nil, New: uid.String()},
		"checksum_sha256": {Old: nil, New: checksum},
		"byte_size":       {Old: nil, New: row.ByteSize},
	}
	if filename != "" {
		fields["original_filename"] = audit.FieldDiff{Old: nil, New: filename}
	}
	if mediaType != "" {
		fields["media_type"] = audit.FieldDiff{Old: nil, New: mediaType}
	}
	if _, err := audit.Record(tx, audit.Revision{
		UserID:     userID,
		ActionType: "create_file",
		CreatedAt:  project.NowUTC(),
		Changes: []audit.Change{{
			EntityType: "file",
			EntityID:   id,
			Action:     audit.ActionCreate,
			Fields:     fields,
		}},
	}); err != nil {
		return Result{}, err
	}
	if err := tx.Commit(); err != nil {
		return Result{}, err
	}
	return Result{File: row, RelPath: relPath}, nil
}

func writeObjectIfAbsent(objPath string, data []byte) error {
	if _, err := os.Lstat(objPath); err == nil {
		return nil
	} else if !os.IsNotExist(err) {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(objPath), 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(objPath), ".ingest-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	ok := false
	defer func() {
		if !ok {
			_ = os.Remove(tmpName)
		}
	}()
	if _, err := tmp.Write(data); err != nil {
		_ = tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Rename(tmpName, objPath); err != nil {
		// Another writer may have won the race.
		if _, statErr := os.Lstat(objPath); statErr == nil {
			_ = os.Remove(tmpName)
			ok = true
			return nil
		}
		return err
	}
	ok = true
	return nil
}

func requireUserID(userID []byte) error {
	if len(userID) == 0 {
		return nil
	}
	if len(userID) != 16 {
		return ErrInvalid
	}
	return nil
}

func mapOpenErr(err error) error {
	if errors.Is(err, os.ErrNotExist) {
		return ErrInvalid
	}
	// Symlink replaced between Lstat and open (O_NOFOLLOW).
	var pathErr *os.PathError
	if errors.As(err, &pathErr) {
		return ErrInvalid
	}
	return err
}
