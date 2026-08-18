package osctl

type Candidate struct {
	Version string
}

type Controller interface {
	CurrentVersion() (string, error)
	Update() error
	Restart() error
	Upgrade(candidate Candidate) error
	RestorePrevious() error
}
