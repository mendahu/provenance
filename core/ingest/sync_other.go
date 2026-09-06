//go:build !unix

package ingest

func syncDir(string) error { return nil }
