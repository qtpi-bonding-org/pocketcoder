package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. Proposals Collection (Drafting Table)
		proposals, _ := app.FindCollectionByNameOrId("proposals")
		if proposals == nil {
			proposals = core.NewCollection(core.CollectionTypeBase, "proposals")
		}

		if proposals.Fields.GetByName("name") == nil {
			proposals.Fields.Add(&core.TextField{Name: "name", Required: true})
		}
		if proposals.Fields.GetByName("description") == nil {
			proposals.Fields.Add(&core.TextField{Name: "description"})
		}
		if proposals.Fields.GetByName("content") == nil {
			proposals.Fields.Add(&core.TextField{Name: "content", Required: true})
		}
		if proposals.Fields.GetByName("authored_by") == nil {
			proposals.Fields.Add(&core.SelectField{
				Name:     "authored_by",
				Required: true,
				Values:   []string{"human", "poco"},
			})
		}
		if proposals.Fields.GetByName("status") == nil {
			proposals.Fields.Add(&core.SelectField{
				Name:     "status",
				Required: true,
				Values:   []string{"draft", "approved"},
			})
		}

		// Rules: Both human and Poco (via Relay) can participate
		proposals.ListRule = ptr("@request.auth.id != ''")
		proposals.ViewRule = ptr("@request.auth.id != ''")
		proposals.CreateRule = ptr("@request.auth.id != ''")
		proposals.UpdateRule = ptr("@request.auth.id != ''")
		proposals.DeleteRule = ptr("@request.auth.id != ''")

		if err := app.Save(proposals); err != nil {
			return err
		}

		// 2. SOPs Collection (The Sovereign Ledger)
		sops, _ := app.FindCollectionByNameOrId("sops")
		if sops == nil {
			sops = core.NewCollection(core.CollectionTypeBase, "sops")
		}

		if sops.Fields.GetByName("name") == nil {
			sops.Fields.Add(&core.TextField{Name: "name", Required: true})
		}
		if sops.Fields.GetByName("description") == nil {
			sops.Fields.Add(&core.TextField{Name: "description", Required: true})
		}
		if sops.Fields.GetByName("content") == nil {
			sops.Fields.Add(&core.TextField{Name: "content", Required: true})
		}
		if sops.Fields.GetByName("signature") == nil {
			sops.Fields.Add(&core.TextField{Name: "signature", Required: true})
		}
		if sops.Fields.GetByName("approved_at") == nil {
			sops.Fields.Add(&core.DateField{Name: "approved_at"})
		}

		// Rules: Human manages, Poco only reads
		sops.ListRule = ptr("@request.auth.id != ''")
		sops.ViewRule = ptr("@request.auth.id != ''")
		sops.CreateRule = ptr("") // Only backend can create from proposal
		sops.UpdateRule = ptr("")
		sops.DeleteRule = ptr("@request.auth.id != ''")

		sops.Indexes = []string{
			"CREATE UNIQUE INDEX idx_sops_name ON sops (name)",
		}

		if err := app.Save(sops); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		proposals, _ := app.FindCollectionByNameOrId("proposals")
		if proposals != nil {
			app.Delete(proposals)
		}
		sops, _ := app.FindCollectionByNameOrId("sops")
		if sops != nil {
			app.Delete(sops)
		}
		return nil
	})
}
