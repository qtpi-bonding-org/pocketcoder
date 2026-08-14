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

package dockerapi

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"errors"
	"io"
	"testing"

	"testing/iotest"
)

func dockerFrame(stream byte, payload []byte) []byte {
	frame := make([]byte, 8+len(payload))
	frame[0] = stream
	binary.BigEndian.PutUint32(frame[4:8], uint32(len(payload)))
	copy(frame[8:], payload)
	return frame
}

func TestDecodeDockerFrame(t *testing.T) {
	stdout := dockerFrame(1, []byte("out\n"))
	stderr := dockerFrame(2, []byte("err\n"))

	t.Run("stdout", func(t *testing.T) {
		stream, payload, err := DecodeLogFrame(bufio.NewReader(bytes.NewReader(stdout)))
		if err != nil || stream != 1 || string(payload) != "out\n" {
			t.Fatalf("got stream %d payload %q err %v", stream, payload, err)
		}
	})
	t.Run("stderr", func(t *testing.T) {
		stream, payload, err := DecodeLogFrame(bufio.NewReader(bytes.NewReader(stderr)))
		if err != nil || stream != 2 || string(payload) != "err\n" {
			t.Fatalf("got stream %d payload %q err %v", stream, payload, err)
		}
	})

	t.Run("multiple", func(t *testing.T) {
		r := bufio.NewReader(bytes.NewReader(append(stdout, stderr...)))
		for _, want := range []struct {
			stream byte
			text   string
		}{{1, "out\n"}, {2, "err\n"}} {
			stream, payload, err := DecodeLogFrame(r)
			if err != nil || stream != want.stream || string(payload) != want.text {
				t.Fatalf("got stream %d payload %q err %v", stream, payload, err)
			}
		}
	})

	t.Run("partial reads", func(t *testing.T) {
		r := bufio.NewReader(iotest.OneByteReader(bytes.NewReader(stdout)))
		stream, payload, err := DecodeLogFrame(r)
		if err != nil || stream != 1 || string(payload) != "out\n" {
			t.Fatalf("got stream %d payload %q err %v", stream, payload, err)
		}
	})
}

func TestDecodeDockerFrameTruncated(t *testing.T) {
	tests := []struct {
		name string
		data []byte
	}{
		{"header", []byte{1, 0, 0}},
		{"payload", append([]byte{1, 0, 0, 0, 0, 0, 0, 4}, 'x')},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, err := DecodeLogFrame(bufio.NewReader(bytes.NewReader(tt.data)))
			if !errors.Is(err, io.EOF) && !errors.Is(err, io.ErrUnexpectedEOF) {
				t.Fatalf("expected EOF error, got %v", err)
			}
		})
	}
}

func TestDecodeDockerFrameOversized(t *testing.T) {
	var header [8]byte
	binary.BigEndian.PutUint32(header[4:], MaxLogFrameSize+1)
	_, _, err := DecodeLogFrame(bufio.NewReader(bytes.NewReader(header[:])))
	if err == nil {
		t.Fatal("expected oversized frame error")
	}
}

func FuzzDecodeDockerFrame(f *testing.F) {
	f.Add(dockerFrame(1, []byte("valid\n")))
	f.Add([]byte{})
	f.Add(make([]byte, 8))
	var huge [8]byte
	binary.BigEndian.PutUint32(huge[4:], ^uint32(0))
	f.Add(huge[:])
	f.Fuzz(func(t *testing.T, data []byte) {
		DecodeLogFrame(bufio.NewReader(bytes.NewReader(data)))
	})
}
