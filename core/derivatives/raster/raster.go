// Package raster turns image bytes into a thumbnail JPEG.
// Swap this implementation later without touching EnsureThumbnail / DB / objects.
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

// Supported reports whether mediaType is an allowlisted raster format.
func Supported(mediaType string) bool {
	mediaType = strings.ToLower(strings.TrimSpace(mediaType))
	if i := strings.IndexByte(mediaType, ';'); i >= 0 {
		mediaType = strings.TrimSpace(mediaType[:i])
	}
	_, ok := supportedMIME[mediaType]
	return ok
}

// ThumbnailJPEG decodes src, scales so the longest edge is at most maxEdge, and encodes JPEG.
func ThumbnailJPEG(src []byte, maxEdge int) ([]byte, error) {
	if maxEdge < 1 {
		return nil, fmt.Errorf("raster: maxEdge must be positive")
	}
	img, _, err := image.Decode(bytes.NewReader(src))
	if err != nil {
		return nil, err
	}
	scaled := scaleToMaxEdge(img, maxEdge)
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, scaled, &jpeg.Options{Quality: 85}); err != nil {
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
