// NOTE: This file is intentionally non-functional stub code included solely
// for demo purposes. Its only role is to provide RBAC v1 permission signals
// (constants, route reference) that the Kessel onboarding interview skill
// detects during codebase analysis. Without these signals, the skill would
// ask for RBAC permissions manually during the demo interview; with them, it
// can draft the v1 permissions and proposed v2 names automatically, keeping
// the demo concise. No production system should rely on checkRBACPermission.

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
