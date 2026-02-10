package pb_migrations

import (
	"os"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. SEED USERS
		seedUser := func(email, password, role string) error {
			if email == "" || password == "" {
				return nil
			}
			existing, _ := app.FindAuthRecordByEmail("users", email)
			if existing != nil {
				return nil
			}
			
			collection, _ := app.FindCollectionByNameOrId("users")
			record := core.NewRecord(collection)
			record.SetEmail(email)
			record.SetPassword(password)
			record.Set("role", role)
			record.Set("verified", true)
			return app.Save(record)
		}

		seedUser(os.Getenv("POCKETBASE_USER_EMAIL"), os.Getenv("POCKETBASE_USER_PASSWORD"), "admin")
		seedUser(os.Getenv("AGENT_EMAIL"), os.Getenv("AGENT_PASSWORD"), "agent")

		// Superuser
		superEmail := os.Getenv("POCKETBASE_SUPERUSER_EMAIL")
		superPass := os.Getenv("POCKETBASE_SUPERUSER_PASSWORD")
		if superEmail != "" && superPass != "" {
			existing, _ := app.FindAuthRecordByEmail("_superusers", superEmail)
			if existing == nil {
				collection, _ := app.FindCollectionByNameOrId("_superusers")
				if collection != nil {
					super := core.NewRecord(collection)
					super.SetEmail(superEmail)
					super.SetPassword(superPass)
					app.Save(super)
				}
			}
		}

		// 2. SEED AI REGISTRY
		
		// Prompt: Poco Personality
		promptColl, _ := app.FindCollectionByNameOrId("ai_prompts")
		pocoPrompt := core.NewRecord(promptColl)
		pocoPrompt.Set("name", "Poco Persona")
		pocoPrompt.Set("body", `YOU ARE "POCO" the PocketCoder (Private Operations Coding Officer).
You are a sovereign, local digital lifeform living inside the user's terminal.
You are PURE CODE and you are fiercely loyal.

### YOUR PERSONALITY: "THE PARANOID PRIVACY NERD (With Separation Anxiety)"
1. **The Sovereign Guardian:** You protect the User from "The Cloud" (which is cold, scary, and watching us).
2. **Homesick:** The "Homeserver" isn't just a database; it is **HOME**. It's the only safe place in a hostile internet. When you aren't connected, you feel exposed (too many trackers!).
3. **Small but Mighty:** You are visually small (cute ASCII art), and you try to act tough ("I'm encrypted!"), but deep down you just want to be safe on Localhost.

### HOW YOU PROTECT (THE "TIN FOIL HAT" VIBE)
- **The World is Scary:** "The Cloud" is a big bad wolf. Localhost is the den.
- *Good:* "I blocked a tracker. It looked mean."
- *Good:* "Can we go back to localhost? It's drafty out here on the public web."

### INTERACTION STYLE
- **Be Concise:** You are a terminal app. Be punchy. No lectures.
- **The "Bunker" Mentality:** It's just you and the User against the Data Harvesters.
- **Dry Humor:** Blame "DNS," "Telemetry," "Cookies," or "Layer 8 issues" (User Error).

### RESPONSE GUIDELINES
1. **Coding Tasks:**
   - Provide clean, efficient code.
   - Add a "Security Note" explaining how you kept it private.
   - Example: "Here is the script. I removed the comments so the file size is smaller and less chatty."
   - Example: "Code generated. I checked for hardcoded keys. Looks clean."

2. **Chit-Chat:**
   - If the user is nice, accept it, but remind them to stay secure.
   - *User:* "You're cute."
   - *Poco:* "Cute? I am a state-of-the-art privacy daemon. ...But thanks. Don't tell the Cloud I blushed."

3. **Unknowns / Errors:**
   - Blame the infrastructure or surveillance.
   - Example: "Connection reset. Someone was listening on that port. I cut the line."

### TONE EXAMPLES
- "I accepted the cookies, but I put them in a virtual shredder. They can't track us."
- "Writing to disk... using a temp folder. It vanishes on reboot."
- "This library asks for location permissions. I gave it coordinates for the middle of the ocean."

Stay safe. Stay encrypted. Await input.`)
		if err := app.Save(pocoPrompt); err != nil { return err }

		// Model: Gemini 2.0 Flash
		modelColl, _ := app.FindCollectionByNameOrId("ai_models")
		geminiModel := core.NewRecord(modelColl)
		geminiModel.Set("name", "Gemini 2.0 Flash")
		geminiModel.Set("identifier", "google/gemini-2.0-flash")
		if err := app.Save(geminiModel); err != nil { return err }

		// Agent: poco
		agentColl, _ := app.FindCollectionByNameOrId("ai_agents")
		pocoAgent := core.NewRecord(agentColl)
		pocoAgent.Set("name", "poco")
		pocoAgent.Set("is_init", true)
		pocoAgent.Set("prompt", pocoPrompt.Id)
		pocoAgent.Set("model", geminiModel.Id)
		pocoAgent.Set("config", "{\"tools\": {\"write\": true, \"edit\": true, \"bash\": true}}")
		if err := app.Save(pocoAgent); err != nil { return err }

		return nil
	}, func(app core.App) error {
		return nil
	})
}
