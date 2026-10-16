// Command counter increments two counters from many goroutines at the
// same time. A mutex protects the first counter. Nothing protects the
// second counter, so some of its increments can get lost.
//
// Build it with -race to see the race detector find the missing lock.
package main

import (
	"fmt"
	"sync"
)

const (
	callers    = 100
	increments = 1_000
)

// Counter is safe for concurrent use. The mutex protects n.
type Counter struct {
	mu sync.Mutex
	n  int
}

func (c *Counter) Increment() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.n++
}

func main() {
	var safe Counter
	run(safe.Increment)

	unsafe := 0
	run(func() { unsafe++ }) // no lock: a data race

	fmt.Println("expected:     ", callers*increments)
	fmt.Println("with mutex:   ", safe.n)
	fmt.Println("without mutex:", unsafe)
}

// run calls increment from many goroutines at the same time.
func run(increment func()) {
	var wg sync.WaitGroup
	for range callers {
		wg.Go(func() {
			for range increments {
				increment()
			}
		})
	}
	wg.Wait()
}
