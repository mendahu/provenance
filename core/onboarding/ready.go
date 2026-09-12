package onboarding

import (
	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/files"
	"github.com/mendahu/provenencia/core/database/sourcecredibilitygrades"
	"github.com/mendahu/provenencia/core/database/sourcevocab"
	"github.com/mendahu/provenencia/core/database/users"
)

// createCatalog and OpenCatalog are the only researcher-facing catalog entry
// points in onboarding. database.Create/Open stay migrate-only for tests and
// low-level use. Refs are reconciled on create and open; Source vocabulary and
// credibility grades are installed once at create only (never healed on open).
func createCatalog(parent, folder string) (*database.Catalog, error) {
	c, err := database.Create(parent, folder)
	if err != nil {
		return nil, err
	}
	if err := users.EnsureRefs(c); err != nil {
		_ = c.Close()
		return nil, err
	}
	if err := sourcevocab.Install(c); err != nil {
		_ = c.Close()
		return nil, err
	}
	if err := sourcecredibilitygrades.Install(c); err != nil {
		_ = c.Close()
		return nil, err
	}
	return c, nil
}

// OpenCatalog opens a project for researcher use (migrate + ensure user refs +
// object-store extension rename). FFI Source handlers and onboarding open paths
// must use this, not database.Open. Does not re-install or heal Source
// vocabulary or credibility grades.
func OpenCatalog(projectDir string) (*database.Catalog, error) {
	c, err := database.Open(projectDir)
	if err != nil {
		return nil, err
	}
	if err := users.EnsureRefs(c); err != nil {
		_ = c.Close()
		return nil, err
	}
	if err := files.EnsureObjectExtensions(c); err != nil {
		_ = c.Close()
		return nil, err
	}
	return c, nil
}
