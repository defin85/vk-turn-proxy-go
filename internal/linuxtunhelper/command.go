package linuxtunhelper

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
)

const (
	exitOK             = 0
	exitUsage          = 2
	exitInvalidRequest = 3
	exitNotImplemented = 4
	exitNativeFailure  = 5
)

var (
	startNativeAttempt   = defaultStartNativeAttempt
	statusNativeAttempt  = defaultStatusNativeAttempt
	cleanupNativeAttempt = defaultCleanupNativeAttempt
)

func Run(stdin io.Reader, stdout io.Writer, stderr io.Writer, args []string) int {
	flags := flag.NewFlagSet(HelperIdentity, flag.ContinueOnError)
	flags.SetOutput(stderr)
	if err := flags.Parse(args); err != nil {
		writeResponse(stdout, errorResponse("usage", err))
		return exitUsage
	}
	remaining := flags.Args()
	if len(remaining) != 1 {
		err := fmt.Errorf("expected exactly one command: start, status, or cleanup")
		writeResponse(stdout, errorResponse("usage", err))
		return exitUsage
	}
	switch Command(remaining[0]) {
	case CommandStart:
		return runStart(stdin, stdout)
	case CommandStatus:
		return runAttemptCommand(stdin, stdout, CommandStatus)
	case CommandCleanup:
		return runAttemptCommand(stdin, stdout, CommandCleanup)
	default:
		writeResponse(stdout, errorResponse("usage", fmt.Errorf("unknown command")))
		return exitUsage
	}
}

func runStart(stdin io.Reader, stdout io.Writer) int {
	var req StartRequest
	if err := decodeStrict(stdin, &req); err != nil {
		writeResponse(stdout, errorResponse("invalid_request", err))
		return exitInvalidRequest
	}
	if err := req.validate(); err != nil {
		writeResponse(stdout, errorResponse("invalid_request", err, req.diagnosticSecrets()...))
		return exitInvalidRequest
	}
	return startNativeAttempt(stdout, req)
}

func runAttemptCommand(stdin io.Reader, stdout io.Writer, command Command) int {
	var req AttemptRequest
	if err := decodeStrict(stdin, &req); err != nil {
		writeResponse(stdout, errorResponse("invalid_request", err))
		return exitInvalidRequest
	}
	if err := req.validate(); err != nil {
		writeResponse(stdout, errorResponse("invalid_request", err, req.diagnosticSecrets()...))
		return exitInvalidRequest
	}
	switch command {
	case CommandStatus:
		return statusNativeAttempt(stdout, req)
	case CommandCleanup:
		return cleanupNativeAttempt(stdout, req)
	default:
		writeResponse(stdout, errorResponse("usage", fmt.Errorf("unknown command"), req.diagnosticSecrets()...))
		return exitUsage
	}
}

func decodeStrict(r io.Reader, target any) error {
	body, err := io.ReadAll(io.LimitReader(r, maxRequestBodyBytes+1))
	if err != nil {
		return err
	}
	if len(body) > maxRequestBodyBytes {
		return fmt.Errorf("request exceeds %d bytes", maxRequestBodyBytes)
	}
	decoder := json.NewDecoder(bytes.NewReader(body))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	var extra struct{}
	if err := decoder.Decode(&extra); err != io.EOF {
		return fmt.Errorf("request contains extra JSON values")
	}
	return nil
}

func writeResponse(w io.Writer, response Response) {
	encoder := json.NewEncoder(w)
	_ = encoder.Encode(response)
}
