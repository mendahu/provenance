package datevalues

import (
	"fmt"
	"strings"
)

var monthAbbrev = []string{
	"", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
}

// FormatSummary returns a compact GEDCOM-style display string for a DateValue
// (e.g. "ABT 1890", "14 May 1985", "BET 1880 AND 1885"). Empty when nothing
// can be shown.
func FormatSummary(v Value) string {
	switch v.Kind {
	case KindRange:
		a := formatSide(v, true)
		b := formatSide(v, false)
		if a == "" && b == "" {
			return ""
		}
		if a == "" {
			a = "…"
		}
		if b == "" {
			b = "…"
		}
		out := "BET " + a + " AND " + b
		if p := strings.TrimSpace(v.Phrase); p != "" {
			out += " (" + p + ")"
		}
		return out
	case KindPoint:
		a := formatSide(v, true)
		if a == "" {
			if p := strings.TrimSpace(v.Phrase); p != "" {
				return p
			}
			return ""
		}
		out := a
		if q := strings.TrimSpace(v.Qualifier); q != "" {
			out = q + " " + out
		}
		if p := strings.TrimSpace(v.Phrase); p != "" {
			out += " (" + p + ")"
		}
		return out
	default:
		return ""
	}
}

func formatSide(v Value, start bool) string {
	var year, month, day, hour, minute, second, ms *int
	var tz string
	if start {
		year, month, day = v.StartYear, v.StartMonth, v.StartDay
		hour, minute, second, ms = v.StartHour, v.StartMinute, v.StartSecond, v.StartMillisecond
		tz = v.StartTZ
	} else {
		year, month, day = v.EndYear, v.EndMonth, v.EndDay
		hour, minute, second, ms = v.EndHour, v.EndMinute, v.EndSecond, v.EndMillisecond
		tz = v.EndTZ
	}
	if year == nil {
		return ""
	}
	out := fmt.Sprintf("%d", *year)
	if month != nil && *month >= 1 && *month <= 12 {
		if day != nil {
			out = fmt.Sprintf("%d %s %d", *day, monthAbbrev[*month], *year)
		} else {
			out = fmt.Sprintf("%s %d", monthAbbrev[*month], *year)
		}
	}
	if hour != nil && day != nil {
		mi := 0
		if minute != nil {
			mi = *minute
		}
		out += fmt.Sprintf(" %02d:%02d", *hour, mi)
		if second != nil {
			out += fmt.Sprintf(":%02d", *second)
			if ms != nil {
				out += fmt.Sprintf(".%03d", *ms)
			}
		}
		if strings.TrimSpace(tz) != "" {
			out += " " + strings.TrimSpace(tz)
		}
	}
	return out
}
