package handlers

import (
	"github.com/mendahu/provenencia/api/proto/engine"
	"github.com/mendahu/provenencia/core/database/datevalues"
	"github.com/mendahu/provenencia/core/database/files"
	"github.com/mendahu/provenencia/core/database/sourcemetadata"
	"github.com/mendahu/provenencia/core/database/sources"
	"google.golang.org/protobuf/proto"
)

func ListSources(in []byte) ([]byte, error) {
	var req engine.ListSourcesRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("list_sources", err)
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	rows, err := sources.List(c)
	if err != nil {
		return nil, err
	}
	out := &engine.ListSourcesResponse{}
	for _, s := range rows {
		out.Sources = append(out.Sources, sourceProto(s))
	}
	return proto.Marshal(out)
}

func GetSourceWorkspace(in []byte) ([]byte, error) {
	var req engine.GetSourceWorkspaceRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("get_source_workspace", err)
	}
	sourceID, err := parseID(req.GetSourceId())
	if err != nil {
		return nil, err
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()

	s, err := sources.Get(c, sourceID)
	if err != nil {
		return nil, err
	}
	notes, err := sources.ListNotes(c, sourceID)
	if err != nil {
		return nil, err
	}
	meta, err := sourcemetadata.ListWorkspace(c, sourceID)
	if err != nil {
		return nil, err
	}
	arts, err := listArtifactsProto(c, sourceID)
	if err != nil {
		return nil, err
	}
	cred, err := credibilityForSource(c, sourceID)
	if err != nil {
		return nil, err
	}

	out := &engine.GetSourceWorkspaceResponse{Source: sourceProto(s)}
	for _, n := range notes {
		out.Notes = append(out.Notes, noteProto(n))
	}
	for _, e := range meta {
		out.Metadata = append(out.Metadata, metadataEntryProto(e))
	}
	out.Artifacts = arts
	out.Credibility = cred
	return proto.Marshal(out)
}

func CreateSource(in []byte) ([]byte, error) {
	var req engine.CreateSourceRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("create_source", err)
	}
	userID, err := parseUserID(req.GetUserId())
	if err != nil {
		return nil, err
	}
	typeID, err := parseID(req.GetSourceTypeId())
	if err != nil {
		return nil, err
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	s, err := sources.Create(c, userID, sources.CreateInput{
		SourceTypeID: typeID,
		Title:        req.GetTitle(),
		Description:  req.GetDescription(),
	})
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.CreateSourceResponse{Source: sourceProto(s)})
}

func UpdateSource(in []byte) ([]byte, error) {
	var req engine.UpdateSourceRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("update_source", err)
	}
	userID, err := parseUserID(req.GetUserId())
	if err != nil {
		return nil, err
	}
	id, err := parseID(req.GetSourceId())
	if err != nil {
		return nil, err
	}
	typeID, err := parseID(req.GetSourceTypeId())
	if err != nil {
		return nil, err
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	prev, err := sources.Get(c, id)
	if err != nil {
		return nil, err
	}
	s := sources.Source{
		ID:           id,
		Ref:          prev.Ref,
		SourceTypeID: typeID,
		Title:        req.GetTitle(),
		Description:  req.GetDescription(),
	}
	if err := sources.Update(c, userID, s); err != nil {
		return nil, err
	}
	got, err := sources.Get(c, id)
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.UpdateSourceResponse{Source: sourceProto(got)})
}

func AddSourceNote(in []byte) ([]byte, error) {
	var req engine.AddSourceNoteRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("add_source_note", err)
	}
	userID, err := parseUserID(req.GetUserId())
	if err != nil {
		return nil, err
	}
	sourceID, err := parseID(req.GetSourceId())
	if err != nil {
		return nil, err
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	n, err := sources.AddNote(c, userID, sourceID, req.GetBody())
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.AddSourceNoteResponse{Note: noteProto(n)})
}

func UpdateSourceNote(in []byte) ([]byte, error) {
	var req engine.UpdateSourceNoteRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("update_source_note", err)
	}
	userID, err := parseUserID(req.GetUserId())
	if err != nil {
		return nil, err
	}
	noteID, err := parseID(req.GetNoteId())
	if err != nil {
		return nil, err
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	if err := sources.UpdateNote(c, userID, noteID, req.GetBody()); err != nil {
		return nil, err
	}
	n, err := sources.GetNote(c, noteID)
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.UpdateSourceNoteResponse{Note: noteProto(n)})
}

func DeleteSourceNote(in []byte) ([]byte, error) {
	var req engine.DeleteSourceNoteRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("delete_source_note", err)
	}
	userID, err := parseUserID(req.GetUserId())
	if err != nil {
		return nil, err
	}
	noteID, err := parseID(req.GetNoteId())
	if err != nil {
		return nil, err
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	if err := sources.DeleteNote(c, userID, noteID); err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.DeleteSourceNoteResponse{})
}

func SetSourceMetadata(in []byte) ([]byte, error) {
	var req engine.SetSourceMetadataRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("set_source_metadata", err)
	}
	userID, err := parseUserID(req.GetUserId())
	if err != nil {
		return nil, err
	}
	sourceID, err := parseID(req.GetSourceId())
	if err != nil {
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

	var dateID []byte
	if d := req.GetDate(); d != nil && d.GetKind() != "" {
		v := dateValueFromProto(d)
		dateID, err = datevalues.Insert(c, v)
		if err != nil {
			return nil, err
		}
	}
	row, err := sourcemetadata.Set(c, userID, sourcemetadata.Input{
		SourceID:    sourceID,
		FieldID:     fieldID,
		ValueText:   req.GetValueText(),
		DateValueID: dateID,
	})
	if err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.SetSourceMetadataResponse{
		ValueText:   row.ValueText,
		DateValueId: uuidString(row.DateValueID),
	})
}

func ClearSourceMetadata(in []byte) ([]byte, error) {
	var req engine.ClearSourceMetadataRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("clear_source_metadata", err)
	}
	userID, err := parseUserID(req.GetUserId())
	if err != nil {
		return nil, err
	}
	sourceID, err := parseID(req.GetSourceId())
	if err != nil {
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
	if err := sourcemetadata.Clear(c, userID, sourceID, fieldID); err != nil {
		return nil, err
	}
	return proto.Marshal(&engine.ClearSourceMetadataResponse{})
}

func DismissSourceMetadataSuggestion(in []byte) ([]byte, error) {
	var req engine.DismissSourceMetadataSuggestionRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("dismiss_source_metadata_suggestion", err)
	}
	userID, err := parseUserID(req.GetUserId())
	if err != nil {
		return nil, err
	}
	sourceID, err := parseID(req.GetSourceId())
	if err != nil {
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
	if err := sourcemetadata.DismissSuggestion(c, userID, sourceID, fieldID); err != nil {
		return nil, err
	}
	entries, err := sourcemetadata.ListWorkspace(c, sourceID)
	if err != nil {
		return nil, err
	}
	out := &engine.DismissSourceMetadataSuggestionResponse{}
	for _, e := range entries {
		out.Metadata = append(out.Metadata, metadataEntryProto(e))
	}
	return proto.Marshal(out)
}

func ReorderSourceMetadata(in []byte) ([]byte, error) {
	var req engine.ReorderSourceMetadataRequest
	if err := proto.Unmarshal(in, &req); err != nil {
		return nil, unmarshalErr("reorder_source_metadata", err)
	}
	userID, err := parseUserID(req.GetUserId())
	if err != nil {
		return nil, err
	}
	sourceID, err := parseID(req.GetSourceId())
	if err != nil {
		return nil, err
	}
	fieldIDs := make([][]byte, 0, len(req.GetFieldIds()))
	for _, id := range req.GetFieldIds() {
		fid, err := parseID(id)
		if err != nil {
			return nil, err
		}
		fieldIDs = append(fieldIDs, fid)
	}
	c, err := openProjectCatalog(req.GetProjectDir())
	if err != nil {
		return nil, err
	}
	defer c.Close()
	if err := sourcemetadata.Reorder(c, userID, sourceID, fieldIDs); err != nil {
		return nil, err
	}
	entries, err := sourcemetadata.ListWorkspace(c, sourceID)
	if err != nil {
		return nil, err
	}
	out := &engine.ReorderSourceMetadataResponse{}
	for _, e := range entries {
		out.Metadata = append(out.Metadata, metadataEntryProto(e))
	}
	return proto.Marshal(out)
}

func sourceProto(s sources.Source) *engine.Source {
	return &engine.Source{
		Id:           uuidString(s.ID),
		Ref:          s.Ref,
		SourceTypeId: uuidString(s.SourceTypeID),
		Title:        s.Title,
		Description:  s.Description,
	}
}

func noteProto(n sources.Note) *engine.SourceNote {
	return &engine.SourceNote{
		Id:                uuidString(n.ID),
		SourceId:          uuidString(n.SourceID),
		Body:              n.Body,
		AuthorDisplayName: n.AuthorDisplayName,
		CreatedAt:         n.CreatedAt,
	}
}

func metadataEntryProto(e sourcemetadata.WorkspaceEntry) *engine.MetadataWorkspaceEntry {
	out := &engine.MetadataWorkspaceEntry{
		Field: &engine.MetadataField{
			Id:          uuidString(e.Field.ID),
			Key:         e.Field.Key,
			Origin:      e.Field.Origin,
			Label:       e.Field.Label,
			DataType:    e.Field.DataType,
			Description: e.Field.Description,
		},
		Suggested: e.Suggested,
		SortOrder: int32(e.SortOrder),
	}
	if e.Value != nil {
		out.HasValue = true
		out.ValueText = e.Value.ValueText
		out.DateValueId = uuidString(e.Value.DateValueID)
	}
	return out
}

func fileRefProto(f files.File, relPath string) *engine.SourceFileRef {
	return &engine.SourceFileRef{
		Id:               uuidString(f.ID),
		RelPath:          relPath,
		OriginalFilename: f.OriginalFilename,
		MediaType:        f.MediaType,
		ByteSize:         f.ByteSize,
	}
}

func dateValueFromProto(d *engine.DateValueInput) datevalues.Value {
	v := datevalues.Value{
		Kind:      d.GetKind(),
		Qualifier: d.GetQualifier(),
		Calendar:  d.GetCalendar(),
		StartTZ:   d.GetStartTz(),
		EndTZ:     d.GetEndTz(),
		Phrase:    d.GetPhrase(),
	}
	if d.StartYear != nil {
		y := int(d.GetStartYear())
		v.StartYear = &y
	}
	if d.StartMonth != nil {
		m := int(d.GetStartMonth())
		v.StartMonth = &m
	}
	if d.StartDay != nil {
		day := int(d.GetStartDay())
		v.StartDay = &day
	}
	if d.StartHour != nil {
		h := int(d.GetStartHour())
		v.StartHour = &h
	}
	if d.StartMinute != nil {
		m := int(d.GetStartMinute())
		v.StartMinute = &m
	}
	if d.StartSecond != nil {
		s := int(d.GetStartSecond())
		v.StartSecond = &s
	}
	if d.StartMillisecond != nil {
		ms := int(d.GetStartMillisecond())
		v.StartMillisecond = &ms
	}
	if d.EndYear != nil {
		y := int(d.GetEndYear())
		v.EndYear = &y
	}
	if d.EndMonth != nil {
		m := int(d.GetEndMonth())
		v.EndMonth = &m
	}
	if d.EndDay != nil {
		day := int(d.GetEndDay())
		v.EndDay = &day
	}
	if d.EndHour != nil {
		h := int(d.GetEndHour())
		v.EndHour = &h
	}
	if d.EndMinute != nil {
		m := int(d.GetEndMinute())
		v.EndMinute = &m
	}
	if d.EndSecond != nil {
		s := int(d.GetEndSecond())
		v.EndSecond = &s
	}
	if d.EndMillisecond != nil {
		ms := int(d.GetEndMillisecond())
		v.EndMillisecond = &ms
	}
	return v
}
