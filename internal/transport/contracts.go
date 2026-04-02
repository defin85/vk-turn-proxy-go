package transport

import "context"

type Runner interface {
	Run(context.Context) error
}
