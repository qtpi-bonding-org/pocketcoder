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
// unambiguous interpretation across every consumer. Use this for anything
// this binary wrote itself (e.g. its own previously-persisted local state)
// -- self-produced data is always exactly as new as the code reading it, so
// there is no unknown-field case to tolerate.
func DecodeStrict(data []byte, destination any) error {
	return decode(data, destination, true)
}

// DecodeForward rejects duplicate object members and trailing JSON, but
// (unlike DecodeStrict) tolerates unknown fields. Use this for anything
// fetched fresh from the relay (channel pointer, release manifest,
// revocations) -- that data may have been published by newer tooling than
// whatever built this binary, and an older release-manager must be able to
// ignore fields it doesn't understand yet rather than fail outright.
// Rejecting DisallowUnknownFields here would make every future additive
// schema change permanently unrecoverable for any box still running an
// older binary: the box can only receive a fix through the very channel
// (parsing a fetched manifest) that a hard rejection would break, with no
// remote recovery path (every deployment is zero-touch, no SSH -- see the
// root CLAUDE.md's "Deployment Model"). Duplicate-member rejection is kept
// regardless -- that defends against JSON parser-differential ambiguity,
// which is a security property unrelated to schema evolution.
func DecodeForward(data []byte, destination any) error {
	return decode(data, destination, false)
}

func decode(data []byte, destination any, disallowUnknownFields bool) error {
	if err := rejectDuplicateMembers(data); err != nil {
		return err
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	if disallowUnknownFields {
		decoder.DisallowUnknownFields()
	}
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
