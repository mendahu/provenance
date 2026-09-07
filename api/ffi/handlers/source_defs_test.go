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
