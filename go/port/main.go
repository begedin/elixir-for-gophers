// Command port counts prime numbers for an Elixir Port.
//
// For each number n, it writes the count of primes below n to stdout,
// on one line. With arguments, it reads the numbers from the arguments
// and stops. Without arguments, it reads one number per line from stdin.
// When stdin closes, the program stops.
package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

func main() {
	if len(os.Args) > 1 {
		for _, arg := range os.Args[1:] {
			printCount(arg)
		}
		return
	}

	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		printCount(scanner.Text())
	}
}

// printCount reads text as a number n and prints the count of primes below n.
func printCount(text string) {
	n, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil {
		fmt.Println("error:", err)
		return
	}
	fmt.Println(countPrimes(n))
}

// countPrimes returns the number of primes below n.
// It uses the sieve of Eratosthenes.
func countPrimes(n int) int {
	if n < 3 {
		return 0
	}
	composite := make([]bool, n)
	count := 0
	for i := 2; i < n; i++ {
		if composite[i] {
			continue
		}
		count++
		for j := i * i; j < n; j += i {
			composite[j] = true
		}
	}
	return count
}
