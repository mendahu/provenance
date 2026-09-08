import Testing
@testable import Provenencia

@Suite
struct FieldSlugTests {
    @Test func fixturesMatchGo() {
        for fixture in FieldSlug.fixtures {
            #expect(FieldSlug.kebab(fixture.label) == fixture.key, "\(fixture.label) → \(fixture.key)")
        }
    }

    @Test func unslugifiableReturnsEmpty() {
        #expect(FieldSlug.kebab("...") == "")
        #expect(FieldSlug.kebab("  ") == "")
        #expect(FieldSlug.kebab("") == "")
    }
}
