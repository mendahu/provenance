package handlers

import (
	"github.com/mendahu/provenencia/api/proto/engine"
	"github.com/mendahu/provenencia/core/database/files"
	"google.golang.org/protobuf/proto"
)

func CountFiles(in []byte) ([]byte, error) {
	var req engine.CountFilesRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("count_files", err)
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	n, err := files.Count(c)
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.CountFilesResponse{Count: int32(n)})
}
