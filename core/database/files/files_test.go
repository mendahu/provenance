package files

import (
	"database/sql"
	"errors"
	"testing"

	"github.com/mattn/go-sqlite3"
	"github.com/mendahu/provenencia/core/database"
)

func TestStorageRelPath(t *testing.T) {
	const sum = "8fce3b0000000000000000000000000000000000000000000000000000000000"
	got, err := StorageRelPath(sum)
	if err != nil {
		t.Fatal(err)
	}
	want := "objects/8f/ce/" + sum
	if got != want {
		t.Fatalf("got %q want %q", got, want)
	}
	if _, err := StorageRelPath("abcd"); !errors.Is(err, ErrInvalid) {
		t.Fatalf("short %v", err)
	}
	if _, err := StorageRelPath("8FCE3B0000000000000000000000000000000000000000000000000000000000"); !errors.Is(err, ErrInvalid) {
		t.Fatalf("upper %v", err)
	}
}

func TestLookupInsert(t *testing.T) {
	c, err := database.Create(t.TempDir(), "t.provenencia")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()

	id, err := NewID()
	if err != nil {
		t.Fatal(err)
	}
	const sum = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	db, err := c.DB()
	if err != nil {
		t.Fatal(err)
	}
	tx, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	if err := Insert(tx, File{
		ID: id, ChecksumSHA256: sum, OriginalFilename: "a.jpg", MediaType: "image/jpeg", ByteSize: 12,
	}); err != nil {
		t.Fatal(err)
	}
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}
	got, err := LookupByChecksum(c, sum)
	if err != nil {
		t.Fatal(err)
	}
	if got.OriginalFilename != "a.jpg" || got.ByteSize != 12 {
		t.Fatalf("%+v", got)
	}
	byID, err := Lookup(c, id)
	if err != nil || string(byID.ID) != string(id) {
		t.Fatalf("%v %+v", err, byID)
	}
	_, err = Lookup(c, make([]byte, 16))
	if !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("missing %v", err)
	}

	tx2, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	if err := UpdateOriginalFilename(tx2, id, "renamed.jpg"); err != nil {
		t.Fatal(err)
	}
	if err := tx2.Commit(); err != nil {
		t.Fatal(err)
	}
	got2, err := Lookup(c, id)
	if err != nil || got2.OriginalFilename != "renamed.jpg" {
		t.Fatalf("%v %+v", err, got2)
	}
}

func TestUpdateOriginalFilenameInvalid(t *testing.T) {
	if err := UpdateOriginalFilename(nil, make([]byte, 16), "x"); !errors.Is(err, ErrInvalid) {
		t.Fatalf("nil tx %v", err)
	}
	c, err := database.Create(t.TempDir(), "t.provenencia")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	db, err := c.DB()
	if err != nil {
		t.Fatal(err)
	}
	tx, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = tx.Rollback() }()
	if err := UpdateOriginalFilename(tx, []byte{1}, "x"); !errors.Is(err, ErrInvalid) {
		t.Fatalf("short id %v", err)
	}
	if err := UpdateOriginalFilename(tx, make([]byte, 16), "missing"); !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("missing row %v", err)
	}
}

func TestCount(t *testing.T) {
	c, err := database.Create(t.TempDir(), "t.provenencia")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()

	n, err := Count(c)
	if err != nil {
		t.Fatal(err)
	}
	if n != 0 {
		t.Fatalf("empty catalog: got %d want 0", n)
	}

	db, err := c.DB()
	if err != nil {
		t.Fatal(err)
	}
	tx, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	for i, sum := range []string{
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
	} {
		id, err := NewID()
		if err != nil {
			t.Fatal(err)
		}
		if err := Insert(tx, File{ID: id, ChecksumSHA256: sum, ByteSize: int64(i)}); err != nil {
			t.Fatal(err)
		}
	}
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}

	n, err = Count(c)
	if err != nil {
		t.Fatal(err)
	}
	if n != 2 {
		t.Fatalf("after insert: got %d want 2", n)
	}
}

func TestMapConstraint(t *testing.T) {
	unique := sqlite3.Error{Code: sqlite3.ErrConstraint, ExtendedCode: sqlite3.ErrConstraintUnique}
	otherConstraint := sqlite3.Error{Code: sqlite3.ErrConstraint, ExtendedCode: sqlite3.ErrConstraintForeignKey}
	plain := errors.New("plain")

	if !IsUniqueConflict(unique) {
		t.Fatal("expected unique")
	}
	if IsUniqueConflict(otherConstraint) || IsUniqueConflict(plain) {
		t.Fatal("unexpected unique")
	}
	if err := mapConstraint(unique); !IsUniqueConflict(err) {
		t.Fatalf("unique passthrough %v", err)
	}
	if err := mapConstraint(otherConstraint); !errors.Is(err, ErrInvalid) {
		t.Fatalf("constraint %v", err)
	}
	if err := mapConstraint(plain); !errors.Is(err, plain) {
		t.Fatalf("plain %v", err)
	}
}
