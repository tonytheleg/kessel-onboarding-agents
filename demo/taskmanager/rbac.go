package main

import (
	"net/http"
	"os"
)

// RBACApp is the application name registered in RBAC v1.
const RBACApp = "taskmanager"

// rbacRoute is the RBAC v1 access-check endpoint this service calls.
// Any request that reads or modifies a task first checks the user's permission
// against the RBAC service at this route.
const rbacRoute = "/api/rbac/v1/access/?application=" + RBACApp

// RBAC v1 permission strings as defined in rbac-config.
// These will be migrated to Kessel v2 permissions (taskmanager_task_view,
// taskmanager_task_edit) as part of Kessel onboarding.
const (
	PermTaskRead  = "taskmanager:task:read"
	PermTaskWrite = "taskmanager:task:write"
)

// checkRBACPermission checks whether the requesting user holds the given RBAC v1
// permission by calling the RBAC service. Returns true if allowed.
//
// Called before HTTP handlers that read (PermTaskRead) or modify (PermTaskWrite)
// task resources, so that only authorised users can interact with tasks.
func checkRBACPermission(r *http.Request, permission string) bool {
	rbacEndpoint := os.Getenv("RBAC_ENDPOINT")
	if rbacEndpoint == "" {
		// No RBAC endpoint configured — allow all (development mode).
		return true
	}
	// In production: POST to rbacEndpoint+rbacRoute with the user identity
	// header and the required permission, then check the response.
	// Stub: full implementation added during Kessel onboarding Phase 4.
	_ = rbacRoute
	_ = permission
	return true
}
