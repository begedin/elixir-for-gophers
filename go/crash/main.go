// Command crash shows that a panic in one goroutine stops the whole
// program, with all its other goroutines.
package main

import (
	"fmt"
	"time"
)

func main() {
	for id := 1; id <= 3; id++ {
		go worker(id)
	}

	time.Sleep(time.Second)
	fmt.Println("main: still running") // never printed
}

func worker(id int) {
	time.Sleep(time.Duration(id) * 100 * time.Millisecond)
	if id == 2 {
		var counts map[string]int
		counts["boom"]++ // panic: assignment to entry in nil map
	}
	fmt.Println("worker", id, "done")
}
