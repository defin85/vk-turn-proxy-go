package main

import (
	"os"

	"github.com/defin85/vk-turn-proxy-go/internal/linuxtunhelper"
)

func main() {
	os.Exit(linuxtunhelper.Run(os.Stdin, os.Stdout, os.Stderr, os.Args[1:]))
}
