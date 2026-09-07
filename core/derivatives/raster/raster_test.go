package raster

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"testing"
)

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

func TestEncodeJPEGOptionsAndTransform(t *testing.T) {
	img := image.NewRGBA(image.Rect(0, 0, 100, 50))
	for y := 0; y < 50; y++ {
		for x := 0; x < 100; x++ {
			img.Set(x, y, color.RGBA{R: 200, G: 100, B: 50, A: 255})
		}
	}
	var src bytes.Buffer
	if err := png.Encode(&src, img); err != nil {
		t.Fatal(err)
	}

	called := false
	out, err := EncodeJPEG(src.Bytes(), Options{
		MaxEdge: 40,
		Quality: 70,
		Transforms: []Transform{
			func(in image.Image) image.Image {
				called = true
				return in
			},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !called {
		t.Fatal("expected transform to run")
	}
	decoded, _, err := image.Decode(bytes.NewReader(out))
	if err != nil {
		t.Fatal(err)
	}
	b := decoded.Bounds()
	if b.Dx() != 40 || b.Dy() != 20 {
		t.Fatalf("got %dx%d", b.Dx(), b.Dy())
	}
}
