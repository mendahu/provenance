package sourcetypes

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
			name: "upsert lookup and list",
			run: func(t *testing.T, c *database.Catalog) {
				id, err := Upsert(c, Type{
					Key: "photograph", Origin: OriginProvenencia, Label: "Photograph", Description: "Photo",
				})
				if err != nil {
					t.Fatal(err)
				}
				got, err := Lookup(c, "photograph", OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if string(got.ID) != string(id) || got.Label != "Photograph" || got.Description != "Photo" {
					t.Fatalf("got %+v", got)
				}
				id2, err := Upsert(c, Type{
					Key: "photograph", Origin: OriginProvenencia, Label: "Photo", Description: "Updated",
				})
				if err != nil {
					t.Fatal(err)
				}
				if string(id2) != string(id) {
					t.Fatal("id should be stable on upsert")
				}
				got, err = Lookup(c, "photograph", OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if got.Label != "Photo" || got.Description != "Updated" {
					t.Fatalf("got %+v", got)
				}
				all, err := List(c)
				if err != nil || len(all) != 1 {
					t.Fatalf("list %v %d", err, len(all))
				}
			},
		},
		{
			name: "same key different origins",
			run: func(t *testing.T, c *database.Catalog) {
				if _, err := Upsert(c, Type{Key: "book", Origin: OriginProvenencia, Label: "Book"}); err != nil {
					t.Fatal(err)
				}
				if _, err := Upsert(c, Type{Key: "book", Origin: OriginUser, Label: "My Book"}); err != nil {
					t.Fatal(err)
				}
				all, err := List(c)
				if err != nil || len(all) != 2 {
					t.Fatalf("list %v %d", err, len(all))
				}
			},
		},
		{
			name: "rejects blank key",
			run: func(t *testing.T, c *database.Catalog) {
				if _, err := Upsert(c, Type{Key: "  ", Origin: OriginUser, Label: "X"}); !errors.Is(err, ErrInvalid) {
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
