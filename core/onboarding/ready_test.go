package onboarding

import (
	"database/sql"
	"errors"
	"testing"

	"github.com/mendahu/provenencia/core/database/sourcecredibilitygrades"
	"github.com/mendahu/provenencia/core/database/sourcetypes"
)

func TestOpenCatalogDoesNotHealSourceVocab(t *testing.T) {
	ident := t.TempDir()
	parent := t.TempDir()
	created, err := Complete(ident, parent, "Jake", "Heal Check")
	if err != nil {
		t.Fatal(err)
	}

	c, err := OpenCatalog(created.ProjectDir)
	if err != nil {
		t.Fatal(err)
	}
	cert, err := sourcetypes.Lookup(c, "birth_certificate", sourcetypes.OriginProvenencia)
	if err != nil {
		t.Fatal(err)
	}
	if err := sourcetypes.Delete(c, cert.ID); err != nil {
		t.Fatal(err)
	}
	c.Close()

	c, err = OpenCatalog(created.ProjectDir)
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	_, err = sourcetypes.Lookup(c, "birth_certificate", sourcetypes.OriginProvenencia)
	if !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("open healed seed: %v", err)
	}
}

func TestOpenCatalogDoesNotHealCredibilityGrades(t *testing.T) {
	ident := t.TempDir()
	parent := t.TempDir()
	created, err := Complete(ident, parent, "Jake", "Cred Heal")
	if err != nil {
		t.Fatal(err)
	}

	c, err := OpenCatalog(created.ProjectDir)
	if err != nil {
		t.Fatal(err)
	}
	low, err := sourcecredibilitygrades.Lookup(c, "low_trust", sourcecredibilitygrades.OriginProvenencia)
	if err != nil {
		t.Fatal(err)
	}
	db, err := c.DB()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`DELETE FROM source_credibility_grades WHERE id = ?`, low.ID); err != nil {
		t.Fatal(err)
	}
	c.Close()

	c, err = OpenCatalog(created.ProjectDir)
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	_, err = sourcecredibilitygrades.Lookup(c, "low_trust", sourcecredibilitygrades.OriginProvenencia)
	if !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("open healed credibility grade: %v", err)
	}
}

func TestCreateCatalogSeedsCredibilityGrades(t *testing.T) {
	ident := t.TempDir()
	parent := t.TempDir()
	created, err := Complete(ident, parent, "Jake", "Cred Seed")
	if err != nil {
		t.Fatal(err)
	}
	c, err := OpenCatalog(created.ProjectDir)
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	list, err := sourcecredibilitygrades.List(c)
	if err != nil || len(list) != 3 {
		t.Fatalf("%v len=%d", err, len(list))
	}
}
