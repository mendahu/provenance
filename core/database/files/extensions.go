package files

import (
	"crypto/sha256"
	"encoding/hex"
	"io"
	"os"
	"path/filepath"

	"github.com/mendahu/provenencia/core/database"
)

// EnsureObjectExtensions renames legacy extensionless object files to the
// MIME-derived path (objects/{hh}/{hh}/{hex}.jpg, …). Idempotent; safe on
// every researcher open. No-ops when media type has no mapped extension or
// the extended path already exists alone.
func EnsureObjectExtensions(c *database.Catalog) error {
	rows, err := List(c)
	if err != nil {
		return err
	}
	root := c.Dir()
	for _, f := range rows {
		if err := migrateObjectFile(root, f); err != nil {
			return err
		}
	}
	return nil
}

func migrateObjectFile(root string, f File) error {
	legacyRel, err := storageRelPathBase(f.ChecksumSHA256)
	if err != nil {
		return err
	}
	newRel, err := StorageRelPath(f.ChecksumSHA256, f.MediaType)
	if err != nil {
		return err
	}
	if newRel == legacyRel {
		return nil
	}

	legacyPath := filepath.Join(root, filepath.FromSlash(legacyRel))
	newPath := filepath.Join(root, filepath.FromSlash(newRel))

	legacyInfo, legacyErr := os.Lstat(legacyPath)
	newInfo, newErr := os.Lstat(newPath)
	legacyOK := legacyErr == nil && legacyInfo.Mode().IsRegular()
	newOK := newErr == nil && newInfo.Mode().IsRegular()

	switch {
	case !legacyOK && !newOK:
		return nil
	case !legacyOK && newOK:
		return nil
	case legacyOK && !newOK:
		if err := os.MkdirAll(filepath.Dir(newPath), 0o755); err != nil {
			return err
		}
		return os.Rename(legacyPath, newPath)
	default:
		// Both exist: keep new if it matches the catalog checksum; remove legacy.
		ok, err := objectChecksumMatches(newPath, f.ChecksumSHA256)
		if err != nil {
			return err
		}
		if !ok {
			okLegacy, err := objectChecksumMatches(legacyPath, f.ChecksumSHA256)
			if err != nil {
				return err
			}
			if okLegacy {
				if err := os.Remove(newPath); err != nil {
					return err
				}
				return os.Rename(legacyPath, newPath)
			}
			// Neither matches — leave both; writers will re-verify on use.
			return nil
		}
		return os.Remove(legacyPath)
	}
}

func objectChecksumMatches(absPath, wantHex string) (bool, error) {
	f, err := os.Open(absPath)
	if err != nil {
		return false, err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return false, err
	}
	return hex.EncodeToString(h.Sum(nil)) == wantHex, nil
}
