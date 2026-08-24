package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"sync"

	"github.com/google/uuid"
	"github.com/project-kessel/kessel-sdk-go/kessel/inventory/v1beta2"
	"google.golang.org/protobuf/types/known/structpb"
)

// Task is the core domain object for the TaskManager service.
type Task struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Status      string `json:"status"` // open, in_progress, done
	AssigneeID  string `json:"assignee_id,omitempty"`
	WorkspaceID string `json:"workspace_id"`
}

// taskStore is a thread-safe in-memory task database.
type taskStore struct {
	mu    sync.RWMutex
	tasks map[string]Task
}

func (s *taskStore) insert(t Task) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.tasks[t.ID] = t
}

func (s *taskStore) get(id string) (Task, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	t, ok := s.tasks[id]
	return t, ok
}

func (s *taskStore) delete(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, ok := s.tasks[id]
	delete(s.tasks, id)
	return ok
}

func (s *taskStore) list() []Task {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Task, 0, len(s.tasks))
	for _, t := range s.tasks {
		out = append(out, t)
	}
	return out
}

// server holds all dependencies for the TaskManager HTTP service.
type server struct {
	store         *taskStore
	kessel        v1beta2.KesselInventoryServiceClient
	instanceID    string
	baseURL       string
	rbacEndpoint  string // RBAC v2 base URL for workspace lookup (default-workspace pattern)
	kesselEnabled bool   // when true, enforce Kessel permission checks on all handlers
}

func main() {
	kesselClient, cleanup, err := newKesselClient()
	if err != nil {
		log.Fatalf("kessel client: %v", err)
	}
	defer cleanup()

	svc := &server{
		store:         &taskStore{tasks: make(map[string]Task)},
		kessel:        kesselClient,
		instanceID:    envOrDefault("REPORTER_INSTANCE_ID", "taskmanager-1"),
		baseURL:       envOrDefault("BASE_URL", "http://localhost:8080"),
		rbacEndpoint:  envOrDefault("RBAC_ENDPOINT", ""),
		kesselEnabled: envOrDefault("KESSEL_ENABLED", "false") == "true",
	}

	mux := http.NewServeMux()
	mux.HandleFunc("POST /tasks", svc.handleCreateTask)
	mux.HandleFunc("GET /tasks", svc.handleListTasks)
	mux.HandleFunc("GET /tasks/{id}", svc.handleGetTask)
	mux.HandleFunc("DELETE /tasks/{id}", svc.handleDeleteTask)

	addr := envOrDefault("ADDR", ":8080")
	log.Printf("TaskManager listening on %s", addr)
	log.Printf("Kessel endpoint: %s", envOrDefault("KESSEL_ENDPOINT", "(not set — Kessel calls will fail gracefully)"))
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("serve: %v", err)
	}
}

// handleCreateTask creates a new task and reports it to Kessel inventory.
//
// POST /tasks
// Body: { "title": "...", "status": "open", "workspace_id": "...", "assignee_id": "..." }
func (s *server) handleCreateTask(w http.ResponseWriter, r *http.Request) {
	if s.kesselEnabled && !s.checkKesselPermission(r, "taskmanager_task_edit") {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	var req struct {
		Title       string `json:"title"`
		Status      string `json:"status"`
		AssigneeID  string `json:"assignee_id"`
		WorkspaceID string `json:"workspace_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if req.Title == "" || req.WorkspaceID == "" {
		http.Error(w, "title and workspace_id are required", http.StatusBadRequest)
		return
	}
	if req.Status == "" {
		req.Status = "open"
	}

	task := Task{
		ID:          uuid.New().String(),
		Title:       req.Title,
		Status:      req.Status,
		AssigneeID:  req.AssigneeID,
		WorkspaceID: req.WorkspaceID,
	}
	s.store.insert(task)
	log.Printf("created task %s: %q (workspace=%s)", task.ID, task.Title, task.WorkspaceID)

	// Report the new resource to Kessel Inventory via gRPC.
	reporterFields := map[string]*structpb.Value{
		"title":  structpb.NewStringValue(task.Title),
		"status": structpb.NewStringValue(task.Status),
	}
	if task.AssigneeID != "" {
		reporterFields["assignee_id"] = structpb.NewStringValue(task.AssigneeID)
	}

	_, err := s.kessel.ReportResource(r.Context(), &v1beta2.ReportResourceRequest{
		Type:               "task",
		ReporterType:       "TASKMANAGER",
		ReporterInstanceId: s.instanceID,
		Representations: &v1beta2.ResourceRepresentations{
			Metadata: &v1beta2.RepresentationMetadata{
				LocalResourceId: task.ID,
				ApiHref:         fmt.Sprintf("%s/tasks/%s", s.baseURL, task.ID),
			},
			Common: &structpb.Struct{
				Fields: map[string]*structpb.Value{
					"workspace_id": structpb.NewStringValue(task.WorkspaceID),
				},
			},
			Reporter: &structpb.Struct{Fields: reporterFields},
		},
	})
	if err != nil {
		log.Printf("kessel: failed to report task %s: %v", task.ID, err)
	} else {
		log.Printf("kessel: reported task %s to inventory", task.ID)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(task)
}

// handleDeleteTask deletes a task and removes it from Kessel inventory.
//
// DELETE /tasks/{id}
func (s *server) handleDeleteTask(w http.ResponseWriter, r *http.Request) {
	if s.kesselEnabled && !s.checkKesselPermission(r, "taskmanager_task_edit") {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	id := r.PathValue("id")
	if !s.store.delete(id) {
		http.Error(w, "task not found", http.StatusNotFound)
		return
	}
	log.Printf("deleted task %s", id)

	// Remove the resource from Kessel Inventory via gRPC.
	_, err := s.kessel.DeleteResource(r.Context(), &v1beta2.DeleteResourceRequest{
		Reference: &v1beta2.ResourceReference{
			ResourceType: "task",
			ResourceId:   id,
			Reporter:     &v1beta2.ReporterReference{Type: "TASKMANAGER"},
		},
	})
	if err != nil {
		log.Printf("kessel: failed to delete task %s from inventory: %v", id, err)
	} else {
		log.Printf("kessel: removed task %s from inventory", id)
	}

	w.WriteHeader(http.StatusNoContent)
}

// handleGetTask returns a single task by ID.
//
// GET /tasks/{id}
func (s *server) handleGetTask(w http.ResponseWriter, r *http.Request) {
	if s.kesselEnabled && !s.checkKesselPermission(r, "taskmanager_task_view") {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	id := r.PathValue("id")
	task, ok := s.store.get(id)
	if !ok {
		http.Error(w, "task not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(task)
}

// handleListTasks returns all tasks in the store.
//
// GET /tasks
func (s *server) handleListTasks(w http.ResponseWriter, r *http.Request) {
	if s.kesselEnabled && !s.checkKesselPermission(r, "taskmanager_task_view") {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	tasks := s.store.list()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tasks)
}

func newKesselClient() (v1beta2.KesselInventoryServiceClient, func(), error) {
	endpoint := envOrDefault("KESSEL_ENDPOINT", "localhost:9081")
	client, conn, err := v1beta2.NewClientBuilder(endpoint).
		Insecure().
		Build()
	if err != nil {
		return nil, nil, fmt.Errorf("build kessel client: %w", err)
	}
	return client, func() { conn.Close() }, nil
}

func envOrDefault(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

