package datevalues

import (
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

// Shared with macos/ProvenenciaTests (Swift DateValueDraft.summary).
// Source of truth: testdata/datevalues/format_summary.json at the repo root.
type summaryFixture struct {
	Name             string  `json:"name"`
	Kind             string  `json:"kind"`
	Qualifier        string  `json:"qualifier"`
	Phrase           string  `json:"phrase"`
	StartYear        *int    `json:"startYear"`
	StartMonth       *int    `json:"startMonth"`
	StartDay         *int    `json:"startDay"`
	StartHour        *int    `json:"startHour"`
	StartMinute      *int    `json:"startMinute"`
	StartSecond      *int    `json:"startSecond"`
	StartMillisecond *int    `json:"startMillisecond"`
	StartTZ          string  `json:"startTZ"`
	EndYear          *int    `json:"endYear"`
	EndMonth         *int    `json:"endMonth"`
	EndDay           *int    `json:"endDay"`
	EndHour          *int    `json:"endHour"`
	EndMinute        *int    `json:"endMinute"`
	EndSecond        *int    `json:"endSecond"`
	EndMillisecond   *int    `json:"endMillisecond"`
	EndTZ            string  `json:"endTZ"`
	Want             string  `json:"want"`
}

func TestFormatSummaryParityFixtures(t *testing.T) {
	fixtures := loadSummaryFixtures(t)
	for _, tt := range fixtures {
		t.Run(tt.Name, func(t *testing.T) {
			v := Value{
				Kind:             tt.Kind,
				Qualifier:        tt.Qualifier,
				Phrase:           tt.Phrase,
				StartYear:        tt.StartYear,
				StartMonth:       tt.StartMonth,
				StartDay:         tt.StartDay,
				StartHour:        tt.StartHour,
				StartMinute:      tt.StartMinute,
				StartSecond:      tt.StartSecond,
				StartMillisecond: tt.StartMillisecond,
				StartTZ:          tt.StartTZ,
				EndYear:          tt.EndYear,
				EndMonth:         tt.EndMonth,
				EndDay:           tt.EndDay,
				EndHour:          tt.EndHour,
				EndMinute:        tt.EndMinute,
				EndSecond:        tt.EndSecond,
				EndMillisecond:   tt.EndMillisecond,
				EndTZ:            tt.EndTZ,
			}
			if got := FormatSummary(v); got != tt.Want {
				t.Fatalf("got %q want %q", got, tt.Want)
			}
		})
	}
}

func loadSummaryFixtures(t *testing.T) []summaryFixture {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller failed")
	}
	// core/database/datevalues → repo root
	root := filepath.Clean(filepath.Join(filepath.Dir(file), "..", "..", ".."))
	path := filepath.Join(root, "testdata", "datevalues", "format_summary.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read fixtures: %v", err)
	}
	var fixtures []summaryFixture
	if err := json.Unmarshal(raw, &fixtures); err != nil {
		t.Fatalf("decode fixtures: %v", err)
	}
	if len(fixtures) == 0 {
		t.Fatal("fixtures empty")
	}
	return fixtures
}
