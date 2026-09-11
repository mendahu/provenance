package handlers

import (
	"testing"

	"github.com/mendahu/provenencia/api/proto/engine"
	"google.golang.org/protobuf/proto"
)

func TestSourceCredibility(t *testing.T) {
	runRPC(t, ListSourceCredibilityGrades, []rpcTest{
		{name: "bad proto", raw: []byte{0xff}, wantErr: true},
		{
			name: "list seeded grades",
			reqFn: func(t *testing.T) proto.Message {
				dir, _, _ := sourceFixture(t)
				return &engine.ListSourceCredibilityGradesRequest{ProjectDir: dir}
			},
			after: func(t *testing.T, out []byte, _ proto.Message) {
				var resp engine.ListSourceCredibilityGradesResponse
				if err := proto.Unmarshal(out, &resp); err != nil {
					t.Fatal(err)
				}
				if len(resp.Grades) != 3 {
					t.Fatalf("grades=%d", len(resp.Grades))
				}
				if resp.Grades[0].GetKey() != "low_trust" || resp.Grades[1].GetKey() != "standard" {
					t.Fatalf("%+v", resp.Grades)
				}
			},
		},
	})

	runRPC(t, UpsertSourceCredibilityAssessment, []rpcTest{
		{name: "bad proto", raw: []byte{0xff}, wantErr: true},
		{
			name: "upsert by grade id then workspace",
			reqFn: func(t *testing.T) proto.Message {
				dir, userID, typeID := sourceFixture(t)
				cout, err := CreateSource(marshalProto(t, &engine.CreateSourceRequest{
					ProjectDir: dir, UserId: userID, SourceTypeId: typeID, Title: "Bible",
				}))
				if err != nil {
					t.Fatal(err)
				}
				var created engine.CreateSourceResponse
				if err := proto.Unmarshal(cout, &created); err != nil {
					t.Fatal(err)
				}
				gout, err := ListSourceCredibilityGrades(marshalProto(t, &engine.ListSourceCredibilityGradesRequest{
					ProjectDir: dir,
				}))
				if err != nil {
					t.Fatal(err)
				}
				var grades engine.ListSourceCredibilityGradesResponse
				if err := proto.Unmarshal(gout, &grades); err != nil {
					t.Fatal(err)
				}
				high := grades.Grades[2]
				return &engine.UpsertSourceCredibilityAssessmentRequest{
					ProjectDir: dir, UserId: userID, SourceId: created.Source.Id,
					GradeId: high.Id, Argument: "original",
				}
			},
			after: func(t *testing.T, out []byte, req proto.Message) {
				var resp engine.UpsertSourceCredibilityAssessmentResponse
				if err := proto.Unmarshal(out, &resp); err != nil {
					t.Fatal(err)
				}
				if resp.Assessment.GetGradeKey() != "high_trust" || resp.Assessment.GetArgument() != "original" {
					t.Fatalf("%+v", resp.Assessment)
				}
				cr := req.(*engine.UpsertSourceCredibilityAssessmentRequest)
				wout, err := GetSourceWorkspace(marshalProto(t, &engine.GetSourceWorkspaceRequest{
					ProjectDir: cr.ProjectDir, SourceId: cr.SourceId,
				}))
				if err != nil {
					t.Fatal(err)
				}
				var ws engine.GetSourceWorkspaceResponse
				if err := proto.Unmarshal(wout, &ws); err != nil {
					t.Fatal(err)
				}
				if ws.Credibility.GetGradeKey() != "high_trust" {
					t.Fatalf("workspace credibility %+v", ws.Credibility)
				}
			},
		},
	})
}
