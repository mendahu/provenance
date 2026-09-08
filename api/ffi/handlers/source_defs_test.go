package handlers

import (
	"testing"

	"github.com/mendahu/provenencia/api/proto/engine"
	"github.com/mendahu/provenencia/core/database/sourcefields"
	"github.com/mendahu/provenencia/core/onboarding"
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
			name: "updates label and description, key and data type unchanged",
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
					Label: "Album Code", DataType: "text", Description: "updated",
				}
			},
			after: func(t *testing.T, out []byte, _ proto.Message) {
				var resp engine.UpdateMetadataFieldResponse
				if err := proto.Unmarshal(out, &resp); err != nil {
					t.Fatal(err)
				}
				if resp.Field.GetKey() != "album-code" || resp.Field.GetLabel() != "Album Code" ||
					resp.Field.GetDataType() != "text" || resp.Field.GetDescription() != "updated" {
					t.Fatalf("%+v", resp.Field)
				}
			},
		},
		{
			name: "rejects data type change",
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
			wantErr: true,
		},
		{
			name: "updates a seeded field",
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
					ProjectDir: dir, UserId: userID, FieldId: seededID,
					Label: "Renamed starter", DataType: "text", Description: "edited",
				}
			},
			after: func(t *testing.T, out []byte, _ proto.Message) {
				var resp engine.UpdateMetadataFieldResponse
				if err := proto.Unmarshal(out, &resp); err != nil {
					t.Fatal(err)
				}
				if resp.Field.GetOrigin() != "provenencia" || resp.Field.GetLabel() != "Renamed starter" ||
					resp.Field.GetDescription() != "edited" || resp.Field.GetKey() == "" {
					t.Fatalf("%+v", resp.Field)
				}
			},
		},
		{
			name: "rejects editing a plugin field",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, _ := sourceFixture(t)
				c, err := onboarding.OpenCatalog(dir)
				if err != nil {
					t.Fatal(err)
				}
				defer c.Close()
				id, err := sourcefields.Upsert(c, sourcefields.Field{
					Key: "memorial_id", Origin: "plugin:findagrave", Label: "Memorial id", DataType: sourcefields.DataTypeText,
				})
				if err != nil {
					t.Fatal(err)
				}
				return &engine.UpdateMetadataFieldRequest{
					ProjectDir: dir, UserId: userID, FieldId: uuidString(id),
					Label: "Changed", DataType: "text",
				}
			},
			wantErr: true,
		},
	})
}

func TestDeleteSourceType(t *testing.T) {
	runRPC(t, DeleteSourceType, []rpcTest{
		{name: "bad proto", raw: []byte{0xff}, wantErr: true},
		{
			name: "deletes unused user type",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, _ := sourceFixture(t)
				out, err := CreateSourceType(marshalProto(t, &engine.CreateSourceTypeRequest{
					ProjectDir: dir, UserId: userID, Key: "deed", Label: "Deed",
				}))
				if err != nil {
					t.Fatal(err)
				}
				var created engine.CreateSourceTypeResponse
				if err := proto.Unmarshal(out, &created); err != nil {
					t.Fatal(err)
				}
				return &engine.DeleteSourceTypeRequest{
					ProjectDir: dir, UserId: userID, TypeId: created.Type.GetId(),
				}
			},
			want: &engine.DeleteSourceTypeResponse{},
		},
		{
			name: "refuses type in use",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, typeID := sourceFixture(t)
				if _, err := CreateSource(marshalProto(t, &engine.CreateSourceRequest{
					ProjectDir: dir, UserId: userID, SourceTypeId: typeID, Title: "One",
				})); err != nil {
					t.Fatal(err)
				}
				return &engine.DeleteSourceTypeRequest{
					ProjectDir: dir, UserId: userID, TypeId: typeID,
				}
			},
			wantErr: true,
		},
		{
			name: "deletes unused seeded type",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, typeID := sourceFixture(t)
				return &engine.DeleteSourceTypeRequest{
					ProjectDir: dir, UserId: userID, TypeId: typeID,
				}
			},
			want: &engine.DeleteSourceTypeResponse{},
		},
	})
}

func TestDeleteMetadataField(t *testing.T) {
	runRPC(t, DeleteMetadataField, []rpcTest{
		{name: "bad proto", raw: []byte{0xff}, wantErr: true},
		{
			name: "deletes unused user field",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, _ := sourceFixture(t)
				out, err := CreateMetadataField(marshalProto(t, &engine.CreateMetadataFieldRequest{
					ProjectDir: dir, UserId: userID, Label: "Folio", DataType: "text",
				}))
				if err != nil {
					t.Fatal(err)
				}
				var created engine.CreateMetadataFieldResponse
				if err := proto.Unmarshal(out, &created); err != nil {
					t.Fatal(err)
				}
				return &engine.DeleteMetadataFieldRequest{
					ProjectDir: dir, UserId: userID, FieldId: created.Field.GetId(),
				}
			},
			want: &engine.DeleteMetadataFieldResponse{},
		},
		{
			name: "refuses field in use",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, typeID := sourceFixture(t)
				fout, err := CreateMetadataField(marshalProto(t, &engine.CreateMetadataFieldRequest{
					ProjectDir: dir, UserId: userID, Label: "Folio", DataType: "text",
				}))
				if err != nil {
					t.Fatal(err)
				}
				var field engine.CreateMetadataFieldResponse
				if err := proto.Unmarshal(fout, &field); err != nil {
					t.Fatal(err)
				}
				sout, err := CreateSource(marshalProto(t, &engine.CreateSourceRequest{
					ProjectDir: dir, UserId: userID, SourceTypeId: typeID, Title: "One",
				}))
				if err != nil {
					t.Fatal(err)
				}
				var src engine.CreateSourceResponse
				if err := proto.Unmarshal(sout, &src); err != nil {
					t.Fatal(err)
				}
				if _, err := SetSourceMetadata(marshalProto(t, &engine.SetSourceMetadataRequest{
					ProjectDir: dir, UserId: userID, SourceId: src.Source.GetId(),
					FieldId: field.Field.GetId(), ValueText: "12",
				})); err != nil {
					t.Fatal(err)
				}
				return &engine.DeleteMetadataFieldRequest{
					ProjectDir: dir, UserId: userID, FieldId: field.Field.GetId(),
				}
			},
			wantErr: true,
		},
	})
}
