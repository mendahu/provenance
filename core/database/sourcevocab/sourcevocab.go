// Package sourcevocab owns type↔field suggestions and provenencia seed reconcile.
//
// Ensure upserts the shipped vocabulary registry (origin=provenencia) and
// restores missing suggestion joins. It does not delete user/plugin rows or
// extra user-added suggestions. Recreating a deleted provenencia row mints a
// new UUID.
package sourcevocab

import (
	"database/sql"

	"github.com/mendahu/provenencia/core/apperr"
	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/sourcefields"
	"github.com/mendahu/provenencia/core/database/sourcetypes"
)

var ErrInvalid = apperr.New(apperr.CodeSourceVocabInvalid, apperr.KindUser)

const (
	sqlEnsureSuggestion = `INSERT INTO source_type_metadata_fields (source_type_id, field_id, sort_order)
		VALUES (?, ?, ?)
		ON CONFLICT(source_type_id, field_id) DO UPDATE SET sort_order = excluded.sort_order`
	sqlListSuggestions = `SELECT f.id, f.key, f.origin, f.label, f.data_type, COALESCE(f.description, ''), j.sort_order
		FROM source_type_metadata_fields j
		JOIN source_metadata_fields f ON f.id = j.field_id
		WHERE j.source_type_id = ?
		ORDER BY j.sort_order ASC, f.label COLLATE NOCASE, f.key`
	sqlDeleteSuggestion = `DELETE FROM source_type_metadata_fields
		WHERE source_type_id = ? AND field_id = ?`
)

// Suggestion is one ordered field attached to a source type.
type Suggestion struct {
	Field     sourcefields.Field
	SortOrder int
}

// EnsureSuggestion inserts or updates the join row's sort_order.
func EnsureSuggestion(c *database.Catalog, typeID, fieldID []byte, sortOrder int) error {
	db, err := c.DB()
	if err != nil {
		return err
	}
	if len(typeID) != 16 || len(fieldID) != 16 {
		return ErrInvalid
	}
	_, err = db.Exec(sqlEnsureSuggestion, typeID, fieldID, sortOrder)
	return err
}

// ListSuggestions returns suggested fields for a type, ordered by sort_order.
func ListSuggestions(c *database.Catalog, typeID []byte) ([]Suggestion, error) {
	db, err := c.DB()
	if err != nil {
		return nil, err
	}
	if len(typeID) != 16 {
		return nil, ErrInvalid
	}
	rows, err := db.Query(sqlListSuggestions, typeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Suggestion
	for rows.Next() {
		var s Suggestion
		var sort sql.NullInt64
		if err := rows.Scan(
			&s.Field.ID, &s.Field.Key, &s.Field.Origin, &s.Field.Label, &s.Field.DataType, &s.Field.Description, &sort,
		); err != nil {
			return nil, err
		}
		if sort.Valid {
			s.SortOrder = int(sort.Int64)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// DeleteSuggestion removes one join row (for tests).
func DeleteSuggestion(c *database.Catalog, typeID, fieldID []byte) error {
	db, err := c.DB()
	if err != nil {
		return err
	}
	if len(typeID) != 16 || len(fieldID) != 16 {
		return ErrInvalid
	}
	_, err = db.Exec(sqlDeleteSuggestion, typeID, fieldID)
	return err
}

// Ensure reconciles the provenencia seed registry into the catalog.
func Ensure(c *database.Catalog) error {
	if _, err := c.DB(); err != nil {
		return err
	}
	fieldIDs := make(map[string][]byte, len(seedFields))
	for _, f := range seedFields {
		id, err := sourcefields.Upsert(c, sourcefields.Field{
			Key:         f.Key,
			Origin:      sourcefields.OriginProvenencia,
			Label:       f.Label,
			DataType:    f.DataType,
			Description: f.Description,
		})
		if err != nil {
			return err
		}
		fieldIDs[f.Key] = id
	}
	typeIDs := make(map[string][]byte, len(seedTypes))
	for _, t := range seedTypes {
		id, err := sourcetypes.Upsert(c, sourcetypes.Type{
			Key:         t.Key,
			Origin:      sourcetypes.OriginProvenencia,
			Label:       t.Label,
			Description: t.Description,
		})
		if err != nil {
			return err
		}
		typeIDs[t.Key] = id
	}
	for _, s := range seedSuggestions {
		typeID := typeIDs[s.TypeKey]
		fieldID := fieldIDs[s.FieldKey]
		if len(typeID) == 0 || len(fieldID) == 0 {
			return ErrInvalid
		}
		if err := EnsureSuggestion(c, typeID, fieldID, s.SortOrder); err != nil {
			return err
		}
	}
	return nil
}
