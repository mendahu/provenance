//go:build !unix && !windows

package ingest

import "os"

func openSource(path string) (*os.File, error) {
	return os.Open(path)
}
