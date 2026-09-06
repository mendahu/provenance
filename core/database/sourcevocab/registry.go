package sourcevocab

import (
	"github.com/mendahu/provenencia/core/database/sourcefields"
)

// Declarative provenencia seed registry (dogfood set for S2-07).

type seedType struct {
	Key, Label, Description string
}

type seedField struct {
	Key, Label, DataType, Description string
}

type seedSuggestion struct {
	TypeKey   string
	FieldKey  string
	SortOrder int
}

var seedTypes = []seedType{
	{Key: "photograph", Label: "Photograph", Description: "Photographic image or print."},
	{Key: "book", Label: "Book", Description: "Published book or monograph."},
	{Key: "passport", Label: "Passport", Description: "Government-issued travel identity document."},
	{Key: "birth_record", Label: "Birth record", Description: "Civil or parish record of a birth (certificate, register entry, abstract, etc.)."},
	{Key: "marriage_record", Label: "Marriage record", Description: "Civil or parish record of a marriage (certificate, register entry, abstract, etc.)."},
}

var seedFields = []seedField{
	{Key: "photographer", Label: "Photographer", DataType: sourcefields.DataTypeText},
	{Key: "taken_date", Label: "Taken date", DataType: sourcefields.DataTypeDate},
	{Key: "medium", Label: "Medium", DataType: sourcefields.DataTypeText},
	{Key: "author", Label: "Author", DataType: sourcefields.DataTypeText},
	{Key: "publisher", Label: "Publisher", DataType: sourcefields.DataTypeText},
	{Key: "publication_date", Label: "Publication date", DataType: sourcefields.DataTypeDate},
	{Key: "isbn", Label: "ISBN", DataType: sourcefields.DataTypeText},
	{Key: "document_number", Label: "Document number", DataType: sourcefields.DataTypeText},
	{Key: "issue_date", Label: "Issue date", DataType: sourcefields.DataTypeDate},
	{Key: "record_date", Label: "Record date", DataType: sourcefields.DataTypeDate},
	{Key: "expiration_date", Label: "Expiration date", DataType: sourcefields.DataTypeDate},
}

var seedSuggestions = []seedSuggestion{
	{TypeKey: "photograph", FieldKey: "photographer", SortOrder: 0},
	{TypeKey: "photograph", FieldKey: "taken_date", SortOrder: 1},
	{TypeKey: "photograph", FieldKey: "medium", SortOrder: 2},

	{TypeKey: "book", FieldKey: "author", SortOrder: 0},
	{TypeKey: "book", FieldKey: "publisher", SortOrder: 1},
	{TypeKey: "book", FieldKey: "publication_date", SortOrder: 2},
	{TypeKey: "book", FieldKey: "isbn", SortOrder: 3},

	{TypeKey: "passport", FieldKey: "document_number", SortOrder: 0},
	{TypeKey: "passport", FieldKey: "issue_date", SortOrder: 1},
	{TypeKey: "passport", FieldKey: "expiration_date", SortOrder: 2},

	{TypeKey: "birth_record", FieldKey: "document_number", SortOrder: 0},
	{TypeKey: "birth_record", FieldKey: "record_date", SortOrder: 1},
	{TypeKey: "birth_record", FieldKey: "issue_date", SortOrder: 2},

	{TypeKey: "marriage_record", FieldKey: "document_number", SortOrder: 0},
	{TypeKey: "marriage_record", FieldKey: "record_date", SortOrder: 1},
	{TypeKey: "marriage_record", FieldKey: "issue_date", SortOrder: 2},
}
