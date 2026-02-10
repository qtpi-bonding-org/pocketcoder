package relay

import (
	"log"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

// RelayService orchestrates communication between PocketBase and OpenCode
type RelayService struct {
	app         *pocketbase.PocketBase
	openCodeURL string
}

// NewRelayService creates a new Relay instance
func NewRelayService(app *pocketbase.PocketBase, openCodeURL string) *RelayService {
	return &RelayService{
		app:         app,
		openCodeURL: openCodeURL,
	}
}

// Start begins the relay's background processes:
// 1. Permission Listener (SSE)
// 2. Message Pump (Hooks)
// 3. Agent Sync (Hooks)
func (r *RelayService) Start() {
	log.Println("🌉 [Relay] Starting Go-based Relay Service...")

	// 1. Start SSE Listener (in background)
	go r.listenForEvents()

	// 2. Register Hooks
	r.registerMessageHooks()
	r.registerAgentHooks()
	r.registerSSHKeyHooks()
}

func (r *RelayService) registerMessageHooks() {
	// Intercept new user messages and send to OpenCode
	r.app.OnRecordAfterCreateSuccess("messages").BindFunc(func(e *core.RecordEvent) error {
		// Only process user messages that haven't been processed
		role := e.Record.GetString("role")
		processed := e.Record.GetBool("metadata.processed")

		if role == "user" && !processed {
			log.Printf("📨 [Relay] Intercepted user message: %s", e.Record.Id)
			// Small delay or reload might be needed if using AfterCreate goroutine,
			// but PocketBase v0.23 After hooks are usually safe for this.
			go r.processUserMessage(e.Record)
		}
		return e.Next()
	})
}

func (r *RelayService) registerAgentHooks() {
	// Sync agent files on Create/Update
	sync := func(e *core.RecordEvent) error {
		go r.deployAgent(e.Record)
		return e.Next()
	}

	r.app.OnRecordAfterCreateSuccess("ai_agents").BindFunc(sync)
	r.app.OnRecordAfterUpdateSuccess("ai_agents").BindFunc(sync)
	
	// Initial Sync on startup
	go r.syncAllAgents()
}
