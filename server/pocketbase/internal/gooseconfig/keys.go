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

package gooseconfig

import (
	"fmt"
	"sort"
	"strings"
)

// RenderKeysEnv merges provider_keys env_vars maps (later sets win) into a
// deterministic KEY=VALUE env file, keys sorted. Secrets live only here.
func RenderKeysEnv(keySets []map[string]any) []byte {
	merged := map[string]string{}
	for _, set := range keySets {
		for k, v := range set {
			merged[k] = fmt.Sprintf("%v", v)
		}
	}
	keys := make([]string, 0, len(merged))
	for k := range merged {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var b strings.Builder
	for _, k := range keys {
		b.WriteString(k)
		b.WriteByte('=')
		b.WriteString(merged[k])
		b.WriteByte('\n')
	}
	return []byte(b.String())
}
