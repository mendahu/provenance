package handlers

import (
	"github.com/mendahu/provenencia/api/proto/engine"
	"github.com/mendahu/provenencia/core/database/files"
	"github.com/mendahu/provenencia/core/database/sourcefields"
	"github.com/mendahu/provenencia/core/database/sources"
	"github.com/mendahu/provenencia/core/database/sourcetypes"
	"google.golang.org/protobuf/proto"
)

func GetWorkspaceNavCounts(in []byte) ([]byte, error) {
	var req engine.GetWorkspaceNavCountsRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("get_workspace_nav_counts", err)
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()

	sourceCount, err := sources.Count(c)
	if err != nil {
		return nil, err
	}
	types, err := sourcetypes.CountByOrigin(c)
	if err != nil {
		return nil, err
	}
	fields, err := sourcefields.CountByOrigin(c)
	if err != nil {
		return nil, err
	}
	fileCount, err := files.Count(c)
	if err != nil {
		return nil, err
	}

	return proto.Marshal(&engine.GetWorkspaceNavCountsResponse{
		Sources:      int32(sourceCount),
		SourceTypes:  typeOriginProto(types),
		SourceFields: fieldOriginProto(fields),
		Files:        int32(fileCount),
	})
}

func typeOriginProto(c sourcetypes.OriginCounts) *engine.VocabularyOriginCounts {
	return &engine.VocabularyOriginCounts{
		Total:  int32(c.Total),
		Seeded: int32(c.Seeded),
		User:   int32(c.User),
		Plugin: int32(c.Plugin),
	}
}

func fieldOriginProto(c sourcefields.OriginCounts) *engine.VocabularyOriginCounts {
	return &engine.VocabularyOriginCounts{
		Total:  int32(c.Total),
		Seeded: int32(c.Seeded),
		User:   int32(c.User),
		Plugin: int32(c.Plugin),
	}
}
