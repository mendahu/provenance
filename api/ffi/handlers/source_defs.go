package handlers

import (
	"github.com/mendahu/provenencia/api/proto/engine"
	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/database/sourcefields"
	"github.com/mendahu/provenencia/core/database/sourcetypes"
	"github.com/mendahu/provenencia/core/database/sourcevocab"
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
	got, err := sourcetypes.Create(c, req.GetLabel(), req.GetDescription())
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.CreateSourceTypeResponse{Type: sourceTypeProto(got)})
}

func UpdateSourceType(in []byte) ([]byte, error) {
	var req engine.UpdateSourceTypeRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("update_source_type", err)
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
	got, err := sourcetypes.Update(c, typeID, req.GetLabel(), req.GetDescription())
	if err != nil {
		return nil, err
	}
	if got.UsedBy, err = sourcetypes.UsedBy(c, typeID); err != nil {
		return nil, err
	}
	suggested, err := sourcevocab.ListSuggestions(c, typeID)
	if err != nil {
		return nil, err
	}
	got.SuggestedFields = len(suggested)
	return proto.Marshal(&engine.UpdateSourceTypeResponse{Type: sourceTypeProto(got)})
}

func ListTypeSuggestions(in []byte) ([]byte, error) {
	var req engine.ListTypeSuggestionsRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("list_type_suggestions", err)
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
	out, err := suggestionsProto(c, typeID)
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.ListTypeSuggestionsResponse{Suggestions: out})
}

func AssignTypeField(in []byte) ([]byte, error) {
	var req engine.AssignTypeFieldRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("assign_type_field", err)
	}
	typeID, fieldID, c, err := openSuggestionJoin(req.GetUserId(), req.GetTypeId(), req.GetFieldId(), req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	if err := sourcevocab.AppendSuggestion(c, typeID, fieldID); err != nil {
		return nil, err
	}
	out, err := suggestionsProto(c, typeID)
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.AssignTypeFieldResponse{Suggestions: out})
}

func RemoveTypeField(in []byte) ([]byte, error) {
	var req engine.RemoveTypeFieldRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("remove_type_field", err)
	}
	typeID, fieldID, c, err := openSuggestionJoin(req.GetUserId(), req.GetTypeId(), req.GetFieldId(), req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	if err := sourcevocab.DeleteSuggestion(c, typeID, fieldID); err != nil {
		return nil, err
	}
	out, err := suggestionsProto(c, typeID)
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.RemoveTypeFieldResponse{Suggestions: out})
}

// openSuggestionJoin validates the user and both join sides, then opens the
// catalog — the shared preamble of assign and remove. The caller closes it.
func openSuggestionJoin(userID, typeID, fieldID, projectDir string) ([]byte, []byte, *database.Catalog, error) {
	if _, err := parseUserID(userID); err != nil {
		return nil, nil, nil, err
	}
	tid, err := parseID(typeID)
	if err != nil {
		return nil, nil, nil, err
	}
	fid, err := parseID(fieldID)
	if err != nil {
		return nil, nil, nil, err
	}
	c, err := openProjectCatalog(projectDir)
	if err != nil {
		return nil, nil, nil, err
	}
	return tid, fid, c, nil
}

func suggestionsProto(c *database.Catalog, typeID []byte) ([]*engine.TypeSuggestion, error) {
	rows, err := sourcevocab.ListSuggestions(c, typeID)
	if err != nil {
		return nil, err
	}
	out := make([]*engine.TypeSuggestion, 0, len(rows))
	for _, s := range rows {
		out = append(out, &engine.TypeSuggestion{
			Field:     metadataFieldProto(s.Field),
			SortOrder: int32(s.SortOrder),
		})
	}
	return out, nil
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
	if got.UsedBy, err = sourcefields.UsedBy(c, fieldID); err != nil {
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
		Id:                  uuidString(t.ID),
		Key:                 t.Key,
		Origin:              t.Origin,
		Label:               t.Label,
		Description:         t.Description,
		UsedBy:              int32(t.UsedBy),
		SuggestedFieldCount: int32(t.SuggestedFields),
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
		UsedBy:      int32(f.UsedBy),
	}
}
