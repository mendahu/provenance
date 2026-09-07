import Foundation

struct InstallIdentity: Sendable, Equatable {
    var userID: String
    var displayName: String
    var ref: String
}

struct ProjectInfo: Sendable, Equatable {
    var label: String
    var folderName: String
    var createdAt: String
    var updatedAt: String
    var updatedByUserID: String
    var updatedByDisplayName: String
    var updatedByRef: String
}

struct OnboardingResult: Sendable, Equatable {
    var projectDir: String
    var userID: String
    var displayName: String
    var ref: String
    var project: ProjectInfo
}

struct CatalogSource: Sendable, Equatable {
    var id: String
    var ref: String
    var sourceTypeID: String
    var title: String
    var description: String
}

struct CatalogSourceNote: Sendable, Equatable {
    var id: String
    var sourceID: String
    var body: String
}

struct CatalogFileRef: Sendable, Equatable {
    var id: String
    var relPath: String
    var originalFilename: String
    var mediaType: String
    var byteSize: Int64
}

struct CatalogArtifact: Sendable, Equatable {
    var id: String
    var ref: String
    var sourceID: String
    var fileID: String
    var description: String
    var file: CatalogFileRef?
}

struct CatalogSourceType: Sendable, Equatable {
    var id: String
    var key: String
    var origin: String
    var label: String
    var description: String
}

struct CatalogMetadataField: Sendable, Equatable {
    var id: String
    var key: String
    var origin: String
    var label: String
    var dataType: String
    var description: String
}

struct CatalogMetadataEntry: Sendable, Equatable {
    var field: CatalogMetadataField
    var valueText: String
    var dateValueID: String
    var hasValue: Bool
    var suggested: Bool
    var sortOrder: Int32
}

struct CatalogSourceWorkspace: Sendable, Equatable {
    var source: CatalogSource
    var notes: [CatalogSourceNote]
    var metadata: [CatalogMetadataEntry]
    var artifacts: [CatalogArtifact]
}

struct CatalogDateValueInput: Sendable, Equatable {
    var kind: String
    var qualifier: String
    var calendar: String
    var startYear: Int32?
    var startMonth: Int32?
    var startDay: Int32?
    var phrase: String
}

protocol GenealogyStore: Sendable {
    func installIdentity(identityDir: String) async throws -> InstallIdentity?
    func completeOnboarding(
        identityDir: String,
        parentDir: String,
        displayName: String,
        familyName: String
    ) async throws -> OnboardingResult
    func signOut(identityDir: String) async throws
    func activeProject(identityDir: String) async throws -> String?
    func listProjectUsers(projectDir: String) async throws -> [InstallIdentity]
    func openProject(
        identityDir: String,
        projectDir: String,
        displayName: String,
        adoptUserID: String
    ) async throws -> OnboardingResult
    func removeActiveProject(identityDir: String) async throws
    func projectInfo(projectDir: String) async throws -> ProjectInfo

    func listSources(projectDir: String) async throws -> [CatalogSource]
    func getSourceWorkspace(projectDir: String, sourceID: String) async throws -> CatalogSourceWorkspace
    func createSource(
        projectDir: String,
        userID: String,
        sourceTypeID: String,
        title: String,
        description: String
    ) async throws -> CatalogSource
    func updateSource(
        projectDir: String,
        userID: String,
        sourceID: String,
        sourceTypeID: String,
        title: String,
        description: String
    ) async throws -> CatalogSource
    func addSourceNote(projectDir: String, userID: String, sourceID: String, body: String) async throws
        -> CatalogSourceNote
    func updateSourceNote(projectDir: String, userID: String, noteID: String, body: String) async throws
        -> CatalogSourceNote
    func deleteSourceNote(projectDir: String, userID: String, noteID: String) async throws
    func setSourceMetadata(
        projectDir: String,
        userID: String,
        sourceID: String,
        fieldID: String,
        valueText: String,
        date: CatalogDateValueInput?
    ) async throws -> (valueText: String, dateValueID: String)
    func clearSourceMetadata(projectDir: String, userID: String, sourceID: String, fieldID: String) async throws
    func createArtifact(
        projectDir: String,
        userID: String,
        sourceID: String,
        fileID: String,
        description: String
    ) async throws -> CatalogArtifact
    func ingestArtifactFile(
        projectDir: String,
        userID: String,
        artifactID: String,
        path: String
    ) async throws -> (artifact: CatalogArtifact, file: CatalogFileRef, reused: Bool)
    func listSourceTypes(projectDir: String) async throws -> [CatalogSourceType]
    func createSourceType(
        projectDir: String,
        userID: String,
        key: String,
        label: String,
        description: String
    ) async throws -> CatalogSourceType
    func listMetadataFields(projectDir: String) async throws -> [CatalogMetadataField]
    func createMetadataField(
        projectDir: String,
        userID: String,
        key: String,
        label: String,
        dataType: String,
        description: String
    ) async throws -> CatalogMetadataField
}
