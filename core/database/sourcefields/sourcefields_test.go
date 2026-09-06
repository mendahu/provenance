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
