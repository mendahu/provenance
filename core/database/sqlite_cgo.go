//go:build cgo

package database

import (
	"errors"

	"github.com/mattn/go-sqlite3"
)

// IsUniqueConflict reports a SQLite UNIQUE constraint failure.
func IsUniqueConflict(err error) bool {
	var se sqlite3.Error
	return errors.As(err, &se) && se.ExtendedCode == sqlite3.ErrConstraintUnique
}

// IsBusyOrLocked reports SQLITE_BUSY or SQLITE_LOCKED.
func IsBusyOrLocked(err error) bool {
	var se sqlite3.Error
	return errors.As(err, &se) && (se.Code == sqlite3.ErrBusy || se.Code == sqlite3.ErrLocked)
}

// IsConstraint reports any SQLite constraint failure (including extended codes).
func IsConstraint(err error) bool {
	var se sqlite3.Error
	return errors.As(err, &se) && se.Code == sqlite3.ErrConstraint
}

// IsConstraintViolation reports FK, UNIQUE, or other SQLite constraint failures.
func IsConstraintViolation(err error) bool {
	var se sqlite3.Error
	if !errors.As(err, &se) {
		return false
	}
	return se.ExtendedCode == sqlite3.ErrConstraintForeignKey ||
		se.ExtendedCode == sqlite3.ErrConstraintUnique ||
		se.Code == sqlite3.ErrConstraint
}
