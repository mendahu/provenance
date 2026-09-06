package sourcevocab

import (
	"testing"

	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/sourcefields"
	"github.com/mendahu/provenencia/core/database/sourcetypes"
)

func TestEnsure(t *testing.T) {
	tests := []struct {
		name string
		run  func(t *testing.T, c *database.Catalog)
	}{
		{
			name: "empty catalog gets full seed",
			run: func(t *testing.T, c *database.Catalog) {
				if err := Ensure(c); err != nil {
					t.Fatal(err)
				}
				types, err := sourcetypes.List(c)
				if err != nil {
					t.Fatal(err)
				}
				fields, err := sourcefields.List(c)
				if err != nil {
					t.Fatal(err)
				}
				if len(types) != 5 || len(fields) != 11 {
					t.Fatalf("types=%d fields=%d", len(types), len(fields))
				}
				photo, err := sourcetypes.Lookup(c, "photograph", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				sugs, err := ListSuggestions(c, photo.ID)
				if err != nil {
					t.Fatal(err)
				}
				if len(sugs) != 3 || sugs[0].Field.Key != "photographer" || sugs[0].SortOrder != 0 {
					t.Fatalf("suggestions %+v", sugs)
				}
				book, err := sourcetypes.Lookup(c, "book", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				bookSugs, err := ListSuggestions(c, book.ID)
				if err != nil || len(bookSugs) != 4 {
					t.Fatalf("book suggestions %v %d", err, len(bookSugs))
				}
			},
		},
		{
			name: "ensure twice is idempotent",
			run: func(t *testing.T, c *database.Catalog) {
				if err := Ensure(c); err != nil {
					t.Fatal(err)
				}
				photo, err := sourcetypes.Lookup(c, "photograph", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				id1 := append([]byte(nil), photo.ID...)
				if err := Ensure(c); err != nil {
					t.Fatal(err)
				}
				photo, err = sourcetypes.Lookup(c, "photograph", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if string(photo.ID) != string(id1) {
					t.Fatal("id changed on second ensure")
				}
				types, err := sourcetypes.List(c)
				if err != nil || len(types) != 5 {
					t.Fatalf("types %v %d", err, len(types))
				}
			},
		},
		{
			name: "restores deleted provenencia type",
			run: func(t *testing.T, c *database.Catalog) {
				if err := Ensure(c); err != nil {
					t.Fatal(err)
				}
				photo, err := sourcetypes.Lookup(c, "photograph", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if err := sourcetypes.Delete(c, photo.ID); err != nil {
					t.Fatal(err)
				}
				if err := Ensure(c); err != nil {
					t.Fatal(err)
				}
				restored, err := sourcetypes.Lookup(c, "photograph", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if string(restored.ID) == string(photo.ID) {
					t.Fatal("expected new id after recreate")
				}
				sugs, err := ListSuggestions(c, restored.ID)
				if err != nil || len(sugs) != 3 {
					t.Fatalf("suggestions %v %d", err, len(sugs))
				}
			},
		},
		{
			name: "restores deleted suggestion join",
			run: func(t *testing.T, c *database.Catalog) {
				if err := Ensure(c); err != nil {
					t.Fatal(err)
				}
				photo, err := sourcetypes.Lookup(c, "photograph", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				field, err := sourcefields.Lookup(c, "medium", sourcefields.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if err := DeleteSuggestion(c, photo.ID, field.ID); err != nil {
					t.Fatal(err)
				}
				sugs, err := ListSuggestions(c, photo.ID)
				if err != nil || len(sugs) != 2 {
					t.Fatalf("after delete %v %d", err, len(sugs))
				}
				if err := Ensure(c); err != nil {
					t.Fatal(err)
				}
				sugs, err = ListSuggestions(c, photo.ID)
				if err != nil || len(sugs) != 3 {
					t.Fatalf("after ensure %v %d", err, len(sugs))
				}
			},
		},
		{
			name: "user origin twin left alone",
			run: func(t *testing.T, c *database.Catalog) {
				if _, err := sourcetypes.Upsert(c, sourcetypes.Type{
					Key: "photograph", Origin: sourcetypes.OriginUser, Label: "My Photo Type",
				}); err != nil {
					t.Fatal(err)
				}
				if err := Ensure(c); err != nil {
					t.Fatal(err)
				}
				userRow, err := sourcetypes.Lookup(c, "photograph", sourcetypes.OriginUser)
				if err != nil {
					t.Fatal(err)
				}
				if userRow.Label != "My Photo Type" {
					t.Fatalf("user row mutated: %+v", userRow)
				}
				prov, err := sourcetypes.Lookup(c, "photograph", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if prov.Label != "Photograph" {
					t.Fatalf("provenencia %+v", prov)
				}
			},
		},
		{
			name: "refreshes provenencia label from registry",
			run: func(t *testing.T, c *database.Catalog) {
				if err := Ensure(c); err != nil {
					t.Fatal(err)
				}
				if _, err := sourcetypes.Upsert(c, sourcetypes.Type{
					Key: "book", Origin: sourcetypes.OriginProvenencia, Label: "Stale",
				}); err != nil {
					t.Fatal(err)
				}
				if err := Ensure(c); err != nil {
					t.Fatal(err)
				}
				got, err := sourcetypes.Lookup(c, "book", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if got.Label != "Book" {
					t.Fatalf("label %q", got.Label)
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
