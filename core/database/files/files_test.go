package files

import (
	"database/sql"
	"errors"
	"testing"

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
