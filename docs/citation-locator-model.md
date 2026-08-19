# Provenance Genealogy — Citation Locator Model

## Status

Draft architecture notes. This document defines the JSON structure used by `citations.locator_json` in the Interpretation layer.

A Citation identifies an addressable portion of exactly one Artifact. The locator must be independently resolvable from the Citation's `artifact_id` and `locator_json`; it does not depend on another Citation.

---

# 1. Design principles

Citation locators must work across different Artifact media without forcing every Citation into one mutually exclusive locator type.

Examples include:

```text
PDF page
PDF page -> polygon region
PDF page -> quoted text
image -> polygon region
audio -> time range
video -> time range -> polygon frame region
```

The locator is therefore a versioned, ordered chain of selectors. Each selector narrows the context produced by the selectors before it.

```json
{
  "version": 1,
  "selectors": [
    { "type": "..." }
  ]
}
```

Conceptually:

```text
LocatorV1 {
    version: 1
    selectors: Selector[]   // ordered, at least one
}
```

The selector vocabulary is application-defined but extensible. Unknown selector types must be preserved losslessly even when the current client cannot render or edit them.

---

# 2. Citation table relationship

The Interpretation-layer Citation table stores only the complete locator JSON, not a separate `locator_type` column:

```sql
CREATE TABLE citations (
    id              BLOB PRIMARY KEY,
    artifact_id     BLOB NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    locator_json    TEXT NOT NULL,
    transcription   TEXT,
    description     TEXT,
    notes           TEXT
) STRICT;
```

A separate locator type column would be ambiguous for composed locators such as `page -> region`.

---

# 3. `page` selector

The `page` selector identifies a page by its position in the Artifact itself.

For a PDF, `artifact_page` is the page number the application uses to navigate the PDF. It is 1-based and is the authoritative locator value.

A scanned book, register, newspaper, or archival document may display a different page number or label on the image itself. That marked value is retained separately as optional descriptive information in `page_label`.

Example:

```json
{
  "type": "page",
  "artifact_page": 37,
  "page_label": "23"
}
```

This means:

```text
PDF / Artifact page: 37
Marked page in scanned work: 23
```

The locator navigates to Artifact page 37. `page_label` helps the researcher understand and display the pagination of the underlying work but does not determine navigation within the Artifact.

Schema:

```text
PageSelector {
    type: "page"
    artifact_page: integer >= 1
    page_label?: string
}
```

`page_label` is deliberately text rather than an integer because source pagination may contain values such as:

```text
iv
xii
A-3
23a
folio 17r
```

An unnumbered page simply omits `page_label`.

The distinction is important because Artifact pagination and source pagination frequently diverge due to covers, title pages, front matter, inserts, foldouts, scanning order, or missing pages.

The general rule is:

> `artifact_page` answers where the Citation is in the digital Artifact. `page_label` records how that page identifies itself in the underlying source.

---

# 4. `region` selector

Selects an arbitrary polygonal region from an image-like context, including a standalone image, a rendered PDF page, or a video-frame context.

A polygon is used rather than a rectangle so the same selector can represent both simple rectangular crops and irregularly shaped evidence such as handwriting blocks, seals, marginal notes, damaged document fragments, or people in photographs.

```json
{
  "type": "region",
  "points": [
    { "x": 0.31, "y": 0.18 },
    { "x": 0.73, "y": 0.18 },
    { "x": 0.70, "y": 0.39 },
    { "x": 0.34, "y": 0.42 }
  ],
  "unit": "normalized"
}
```

Schema:

```text
RegionSelector {
    type: "region"
    points: Point[]       // at least 3 points
    unit: "normalized"
}

Point {
    x: number between 0 and 1
    y: number between 0 and 1
}
```

The polygon is implicitly closed by connecting the final point back to the first point. The first point therefore should not be repeated at the end of the array.

For version 1:

- `points` must contain at least three distinct points;
- every point must lie within the normalized media bounds;
- points are interpreted in array order as the polygon boundary;
- the polygon must not self-intersect;
- degenerate polygons with zero area are invalid.

Normalized coordinates keep Citations stable across rendering resolutions and generated previews.

A rectangle is represented as an ordinary four-point polygon. For example:

```json
{
  "type": "region",
  "points": [
    { "x": 0.31, "y": 0.18 },
    { "x": 0.73, "y": 0.18 },
    { "x": 0.73, "y": 0.39 },
    { "x": 0.31, "y": 0.39 }
  ],
  "unit": "normalized"
}
```

The application may provide a rectangular drag-selection UI as a convenience and serialize the resulting rectangle as four polygon points. More advanced tools may allow users to add or move arbitrary vertices without requiring a schema change.

A crop on a scanned PDF page is represented compositionally:

```json
{
  "version": 1,
  "selectors": [
    {
      "type": "page",
      "artifact_page": 37,
      "page_label": "23"
    },
    {
      "type": "region",
      "points": [
        { "x": 0.31, "y": 0.18 },
        { "x": 0.73, "y": 0.18 },
        { "x": 0.70, "y": 0.39 },
        { "x": 0.34, "y": 0.42 }
      ],
      "unit": "normalized"
    }
  ]
}
```

---

# 5. `time_range` selector

Selects an interval from time-based media such as audio or video.

```json
{
  "type": "time_range",
  "start_ms": 802400,
  "end_ms": 845100
}
```

Schema:

```text
TimeRangeSelector {
    type: "time_range"
    start_ms: integer >= 0
    end_ms: integer > start_ms
}
```

Milliseconds are the canonical stored unit.

A video Citation can compose time and spatial selection:

```json
{
  "version": 1,
  "selectors": [
    {
      "type": "time_range",
      "start_ms": 15120,
      "end_ms": 19440
    },
    {
      "type": "region",
      "points": [
        { "x": 0.12, "y": 0.08 },
        { "x": 0.42, "y": 0.08 },
        { "x": 0.42, "y": 0.53 },
        { "x": 0.12, "y": 0.53 }
      ],
      "unit": "normalized"
    }
  ]
}
```

---

# 6. `text_quote` selector

Selects textual content by the text itself rather than unstable paragraph numbers or rendered coordinates.

```json
{
  "type": "text_quote",
  "exact": "William Robins, carpenter",
  "prefix": "household of ",
  "suffix": " aged 43"
}
```

Schema:

```text
TextQuoteSelector {
    type: "text_quote"
    exact: non-empty string
    prefix?: string
    suffix?: string
}
```

`exact` is the selected text. Optional `prefix` and `suffix` provide surrounding context to disambiguate repeated text without becoming part of the selected content.

For a PDF with a text layer:

```json
{
  "version": 1,
  "selectors": [
    {
      "type": "page",
      "artifact_page": 37,
      "page_label": "23"
    },
    {
      "type": "text_quote",
      "exact": "William Robins, carpenter",
      "prefix": "household of ",
      "suffix": " aged 43"
    }
  ]
}
```

---

# 7. Future selectors

Possible future selector types include:

```text
text_position
table_row
table_cell
csv_row
json_pointer
xpath
```

These should only become supported selector types when a concrete workflow requires them.

Adding a selector type requires defining its JSON shape, validation rules, and context behavior, but does not require a `citations` table migration.

---

# 8. Locator invariants

For locator version 1:

1. `version` must equal `1`.
2. `selectors` contains at least one selector.
3. Selectors are ordered and interpreted from the Artifact inward.
4. Every selector has a string `type` discriminator.
5. Known selector types satisfy their type-specific schema and context requirements.
6. Unknown selector types are preserved losslessly for forward compatibility.
7. A Citation is independently resolvable from `artifact_id` plus `locator_json`.
8. A Citation never depends on another Citation for its location.
9. Region vertices use normalized coordinates relative to the selected media context rather than a UI rendering.
10. Region polygons contain at least three distinct points, are non-self-intersecting, and have non-zero area.
11. For paginated digital Artifacts, the Artifact page position is authoritative for navigation.
12. Printed or marked source pagination is supplementary descriptive data and does not replace the Artifact page position.
13. Locator JSON identifies where the evidence is; transcription, description, and interpretation are separate concerns.

Conceptually:

```text
Citation = Artifact + complete composable locator
```
