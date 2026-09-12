import Foundation
import Testing
@testable import Provenencia

@Suite
struct CatalogSessionStoreTests {
    private let projectDir = "/tmp/session.provenencia"

    @Test func workspaceNavCountsMarksSessionHeld() async throws {
        let store = FakeStore()
        _ = try await store.workspaceNavCounts(projectDir: projectDir)
        #expect(store.heldCatalogProjectDir == projectDir)
    }

    @Test func listSourcesMarksSessionHeld() async throws {
        let store = FakeStore()
        _ = try await store.listSources(projectDir: projectDir)
        #expect(store.heldCatalogProjectDir == projectDir)
    }

    @Test func closeCatalogSessionClearsHeldAndRecordsDir() async throws {
        let store = FakeStore()
        _ = try await store.workspaceNavCounts(projectDir: projectDir)
        #expect(store.heldCatalogProjectDir == projectDir)

        try await store.closeCatalogSession(projectDir: projectDir)
        #expect(store.lastClosedCatalogProjectDir == projectDir)
        #expect(store.heldCatalogProjectDir == nil)
    }

    @Test func closeOtherProjectLeavesHeldUntouched() async throws {
        let store = FakeStore()
        _ = try await store.workspaceNavCounts(projectDir: projectDir)
        try await store.closeCatalogSession(projectDir: "/tmp/other.provenencia")
        #expect(store.lastClosedCatalogProjectDir == "/tmp/other.provenencia")
        #expect(store.heldCatalogProjectDir == projectDir)
    }

    @Test func signOutClearsHeldSession() async throws {
        let store = FakeStore(identity: InstallIdentity(userID: "u", displayName: "Jake", ref: "USR-1"))
        store.activeProjectDir = projectDir
        _ = try await store.listSources(projectDir: projectDir)
        try await store.signOut(identityDir: "/tmp/ident")
        #expect(store.heldCatalogProjectDir == nil)
        #expect(store.identity == nil)
    }

    @Test func refreshAllHoldsSessionViaStore() async {
        let store = FakeStore()
        let counts = CatalogCounts(projectDir: projectDir, store: store)
        await counts.refreshAll()
        #expect(store.heldCatalogProjectDir == projectDir)
    }
}
