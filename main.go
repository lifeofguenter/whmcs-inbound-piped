package main

import (
	"bytes"
	"fmt"
	"github.com/mhale/smtpd"
	"log"
	"net"
	"net/mail"
	"os"
	"os/exec"
	"os/signal"
	"sync"
	"syscall"
)

const serverId = "whmcs-inbound-piped"

var certFile string
var keyFile string
var bindTo string
var listenTo string
var hostname string
var phpBin string
var phpScript string
var wg sync.WaitGroup

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	if err == nil {
		return true
	}
	return false
}

func sigHandler() {
	c := make(chan os.Signal)

	signal.Notify(c, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-c
		fmt.Printf("- Gracefully shutting down -\n")
		wg.Wait()
		os.Exit(0)
	}()
}

func execScript(data []byte) {
	defer wg.Done()

	cmd := exec.Command(phpBin, phpScript)
	cmd.Stdin = bytes.NewReader(data)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		log.Print(err)
		log.Printf("%s\n", out.String())
	}
}

func mailHandler(origin net.Addr, from string, to []string, data []byte) error {
	msg, _ := mail.ReadMessage(bytes.NewReader(data))
	subject := msg.Header.Get("Subject")

	if listenTo != to[0] {
		log.Printf("Received mail from %s for %s with subject %s\n", from, to[0], subject)
		return nil
	} else {
		log.Printf("Accepting mail from %s for %s with subject %s\n", from, to[0], subject)
	}

	wg.Add(1)
	go execScript(data)

	return nil
}

func main() {

	certFile = getEnv("CERT_FILE", "")
	keyFile = getEnv("KEY_FILE", "")
	bindTo = getEnv("BIND_TO", "0.0.0.0:25")
	listenTo = getEnv("LISTEN_TO", "support@localhost")
	hostname = getEnv("HOSTNAME", "")
	phpBin = getEnv("PHP_BIN", "php")
	phpScript = getEnv("PHP_SCRIPT", "/home/whmcs/crons/pipe.php")

	sigHandler()

	if fileExists(certFile) && fileExists(keyFile) {
		smtpd.ListenAndServeTLS(
			bindTo,
			certFile,
			keyFile,
			mailHandler,
			serverId,
			hostname,
		)
	} else {
		smtpd.ListenAndServe(
			bindTo,
			mailHandler,
			serverId,
			hostname,
		)
	}
}
