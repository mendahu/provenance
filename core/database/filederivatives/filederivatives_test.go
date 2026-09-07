package filederivatives

import (
	"database/sql"
	"errors"
	"testing"

	"github.com/mattn/go-sqlite3"
	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/files"
)

func insertFile(t *testing.T, c *database.Catalog, sum string) []byte {
	t.Helper()
	id, err := files.NewID()
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
	if err := files.Insert(tx, files.File{
		ID: id, ChecksumSHA256: sum, MediaType: "image/png", ByteSize: 1,
	}); err != nil {
		t.Fatal(err)
	}
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}
	return id
}

func TestInsertLookupList(t *testing.T) {
	c, err := database.Create(t.TempDir(), "t.provenencia")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()

	src := insertFile(t, c, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
	dst := insertFile(t, c, "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
	linkID, err := NewID()
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
	link := Link{
		ID: linkID, SourceFileID: src, DerivedFileID: dst, DerivativeType: TypeThumbnail,
	}
	if err := Insert(tx, link); err != nil {
		t.Fatal(err)
	}
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}

	got, err := Lookup(c, src, TypeThumbnail)
	if err != nil {
		t.Fatal(err)
	}
	if string(got.ID) != string(linkID) || string(got.DerivedFileID) != string(dst) {
		t.Fatalf("%+v", got)
	}
	list, err := ListBySourceFile(c, src)
	if err != nil || len(list) != 1 {
		t.Fatalf("%v %+v", err, list)
	}
	_, err = Lookup(c, src, "page")
	if !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("missing %v", err)
	}
}

func TestInsertRejectsSameSourceDerived(t *testing.T) {
	c, err := database.Create(t.TempDir(), "t.provenencia")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	src := insertFile(t, c, "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")
	linkID, err := NewID()
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
	err = Insert(tx, Link{
		ID: linkID, SourceFileID: src, DerivedFileID: src, DerivativeType: TypeThumbnail,
	})
	if !errors.Is(err, ErrInvalid) {
		t.Fatalf("got %v", err)
	}
	_ = tx.Rollback()
}

func TestUniqueConstraint(t *testing.T) {
	c, err := database.Create(t.TempDir(), "t.provenencia")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	src := insertFile(t, c, "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd")
	a := insertFile(t, c, "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
	b := insertFile(t, c, "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
	db, err := c.DB()
	if err != nil {
		t.Fatal(err)
	}
	tx, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	id1, _ := NewID()
	if err := Insert(tx, Link{ID: id1, SourceFileID: src, DerivedFileID: a, DerivativeType: TypeThumbnail}); err != nil {
		t.Fatal(err)
	}
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}
	tx2, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	id2, _ := NewID()
	err = Insert(tx2, Link{ID: id2, SourceFileID: src, DerivedFileID: b, DerivativeType: TypeThumbnail})
	if !IsUniqueConflict(err) {
		t.Fatalf("want unique, got %v", err)
	}
	var se sqlite3.Error
	if !errors.As(err, &se) {
		t.Fatalf("want sqlite3.Error, got %T", err)
	}
}

func TestMigrationPresent(t *testing.T) {
	c, err := database.Create(t.TempDir(), "t.provenencia")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	db, err := c.DB()
	if err != nil {
		t.Fatal(err)
	}
	var name string
	if err := db.QueryRow(
		`SELECT name FROM sqlite_master WHERE type='table' AND name='file_derivatives'`,
	).Scan(&name); err != nil || name != "file_derivatives" {
		t.Fatalf("%v %q", err, name)
	}
}
