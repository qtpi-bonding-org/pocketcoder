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
