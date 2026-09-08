package slug

import "testing"

func TestKebab(t *testing.T) {
	// Keep in sync with macos FieldSlug.fixtures.
	tests := []struct {
		name string
		in   string
		want string
	}{
		{name: "plain", in: "Certificate number", want: "certificate-number"},
		{name: "apostrophe", in: "Grandma's album code", want: "grandmas-album-code"},
		{name: "curly apostrophe", in: "Grandma’s album code", want: "grandmas-album-code"},
		{name: "slash", in: "A/B", want: "a-b"},
		{name: "collapse spaces", in: "  Scanned   at church  ", want: "scanned-at-church"},
		{name: "unicode letters kept", in: "García", want: "garcía"},
		{name: "only punctuation", in: "...", want: ""},
		{name: "blank", in: "  ", want: ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Kebab(tt.in); got != tt.want {
				t.Fatalf("Kebab(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}
