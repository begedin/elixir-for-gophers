// Command goroutines starts 100,000 goroutines that wait on a channel.
// It prints the time to start them and the memory for each goroutine.
package main

import (
	"fmt"
	"runtime"
	"sync"
	"time"
)

const count = 100_000

func main() {
	var before, after runtime.MemStats
	runtime.GC()
	runtime.ReadMemStats(&before)

	stop := make(chan struct{})
	var wg sync.WaitGroup

	start := time.Now()
	for range count {
		wg.Go(func() { <-stop })
	}
	elapsed := time.Since(start)

	runtime.ReadMemStats(&after)
	used := inUse(after) - inUse(before)

	close(stop)
	wg.Wait()

	fmt.Printf("goroutines: %d\n", count)
	fmt.Printf("time: %d ms\n", elapsed.Milliseconds())
	fmt.Printf("bytes per goroutine: %d\n", used/count)
}

// inUse returns the bytes that goroutine stacks and the heap use.
func inUse(m runtime.MemStats) uint64 {
	return m.StackInuse + m.HeapInuse
}
