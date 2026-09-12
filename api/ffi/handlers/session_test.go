package handlers

import (
	"errors"
	"testing"

	"github.com/mendahu/provenencia/api/proto/engine"
	"github.com/mendahu/provenencia/core/catalogsession"
	"github.com/mendahu/provenencia/core/database"
	"github.com/mendahu/provenencia/core/identity"
	"github.com/mendahu/provenencia/core/onboarding"
	"google.golang.org/protobuf/proto"
)

func TestGetActiveProject(t *testing.T) {
	runRPC(t, GetActiveProject, []rpcTest{
		{
			name: "not found",
			reqFn: func(t *testing.T) proto.Message {
				return &engine.GetActiveProjectRequest{IdentityDir: t.TempDir()}
			},
			want: &engine.GetActiveProjectResponse{Found: false},
		},
		{
			name: "found",
			reqFn: func(t *testing.T) proto.Message {
				dir := t.TempDir()
				if err := identity.SaveActive(dir, identity.Active{ProjectDir: "/tmp/A.provenencia"}); err != nil {
					t.Fatal(err)
				}
				return &engine.GetActiveProjectRequest{IdentityDir: dir}
			},
			want: &engine.GetActiveProjectResponse{Found: true, ProjectDir: "/tmp/A.provenencia"},
		},
		{
			name:    "bad proto",
			raw:     []byte{0xff, 0xff, 0xff, 0xff},
			wantErr: true,
		},
	})
}

func TestRemoveActiveProject(t *testing.T) {
	runRPC(t, RemoveActiveProject, []rpcTest{
		{
			name: "missing is ok",
			reqFn: func(t *testing.T) proto.Message {
				return &engine.RemoveActiveProjectRequest{IdentityDir: t.TempDir()}
			},
			want:  &engine.RemoveActiveProjectResponse{},
			exact: true,
		},
		{
			name: "deletes active json",
			reqFn: func(t *testing.T) proto.Message {
				dir := t.TempDir()
				if err := identity.SaveActive(dir, identity.Active{ProjectDir: "/tmp/A.provenencia"}); err != nil {
					t.Fatal(err)
				}
				return &engine.RemoveActiveProjectRequest{IdentityDir: dir}
			},
			want:  &engine.RemoveActiveProjectResponse{},
			exact: true,
			after: func(t *testing.T, _ []byte, req proto.Message) {
				r := req.(*engine.RemoveActiveProjectRequest)
				out, err := GetActiveProject(marshalProto(t, &engine.GetActiveProjectRequest{IdentityDir: r.GetIdentityDir()}))
				if err != nil {
					t.Fatal(err)
				}
				assertWantFields(t, out, &engine.GetActiveProjectResponse{Found: false})
			},
		},
	})
}

func TestSignOut(t *testing.T) {
	runRPC(t, SignOut, []rpcTest{
		{
			name: "missing files ok",
			reqFn: func(t *testing.T) proto.Message {
				return &engine.SignOutRequest{IdentityDir: t.TempDir()}
			},
			want:  &engine.SignOutResponse{},
			exact: true,
		},
		{
			name: "clears identity and active",
			reqFn: func(t *testing.T) proto.Message {
				dir, _ := saveIdentity(t, "Jake")
				if err := identity.SaveActive(dir, identity.Active{ProjectDir: "/tmp/A.provenencia"}); err != nil {
					t.Fatal(err)
				}
				return &engine.SignOutRequest{IdentityDir: dir}
			},
			want:  &engine.SignOutResponse{},
			exact: true,
			after: func(t *testing.T, _ []byte, req proto.Message) {
				r := req.(*engine.SignOutRequest)
				got, err := GetActiveProject(marshalProto(t, &engine.GetActiveProjectRequest{IdentityDir: r.GetIdentityDir()}))
				if err != nil {
					t.Fatal(err)
				}
				assertWantFields(t, got, &engine.GetActiveProjectResponse{Found: false})
				ident, err := GetInstallIdentity(marshalProto(t, &engine.GetInstallIdentityRequest{IdentityDir: r.GetIdentityDir()}))
				if err != nil {
					t.Fatal(err)
				}
				assertIdentityNotFound(t, ident, nil)
			},
		},
		{
			name:    "bad proto",
			raw:     []byte{0xff, 0xff, 0xff, 0xff},
			wantErr: true,
		},
	})
}

func TestCloseCatalogSession(t *testing.T) {
	runRPC(t, CloseCatalogSession, []rpcTest{
		{
			name:    "bad proto",
			raw:     []byte{0xff, 0xff, 0xff, 0xff},
			wantErr: true,
		},
		{
			name:      "empty project dir",
			req:       &engine.CloseCatalogSessionRequest{ProjectDir: "  "},
			wantErr:   true,
			wantErrIs: database.ErrNotAProject,
		},
		{
			name: "closes held session so direct Open works",
			reqFn: func(t *testing.T) proto.Message {
				created, err := onboarding.Complete(t.TempDir(), t.TempDir(), "Jake", "Close")
				if err != nil {
					t.Fatal(err)
				}
				if _, err := ListSources(marshalProto(t, &engine.ListSourcesRequest{ProjectDir: created.ProjectDir})); err != nil {
					t.Fatal(err)
				}
				return &engine.CloseCatalogSessionRequest{ProjectDir: created.ProjectDir}
			},
			want:  &engine.CloseCatalogSessionResponse{},
			exact: true,
			after: func(t *testing.T, _ []byte, req proto.Message) {
				r := req.(*engine.CloseCatalogSessionRequest)
				c, err := database.Open(r.GetProjectDir())
				if err != nil {
					t.Fatal(err)
				}
				_ = c.Close()
			},
		},
		{
			name: "close when nothing held is ok",
			reqFn: func(t *testing.T) proto.Message {
				created, err := onboarding.Complete(t.TempDir(), t.TempDir(), "Jake", "Idle")
				if err != nil {
					t.Fatal(err)
				}
				_ = catalogsession.CloseAll()
				return &engine.CloseCatalogSessionRequest{ProjectDir: created.ProjectDir}
			},
			want:  &engine.CloseCatalogSessionResponse{},
			exact: true,
		},
	})
}

func TestSignOutClosesCatalogSession(t *testing.T) {
	var projectDir string
	runRPC(t, SignOut, []rpcTest{
		{
			name: "releases exclusive lock",
			reqFn: func(t *testing.T) proto.Message {
				ident := t.TempDir()
				created, err := onboarding.Complete(ident, t.TempDir(), "Jake", "SignOutLock")
				if err != nil {
					t.Fatal(err)
				}
				projectDir = created.ProjectDir
				if _, err := ListSources(marshalProto(t, &engine.ListSourcesRequest{ProjectDir: created.ProjectDir})); err != nil {
					t.Fatal(err)
				}
				return &engine.SignOutRequest{IdentityDir: ident}
			},
			want:  &engine.SignOutResponse{},
			exact: true,
			after: func(t *testing.T, _ []byte, req proto.Message) {
				r := req.(*engine.SignOutRequest)
				if _, err := identity.LoadActive(r.GetIdentityDir()); !errors.Is(err, identity.ErrActiveNotFound) {
					t.Fatalf("active after sign-out: %v", err)
				}
				c, err := database.Open(projectDir)
				if err != nil {
					t.Fatal(err)
				}
				_ = c.Close()
			},
		},
	})
}
