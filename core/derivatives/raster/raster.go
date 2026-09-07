// Package raster turns image bytes into derivative JPEGs.
// Swap this implementation later without touching Ensure / DB / objects.
//
// Security: golang.org/x/image decoders (bmp, tiff, webp) parse fully
// untrusted input here and have a history of memory-exhaustion CVEs.
// Keep that dependency current (go list -m -u golang.org/x/image).
package raster

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/gif"
	"image/jpeg"
	"image/png"
	"strings"

	_ "golang.org/x/image/bmp"  // register bmp decoder
	_ "golang.org/x/image/tiff" // register tiff decoder
	_ "golang.org/x/image/webp" // register webp decoder
)

func init() {
	// Keep stdlib decoders linked for image.Decode.
	_ = jpeg.Decode
	_ = png.Decode
	_ = gif.Decode
}

// DefaultQuality is used when Options.Quality is zero.
const DefaultQuality = 85

// MaxEdgeLimit is the largest Options.MaxEdge EncodeJPEG accepts. It bounds
// output allocations even if callers become externally parameterized.
const MaxEdgeLimit = 4096

// maxDecodePixels caps declared width*height before full decode. Decoders
// allocate pixel buffers from header dimensions, so this is the primary
// defense against decompression bombs (see image package security notes).
const maxDecodePixels = 64_000_000 // 64 MP ≈ 256 MiB RGBA

// ErrTooLarge means the image declares more pixels than maxDecodePixels
// allows, so it was rejected before full decode.
var ErrTooLarge = errors.New("raster: image dimensions exceed decode budget")

// ErrUnsupportedFormat means the bytes are not one of the allowlisted
// raster formats, regardless of the recorded media type.
var ErrUnsupportedFormat = errors.New("raster: unsupported image format")

var supportedMIME = map[string]struct{}{
	"image/jpeg": {},
	"image/jpg":  {},
	"image/png":  {},
	"image/gif":  {},
	"image/bmp":  {},
	"image/tiff": {},
	"image/tif":  {},
	"image/webp": {},
}

// supportedFormats are image.DecodeConfig format names allowed to fully
// decode. Keep in sync with the decoders registered by this package.
var supportedFormats = map[string]struct{}{
	"jpeg": {},
	"png":  {},
	"gif":  {},
	"bmp":  {},
	"tiff": {},
	"webp": {},
}

// Transform mutates or replaces an image in the encode pipeline (after scale).
// Add grayscale, sharpen, etc. as named Transform funcs later without changing EncodeJPEG.
type Transform func(image.Image) image.Image

// Options parameterizes raster encoding. Zero Quality means DefaultQuality.
type Options struct {
	MaxEdge    int // longest output edge in pixels; must be > 0
	Quality    int // JPEG quality 1–100; 0 → DefaultQuality
	Transforms []Transform
}

// Supported reports whether mediaType is an allowlisted raster format.
func Supported(mediaType string) bool {
	mediaType = strings.ToLower(strings.TrimSpace(mediaType))
	if i := strings.IndexByte(mediaType, ';'); i >= 0 {
		mediaType = strings.TrimSpace(mediaType[:i])
	}
	_, ok := supportedMIME[mediaType]
	return ok
}

// EncodeJPEG decodes src, scales to MaxEdge, applies Transforms, and encodes JPEG.
// Before full decode it checks the sniffed format against the package allowlist
// (ErrUnsupportedFormat) and the declared pixel count against maxDecodePixels
// (ErrTooLarge), so header-declared decompression bombs never allocate.
func EncodeJPEG(src []byte, opts Options) ([]byte, error) {
	if opts.MaxEdge < 1 {
		return nil, fmt.Errorf("raster: MaxEdge must be positive")
	}
	if opts.MaxEdge > MaxEdgeLimit {
		return nil, fmt.Errorf("raster: MaxEdge must be at most %d", MaxEdgeLimit)
	}
	quality := opts.Quality
	if quality == 0 {
		quality = DefaultQuality
	}
	if quality < 1 || quality > 100 {
		return nil, fmt.Errorf("raster: Quality must be 1–100 or 0 for default")
	}
	cfg, format, err := image.DecodeConfig(bytes.NewReader(src))
	if err != nil {
		return nil, err
	}
	if _, ok := supportedFormats[format]; !ok {
		return nil, ErrUnsupportedFormat
	}
	if cfg.Width < 1 || cfg.Height < 1 ||
		int64(cfg.Width)*int64(cfg.Height) > maxDecodePixels {
		return nil, ErrTooLarge
	}
	img, _, err := image.Decode(bytes.NewReader(src))
	if err != nil {
		return nil, err
	}
	img = scaleToMaxEdge(img, opts.MaxEdge)
	for _, t := range opts.Transforms {
		if t != nil {
			img = t(img)
		}
	}
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: quality}); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func scaleToMaxEdge(src image.Image, maxEdge int) image.Image {
	b := src.Bounds()
	w, h := b.Dx(), b.Dy()
	if w < 1 || h < 1 {
		return src
	}
	long := w
	if h > long {
		long = h
	}
	if long <= maxEdge {
		return src
	}
	nw := w * maxEdge / long
	nh := h * maxEdge / long
	if nw < 1 {
		nw = 1
	}
	if nh < 1 {
		nh = 1
	}
	dst := image.NewRGBA(image.Rect(0, 0, nw, nh))
	for y := 0; y < nh; y++ {
		sy := b.Min.Y + y*h/nh
		for x := 0; x < nw; x++ {
			sx := b.Min.X + x*w/nw
			dst.Set(x, y, src.At(sx, sy))
		}
	}
	return dst
}
