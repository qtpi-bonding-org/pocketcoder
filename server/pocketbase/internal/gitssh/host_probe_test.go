package gitssh

import (
	"context"
	"net"
	"strconv"
	"strings"
	"testing"
	"time"

	"golang.org/x/crypto/ssh"
)

func serveOneHandshake(t *testing.T, hostKey ssh.Signer) (host string, port int) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ln.Close() })

	config := &ssh.ServerConfig{NoClientAuth: true}
	config.AddHostKey(hostKey)

	go func() {
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		_, chans, reqs, _ := ssh.NewServerConn(conn, config)
		if chans == nil {
			return
		}
		go ssh.DiscardRequests(reqs)
		for ch := range chans {
			_ = ch.Reject(ssh.Prohibited, "no channels")
		}
	}()

	addr := ln.Addr().String()
	h, p, err := net.SplitHostPort(addr)
	if err != nil {
		t.Fatal(err)
	}
	portNum, err := strconv.Atoi(p)
	if err != nil {
		t.Fatal(err)
	}
	return h, portNum
}

func newTestHostKey(t *testing.T) ssh.Signer {
	t.Helper()
	k, err := GenerateKey("test-host-key")
	if err != nil {
		t.Fatal(err)
	}
	signer, err := ssh.ParsePrivateKey(k.Private)
	if err != nil {
		t.Fatal(err)
	}
	return signer
}

func TestProbeHostKeyReturnsAKnownHostsLineMatchingTheServer(t *testing.T) {
	hostKey := newTestHostKey(t)
	host, port := serveOneHandshake(t, hostKey)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	line, err := ProbeHostKey(ctx, host, port)
	if err != nil {
		t.Fatal(err)
	}

	wantMarshaled := strings.TrimSpace(string(ssh.MarshalAuthorizedKey(hostKey.PublicKey())))
	if !strings.HasSuffix(line, wantMarshaled) {
		t.Fatalf("known_hosts line %q does not end with the server's public key %q", line, wantMarshaled)
	}
	if !strings.HasPrefix(line, host+" ") {
		t.Fatalf("known_hosts line %q does not start with host %q", line, host)
	}
}

func TestProbeHostKeyRespectsCtxDeadlineEvenWhenTheServerNeverSpeaks(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ln.Close() })
	go func() {
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		// Accept the TCP connection but never send an SSH banner --
		// simulates a tarpit or a non-SSH service on that host/port.
		<-t.Context().Done()
		_ = conn.Close()
	}()

	addr := ln.Addr().String()
	h, p, _ := net.SplitHostPort(addr)
	portNum, _ := strconv.Atoi(p)

	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()

	start := time.Now()
	_, err = ProbeHostKey(ctx, h, portNum)
	elapsed := time.Since(start)

	if err == nil {
		t.Fatal("expected an error from a server that never completes the handshake")
	}
	if elapsed > 3*time.Second {
		t.Fatalf("ProbeHostKey took %s to return; it must respect ctx's deadline instead of blocking indefinitely", elapsed)
	}
}

func TestProbeHostKeyFailsFastOnAClosedPort(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	addr := ln.Addr().String()
	_ = ln.Close()
	h, p, _ := net.SplitHostPort(addr)
	portNum, _ := strconv.Atoi(p)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if _, err := ProbeHostKey(ctx, h, portNum); err == nil {
		t.Fatal("expected an error connecting to a closed port")
	}
}
