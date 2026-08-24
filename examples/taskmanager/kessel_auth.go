package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/project-kessel/kessel-sdk-go/kessel/console"
	v1beta2 "github.com/project-kessel/kessel-sdk-go/kessel/inventory/v1beta2"
	v2 "github.com/project-kessel/kessel-sdk-go/kessel/rbac/v2"
)

// parseIdentityHeader decodes the x-rh-identity header and returns the inner
// identity object.
func parseIdentityHeader(r *http.Request) (map[string]any, error) {
	header := r.Header.Get("x-rh-identity")
	if header == "" {
		return nil, fmt.Errorf("x-rh-identity header is missing")
	}
	decoded, err := base64.StdEncoding.DecodeString(header)
	if err != nil {
		return nil, fmt.Errorf("failed to decode x-rh-identity: %w", err)
	}
	var envelope map[string]any
	if err := json.Unmarshal(decoded, &envelope); err != nil {
		return nil, fmt.Errorf("failed to unmarshal x-rh-identity: %w", err)
	}
	identity, ok := envelope["identity"].(map[string]any)
	if !ok {
		return nil, fmt.Errorf("x-rh-identity missing \"identity\" envelope key")
	}
	return identity, nil
}

// orgIDFromIdentity extracts the org_id from a decoded identity map.
func orgIDFromIdentity(identity map[string]any) (string, error) {
	orgID, _ := identity["org_id"].(string)
	if orgID == "" {
		return "", fmt.Errorf("org_id not found in x-rh-identity")
	}
	return orgID, nil
}

// checkKesselPermission performs a default-workspace Check against Kessel for
// the given v2 relation (e.g. "taskmanager_task_view").
//
// Pattern: default-workspace — looks up the org's DEFAULT workspace via RBAC
// v2, then calls Kessel Check against that workspace object.
//
// Fails closed: any error (identity parse failure, workspace lookup failure,
// gRPC error) returns false and logs the reason.
func (s *server) checkKesselPermission(r *http.Request, relation string) bool {
	identity, err := parseIdentityHeader(r)
	if err != nil {
		log.Printf("kessel: identity parse error (relation=%s): %v", relation, err)
		return false
	}

	orgID, err := orgIDFromIdentity(identity)
	if err != nil {
		log.Printf("kessel: org_id error (relation=%s): %v", relation, err)
		return false
	}

	subject, err := console.PrincipalFromRHIdentity(identity)
	if err != nil {
		log.Printf("kessel: principal error (relation=%s): %v", relation, err)
		return false
	}

	// Workspace lookup uses x-rh-rbac-org-id, NOT x-rh-identity — the SDK
	// sets the correct header internally.
	ws, err := v2.FetchDefaultWorkspace(r.Context(), s.rbacEndpoint, orgID, v2.FetchWorkspaceOptions{})
	if err != nil {
		log.Printf("kessel: default workspace lookup failed (org=%s, relation=%s): %v", orgID, relation, err)
		return false
	}

	resp, err := s.kessel.Check(r.Context(), &v1beta2.CheckRequest{
		Object: &v1beta2.ResourceReference{
			ResourceType: "rbac/workspace",
			ResourceId:   ws.Id,
		},
		Relation: relation,
		Subject:  subject,
	})
	if err != nil {
		log.Printf("kessel: Check RPC failed (relation=%s, workspace=%s): %v", relation, ws.Id, err)
		return false
	}

	allowed := resp.GetAllowed() == v1beta2.Allowed_ALLOWED_TRUE
	log.Printf("kessel: Check(relation=%s, workspace=%s) → %v", relation, ws.Id, allowed)
	return allowed
}
