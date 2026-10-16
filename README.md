# Elixir for Gophers: Same Problems, Different Solutions

This repository contains the code examples for the talk "Elixir for Gophers: Same Problems, Different Solutions".

## Run the slides

The slides are a Livebook notebook: [talk.livemd](talk.livemd). Each section (`##` heading) is one slide. In Livebook, the notebook reads as one page. The slideshow bookmarklet shows one slide at a time (see [Present the slides](#present-the-slides)).

1. Install Erlang 28.3, Elixir 1.20.4 and Go 1.27.2 from `.tool-versions` with asdf:

   ```bash
   asdf install
   ```

2. Install Livebook with the same Elixir version. The type-checker slide needs Elixir 1.20:

   ```bash
   mix escript.install hex livebook
   asdf reshim elixir
   ```

3. In the repository folder, start Livebook with the notebook:

   ```bash
   livebook server "$PWD/talk.livemd"
   ```

Start Livebook from a terminal in this folder. The cells run `go`, and asdf finds the Go version from `.tool-versions` in this folder. Livebook Desktop may not find `go`.

## Code

* `go/<name>/main.go`: Go programs that the slides build and run, for example `go/fanout` and `go/port`.
* `go/snippets/*.go`: Go code that the slides only show. The `//go:build ignore` line keeps these files out of the build.
* `slides/`: a bookmarklet that shows a Livebook notebook as a slideshow. See [slides/README.md](slides/README.md).

## Present the slides

Livebook has no slideshow mode, so this repository has a bookmarklet for it. The bookmarklet shows one `##` section at a time, with all its blocks. [slides/README.md](slides/README.md) tells what it does, how to install it and which keys move between slides.

For this talk:

1. Run all cells before the talk. The first run of the setup cell downloads and compiles the dependencies.
2. Click the bookmark in the Livebook tab, then use `PageDown` and `PageUp` (or a presentation clicker) to move between slides.
3. To run a cell during the talk, click into it and press `Cmd+Enter`.
4. Zoom the browser (`Cmd +`) to make the text larger for the room.

Some slides depend on earlier slides. "Look inside a running system" reads the workers from "Let it crash, with a supervisor". "Use both: Ports" uses the `Slides` helpers from the setup cell.
