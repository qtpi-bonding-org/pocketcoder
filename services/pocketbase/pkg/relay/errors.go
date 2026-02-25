package relay

import (
	"encoding/json"
	"errors"
	"strings"
)

// InfrastructureError represents an Envelope_1 error from the relay
// for infrastructure-level failures (Docker/network failures).
type InfrastructureError struct {
	Source string `json:"source"` // Always "relay"
	Error  struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

// ProviderError represents an Envelope_2 error from OpenCode
// for provider-level failures (LLM/API failures).
type ProviderError struct {
	Source string `json:"source"` // Always "opencode"
	Error  struct {
		Name         string `json:"name"`
		Message      string `json:"message"`
		ResponseBody string `json:"responseBody,omitempty"` // Stringified JSON to match OpenCode's Zod schema
		IsRetryable  bool   `json:"isRetryable,omitempty"`  // Maps to OpenCode's APIError.isRetryable field
	} `json:"error"`
}

// ErrorEnvelope is a union interface for both envelope types.
type ErrorEnvelope interface {
	GetSource() string
	Validate() error
	ToJSON() ([]byte, error)
}

// GetSource returns the source field of the envelope.
func (e *InfrastructureError) GetSource() string {
	return e.Source
}

// GetSource returns the source field of the envelope.
func (e *ProviderError) GetSource() string {
	return e.Source
}

// Validate checks that the InfrastructureError has all required fields.
func (e *InfrastructureError) Validate() error {
	if e.Source != "relay" {
		return errors.New("infrastructure error must have source 'relay'")
	}
	if e.Error.Code == "" {
		return errors.New("infrastructure error must have error.code")
	}
	if e.Error.Message == "" {
		return errors.New("infrastructure error must have error.message")
	}
	return nil
}

// Validate checks that the ProviderError has all required fields.
func (e *ProviderError) Validate() error {
	if e.Source != "opencode" {
		return errors.New("provider error must have source 'opencode'")
	}
	if e.Error.Name == "" {
		return errors.New("provider error must have error.name")
	}
	if e.Error.Message == "" {
		return errors.New("provider error must have error.message")
	}
	return nil
}

// ToJSON serializes the InfrastructureError to JSON.
func (e *InfrastructureError) ToJSON() ([]byte, error) {
	return json.Marshal(e)
}

// ToJSON serializes the ProviderError to JSON.
func (e *ProviderError) ToJSON() ([]byte, error) {
	return json.Marshal(e)
}

// Error code constants for infrastructure errors.
const (
	ErrCodeConnectionFailed     = "connection_failed"
	ErrCodeNetworkTimeout       = "network_timeout"
	ErrCodeContainerUnreachable = "container_unreachable"
	ErrCodeHeartbeatTimeout     = "heartbeat_timeout"
	ErrCodeDockerNetworkTimeout = "docker_network_timeout"
	ErrCodeStreamClosed         = "stream_closed"
	ErrCodeInternalError        = "internal_error"
)

// Error code to human-readable message mapping.
var errorMessages = map[string]string{
	ErrCodeConnectionFailed:     "Failed to connect to OpenCode container",
	ErrCodeNetworkTimeout:       "Network request to OpenCode timed out",
	ErrCodeContainerUnreachable: "OpenCode container is unreachable",
	ErrCodeHeartbeatTimeout:     "No heartbeat received from OpenCode for 45+ seconds",
	ErrCodeDockerNetworkTimeout: "Docker network connection failed",
	ErrCodeStreamClosed:         "SSE stream from OpenCode closed unexpectedly",
	ErrCodeInternalError:        "Internal relay error occurred",
}

// NewInfrastructureError creates a new Envelope_1 error with the given code.
func NewInfrastructureError(code string) *InfrastructureError {
	env := &InfrastructureError{
		Source: "relay",
	}
	env.Error.Code = code
	if msg, ok := errorMessages[code]; ok {
		env.Error.Message = msg
	} else {
		env.Error.Message = "Unknown infrastructure error"
	}
	return env
}

// NewProviderError creates a new Envelope_2 error by wrapping OpenCode error data.
// The responseBody is preserved as a string to match OpenCode's Zod schema.
func NewProviderError(openCodeError map[string]interface{}) *ProviderError {
	env := &ProviderError{
		Source: "opencode",
	}

	if name, ok := openCodeError["name"].(string); ok {
		env.Error.Name = name
	}
	if message, ok := openCodeError["message"].(string); ok {
		env.Error.Message = message
	}

	// ResponseBody must be stored as string to match OpenCode's Zod schema
	if responseBody, ok := openCodeError["responseBody"]; ok && responseBody != nil {
		switch rb := responseBody.(type) {
		case string:
			env.Error.ResponseBody = rb
		default:
			// Convert to JSON string for non-string types
			if jsonBytes, err := json.Marshal(responseBody); err == nil {
				env.Error.ResponseBody = string(jsonBytes)
			}
		}
	}

	// Map isRetryable field from OpenCode APIError
	if isRetryable, ok := openCodeError["isRetryable"].(bool); ok {
		env.Error.IsRetryable = isRetryable
	}

	return env
}

// ValidateEnvelope1 validates an Envelope_1 structure.
func ValidateEnvelope1(env *InfrastructureError) error {
	return env.Validate()
}

// ValidateEnvelope2 validates an Envelope_2 structure.
func ValidateEnvelope2(env *ProviderError) error {
	return env.Validate()
}

// SerializeEnvelope converts an error envelope to JSON.
func SerializeEnvelope(env ErrorEnvelope) ([]byte, error) {
	return env.ToJSON()
}

// DeserializeEnvelope parses JSON into an error envelope.
func DeserializeEnvelope(data []byte) (ErrorEnvelope, error) {
	// Try to determine the envelope type from the source field
	var sourceCheck struct {
		Source string `json:"source"`
	}
	if err := json.Unmarshal(data, &sourceCheck); err != nil {
		return nil, errors.New("invalid JSON: cannot parse envelope source")
	}

	if sourceCheck.Source == "relay" {
		var env InfrastructureError
		if err := json.Unmarshal(data, &env); err != nil {
			return nil, err
		}
		return &env, nil
	} else if sourceCheck.Source == "opencode" {
		var env ProviderError
		if err := json.Unmarshal(data, &env); err != nil {
			return nil, err
		}
		return &env, nil
	}

	return nil, errors.New("unknown envelope source: " + sourceCheck.Source)
}

// IsRetryableError checks if an error envelope indicates a retryable error.
func IsRetryableError(env ErrorEnvelope) bool {
	if providerErr, ok := env.(*ProviderError); ok {
		return providerErr.Error.IsRetryable
	}
	return false
}

// GetErrorCode returns the error code from an InfrastructureError.
func GetErrorCode(env *InfrastructureError) string {
	return env.Error.Code
}

// GetErrorMessage returns the error message from an error envelope.
func GetErrorMessage(env ErrorEnvelope) string {
	switch e := env.(type) {
	case *InfrastructureError:
		return e.Error.Message
	case *ProviderError:
		return e.Error.Message
	default:
		return ""
	}
}

// GetErrorName returns the error name from a ProviderError.
func GetErrorName(env *ProviderError) string {
	return env.Error.Name
}

// GetResponseBody returns the response body from a ProviderError.
func GetResponseBody(env *ProviderError) string {
	return env.Error.ResponseBody
}

// NewFallbackError creates a fallback Envelope_1 with code "internal_error".
func NewFallbackError() *InfrastructureError {
	return NewInfrastructureError(ErrCodeInternalError)
}

// IsInfrastructureError checks if the envelope is an infrastructure error.
func IsInfrastructureError(env ErrorEnvelope) bool {
	_, ok := env.(*InfrastructureError)
	return ok
}

// IsProviderError checks if the envelope is a provider error.
func IsProviderError(env ErrorEnvelope) bool {
	_, ok := env.(*ProviderError)
	return ok
}

// ParseOpenCodeError parses an error from OpenCode's event data.
func ParseOpenCodeError(eventData map[string]interface{}) *ProviderError {
	if errorData, ok := eventData["error"].(map[string]interface{}); ok && errorData != nil {
		return NewProviderError(errorData)
	}
	return nil
}

// CreateInfrastructureErrorFromConnectionError creates an infrastructure error
// based on the type of connection error encountered.
func CreateInfrastructureErrorFromConnectionError(err error) *InfrastructureError {
	errStr := err.Error()

	if strings.Contains(errStr, "connection refused") {
		return NewInfrastructureError(ErrCodeContainerUnreachable)
	}
	if strings.Contains(errStr, "timeout") || strings.Contains(errStr, "deadline") {
		return NewInfrastructureError(ErrCodeNetworkTimeout)
	}
	if strings.Contains(errStr, "no such host") || strings.Contains(errStr, "dial tcp") {
		return NewInfrastructureError(ErrCodeContainerUnreachable)
	}

	return NewInfrastructureError(ErrCodeConnectionFailed)
}