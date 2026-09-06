package ingest

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/files"
	"github.com/mendahu/provenencia/core/database/users"
	"github.com/mendahu/provenencia/core/ref"
)

func TestFile(t *testing.T) {
	userID := []byte{16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1}

	mustUser := func(t *testing.T, c *database.Catalog) {
		t.Helper()
		r, err := ref.Mint(ref.PrefixUser)
		if err != nil {
			t.Fatal(err)
		}
		if err := users.Upsert(c, userID, "Jake", r); err != nil {
			t.Fatal(err)
		}
	}
	writeTemp := func(t *testing.T, dir, name string, data []byte) string {
		t.Helper()
		path := filepath.Join(dir, name)
		if err := os.WriteFile(path, data, 0o644); err != nil {
			t.Fatal(err)
		}
		return path
	}
	auditCount := func(t *testing.T, c *database.Catalog) int {
		t.Helper()
		db, err := c.DB()
		if err != nil {
			t.Fatal(err)
		}
		var n int
		if err := db.QueryRow(`SELECT COUNT(*) FROM audit_transactions WHERE action_type = 'create_file'`).Scan(&n); err != nil {
			t.Fatal(err)
		}
		return n
	}

	t.Run("ingest new file", func(t *testing.T) {
		c, err := database.Create(t.TempDir(), "t.provenencia")
		if err != nil {
			t.Fatal(err)
		}
		defer c.Close()
		mustUser(t, c)
		srcDir := t.TempDir()
		data := []byte("hello evidence")
		path := writeTemp(t, srcDir, "scan.jpg", data)

		res, err := File(c, path, userID)
		if err != nil {
			t.Fatal(err)
		}
		sum := sha256.Sum256(data)
		wantSum := hex.EncodeToString(sum[:])
		if res.File.ChecksumSHA256 != wantSum || res.File.OriginalFilename != "scan.jpg" {
			t.Fatalf("%+v", res.File)
		}
		wantRel, err := files.StorageRelPath(wantSum)
		if err != nil || res.RelPath != wantRel {
			t.Fatalf("rel %q want %q err %v", res.RelPath, wantRel, err)
		}
		obj := filepath.Join(c.Dir(), filepath.FromSlash(res.RelPath))
		got, err := os.ReadFile(obj)
		if err != nil || string(got) != string(data) {
			t.Fatalf("object %v %q", err, got)
		}
		if filepath.Base(obj) == "scan.jpg" {
			t.Fatal("object path must not use original filename")
		}
		if auditCount(t, c) != 1 {
			t.Fatalf("audit %d", auditCount(t, c))
		}
	})

	t.Run("dedup same bytes no second audit", func(t *testing.T) {
		c, err := database.Create(t.TempDir(), "t.provenencia")
		if err != nil {
			t.Fatal(err)
		}
		defer c.Close()
		mustUser(t, c)
		srcDir := t.TempDir()
		data := []byte("same bytes")
		a := writeTemp(t, srcDir, "a.bin", data)
		b := writeTemp(t, srcDir, "b.bin", data)
		first, err := File(c, a, userID)
		if err != nil {
			t.Fatal(err)
		}
		second, err := File(c, b, userID)
		if err != nil {
			t.Fatal(err)
		}
		if string(first.File.ID) != string(second.File.ID) {
			t.Fatal("expected same file id")
		}
		if auditCount(t, c) != 1 {
			t.Fatalf("audit %d", auditCount(t, c))
		}
	})

	t.Run("rejects symlink", func(t *testing.T) {
		c, err := database.Create(t.TempDir(), "t.provenencia")
		if err != nil {
			t.Fatal(err)
		}
		defer c.Close()
		srcDir := t.TempDir()
		target := writeTemp(t, srcDir, "real.txt", []byte("x"))
		link := filepath.Join(srcDir, "link.txt")
		if err := os.Symlink(target, link); err != nil {
			t.Fatal(err)
		}
		if _, err := File(c, link, nil); !errors.Is(err, ErrInvalid) {
			t.Fatalf("got %v", err)
		}
	})

	t.Run("rejects directory", func(t *testing.T) {
		c, err := database.Create(t.TempDir(), "t.provenencia")
		if err != nil {
			t.Fatal(err)
		}
		defer c.Close()
		if _, err := File(c, t.TempDir(), nil); !errors.Is(err, ErrInvalid) {
			t.Fatalf("got %v", err)
		}
	})

	t.Run("rejects oversize", func(t *testing.T) {
		c, err := database.Create(t.TempDir(), "t.provenencia")
		if err != nil {
			t.Fatal(err)
		}
		defer c.Close()
		prev := maxBytes
		maxBytes = 4
		defer func() { maxBytes = prev }()
		path := writeTemp(t, t.TempDir(), "big.bin", []byte("12345"))
		if _, err := File(c, path, nil); !errors.Is(err, ErrInvalid) {
			t.Fatalf("got %v", err)
		}
	})

	t.Run("closed catalog", func(t *testing.T) {
		c, err := database.Create(t.TempDir(), "t.provenencia")
		if err != nil {
			t.Fatal(err)
		}
		path := writeTemp(t, t.TempDir(), "x.bin", []byte("x"))
		_ = c.Close()
		if _, err := File(c, path, nil); !errors.Is(err, database.ErrClosed) {
			t.Fatalf("got %v", err)
		}
	})

	t.Run("missing path", func(t *testing.T) {
		c, err := database.Create(t.TempDir(), "t.provenencia")
		if err != nil {
			t.Fatal(err)
		}
		defer c.Close()
		if _, err := File(c, filepath.Join(t.TempDir(), "nope"), nil); !errors.Is(err, ErrInvalid) {
			t.Fatalf("got %v", err)
		}
	})
}
