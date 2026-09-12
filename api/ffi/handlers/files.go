package handlers

import (
	"github.com/mendahu/provenencia/api/proto/engine"
	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/files"
	"google.golang.org/protobuf/proto"
)

func CountFiles(in []byte) ([]byte, error) {
	var req engine.CountFilesRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("count_files", err)
	}
	var out *engine.CountFilesResponse
	err := withProjectCatalog(req.GetProjectDir(), func(c *database.Catalog) error {
		n, err := files.Count(c)
		if err != nil {
			return err
		}
		out = &engine.CountFilesResponse{Count: int32(n)}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return proto.Marshal(out)
}
