//go:build !unix

package ingest

func isSymlinkLoop(error) bool { return false }

func isAccessDenied(error) bool { return false }
