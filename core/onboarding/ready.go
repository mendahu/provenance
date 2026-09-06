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
