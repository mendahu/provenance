#if DEBUG
import Foundation

/// In-memory `GenealogyStore` for SwiftUI previews and tests. Not used in the shipped app.
final class FakeStore: GenealogyStore, @unchecked Sendable {
    var identity: InstallIdentity?
    var activeProjectDir: String?
    var catalogUsers: [InstallIdentity]
    var projectInfos: [String: ProjectInfo] = [:]
    var sourcesByProject: [String: [CatalogSource]] = [:]
    var notesBySource: [String: [CatalogSourceNote]] = [:]
    var artifactsBySource: [String: [CatalogArtifact]] = [:]
    var sourceTypesByProject: [String: [CatalogSourceType]] = [:]
    var fieldsByProject: [String: [CatalogMetadataField]] = [:]
    var metadataBySource: [String: [CatalogMetadataEntry]] = [:]
    var fileCountByProject: [String: Int] = [:]
    var lastResult = OnboardingResult(
        projectDir: "/tmp/robins-family.provenencia",
        userID: "00000000-0000-7000-8000-000000000001",
        displayName: "Jake Robins",
        ref: "USR-F4N2P",
        project: ProjectInfo(
            label: "Robins Family",
            folderName: "robins-family.provenencia",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z",
            updatedByUserID: "00000000-0000-7000-8000-000000000001",
            updatedByDisplayName: "Jake Robins",
            updatedByRef: "USR-F4N2P"
        )
    )

    init(
        identity: InstallIdentity? = nil,
        activeProjectDir: String? = nil,
        catalogUsers: [InstallIdentity] = [
            InstallIdentity(
                userID: "00000000-0000-7000-8000-000000000001",
                displayName: "Jane Smith",
                ref: "USR-A1B2C"
            )
        ]
    ) {
        self.identity = identity
        self.activeProjectDir = activeProjectDir
        self.catalogUsers = catalogUsers
    }

    func installIdentity(identityDir _: String) async throws -> InstallIdentity? {
        identity
    }

    func completeOnboarding(
        identityDir _: String,
        parentDir: String,
        displayName: String,
        familyName: String
    ) async throws -> OnboardingResult {
        let folder = ProjectSlug.folderName(from: familyName)
        let projectDir = parentDir + "/" + folder
        let ref = identity?.ref ?? lastResult.ref
        let userID = identity?.userID ?? lastResult.userID
        identity = InstallIdentity(userID: userID, displayName: displayName, ref: ref)
        let now = ISO8601DateFormatter().string(from: Date())
        let info = ProjectInfo(
            label: familyName,
            folderName: folder,
            createdAt: now,
            updatedAt: now,
            updatedByUserID: userID,
            updatedByDisplayName: displayName,
            updatedByRef: ref
        )
        let result = OnboardingResult(
            projectDir: projectDir,
            userID: userID,
            displayName: displayName,
            ref: ref,
            project: info
        )
        activeProjectDir = result.projectDir
        catalogUsers = [InstallIdentity(userID: userID, displayName: displayName, ref: ref)]
        projectInfos[projectDir] = info
        return result
    }

    func activeProject(identityDir _: String) async throws -> String? {
        activeProjectDir
    }

    func listProjectUsers(projectDir _: String) async throws -> [InstallIdentity] {
        catalogUsers
    }

    func openProject(
        identityDir _: String,
        projectDir: String,
        displayName: String,
        adoptUserID: String
    ) async throws -> OnboardingResult {
        if !adoptUserID.isEmpty, let match = catalogUsers.first(where: { $0.userID == adoptUserID }) {
            identity = match
            activeProjectDir = projectDir
            let info = projectInfos[projectDir] ?? ProjectInfo(
                label: ProjectSlug.labelFromFolder(projectDir),
                folderName: URL(fileURLWithPath: projectDir).lastPathComponent,
                createdAt: "",
                updatedAt: "",
                updatedByUserID: match.userID,
                updatedByDisplayName: match.displayName,
                updatedByRef: match.ref
            )
            return OnboardingResult(
                projectDir: projectDir,
                userID: match.userID,
                displayName: match.displayName,
                ref: match.ref,
                project: info
            )
        }
        if identity == nil {
            identity = InstallIdentity(userID: lastResult.userID, displayName: displayName, ref: lastResult.ref)
        }
        let name = identity?.displayName ?? displayName
        let ref = identity?.ref ?? lastResult.ref
        let userID = identity?.userID ?? lastResult.userID
        let info = projectInfos[projectDir] ?? ProjectInfo(
            label: ProjectSlug.labelFromFolder(projectDir),
            folderName: URL(fileURLWithPath: projectDir).lastPathComponent,
            createdAt: "",
            updatedAt: "",
            updatedByUserID: userID,
            updatedByDisplayName: name,
            updatedByRef: ref
        )
        let result = OnboardingResult(
            projectDir: projectDir,
            userID: userID,
            displayName: name,
            ref: ref,
            project: info
        )
        activeProjectDir = projectDir
        projectInfos[projectDir] = info
        return result
    }

    func removeActiveProject(identityDir _: String) async throws {
        activeProjectDir = nil
    }

    func signOut(identityDir _: String) async throws {
        activeProjectDir = nil
        identity = nil
    }

    func projectInfo(projectDir: String) async throws -> ProjectInfo {
        if let info = projectInfos[projectDir] {
            return info
        }
        return ProjectInfo(
            label: ProjectSlug.labelFromFolder(projectDir),
            folderName: URL(fileURLWithPath: projectDir).lastPathComponent,
            createdAt: "",
            updatedAt: "",
            updatedByUserID: "",
            updatedByDisplayName: "",
            updatedByRef: ""
        )
    }

    func listSources(projectDir: String) async throws -> [CatalogSource] {
        sourcesByProject[projectDir] ?? []
    }

    func getSourceWorkspace(projectDir: String, sourceID: String) async throws -> CatalogSourceWorkspace {
        let source = (sourcesByProject[projectDir] ?? []).first { $0.id == sourceID }
            ?? CatalogSource(id: sourceID, ref: "SRC-XXXXX", sourceTypeID: "", title: "", description: "")
        return CatalogSourceWorkspace(
            source: source,
            notes: notesBySource[sourceID] ?? [],
            metadata: metadataBySource[sourceID] ?? [],
            artifacts: artifactsBySource[sourceID] ?? []
        )
    }

    func createSource(
        projectDir: String,
        userID _: String,
        sourceTypeID: String,
        title: String,
        description: String
    ) async throws -> CatalogSource {
        let source = CatalogSource(
            id: UUID().uuidString.lowercased(),
            ref: "SRC-FAKE1",
            sourceTypeID: sourceTypeID,
            title: title,
            description: description
        )
        sourcesByProject[projectDir, default: []].append(source)
        return source
    }

    func updateSource(
        projectDir: String,
        userID _: String,
        sourceID: String,
        sourceTypeID: String,
        title: String,
        description: String
    ) async throws -> CatalogSource {
        var list = sourcesByProject[projectDir] ?? []
        guard let idx = list.firstIndex(where: { $0.id == sourceID }) else {
            throw StoreBoom.boom
        }
        list[idx].sourceTypeID = sourceTypeID
        list[idx].title = title
        list[idx].description = description
        sourcesByProject[projectDir] = list
        return list[idx]
    }

    func addSourceNote(projectDir _: String, userID _: String, sourceID: String, body: String) async throws
        -> CatalogSourceNote
    {
        let note = CatalogSourceNote(id: UUID().uuidString.lowercased(), sourceID: sourceID, body: body)
        notesBySource[sourceID, default: []].append(note)
        return note
    }

    func updateSourceNote(projectDir _: String, userID _: String, noteID: String, body: String) async throws
        -> CatalogSourceNote
    {
        for (sourceID, notes) in notesBySource {
            if let idx = notes.firstIndex(where: { $0.id == noteID }) {
                var copy = notes
                copy[idx].body = body
                notesBySource[sourceID] = copy
                return copy[idx]
            }
        }
        throw StoreBoom.boom
    }

    func deleteSourceNote(projectDir _: String, userID _: String, noteID: String) async throws {
        for (sourceID, notes) in notesBySource {
            notesBySource[sourceID] = notes.filter { $0.id != noteID }
        }
    }

    func setSourceMetadata(
        projectDir _: String,
        userID _: String,
        sourceID: String,
        fieldID: String,
        valueText: String,
        date _: CatalogDateValueInput?
    ) async throws -> (valueText: String, dateValueID: String) {
        let field = CatalogMetadataField(
            id: fieldID, key: "field", origin: "user", label: "Field", dataType: "text", description: ""
        )
        let entry = CatalogMetadataEntry(
            field: field, valueText: valueText, dateValueID: "", hasValue: true, suggested: false, sortOrder: 0
        )
        metadataBySource[sourceID, default: []].append(entry)
        return (valueText, "")
    }

    func clearSourceMetadata(projectDir _: String, userID _: String, sourceID: String, fieldID: String) async throws {
        metadataBySource[sourceID] = (metadataBySource[sourceID] ?? []).filter { $0.field.id != fieldID }
    }

    func createArtifact(
        projectDir _: String,
        userID _: String,
        sourceID: String,
        fileID: String,
        description: String
    ) async throws -> CatalogArtifact {
        let art = CatalogArtifact(
            id: UUID().uuidString.lowercased(),
            ref: "ART-FAKE1",
            sourceID: sourceID,
            fileID: fileID,
            description: description,
            file: nil
        )
        artifactsBySource[sourceID, default: []].append(art)
        return art
    }

    func ingestArtifactFile(
        projectDir _: String,
        userID _: String,
        artifactID: String,
        path: String
    ) async throws -> (artifact: CatalogArtifact, file: CatalogFileRef, reused: Bool) {
        let file = CatalogFileRef(
            id: UUID().uuidString.lowercased(),
            relPath: "objects/aa/bb/aabb",
            originalFilename: URL(fileURLWithPath: path).lastPathComponent,
            mediaType: "application/octet-stream",
            byteSize: 0
        )
        for (sourceID, arts) in artifactsBySource {
            if let idx = arts.firstIndex(where: { $0.id == artifactID }) {
                var copy = arts
                copy[idx].fileID = file.id
                copy[idx].file = file
                artifactsBySource[sourceID] = copy
                return (copy[idx], file, false)
            }
        }
        throw StoreBoom.boom
    }

    func listSourceTypes(projectDir: String) async throws -> [CatalogSourceType] {
        sourceTypesByProject[projectDir] ?? []
    }

    func createSourceType(
        projectDir: String,
        userID _: String,
        key: String,
        label: String,
        description: String
    ) async throws -> CatalogSourceType {
        let type = CatalogSourceType(
            id: UUID().uuidString.lowercased(),
            key: key,
            origin: "user",
            label: label,
            description: description
        )
        sourceTypesByProject[projectDir, default: []].append(type)
        return type
    }

    func listMetadataFields(projectDir: String) async throws -> [CatalogMetadataField] {
        fieldsByProject[projectDir] ?? []
    }

    func createMetadataField(
        projectDir: String,
        userID _: String,
        label: String,
        dataType: String,
        description: String
    ) async throws -> CatalogMetadataField {
        let key = FieldSlug.kebab(label)
        if key.isEmpty {
            throw StoreBoom.boom
        }
        if (fieldsByProject[projectDir] ?? []).contains(where: { $0.origin == "user" && $0.key == key }) {
            throw StoreBoom.boom
        }
        let field = CatalogMetadataField(
            id: UUID().uuidString.lowercased(),
            key: key,
            origin: "user",
            label: label,
            dataType: dataType,
            description: description
        )
        fieldsByProject[projectDir, default: []].append(field)
        return field
    }

    func updateMetadataField(
        projectDir: String,
        userID _: String,
        fieldID: String,
        label: String,
        dataType: String,
        description: String
    ) async throws -> CatalogMetadataField {
        var list = fieldsByProject[projectDir] ?? []
        guard let idx = list.firstIndex(where: { $0.id == fieldID }) else {
            throw StoreBoom.boom
        }
        guard list[idx].origin == "user" || list[idx].origin == "provenencia" else {
            throw StoreBoom.boom
        }
        list[idx].label = label
        list[idx].dataType = dataType
        list[idx].description = description
        fieldsByProject[projectDir] = list
        return list[idx]
    }

    func countFiles(projectDir: String) async throws -> Int {
        fileCountByProject[projectDir] ?? 0
    }
}

private enum StoreBoom: Error { case boom }
#endif
