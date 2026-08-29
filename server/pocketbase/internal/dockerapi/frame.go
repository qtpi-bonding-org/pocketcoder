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
	"encoding/binary"
	"fmt"
	"io"
)

// MaxLogFrameSize is the largest payload accepted from a Docker log frame.
const MaxLogFrameSize = 1 << 20

// DecodeLogFrame reads one Docker multiplexed log frame.
func DecodeLogFrame(r *bufio.Reader) (stream byte, payload []byte, err error) {
	peek, peekErr := r.Peek(8)
	if peekErr != nil {
		if len(peek) == 0 && (peekErr == io.EOF || peekErr == io.ErrUnexpectedEOF) {
			// Nothing left at all: a clean end of stream.
			return 0, nil, io.EOF
		}
		// Fewer than 8 bytes remain before end-of-stream. This is
		// indistinguishable from a truncated/corrupted multiplexed frame,
		// so preserve the original (pre-TTY-support) behavior of erroring
		// rather than guessing it's a raw stream's short final chunk.
		return 0, nil, peekErr
	}
	// TTY containers return raw bytes rather than Docker's multiplexed
	// frames. Only take this branch when the leading byte isn't a valid
	// stream-type marker -- a valid-looking header with a bogus/oversized
	// size field is a genuinely malformed multiplexed frame, not raw mode,
	// and must still hit the "exceeds maximum" error below. Read one line
	// at a time here, not io.ReadAll: this function is also used by the
	// live SSE follow loop, and ReadAll would block until the whole
	// connection closes before yielding anything.
	if peek[0] != 0 && peek[0] != 1 && peek[0] != 2 {
		payload, _ = r.ReadBytes('\n')
		if len(payload) == 0 {
			return 0, nil, io.EOF
		}
		return 0, payload, nil
	}
	var header [8]byte
	if _, err := io.ReadFull(r, header[:]); err != nil {
		return 0, nil, err
	}
	size := binary.BigEndian.Uint32(header[4:])
	if size > MaxLogFrameSize {
		return 0, nil, fmt.Errorf("docker log frame payload %d exceeds maximum %d", size, MaxLogFrameSize)
	}
	payload = make([]byte, int(size))
	if _, err := io.ReadFull(r, payload); err != nil {
		return 0, nil, err
	}
	return header[0], payload, nil
}
