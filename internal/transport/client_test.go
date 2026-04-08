package transport

import "testing"

func TestLastRouteIDKeepsMostRecentRoute(t *testing.T) {
	route := &lastRouteID{}

	route.Store(10)
	route.Store(22)

	got, ok := route.Load()
	if !ok {
		t.Fatal("expected stored route id")
	}
	if got != 22 {
		t.Fatalf("route id = %d, want 22", got)
	}
}
