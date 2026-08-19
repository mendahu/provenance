# Provenance Genealogy — User and Contributor Identity Model

## Status

Draft architecture notes. This document defines how Provenance represents researchers and contributors while remaining local-first and leaving room for future synchronization, sharing, hosted backup, and web access.

The central requirement is:

> A researcher must be able to create and use a Provenance project without creating an online account, while every research change must still have a durable contributor identity that can survive later synchronization or sharing.

---

# 1. Separate contributor identity from authentication

Provenance should not treat "user" and "login account" as the same concept.

There are three distinct concerns:

```text
Contributor identity
    Who performed this research action?

External identity
    Is this contributor known to some external account or identity system?

Authentication
    How does a service prove that someone is allowed to act as that identity?
```

Only the first two belong in a portable project dataset.

Authentication credentials, sessions, password hashes, OAuth refresh tokens, passkeys, and similar secrets belong to the application or service providing authentication. They should not be embedded in a genealogy project file that may be copied, backed up, exported, or shared with other researchers.

---

# 2. Local-first identity

A fresh desktop installation must not require authentication.

On first use, Provenance can create a local user identity with a globally unique UUIDv7 and ask only for enough information to identify the researcher in audit history, typically a display name.

For example:

```text
Jake Robins
USR-UUID = 019c...
```

That UUID is the durable identity used in project history.

Creating a new project then records this user in the project and audit revisions can immediately attribute actions to that identity.

```text
Revision 1
  user_id = Jake's local UUID
  action = create_project
```

No email address, password, cloud service, or network connection is required.

The same local application identity may be reused when the researcher creates additional projects, allowing the same UUID to identify that contributor consistently across their own local datasets.

---

# 3. `users`

The `users` table represents durable research contributors known to a project.

It is intentionally small.

```sql
CREATE TABLE users (
    id              BLOB PRIMARY KEY,          -- UUIDv7, 16 bytes
    display_name    TEXT NOT NULL,
    kind            TEXT NOT NULL DEFAULT 'human',
    status          TEXT NOT NULL DEFAULT 'active',

    CHECK (kind IN ('human', 'system')),
    CHECK (status IN ('active', 'inactive'))
) STRICT;
```

## 3.1 `id`

`id` is the contributor's durable identity and must remain stable across synchronization.

It is not scoped to one particular project. A locally created user should retain the same UUID when that person's identity is introduced into other Provenance projects.

This makes audit histories from different replicas or projects capable of referring to the same contributor without relying on mutable properties such as name or email address.

## 3.2 `display_name`

`display_name` is the human-readable attribution shown in the research UI and audit history.

Examples:

```text
Jake Robins
Jane Smith
A. García
```

It is not required to be globally unique and is not an authentication credential.

A user's name may change over time. The audit system records that change like any other durable project data.

## 3.3 `kind`

Most users are human researchers.

A `system` identity allows durable attribution for automated operations that genuinely create or modify research state, such as a future importer or synchronization process where attributing the action only to a human would be misleading.

Application cache operations such as generating thumbnails do not need research audit attribution and therefore do not require system-user revisions.

## 3.4 `status`

A contributor should generally not be deleted simply because they no longer participate in a project. Historical audit revisions continue to reference the contributor.

`inactive` allows a contributor to be retired from current use while preserving attribution history.

The initial implementation should not support destructive deletion of users that are referenced by audit history.

---

# 4. External identity links

A local Provenance user may later become associated with one or more external identity systems.

Examples might include:

```text
Provenance hosted account
Google OIDC identity
Apple identity
enterprise identity provider
future peer-to-peer synchronization identity
```

These relationships should extend the existing local user rather than replace it.

For example:

```text
Before sign-in

User 019c...
  display_name = "Jake Robins"

After linking hosted account

User 019c...
  display_name = "Jake Robins"
  external identity -> provenance / acct_8372
```

The local research history continues to reference the same User UUID.

## 4.1 `user_external_identities`

```sql
CREATE TABLE user_external_identities (
    id                  BLOB PRIMARY KEY,          -- UUIDv7, 16 bytes
    user_id             BLOB NOT NULL REFERENCES users(id),
    provider            TEXT NOT NULL,
    provider_subject    TEXT NOT NULL,
    display_identifier  TEXT,

    UNIQUE (provider, provider_subject)
) STRICT;
```

### `provider`

`provider` identifies the identity namespace, not necessarily the authentication protocol.

Examples:

```text
provenance
apple
google
example-genealogy-service
```

### `provider_subject`

`provider_subject` is the stable identifier assigned by that provider.

For OAuth/OIDC-style systems this should normally be the provider's immutable subject identifier rather than an email address.

Email addresses and usernames can change and therefore should not be used as durable identity keys.

### `display_identifier`

`display_identifier` is optional convenience information such as an email address or username useful to the researcher when recognizing the linked account.

It is descriptive only. It is not the durable key and should not be trusted as proof of identity.

---

# 5. Authentication does not belong in the project database

The project database should not contain authentication secrets.

Do not store project-level fields such as:

```text
password_hash
access_token
refresh_token
OAuth client secret
session cookie
passkey private material
```

A desktop application may use operating-system facilities such as Keychain or Credential Manager for local secrets.

A hosted Provenance service may maintain its own account/authentication database.

Conceptually:

```text
Portable genealogy project

users
user_external_identities
audit_transactions
research data

        ↑ identity mapping
        │
        │
Hosted service / desktop app security domain

auth accounts
credentials
sessions
OAuth tokens
passkeys
permissions
```

The hosted service authenticates an account, resolves it to a stable external identity, and then determines which project User that identity corresponds to.

This keeps copied project files free of reusable login credentials.

---

# 6. Relationship to audit history

`audit_transactions.user_id` references `users.id`.

```sql
audit_transactions.user_id BLOB REFERENCES users(id)
```

The User row is the durable attribution identity. External account mappings are supplementary.

This means an audit history remains understandable offline:

```text
Revision 142
User: Jake Robins
Action: replace_artifact_file
```

without contacting an identity service.

If Jake later links or unlinks a hosted account, historical revisions still refer to the same local User.

A user referenced by audit history must remain resolvable even if the contributor becomes inactive or an external account disappears.

---

# 7. Synchronization and contributor discovery

When datasets or revisions are synchronized, User rows referenced by incoming audit transactions must travel with those transactions.

For example:

```text
Alice's replica
  User A = Alice

Bob's replica
  User B = Bob

After shared synchronization

Project users
  User A = Alice
  User B = Bob

Audit history
  revisions by User A
  revisions by User B
```

Because User IDs are globally unique UUIDs, the replicas do not need to assign new project-local numeric identities.

External identity links can help determine that a contributor arriving from another replica corresponds to an already-known account, but synchronization correctness should not depend solely on mutable values such as display name or email address.

---

# 8. Identity reconciliation

A future sync system may encounter two User rows that appear to represent the same human but were independently created before the identities were linked.

For example:

```text
User A
  "Jake Robins"
  created on Mac

User B
  "Jake Robins"
  created on Windows before synchronization
```

Provenance must not silently rewrite historical audit references merely because names match.

Identity reconciliation should be explicit.

The simplest initial rule is:

> User UUIDs remain distinct unless the application can establish an explicit identity link or the researcher deliberately reconciles them.

A future user-alias/merge mechanism may allow the UI to treat User A and User B as the same contributor while preserving original audit IDs. That mechanism should be designed when synchronization work makes the concrete requirements clear.

---

# 9. Project access and permissions are separate

A User identifies a contributor. It does not, by itself, answer whether that contributor is currently authorized to read or modify a project.

These are separate questions:

```text
Identity
  Who is this contributor?

Authorization
  What may this contributor do with this project?
```

For a purely local single-user project, no project permission model is necessary.

A future sync or hosted service may need roles such as:

```text
owner
editor
viewer
```

Those permissions should be modeled by the synchronization/hosting layer or by a future explicit project-membership model. They should not be encoded as properties of `users`, because the same User may have different permissions in different projects.

This also prevents a local project from requiring cloud-style authorization machinery before sharing exists.

---

# 10. Email addresses and profile information

The core User record should remain intentionally minimal.

Fields such as:

```text
email
avatar
organization
biography
website
```

should not be added merely because conventional account systems usually contain them.

If Provenance later has a concrete research or collaboration use case for contributor profile metadata, that can be introduced separately.

In particular, email should not initially be required because:

- local users do not need one;
- email is not a durable identity key;
- a contributor may use different emails with different services;
- storing unnecessary personal information inside shared genealogy datasets has privacy costs.

---

# 11. Example lifecycle

## Local-only start

```text
1. Jake installs Provenance on macOS.
2. Provenance creates User U1 with a UUIDv7.
3. Jake enters display name "Jake Robins".
4. Jake creates a genealogy project.
5. The project stores User U1.
6. Audit revisions reference U1.
```

No authentication exists or is required.

## Later hosted backup

```text
1. Jake enables Provenance hosted backup.
2. The service authenticates Jake using its own account system.
3. U1 is linked to the hosted account through user_external_identities.
4. Existing project history remains unchanged.
```

## Later collaboration

```text
1. Jane accepts access through a future synchronization service.
2. Jane has her own durable User U2.
3. U2 is introduced into the shared project.
4. Jane's new audit revisions reference U2.
5. Jake's historical revisions continue to reference U1.
```

The project remains intelligible if subsequently opened offline.

---

# 12. Current schema

```text
users
  id
  display_name
  kind
  status

user_external_identities
  id
  user_id -> users.id
  provider
  provider_subject
  display_identifier

users
  ↑
  │ audit attribution
  │
audit_transactions
```

Authentication and project authorization deliberately sit outside this core portable identity schema.

---

# 13. Current architectural rules

1. A local user account is created without requiring authentication or network access.
2. Every contributor receives a globally unique UUIDv7 identity.
3. `users` represents durable research attribution, not login credentials.
4. Display names are descriptive and need not be unique.
5. Email is not required and is not a durable identity key.
6. External accounts extend a local User through `user_external_identities`; they do not replace the User ID.
7. Provider subject identifiers, rather than email addresses, are used for durable external identity mappings.
8. Authentication credentials and sessions do not live in portable project databases.
9. `audit_transactions.user_id` references the durable project User identity.
10. Users referenced by history are preserved; inactive contributors are not destructively deleted.
11. User identity and project authorization are separate concerns.
12. Permissions should not be stored directly on `users`.
13. Synchronization transports referenced User identities along with research history.
14. Independently created duplicate contributor identities are not silently merged.
15. All tables use SQLite `STRICT` typing.

This design allows Provenance to begin as a completely local desktop application while keeping contributor identity stable enough to support future synchronization, collaboration, backup, and hosted services without redesigning research attribution.