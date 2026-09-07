package handlers

import (
	"testing"

	"github.com/mendahu/provenencia/api/proto/engine"
	"google.golang.org/protobuf/proto"
)

func TestListSources(t *testing.T) {
	runRPC(t, ListSources, []rpcTest{
		{name: "bad proto", raw: []byte{0xff}, wantErr: true},
		{
			name: "empty then create",
			reqFn: func(t *testing.T) proto.Message {
				dir, _, _ := sourceFixture(t)
				return &engine.ListSourcesRequest{ProjectDir: dir}
			},
			want: &engine.ListSourcesResponse{},
			after: func(t *testing.T, out []byte, req proto.Message) {
				var list engine.ListSourcesResponse
				if err := proto.Unmarshal(out, &list); err != nil {
					t.Fatal(err)
				}
				if len(list.Sources) != 0 {
					t.Fatalf("want empty got %d", len(list.Sources))
				}
			},
		},
	})
}

func TestCreateSourceAndWorkspace(t *testing.T) {
	runRPC(t, CreateSource, []rpcTest{
		{name: "bad proto", raw: []byte{0xff}, wantErr: true},
		{
			name: "creates source",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, typeID := sourceFixture(t)
				return &engine.CreateSourceRequest{
					ProjectDir:   dir,
					UserId:       userID,
					SourceTypeId: typeID,
					Title:        "Passport",
					Description:  "1948",
				}
			},
			want: nil,
			after: func(t *testing.T, out []byte, req proto.Message) {
				var created engine.CreateSourceResponse
				if err := proto.Unmarshal(out, &created); err != nil {
					t.Fatal(err)
				}
				if created.Source.GetTitle() != "Passport" || created.Source.GetDescription() != "1948" {
					t.Fatalf("%+v", created.Source)
				}
				cr := req.(*engine.CreateSourceRequest)
				wsOut, err := GetSourceWorkspace(marshalProto(t, &engine.GetSourceWorkspaceRequest{
					ProjectDir: cr.ProjectDir,
					SourceId:   created.Source.Id,
				}))
				if err != nil {
					t.Fatal(err)
				}
				var ws engine.GetSourceWorkspaceResponse
				if err := proto.Unmarshal(wsOut, &ws); err != nil {
					t.Fatal(err)
				}
				if ws.Source.GetTitle() != "Passport" {
					t.Fatalf("%+v", ws.Source)
				}
			},
		},
	})
}

func TestSourceNotes(t *testing.T) {
	runRPC(t, AddSourceNote, []rpcTest{
		{
			name: "add update delete note",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, typeID := sourceFixture(t)
				cout, err := CreateSource(marshalProto(t, &engine.CreateSourceRequest{
					ProjectDir: dir, UserId: userID, SourceTypeId: typeID, Title: "Book",
				}))
				if err != nil {
					t.Fatal(err)
				}
				var created engine.CreateSourceResponse
				if err := proto.Unmarshal(cout, &created); err != nil {
					t.Fatal(err)
				}
				return &engine.AddSourceNoteRequest{
					ProjectDir: dir, UserId: userID, SourceId: created.Source.Id, Body: "First",
				}
			},
			want: nil,
			after: func(t *testing.T, out []byte, req proto.Message) {
				var added engine.AddSourceNoteResponse
				if err := proto.Unmarshal(out, &added); err != nil {
					t.Fatal(err)
				}
				if added.Note.GetBody() != "First" {
					t.Fatalf("%+v", added.Note)
				}
				ar := req.(*engine.AddSourceNoteRequest)
				uout, err := UpdateSourceNote(marshalProto(t, &engine.UpdateSourceNoteRequest{
					ProjectDir: ar.ProjectDir, UserId: ar.UserId, NoteId: added.Note.Id, Body: "Revised",
				}))
				if err != nil {
					t.Fatal(err)
				}
				var updated engine.UpdateSourceNoteResponse
				if err := proto.Unmarshal(uout, &updated); err != nil {
					t.Fatal(err)
				}
				if updated.Note.GetBody() != "Revised" {
					t.Fatalf("%+v", updated.Note)
				}
				if _, err := DeleteSourceNote(marshalProto(t, &engine.DeleteSourceNoteRequest{
					ProjectDir: ar.ProjectDir, UserId: ar.UserId, NoteId: added.Note.Id,
				})); err != nil {
					t.Fatal(err)
				}
			},
		},
	})
}

func TestSetSourceMetadata(t *testing.T) {
	runRPC(t, SetSourceMetadata, []rpcTest{
		{
			name: "set text metadata",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, typeID := sourceFixture(t)
				cout, err := CreateSource(marshalProto(t, &engine.CreateSourceRequest{
					ProjectDir: dir, UserId: userID, SourceTypeId: typeID, Title: "Book",
				}))
				if err != nil {
					t.Fatal(err)
				}
				var created engine.CreateSourceResponse
				if err := proto.Unmarshal(cout, &created); err != nil {
					t.Fatal(err)
				}
				fout, err := ListMetadataFields(marshalProto(t, &engine.ListMetadataFieldsRequest{ProjectDir: dir}))
				if err != nil {
					t.Fatal(err)
				}
				var fields engine.ListMetadataFieldsResponse
				if err := proto.Unmarshal(fout, &fields); err != nil {
					t.Fatal(err)
				}
				var fieldID string
				for _, f := range fields.Fields {
					if f.DataType == "text" {
						fieldID = f.Id
						break
					}
				}
				if fieldID == "" {
					t.Fatal("no text field")
				}
				return &engine.SetSourceMetadataRequest{
					ProjectDir: dir, UserId: userID, SourceId: created.Source.Id, FieldId: fieldID, ValueText: "Ada",
				}
			},
			want: &engine.SetSourceMetadataResponse{ValueText: "Ada"},
		},
	})
}
