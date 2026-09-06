package sources

import (
	"database/sql"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/audit"
	"github.com/mendahu/provenencia/core/database/project"
)

const (
	sqlInsertNote = `INSERT INTO source_notes (id, source_id, body) VALUES (?, ?, ?)`
	sqlUpdateNote = `UPDATE source_notes SET body = ? WHERE id = ?`
	sqlDeleteNote = `DELETE FROM source_notes WHERE id = ?`
	sqlGetNote    = `SELECT id, source_id, body FROM source_notes WHERE id = ?`
	sqlListNotes  = `SELECT id, source_id, body FROM source_notes
		WHERE source_id = ? ORDER BY id`
	sqlSourceExists = `SELECT 1 FROM sources WHERE id = ?`
)

// Note is one source_notes row.
type Note struct {
	ID       []byte
	SourceID []byte
	Body     string
}

// AddNote inserts a note and records create_source_note.
func AddNote(c *database.Catalog, userID, sourceID []byte, body string) (Note, error) {
	db, err := c.DB()
	if err != nil {
		return Note{}, err
	}
	body = strings.TrimSpace(body)
	if len(sourceID) != 16 || body == "" {
		return Note{}, ErrInvalid
	}
	if err := requireUserID(userID); err != nil {
		return Note{}, err
	}

	tx, err := db.Begin()
	if err != nil {
		return Note{}, err
	}
	defer func() { _ = tx.Rollback() }()

	if err := requireSource(tx, sourceID); err != nil {
		return Note{}, err
	}
	id, err := uuid.NewV7()
	if err != nil {
		return Note{}, err
	}
	idBytes := id[:]
	if _, err := tx.Exec(sqlInsertNote, idBytes, sourceID, body); err != nil {
		return Note{}, mapConstraint(err)
	}
	if _, err := audit.Record(tx, audit.Revision{
		UserID:     userID,
		ActionType: "create_source_note",
		CreatedAt:  project.NowUTC(),
		Changes: []audit.Change{{
			EntityType: "source_note",
			EntityID:   idBytes,
			Action:     audit.ActionCreate,
			Fields: map[string]audit.FieldDiff{
				"id":        {Old: nil, New: id.String()},
				"source_id": {Old: nil, New: uuidString(sourceID)},
				"body":      {Old: nil, New: body},
			},
		}},
	}); err != nil {
		return Note{}, err
	}
	if err := tx.Commit(); err != nil {
		return Note{}, err
	}
	return Note{
		ID:       append([]byte(nil), idBytes...),
		SourceID: append([]byte(nil), sourceID...),
		Body:     body,
	}, nil
}

// UpdateNote changes body and records update_source_note.
func UpdateNote(c *database.Catalog, userID, noteID []byte, body string) error {
	db, err := c.DB()
	if err != nil {
		return err
	}
	body = strings.TrimSpace(body)
	if len(noteID) != 16 || body == "" {
		return ErrInvalid
	}
	if err := requireUserID(userID); err != nil {
		return err
	}

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	prev, err := getNoteTx(tx, noteID)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrInvalid
	}
	if err != nil {
		return err
	}
	if prev.Body == body {
		return tx.Commit()
	}
	if _, err := tx.Exec(sqlUpdateNote, body, noteID); err != nil {
		return err
	}
	if _, err := audit.Record(tx, audit.Revision{
		UserID:     userID,
		ActionType: "update_source_note",
		CreatedAt:  project.NowUTC(),
		Changes: []audit.Change{{
			EntityType: "source_note",
			EntityID:   noteID,
			Action:     audit.ActionUpdate,
			Fields: map[string]audit.FieldDiff{
				"body": {Old: prev.Body, New: body},
			},
		}},
	}); err != nil {
		return err
	}
	return tx.Commit()
}

// DeleteNote removes a note and records delete_source_note.
func DeleteNote(c *database.Catalog, userID, noteID []byte) error {
	db, err := c.DB()
	if err != nil {
		return err
	}
	if len(noteID) != 16 {
		return ErrInvalid
	}
	if err := requireUserID(userID); err != nil {
		return err
	}

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	prev, err := getNoteTx(tx, noteID)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrInvalid
	}
	if err != nil {
		return err
	}
	if _, err := tx.Exec(sqlDeleteNote, noteID); err != nil {
		return err
	}
	if _, err := audit.Record(tx, audit.Revision{
		UserID:     userID,
		ActionType: "delete_source_note",
		CreatedAt:  project.NowUTC(),
		Changes: []audit.Change{{
			EntityType: "source_note",
			EntityID:   noteID,
			Action:     audit.ActionDelete,
			Fields: map[string]audit.FieldDiff{
				"id":        {Old: uuidString(noteID), New: nil},
				"source_id": {Old: uuidString(prev.SourceID), New: nil},
				"body":      {Old: prev.Body, New: nil},
			},
		}},
	}); err != nil {
		return err
	}
	return tx.Commit()
}

// ListNotes returns notes for a Source, ordered by id.
func ListNotes(c *database.Catalog, sourceID []byte) ([]Note, error) {
	db, err := c.DB()
	if err != nil {
		return nil, err
	}
	if len(sourceID) != 16 {
		return nil, ErrInvalid
	}
	rows, err := db.Query(sqlListNotes, sourceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Note
	for rows.Next() {
		var n Note
		if err := rows.Scan(&n.ID, &n.SourceID, &n.Body); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, rows.Err()
}

func getNoteTx(tx *sql.Tx, id []byte) (Note, error) {
	var n Note
	err := tx.QueryRow(sqlGetNote, id).Scan(&n.ID, &n.SourceID, &n.Body)
	if err != nil {
		return Note{}, err
	}
	return n, nil
}

func requireSource(tx *sql.Tx, sourceID []byte) error {
	var one int
	err := tx.QueryRow(sqlSourceExists, sourceID).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrInvalid
	}
	return err
}
