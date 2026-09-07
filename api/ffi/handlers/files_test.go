package handlers

import (
	"testing"

	"github.com/mendahu/provenencia/api/proto/engine"
	"google.golang.org/protobuf/proto"
)

func TestCountFiles(t *testing.T) {
	runRPC(t, CountFiles, []rpcTest{
		{name: "bad proto", raw: []byte{0xff, 0xff, 0xff, 0xff}, wantErr: true},
		{
			name: "empty project has zero files",
			reqFn: func(t *testing.T) proto.Message {
				dir, _, _ := sourceFixture(t)
				return &engine.CountFilesRequest{ProjectDir: dir}
			},
			want:  &engine.CountFilesResponse{Count: 0},
			exact: true,
		},
	})
}
