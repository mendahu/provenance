package handlers

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/mendahu/provenencia/api/proto/engine"
	"github.com/mendahu/provenencia/core/onboarding"
	"google.golang.org/protobuf/proto"
)

func sourceFixture(t *testing.T) (projectDir, userID, typeID string) {
	t.Helper()
	res, err := onboarding.Complete(t.TempDir(), t.TempDir(), "Jake", "Sources")
	if err != nil {
		t.Fatal(err)
	}
	listOut, err := ListSourceTypes(marshalProto(t, &engine.ListSourceTypesRequest{ProjectDir: res.ProjectDir}))
	if err != nil {
		t.Fatal(err)
	}
	var types engine.ListSourceTypesResponse
	if err := proto.Unmarshal(listOut, &types); err != nil {
		t.Fatal(err)
	}
	if len(types.Types) == 0 {
		t.Fatal("expected seeded types")
	}
	return res.ProjectDir, res.Identity.UserID.String(), types.Types[0].Id
}

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

func TestCreateArtifactAndIngest(t *testing.T) {
	runRPC(t, CreateArtifact, []rpcTest{
		{
			name: "fileless then ingest",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, typeID := sourceFixture(t)
				cout, err := CreateSource(marshalProto(t, &engine.CreateSourceRequest{
					ProjectDir: dir, UserId: userID, SourceTypeId: typeID, Title: "Photo",
				}))
				if err != nil {
					t.Fatal(err)
				}
				var created engine.CreateSourceResponse
				if err := proto.Unmarshal(cout, &created); err != nil {
					t.Fatal(err)
				}
				return &engine.CreateArtifactRequest{
					ProjectDir: dir, UserId: userID, SourceId: created.Source.Id, Description: "front",
				}
			},
			want: nil,
			after: func(t *testing.T, out []byte, req proto.Message) {
				var art engine.CreateArtifactResponse
				if err := proto.Unmarshal(out, &art); err != nil {
					t.Fatal(err)
				}
				if art.Artifact.GetDescription() != "front" {
					t.Fatalf("%+v", art.Artifact)
				}
				cr := req.(*engine.CreateArtifactRequest)
				path := filepath.Join(t.TempDir(), "scan.jpg")
				if err := os.WriteFile(path, []byte("jpeg-bytes"), 0o644); err != nil {
					t.Fatal(err)
				}
				iout, err := IngestArtifactFile(marshalProto(t, &engine.IngestArtifactFileRequest{
					ProjectDir: cr.ProjectDir, UserId: cr.UserId, ArtifactId: art.Artifact.Id, Path: path,
				}))
				if err != nil {
					t.Fatal(err)
				}
				var ingested engine.IngestArtifactFileResponse
				if err := proto.Unmarshal(iout, &ingested); err != nil {
					t.Fatal(err)
				}
				if ingested.File.GetOriginalFilename() != "scan.jpg" || ingested.GetReused() {
					t.Fatalf("%+v", ingested)
				}
				if ingested.Artifact.GetFileId() == "" {
					t.Fatal("expected file_id")
				}
			},
		},
	})
}

func TestVocabulary(t *testing.T) {
	runRPC(t, CreateSourceType, []rpcTest{
		{
			name: "create user type and field",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, _ := sourceFixture(t)
				return &engine.CreateSourceTypeRequest{
					ProjectDir: dir, UserId: userID, Key: "deed", Label: "Deed",
				}
			},
			want: nil,
			after: func(t *testing.T, out []byte, req proto.Message) {
				var typ engine.CreateSourceTypeResponse
				if err := proto.Unmarshal(out, &typ); err != nil {
					t.Fatal(err)
				}
				if typ.Type.GetKey() != "deed" || typ.Type.GetOrigin() != "user" || typ.Type.GetLabel() != "Deed" {
					t.Fatalf("%+v", typ.Type)
				}
				cr := req.(*engine.CreateSourceTypeRequest)
				fout, err := CreateMetadataField(marshalProto(t, &engine.CreateMetadataFieldRequest{
					ProjectDir: cr.ProjectDir, UserId: cr.UserId, Key: "folio", Label: "Folio", DataType: "text",
				}))
				if err != nil {
					t.Fatal(err)
				}
				var field engine.CreateMetadataFieldResponse
				if err := proto.Unmarshal(fout, &field); err != nil {
					t.Fatal(err)
				}
				if field.Field.GetKey() != "folio" || field.Field.GetOrigin() != "user" {
					t.Fatalf("%+v", field.Field)
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
