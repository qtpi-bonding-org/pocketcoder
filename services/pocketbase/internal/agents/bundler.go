package agents

import (
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"gopkg.in/yaml.v3"
)

// GetAgentBundle converts an Agent record into a frontmatter-laden bundle.
func GetAgentBundle(app *pocketbase.PocketBase, agent *core.Record) (string, error) {
	// 1. Expand dependencies
	app.ExpandRecord(agent, []string{"prompt", "model"}, nil)

	// 2. Build Frontmatter
	frontmatter := make(map[string]any)
	if desc := agent.GetString("description"); desc != "" {
		frontmatter["description"] = desc
	}

	model := agent.ExpandedOne("model")
	if model == nil {
		modelID := agent.GetString("model")
		if modelID != "" {
			model, _ = app.FindRecordById("ai_models", modelID)
		}
	}
	if model != nil {
		frontmatter["model"] = model.GetString("identifier")
	}

	yamlBytes, err := yaml.Marshal(frontmatter)
	if err != nil {
		return "", err
	}

	// 4. Combine with Prompt Body
	body := ""
	prompt := agent.ExpandedOne("prompt")
	if prompt == nil {
		promptID := agent.GetString("prompt")
		if promptID != "" {
			prompt, _ = app.FindRecordById("ai_prompts", promptID)
		}
	}

	if prompt != nil {
		body = prompt.GetString("body")
	}

	return "---\n" + string(yamlBytes) + "---\n\n" + body, nil
}

// UpdateAgentConfig re-assembles the bundle and saves it to the 'config' field if changed.
func UpdateAgentConfig(app *pocketbase.PocketBase, agent *core.Record) error {
	bundle, err := GetAgentBundle(app, agent)
	if err != nil {
		return err
	}
	if agent.GetString("config") == bundle {
		return nil
	}
	agent.Set("config", bundle)
	return app.Save(agent)
}
