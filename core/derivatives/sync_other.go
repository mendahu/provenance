//go:build !unix

package derivatives

func syncDir(string) error { return nil }
