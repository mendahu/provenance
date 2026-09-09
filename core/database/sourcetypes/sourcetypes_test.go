package sourcetypes

import (
	"database/sql"
	"errors"
	"testing"

	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/sources"
	"github.com/mendahu/provenencia/core/database/users"
	"github.com/mendahu/provenencia/core/ref"
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

func TestDelete(t *testing.T) {
	userID := []byte{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}

	tests := []struct {
		name string
		run  func(t *testing.T, c *database.Catalog)
	}{
		{
			name: "unused provenencia ok",
			run: func(t *testing.T, c *database.Catalog) {
				id, err := Upsert(c, Type{Key: "census", Origin: OriginProvenencia, Label: "Census"})
				if err != nil {
					t.Fatal(err)
				}
				if err := Delete(c, id); err != nil {
					t.Fatal(err)
				}
				_, err = Lookup(c, "census", OriginProvenencia)
				if !errors.Is(err, sql.ErrNoRows) {
					t.Fatalf("got %v", err)
				}
			},
		},
		{
			name: "in use refuses",
			run: func(t *testing.T, c *database.Catalog) {
				r, err := ref.Mint(ref.PrefixUser)
				if err != nil {
					t.Fatal(err)
				}
				if err := users.Upsert(c, userID, "Jake", r); err != nil {
					t.Fatal(err)
				}
				id, err := Upsert(c, Type{Key: "book", Origin: OriginUser, Label: "Book"})
				if err != nil {
					t.Fatal(err)
				}
				if _, err := sources.Create(c, userID, sources.CreateInput{SourceTypeID: id, Title: "T"}); err != nil {
					t.Fatal(err)
				}
				if err := Delete(c, id); !errors.Is(err, ErrInUse) {
					t.Fatalf("got %v", err)
				}
			},
		},
		{
			name: "bad id",
			run: func(t *testing.T, c *database.Catalog) {
				if err := Delete(c, []byte{1}); !errors.Is(err, ErrInvalid) {
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
	userID := []byte{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}

	tests := []struct {
		name string
		run  func(t *testing.T, c *database.Catalog)
	}{
		{
			name: "create mints kebab key from label",
			run: func(t *testing.T, c *database.Catalog) {
				got, err := Create(c, "Parish register", "Baptisms, marriages, burials")
				if err != nil {
					t.Fatal(err)
				}
				if got.Key != "parish-register" || got.Origin != OriginUser {
					t.Fatalf("got %+v", got)
				}
			},
		},
		{
			name: "create refuses an unslugifiable label",
			run: func(t *testing.T, c *database.Catalog) {
				if _, err := Create(c, "—", ""); !errors.Is(err, ErrInvalid) {
					t.Fatalf("got %v", err)
				}
			},
		},
		{
			name: "create refuses a duplicate user key",
			run: func(t *testing.T, c *database.Catalog) {
				if _, err := Create(c, "Parish register", ""); err != nil {
					t.Fatal(err)
				}
				_, err := Create(c, "Parish Register", "")
				if !errors.Is(err, ErrDuplicateKey) {
					t.Fatalf("got %v", err)
				}
			},
		},
		{
			name: "create may reuse a provenencia key under user origin",
			run: func(t *testing.T, c *database.Catalog) {
				if _, err := Upsert(c, Type{Key: "book", Origin: OriginProvenencia, Label: "Book"}); err != nil {
					t.Fatal(err)
				}
				got, err := Create(c, "Book", "")
				if err != nil {
					t.Fatal(err)
				}
				if got.Key != "book" || got.Origin != OriginUser {
					t.Fatalf("got %+v", got)
				}
			},
		},
		{
			name: "update patches label and description, keeping the key",
			run: func(t *testing.T, c *database.Catalog) {
				id, err := Upsert(c, Type{Key: "book", Origin: OriginProvenencia, Label: "Book", Description: "Old"})
				if err != nil {
					t.Fatal(err)
				}
				got, err := Update(c, id, "Printed book", "New")
				if err != nil {
					t.Fatal(err)
				}
				if got.Key != "book" || got.Label != "Printed book" || got.Description != "New" {
					t.Fatalf("got %+v", got)
				}
			},
		},
		{
			name: "update refuses a plugin type",
			run: func(t *testing.T, c *database.Catalog) {
				id, err := Upsert(c, Type{Key: "memorial", Origin: "plugin:findagrave", Label: "Grave memorial"})
				if err != nil {
					t.Fatal(err)
				}
				if _, err := Update(c, id, "Mine now", ""); !errors.Is(err, ErrLocked) {
					t.Fatalf("got %v", err)
				}
			},
		},
		{
			name: "update refuses a blank label",
			run: func(t *testing.T, c *database.Catalog) {
				id, err := Upsert(c, Type{Key: "book", Origin: OriginUser, Label: "Book"})
				if err != nil {
					t.Fatal(err)
				}
				if _, err := Update(c, id, "   ", ""); !errors.Is(err, ErrInvalid) {
					t.Fatalf("got %v", err)
				}
			},
		},
		{
			name: "get by id round-trips, missing is ErrNoRows",
			run: func(t *testing.T, c *database.Catalog) {
				id, err := Upsert(c, Type{Key: "book", Origin: OriginUser, Label: "Book"})
				if err != nil {
					t.Fatal(err)
				}
				got, err := GetByID(c, id)
				if err != nil || got.Key != "book" {
					t.Fatalf("got %+v %v", got, err)
				}
				missing := []byte{9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9}
				if _, err := GetByID(c, missing); !errors.Is(err, sql.ErrNoRows) {
					t.Fatalf("got %v", err)
				}
			},
		},
		{
			name: "list and UsedBy count the sources of a type",
			run: func(t *testing.T, c *database.Catalog) {
				r, err := ref.Mint(ref.PrefixUser)
				if err != nil {
					t.Fatal(err)
				}
				if err := users.Upsert(c, userID, "Jake", r); err != nil {
					t.Fatal(err)
				}
				used, err := Upsert(c, Type{Key: "book", Origin: OriginUser, Label: "Book"})
				if err != nil {
					t.Fatal(err)
				}
				if _, err := Upsert(c, Type{Key: "letter", Origin: OriginUser, Label: "Letter"}); err != nil {
					t.Fatal(err)
				}
				for _, title := range []string{"One", "Two"} {
					if _, err := sources.Create(c, userID, sources.CreateInput{SourceTypeID: used, Title: title}); err != nil {
						t.Fatal(err)
					}
				}
				n, err := UsedBy(c, used)
				if err != nil || n != 2 {
					t.Fatalf("UsedBy %d %v", n, err)
				}
				all, err := List(c)
				if err != nil {
					t.Fatal(err)
				}
				byKey := map[string]int{}
				for _, tp := range all {
					byKey[tp.Key] = tp.UsedBy
				}
				if byKey["book"] != 2 || byKey["letter"] != 0 {
					t.Fatalf("got %v", byKey)
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
