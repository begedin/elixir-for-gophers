// Command fanout checks 100 fake links, 10 at a time.
//
// Each check takes a random time. One link in ten hangs. A timeout
// of 500 ms stops the wait for a slow link.
package main

import (
	"context"
	"fmt"
	"math/rand/v2"
	"sync"
	"sync/atomic"
	"time"
)

func main() {
	start := time.Now()
	limit := make(chan struct{}, 10) // at most 10 checks at a time
	var wg sync.WaitGroup
	var ok, timeout atomic.Int64

	for link := range 100 {
		wg.Go(func() {
			limit <- struct{}{}
			defer func() { <-limit }()

			ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
			defer cancel()

			if err := check(ctx, link); err != nil {
				timeout.Add(1)
				return
			}
			ok.Add(1)
		})
	}
	wg.Wait()

	fmt.Printf("ok: %d, timeout: %d, time: %d ms\n",
		ok.Load(), timeout.Load(), time.Since(start).Milliseconds())
}

// check simulates one link check. It must watch ctx to stop early.
func check(ctx context.Context, link int) error {
	latency := time.Duration(rand.IntN(200)) * time.Millisecond
	if link%10 == 0 {
		latency = time.Hour // this link hangs
	}

	select {
	case <-time.After(latency):
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}
