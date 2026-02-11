package relay

// resolveChatID attempts to find a chat associated with an OpenCode session ID.
func (r *RelayService) resolveChatID(sessionID string) string {
	if sessionID == "" {
		return ""
	}

	record, err := r.app.FindFirstRecordByFilter("chats", "opencode_id = {:id}", map[string]any{"id": sessionID})
	if err != nil {
		return ""
	}

	return record.Id
}
