import Foundation

enum L10n {
    enum DesignSystem {
        static let requiredMarker = LocalizedStringResource(
            "designSystem.field.requiredMarker",
            defaultValue: "*",
            comment: "Marks a required PVField as required, shown beside its label"
        )

        static let toastDismiss = LocalizedStringResource(
            "designSystem.toast.dismiss",
            defaultValue: "Dismiss",
            comment: "Accessibility label for a PVToast's dismiss button"
        )

        static let tableSortNone = LocalizedStringResource(
            "designSystem.table.sortNone",
            defaultValue: "Not sorted. Activate to sort ascending",
            comment: "Spoken sort state of an unsorted PVTable column header"
        )

        static let tableSortAscending = LocalizedStringResource(
            "designSystem.table.sortAscending",
            defaultValue: "Sorted ascending. Activate to sort descending",
            comment: "Spoken sort state of a PVTable column header sorted ascending"
        )

        static let tableSortDescending = LocalizedStringResource(
            "designSystem.table.sortDescending",
            defaultValue: "Sorted descending. Activate to sort ascending",
            comment: "Spoken sort state of a PVTable column header sorted descending"
        )

        static func tableFilterColumn(column: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "designSystem.table.filterColumn",
                defaultValue: "Filter %@",
                comment: "Accessibility label for a PVTable column's filter menu; argument is the column title"
            ))
            return String(format: format, locale: .current, column)
        }

        static func tableFilterOptionCount(label: String, count: Int) -> String {
            let format = String(localized: LocalizedStringResource(
                "designSystem.table.filterOptionCount",
                defaultValue: "%1$@ (%2$lld)",
                comment: "A PVTable filter menu option with its row count; arguments are the option label and the count"
            ))
            return String(format: format, locale: .current, label, count)
        }
    }

    enum Onboarding {
        static let welcomeTitle = LocalizedStringResource(
            "onboarding.chooseFile.welcomeTitle",
            defaultValue: "Welcome to Provenencia",
            comment: "Onboarding choose-file headline"
        )

        static func bodySignedIn(displayName: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "onboarding.chooseFile.bodySignedIn",
                defaultValue: "You're signed in as %@. Open a project you already have, or create a new one.",
                comment: "Onboarding choose-file body when researcher is locked; argument is display name"
            ))
            return String(format: format, locale: .current, displayName)
        }

        static let bodyChoose = LocalizedStringResource(
            "onboarding.chooseFile.bodyChoose",
            defaultValue: "Do you already have a Provenencia project, or do you want to start a new one?",
            comment: "Onboarding choose-file body when researcher is not locked"
        )

        static let createNewTitle = LocalizedStringResource(
            "onboarding.chooseFile.createNewTitle",
            defaultValue: "Create new",
            comment: "Create-new mode card title"
        )

        static let createNewSubtitle = LocalizedStringResource(
            "onboarding.chooseFile.createNewSubtitle",
            defaultValue: "Start a new project folder",
            comment: "Create-new mode card subtitle"
        )

        static let haveFileTitle = LocalizedStringResource(
            "onboarding.chooseFile.haveFileTitle",
            defaultValue: "I have a file",
            comment: "Open-existing mode card title"
        )

        static let haveFileSubtitle = LocalizedStringResource(
            "onboarding.chooseFile.haveFileSubtitle",
            defaultValue: "Open a project you already have",
            comment: "Open-existing mode card subtitle"
        )

        static let signOut = LocalizedStringResource(
            "onboarding.common.signOut",
            defaultValue: "Sign out",
            comment: "Sign out button"
        )

        static let continueAction = LocalizedStringResource(
            "onboarding.common.continue",
            defaultValue: "Continue",
            comment: "Continue button"
        )

        static let back = LocalizedStringResource(
            "onboarding.common.back",
            defaultValue: "Back",
            comment: "Back button"
        )

        static let nameResearchTitle = LocalizedStringResource(
            "onboarding.identify.nameResearchTitle",
            defaultValue: "Name this research",
            comment: "Create-mode identify headline"
        )

        static let nameResearchBody = LocalizedStringResource(
            "onboarding.identify.nameResearchBody",
            defaultValue: "Your researcher name is how work is attributed. The project name is a label; the folder on disk uses a simple slug.",
            comment: "Create-mode identify helper copy"
        )

        static let researcherName = LocalizedStringResource(
            "onboarding.identify.researcherName",
            defaultValue: "Researcher name",
            comment: "Researcher name field label"
        )

        static let researcherNamePrompt = LocalizedStringResource(
            "onboarding.identify.researcherNamePrompt",
            defaultValue: "Jane Smith",
            comment: "Placeholder for researcher name field"
        )

        static let familyName = LocalizedStringResource(
            "onboarding.identify.familyName",
            defaultValue: "Family / project name",
            comment: "Family / project name field label"
        )

        static let familyNamePrompt = LocalizedStringResource(
            "onboarding.identify.familyNamePrompt",
            defaultValue: "Smith Family",
            comment: "Placeholder for family / project name field"
        )

        static func folderNamePreview(folderName: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "onboarding.identify.folderNamePreview",
                defaultValue: "Folder: %@",
                comment: "Live preview of kebab-case project folder name; argument is folder basename"
            ))
            return String(format: format, locale: .current, folderName)
        }

        static let whoAreYouTitle = LocalizedStringResource(
            "onboarding.identify.whoAreYouTitle",
            defaultValue: "Who are you in this file?",
            comment: "Open-mode identify headline"
        )

        static let thisProject = LocalizedStringResource(
            "onboarding.identify.thisProject",
            defaultValue: "this project",
            comment: "Fallback project name when folder basename is unknown"
        )

        static func contributorsBody(projectName: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "onboarding.identify.contributorsBody",
                defaultValue: "These are the contributors already in %@. Choose yourself to keep the same ID, or add a new contributor.",
                comment: "Open-mode identify body; argument is project folder name"
            ))
            return String(format: format, locale: .current, projectName)
        }

        static func contributorOption(displayName: String, ref: String) -> String {
            if ref.isEmpty {
                return displayName
            }
            let format = String(localized: LocalizedStringResource(
                "onboarding.identify.contributorOption",
                defaultValue: "%@ (%@)",
                comment: "Contributor accessibility/combined label; arguments are display name then USR-… ref"
            ))
            return String(format: format, locale: .current, displayName, ref)
        }

        static func contributorRef(ref: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "onboarding.identify.contributorRef",
                defaultValue: "(%@)",
                comment: "Parenthesized short ref beside a display name; argument is USR-… ref"
            ))
            return String(format: format, locale: .current, ref)
        }

        static let notListed = LocalizedStringResource(
            "onboarding.identify.notListed",
            defaultValue: "I’m not listed — add me",
            comment: "Picker option to add a new contributor"
        )

        static let signedInTitle = LocalizedStringResource(
            "onboarding.home.signedInTitle",
            defaultValue: "You're signed in",
            comment: "Home screen headline after successful open/create"
        )

        static func homeFolder(folderName: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "onboarding.home.folder",
                defaultValue: "Folder: %@",
                comment: "Home screen project folder line; argument is folder basename"
            ))
            return String(format: format, locale: .current, folderName)
        }

        static func homeCreated(date: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "onboarding.home.created",
                defaultValue: "Created %@",
                comment: "Home screen created date; argument is localized date"
            ))
            return String(format: format, locale: .current, date)
        }

        static func homeUpdated(date: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "onboarding.home.updated",
                defaultValue: "Updated %@",
                comment: "Home screen updated date; argument is localized date"
            ))
            return String(format: format, locale: .current, date)
        }

        static func homeUpdatedBy(displayName: String, ref: String) -> String {
            if ref.isEmpty {
                let format = String(localized: LocalizedStringResource(
                    "onboarding.home.updatedByName",
                    defaultValue: "Last edited by %@",
                    comment: "Home screen last editor without ref; argument is display name"
                ))
                return String(format: format, locale: .current, displayName)
            }
            let format = String(localized: LocalizedStringResource(
                "onboarding.home.updatedBy",
                defaultValue: "Last edited by %@ (%@)",
                comment: "Home screen last editor; arguments are display name then USR-… ref"
            ))
            return String(format: format, locale: .current, displayName, ref)
        }

        static let projectFolder = LocalizedStringResource(
            "onboarding.open.projectFolder",
            defaultValue: "Project folder",
            comment: "Section label above project folder picker"
        )

        static let noProjectsInDocuments = LocalizedStringResource(
            "onboarding.open.noProjectsInDocuments",
            defaultValue: "No project folders in Documents.",
            comment: "Empty state when Documents has no .provenencia folders"
        )

        static let chooseFolder = LocalizedStringResource(
            "onboarding.open.chooseFolder",
            defaultValue: "Choose…",
            comment: "Button to open a folder picker"
        )

        static let selectProject = LocalizedStringResource(
            "onboarding.open.selectProject",
            defaultValue: "Select a project",
            comment: "Placeholder row in existing-project picker"
        )

        static let openPanelPrompt = LocalizedStringResource(
            "onboarding.open.openPanelPrompt",
            defaultValue: "Open",
            comment: "NSOpenPanel confirm button"
        )

        static let openPanelMessage = LocalizedStringResource(
            "onboarding.open.openPanelMessage",
            defaultValue: "Choose a Provenencia project folder.",
            comment: "NSOpenPanel message for choosing a project folder"
        )

        static let missingProject = LocalizedStringResource(
            "onboarding.missingProject",
            defaultValue: "The last project could not be found. Create or open a project.",
            comment: "Error when the last active project folder is missing"
        )

        static let workspaceMissingContext = LocalizedStringResource(
            "onboarding.workspaceMissingContext",
            defaultValue: "Provenencia could not open the workspace because the project or your account is missing. Create or open a project to continue.",
            comment: "Error when entering the workspace without a project directory or user id"
        )

        static let createNewFolderNote = LocalizedStringResource(
            "onboarding.chooseFile.createNewFolderNote",
            defaultValue: "The folder is written to ~/Documents when you continue. You name the research on the next screen.",
            comment: "Info note shown when create-new mode is selected, explaining where the project folder is written"
        )

        static let newContributorIDNote = LocalizedStringResource(
            "onboarding.identify.newContributorIDNote",
            defaultValue: "A new ID is minted on continue",
            comment: "Note under the new-contributor name field explaining an ID will be assigned"
        )

        static let loadingFooterNote = LocalizedStringResource(
            "onboarding.loading.footerNote",
            defaultValue: "No project is opened until you choose one",
            comment: "Footer note on the loading screen, reassuring no project is auto-opened"
        )
    }

    enum Workspace {
        static let navGroupLabel = LocalizedStringResource(
            "workspace.sidebar.navGroupLabel",
            defaultValue: "Source layer",
            comment: "Eyebrow label above the workspace sidebar's nav destinations"
        )

        static let sourcesTitle = LocalizedStringResource(
            "workspace.section.sources.title",
            defaultValue: "Sources",
            comment: "Workspace sidebar destination and page title: Sources"
        )

        static let sourcesPlaceholderNote = LocalizedStringResource(
            "workspace.section.sources.placeholderNote",
            defaultValue: "The Source catalog list and detail arrive in a later update.",
            comment: "Placeholder note shown in the empty Sources content host"
        )

        static let sourceTypesTitle = LocalizedStringResource(
            "workspace.section.sourceTypes.title",
            defaultValue: "Source types",
            comment: "Workspace sidebar destination and page title: Source types"
        )

        static let sourceTypesPlaceholderNote = LocalizedStringResource(
            "workspace.section.sourceTypes.placeholderNote",
            defaultValue: "Editing the Source type vocabulary arrives in a later update.",
            comment: "Placeholder note shown in the empty Source types content host"
        )

        static let sourceFieldsTitle = LocalizedStringResource(
            "workspace.section.sourceFields.title",
            defaultValue: "Source fields",
            comment: "Workspace sidebar destination and page title: Source fields"
        )

        static let sourceFieldsPlaceholderNote = LocalizedStringResource(
            "workspace.section.sourceFields.placeholderNote",
            defaultValue: "Editing the Source metadata fields arrives in a later update.",
            comment: "Placeholder note shown in the empty Source fields content host"
        )

        static let filesTitle = LocalizedStringResource(
            "workspace.section.files.title",
            defaultValue: "Files",
            comment: "Workspace sidebar destination and page title: Files"
        )

        static let filesPlaceholderNote = LocalizedStringResource(
            "workspace.section.files.placeholderNote",
            defaultValue: "Artifact ingest and file preview arrive in a later update.",
            comment: "Placeholder note shown in the empty Files content host"
        )

        static let collapseSidebar = LocalizedStringResource(
            "workspace.sidebar.collapse",
            defaultValue: "Collapse labels",
            comment: "Tooltip/accessibility label for the sidebar toggle when expanded"
        )

        static let expandSidebar = LocalizedStringResource(
            "workspace.sidebar.expand",
            defaultValue: "Show labels",
            comment: "Tooltip/accessibility label for the sidebar toggle when collapsed"
        )
    }

    /// The **Source fields** workspace destination (S2-15): browse, search,
    /// and create/edit the project's `source_metadata_fields` vocabulary.
    /// Origin markers shared by every catalog vocabulary destination —
    /// `OriginBadge` on a detail panel, `OriginPill` inline in a list.
    enum Origin {
        static let provenencia = LocalizedStringResource(
            "origin.badge.provenencia",
            defaultValue: "provenencia",
            comment: "Origin badge for a vocabulary row seeded by Provenencia"
        )

        static let user = LocalizedStringResource(
            "origin.badge.user",
            defaultValue: "you",
            comment: "Origin badge for a vocabulary row the researcher added"
        )

        static let seededPill = LocalizedStringResource(
            "origin.pill.seeded",
            defaultValue: "Seeded by Provenencia",
            comment: "Accessibility label and tooltip for the pill marking a Provenencia-seeded row in a vocabulary list"
        )

        static func pluginPill(pluginID: String) -> LocalizedStringResource {
            LocalizedStringResource(
                "origin.pill.plugin",
                defaultValue: "Supplied by the \(pluginID) plugin",
                comment: "Accessibility label and tooltip for the pill marking a plugin-owned row in a vocabulary list; argument is the plugin id"
            )
        }
    }

    enum SourceFields {
        static let description = LocalizedStringResource(
            "sourceFields.list.description",
            defaultValue: "The metadata a source can carry in this project. Provenencia seeds the common fields; you add the ones your records actually use.",
            comment: "Explanatory copy under the Source fields page title"
        )

        static func countLine(total: Int, seeded: Int, user: Int) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceFields.list.countLine",
                defaultValue: "%lld fields · %lld seeded · %lld yours",
                comment: "Source fields count summary; arguments are total, seeded (provenencia), and user field counts"
            ))
            return String(format: format, locale: .current, total, seeded, user)
        }

        static func countLineWithPlugin(total: Int, seeded: Int, user: Int, plugin: Int) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceFields.list.countLineWithPlugin",
                defaultValue: "%lld fields · %lld seeded · %lld yours · %lld plugin",
                comment: "Source fields count summary including plugin-origin fields; arguments are total, seeded, user, and plugin field counts"
            ))
            return String(format: format, locale: .current, total, seeded, user, plugin)
        }

        static let addField = LocalizedStringResource(
            "sourceFields.list.addField",
            defaultValue: "Add field",
            comment: "Button: add a new Source field (toolbar, empty state, and add-form submit)"
        )

        static let searchPlaceholder = LocalizedStringResource(
            "sourceFields.list.searchPlaceholder",
            defaultValue: "Search fields — label, key, or description",
            comment: "Placeholder for the Source fields search input"
        )

        static let clearSearch = LocalizedStringResource(
            "sourceFields.list.clearSearch",
            defaultValue: "Clear search",
            comment: "Button that clears the Source fields search query"
        )

        static let columnLabel = LocalizedStringResource(
            "sourceFields.list.columnLabel",
            defaultValue: "Label",
            comment: "Source fields list column header: label"
        )

        static let columnKey = LocalizedStringResource(
            "sourceFields.list.columnKey",
            defaultValue: "Key",
            comment: "Source fields list column header: key"
        )

        static let columnDataType = LocalizedStringResource(
            "sourceFields.list.columnDataType",
            defaultValue: "Data type",
            comment: "Source fields list column header: data type"
        )

        static let dataTypeText = LocalizedStringResource(
            "sourceFields.dataType.text",
            defaultValue: "text",
            comment: "Source field data type badge/option: text"
        )

        static let dataTypeDate = LocalizedStringResource(
            "sourceFields.dataType.date",
            defaultValue: "date",
            comment: "Source field data type badge/option: date"
        )

        static let deleteField = LocalizedStringResource(
            "sourceFields.delete.action",
            defaultValue: "Delete field",
            comment: "Delete button in the Source fields detail pane, and the confirm dialog's destructive button"
        )

        static let deleteOwnedByPlugin = LocalizedStringResource(
            "sourceFields.delete.ownedByPlugin",
            defaultValue: "Owned by the plugin",
            comment: "Tooltip on the disabled delete button when the selected field comes from a plugin"
        )

        static func deleteInUse(count: Int) -> LocalizedStringResource {
            count == 1 ? deleteInUseOne : deleteInUseOther(count: count)
        }

        private static let deleteInUseOne = LocalizedStringResource(
            "sourceFields.delete.inUseOne",
            defaultValue: "In use on 1 source",
            comment: "Tooltip on the disabled delete button when exactly one source carries a value for the field"
        )

        private static func deleteInUseOther(count: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "sourceFields.delete.inUseOther",
                defaultValue: "In use on \(count) sources",
                comment: "Tooltip on the disabled delete button; argument is how many sources carry a value for the field"
            )
        }

        static func deleteConfirmTitle(label: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceFields.delete.confirmTitle",
                defaultValue: "Delete %@?",
                comment: "Title of the delete-field confirmation dialog; argument is the field label"
            ))
            return String(format: format, locale: .current, label)
        }

        static let deleteConfirmMessage = LocalizedStringResource(
            "sourceFields.delete.confirmMessage",
            defaultValue: "No source in this project carries a value for this field, so nothing is lost. The key is released and can be minted again by a later field with the same label.",
            comment: "Message of the delete-field confirmation sheet: what is and is not lost"
        )

        static let deleteKeyReleased = LocalizedStringResource(
            "sourceFields.delete.keyReleased",
            defaultValue: "Key released",
            comment: "Micro-caps label beside the key a field delete releases, in the confirmation sheet"
        )

        static let deleteKeep = LocalizedStringResource(
            "sourceFields.delete.keep",
            defaultValue: "Keep field",
            comment: "Button that closes the delete-field confirmation without deleting"
        )

        static let toastDeletedTitle = LocalizedStringResource(
            "sourceFields.toast.deletedTitle",
            defaultValue: "Field deleted",
            comment: "Toast title after a source field is deleted"
        )

        static func toastDeletedBody(label: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceFields.toast.deletedBody",
                defaultValue: "%@ is no longer in this project's vocabulary.",
                comment: "Toast body after a source field is deleted; argument is the field label"
            ))
            return String(format: format, locale: .current, label)
        }

        static let emptyProjectTitle = LocalizedStringResource(
            "sourceFields.emptyProject.title",
            defaultValue: "No source fields yet",
            comment: "Title of the empty state when the project has zero metadata fields"
        )

        static let emptyProjectBody = LocalizedStringResource(
            "sourceFields.emptyProject.body",
            defaultValue: "This project has no metadata vocabulary. Add the fields your records actually carry — a certificate number, a photographer, an album code.",
            comment: "Body of the empty state when the project has zero metadata fields"
        )

        static let noMatchTitle = LocalizedStringResource(
            "sourceFields.noMatch.title",
            defaultValue: "No field matches",
            comment: "Title of the empty state when a search finds no fields"
        )

        static func noMatchBody(query: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceFields.noMatch.body",
                defaultValue: "Nothing in this project’s vocabulary matches “%@”. Clear the search, or add the field.",
                comment: "Body of the no-match empty state; argument is the search query"
            ))
            return String(format: format, locale: .current, query)
        }

        static func resultLine(shown: Int, total: Int) -> String {
            if shown == total {
                let format = String(localized: LocalizedStringResource(
                    "sourceFields.list.resultLineAll",
                    defaultValue: "%lld fields",
                    comment: "Footer result count when no search/filter narrows the Source fields list; argument is the total"
                ))
                return String(format: format, locale: .current, total)
            }
            let format = String(localized: LocalizedStringResource(
                "sourceFields.list.resultLineFiltered",
                defaultValue: "%lld of %lld fields shown",
                comment: "Footer result count when search narrows the Source fields list; arguments are shown then total"
            ))
            return String(format: format, locale: .current, shown, total)
        }

        static let detailEyebrowField = LocalizedStringResource(
            "sourceFields.detail.eyebrowField",
            defaultValue: "Field",
            comment: "Eyebrow label above an existing field's detail panel"
        )

        static let detailEyebrowNewField = LocalizedStringResource(
            "sourceFields.detail.eyebrowNewField",
            defaultValue: "New field",
            comment: "Eyebrow label above the add-field panel"
        )

        static let keyHintAdd = LocalizedStringResource(
            "sourceFields.detail.keyHintAdd",
            defaultValue: "Provenencia mints the key from the label when the field is added",
            comment: "Hint under the live key preview while adding a field"
        )

        static let keyHintEdit = LocalizedStringResource(
            "sourceFields.detail.keyHintEdit",
            defaultValue: "The key is minted once from the label and never changes — renaming the field keeps existing sources attached",
            comment: "Hint under the key on an existing field's detail panel"
        )

        static func lockedNotePlugin(pluginID: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceFields.detail.lockedNotePlugin",
                defaultValue: "Supplied by the %@ plugin. The plugin owns this definition — Provenencia will not edit it.",
                comment: "Callout explaining why a plugin-origin field can't be edited; argument is the plugin id"
            ))
            return String(format: format, locale: .current, pluginID)
        }

        static let dataTypeSectionLabel = LocalizedStringResource(
            "sourceFields.detail.dataTypeSectionLabel",
            defaultValue: "Data type",
            comment: "Section label above the read-only data type line on a locked field's detail"
        )

        static let descriptionSectionLabel = LocalizedStringResource(
            "sourceFields.detail.descriptionSectionLabel",
            defaultValue: "Description",
            comment: "Section label above the read-only description on a locked field's detail"
        )

        static let descriptionEmptyPlaceholder = LocalizedStringResource(
            "sourceFields.detail.descriptionEmptyPlaceholder",
            defaultValue: "—",
            comment: "Shown in place of a locked field's description when it has none"
        )

        static let panelEmptyTitle = LocalizedStringResource(
            "sourceFields.detail.panelEmptyTitle",
            defaultValue: "No field selected",
            comment: "Title of the empty state shown in the detail panel before any field is selected"
        )

        static let panelEmptyBody = LocalizedStringResource(
            "sourceFields.detail.panelEmptyBody",
            defaultValue: "Select a field to read or edit its definition. Fields supplied by a plugin are read-only; the rest of this project's vocabulary stays editable.",
            comment: "Body of the empty state shown in the detail panel before any field is selected"
        )

        static let formLabel = LocalizedStringResource(
            "sourceFields.form.label",
            defaultValue: "Label",
            comment: "Add/edit form field: label"
        )

        static let formLabelPlaceholder = LocalizedStringResource(
            "sourceFields.form.labelPlaceholder",
            defaultValue: "Grandma’s album code",
            comment: "Placeholder text for the add-field label input"
        )

        static let formDataType = LocalizedStringResource(
            "sourceFields.form.dataType",
            defaultValue: "Data type",
            comment: "Add/edit form field: data type picker"
        )

        static let formDataTypeHint = LocalizedStringResource(
            "sourceFields.form.dataTypeHint",
            defaultValue: "Only text and date exist in the Source layer today",
            comment: "Hint under the data type picker on add"
        )

        static let formDataTypeImmutableHint = LocalizedStringResource(
            "sourceFields.form.dataTypeImmutableHint",
            defaultValue: "Data type is fixed when the field is created so existing values stay valid.",
            comment: "Hint under the read-only data type on edit"
        )

        static let formDescription = LocalizedStringResource(
            "sourceFields.form.description",
            defaultValue: "Description",
            comment: "Add/edit form field: description"
        )

        static let formDescriptionHint = LocalizedStringResource(
            "sourceFields.form.descriptionHint",
            defaultValue: "What a researcher should put in this field, in your own words",
            comment: "Hint under the description field"
        )

        static let formDescriptionPlaceholder = LocalizedStringResource(
            "sourceFields.form.descriptionPlaceholder",
            defaultValue: "Pencil code on the back of prints from the album",
            comment: "Placeholder text for the add-field description input"
        )

        static let errorLabelRequired = LocalizedStringResource(
            "sourceFields.form.errorLabelRequired",
            defaultValue: "A label is required — it is how the field reads on a source.",
            comment: "Inline validation error when the label is blank"
        )

        static let errorUnslugifiable = LocalizedStringResource(
            "sourceFields.form.errorUnslugifiable",
            defaultValue: "That label cannot be turned into a key. Use at least one letter or number.",
            comment: "Inline validation error when the label has no letters or digits to slug"
        )

        static let saveSaving = LocalizedStringResource(
            "sourceFields.form.saveSaving",
            defaultValue: "Saving",
            comment: "Primary button label while a Source field add/edit is in flight"
        )

        static let saveChanges = LocalizedStringResource(
            "sourceFields.form.saveChanges",
            defaultValue: "Save changes",
            comment: "Primary button label for committing an edit to an existing field"
        )

        static let cancel = LocalizedStringResource(
            "sourceFields.form.cancel",
            defaultValue: "Cancel",
            comment: "Secondary button label that dismisses the add-field form"
        )

        static let revert = LocalizedStringResource(
            "sourceFields.form.revert",
            defaultValue: "Revert",
            comment: "Secondary button label that discards unsaved edits to an existing field"
        )

        static let toastAddedTitle = LocalizedStringResource(
            "sourceFields.toast.addedTitle",
            defaultValue: "Field added",
            comment: "Success toast title after creating a Source field"
        )

        static func toastAddedBody(label: String, key: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceFields.toast.addedBody",
                defaultValue: "%@ is in this project’s vocabulary as %@.",
                comment: "Success toast body after creating a Source field; arguments are label then minted key"
            ))
            return String(format: format, locale: .current, label, key)
        }

        static let toastUpdatedTitle = LocalizedStringResource(
            "sourceFields.toast.updatedTitle",
            defaultValue: "Field updated",
            comment: "Success toast title after editing a Source field"
        )

        static func toastUpdatedBody(label: String, key: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceFields.toast.updatedBody",
                defaultValue: "%@ — the key stays %@.",
                comment: "Success toast body after editing a Source field; arguments are label then key"
            ))
            return String(format: format, locale: .current, label, key)
        }
    }

    /// Maps stable Go/FFI error codes to localized user-facing copy.
    enum SourceTypes {
        static let description = LocalizedStringResource(
            "sourceTypes.list.description",
            defaultValue: "The kinds of record this project cites, and the fields each kind usually carries. The fields are suggestions — a source of this type may leave any of them blank.",
            comment: "Explanatory copy under the Source types page title"
        )

        static func countLine(total: Int, seeded: Int, user: Int) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceTypes.list.countLine",
                defaultValue: "%lld types · %lld seeded · %lld yours",
                comment: "Source types count summary; arguments are total, seeded (provenencia), and user type counts"
            ))
            return String(format: format, locale: .current, total, seeded, user)
        }

        static func countLineWithPlugin(total: Int, seeded: Int, user: Int, plugin: Int) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceTypes.list.countLineWithPlugin",
                defaultValue: "%lld types · %lld seeded · %lld yours · %lld plugin",
                comment: "Source types count summary including plugin-origin types; arguments are total, seeded, user, and plugin type counts"
            ))
            return String(format: format, locale: .current, total, seeded, user, plugin)
        }

        static let addType = LocalizedStringResource(
            "sourceTypes.list.addType",
            defaultValue: "Add type",
            comment: "Button: add a new Source type (toolbar, empty state, and add-form submit)"
        )

        static let searchPlaceholder = LocalizedStringResource(
            "sourceTypes.list.searchPlaceholder",
            defaultValue: "Search types — label, key, or description",
            comment: "Placeholder for the Source types search input"
        )

        static let clearSearch = LocalizedStringResource(
            "sourceTypes.list.clearSearch",
            defaultValue: "Clear search",
            comment: "Button that clears the Source types search query"
        )

        static let columnLabel = LocalizedStringResource(
            "sourceTypes.list.columnLabel",
            defaultValue: "Label",
            comment: "Source types list column header: label"
        )

        static let columnKey = LocalizedStringResource(
            "sourceTypes.list.columnKey",
            defaultValue: "Key",
            comment: "Source types list column header: key"
        )

        static let columnFields = LocalizedStringResource(
            "sourceTypes.list.columnFields",
            defaultValue: "Associated fields",
            comment: "Source types list column header: how many metadata fields the type suggests"
        )

        static let fieldCountNone = LocalizedStringResource(
            "sourceTypes.list.fieldCountNone",
            defaultValue: "—",
            comment: "Shown in the associated-fields column when a type suggests no fields"
        )

        static func resultLine(shown: Int, total: Int) -> String {
            if shown == total {
                let format = String(localized: LocalizedStringResource(
                    "sourceTypes.list.resultLineAll",
                    defaultValue: "%lld types",
                    comment: "Footer result count when no search narrows the Source types list; argument is the total"
                ))
                return String(format: format, locale: .current, total)
            }
            let format = String(localized: LocalizedStringResource(
                "sourceTypes.list.resultLineFiltered",
                defaultValue: "%lld of %lld types shown",
                comment: "Footer result count when search narrows the Source types list; arguments are shown then total"
            ))
            return String(format: format, locale: .current, shown, total)
        }

        static let emptyProjectTitle = LocalizedStringResource(
            "sourceTypes.emptyProject.title",
            defaultValue: "No source types yet",
            comment: "Title of the empty state when the project has zero source types"
        )

        static let emptyProjectBody = LocalizedStringResource(
            "sourceTypes.emptyProject.body",
            defaultValue: "This project has no record classes to cite against. Add the kinds of record you actually hold — a parish register, a scrapbook, a headstone photograph.",
            comment: "Body of the empty state when the project has zero source types"
        )

        static let noMatchTitle = LocalizedStringResource(
            "sourceTypes.noMatch.title",
            defaultValue: "No type matches",
            comment: "Title of the empty state when a search finds no types"
        )

        static func noMatchBody(query: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceTypes.noMatch.body",
                defaultValue: "Nothing in this project’s vocabulary matches “%@”. Clear the search, or add the type.",
                comment: "Body of the no-match empty state; argument is the search query"
            ))
            return String(format: format, locale: .current, query)
        }

        static let detailEyebrowType = LocalizedStringResource(
            "sourceTypes.detail.eyebrowType",
            defaultValue: "Source type",
            comment: "Eyebrow label above an existing type's detail panel"
        )

        static let detailEyebrowNewType = LocalizedStringResource(
            "sourceTypes.detail.eyebrowNewType",
            defaultValue: "New type",
            comment: "Eyebrow label above the add-type panel"
        )

        static let keyHintAdd = LocalizedStringResource(
            "sourceTypes.detail.keyHintAdd",
            defaultValue: "Provenencia mints the key from the label when the type is added",
            comment: "Hint under the live key preview while adding a type"
        )

        static let keyHintEdit = LocalizedStringResource(
            "sourceTypes.detail.keyHintEdit",
            defaultValue: "The key is minted once from the label and never changes — renaming the type keeps existing sources attached",
            comment: "Hint under the key on an existing type's detail panel"
        )

        static func usage(count: Int) -> LocalizedStringResource {
            switch count {
            case 0: usageNone
            case 1: usageOne
            default: usageOther(count: count)
            }
        }

        private static let usageNone = LocalizedStringResource(
            "sourceTypes.detail.usageNone",
            defaultValue: "no sources yet",
            comment: "Line under a type's title when no source is classified as it"
        )

        private static let usageOne = LocalizedStringResource(
            "sourceTypes.detail.usageOne",
            defaultValue: "in use on 1 source",
            comment: "Line under a type's title when exactly one source is classified as it"
        )

        private static func usageOther(count: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "sourceTypes.detail.usageOther",
                defaultValue: "in use on \(count) sources",
                comment: "Line under a type's title; argument is how many sources are classified as it"
            )
        }

        static let panelEmptyTitle = LocalizedStringResource(
            "sourceTypes.detail.panelEmptyTitle",
            defaultValue: "No type selected",
            comment: "Title of the empty state shown in the detail panel before any type is selected"
        )

        static let panelEmptyBody = LocalizedStringResource(
            "sourceTypes.detail.panelEmptyBody",
            defaultValue: "Select a type to read its description and the fields it suggests. Types seeded by Provenencia are yours to edit; only plugin-owned types are fixed.",
            comment: "Body of the empty state shown in the detail panel before any type is selected"
        )

        static func lockedNotePlugin(pluginID: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceTypes.detail.lockedNotePlugin",
                defaultValue: "Supplied by the %@ plugin. The plugin owns this type, its description and the fields it suggests — Provenencia will not edit or delete them.",
                comment: "Callout explaining why a plugin-origin type can't be edited; argument is the plugin id"
            ))
            return String(format: format, locale: .current, pluginID)
        }

        static let descriptionSectionLabel = LocalizedStringResource(
            "sourceTypes.detail.descriptionSectionLabel",
            defaultValue: "Description",
            comment: "Section label above the read-only description on a locked type's detail"
        )

        static let descriptionEmptyPlaceholder = LocalizedStringResource(
            "sourceTypes.detail.descriptionEmptyPlaceholder",
            defaultValue: "—",
            comment: "Shown in place of a locked type's description when it has none"
        )

        static let formLabel = LocalizedStringResource(
            "sourceTypes.form.label",
            defaultValue: "Label",
            comment: "Add/edit form field: label"
        )

        static let formLabelPlaceholder = LocalizedStringResource(
            "sourceTypes.form.labelPlaceholder",
            defaultValue: "Parish register",
            comment: "Placeholder text for the add-type label input"
        )

        static let formDescription = LocalizedStringResource(
            "sourceTypes.form.description",
            defaultValue: "Description",
            comment: "Add/edit form field: description"
        )

        static let formDescriptionHint = LocalizedStringResource(
            "sourceTypes.form.descriptionHint",
            defaultValue: "What kind of record belongs to this type, in your own words",
            comment: "Hint under the description field"
        )

        static let formDescriptionPlaceholder = LocalizedStringResource(
            "sourceTypes.form.descriptionPlaceholder",
            defaultValue: "A bound register of baptisms, marriages or burials kept by a parish",
            comment: "Placeholder text for the add-type description input"
        )

        static let errorLabelRequired = LocalizedStringResource(
            "sourceTypes.form.errorLabelRequired",
            defaultValue: "A label is required — it is how the type reads on a source.",
            comment: "Inline validation error when the label is blank"
        )

        static let errorUnslugifiable = LocalizedStringResource(
            "sourceTypes.form.errorUnslugifiable",
            defaultValue: "That label cannot be turned into a key. Use at least one letter or number.",
            comment: "Inline validation error when the label has no letters or digits to slug"
        )

        static let saveSaving = LocalizedStringResource(
            "sourceTypes.form.saveSaving",
            defaultValue: "Saving",
            comment: "Primary button label while a Source type add/edit is in flight"
        )

        static let saveChanges = LocalizedStringResource(
            "sourceTypes.form.saveChanges",
            defaultValue: "Save changes",
            comment: "Primary button label for committing an edit to an existing type"
        )

        static let cancel = LocalizedStringResource(
            "sourceTypes.form.cancel",
            defaultValue: "Cancel",
            comment: "Secondary button label that dismisses the add-type form"
        )

        static let revert = LocalizedStringResource(
            "sourceTypes.form.revert",
            defaultValue: "Revert",
            comment: "Secondary button label that discards unsaved edits to an existing type"
        )

        static let addSuggestionsNote = LocalizedStringResource(
            "sourceTypes.form.addSuggestionsNote",
            defaultValue: "Suggested fields are assigned after the type is saved.",
            comment: "Callout in the add-type form explaining that associations come later"
        )

        static let suggestedSectionLabel = LocalizedStringResource(
            "sourceTypes.suggested.sectionLabel",
            defaultValue: "Suggested fields",
            comment: "Section label above the fields a type suggests"
        )

        static let suggestedHint = LocalizedStringResource(
            "sourceTypes.suggested.hint",
            defaultValue: "Suggestions, not a schema — a source of this type may leave any of them blank",
            comment: "Hint under the suggested fields section label"
        )

        static func assignedCount(count: Int) -> LocalizedStringResource {
            count == 1 ? assignedCountOne : assignedCountOther(count: count)
        }

        private static let assignedCountOne = LocalizedStringResource(
            "sourceTypes.suggested.countOne",
            defaultValue: "1 field",
            comment: "Count beside the suggested fields section label when the type suggests exactly one field"
        )

        private static func assignedCountOther(count: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "sourceTypes.suggested.countOther",
                defaultValue: "\(count) fields",
                comment: "Count beside the suggested fields section label; argument is how many fields the type suggests"
            )
        }

        static let noAssignedBody = LocalizedStringResource(
            "sourceTypes.suggested.noneBody",
            defaultValue: "No suggested fields yet — a source of this type will offer nothing but the standard citation. Assign the fields these records usually carry.",
            comment: "Body of the panel shown when a type suggests no fields yet"
        )

        static let assignPlaceholder = LocalizedStringResource(
            "sourceTypes.suggested.assignPlaceholder",
            defaultValue: "Field label or key",
            comment: "Placeholder in the assign-field combo box, naming both things it searches"
        )

        static let assignNoMatch = LocalizedStringResource(
            "sourceTypes.suggested.assignNoMatch",
            defaultValue: "No field in the vocabulary matches that — add it in Source fields first",
            comment: "Shown inside the assign-field combo box list when the typed query matches no field"
        )

        static let assignFieldLabel = LocalizedStringResource(
            "sourceTypes.suggested.assignFieldLabel",
            defaultValue: "Source field to assign",
            comment: "Accessibility label for the assign-field combo box"
        )

        static let assignField = LocalizedStringResource(
            "sourceTypes.suggested.assignField",
            defaultValue: "Assign field",
            comment: "Spoken label for the assign button when no field is picked yet"
        )

        static func assignFieldNamed(field: String, type: String) -> LocalizedStringResource {
            LocalizedStringResource(
                "sourceTypes.suggested.assignFieldNamed",
                defaultValue: "Assign field \(field) to \(type)",
                comment: "Spoken label for the assign button; arguments are the picked field label then the type label"
            )
        }

        static let assignTipPoolEmpty = LocalizedStringResource(
            "sourceTypes.suggested.assignTipPoolEmpty",
            defaultValue: "Every field is already assigned",
            comment: "Tooltip on the disabled assign button when the type already suggests the whole vocabulary"
        )

        static let assignTipChoose = LocalizedStringResource(
            "sourceTypes.suggested.assignTipChoose",
            defaultValue: "Choose a field to assign",
            comment: "Tooltip on the disabled assign button before a field is picked"
        )

        static func assignTipField(label: String) -> LocalizedStringResource {
            LocalizedStringResource(
                "sourceTypes.suggested.assignTipField",
                defaultValue: "Assign \(label) to this type",
                comment: "Tooltip on the enabled assign button; argument is the picked field label"
            )
        }

        static let poolHint = LocalizedStringResource(
            "sourceTypes.suggested.poolHint",
            defaultValue: "The pool is the Source fields vocabulary — add a new field there first if it is missing",
            comment: "Hint under the assign-field picker naming where the pool comes from"
        )

        static let poolHintEmpty = LocalizedStringResource(
            "sourceTypes.suggested.poolHintEmpty",
            defaultValue: "Every field in the vocabulary is already suggested for this type",
            comment: "Hint under the assign-field picker when nothing is left to assign"
        )

        static func removeSuggestion(label: String) -> LocalizedStringResource {
            LocalizedStringResource(
                "sourceTypes.suggested.remove",
                defaultValue: "Remove \(label) from this type",
                comment: "Accessibility label and tooltip on the control that detaches one suggested field; argument is the field label"
            )
        }

        static let toastAssignedTitle = LocalizedStringResource(
            "sourceTypes.toast.assignedTitle",
            defaultValue: "Field assigned",
            comment: "Toast title after attaching a field to a type"
        )

        static func toastAssignedBody(field: String, type: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceTypes.toast.assignedBody",
                defaultValue: "%1$@ is now suggested for %2$@.",
                comment: "Toast body after attaching a field to a type; arguments are the field label then the type label"
            ))
            return String(format: format, locale: .current, field, type)
        }

        static let toastRemovedTitle = LocalizedStringResource(
            "sourceTypes.toast.removedTitle",
            defaultValue: "Suggestion removed",
            comment: "Toast title after detaching a field from a type"
        )

        /// The reassurance that carries T-20: detaching the join deletes
        /// neither the field nor the values sources already hold for it.
        static func toastRemovedBody(field: String, type: String, valueCount: Int) -> String {
            if valueCount == 0 {
                return String(format: String(localized: removedBodyNoValues), locale: .current, field, type)
            }
            return String(format: String(localized: removedBodyWithValues), locale: .current, field, type, valueCount)
        }

        private static let removedBodyNoValues = LocalizedStringResource(
            "sourceTypes.toast.removedBodyNoValues",
            defaultValue: "%1$@ is no longer suggested for %2$@. The field stays in this project’s vocabulary.",
            comment: "Toast body after detaching a field no source carries a value for; arguments are the field label then the type label"
        )

        private static let removedBodyWithValues = LocalizedStringResource(
            "sourceTypes.toast.removedBodyWithValues",
            defaultValue: "%1$@ is no longer suggested for %2$@. The field stays in this project’s vocabulary, and the %3$lld sources already carrying a value keep it.",
            comment: "Toast body after detaching a field sources still carry values for; arguments are the field label, the type label, then how many sources hold a value"
        )

        static let toastAddedTitle = LocalizedStringResource(
            "sourceTypes.toast.addedTitle",
            defaultValue: "Type added",
            comment: "Success toast title after creating a Source type"
        )

        static func toastAddedBody(label: String, key: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceTypes.toast.addedBody",
                defaultValue: "%1$@ is in this project’s vocabulary as %2$@. Assign the fields it should suggest.",
                comment: "Success toast body after creating a Source type; arguments are label then minted key"
            ))
            return String(format: format, locale: .current, label, key)
        }

        static let toastUpdatedTitle = LocalizedStringResource(
            "sourceTypes.toast.updatedTitle",
            defaultValue: "Type updated",
            comment: "Success toast title after editing a Source type"
        )

        static func toastUpdatedBody(label: String, key: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceTypes.toast.updatedBody",
                defaultValue: "%1$@ — the key stays %2$@.",
                comment: "Success toast body after editing a Source type; arguments are label then key"
            ))
            return String(format: format, locale: .current, label, key)
        }

        static let deleteType = LocalizedStringResource(
            "sourceTypes.delete.action",
            defaultValue: "Delete type",
            comment: "Delete button in the Source types detail pane, and the confirm dialog's destructive button"
        )

        static let deleteOwnedByPlugin = LocalizedStringResource(
            "sourceTypes.delete.ownedByPlugin",
            defaultValue: "Owned by the plugin",
            comment: "Tooltip on the disabled delete button when the selected type comes from a plugin"
        )

        static func deleteInUse(count: Int) -> LocalizedStringResource {
            count == 1 ? deleteInUseOne : deleteInUseOther(count: count)
        }

        private static let deleteInUseOne = LocalizedStringResource(
            "sourceTypes.delete.inUseOne",
            defaultValue: "In use on 1 source",
            comment: "Tooltip on the disabled delete button when exactly one source is classified as the type"
        )

        private static func deleteInUseOther(count: Int) -> LocalizedStringResource {
            LocalizedStringResource(
                "sourceTypes.delete.inUseOther",
                defaultValue: "In use on \(count) sources",
                comment: "Tooltip on the disabled delete button; argument is how many sources are classified as the type"
            )
        }

        static func deleteConfirmTitle(label: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceTypes.delete.confirmTitle",
                defaultValue: "Delete %@?",
                comment: "Title of the delete-type confirmation dialog; argument is the type label"
            ))
            return String(format: format, locale: .current, label)
        }

        static let deleteConfirmMessage = LocalizedStringResource(
            "sourceTypes.delete.confirmMessage",
            defaultValue: "No source in this project is classified as this type, so no citation loses its class. The field suggestions attached to it go with it; the fields themselves stay in the vocabulary.",
            comment: "Message of the delete-type confirmation sheet: what does and does not cascade"
        )

        static let deleteKeyReleased = LocalizedStringResource(
            "sourceTypes.delete.keyReleased",
            defaultValue: "Key released",
            comment: "Micro-caps label beside the key a type delete releases, in the confirmation sheet"
        )

        static let deleteKeep = LocalizedStringResource(
            "sourceTypes.delete.keep",
            defaultValue: "Keep type",
            comment: "Button that closes the delete-type confirmation without deleting"
        )

        static let toastDeletedTitle = LocalizedStringResource(
            "sourceTypes.toast.deletedTitle",
            defaultValue: "Type deleted",
            comment: "Toast title after a source type is deleted"
        )

        static func toastDeletedBody(label: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "sourceTypes.toast.deletedBody",
                defaultValue: "%@ is no longer in this project’s vocabulary. Its field suggestions went with it; the fields did not.",
                comment: "Toast body after a source type is deleted; argument is the type label"
            ))
            return String(format: format, locale: .current, label)
        }
    }

    enum Errors {
        static let catalogAlreadyExists = LocalizedStringResource(
            "error.catalog.already_exists",
            defaultValue: "Project already exists.",
            comment: "FFI error catalog.already_exists"
        )
        static let catalogAlreadyOpen = LocalizedStringResource(
            "error.catalog.already_open",
            defaultValue: "Project already open.",
            comment: "FFI error catalog.already_open"
        )
        static let catalogNotAProject = LocalizedStringResource(
            "error.catalog.not_a_project",
            defaultValue: "Not a Provenencia catalog.",
            comment: "FFI error catalog.not_a_project"
        )
        static func catalogUnsupportedVersion(version: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "error.catalog.unsupported_version",
                defaultValue: "Unsupported catalog version (%@).",
                comment: "FFI error catalog.unsupported_version; argument is catalog user_version"
            ))
            return String(format: format, locale: .current, version)
        }
        static let catalogInvalidFolderName = LocalizedStringResource(
            "error.catalog.invalid_folder_name",
            defaultValue: "Folder name must end in .provenencia.",
            comment: "FFI error catalog.invalid_folder_name"
        )
        static let catalogClosed = LocalizedStringResource(
            "error.catalog.closed",
            defaultValue: "Catalog closed.",
            comment: "FFI error catalog.closed"
        )
        static let catalogSchemaMismatch = LocalizedStringResource(
            "error.catalog.schema_mismatch",
            defaultValue: "This catalog’s schema does not match this version of Provenencia.",
            comment: "FFI error catalog.schema_mismatch"
        )
        static let projectInvalidMetadata = LocalizedStringResource(
            "error.project.invalid_metadata",
            defaultValue: "Invalid project metadata.",
            comment: "FFI error project.invalid_metadata"
        )
        static let projectMissingMetadata = LocalizedStringResource(
            "error.project.missing_metadata",
            defaultValue: "Project metadata missing.",
            comment: "FFI error project.missing_metadata"
        )
        static let usersInvalid = LocalizedStringResource(
            "error.users.invalid",
            defaultValue: "Invalid user ID, display name, or ref.",
            comment: "FFI error users.invalid"
        )
        static let identityNotFound = LocalizedStringResource(
            "error.identity.not_found",
            defaultValue: "Identity file not found.",
            comment: "FFI error identity.not_found"
        )
        static let identityInvalidName = LocalizedStringResource(
            "error.identity.invalid_name",
            defaultValue: "Display name is empty.",
            comment: "FFI error identity.invalid_name"
        )
        static let identityInvalidID = LocalizedStringResource(
            "error.identity.invalid_id",
            defaultValue: "User ID must be UUIDv7.",
            comment: "FFI error identity.invalid_id"
        )
        static let identityInvalidRef = LocalizedStringResource(
            "error.identity.invalid_ref",
            defaultValue: "User ref is invalid.",
            comment: "FFI error identity.invalid_ref"
        )
        static let installNotFound = LocalizedStringResource(
            "error.install.not_found",
            defaultValue: "Active project file not found.",
            comment: "FFI error install.not_found"
        )
        static let installInvalid = LocalizedStringResource(
            "error.install.invalid",
            defaultValue: "Project dir is empty.",
            comment: "FFI error install.invalid"
        )
        static let onboardingBlankName = LocalizedStringResource(
            "error.onboarding.blank_name",
            defaultValue: "Name is empty.",
            comment: "FFI error onboarding.blank_name"
        )
        static let onboardingInvalidFamilyName = LocalizedStringResource(
            "error.onboarding.invalid_family_name",
            defaultValue: "Invalid family name.",
            comment: "FFI error onboarding.invalid_family_name"
        )
        static let onboardingUnknownUser = LocalizedStringResource(
            "error.onboarding.unknown_user",
            defaultValue: "User not in project.",
            comment: "FFI error onboarding.unknown_user"
        )
        static let fileNotFound = LocalizedStringResource(
            "error.file.not_found",
            defaultValue: "File not found.",
            comment: "FFI error file.not_found"
        )
        static let sourcesInvalid = LocalizedStringResource(
            "error.sources.invalid",
            defaultValue: "Invalid source.",
            comment: "FFI error sources.invalid"
        )
        static let artifactsInvalid = LocalizedStringResource(
            "error.artifacts.invalid",
            defaultValue: "Invalid artifact.",
            comment: "FFI error artifacts.invalid"
        )
        static let sourceMetadataInvalid = LocalizedStringResource(
            "error.sourcemetadata.invalid",
            defaultValue: "Invalid source metadata.",
            comment: "FFI error sourcemetadata.invalid"
        )
        static let filesInvalid = LocalizedStringResource(
            "error.files.invalid",
            defaultValue: "Invalid file.",
            comment: "FFI error files.invalid"
        )
        static let ingestInvalid = LocalizedStringResource(
            "error.ingest.invalid",
            defaultValue: "Could not ingest that file.",
            comment: "FFI error ingest.invalid"
        )
        static let ingestPermissionDenied = LocalizedStringResource(
            "error.ingest.permission_denied",
            defaultValue: "Permission denied reading that file.",
            comment: "FFI error ingest.permission_denied"
        )
        static let sourceTypesInvalid = LocalizedStringResource(
            "error.sourcetypes.invalid",
            defaultValue: "Invalid source type.",
            comment: "FFI error sourcetypes.invalid"
        )
        static let sourceTypesInUse = LocalizedStringResource(
            "error.sourcetypes.in_use",
            defaultValue: "That source type is still used by one or more sources.",
            comment: "FFI error sourcetypes.in_use"
        )
        static func sourceTypesDuplicateKey(key: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "error.sourcetypes.duplicate_key",
                defaultValue: "You already have a type with the key %@. Give this one a different label.",
                comment: "FFI error sourcetypes.duplicate_key; argument is the colliding key"
            ))
            return String(format: format, locale: .current, key)
        }
        static let sourceFieldsInvalid = LocalizedStringResource(
            "error.sourcefields.invalid",
            defaultValue: "Invalid metadata field.",
            comment: "FFI error sourcefields.invalid"
        )
        static func sourceFieldsDuplicateKey(key: String) -> String {
            let format = String(localized: LocalizedStringResource(
                "error.sourcefields.duplicate_key",
                defaultValue: "You already have a field with the key %@. Give this one a different label.",
                comment: "FFI error sourcefields.duplicate_key; argument is the colliding key"
            ))
            return String(format: format, locale: .current, key)
        }
        static let sourceFieldsInUse = LocalizedStringResource(
            "error.sourcefields.in_use",
            defaultValue: "That metadata field is still used on one or more sources.",
            comment: "FFI error sourcefields.in_use"
        )
        static let sourceVocabInvalid = LocalizedStringResource(
            "error.sourcevocab.invalid",
            defaultValue: "Invalid source vocabulary.",
            comment: "FFI error sourcevocab.invalid"
        )
        static let dateValuesInvalid = LocalizedStringResource(
            "error.datevalues.invalid",
            defaultValue: "Invalid date value.",
            comment: "FFI error datevalues.invalid"
        )
        static let fileDerivativesInvalid = LocalizedStringResource(
            "error.filederivatives.invalid",
            defaultValue: "Invalid file derivative.",
            comment: "FFI error filederivatives.invalid"
        )
        static let fileDerivativesUnprocessable = LocalizedStringResource(
            "error.filederivatives.unprocessable",
            defaultValue: "Cannot generate a preview for that file.",
            comment: "FFI error filederivatives.unprocessable"
        )
        static let fileDerivativesCorruptObject = LocalizedStringResource(
            "error.filederivatives.corrupt_object",
            defaultValue: "Stored file object is corrupt.",
            comment: "FFI error filederivatives.corrupt_object"
        )
        static let unknown = LocalizedStringResource(
            "error.internal.unknown",
            defaultValue: "Something went wrong. Please try again.",
            comment: "FFI error internal.unknown and other unmapped codes"
        )

        /// Resolves a wire error code (+ params) to localized UI copy.
        static func message(code: String, params: [String] = []) -> String {
            switch code {
            case "catalog.already_exists":
                return String(localized: catalogAlreadyExists)
            case "catalog.already_open":
                return String(localized: catalogAlreadyOpen)
            case "catalog.not_a_project":
                return String(localized: catalogNotAProject)
            case "catalog.unsupported_version":
                return catalogUnsupportedVersion(version: params.first ?? "?")
            case "catalog.invalid_folder_name":
                return String(localized: catalogInvalidFolderName)
            case "catalog.closed":
                return String(localized: catalogClosed)
            case "catalog.schema_mismatch":
                return String(localized: catalogSchemaMismatch)
            case "project.invalid_metadata":
                return String(localized: projectInvalidMetadata)
            case "project.missing_metadata":
                return String(localized: projectMissingMetadata)
            case "users.invalid":
                return String(localized: usersInvalid)
            case "identity.not_found":
                return String(localized: identityNotFound)
            case "identity.invalid_name":
                return String(localized: identityInvalidName)
            case "identity.invalid_id":
                return String(localized: identityInvalidID)
            case "identity.invalid_ref":
                return String(localized: identityInvalidRef)
            case "install.not_found":
                return String(localized: installNotFound)
            case "install.invalid":
                return String(localized: installInvalid)
            case "onboarding.blank_name":
                return String(localized: onboardingBlankName)
            case "onboarding.invalid_family_name":
                return String(localized: onboardingInvalidFamilyName)
            case "onboarding.unknown_user":
                return String(localized: onboardingUnknownUser)
            case "file.not_found":
                return String(localized: fileNotFound)
            case "sources.invalid":
                return String(localized: sourcesInvalid)
            case "artifacts.invalid":
                return String(localized: artifactsInvalid)
            case "sourcemetadata.invalid":
                return String(localized: sourceMetadataInvalid)
            case "files.invalid":
                return String(localized: filesInvalid)
            case "ingest.invalid":
                return String(localized: ingestInvalid)
            case "ingest.permission_denied":
                return String(localized: ingestPermissionDenied)
            case "sourcetypes.invalid":
                return String(localized: sourceTypesInvalid)
            case "sourcetypes.in_use":
                return String(localized: sourceTypesInUse)
            case "sourcetypes.duplicate_key":
                return sourceTypesDuplicateKey(key: params.first ?? "?")
            case "sourcefields.invalid":
                return String(localized: sourceFieldsInvalid)
            case "sourcefields.duplicate_key":
                return sourceFieldsDuplicateKey(key: params.first ?? "?")
            case "sourcefields.in_use":
                return String(localized: sourceFieldsInUse)
            case "sourcevocab.invalid":
                return String(localized: sourceVocabInvalid)
            case "datevalues.invalid":
                return String(localized: dateValuesInvalid)
            case "filederivatives.invalid":
                return String(localized: fileDerivativesInvalid)
            case "filederivatives.unprocessable":
                return String(localized: fileDerivativesUnprocessable)
            case "filederivatives.corrupt_object":
                return String(localized: fileDerivativesCorruptObject)
            default:
                return String(localized: unknown)
            }
        }

        static func message(for error: Error) -> String {
            if let coded = error as? CoreInvokeError {
                switch coded {
                case .coded(_, let code, _, let params):
                    return message(code: code, params: params)
                case .failed:
                    return String(localized: unknown)
                }
            }
            return String(localized: unknown)
        }

        /// `ref.invalid` / `ref.invalid_prefix` are KindInternal minting failures and
        /// intentionally fall through to `unknown` — clients never surface them as
        /// distinct copy.
    }
}
