# Provenance Genealogy Software — Proposed Application Stack

## Status

This document captures the current proposed application architecture and technology stack. It is intended as a working design direction rather than a final implementation specification.

The primary goals are:

- local-first operation;
- strong user ownership and control of data;
- offline capability;
- long-term interoperability;
- native desktop experience;
- a clean path from a personal macOS application to a commercial cross-platform product;
- shared domain and persistence logic across platforms;
- optional collaboration and cloud synchronization without making cloud services authoritative.

## 1. Platform Strategy

The initial application would target **macOS as a native application**.

If the application is later commercialized, additional clients could be developed for Windows, potentially Linux, and potentially the web.

The architecture should therefore avoid making the genealogy domain model, storage layer, import/export logic, or synchronization system dependent on Apple technologies.

```text
                         Shared Go Core
                              │
           ┌──────────────────┼──────────────────┐
           │                  │                  │
           ▼                  ▼                  ▼
        macOS              Windows            Linux
     Swift/SwiftUI        C#/WinUI        future native UI

                              │
                              │ shared protocols/data formats
                              ▼
                         Web / Server
```

The native UIs are platform-specific. The genealogy engine underneath them is shared.

## 2. Core Technology Choices

### Go

Go would implement the portable application core.

This is attractive because it runs on macOS, Windows, Linux, and servers; is well suited to domain logic and data processing; has mature SQLite support; can be compiled into native shared libraries; allows substantial core reuse by future synchronization or web services; and naturally supports command-line tooling.

The Go core would own functionality such as:

```text
domain model
database access
schema migrations
query logic
GEDCOM import/export
validation
search
relationship traversal
merge logic
duplicate detection
change history
sync algorithms
media metadata
```

The platform UI should not reimplement this logic.

## 3. macOS Client

The first client would be a native macOS application built primarily with Swift, SwiftUI, and AppKit where necessary.

SwiftUI would provide the main application UI, while AppKit could be used where macOS-native functionality or more mature desktop controls are required.

The macOS layer would primarily own windows, navigation, menus, toolbars, keyboard commands, drag and drop, file dialogs, document integration, accessibility, platform-specific presentation, and view state. It should not directly implement genealogy business rules.

```text
SwiftUI / AppKit
       │
       ▼
Swift application layer
       │
       ▼
FFI boundary
       │
       ▼
Go genealogy core
       │
       ▼
SQLite + media
```

## 4. Future Windows Client

A commercial Windows client could be implemented using C# and WinUI 3. The Windows client would implement its own native presentation layer while calling the same Go core used by macOS.

```text
C# / WinUI
     │
     ▼
native interop
     │
     ▼
Go genealogy core
     │
     ▼
SQLite
```

This avoids rewriting genealogy rules, persistence logic, migrations, GEDCOM support, search, merge logic, synchronization, validation, and most non-UI application behavior.

The Windows application would still require its own UI implementation and platform integration. This is an intentional tradeoff: native UIs require more development effort than a shared web UI, but provide better platform integration and allow each application to behave naturally on its host operating system.

## 5. Linux

The same core architecture can support Linux. The Go core can be built as a Linux shared library and used by a future Linux UI.

The unresolved decision would primarily be the Linux frontend toolkit, for example GTK, Qt, or another native UI framework. Linux is therefore not an immediate target but should not require redesigning the genealogy engine or data model.

## 6. Foreign Function Interface

The native applications communicate with Go through an **FFI — Foreign Function Interface**.

Go can compile the core as a shared library exposing a C-compatible ABI:

```text
macOS      .dylib
Windows    .dll
Linux      .so
```

The platform applications call exported functions from that library. The FFI should be treated as a deliberate application boundary and should not expose the internal Go object graph directly.

Avoid a very granular interface such as `getPersonName()`, `getPersonBirthDate()`, `getPersonParents()`, and `getPersonSources()`. Prefer application-level operations such as `getPersonWorkspace()`, `searchPeople()`, `createClaim()`, `updateSource()`, `importGEDCOM()`, and `mergePeople()`.

This minimizes coupling and reduces FFI chatter.

## 7. FFI Data Format

Structured data crossing the FFI boundary needs a language-neutral representation. Two primary candidates are JSON and Protocol Buffers.

### JSON

Advantages include simplicity, easy inspection and logging, trivial Go and Swift support, easy test fixtures, and sufficient performance for most genealogy operations.

```text
Swift object
    │
JSON encode
    ▼
byte buffer
    │
FFI
    ▼
Go
    │
JSON decode
    ▼
domain operation
```

### Protocol Buffers

Protocol Buffers may eventually provide a stronger contract. A `.proto` definition could generate Go, Swift, and C# types and therefore become a language-independent specification of the application API.

```text
                genealogy.proto
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
         Go         Swift         C#
```

Protocol Buffers would primarily be adopted for explicit interface schemas, generated cross-language types, API evolution, and potentially sharing message definitions with synchronization. Performance is not the main motivation.

An initial implementation could reasonably use JSON and move toward protobuf if maintaining the interface manually becomes cumbersome.

## 8. Asynchronous Behavior

FFI calls themselves are ordinary synchronous native calls. A long-running Go operation must therefore not block the macOS main UI thread.

The Swift application should generally expose asynchronous APIs such as:

```swift
let person = try await store.person(id: personID)
```

Internally, the operation may invoke a synchronous Go function on non-UI execution.

Long-running tasks may warrant true asynchronous operations within the Go core, including large GEDCOM imports, search index rebuilding, media processing, synchronization, bulk validation, duplicate detection, and large exports. The Go runtime can use goroutines internally.

## 9. Persistence

### SQLite

SQLite is the proposed canonical local database.

Advantages include embedded operation, no database server, excellent portability, transactional safety, mature tooling, predictable backups, cross-platform database files, and support for indexes, JSON functionality, FTS, and other useful features.

The Go core should own database access:

```text
Native UI
    │
    ▼
Go core
    │
    ▼
SQLite
```

Swift or C# should not independently issue queries against the same database. This creates a single authoritative persistence implementation across platforms.

## 10. SQLite Packaging

A deliberate decision will be required regarding the Go SQLite driver.

### Native SQLite through cgo

```text
Go
 │
cgo
 │
SQLite C implementation
```

This provides the standard SQLite implementation but adds native build-toolchain requirements. Because the application already needs native platform-specific builds, this is considered acceptable.

### Pure-Go SQLite implementation

This simplifies cross-compilation and removes the C dependency. It is also viable, provided compatibility and required SQLite features are satisfactory.

The current preference is not to optimize prematurely around avoiding cgo. A mature SQLite implementation with controlled application builds is likely preferable.

## 11. Bundled SQLite

The application should preferably control its SQLite implementation rather than depending on whichever SQLite build happens to be installed by the operating system.

This makes functionality consistent across macOS, Windows, and Linux and allows the project to standardize features such as FTS5, JSON functionality, R-tree indexes, custom functions, and selected SQLite extensions.

The SQLite file itself remains portable across platforms.

## 12. Local Genealogy File

A genealogy project should ideally be a portable, self-contained object.

```text
Robins Family.genealogy/
├── genealogy.sqlite
├── media/
├── thumbnails/
└── metadata.json
```

On macOS this could appear to users as a single document/package even though it contains multiple files internally. The same contents should remain intelligible to future Windows or Linux applications.

Platform-specific absolute paths should not be stored in the genealogy database.

## 13. Media Storage

Documents, photographs, scans, PDFs, and other evidence should normally be **ingested into the genealogy project**, rather than referencing their original filesystem locations.

This prevents research from depending on fragile absolute paths. A copied genealogy project should retain its associated evidence.

## 14. Media Model

The domain model should distinguish a semantic media record from physical blob storage.

```text
MediaAsset
    │
    ▼
Blob
    │
    ▼
Storage
```

Example:

```text
MediaAsset
  id
  title
  original_filename
  MIME type
  blob_hash

Blob
  hash
  size

Storage
  local path
  optional remote storage state
```

Citations and other genealogy records should reference a `MediaAsset` ID, not filesystem paths or cloud URLs. This prevents storage implementation details from leaking into the genealogy model.

## 15. Content-Addressed Media

Media blobs should be considered for content-addressed storage.

```text
SHA-256(file contents)
        │
        ▼
7f82375d...
        │
        ▼
media/7f/7f82375d...
```

Benefits include automatic duplicate detection, integrity checking, efficient synchronization, immutable blob identity, independence from filenames, and straightforward local/cloud reconciliation. The original filename remains metadata rather than storage identity.

## 16. Local-First Identity

The desktop application should not require a cloud account merely to operate.

Three identities should be kept conceptually separate:

```text
OS user
   │
   ▼
Local researcher / actor
   │
   ▼
Optional cloud account
```

The operating system controls access to local files. A local **Actor** identifies who created or modified research records. Research records may contain `created_by = actor_id`.

This ensures authorship remains meaningful even if cloud services later disappear.

## 17. Cloud Accounts

A cloud account becomes necessary only when the user enables online services such as synchronization, collaboration, sharing, remote backup, or family invitations.

The account should be associated with an existing local Actor rather than replacing it.

```text
Actor
   │
   └── optional CloudAccount
```

Cloud authentication therefore answers, “Who is making this network request?” The Actor answers, “Who authored this research?” These should remain separate concepts.

## 18. Authorization

For collaborative projects, the server may maintain workspace membership separately from research authorship.

```text
WorkspaceMembership
  workspace_id
  account_id
  actor_id
  role
```

Possible roles might include owner, editor, and viewer. Authentication, authorization, and research authorship therefore remain distinct concerns.

## 19. Local-First Collaboration

Cloud services should not become the canonical owner of the genealogy database. Each native client should retain a complete local database.

```text
Mac
  local SQLite
       │
       │
       ▼
    Sync service
       ▲
       │
Windows
  local SQLite
```

The cloud service coordinates replication rather than becoming the only authoritative database. The application should continue to function offline.

## 20. Sync Server

A future synchronization service could also be written in Go. This potentially allows shared packages for domain definitions, mutation models, validation, sync rules, conflict handling, and serialization.

The server might use PostgreSQL even though desktop clients use SQLite.

```text
Desktop Go Core
      │
      │ sync protocol
      ▼
Go Sync Server
      │
      ▼
PostgreSQL / object storage
```

Persistence details should not dictate the domain model.

## 21. Cloud Media

When collaboration is enabled, local media blobs can be synchronized into object storage such as S3, R2, B2, or an equivalent service.

The genealogy database should still not store provider-specific URLs. It should retain stable blob or media identifiers. The synchronization layer maps those identifiers to cloud object keys.

## 22. Lazy Media Synchronization

A shared tree could eventually contain many gigabytes of scans and photographs. A new collaborator should not necessarily be required to download every original file immediately.

A useful model would synchronize media metadata, filenames, hashes, dimensions, MIME types, and thumbnails first, while fetching full-resolution blobs on demand.

```text
User opens media
      │
      ▼
Is blob local?
   │       │
  yes      no
   │       │
   ▼       ▼
display   fetch from cloud
              │
              ▼
           cache locally
```

This allows large collaborative repositories while retaining local access to actively used content.

## 23. Web Application Path

The shared Go architecture does not prevent a future web client.

A conventional web implementation could use:

```text
Browser
   │
HTTP / WebSocket
   │
Go server
   │
shared genealogy packages
   │
database
```

The Go domain logic should not know whether it was invoked through FFI, HTTP, CLI, or sync. Instead, platform-specific adapters invoke the same application services.

```text
                     Go Core
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
       FFI             HTTP             CLI
        │               │
     Native UI       Web client
```

## 24. Local-First Web

A conventional server-backed web client would not provide the same degree of local-first ownership as the desktop application.

A future local-first web version could instead use a browser-local database and media cache with a sync client connecting to the Go server. Potential browser storage technologies include SQLite compiled to WebAssembly and persistent browser filesystem/storage APIs.

This is considered feasible but is not necessary for the initial application.

## 25. Command-Line Tooling

A Go core creates a natural opportunity for an independent CLI.

Possible commands could eventually include:

```text
genealogy validate
genealogy import
genealogy export
genealogy search
genealogy migrate
genealogy stats
genealogy repair
```

The CLI would be valuable for automated tests, database recovery, migrations, diagnostics, developer tooling, power users, and batch operations. This also provides a way to exercise the core independently of any UI.

## 26. Proposed Repository Shape

A possible repository structure is:

```text
/
├── core/
│   ├── domain/
│   ├── application/
│   ├── database/
│   ├── migrations/
│   ├── gedcom/
│   ├── search/
│   ├── merge/
│   ├── sync/
│   ├── media/
│   └── validation/
│
├── api/
│   ├── ffi/
│   └── proto/
│
├── cmd/
│   ├── genealogy-cli/
│   └── genealogy-server/
│
├── macos/
│   ├── App/
│   ├── Views/
│   ├── ViewModels/
│   └── Platform/
│
├── windows/
│   └── future/
│
├── web/
│   └── future/
│
└── docs/
```

The exact package boundaries can evolve, but the dependency direction should remain clear:

```text
platform UI
     │
     ▼
application API
     │
     ▼
domain/core
     │
     ▼
persistence
```

Platform code should not leak downward into the core.

## 27. Architectural Principles

### The application is not the data

The user's research should survive replacing the UI, switching operating systems, discontinuation of the commercial service, and loss of cloud access.

### Cloud services are optional capabilities

An account may provide sync, sharing, backup, and collaboration, but should not be required to open or edit local research.

### Genealogy semantics remain platform-independent

Core concepts such as sources, interpretations, claims, conclusions, citations, actors, relationships, events, places, media, and change history must not depend on SwiftUI, WinUI, HTTP, or any particular storage provider.

### Platform UIs are replaceable clients

SwiftUI is the first presentation layer, not the application architecture.

### Local data is canonical

The desktop client should be capable of operating normally without a network connection.

### Storage references are logical, not physical

Domain objects reference stable IDs. They should not directly reference absolute filesystem paths, S3 URLs, or platform-specific identifiers.

### Auditability is first-class

Authorship and change history are part of the research record, not merely application metadata.

## 28. Current Preferred Initial Stack

For the first macOS implementation:

```text
UI
  Swift
  SwiftUI
  AppKit where appropriate

Core
  Go

Interop
  C ABI / FFI
  initially JSON or Protocol Buffers

Persistence
  SQLite

Media
  project-local files
  content-addressed blobs where practical

Document format
  portable project/package
  SQLite + media + metadata

Accounts
  none required for local use

Identity
  local Actor

Cloud
  none required initially
```

A later commercial architecture could add:

```text
Windows
  C#
  WinUI 3

Linux
  native frontend TBD

Server
  Go

Server database
  likely PostgreSQL

Blob storage
  S3-compatible object storage

Sync
  shared Go protocol/domain packages

Web
  frontend framework TBD
  Go server
  potentially local-first browser storage
```

## 29. Decisions Still Open

The architecture leaves several implementation decisions intentionally unresolved:

- JSON versus Protocol Buffers for the first FFI API;
- specific Go SQLite driver;
- cgo SQLite versus a pure-Go implementation;
- precise document/package format;
- whether the SQLite database itself is directly exposed/documented as an interoperability format;
- content-addressed storage details;
- encryption strategy;
- local database locking and concurrent access;
- exact Actor model;
- sync protocol;
- mutation/change-log format;
- server-side persistence model;
- conflict-resolution semantics;
- eventual Linux frontend toolkit;
- eventual web frontend stack.

These can be decided independently without changing the core direction described above.

## 30. Summary

The proposed architecture treats the genealogy system as a **portable Go application engine with native platform clients**.

The initial application would be:

```text
SwiftUI
   │
   ▼
Go Core
   │
   ├── genealogy domain logic
   ├── SQLite
   ├── GEDCOM
   ├── media
   ├── validation
   └── future sync
```

This allows development to begin as a polished native macOS application without committing the underlying genealogy system to Apple.

If commercialization later warrants Windows support, a native Windows client can be built against the same Go core. Linux and web clients can follow without changing the fundamental storage or domain model.

The architecture prioritizes local-first operation, ownership, privacy, interoperability, and long-term durability while preserving a practical route to a multi-platform commercial product.