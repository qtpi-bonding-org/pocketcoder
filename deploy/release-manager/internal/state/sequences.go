package state

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
)

type Sequences map[string]int64

func LoadSequences(path string) (Sequences, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return Sequences{}, nil
	}
	if err != nil {
		return nil, err
	}
	var sequences Sequences
	if err := json.Unmarshal(data, &sequences); err != nil {
		return nil, fmt.Errorf("decode persisted sequences: %w", err)
	}
	return sequences, nil
}

func (sequences Sequences) Accept(name string, candidate, floor int64) error {
	required := floor
	if persisted := sequences[name]; persisted > required {
		required = persisted
	}
	if candidate < required {
		return fmt.Errorf("%s sequence replay rejected: got %d, require at least %d", name, candidate, required)
	}
	return nil
}
