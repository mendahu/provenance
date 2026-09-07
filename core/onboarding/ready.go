package onboarding

import (
	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/sourcevocab"
	"github.com/mendahu/provenencia/core/database/users"
)

// createCatalog and openCatalog are the only researcher-facing catalog entry
// points in onboarding. database.Create/Open stay migrate-only for tests and
// low-level use; reconcile (refs + provenencia vocabulary) runs here once.
func createCatalog(parent, folder string) (*database.Catalog, error) {
	c, err := database.Create(parent, folder)
	if err != nil {
		return nil, err
	}
	if err := reconcile(c); err != nil {
		_ = c.Close()
		return nil, err
	}
	return c, nil
}

// OpenCatalog opens a project for researcher use (migrate + reconcile).
// FFI Source handlers and onboarding open paths must use this, not database.Open.
func OpenCatalog(projectDir string) (*database.Catalog, error) {
	return openCatalog(projectDir)
}

func openCatalog(projectDir string) (*database.Catalog, error) {
	c, err := database.Open(projectDir)
	if err != nil {
		return nil, err
	}
	if err := reconcile(c); err != nil {
		_ = c.Close()
		return nil, err
	}
	return c, nil
}

func reconcile(c *database.Catalog) error {
	if err := users.EnsureRefs(c); err != nil {
		return err
	}
	return sourcevocab.Ensure(c)
}
