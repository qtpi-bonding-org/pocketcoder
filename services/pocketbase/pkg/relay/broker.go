package relay

import (
	"encoding/json"
	"log"

	"github.com/pocketbase/pocketbase/tools/subscriptions"
	"golang.org/x/sync/errgroup"
)

// broadcastToChat pushes JSON events to connected realtime clients subscribed to "chats:{chatID}".
func (r *RelayService) broadcastToChat(chatID string, eventName string, data interface{}) {
	topic := "chats:" + chatID

	broker := r.app.SubscriptionsBroker()
	if broker == nil {
		return
	}

	// We wrap our data in the HotPipeEvent format the client expects
	payload := map[string]interface{}{
		"event": eventName,
		"data":  data,
	}

	rawData, err := json.Marshal(payload)
	if err != nil {
		log.Printf("❌ [Relay/Broker] Error marshaling event %s: %v", eventName, err)
		return
	}

	message := subscriptions.Message{
		Name: topic,
		Data: rawData,
	}

	group := new(errgroup.Group)

	// Chunk clients for concurrent delivery
	chunks := broker.ChunkedClients(300)

	for _, chunk := range chunks {
		// create a local copy for the goroutine
		c := chunk
		group.Go(func() error {
			for _, client := range c {
				if !client.HasSubscription(topic) {
					continue
				}
				client.Send(message)
			}
			return nil
		})
	}

	if err := group.Wait(); err != nil {
		log.Printf("❌ [Relay/Broker] Error broadcasing to %s: %v", topic, err)
	}
}

// broadcastTextDelta defines a shortcut for the text_delta event stream
func (r *RelayService) broadcastTextDelta(chatID, partID, delta string) {
	r.broadcastToChat(chatID, "text_delta", map[string]interface{}{
		"partID": partID,
		"text":   delta,
	})
}
