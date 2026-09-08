package onboarding

import (
	"database/sql"
	"errors"
	"testing"

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
