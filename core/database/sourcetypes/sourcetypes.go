// Package sourcetypes accesses the source_types vocabulary table.
package sourcetypes

import (
	"database/sql"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/mendahu/provenencia/core/apperr"
	"github.com/mendahu/provenencia/core/database"
)

var ErrInvalid = apperr.New(apperr.CodeSourceTypesInvalid, apperr.KindUser)

// ErrInUse is returned by Delete when sources still reference the type.
var ErrInUse = apperr.New(apperr.CodeSourceTypesInUse, apperr.KindConflict)

const (
	OriginProvenencia = "provenencia"
	OriginUser        = "user"

	sqlUpsert = `INSERT INTO source_types (id, key, origin, label, description)
		VALUES (?, ?, ?, ?, ?)
		ON CONFLICT(key, origin) DO UPDATE SET
			label = excluded.label,
			description = excluded.description`
	sqlLookup = `SELECT id, key, origin, label, COALESCE(description, '')
		FROM source_types WHERE key = ? AND origin = ?`
	sqlList = `SELECT id, key, origin, label, COALESCE(description, '')
		FROM source_types ORDER BY label COLLATE NOCASE, origin, key`
	sqlDelete = `DELETE FROM source_types WHERE id = ?`
	sqlInUse  = `SELECT 1 FROM sources WHERE source_type_id = ? LIMIT 1`
)

// Type is one source_types row.
type Type struct {
	ID          []byte
	Key         string
	Origin      string
	Label       string
	Description string
}

// Upsert inserts or updates by (key, origin). Mints a UUIDv7 id when ID is empty on insert.
func Upsert(c *database.Catalog, t Type) ([]byte, error) {
	db, err := c.DB()
	if err != nil {
		return nil, err
	}
	t.Key = strings.TrimSpace(t.Key)
	t.Origin = strings.TrimSpace(t.Origin)
	t.Label = strings.TrimSpace(t.Label)
	t.Description = strings.TrimSpace(t.Description)
	if t.Key == "" || t.Label == "" || !originOK(t.Origin) {
		return nil, ErrInvalid
	}
	id := t.ID
	if len(id) == 0 {
		existing, err := Lookup(c, t.Key, t.Origin)
		if err == nil {
			id = existing.ID
		} else if errors.Is(err, sql.ErrNoRows) {
			uid, err := uuid.NewV7()
			if err != nil {
				return nil, err
			}
			id = uid[:]
		} else {
			return nil, err
		}
	} else if len(id) != 16 {
		return nil, ErrInvalid
	}
	var desc any
	if t.Description == "" {
		desc = nil
	} else {
		desc = t.Description
	}
	if _, err := db.Exec(sqlUpsert, id, t.Key, t.Origin, t.Label, desc); err != nil {
		return nil, err
	}
	return append([]byte(nil), id...), nil
}

// Lookup returns the type for (key, origin), or sql.ErrNoRows.
func Lookup(c *database.Catalog, key, origin string) (Type, error) {
	db, err := c.DB()
	if err != nil {
		return Type{}, err
	}
	key = strings.TrimSpace(key)
	origin = strings.TrimSpace(origin)
	if key == "" || origin == "" {
		return Type{}, ErrInvalid
	}
	var t Type
	err = db.QueryRow(sqlLookup, key, origin).Scan(&t.ID, &t.Key, &t.Origin, &t.Label, &t.Description)
	if err != nil {
		return Type{}, err
	}
	return t, nil
}

// List returns all source_types rows.
func List(c *database.Catalog) ([]Type, error) {
	db, err := c.DB()
	if err != nil {
		return nil, err
	}
	rows, err := db.Query(sqlList)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Type
	for rows.Next() {
		var t Type
		if err := rows.Scan(&t.ID, &t.Key, &t.Origin, &t.Label, &t.Description); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// Delete removes a type by id when no sources reference it.
// Cascades suggestion joins. Any origin may be deleted when unused.
func Delete(c *database.Catalog, id []byte) error {
	db, err := c.DB()
	if err != nil {
		return err
	}
	if len(id) != 16 {
		return ErrInvalid
	}
	var one int
	err = db.QueryRow(sqlInUse, id).Scan(&one)
	if err == nil {
		return ErrInUse
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return err
	}
	_, err = db.Exec(sqlDelete, id)
	return err
}

func originOK(origin string) bool {
	if origin == OriginProvenencia || origin == OriginUser {
		return true
	}
	return strings.HasPrefix(origin, "plugin:") && len(origin) > len("plugin:")
}
