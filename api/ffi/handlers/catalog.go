package handlers

import (
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/mendahu/provenencia/core/apperr"
	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/onboarding"
)

var errInvalidID = apperr.New(apperr.CodeSourcesInvalid, apperr.KindUser)

func openProjectCatalog(projectDir string) (*database.Catalog, error) {
	projectDir = strings.TrimSpace(projectDir)
	if projectDir == "" {
		return nil, database.ErrNotAProject
	}
	return onboarding.OpenCatalog(projectDir)
}

func parseUserID(s string) ([]byte, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil, nil
	}
	return parseID(s)
}

func parseID(s string) ([]byte, error) {
	u, err := uuid.Parse(strings.TrimSpace(s))
	if err != nil || u.Version() != 7 {
		return nil, errInvalidID
	}
	return u[:], nil
}

func uuidString(id []byte) string {
	if len(id) != 16 {
		return ""
	}
	u, err := uuid.FromBytes(id)
	if err != nil {
		return ""
	}
	return u.String()
}

func unmarshalErr(op string, err error) error {
	return fmt.Errorf("%s: unmarshal: %w", op, err)
}
