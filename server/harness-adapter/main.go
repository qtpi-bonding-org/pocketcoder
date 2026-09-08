package main

import (
	"flag"
	"log"
	"net/http"
	"os"
	"strings"
)

// secretEnvVar is what a harnesses.launch_template.env_template entry
// should target to deliver the per-instance secret hooks.ProvisionHarnessInstance
// mints (e.g. {"HARNESS_ADAPTER_SECRET": "{{.__adapter_secret}}"}) — Docker
// passes container Env to an exec-form ENTRYPOINT's process regardless of
// shell vs exec form, so no shell wrapper is needed to read it here.
const secretEnvVar = "HARNESS_ADAPTER_SECRET"

// resolveSecret picks the adapter's auth secret: the --secret flag when
// non-empty, else the value of HARNESS_ADAPTER_SECRET (read via getenv, so
// tests can inject a fake environment instead of mutating the process's
// real one).
func resolveSecret(flagSecret string, getenv func(string) string) string {
	if flagSecret != "" {
		return flagSecret
	}
	return getenv(secretEnvVar)
}

const logRawLinesEnvVar = "HARNESS_ADAPTER_LOG_RAW_LINES"

func resolveLogRawLines(flagSet bool, getenv func(string) string) bool {
	return flagSet || getenv(logRawLinesEnvVar) != ""
}

func main() {
	cmd := flag.String("cmd", "", "the stdio ACP binary to spawn per connection, e.g. 'claude-agent-acp'")
	port := flag.String("port", "3000", "port to listen on")
	secret := flag.String("secret", "", "?token= value the adapter enforces on the WS upgrade; overrides HARNESS_ADAPTER_SECRET when both are set")
	logRawLines := flag.Bool("log-raw-lines", false, "log raw ACP JSON-RPC line content (tool args/results included); overridable via HARNESS_ADAPTER_LOG_RAW_LINES")
	flag.Parse()
	if *cmd == "" {
		log.Fatal("harness-adapter: --cmd is required")
	}
	resolvedSecret := resolveSecret(*secret, os.Getenv)
	resolvedLogRawLines := resolveLogRawLines(*logRawLines, os.Getenv)
	handler := newAdapterHandler(adapterConfig{
		Cmd:          strings.Fields(*cmd),
		Secret:       resolvedSecret,
		MaxLineBytes: 64 << 20,
		LogRawLines:  resolvedLogRawLines,
	})
	log.Printf("harness-adapter listening on :%s, spawning %q per connection", *port, *cmd)
	log.Fatal(http.ListenAndServe(":"+*port, handler))
}
