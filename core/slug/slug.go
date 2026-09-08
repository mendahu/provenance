// Package slug turns free-text labels into stable kebab-case identifiers.
package slug

import (
	"strings"
	"unicode"
)

// Kebab lowercases s and turns it into a kebab-case slug: letters and
// digits pass through, apostrophes are dropped without leaving a
// separator (so "Grandma's" becomes "grandmas", not "grandma-s"), and any
// other run of characters collapses to a single hyphen. Leading and
// trailing hyphens are trimmed. Returns "" if no letters or digits survive.
//
// Deliberately keeps non-ASCII letters as-is (lowercased) rather than
// folding diacritics, same as core/onboarding.FolderName — full Unicode
// normalization needs a package this module doesn't otherwise depend on.
// Not shared code with FolderName: that helper intentionally treats a
// straight quote as a word separator instead of dropping it, so the two
// slugs are related in spirit, not byte-for-byte identical.
func Kebab(s string) string {
	var b strings.Builder
	prevHyphen := false
	for _, r := range s {
		if r == '\'' || r == '’' {
			continue
		}
		r = unicode.ToLower(r)
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
			prevHyphen = false
			continue
		}
		if b.Len() > 0 && !prevHyphen {
			b.WriteByte('-')
			prevHyphen = true
		}
	}
	return strings.Trim(b.String(), "-")
}
