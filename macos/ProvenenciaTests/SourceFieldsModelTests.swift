import Foundation
import Testing
@testable import Provenencia

@Suite
@MainActor
struct SourceFieldsModelTests {
    private let projectDir = "/tmp/fields.provenencia"
    private let userID = "00000000-0000-7000-8000-000000000001"

    private func seededField(id: String = "1", label: String = "Author") -> CatalogMetadataField {
        CatalogMetadataField(id: id, key: "author", origin: "provenencia", label: label, dataType: "text", description: "Seeded.")
    }

    private func userField(id: String = "2", label: String = "Grandma's album code") -> CatalogMetadataField {
        CatalogMetadataField(id: id, key: FieldSlug.kebab(label), origin: "user", label: label, dataType: "text", description: "Pencil code.")
    }

    private func makeModel(store: FakeStore = FakeStore(), fields: [CatalogMetadataField] = []) -> SourceFieldsModel {
        store.fieldsByProject[projectDir] = fields
        return SourceFieldsModel(projectDir: projectDir, userID: userID, store: store)
    }

    @Test func loadPopulatesFieldsAndCounts() async {
        let model = makeModel(fields: [seededField(), userField()])
        await model.load()
        #expect(model.fields.count == 2)
        #expect(model.seededCount == 1)
        #expect(model.userCount == 1)
        #expect(model.pluginCount == 0)
    }

    @Test func searchFiltersByLabelKeyAndDescription() async {
        let model = makeModel(fields: [seededField(), userField()])
        await model.load()

        model.query = "album"
        #expect(model.visibleFields.map(\.id) == ["2"])

        model.query = "seeded"
        #expect(model.visibleFields.map(\.id) == ["1"])

        model.query = "nomatch"
        #expect(model.visibleFields.isEmpty)
    }

    @Test func sortTogglesLabelDirection() async {
        let model = makeModel(fields: [
            seededField(id: "1", label: "Zebra"),
            userField(id: "2", label: "Album"),
        ])
        await model.load()
        #expect(model.visibleFields.map(\.id) == ["2", "1"])
        model.toggleLabelSort()
        #expect(model.visibleFields.map(\.id) == ["1", "2"])
    }

    @Test func selectedFieldLockedForPluginOriginOnly() async {
        let plugin = CatalogMetadataField(
            id: "3", key: "memorial-id", origin: "plugin:findagrave",
            label: "Memorial id", dataType: "text", description: ""
        )
        let model = makeModel(fields: [seededField(), userField(), plugin])
        await model.load()
        model.select("1")
        #expect(!model.isSelectedFieldLocked)
        model.select("2")
        #expect(!model.isSelectedFieldLocked)
        model.select("3")
        #expect(model.isSelectedFieldLocked)
    }

    @Test func submitEditUpdatesSeededFieldButKeepsKeyAndOrigin() async {
        let model = makeModel(fields: [seededField()])
        await model.load()
        model.select("1")
        #expect(!model.isSelectedFieldLocked)
        model.draft?.label = "Author renamed"
        model.draft?.description = "Updated starter."
        await model.submit()
        #expect(model.formError == nil)
        #expect(model.fields.first?.label == "Author renamed")
        #expect(model.fields.first?.key == "author")
        #expect(model.fields.first?.origin == "provenencia")
        #expect(model.toast?.title == String(localized: L10n.SourceFields.toastUpdatedTitle))
    }

    @Test func openAddSeedsBlankDraftAndClearsSelection() async {
        let model = makeModel(fields: [userField()])
        await model.load()
        model.select("2")
        model.openAdd()
        #expect(model.selectedField == nil)
        #expect(model.draft == SourceFieldsModel.Draft(label: "", dataType: "text", description: ""))
    }

    @Test func cancelAddResumesPriorSelection() async {
        let model = makeModel(fields: [userField()])
        await model.load()
        model.select("2")
        model.openAdd()
        model.cancelAdd()
        #expect(model.selectedField?.id == "2")
    }

    @Test func submitAddCreatesFieldAndMintsKeyFromLabel() async {
        let model = makeModel(fields: [])
        await model.load()
        model.openAdd()
        model.draft?.label = "Grandma's album code"
        await model.submit()
        #expect(model.formError == nil)
        #expect(model.fields.count == 1)
        #expect(model.fields.first?.key == "grandmas-album-code")
        #expect(model.fields.first?.origin == "user")
        #expect(model.toast?.title == String(localized: L10n.SourceFields.toastAddedTitle))
        #expect(model.selectedField?.key == "grandmas-album-code")
    }

    @Test func submitAddWithBlankLabelSetsFormError() async {
        let model = makeModel(fields: [])
        await model.load()
        model.openAdd()
        await model.submit()
        #expect(model.formError != nil)
        #expect(model.fields.isEmpty)
    }

    @Test func submitAddWithUnslugifiableLabelSetsFormError() async {
        let model = makeModel(fields: [])
        await model.load()
        model.openAdd()
        model.draft?.label = "..."
        await model.submit()
        #expect(model.formError != nil)
        #expect(model.fields.isEmpty)
    }

    @Test func submitAddWithCollidingSlugSetsFormError() async {
        // "Album code" and "Album  Code!" both slug to "album-code".
        let model = makeModel(fields: [userField(id: "2", label: "Album code")])
        await model.load()
        model.openAdd()
        model.draft?.label = "Album  Code!"
        await model.submit()
        #expect(model.formError != nil)
        #expect(model.fields.count == 1)
    }

    @Test func submitEditUpdatesFieldButKeepsKey() async {
        let model = makeModel(fields: [userField()])
        await model.load()
        model.select("2")
        model.draft?.label = "Grandma's photo album code"
        model.draft?.description = "Updated."
        await model.submit()
        #expect(model.formError == nil)
        #expect(model.fields.first?.label == "Grandma's photo album code")
        #expect(model.fields.first?.key == "grandmas-album-code")
        #expect(model.toast?.title == String(localized: L10n.SourceFields.toastUpdatedTitle))
    }

    @Test func isDirtyTracksUnsavedEditsAndRevertClearsThem() async {
        let model = makeModel(fields: [userField()])
        await model.load()
        model.select("2")
        #expect(!model.isDirty)
        model.draft?.label = "Changed"
        #expect(model.isDirty)
        model.revertEdit()
        #expect(!model.isDirty)
        #expect(model.draft?.label == "Grandma's album code")
    }

    @Test func canSubmitRequiresDirtyOnEditAndNonEmptyLabelOnAdd() async {
        let model = makeModel(fields: [userField()])
        await model.load()
        model.select("2")
        #expect(!model.canSubmit)
        model.draft?.label = "Changed"
        #expect(model.canSubmit)

        model.openAdd()
        #expect(!model.canSubmit)
        model.draft?.label = "New field"
        #expect(model.canSubmit)
    }
}
