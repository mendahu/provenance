// Package raster turns image bytes into derivative JPEGs.
// Swap this implementation later without touching Ensure / DB / objects.
package raster

import (
	"bytes"
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
func EncodeJPEG(src []byte, opts Options) ([]byte, error) {
	if opts.MaxEdge < 1 {
		return nil, fmt.Errorf("raster: MaxEdge must be positive")
	}
	quality := opts.Quality
	if quality == 0 {
		quality = DefaultQuality
	}
	if quality < 1 || quality > 100 {
		return nil, fmt.Errorf("raster: Quality must be 1–100 or 0 for default")
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
