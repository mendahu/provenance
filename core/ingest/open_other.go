//go:build !unix

package ingest

import "os"

func openSource(path string) (*os.File, error) {
	return os.Open(path)
}
