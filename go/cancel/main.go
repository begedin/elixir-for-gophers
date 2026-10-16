// Command cancel shows that a goroutine stops only when it checks
// its context. Here, work never checks ctx, so cancel has no effect.
package main

import (
	"context"
	"fmt"
	"time"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	go work(ctx)

	time.Sleep(250 * time.Millisecond)
	cancel()
	fmt.Println("main: cancel()")

	time.Sleep(250 * time.Millisecond)
	fmt.Println("main: done")
}

// work ignores ctx. In a server, this goroutine leaks.
func work(ctx context.Context) {
	for step := 1; ; step++ {
		fmt.Println("work: step", step)
		time.Sleep(100 * time.Millisecond)
	}
}
