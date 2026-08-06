# TaskManager — Service Overview

## What is TaskManager?

TaskManager is a simple team task-tracking service. Teams use it to create and manage tasks within workspaces, assign them to users, and track their progress from open through to done.

It is the demo service used to show the Kessel onboarding skills in action.

---

## What does it do?

| Operation | HTTP | Description |
|---|---|---|
| Create task | `POST /tasks` | Creates a new task in a workspace |
| List tasks | `GET /tasks` | Returns all tasks |
| Get task | `GET /tasks/{id}` | Returns a single task |
| Delete task | `DELETE /tasks/{id}` | Removes a task |

A task has:
- **Title** — what needs to be done
- **Status** — `open`, `in_progress`, or `done`
- **Workspace ID** — the workspace this task belongs to
- **Assignee ID** — the user the task is assigned to (optional)

---

## Current state (before Kessel)

TaskManager stores tasks in memory and enforces no access control. Any user can read or modify any task. There is no way to restrict tasks by workspace or user.

**What's missing:**
- Users should only see tasks in workspaces they have access to
- Only authorized users should be able to edit or delete tasks
- The platform has no record of what tasks exist or who owns them

---

## Why Kessel?

Kessel provides workspace-based access control across the platform. By onboarding to Kessel, TaskManager gets:

- **Inventory reporting** — tasks are registered as resources in Kessel so the platform knows they exist
- **Permission checking** — Kessel decides who can view or edit each task based on workspace membership
- **Workspace scoping** — users only see tasks in workspaces they belong to, automatically

---

## Onboarding goal

After running through the Kessel onboarding skills:

1. TaskManager's `task` resource type is registered in **Kessel Inventory** with the correct schema
2. A **KSL permissions schema** defines `task_view` and `task_edit` permissions scoped to workspaces
3. TaskManager calls `ReportResource` on create and `DeleteResource` on delete, keeping Kessel's inventory in sync

---

## Tech stack

| | |
|---|---|
| Language | Go |
| Transport | HTTP (REST) externally; gRPC to Kessel internally |
| Storage | In-memory (demo only) |
| Auth | Kessel Inventory via `kessel-sdk-go` |

---

## Resource type

| Field | Value |
|---|---|
| Resource type | `task` |
| Reporter type | `TASKMANAGER` |
| Common fields | `workspace_id` |
| Reporter fields | `title`, `status`, `assignee_id` |
| Permissions | `task_view` (read), `task_edit` (write) |
