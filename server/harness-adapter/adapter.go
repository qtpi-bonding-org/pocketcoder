/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: stdio<->websocket bridge for stdio-native ACP harnesses
// (§5.4/§5.4.1 of the multi-harness design spec). Byte-transparent: this
// file must never parse or filter ACP JSON-RPC content — reframing only.
package main

import (
	"bufio"
	"context"
	"io"
	"log"
	"net/http"
	"os/exec"
	"sync"

	"github.com/coder/websocket"
)

type adapterConfig struct {
	Cmd          []string
	Secret       string
	MaxLineBytes int64
}

func newAdapterHandler(cfg adapterConfig) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/acp", func(w http.ResponseWriter, r *http.Request) {
		if cfg.Secret != "" && r.URL.Query().Get("token") != cfg.Secret {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}
		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			log.Printf("harness-adapter: websocket accept failed: %v", err)
			return
		}
		conn.SetReadLimit(cfg.MaxLineBytes)
		defer conn.Close(websocket.StatusNormalClosure, "") // harmless if bridgeConnection's own teardown already closed it — coder/websocket's Close is safe to call more than once
		bridgeConnection(r.Context(), conn, cfg)
	})
	return mux
}

// initialStdoutBufferSize is the bufio.Reader's internal read-chunk size,
// NOT a cap on message size — readUnboundedLine accumulates across
// ReadLine's isPrefix continuations regardless of this value, so it only
// affects syscall batching, not the (much larger) MaxLineBytes ceiling. A
// 64 MiB buffer here, once per bridged connection (i.e. once per prompt,
// per §5.4's spawn-per-connection model), would be wasteful for no benefit.
const initialStdoutBufferSize = 4096

// bridgeConnection spawns cfg.Cmd fresh for this one connection and relays
// newline-delimited JSON-RPC both directions: one subprocess stdout line ->
// one WS TEXT frame; one WS TEXT frame -> one subprocess stdin line. Never
// inspects message content beyond finding line boundaries.
//
// Teardown is symmetric and idempotent: whichever direction exits first
// (oversized line, subprocess exit, WS close, ctx cancellation) triggers
// killing the subprocess AND closing the WS connection, which together
// unblock whichever side was still stuck on a pipe read/write or a
// conn.Read/Write — otherwise a goroutine, its subprocess, and the OS pipe
// buffer backing it can all hang forever on exactly the size-limit or
// abrupt-disconnect paths this bridge exists to handle correctly.
func bridgeConnection(ctx context.Context, conn *websocket.Conn, cfg adapterConfig) {
	cmd := exec.Command(cfg.Cmd[0], cfg.Cmd[1:]...) // NOT CommandContext: teardown() below kills it on our own terms, so a ctx cancellation racing a normal exit is handled the same way as every other exit path, not as a special case
	stdin, err := cmd.StdinPipe()
	if err != nil {
		log.Printf("harness-adapter: create stdin pipe failed: %v", err)
		return
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Printf("harness-adapter: create stdout pipe failed: %v", err)
		return
	}
	if err := cmd.Start(); err != nil {
		log.Printf("harness-adapter: start command failed: %v", err)
		return
	}

	var once sync.Once
	var killed bool
	teardown := func() {
		once.Do(func() {
			if err := cmd.Process.Kill(); err == nil {
				killed = true
			} // unblocks a stuck stdout read or stdin write
			_ = conn.Close(websocket.StatusInternalError, "bridge closing") // unblocks a stuck conn.Read/Write
		})
	}
	defer teardown()

	var wg sync.WaitGroup
	wg.Add(2)

	// stdout (subprocess) -> WS
	go func() {
		defer wg.Done()
		defer teardown()
		reader := bufio.NewReaderSize(stdout, initialStdoutBufferSize)
		for {
			line, err := readUnboundedLine(reader, cfg.MaxLineBytes)
			if err != nil {
				log.Printf("harness-adapter: read subprocess stdout failed: %v", err)
				return
			}
			if len(line) == 0 {
				continue
			}
			if err := conn.Write(ctx, websocket.MessageText, line); err != nil {
				log.Printf("harness-adapter: write stdout to websocket failed: %v", err)
				return
			}
		}
	}()

	// WS -> stdin (subprocess)
	go func() {
		defer wg.Done()
		defer teardown()
		defer stdin.Close()
		for {
			_, data, err := conn.Read(ctx)
			if err != nil {
				log.Printf("harness-adapter: read websocket failed: %v", err)
				return
			}
			if _, err := stdin.Write(append(data, '\n')); err != nil {
				log.Printf("harness-adapter: write websocket data to stdin failed: %v", err)
				return
			}
		}
	}()

	wg.Wait()  // both directions have stopped — guaranteed by teardown() unblocking whichever side didn't exit on its own
	if err := cmd.Wait(); err != nil && !killed {
		log.Printf("harness-adapter: subprocess exited unexpectedly: %v", err)
	}
}

// readUnboundedLine reads up to a '\n' without Go's bufio.Scanner 64KB
// default token-size ceiling — the stdio-leg half of the "two limits, not
// one" finding (§5.4.1). maxBytes still bounds it, matching the WS leg's
// raised SetReadLimit, so neither side is silently unbounded either.
func readUnboundedLine(r *bufio.Reader, maxBytes int64) ([]byte, error) {
	var buf []byte
	for {
		chunk, isPrefix, err := r.ReadLine()
		if err != nil {
			return nil, err
		}
		buf = append(buf, chunk...)
		if int64(len(buf)) > maxBytes {
			return nil, io.ErrShortBuffer
		}
		if !isPrefix {
			return buf, nil
		}
	}
}
