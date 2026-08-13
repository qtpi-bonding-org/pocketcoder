package contract

import "encoding/json"

const SchemaVersion = 1

// AttestationDescriptor locates the GitHub Actions Sigstore bundle for a
// subject. Publisher identity is deliberately not data: it is immutable
// verifier policy baked into the native release manager.
type AttestationDescriptor struct {
	URL string `json:"url"`
}

type ManifestReference struct {
	URL           string                `json:"url"`
	SHA256        string                `json:"sha256"`
	DownloadBytes int64                 `json:"downloadBytes"`
	Attestation   AttestationDescriptor `json:"attestation"`
}

type ChannelPointer struct {
	SchemaVersion int                   `json:"schemaVersion"`
	Channel       string                `json:"channel"`
	Sequence      int64                 `json:"sequence"`
	PromotedAt    string                `json:"promotedAt"`
	Manifest      ManifestReference     `json:"manifest"`
	Attestation   AttestationDescriptor `json:"attestation"`
}

type Revocation struct {
	ReasonCode string `json:"reasonCode"`
	Summary    string `json:"summary"`
	RevokedAt  string `json:"revokedAt"`
}

type Revocations struct {
	SchemaVersion   int                   `json:"schemaVersion"`
	Sequence        int64                 `json:"sequence"`
	PublishedAt     string                `json:"publishedAt"`
	RevokedReleases map[string]Revocation `json:"revokedReleases"`
}

type VersionRange struct {
	Minimum int `json:"minimum"`
	Maximum int `json:"maximum"`
}

type AppCompatibility struct {
	ContractVersion         int               `json:"contractVersion"`
	OfficialMinimumVersions map[string]string `json:"officialMinimumVersions"`
}

type APICompatibility struct {
	APIVersion int `json:"apiVersion"`
}

type ContractCompatibility struct {
	ContractVersion int `json:"contractVersion"`
}

type DeploymentCompatibility struct {
	ContractVersion                 int          `json:"contractVersion"`
	SupportedSourceContractVersions VersionRange `json:"supportedSourceContractVersions"`
}

type Compatibility struct {
	App          AppCompatibility        `json:"app"`
	Server       APICompatibility        `json:"server"`
	Workers      map[string]int          `json:"workers"`
	Provisioning ContractCompatibility   `json:"provisioning"`
	Deployment   DeploymentCompatibility `json:"deployment"`
}

type Platform struct {
	OS           string `json:"os"`
	Architecture string `json:"architecture"`
}

type Document struct {
	SchemaVersion *int   `json:"schemaVersion,omitempty"`
	MediaType     string `json:"mediaType"`
	SourcePath    string `json:"sourcePath"`
	URL           string `json:"url"`
	SHA256        string `json:"sha256"`
	DownloadBytes int64  `json:"downloadBytes"`
}

type Artifact struct {
	URL           string   `json:"url"`
	SHA256        string   `json:"sha256"`
	DownloadBytes int64    `json:"downloadBytes"`
	UnpackedBytes int64    `json:"unpackedBytes"`
	Images        []string `json:"images,omitempty"`
}

type OSDelivery struct {
	Kind           string            `json:"kind"`
	Artifact       *Artifact         `json:"artifact,omitempty"`
	ProviderImages map[string]string `json:"providerImages,omitempty"`
}

type OSBootstrap struct {
	Kind                string   `json:"kind"`
	ScriptDocument      string   `json:"scriptDocument,omitempty"`
	SupportingDocuments []string `json:"supportingDocuments,omitempty"`
}

type OSImage struct {
	Delivery  OSDelivery  `json:"delivery"`
	Bootstrap OSBootstrap `json:"bootstrap"`
}

type ChoiceGroup struct {
	SchemaVersion     int                 `json:"schemaVersion"`
	ConsumerPolicy    string              `json:"consumerPolicy"`
	CatalogDocument   string              `json:"catalogDocument,omitempty"`
	MinimumSelections int                 `json:"minimumSelections"`
	MaximumSelections *int                `json:"maximumSelections"`
	Options           map[string]Artifact `json:"options"`
}

type OptionalRegistryImage struct {
	Image          string `json:"image"`
	ComposeProfile string `json:"composeProfile"`
}

type RegistryImages struct {
	Required []string                         `json:"required"`
	Optional map[string]OptionalRegistryImage `json:"optional"`
}

type Images struct {
	Required map[string]Artifact    `json:"required"`
	Choices  map[string]ChoiceGroup `json:"choices"`
	Registry RegistryImages         `json:"registry"`
}

type Manifest struct {
	SchemaVersion                 int                        `json:"schemaVersion"`
	ServerVersion                 string                     `json:"serverVersion"`
	SourceRepository              string                     `json:"sourceRepository"`
	SourceCommit                  string                     `json:"sourceCommit"`
	BuiltAt                       string                     `json:"builtAt"`
	Platform                      Platform                   `json:"platform"`
	DataVersion                   int                        `json:"dataVersion"`
	MinimumUpgradeFromDataVersion int                        `json:"minimumUpgradeFromDataVersion"`
	Compatibility                 Compatibility              `json:"compatibility"`
	Documents                     map[string]Document        `json:"documents"`
	OSImages                      map[string]OSImage         `json:"osImages"`
	ServerFiles                   Artifact                   `json:"serverFiles"`
	Images                        Images                     `json:"images"`
	Extensions                    map[string]json.RawMessage `json:"extensions,omitempty"`
}
