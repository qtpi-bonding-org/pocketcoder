package transaction

import (
	"encoding/json"
	"os"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
)

func loadJournal(path string) (state.Transaction, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return state.Transaction{}, err
	}
	var transaction state.Transaction
	if err := json.Unmarshal(data, &transaction); err != nil {
		return state.Transaction{}, err
	}
	return transaction, nil
}

func removeDurable(path string) error {
	return state.RemoveDurable(path)
}
