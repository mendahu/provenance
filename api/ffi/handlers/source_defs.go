package handlers

import (
	"github.com/mendahu/provenencia/api/proto/engine"
	"github.com/mendahu/provenencia/core/database/sourcefields"
	"github.com/mendahu/provenencia/core/database/sourcetypes"
	"google.golang.org/protobuf/proto"
)

func ListSourceTypes(in []byte) ([]byte, error) {
	var req engine.ListSourceTypesRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("list_source_types", err)
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	rows, err := sourcetypes.List(c)
	if err != nil {
		return nil, err
	}
	out := &engine.ListSourceTypesResponse{}
	for _, t := range rows {
		out.Types = append(out.Types, sourceTypeProto(t))
	}
	return proto.Marshal(out)
}

func CreateSourceType(in []byte) ([]byte, error) {
	var req engine.CreateSourceTypeRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("create_source_type", err)
	}
	if _, err := parseUserID(req.GetUserId()); err != nil {
		return nil, err
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	id, err := sourcetypes.Upsert(c, sourcetypes.Type{
		Key:         req.GetKey(),
		Origin:      sourcetypes.OriginUser,
		Label:       req.GetLabel(),
		Description: req.GetDescription(),
	})
	if err != nil {
		return nil, err
	}
	got, err := sourcetypes.Lookup(c, req.GetKey(), sourcetypes.OriginUser)
	if err != nil {
		return nil, err
	}
	_ = id
	return proto.Marshal(&engine.CreateSourceTypeResponse{Type: sourceTypeProto(got)})
}

func ListMetadataFields(in []byte) ([]byte, error) {
	var req engine.ListMetadataFieldsRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("list_metadata_fields", err)
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	rows, err := sourcefields.List(c)
	if err != nil {
		return nil, err
	}
	out := &engine.ListMetadataFieldsResponse{}
	for _, f := range rows {
		out.Fields = append(out.Fields, metadataFieldProto(f))
	}
	return proto.Marshal(out)
}

func CreateMetadataField(in []byte) ([]byte, error) {
	var req engine.CreateMetadataFieldRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("create_metadata_field", err)
	}
	if _, err := parseUserID(req.GetUserId()); err != nil {
		return nil, err
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	_, err = sourcefields.Upsert(c, sourcefields.Field{
		Key:         req.GetKey(),
		Origin:      sourcefields.OriginUser,
		Label:       req.GetLabel(),
		DataType:    req.GetDataType(),
		Description: req.GetDescription(),
	})
	if err != nil {
		return nil, err
	}
	got, err := sourcefields.Lookup(c, req.GetKey(), sourcefields.OriginUser)
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.CreateMetadataFieldResponse{Field: metadataFieldProto(got)})
}

func sourceTypeProto(t sourcetypes.Type) *engine.SourceType {
	return &engine.SourceType{
		Id:          uuidString(t.ID),
		Key:         t.Key,
		Origin:      t.Origin,
		Label:       t.Label,
		Description: t.Description,
	}
}

func metadataFieldProto(f sourcefields.Field) *engine.MetadataField {
	return &engine.MetadataField{
		Id:          uuidString(f.ID),
		Key:         f.Key,
		Origin:      f.Origin,
		Label:       f.Label,
		DataType:    f.DataType,
		Description: f.Description,
	}
}
