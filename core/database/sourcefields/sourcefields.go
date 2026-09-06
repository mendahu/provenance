// Package sourcefields accesses the source_metadata_fields vocabulary table.
package sourcefields

import (
	"database/sql"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/mendahu/provenencia/core/apperr"
	"github.com/mendahu/provenencia/core/database"
)

var ErrInvalid = apperr.New(apperr.CodeSourceFieldsInvalid, apperr.KindUser)

const (
	OriginProvenencia = "provenencia"
	OriginUser        = "user"

	DataTypeText = "text"
	DataTypeDate = "date"

	sqlUpsert = `INSERT INTO source_metadata_fields (id, key, origin, label, data_type, description)
		VALUES (?, ?, ?, ?, ?, ?)
		ON CONFLICT(key, origin) DO UPDATE SET
			label = excluded.label,
			data_type = excluded.data_type,
			description = excluded.description`
	sqlLookup = `SELECT id, key, origin, label, data_type, COALESCE(description, '')
		FROM source_metadata_fields WHERE key = ? AND origin = ?`
	sqlList = `SELECT id, key, origin, label, data_type, COALESCE(description, '')
		FROM source_metadata_fields ORDER BY label COLLATE NOCASE, origin, key`
	sqlDelete = `DELETE FROM source_metadata_fields WHERE id = ?`
)

// Field is one source_metadata_fields row.
type Field struct {
	ID          []byte
	Key         string
	Origin      string
	Label       string
	DataType    string
	Description string
}

// Upsert inserts or updates by (key, origin). Mints a UUIDv7 id when ID is empty on insert.
func Upsert(c *database.Catalog, f Field) ([]byte, error) {
	db, err := c.DB()
	if err != nil {
		return nil, err
	}
	f.Key = strings.TrimSpace(f.Key)
	f.Origin = strings.TrimSpace(f.Origin)
	f.Label = strings.TrimSpace(f.Label)
	f.DataType = strings.TrimSpace(f.DataType)
	f.Description = strings.TrimSpace(f.Description)
	if f.Key == "" || f.Label == "" || !originOK(f.Origin) || !dataTypeOK(f.DataType) {
		return nil, ErrInvalid
	}
	id := f.ID
	if len(id) == 0 {
		existing, err := Lookup(c, f.Key, f.Origin)
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
	if f.Description == "" {
		desc = nil
	} else {
		desc = f.Description
	}
	if _, err := db.Exec(sqlUpsert, id, f.Key, f.Origin, f.Label, f.DataType, desc); err != nil {
		return nil, err
	}
	return append([]byte(nil), id...), nil
}

// Lookup returns the field for (key, origin), or sql.ErrNoRows.
func Lookup(c *database.Catalog, key, origin string) (Field, error) {
	db, err := c.DB()
	if err != nil {
		return Field{}, err
	}
	key = strings.TrimSpace(key)
	origin = strings.TrimSpace(origin)
	if key == "" || origin == "" {
		return Field{}, ErrInvalid
	}
	var f Field
	err = db.QueryRow(sqlLookup, key, origin).Scan(
		&f.ID, &f.Key, &f.Origin, &f.Label, &f.DataType, &f.Description,
	)
	if err != nil {
		return Field{}, err
	}
	return f, nil
}

// List returns all source_metadata_fields rows.
func List(c *database.Catalog) ([]Field, error) {
	db, err := c.DB()
	if err != nil {
		return nil, err
	}
	rows, err := db.Query(sqlList)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Field
	for rows.Next() {
		var f Field
		if err := rows.Scan(&f.ID, &f.Key, &f.Origin, &f.Label, &f.DataType, &f.Description); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// Delete removes a field by id (for tests / admin). Cascades suggestion joins.
func Delete(c *database.Catalog, id []byte) error {
	db, err := c.DB()
	if err != nil {
		return err
	}
	if len(id) != 16 {
		return ErrInvalid
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

func dataTypeOK(dt string) bool {
	return dt == DataTypeText || dt == DataTypeDate
}
