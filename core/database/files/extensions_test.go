package files

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"testing"

	"github.com/mendahu/provenencia/core/database"
)

func TestEnsureObjectExtensions(t *testing.T) {
	c, err := database.Create(t.TempDir(), "t.provenencia")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()

	data := []byte("jpeg-ish-bytes")
	sum := sha256.Sum256(data)
	checksum := hex.EncodeToString(sum[:])
	legacyRel, err := storageRelPathBase(checksum)
	if err != nil {
		t.Fatal(err)
	}
	legacyPath := filepath.Join(c.Dir(), filepath.FromSlash(legacyRel))
	if err := os.MkdirAll(filepath.Dir(legacyPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(legacyPath, data, 0o644); err != nil {
		t.Fatal(err)
	}

	id, err := NewID()
	if err != nil {
		t.Fatal(err)
	}
	db, err := c.DB()
	if err != nil {
		t.Fatal(err)
	}
	tx, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	if err := Insert(tx, File{
		ID: id, ChecksumSHA256: checksum, MediaType: "image/jpeg", ByteSize: int64(len(data)),
	}); err != nil {
		t.Fatal(err)
	}
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}

	if err := EnsureObjectExtensions(c); err != nil {
		t.Fatal(err)
	}

	newRel, err := StorageRelPath(checksum, "image/jpeg")
	if err != nil {
		t.Fatal(err)
	}
	newPath := filepath.Join(c.Dir(), filepath.FromSlash(newRel))
	if _, err := os.Stat(newPath); err != nil {
		t.Fatalf("extended path missing: %v", err)
	}
	if _, err := os.Stat(legacyPath); !os.IsNotExist(err) {
		t.Fatalf("legacy path still present: %v", err)
	}

	// Idempotent second pass.
	if err := EnsureObjectExtensions(c); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(newPath)
	if err != nil || string(got) != string(data) {
		t.Fatalf("object bytes %v %q", err, got)
	}
}

func TestList(t *testing.T) {
	c, err := database.Create(t.TempDir(), "t.provenencia")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()

	list, err := List(c)
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 0 {
		t.Fatalf("empty got %d", len(list))
	}

	db, err := c.DB()
	if err != nil {
		t.Fatal(err)
	}
	tx, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	for _, sum := range []string{
		"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
	} {
		id, err := NewID()
		if err != nil {
			t.Fatal(err)
		}
		if err := Insert(tx, File{ID: id, ChecksumSHA256: sum, ByteSize: 1}); err != nil {
			t.Fatal(err)
		}
	}
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}

	list, err = List(c)
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 2 {
		t.Fatalf("got %d want 2", len(list))
	}
	if list[0].ChecksumSHA256 > list[1].ChecksumSHA256 {
		t.Fatalf("not ordered by checksum: %s then %s", list[0].ChecksumSHA256, list[1].ChecksumSHA256)
	}
}
