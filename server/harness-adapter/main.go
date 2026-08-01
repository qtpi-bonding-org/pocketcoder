package main

import (
	"flag"
	"log"
	"net/http"
	"strings"
)

func main() {
	cmd := flag.String("cmd", "", "the stdio ACP binary to spawn per connection, e.g. 'claude-agent-acp'")
	port := flag.String("port", "3000", "port to listen on")
	secret := flag.String("secret", "", "?token= value the adapter enforces on the WS upgrade")
	flag.Parse()
	if *cmd == "" {
		log.Fatal("harness-adapter: --cmd is required")
	}
	handler := newAdapterHandler(adapterConfig{
		Cmd:          strings.Fields(*cmd),
		Secret:       *secret,
		MaxLineBytes: 64 << 20,
	})
	log.Printf("harness-adapter listening on :%s, spawning %q per connection", *port, *cmd)
	log.Fatal(http.ListenAndServe(":"+*port, handler))
}
