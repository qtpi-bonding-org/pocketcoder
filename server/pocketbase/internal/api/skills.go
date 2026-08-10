package api

import (
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

type skillScope struct {
	Scope      string `json:"scope"`
	ProjectDir string `json:"projectDir,omitempty"`
}

type skillRequest struct {
	Name        string     `json:"name"`
	Description string     `json:"description"`
	Content     string     `json:"content"`
	Scope       skillScope `json:"scope"`
}

func requireAdmin(re *core.RequestEvent) error {
	if re.Auth == nil {
		return re.JSON(401, map[string]string{"error": "Authentication required"})
	}
	if re.Auth.GetString("role") != "admin" {
		return re.JSON(403, map[string]string{"error": "Insufficient permissions"})
	}
	return nil
}

// RegisterSkillsApi exposes the PocketBase skills collection. The collection
// is canonical; agent_files.go materializes changes into running harnesses.
func RegisterSkillsApi(app *pocketbase.PocketBase, e *core.ServeEvent, _ func() *coordinator.Coordinator) {
	e.Router.POST("/api/pocketcoder/skills/list", func(re *core.RequestEvent) error {
		if err := requireAdmin(re); err != nil {
			return err
		}
		recs, err := app.FindRecordsByFilter("skills", "active = true && (user = {:user} || is_system = true)", "name", 0, 0, map[string]any{"user": re.Auth.Id})
		if err != nil {
			return re.JSON(500, map[string]string{"error": err.Error()})
		}
		out := make([]map[string]any, 0, len(recs))
		for _, rec := range recs {
			out = append(out, skillResponse(rec))
		}
		return re.JSON(200, map[string]any{"skills": out})
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/skills/create", func(re *core.RequestEvent) error {
		if err := requireAdmin(re); err != nil {
			return err
		}
		var in skillRequest
		if err := re.BindBody(&in); err != nil || in.Name == "" || in.Description == "" || in.Content == "" {
			return re.JSON(400, map[string]string{"error": "name, description, and content are required"})
		}
		if !validSkillName(in.Name) {
			return re.JSON(400, map[string]string{"error": "invalid skill name"})
		}
		if in.Scope.Scope != "global" && in.Scope.Scope != "projectDir" {
			return re.JSON(400, map[string]string{"error": "scope.scope must be global or projectDir"})
		}
		if in.Scope.Scope == "projectDir" && in.Scope.ProjectDir == "" {
			return re.JSON(400, map[string]string{"error": "scope.projectDir is required"})
		}
		coll, err := app.FindCollectionByNameOrId("skills")
		if err != nil {
			return re.JSON(500, map[string]string{"error": err.Error()})
		}
		rec := core.NewRecord(coll)
		rec.Set("name", in.Name)
		rec.Set("description", in.Description)
		rec.Set("content", in.Content)
		rec.Set("active", true)
		if in.Scope.Scope == "global" {
			rec.Set("is_system", true)
		} else {
			rec.Set("user", re.Auth.Id)
			rec.Set("metadata", map[string]any{"projectDir": in.Scope.ProjectDir})
		}
		if err := app.Save(rec); err != nil {
			return re.JSON(400, map[string]string{"error": err.Error()})
		}
		return re.JSON(200, skillResponse(rec))
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/skills/update", func(re *core.RequestEvent) error {
		if err := requireAdmin(re); err != nil {
			return err
		}
		var in struct {
			Path        string `json:"path"`
			Name        string `json:"name"`
			Description string `json:"description"`
			Content     string `json:"content"`
		}
		if err := re.BindBody(&in); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if in.Path == "" || in.Name == "" || in.Description == "" || in.Content == "" {
			return re.JSON(400, map[string]string{"error": "path, name, description, and content are required"})
		}
		rec, err := app.FindRecordById("skills", in.Path)
		if err != nil || (!rec.GetBool("is_system") && rec.GetString("user") != re.Auth.Id) {
			return re.JSON(404, map[string]string{"error": "skill not found"})
		}
		rec.Set("name", in.Name)
		rec.Set("description", in.Description)
		rec.Set("content", in.Content)
		if err := app.Save(rec); err != nil {
			return re.JSON(400, map[string]string{"error": err.Error()})
		}
		return re.JSON(200, skillResponse(rec))
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/skills/delete", func(re *core.RequestEvent) error {
		if err := requireAdmin(re); err != nil {
			return err
		}
		var in struct {
			Path string `json:"path"`
		}
		if err := re.BindBody(&in); err != nil || in.Path == "" {
			return re.JSON(400, map[string]string{"error": "path is required"})
		}
		rec, err := app.FindRecordById("skills", in.Path)
		if err != nil || (!rec.GetBool("is_system") && rec.GetString("user") != re.Auth.Id) {
			return re.JSON(404, map[string]string{"error": "skill not found"})
		}
		if err := app.Delete(rec); err != nil {
			return re.JSON(500, map[string]string{"error": err.Error()})
		}
		return re.JSON(200, map[string]bool{"deleted": true})
	}).Bind(apis.RequireAuth())
}

func skillResponse(rec *core.Record) map[string]any {
	return map[string]any{"name": rec.GetString("name"), "description": rec.GetString("description"), "content": rec.GetString("content"), "path": rec.Id, "global": rec.GetBool("is_system")}
}

func validSkillName(name string) bool {
	if len(name) == 0 || len(name) > 64 || strings.HasPrefix(name, "-") || strings.HasSuffix(name, "-") || strings.Contains(name, "--") {
		return false
	}
	for _, r := range name {
		if (r < 'a' || r > 'z') && (r < '0' || r > '9') && r != '-' {
			return false
		}
	}
	return true
}
