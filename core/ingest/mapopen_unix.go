//go:build unix

package ingest

import (
	"errors"
	"syscall"
)

func isSymlinkLoop(err error) bool {
	return errors.Is(err, syscall.ELOOP)
}

func isAccessDenied(err error) bool {
	return errors.Is(err, syscall.EACCES) || errors.Is(err, syscall.EPERM)
}
