package raster

import "testing"

func TestSupported(t *testing.T) {
	cases := []struct {
		media string
		want  bool
	}{
		{"image/jpeg", true},
		{"image/jpg", true},
		{"image/png", true},
		{"image/gif", true},
		{"image/bmp", true},
		{"image/tiff", true},
		{"image/tif", true},
		{"image/webp", true},
		{"image/jpeg; charset=binary", true},
		{"IMAGE/PNG", true},
		{"image/heic", false},
		{"image/heif", false},
		{"image/svg+xml", false},
		{"application/pdf", false},
		{"application/octet-stream", false},
		{"", false},
	}
	for _, tc := range cases {
		if got := Supported(tc.media); got != tc.want {
			t.Fatalf("%q: got %v want %v", tc.media, got, tc.want)
		}
	}
}
