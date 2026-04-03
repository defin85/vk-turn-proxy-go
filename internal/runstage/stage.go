package runstage

import (
	"errors"
	"fmt"
)

type Stage string

const (
	PolicyValidate  Stage = "policy_validate"
	ProviderResolve Stage = "provider_resolve"
	LocalBind       Stage = "local_bind"
	TURNDial        Stage = "turn_dial"
	TURNAllocate    Stage = "turn_allocate"
	DTLSHandshake   Stage = "dtls_handshake"
	ForwardingLoop  Stage = "forwarding_loop"
)

type Error struct {
	Stage Stage
	Err   error
}

func (e *Error) Error() string {
	if e == nil {
		return "<nil>"
	}
	if e.Err == nil {
		return fmt.Sprintf("stage %s failed", e.Stage)
	}

	return fmt.Sprintf("stage %s failed: %v", e.Stage, e.Err)
}

func (e *Error) Unwrap() error {
	if e == nil {
		return nil
	}

	return e.Err
}

func Wrap(stage Stage, err error) error {
	if err == nil {
		return nil
	}

	var stageErr *Error
	if errors.As(err, &stageErr) {
		return err
	}

	return &Error{
		Stage: stage,
		Err:   err,
	}
}

func FromError(err error) (Stage, bool) {
	var stageErr *Error
	if !errors.As(err, &stageErr) || stageErr == nil {
		return "", false
	}

	return stageErr.Stage, true
}
