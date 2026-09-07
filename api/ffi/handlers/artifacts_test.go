package handlers

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/mendahu/provenencia/api/proto/engine"
	"google.golang.org/protobuf/proto"
)

func TestCreateArtifactAndIngest(t *testing.T) {
	runRPC(t, CreateArtifact, []rpcTest{
		{name: "bad proto", raw: []byte{0xff}, wantErr: true},
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
