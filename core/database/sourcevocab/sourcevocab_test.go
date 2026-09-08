package sourcevocab

import (
	"database/sql"
	"errors"
	"testing"

	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/sourcefields"
	"github.com/mendahu/provenencia/core/database/sourcetypes"
)

func TestInstall(t *testing.T) {
	tests := []struct {
		name string
		run  func(t *testing.T, c *database.Catalog)
	}{
		{
			name: "empty catalog gets trimmed seed",
			run: func(t *testing.T, c *database.Catalog) {
				if err := Install(c); err != nil {
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
				if len(types) != 1 || len(fields) != 3 {
					t.Fatalf("types=%d fields=%d", len(types), len(fields))
				}
				cert, err := sourcetypes.Lookup(c, "birth_certificate", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				sugs, err := ListSuggestions(c, cert.ID)
				if err != nil {
					t.Fatal(err)
				}
				if len(sugs) != 3 || sugs[0].Field.Key != "document_number" || sugs[0].SortOrder != 0 {
					t.Fatalf("suggestions %+v", sugs)
				}
			},
		},
		{
			name: "install twice keeps same ids",
			run: func(t *testing.T, c *database.Catalog) {
				if err := Install(c); err != nil {
					t.Fatal(err)
				}
				cert, err := sourcetypes.Lookup(c, "birth_certificate", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				id1 := append([]byte(nil), cert.ID...)
				if err := Install(c); err != nil {
					t.Fatal(err)
				}
				cert, err = sourcetypes.Lookup(c, "birth_certificate", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if string(cert.ID) != string(id1) {
					t.Fatal("id changed on second install")
				}
				types, err := sourcetypes.List(c)
				if err != nil || len(types) != 1 {
					t.Fatalf("types %v %d", err, len(types))
				}
			},
		},
		{
			name: "deleted provenencia type stays deleted without reinstall",
			run: func(t *testing.T, c *database.Catalog) {
				if err := Install(c); err != nil {
					t.Fatal(err)
				}
				cert, err := sourcetypes.Lookup(c, "birth_certificate", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if err := sourcetypes.Delete(c, cert.ID); err != nil {
					t.Fatal(err)
				}
				_, err = sourcetypes.Lookup(c, "birth_certificate", sourcetypes.OriginProvenencia)
				if !errors.Is(err, sql.ErrNoRows) {
					t.Fatalf("want ErrNoRows got %v", err)
				}
			},
		},
		{
			name: "deleted suggestion join stays deleted without reinstall",
			run: func(t *testing.T, c *database.Catalog) {
				if err := Install(c); err != nil {
					t.Fatal(err)
				}
				cert, err := sourcetypes.Lookup(c, "birth_certificate", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				field, err := sourcefields.Lookup(c, "issue_date", sourcefields.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if err := DeleteSuggestion(c, cert.ID, field.ID); err != nil {
					t.Fatal(err)
				}
				sugs, err := ListSuggestions(c, cert.ID)
				if err != nil || len(sugs) != 2 {
					t.Fatalf("after delete %v %d", err, len(sugs))
				}
			},
		},
		{
			name: "user origin twin left alone",
			run: func(t *testing.T, c *database.Catalog) {
				if _, err := sourcetypes.Upsert(c, sourcetypes.Type{
					Key: "birth_certificate", Origin: sourcetypes.OriginUser, Label: "My Birth Cert",
				}); err != nil {
					t.Fatal(err)
				}
				if err := Install(c); err != nil {
					t.Fatal(err)
				}
				userRow, err := sourcetypes.Lookup(c, "birth_certificate", sourcetypes.OriginUser)
				if err != nil {
					t.Fatal(err)
				}
				if userRow.Label != "My Birth Cert" {
					t.Fatalf("user row mutated: %+v", userRow)
				}
				prov, err := sourcetypes.Lookup(c, "birth_certificate", sourcetypes.OriginProvenencia)
				if err != nil {
					t.Fatal(err)
				}
				if prov.Label != "Birth certificate" {
					t.Fatalf("provenencia %+v", prov)
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
