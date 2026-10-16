# Content ideas

Ideas for the talk "Elixir for Gophers: Same Problems, Different Solutions".

## The core idea

The talk can come back to one sentence many times: **Go shares memory between goroutines. The BEAM isolates every process.** Most differences come from this one design choice:

- **Identity:** A goroutine has no identity, so you send to a channel. An Elixir process has a PID, so you send the message to the process itself.
- **Isolation:** Each BEAM process has its own heap and its own garbage collection. A crash or a memory limit stops one process, not the whole program.
- **No shared memory:** Messages between processes are copied. This prevents data races. Logic race conditions are still possible.

## Structure (30–40 minutes)

1. **Opening (3 min):** Show what Gophers and Elixir developers already agree on. Both languages are small and use errors as values. Both have one formatter and a built-in test tool. Both prefer composition and have no classes.
2. **The core idea (5 min):** Shared memory compared with isolated processes.
3. **Five or six problems (4–5 min each):** Show the Go solution first, then the Elixir solution.
4. **Where Go is the better tool (3 min):** Be honest here. This earns trust from the audience.
5. **Close (3 min):** Use both languages together.

## A running example

Use one app for the whole talk, for example a **link checker**. It reads a list of URLs, checks each link and shows the progress live. Each problem adds one feature to the same app. The audience sees one system grow in two languages.

## Problem map

| # | Problem | Go | Elixir | Demo |
|---|---|---|---|---|
| 1 | Do work concurrently with a limit | Goroutines, `sync.WaitGroup.Go` (Go 1.25), `errgroup.SetLimit` | `Task.async_stream/3` with `max_concurrency` | Check 100 links, 10 at a time |
| 2 | Cancellation and timeouts | `context.Context` goes into every function. The code must check `ctx.Done()` | No context argument. Stop the process from outside: `Task.shutdown/2`, links, `GenServer.call` timeout | A slow check ignores `ctx` and continues in Go. In Elixir, the task stops |
| 3 | Expected errors | `if err != nil`, `errors.Is`, `%w` | `{:ok, v}` / `{:error, reason}` and `with` | A "same problem, same solution" slide |
| 4 | Unexpected failures | `panic` / `recover`. A panic in a goroutine that you start stops the whole program | "Let it crash." The supervisor starts the process again | One bad link stops the Go program. In Elixir, one worker restarts |
| 5 | Shared state | `sync.Mutex`, `sync.Map`, `atomic`, `go test -race` | State in a process (`GenServer`, `Agent`), or ETS for concurrent reads | A cache of checked links |
| 6 | Jobs and back-pressure | Worker pool on a buffered channel. River (Postgres queue) | `Task.Supervisor`, GenStage or Broadway. Oban (Postgres queue) | River and Oban use the same design: Postgres, with the job added in the same transaction |
| 7 | Real-time updates | WebSocket library and a hub goroutine. Redis or NATS for more than one server | Phoenix.PubSub with Channels or LiveView. It works across a cluster | Live progress bar in the browser |
| 8 | Talk to other machines | gRPC, NATS, HTTP | Distributed Erlang: `Node.connect/1`, send to a remote PID, `:pg` | Two `iex` nodes on one laptop |
| 9 | Graceful shutdown | `signal.NotifyContext`, `http.Server.Shutdown`, wait for the workers | Supervisors stop children in reverse start order, with a timeout for each child | Press Ctrl-C during a check |
| 10 | Test concurrent code | `testing/synctest` (stable in Go 1.25, `synctest.Sleep` in Go 1.27) with virtual time | ExUnit `async: true`, `assert_receive`, Ecto SQL sandbox | Test a retry with backoff |
| 11 | Debug in production | pprof, trace flight recorder (Go 1.25), goroutine leak profile (Go 1.27) | Remote shell into the running release, `:observer`, `:sys.get_state/1`, LiveDashboard | Connect to a running node and read the state of one process |

Demo 4 needs one note: `net/http` recovers a panic in a handler. Use a goroutine that the handler starts to show the crash.

Demo 11 can be the strongest moment for Gophers. Go has no equivalent of a live shell inside a production process.

## Topics for single slides (no demo)

- **Polymorphism:** Go uses implicit interfaces. Elixir uses protocols, which dispatch on the data type, and behaviours, which are contracts for a module. `GenServer` is a behaviour.
- **Types:** Elixir v1.20 (June 2026) is gradually typed. It infers types without annotations. At compile time it reports dead code and type errors. This answers the most frequent objection from Gophers. Go 1.27 adds generic methods.
- **Control flow:** Show pattern matching in function heads, `|>` and `with` next to a chain of `if err != nil`.
- **Tooling map:**
  - `go fmt` ↔ `mix format`
  - `go test` ↔ `mix test`
  - `go doc` ↔ `h/1` in IEx and ExDoc
  - `go mod` ↔ Mix and Hex
- **Deployment:** Go builds one static binary and cross-compiles. `mix release` includes the runtime, but you must build it for the target OS and CPU, usually in Docker. Go is better here. Say so.

## Where Go is the better tool, and the close

- **Go is better for:** CPU-heavy work, low memory use, CLIs and Kubernetes operators.
- **Elixir is better for:** many long-lived connections, soft real-time systems and systems that must stay up when parts fail.
- **Closing demo:** Elixir calls a Go binary through a Port. Go does the CPU work. The Elixir supervisor restarts the Go program when it crashes. A recap of Veronica Lopez's 2017 ElixirConf talk "My Journey from Go to Elixir" gives the same conclusion: the two languages can be in the same app.

## Typical Go and Elixir projects

The web backend is where the two languages **overlap**, not where they differ.

### What the surveys say

- **Go:** In the 2025 Go Developer Survey, the top two project types are CLIs (74%) and API/RPC services (73%). 55% of respondents build both. More than one third build cloud infrastructure tools.
- **Elixir:** A 2025 Elixir community survey reports that 97% of respondents use Phoenix and 86% use LiveView. We found only a forum summary of this survey. It does not name the organiser or the number of respondents, so use these numbers with care.

So Go has two main homes: web services and infrastructure tools. Elixir has one main home: web applications. "Web application" is more exact than "backend service". With LiveView, the server also renders the UI, so one Elixir project is often the whole product.

### The real difference: the shape of the backend

Both languages build web backends, but the typical project has a different shape.

**A typical Go backend:**
- It is one small, stateless service among many.
- State and coordination are outside the service: Postgres, Redis, a message broker, a job queue.
- Kubernetes restarts the service, scales it and connects it to the other services.

**A typical Elixir backend:**
- It is one larger application, often a monolith.
- It contains the web layer, background jobs, cache, pub/sub, scheduled tasks and WebSockets.
- It has fewer external parts. Long-lived processes keep state. Supervisors restart the parts that fail.

This matches the talk title. Both languages have the same problems: restart failed parts, keep state, run jobs, send updates. Go puts the solutions in the infrastructure. Elixir puts them in the runtime.

**Slide idea:** Show two architecture diagrams side by side. The Go diagram has many boxes. In the Elixir diagram, most of those boxes are inside one BEAM node.

Saša Jurić's book *Elixir in Action* may support this slide. From memory, chapter 1 has a table that compares two real web servers. One server used Nginx, Rails, Go, Redis, MongoDB, cron and Upstart. The other server used only Erlang. If this is correct, Go is in that table as the tool for long-running requests, which is a good detail for this audience. We could not open the book to check the table, so check it before you put it on a slide.

### Niches for each language

- **Go:** CLIs, Kubernetes operators, proxies, databases and DevOps tools. Kubernetes, Docker, Terraform and Prometheus are written in Go. Elixir is a poor fit for CLIs. A release needs the BEAM runtime, and it starts more slowly than a Go binary.
- **Elixir:** Real-time systems with many connections (for example, Discord chat), embedded devices (Nerves), media streaming (Membrane), data pipelines (Broadway), and notebooks and ML (Livebook, Nx). These niches are small compared with the web.

### Who chooses each language

This part is opinion, not data:

- Platform and infrastructure teams in large companies often choose Go.
- Small product teams that want one codebase and few moving parts often choose Elixir.

Two stories agree with this:
- Veronica Lopez finished a side project in Phoenix. The Go version of the same project was never finished.
- A solo developer moved a backend from Go to Phoenix to remove tooling and boilerplate.

### A real example

The `go-backend` repository seems to be an Elixir web backend, because the `call-tree` skill works on its Elixir modules. If it is possible to share it, a short story about its shape would be stronger than any survey. An Elixir codebase called `go-backend` may also get a laugh from a room of Gophers.

## Facts to check (many old blog posts are now wrong)

- **"Go scheduling is cooperative."** This is not true since Go 1.14 (2020), which added asynchronous preemption. The real difference: the BEAM counts work units (reductions) for each process, and each process has its own garbage collection.
- **"A process uses 0.5 KB and a goroutine uses 2 KB."** The current Erlang efficiency guide gives 327 words for a new process, about 2.6 KB on 64-bit. A goroutine starts with a 2 KB stack. Say "both cost a few KB".
- **"Elixir has no static checks."** This is not true since v1.17–v1.20.
- **"Use Distillery for releases."** Use `mix release`, which is part of Elixir since v1.9.
- **River and Oban:** We could not confirm that Oban inspired River. The River announcement does not mention Oban. Say "same design", not "inspired by".
- **Go 1.27:** Go 1.27 is released. On 19 October 2026, the download page listed Go 1.27.2.

## Repo layout

```
01-fan-out/
  go/          # go run .
  elixir/      # elixir fan_out.exs
02-cancellation/
  ...
```

For the Elixir side, use single `.exs` files with `Mix.install/1`. Each demo is then one file and needs no project setup on stage.

## Sources

- [Elixir concepts for Go developers (Texlution, 2015)](https://texlution.com/post/elixir-concepts-for-golang-developers/)
- [Comparing Elixir and Go (CloudBees, 2017)](https://www.cloudbees.com/blog/comparing-elixir-go)
- [ElixirConf 2017: My Journey from Go to Elixir, Veronica Lopez](https://elixirforum.com/t/2-elixirconf-2017-my-journey-from-go-to-elixir-veronica-lopez/8627)
- [ElixirConf 2017 recap, day three](https://mattr.info/2017/09/07/elixirconf-day-three.html)
- [Elixir Forum: Elixir vs Go](https://elixirforum.com/t/elixir-vs-go/3422)
- [StackShare: Elixir vs Go](https://stackshare.io/stackups/elixir-vs-go)
- [Elixir v1.19 release](https://elixir-lang.org/blog/2025/10/16/elixir-v1-19-0-released/)
- [Elixir v1.20 release](https://elixir-lang.org/blog/2026/06/03/elixir-v1-20-0-released)
- [Go 1.25 release notes](https://go.dev/doc/go1.25)
- [Go 1.26 release notes](https://go.dev/doc/go1.26)
- [Go 1.27 release notes](https://go.dev/doc/go1.27)
- [Go 1.14 asynchronous preemption](https://pages.goframe.org/en/release/golang/go1.14)
- [River: a Fast, Robust Job Queue for Go + Postgres](https://brandur.org/river)
- [Erlang efficiency guide: processes](https://www.erlang.org/doc/system/eff_guide_processes.md)
- [Results from the 2025 Go Developer Survey](https://go.dev/blog/survey2025)
- [Ash Framework is the 4th Most-Used Elixir Framework (2025 Survey)](https://elixirforum.com/t/ash-framework-is-the-4th-most-used-elixir-framework-2025-survey/73580)
- [Stack Overflow Developer Survey 2025 (Elixir Forum thread)](https://elixirforum.com/t/stack-overflow-developer-survey-2025/71073)
- [Elixir in Action (Manning)](https://manning.com/books/elixir-in-action)
- [Why I migrated my backend from Go to Elixir/Phoenix (DEV)](https://dev.to/asyncnavi/the-solo-developers-choice-why-i-migrated-my-backend-from-go-to-elixirphoenix-3jf7)
