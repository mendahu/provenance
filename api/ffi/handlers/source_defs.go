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
	got, err := sourcefields.Create(c, req.GetLabel(), req.GetDataType(), req.GetDescription())
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.CreateMetadataFieldResponse{Field: metadataFieldProto(got)})
}

func UpdateMetadataField(in []byte) ([]byte, error) {
	var req engine.UpdateMetadataFieldRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("update_metadata_field", err)
	}
	if _, err := parseUserID(req.GetUserId()); err != nil {
		return nil, err
	}
	fieldID, err := parseID(req.GetFieldId())
	if err != nil {
		return nil, err
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	got, err := sourcefields.Update(c, fieldID, req.GetLabel(), req.GetDataType(), req.GetDescription())
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.UpdateMetadataFieldResponse{Field: metadataFieldProto(got)})
}

func DeleteSourceType(in []byte) ([]byte, error) {
	var req engine.DeleteSourceTypeRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("delete_source_type", err)
	}
	if _, err := parseUserID(req.GetUserId()); err != nil {
		return nil, err
	}
	typeID, err := parseID(req.GetTypeId())
	if err != nil {
		return nil, err
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	if err := sourcetypes.Delete(c, typeID); err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.DeleteSourceTypeResponse{})
}

func DeleteMetadataField(in []byte) ([]byte, error) {
	var req engine.DeleteMetadataFieldRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("delete_metadata_field", err)
	}
	if _, err := parseUserID(req.GetUserId()); err != nil {
		return nil, err
	}
	fieldID, err := parseID(req.GetFieldId())
	if err != nil {
		return nil, err
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	if err := sourcefields.Delete(c, fieldID); err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.DeleteMetadataFieldResponse{})
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
