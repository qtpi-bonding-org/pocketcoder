package contract

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
)

var ErrTrailingJSON = errors.New("trailing data after JSON value")

// DecodeStrict rejects duplicate object members, unknown typed fields, and
// trailing JSON. Release metadata is security-sensitive and must have one
// unambiguous interpretation across every consumer.
func DecodeStrict(data []byte, destination any) error {
	if err := rejectDuplicateMembers(data); err != nil {
		return err
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(destination); err != nil {
		return fmt.Errorf("decode release JSON: %w", err)
	}
	var trailing any
	if err := decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
		if err == nil {
			return ErrTrailingJSON
		}
		return fmt.Errorf("decode trailing release JSON: %w", err)
	}
	return nil
}

func rejectDuplicateMembers(data []byte) error {
	decoder := json.NewDecoder(bytes.NewReader(data))
	var stack []map[string]struct{}
	var expectingKey []bool
	for {
		token, err := decoder.Token()
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("tokenize release JSON: %w", err)
		}
		switch value := token.(type) {
		case json.Delim:
			switch value {
			case '{':
				stack = append(stack, make(map[string]struct{}))
				expectingKey = append(expectingKey, true)
			case '}':
				stack = stack[:len(stack)-1]
				expectingKey = expectingKey[:len(expectingKey)-1]
				markParentValueConsumed(expectingKey)
			case '[':
				stack = append(stack, nil)
				expectingKey = append(expectingKey, false)
			case ']':
				stack = stack[:len(stack)-1]
				expectingKey = expectingKey[:len(expectingKey)-1]
				markParentValueConsumed(expectingKey)
			}
		case string:
			if len(stack) > 0 && stack[len(stack)-1] != nil && expectingKey[len(expectingKey)-1] {
				members := stack[len(stack)-1]
				if _, exists := members[value]; exists {
					return fmt.Errorf("duplicate JSON member %q", value)
				}
				members[value] = struct{}{}
				expectingKey[len(expectingKey)-1] = false
			} else {
				markParentValueConsumed(expectingKey)
			}
		default:
			markParentValueConsumed(expectingKey)
		}
	}
}

func markParentValueConsumed(expectingKey []bool) {
	if len(expectingKey) > 0 && !expectingKey[len(expectingKey)-1] {
		expectingKey[len(expectingKey)-1] = true
	}
}
