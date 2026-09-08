package gitssh

import (
	"context"
	"fmt"
	"net"
	"strconv"
	"strings"
	"time"

	"golang.org/x/crypto/ssh"
)

func ProbeHostKey(ctx context.Context, host string, port int) (string, error) {
	var observed ssh.PublicKey
	config := &ssh.ClientConfig{
		User: "git",
		Auth: []ssh.AuthMethod{},
		HostKeyCallback: func(hostname string, remote net.Addr, key ssh.PublicKey) error {
			observed = key
			// Handshake only needs to see the key; refusing here avoids a
			// real authentication attempt against a server we don't trust
			// yet.
			return fmt.Errorf("host key observed, aborting handshake by design")
		},
	}

	var d net.Dialer
	conn, err := d.DialContext(ctx, "tcp", net.JoinHostPort(host, strconv.Itoa(port)))
	if err != nil {
		return "", fmt.Errorf("dial %s:%d: %w", host, port, err)
	}
	defer conn.Close()

	deadline := time.Now().Add(10 * time.Second)
	if ctxDeadline, ok := ctx.Deadline(); ok && ctxDeadline.Before(deadline) {
		deadline = ctxDeadline
	}
	if err := conn.SetDeadline(deadline); err != nil {
		return "", fmt.Errorf("set handshake deadline for %s:%d: %w", host, port, err)
	}

	_, _, _, err = ssh.NewClientConn(conn, net.JoinHostPort(host, strconv.Itoa(port)), config)
	if observed == nil {
		return "", fmt.Errorf("handshake with %s:%d never presented a host key: %w", host, port, err)
	}

	line := strings.TrimSpace(string(ssh.MarshalAuthorizedKey(observed)))
	return host + " " + line, nil
}
