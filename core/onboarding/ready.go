package onboarding

import (
	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/sourcevocab"
	"github.com/mendahu/provenencia/core/database/users"
)

// readyCatalog is the single post-migrate gate before a catalog is handed to
// research/UI code. database.Create/Open stay migrate-only; every onboarding
// entry point that opens a researcher-facing catalog must call this once.
func readyCatalog(c *database.Catalog) error {
	if err := users.EnsureRefs(c); err != nil {
		return err
	}
	return sourcevocab.Ensure(c)
}
