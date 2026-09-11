package datevalues

import "testing"

func TestFormatSummary(t *testing.T) {
	tests := []struct {
		name string
		v    Value
		want string
	}{
		{
			name: "point year ABT",
			v: Value{
				Kind: KindPoint, Qualifier: QualifierABT, StartYear: intVal(1890),
			},
			want: "ABT 1890",
		},
		{
			name: "point full day",
			v: Value{
				Kind: KindPoint, StartYear: intVal(1985), StartMonth: intVal(5), StartDay: intVal(14),
			},
			want: "14 May 1985",
		},
		{
			name: "point month",
			v: Value{
				Kind: KindPoint, StartYear: intVal(1911), StartMonth: intVal(3),
			},
			want: "Mar 1911",
		},
		{
			name: "range years",
			v: Value{
				Kind: KindRange, StartYear: intVal(1880), EndYear: intVal(1885),
			},
			want: "BET 1880 AND 1885",
		},
		{
			name: "phrase only",
			v:    Value{Kind: KindPoint, Phrase: "Christmas"},
			want: "Christmas",
		},
		{
			name: "empty",
			v:    Value{Kind: KindPoint},
			want: "",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := FormatSummary(tt.v); got != tt.want {
				t.Fatalf("got %q want %q", got, tt.want)
			}
		})
	}
}
