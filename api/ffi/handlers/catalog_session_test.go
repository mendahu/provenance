package handlers

import (
	"sync"
	"sync/atomic"
	"testing"

	"github.com/mendahu/provenencia/api/proto/engine"
	"github.com/mendahu/provenencia/core/catalogsession"
	"github.com/mendahu/provenencia/core/onboarding"
	"google.golang.org/protobuf/proto"
)

func TestConcurrentCatalogRPCs(t *testing.T) {
	t.Cleanup(func() { _ = catalogsession.CloseAll() })

	created, err := onboarding.Complete(t.TempDir(), t.TempDir(), "Jake", "Concurrent")
	if err != nil {
		t.Fatal(err)
	}
	dir := created.ProjectDir
	listIn := marshalProto(t, &engine.ListSourcesRequest{ProjectDir: dir})
	countsIn := marshalProto(t, &engine.GetWorkspaceNavCountsRequest{ProjectDir: dir})

	var wg sync.WaitGroup
	var fails atomic.Int32
	for i := 0; i < 12; i++ {
		wg.Add(2)
		go func() {
			defer wg.Done()
			if _, err := ListSources(listIn); err != nil {
				fails.Add(1)
				t.Errorf("ListSources: %v", err)
			}
		}()
		go func() {
			defer wg.Done()
			if _, err := GetWorkspaceNavCounts(countsIn); err != nil {
				fails.Add(1)
				t.Errorf("GetWorkspaceNavCounts: %v", err)
			}
		}()
	}
	wg.Wait()
	if fails.Load() != 0 {
		t.Fatalf("%d concurrent RPCs failed", fails.Load())
	}

	// Session still held and reusable.
	out, err := ListSources(listIn)
	if err != nil {
		t.Fatal(err)
	}
	var resp engine.ListSourcesResponse
	if err := proto.Unmarshal(out, &resp); err != nil {
		t.Fatal(err)
	}
}
