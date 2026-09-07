package ingest

import (
	"path/filepath"
	"strings"
	"unicode/utf8"
)

const maxFilenameBytes = 255

// sanitizeFilename strips control and bidi-override characters, trims, and caps length.
func sanitizeFilename(name string) string {
	name = filepath.Base(strings.TrimSpace(name))
	if name == "." || name == "/" || name == string(filepath.Separator) {
		return ""
	}
	var b strings.Builder
	b.Grow(len(name))
	for _, r := range name {
		switch {
		case r < 0x20:
			continue // C0
		case r >= 0x7f && r <= 0x9f:
			continue // DEL + C1
		case r >= 0x202A && r <= 0x202E:
			continue // bidi embedding/overrides
		case r >= 0x2066 && r <= 0x2069:
			continue // bidi isolates
		}
		b.WriteRune(r)
	}
	s := strings.TrimSpace(b.String())
	for len(s) > maxFilenameBytes {
		_, size := utf8.DecodeLastRuneInString(s)
		if size == 0 {
			break
		}
		s = s[:len(s)-size]
	}
	return strings.TrimSpace(s)
}
