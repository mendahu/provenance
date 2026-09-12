# Spike 2 — Dogfood the Source catalog

Short path to verify Spike 2 on a Mac without a server.

1. Finish Spike 1 onboarding and land in the app workspace (sidebar + content).
2. Open **Sources** → **Add source** (seeded type, title, optional description).
3. On the Source page: edit description; set credibility; add a note; set text and date metadata (suggestions or **Add field**).
4. Optionally open **Source types** / **Source fields** and create a custom type or field, then use it on a Source.
5. **Add artifact** fileless, then **Add file…** on that row (or attach at create) with a local image/PDF.
6. Confirm bytes under `{project}.provenencia/objects/{hh}/{hh}/{sha256}` and that **Open** works from the Artifact row.
7. Inspect `provenencia.sqlite`: Source-layer rows, `SRC-…` / `ART-…` refs, and `audit_transactions` for creates/updates.
8. Relaunch: workspace returns; Sources list still shows the catalog; File still opens from the relative path.
