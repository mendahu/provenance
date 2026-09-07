package sourcemetadata

import (
	"errors"
	"testing"

	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/datevalues"
	"github.com/mendahu/provenencia/core/database/sourcefields"
	"github.com/mendahu/provenencia/core/database/sources"
	"github.com/mendahu/provenencia/core/database/sourcetypes"
	"github.com/mendahu/provenencia/core/database/sourcevocab"
	"github.com/mendahu/provenencia/core/database/users"
	"github.com/mendahu/provenencia/core/ref"
)

func TestSourceMetadata(t *testing.T) {
	userID := []byte{16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1}

	mustUser := func(t *testing.T, c *database.Catalog) {
		t.Helper()
		r, err := ref.Mint(ref.PrefixUser)
		if err != nil {
			t.Fatal(err)
		}
		if err := users.Upsert(c, userID, "Jake", r); err != nil {
			t.Fatal(err)
		}
	}
	mustBookSource := func(t *testing.T, c *database.Catalog) sources.Source {
		t.Helper()
		if err := sourcevocab.Ensure(c); err != nil {
			t.Fatal(err)
		}
		st, err := sourcetypes.Lookup(c, "book", sourcetypes.OriginProvenencia)
		if err != nil {
			t.Fatal(err)
		}
		s, err := sources.Create(c, userID, sources.CreateInput{
			SourceTypeID: st.ID,
			Title:        "Family History",
		})
		if err != nil {
			t.Fatal(err)
		}
		return s
	}
	mustField := func(t *testing.T, c *database.Catalog, key string) sourcefields.Field {
		t.Helper()
		f, err := sourcefields.Lookup(c, key, sourcefields.OriginProvenencia)
		if err != nil {
			t.Fatal(err)
		}
		return f
	}
	mustYear := func(t *testing.T, c *database.Catalog, year int, qual string) []byte {
		t.Helper()
		y := year
		id, err := datevalues.Insert(c, datevalues.Value{
			Kind: datevalues.KindYear, Qualifier: qual, StartYear: &y,
		})
		if err != nil {
			t.Fatal(err)
		}
		return id
	}
	latestAction := func(t *testing.T, c *database.Catalog) string {
		t.Helper()
		db, err := c.DB()
		if err != nil {
			t.Fatal(err)
		}
		var actionType string
		if err := db.QueryRow(`SELECT action_type FROM audit_transactions ORDER BY revision DESC LIMIT 1`).Scan(&actionType); err != nil {
			t.Fatal(err)
		}
		return actionType
	}
	metaCount := func(t *testing.T, c *database.Catalog) int {
		t.Helper()
		db, err := c.DB()
		if err != nil {
			t.Fatal(err)
		}
		var n int
		if err := db.QueryRow(`SELECT COUNT(*) FROM source_metadata`).Scan(&n); err != nil {
			t.Fatal(err)
		}
		return n
	}

	tests := []struct {
		name string
		run  func(t *testing.T, c *database.Catalog)
	}{
		{
			name: "set text and reject date on text field",
			run: func(t *testing.T, c *database.Catalog) {
				mustUser(t, c)
				src := mustBookSource(t, c)
				author := mustField(t, c, "author")
				row, err := Set(c, userID, Input{
					SourceID: src.ID, FieldID: author.ID, ValueText: "Alice Smith",
				})
				if err != nil {
					t.Fatal(err)
				}
				if row.ValueText != "Alice Smith" || row.DateValueID != nil {
					t.Fatalf("%+v", row)
				}
				if latestAction(t, c) != "update_source_metadata" {
					t.Fatalf("action %q", latestAction(t, c))
				}
				dv := mustYear(t, c, 1890, datevalues.QualifierABT)
				if _, err := Set(c, userID, Input{
					SourceID: src.ID, FieldID: author.ID, ValueText: "x", DateValueID: dv,
				}); !errors.Is(err, ErrInvalid) {
					t.Fatalf("got %v", err)
				}
			},
		},
		{
			name: "date text only structured only and both",
			run: func(t *testing.T, c *database.Catalog) {
				mustUser(t, c)
				src := mustBookSource(t, c)
				pub := mustField(t, c, "publication_date")
				if _, err := Set(c, userID, Input{
					SourceID: src.ID, FieldID: pub.ID, ValueText: "about the year 1890",
				}); err != nil {
					t.Fatal(err)
				}
				dv := mustYear(t, c, 1890, datevalues.QualifierABT)
				if _, err := Set(c, userID, Input{
					SourceID: src.ID, FieldID: pub.ID, DateValueID: dv,
				}); err != nil {
					t.Fatal(err)
				}
				both, err := Set(c, userID, Input{
					SourceID: src.ID, FieldID: pub.ID,
					ValueText: "about the year 1890", DateValueID: dv,
				})
				if err != nil {
					t.Fatal(err)
				}
				if both.ValueText != "about the year 1890" || string(both.DateValueID) != string(dv) {
					t.Fatalf("%+v", both)
				}
				if _, err := Set(c, userID, Input{SourceID: src.ID, FieldID: pub.ID}); !errors.Is(err, ErrInvalid) {
					t.Fatalf("empty set %v", err)
				}
			},
		},
		{
			name: "clear and upsert same pair",
			run: func(t *testing.T, c *database.Catalog) {
				mustUser(t, c)
				src := mustBookSource(t, c)
				isbn := mustField(t, c, "isbn")
				first, err := Set(c, userID, Input{SourceID: src.ID, FieldID: isbn.ID, ValueText: "111"})
				if err != nil {
					t.Fatal(err)
				}
				second, err := Set(c, userID, Input{SourceID: src.ID, FieldID: isbn.ID, ValueText: "222"})
				if err != nil {
					t.Fatal(err)
				}
				if string(first.ID) != string(second.ID) || second.ValueText != "222" {
					t.Fatalf("first=%+v second=%+v", first, second)
				}
				list, err := ListBySource(c, src.ID)
				if err != nil || len(list) != 1 {
					t.Fatalf("%v len=%d", err, len(list))
				}
				if err := Clear(c, userID, src.ID, isbn.ID); err != nil {
					t.Fatal(err)
				}
				if latestAction(t, c) != "update_source_metadata" {
					t.Fatalf("action %q", latestAction(t, c))
				}
				list, err = ListBySource(c, src.ID)
				if err != nil || len(list) != 0 {
					t.Fatalf("after clear %v len=%d", err, len(list))
				}
				if err := Clear(c, userID, src.ID, isbn.ID); err != nil {
					t.Fatal(err)
				}
			},
		},
		{
			name: "list workspace suggested and extras",
			run: func(t *testing.T, c *database.Catalog) {
				mustUser(t, c)
				src := mustBookSource(t, c)
				author := mustField(t, c, "author")
				if _, err := Set(c, userID, Input{SourceID: src.ID, FieldID: author.ID, ValueText: "Alice"}); err != nil {
					t.Fatal(err)
				}
				extraID, err := sourcefields.Upsert(c, sourcefields.Field{
					Key: "shelf_mark", Origin: sourcefields.OriginUser, Label: "Shelf mark", DataType: sourcefields.DataTypeText,
				})
				if err != nil {
					t.Fatal(err)
				}
				if _, err := Set(c, userID, Input{SourceID: src.ID, FieldID: extraID, ValueText: "A-12"}); err != nil {
					t.Fatal(err)
				}
				ws, err := ListWorkspace(c, src.ID)
				if err != nil {
					t.Fatal(err)
				}
				var sawAuthor, sawUnsetSuggested, sawExtra bool
				for _, e := range ws {
					switch e.Field.Key {
					case "author":
						sawAuthor = true
						if !e.Suggested || e.Value == nil || e.Value.ValueText != "Alice" {
							t.Fatalf("author %+v", e)
						}
					case "publisher", "publication_date", "isbn":
						if e.Suggested && e.Value == nil {
							sawUnsetSuggested = true
						}
					case "shelf_mark":
						sawExtra = true
						if e.Suggested || e.Value == nil || e.Value.ValueText != "A-12" {
							t.Fatalf("extra %+v", e)
						}
					}
				}
				if !sawAuthor || !sawUnsetSuggested || !sawExtra {
					t.Fatalf("author=%v unset=%v extra=%v entries=%d", sawAuthor, sawUnsetSuggested, sawExtra, len(ws))
				}
			},
		},
		{
			name: "source delete cascades metadata",
			run: func(t *testing.T, c *database.Catalog) {
				mustUser(t, c)
				src := mustBookSource(t, c)
				author := mustField(t, c, "author")
				if _, err := Set(c, userID, Input{SourceID: src.ID, FieldID: author.ID, ValueText: "x"}); err != nil {
					t.Fatal(err)
				}
				db, err := c.DB()
				if err != nil {
					t.Fatal(err)
				}
				if _, err := db.Exec(`DELETE FROM sources WHERE id = ?`, src.ID); err != nil {
					t.Fatal(err)
				}
				if metaCount(t, c) != 0 {
					t.Fatalf("count %d", metaCount(t, c))
				}
			},
		},
		{
			name: "reject bad ids and empty text set",
			run: func(t *testing.T, c *database.Catalog) {
				mustUser(t, c)
				src := mustBookSource(t, c)
				author := mustField(t, c, "author")
				missing := make([]byte, 16)
				missing[15] = 9
				if _, err := Set(c, userID, Input{SourceID: missing, FieldID: author.ID, ValueText: "x"}); !errors.Is(err, ErrInvalid) {
					t.Fatalf("bad source %v", err)
				}
				if _, err := Set(c, userID, Input{SourceID: src.ID, FieldID: missing, ValueText: "x"}); !errors.Is(err, ErrInvalid) {
					t.Fatalf("bad field %v", err)
				}
				if _, err := Set(c, nil, Input{SourceID: src.ID, FieldID: author.ID, ValueText: "x"}); !errors.Is(err, ErrInvalid) {
					t.Fatalf("nil user %v", err)
				}
				if _, err := Set(c, userID, Input{SourceID: src.ID, FieldID: author.ID}); !errors.Is(err, ErrInvalid) {
					t.Fatalf("empty text %v", err)
				}
				pub := mustField(t, c, "publication_date")
				if _, err := Set(c, userID, Input{SourceID: src.ID, FieldID: pub.ID, DateValueID: missing}); !errors.Is(err, ErrInvalid) {
					t.Fatalf("bad date %v", err)
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
