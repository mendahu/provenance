package handlers

import (
	"testing"

	"github.com/mendahu/provenencia/api/proto/engine"
	"google.golang.org/protobuf/proto"
)

func TestSourceDefs(t *testing.T) {
	runRPC(t, CreateSourceType, []rpcTest{
		{name: "bad proto", raw: []byte{0xff}, wantErr: true},
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
					ProjectDir: cr.ProjectDir, UserId: cr.UserId, Label: "Folio", DataType: "text",
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

func TestCreateMetadataFieldMintsKeyFromLabel(t *testing.T) {
	runRPC(t, CreateMetadataField, []rpcTest{
		{name: "bad proto", raw: []byte{0xff}, wantErr: true},
		{
			name: "mints slug key",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, _ := sourceFixture(t)
				return &engine.CreateMetadataFieldRequest{
					ProjectDir: dir, UserId: userID, Label: "Grandma's album code", DataType: "text",
				}
			},
			after: func(t *testing.T, out []byte, _ proto.Message) {
				var resp engine.CreateMetadataFieldResponse
				if err := proto.Unmarshal(out, &resp); err != nil {
					t.Fatal(err)
				}
				if resp.Field.GetKey() != "grandmas-album-code" || resp.Field.GetOrigin() != "user" {
					t.Fatalf("%+v", resp.Field)
				}
			},
		},
		{
			name: "rejects unslugifiable label",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, _ := sourceFixture(t)
				return &engine.CreateMetadataFieldRequest{ProjectDir: dir, UserId: userID, Label: "...", DataType: "text"}
			},
			wantErr: true,
		},
		{
			name: "rejects duplicate key under user origin",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, _ := sourceFixture(t)
				return &engine.CreateMetadataFieldRequest{ProjectDir: dir, UserId: userID, Label: "Folio", DataType: "text"}
			},
			calls:   2,
			wantErr: true,
		},
	})
}

func TestUpdateMetadataField(t *testing.T) {
	runRPC(t, UpdateMetadataField, []rpcTest{
		{name: "bad proto", raw: []byte{0xff}, wantErr: true},
		{
			name: "updates label type description, key unchanged",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, _ := sourceFixture(t)
				out, err := CreateMetadataField(marshalProto(t, &engine.CreateMetadataFieldRequest{
					ProjectDir: dir, UserId: userID, Label: "Album code", DataType: "text",
				}))
				if err != nil {
					t.Fatal(err)
				}
				var created engine.CreateMetadataFieldResponse
				if err := proto.Unmarshal(out, &created); err != nil {
					t.Fatal(err)
				}
				return &engine.UpdateMetadataFieldRequest{
					ProjectDir: dir, UserId: userID, FieldId: created.Field.GetId(),
					Label: "Album Code", DataType: "date", Description: "updated",
				}
			},
			after: func(t *testing.T, out []byte, _ proto.Message) {
				var resp engine.UpdateMetadataFieldResponse
				if err := proto.Unmarshal(out, &resp); err != nil {
					t.Fatal(err)
				}
				if resp.Field.GetKey() != "album-code" || resp.Field.GetLabel() != "Album Code" ||
					resp.Field.GetDataType() != "date" || resp.Field.GetDescription() != "updated" {
					t.Fatalf("%+v", resp.Field)
				}
			},
		},
		{
			name: "rejects editing a seeded field",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, _ := sourceFixture(t)
				listOut, err := ListMetadataFields(marshalProto(t, &engine.ListMetadataFieldsRequest{ProjectDir: dir}))
				if err != nil {
					t.Fatal(err)
				}
				var list engine.ListMetadataFieldsResponse
				if err := proto.Unmarshal(listOut, &list); err != nil {
					t.Fatal(err)
				}
				var seededID string
				for _, f := range list.Fields {
					if f.GetOrigin() == "provenencia" {
						seededID = f.GetId()
						break
					}
				}
				if seededID == "" {
					t.Fatal("expected a seeded field")
				}
				return &engine.UpdateMetadataFieldRequest{
					ProjectDir: dir, UserId: userID, FieldId: seededID, Label: "Changed", DataType: "text",
				}
			},
			wantErr: true,
		},
	})
}
