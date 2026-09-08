package sourcefields

import (
	"database/sql"
	"errors"
	"testing"

	"github.com/mendahu/provenencia/core/database"
)

func TestUpsertLookupList(t *testing.T) {
	tests := []struct {
		name string
		run  func(t *testing.T, c *database.Catalog)
	}{
		{
			name: "upsert lookup refresh data type",
			run: func(t *testing.T, c *database.Catalog) {
				id, err := Upsert(c, Field{
					Key: "author", Origin: OriginProvenencia, Label: "Author", DataType: DataTypeText,
				})
				if err != nil {
					t.Fatal(err)
				}
				got, err := Lookup(c, "author", OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if string(got.ID) != string(id) || got.DataType != DataTypeText {
					t.Fatalf("got %+v", got)
				}
				if _, err := Upsert(c, Field{
					Key: "author", Origin: OriginProvenencia, Label: "Author", DataType: DataTypeDate,
				}); err != nil {
					t.Fatal(err)
				}
				got, err = Lookup(c, "author", OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if got.DataType != DataTypeDate {
					t.Fatalf("data_type %q", got.DataType)
				}
			},
		},
		{
			name: "rejects bad data type",
			run: func(t *testing.T, c *database.Catalog) {
				if _, err := Upsert(c, Field{
					Key: "x", Origin: OriginUser, Label: "X", DataType: "number",
				}); !errors.Is(err, ErrInvalid) {
					t.Fatalf("got %v", err)
				}
			},
		},
		{
			name: "lookup missing",
			run: func(t *testing.T, c *database.Catalog) {
				_, err := Lookup(c, "nope", OriginProvenencia)
				if !errors.Is(err, sql.ErrNoRows) {
					t.Fatalf("got %v", err)
				}
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c, err := database.Create(t.TempDir(), "t.provenencia")
			if err != nil {
				t.Fatal(err)
			}
			defer c.Close()
			tt.run(t, c)
		})
	}
}

func TestCreateUpdateGetByID(t *testing.T) {
	tests := []struct {
		name string
		run  func(t *testing.T, c *database.Catalog)
	}{
		{
			name: "create mints slug key",
			run: func(t *testing.T, c *database.Catalog) {
				f, err := Create(c, "Grandma's album code", DataTypeText, "")
				if err != nil {
					t.Fatal(err)
				}
				if f.Key != "grandmas-album-code" || f.Origin != OriginUser {
					t.Fatalf("got %+v", f)
				}
			},
		},
		{
			name: "create rejects unslugifiable label",
			run: func(t *testing.T, c *database.Catalog) {
				if _, err := Create(c, "...", DataTypeText, ""); !errors.Is(err, ErrInvalid) {
					t.Fatalf("got %v", err)
				}
			},
		},
		{
			name: "create rejects duplicate key under user origin",
			run: func(t *testing.T, c *database.Catalog) {
				if _, err := Create(c, "Album code", DataTypeText, ""); err != nil {
					t.Fatal(err)
				}
				_, err := Create(c, "Album code", DataTypeText, "")
				if !errors.Is(err, ErrDuplicateKey) {
					t.Fatalf("got %v", err)
				}
			},
		},
		{
			name: "same key different origin does not collide",
			run: func(t *testing.T, c *database.Catalog) {
				if _, err := Upsert(c, Field{
					Key: "photographer", Origin: OriginProvenencia, Label: "Photographer", DataType: DataTypeText,
				}); err != nil {
					t.Fatal(err)
				}
				f, err := Create(c, "Photographer", DataTypeText, "")
				if err != nil {
					t.Fatal(err)
				}
				if f.Key != "photographer" || f.Origin != OriginUser {
					t.Fatalf("got %+v", f)
				}
			},
		},
		{
			name: "update patches label type description but not key",
			run: func(t *testing.T, c *database.Catalog) {
				created, err := Create(c, "Album code", DataTypeText, "old")
				if err != nil {
					t.Fatal(err)
				}
				updated, err := Update(c, created.ID, "Album Code", DataTypeDate, "new")
				if err != nil {
					t.Fatal(err)
				}
				if updated.Key != created.Key || updated.Label != "Album Code" ||
					updated.DataType != DataTypeDate || updated.Description != "new" {
					t.Fatalf("got %+v", updated)
				}
				got, err := GetByID(c, created.ID)
				if err != nil {
					t.Fatal(err)
				}
				if got.Key != updated.Key || got.Label != updated.Label {
					t.Fatalf("got %+v want %+v", got, updated)
				}
			},
		},
		{
			name: "update rejects seeded field",
			run: func(t *testing.T, c *database.Catalog) {
				id, err := Upsert(c, Field{
					Key: "author", Origin: OriginProvenencia, Label: "Author", DataType: DataTypeText,
				})
				if err != nil {
					t.Fatal(err)
				}
				if _, err := Update(c, id, "Author 2", DataTypeText, ""); !errors.Is(err, ErrLocked) {
					t.Fatalf("got %v", err)
				}
			},
		},
		{
			name: "get by id missing",
			run: func(t *testing.T, c *database.Catalog) {
				if _, err := GetByID(c, make([]byte, 16)); !errors.Is(err, sql.ErrNoRows) {
					t.Fatalf("got %v", err)
				}
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c, err := database.Create(t.TempDir(), "t.provenencia")
			if err != nil {
				t.Fatal(err)
			}
			defer c.Close()
			tt.run(t, c)
		})
	}
}
