package raster

import (
	"bytes"
	"encoding/binary"
	"errors"
	"hash/crc32"
	"image"
	"image/color"
	"image/png"
	"io"
	"testing"
)

func init() {
	// A registered-but-not-allowlisted format to exercise ErrUnsupportedFormat.
	image.RegisterFormat("fake", "FAKEIMG!",
		func(io.Reader) (image.Image, error) { return nil, errors.New("fake: no decode") },
		func(io.Reader) (image.Config, error) { return image.Config{Width: 1, Height: 1}, nil },
	)
}

// pngHeaderOnly returns a PNG signature plus a valid IHDR chunk declaring
// w×h. DecodeConfig needs only this, so bombs stay a few bytes long.
func pngHeaderOnly(t *testing.T, w, h uint32) []byte {
	t.Helper()
	var buf bytes.Buffer
	buf.Write([]byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'})
	data := make([]byte, 13)
	binary.BigEndian.PutUint32(data[0:], w)
	binary.BigEndian.PutUint32(data[4:], h)
	data[8] = 8 // bit depth
	data[9] = 6 // color type RGBA
	var length [4]byte
	binary.BigEndian.PutUint32(length[:], 13)
	buf.Write(length[:])
	buf.WriteString("IHDR")
	buf.Write(data)
	crc := crc32.NewIEEE()
	crc.Write([]byte("IHDR"))
	crc.Write(data)
	var sum [4]byte
	binary.BigEndian.PutUint32(sum[:], crc.Sum32())
	buf.Write(sum[:])
	return buf.Bytes()
}

// gifHeaderOnly returns a GIF89a header declaring a w×h logical screen.
func gifHeaderOnly(w, h uint16) []byte {
	b := []byte("GIF89a")
	b = append(b, byte(w), byte(w>>8), byte(h), byte(h>>8), 0, 0, 0)
	return b
}

func tinyPNG(t *testing.T) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 4, 4))
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func TestEncodeJPEGRejects(t *testing.T) {
	tests := []struct {
		name    string
		src     func(t *testing.T) []byte
		opts    Options
		wantIs  error
		wantErr bool
	}{
		{
			name:   "gif bomb 65535x65535 header",
			src:    func(*testing.T) []byte { return gifHeaderOnly(65535, 65535) },
			opts:   Options{MaxEdge: 256},
			wantIs: ErrTooLarge,
		},
		{
			name:   "png bomb 100000x100000 header",
			src:    func(t *testing.T) []byte { return pngHeaderOnly(t, 100000, 100000) },
			opts:   Options{MaxEdge: 256},
			wantIs: ErrTooLarge,
		},
		{
			name:   "png just over pixel budget",
			src:    func(t *testing.T) []byte { return pngHeaderOnly(t, 8001, 8000) },
			opts:   Options{MaxEdge: 256},
			wantIs: ErrTooLarge,
		},
		{
			name:   "registered but not allowlisted format",
			src:    func(*testing.T) []byte { return []byte("FAKEIMG!....") },
			opts:   Options{MaxEdge: 256},
			wantIs: ErrUnsupportedFormat,
		},
		{
			name:    "MaxEdge above limit",
			src:     tinyPNG,
			opts:    Options{MaxEdge: MaxEdgeLimit + 1},
			wantErr: true,
		},
		{
			name:    "garbage bytes",
			src:     func(*testing.T) []byte { return []byte{0, 1, 2, 3} },
			opts:    Options{MaxEdge: 256},
			wantErr: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			out, err := EncodeJPEG(tt.src(t), tt.opts)
			if err == nil {
				t.Fatalf("expected error, got %d bytes", len(out))
			}
			if tt.wantIs != nil && !errors.Is(err, tt.wantIs) {
				t.Fatalf("got %v, want %v", err, tt.wantIs)
			}
		})
	}
}

func TestEncodeJPEGAtBudgetBoundaries(t *testing.T) {
	// 8000x8000 is exactly the 64 MP budget and must still decode.
	// Header-only would fail at full decode, so use a real (small) image
	// for the success path and MaxEdgeLimit for the cap boundary.
	out, err := EncodeJPEG(tinyPNG(t), Options{MaxEdge: MaxEdgeLimit})
	if err != nil || len(out) == 0 {
		t.Fatalf("MaxEdge=%d should be accepted: %v", MaxEdgeLimit, err)
	}
	cfg, _, err := image.DecodeConfig(bytes.NewReader(pngHeaderOnly(t, 8000, 8000)))
	if err != nil {
		t.Fatal(err)
	}
	if int64(cfg.Width)*int64(cfg.Height) > maxDecodePixels {
		t.Fatalf("8000x8000 must sit inside the pixel budget (%d)", maxDecodePixels)
	}
}

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
