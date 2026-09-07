package derivatives

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"testing"

	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/filederivatives"
	"github.com/mendahu/provenencia/core/database/files"
)

func installSourceFile(t *testing.T, c *database.Catalog, data []byte, mediaType, name string) []byte {
	t.Helper()
	sum := sha256.Sum256(data)
	checksum := hex.EncodeToString(sum[:])
	rel, err := files.StorageRelPath(checksum)
	if err != nil {
		t.Fatal(err)
	}
	objPath := filepath.Join(c.Dir(), filepath.FromSlash(rel))
	if err := os.MkdirAll(filepath.Dir(objPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(objPath, data, 0o644); err != nil {
		t.Fatal(err)
	}
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
		ID: id, ChecksumSHA256: checksum, OriginalFilename: name, MediaType: mediaType, ByteSize: int64(len(data)),
	}); err != nil {
		t.Fatal(err)
	}
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}
	return id
}

func auditTotal(t *testing.T, c *database.Catalog) int {
	t.Helper()
	db, err := c.DB()
	if err != nil {
		t.Fatal(err)
	}
	var n int
	if err := db.QueryRow(`SELECT COUNT(*) FROM audit_transactions`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

func TestEnsureThumbnailIdempotent(t *testing.T) {
	c, err := database.Create(t.TempDir(), "t.provenencia")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()

	pngBytes, err := os.ReadFile("testdata/tiny.png")
	if err != nil {
		t.Fatal(err)
	}
	srcID := installSourceFile(t, c, pngBytes, "image/png", "tiny.png")
	before := auditTotal(t, c)

	first, err := EnsureThumbnail(c, srcID)
	if err != nil || first.Skipped {
		t.Fatalf("%+v %v", first, err)
	}
	if len(first.Link.DerivedFileID) != 16 {
		t.Fatal("missing derived id")
	}
	derived, err := files.Lookup(c, first.Link.DerivedFileID)
	if err != nil {
		t.Fatal(err)
	}
	if derived.MediaType != "image/jpeg" || derived.OriginalFilename != "" {
		t.Fatalf("%+v", derived)
	}
	rel, err := files.StorageRelPath(derived.ChecksumSHA256)
	if err != nil {
		t.Fatal(err)
	}
	thumbPath := filepath.Join(c.Dir(), filepath.FromSlash(rel))
	thumbBytes, err := os.ReadFile(thumbPath)
	if err != nil || len(thumbBytes) == 0 {
		t.Fatalf("thumb object %v len=%d", err, len(thumbBytes))
	}
	if _, _, err := image.Decode(bytes.NewReader(thumbBytes)); err != nil {
		t.Fatalf("decode thumb: %v", err)
	}

	second, err := EnsureThumbnail(c, srcID)
	if err != nil || second.Skipped {
		t.Fatalf("%+v %v", second, err)
	}
	if string(second.Link.DerivedFileID) != string(first.Link.DerivedFileID) {
		t.Fatalf("derived id changed: %x vs %x", first.Link.DerivedFileID, second.Link.DerivedFileID)
	}
	if string(second.Link.ID) != string(first.Link.ID) {
		t.Fatalf("link id changed")
	}
	list, err := filederivatives.ListBySourceFile(c, srcID)
	if err != nil || len(list) != 1 {
		t.Fatalf("%v %+v", err, list)
	}
	if auditTotal(t, c) != before {
		t.Fatalf("EnsureThumbnail wrote audit: before=%d after=%d", before, auditTotal(t, c))
	}
}

func TestEnsureThumbnailSkipsNonImage(t *testing.T) {
	c, err := database.Create(t.TempDir(), "t.provenencia")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()

	pdfID := installSourceFile(t, c, []byte("%PDF-1.4"), "application/pdf", "doc.pdf")
	res, err := EnsureThumbnail(c, pdfID)
	if err != nil || !res.Skipped {
		t.Fatalf("%+v %v", res, err)
	}
	list, err := filederivatives.ListBySourceFile(c, pdfID)
	if err != nil || len(list) != 0 {
		t.Fatalf("%v %+v", err, list)
	}

	binID := installSourceFile(t, c, []byte{0, 1, 2}, "application/octet-stream", "blob.bin")
	res, err = EnsureThumbnail(c, binID)
	if err != nil || !res.Skipped {
		t.Fatalf("%+v %v", res, err)
	}
}

func TestEnsureThumbnailFromGeneratedPNG(t *testing.T) {
	// Extra coverage: encode a larger PNG in-memory (not only fixture).
	c, err := database.Create(t.TempDir(), "t.provenencia")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	img := image.NewRGBA(image.Rect(0, 0, 400, 200))
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	srcID := installSourceFile(t, c, buf.Bytes(), "image/png", "wide.png")
	res, err := EnsureThumbnail(c, srcID)
	if err != nil || res.Skipped {
		t.Fatalf("%+v %v", res, err)
	}
	derived, err := files.Lookup(c, res.Link.DerivedFileID)
	if err != nil {
		t.Fatal(err)
	}
	rel, _ := files.StorageRelPath(derived.ChecksumSHA256)
	raw, err := os.ReadFile(filepath.Join(c.Dir(), filepath.FromSlash(rel)))
	if err != nil {
		t.Fatal(err)
	}
	decoded, _, err := image.Decode(bytes.NewReader(raw))
	if err != nil {
		t.Fatal(err)
	}
	b := decoded.Bounds()
	if b.Dx() > 256 || b.Dy() > 256 {
		t.Fatalf("thumb too large: %dx%d", b.Dx(), b.Dy())
	}
	if b.Dx() != 256 || b.Dy() != 128 {
		t.Fatalf("want 256x128, got %dx%d", b.Dx(), b.Dy())
	}
}
