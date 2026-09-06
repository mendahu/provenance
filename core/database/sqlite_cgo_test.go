//go:build cgo

package database

import (
	"errors"
	"testing"

	"github.com/mattn/go-sqlite3"
)

func TestSQLiteErrorHelpers(t *testing.T) {
	unique := sqlite3.Error{Code: sqlite3.ErrConstraint, ExtendedCode: sqlite3.ErrConstraintUnique}
	fk := sqlite3.Error{Code: sqlite3.ErrConstraint, ExtendedCode: sqlite3.ErrConstraintForeignKey}
	genericConstraint := sqlite3.Error{Code: sqlite3.ErrConstraint}
	busy := sqlite3.Error{Code: sqlite3.ErrBusy}
	locked := sqlite3.Error{Code: sqlite3.ErrLocked}
	other := sqlite3.Error{Code: sqlite3.ErrIoErr}
	plain := errors.New("not sqlite")

	tests := []struct {
		name string
		err  error
		want struct {
			unique, busy, constraint, violation bool
		}
	}{
		{name: "nil"},
		{name: "plain", err: plain},
		{
			name: "unique",
			err:  unique,
			want: struct {
				unique, busy, constraint, violation bool
			}{unique: true, constraint: true, violation: true},
		},
		{
			name: "foreign key",
			err:  fk,
			want: struct {
				unique, busy, constraint, violation bool
			}{constraint: true, violation: true},
		},
		{
			name: "generic constraint",
			err:  genericConstraint,
			want: struct {
				unique, busy, constraint, violation bool
			}{constraint: true, violation: true},
		},
		{
			name: "busy",
			err:  busy,
			want: struct {
				unique, busy, constraint, violation bool
			}{busy: true},
		},
		{
			name: "locked",
			err:  locked,
			want: struct {
				unique, busy, constraint, violation bool
			}{busy: true},
		},
		{name: "other sqlite", err: other},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsUniqueConflict(tt.err); got != tt.want.unique {
				t.Fatalf("IsUniqueConflict=%v want %v", got, tt.want.unique)
			}
			if got := IsBusyOrLocked(tt.err); got != tt.want.busy {
				t.Fatalf("IsBusyOrLocked=%v want %v", got, tt.want.busy)
			}
			if got := IsConstraint(tt.err); got != tt.want.constraint {
				t.Fatalf("IsConstraint=%v want %v", got, tt.want.constraint)
			}
			if got := IsConstraintViolation(tt.err); got != tt.want.violation {
				t.Fatalf("IsConstraintViolation=%v want %v", got, tt.want.violation)
			}
		})
	}
}
