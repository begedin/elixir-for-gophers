// Command channels sends a ping to a goroutine and prints its reply.
// A goroutine has no address, so the two goroutines share a channel.
package main

import "fmt"

func main() {
	ping := make(chan chan string)

	go func() {
		reply := <-ping
		reply <- "pong"
	}()

	reply := make(chan string)
	ping <- reply
	fmt.Println(<-reply)
}
