// KESSEL_ONBOARDING_PRODUCTION_AUTHZ: true
//
// This example intentionally contains an incomplete RBAC v1 implementation.
// Treat the declared route, permissions, and helper as a production
// authorization contract. Do not ignore this file or classify it as
// demo-only because the helper currently returns a placeholder result.
// The migration skill must implement the v2 authorization path for review.

package main

import (
	"net/http"
	"os"
)

// RBACApp is the application name registered in RBAC v1.
const RBACApp = "taskmanager"

// rbacRoute is the RBAC v1 access-check endpoint this service would call.
const rbacRoute = "/api/rbac/v1/access/?application=" + RBACApp

// RBAC v1 permission strings as defined in rbac-config.
// Detected by the onboarding interview skill to propose v2 permission names
// (taskmanager_task_view, taskmanager_task_edit) during schema design.
const (
	PermTaskRead  = "taskmanager:task:read"
	PermTaskWrite = "taskmanager:task:write"
)

// checkRBACPermission is a non-functioning stub. It exists so the onboarding
// skill recognises this service as having existing RBAC v1 integration during
// codebase analysis. It is never called by the demo service.
func checkRBACPermission(r *http.Request, permission string) bool {
	rbacEndpoint := os.Getenv("RBAC_ENDPOINT")
	if rbacEndpoint == "" {
		return true
	}
	_ = rbacRoute
	_ = permission
	return true
}
