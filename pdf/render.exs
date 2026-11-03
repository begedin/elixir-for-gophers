# Runs all cells of a Livebook notebook outside Livebook, and writes one
# HTML page with the code and the outputs. pdf/build.sh runs this script and
# prints the page to PDF with Chrome.
#
#     elixir --name notebook@127.0.0.1 --erl "-hidden" pdf/render.exs talk.livemd talk.html
#
# Run it from the folder of the notebook, so that asdf finds the tool versions.
# The "Many nodes" cells need a distributed node, so the script runs as a
# hidden node, like the Livebook runtime.

[notebook_arg, html_path] = System.argv()
notebook_path = Path.expand(notebook_arg)

defmodule NotebookPdf.Parser do
  @moduledoc false

  # Returns the blocks of a .livemd file in document order:
  #
  #   {:title, text}            the `#` heading
  #   {:section, title}         a `##` heading, one slide
  #   {:markdown, text}
  #   {:code, lang, source}     a code block in Markdown, which does not run
  #   {:cell, source, line}     an Elixir cell, and the line of its first line of code
  def parse(source) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> walk([], [], false)
  end

  defp walk([], md, acc, _force), do: Enum.reverse(flush(md, acc))

  defp walk([{line, n} | rest], md, acc, force) do
    cond do
      String.starts_with?(line, "```") ->
        lang = line |> String.trim_leading("`") |> String.trim()
        {body, rest} = Enum.split_while(rest, fn {l, _} -> String.trim_trailing(l) != "```" end)
        source = Enum.map_join(body, "\n", &elem(&1, 0))

        block =
          if lang == "elixir" and not force,
            do: {:cell, source, n + 1},
            else: {:code, lang, source}

        walk(Enum.drop(rest, 1), [], [block | flush(md, acc)], false)

      line =~ ~r/^<!-- livebook:.*"force_markdown":true/ ->
        walk(rest, md, acc, true)

      String.starts_with?(line, "<!-- livebook:") ->
        walk(rest, [], flush(md, acc), force)

      String.starts_with?(line, "## ") ->
        walk(rest, [], [{:section, String.trim_leading(line, "## ")} | flush(md, acc)], false)

      String.starts_with?(line, "# ") ->
        walk(rest, [], [{:title, String.trim_leading(line, "# ")} | flush(md, acc)], false)

      true ->
        walk(rest, [line | md], acc, force)
    end
  end

  defp flush(md, acc) do
    text = md |> Enum.reverse() |> Enum.join("\n") |> String.trim()
    if text == "", do: acc, else: [{:markdown, text} | acc]
  end
end

blocks = NotebookPdf.Parser.parse(File.read!(notebook_path))

# The setup cell calls Mix.install. Mix.install runs only once in a VM, so this
# script installs the same dependencies and its own, and then skips the call.
{:cell, setup_source, _} = Enum.find(blocks, &match?({:cell, _, _}, &1))

{:__block__, _, [{{:., _, [{:__aliases__, _, [:Mix]}, :install]}, _, [deps_ast | _]} | _]} =
  Code.string_to_quoted!(setup_source)

{notebook_deps, _} = Code.eval_quoted(deps_ast)
Mix.install(notebook_deps ++ [{:earmark, "~> 1.4"}, {:makeup_elixir, "~> 1.0"}])

defmodule NotebookPdf.LogCapture do
  @moduledoc false

  # A :logger handler. Livebook shows the log messages in the output of the
  # cell that runs, so this handler writes them to the output device of that cell.
  def log(event, %{formatter: {module, config}}) do
    if device = :persistent_term.get(__MODULE__, nil) do
      IO.write(device, module.format(event, config))
    end
  end
end

defmodule NotebookPdf.HTML do
  @moduledoc false

  def escape(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  def markdown(text), do: Earmark.as_html!(text, compact_output: true)

  def highlight("elixir", source),
    do: Makeup.highlight_inner_html(source, lexer: Makeup.Lexers.ElixirLexer)

  def highlight(lang, source) do
    case Makeup.Registry.fetch_lexer_by_name(lang) do
      {:ok, {lexer, opts}} ->
        Makeup.highlight_inner_html(source, lexer: lexer, lexer_options: opts)

      :error ->
        escape(source)
    end
  end

  def source(lang, label, source) do
    """
    <div class="source"><div class="tag">#{escape(label)}</div><pre class="highlight"><code>#{highlight(lang, source)}</code></pre></div>
    """
  end

  # Converts the ANSI colors of inspect and Logger to spans.
  def ansi(text) do
    ~r/\e\[([0-9;]*)m/
    |> Regex.split(text, include_captures: true)
    |> Enum.reduce({[], nil}, fn piece, {acc, class} ->
      case Regex.run(~r/\A\e\[([0-9;]*)m\z/, piece) do
        [_, code] -> {acc, ansi_class(code)}
        nil when class == nil -> {[escape(piece) | acc], class}
        nil -> {[~s(<span class="#{class}">#{escape(piece)}</span>) | acc], class}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  @ansi %{
    "31" => "ansi-red",
    "32" => "ansi-green",
    "33" => "ansi-yellow",
    "34" => "ansi-blue",
    "35" => "ansi-magenta",
    "36" => "ansi-cyan"
  }

  defp ansi_class(code), do: code |> String.split(";") |> Enum.find_value(&@ansi[&1])
end

defmodule NotebookPdf.Output do
  @moduledoc false
  import NotebookPdf.HTML

  @inspect_opts [
    pretty: true,
    width: 88,
    syntax_colors: [
      atom: :cyan,
      string: :green,
      charlist: :green,
      number: :yellow,
      boolean: :magenta,
      nil: :magenta,
      regex: :red,
      reset: :reset
    ]
  ]

  # Livebook shows a terminal box for most values. The same is true here.
  def render(%Kino.Text{terminal: true, text: text}), do: terminal(text)
  def render(%Kino.Text{text: text}), do: ~s(<p class="kino-text">#{escape(text)}</p>)

  def render(%Kino.Layout{type: :grid, items: items}),
    do: ~s(<div class="grid">#{Enum.map_join(items, &render/1)}</div>)

  def render(%Kino.JS{module: Kino.HTML} = kino) do
    # Livebook shows Kino.HTML in an iframe. The style of Slides.go_source is
    # for that iframe. This page has its own style for highlighted code.
    html = Regex.replace(~r/<style>.*?<\/style>/s, js_data(kino), "")
    ~s(<div class="html">#{html}</div>)
  end

  def render(%Kino.JS{module: Kino.Mermaid} = kino) do
    %{diagram: diagram} = js_data(kino)
    ~s(<div class="mermaid-box"><pre class="mermaid">#{escape(diagram)}</pre></div>)
  end

  def render(value), do: value |> inspect(@inspect_opts) |> terminal()

  def terminal(text), do: ~s(<pre class="terminal">#{ansi(String.trim_trailing(text))}</pre>)

  # Kino.JS keeps the data in a store process. Livebook asks for the data with
  # a :connect message when it shows the output. This function does the same.
  defp js_data(%Kino.JS{ref: ref}) do
    send(Kino.JS.DataStore, {:connect, self(), %{origin: self(), ref: ref}})

    receive do
      {:connect_reply, data, %{ref: ^ref}} -> data
    after
      5_000 -> raise "no data for the Kino.JS output #{ref}"
    end
  end
end

defmodule NotebookPdf.Evaluator do
  @moduledoc false

  # Evaluates a cell with the binding and the env of the cells before it, as
  # Livebook does. Returns the rendered outputs and the new state.
  def eval(source, line, state) do
    quoted =
      source |> Code.string_to_quoted!(file: state.env.file, line: line) |> drop_mix_install()

    {:ok, device} = StringIO.open("")
    group_leader = Process.group_leader()
    Process.group_leader(self(), device)
    :persistent_term.put(NotebookPdf.LogCapture, device)

    {result, diagnostics} =
      Code.with_diagnostics([log: false], fn ->
        try do
          {value, binding, env} = Code.eval_quoted_with_env(quoted, state.binding, state.env)

          {{:ok, value}, %{state | binding: binding, env: env}}
        catch
          kind, reason -> {{:error, Exception.format(kind, reason, __STACKTRACE__)}, state}
        end
      end)

    :persistent_term.erase(NotebookPdf.LogCapture)
    Process.group_leader(self(), group_leader)
    # Kino.start_child gives the group leader to its children, so the device stays open.
    {_, stdout} = StringIO.contents(device)

    {value, state} = result
    {%{kind: kind(quoted), stdout: stdout, diagnostics: diagnostics, value: value}, state}
  end

  defp drop_mix_install({:__block__, meta, exprs}) do
    {:__block__, meta,
     Enum.reject(exprs, &match?({{:., _, [{:__aliases__, _, [:Mix]}, :install]}, _, _}, &1))}
  end

  defp drop_mix_install(quoted), do: quoted

  # The Slides helpers show Go code and run Go programs.
  defp kind({{:., _, [{:__aliases__, _, [:Slides]}, :go_source]}, _, [path | _]}),
    do: {:go_source, path}

  defp kind({{:., _, [{:__aliases__, _, [:Slides]}, :go_run]}, _, [name | opts]}),
    do: {:go_run, name, opts == [[race: true]]}

  defp kind(_quoted), do: :code
end

defmodule NotebookPdf.Page do
  @moduledoc false
  import NotebookPdf.HTML
  alias NotebookPdf.Output

  def render(blocks, results, meta) do
    {title, preamble, sections} = structure(blocks)
    [cover | slides] = sections

    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <title>#{escape(title)}</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
    <style>#{meta.css}</style>
    </head>
    <body>
    <section class="cover">
      <div class="kicker">A Livebook notebook · #{escape(meta.file)}</div>
      <h2>#{escape(cover.title)}</h2>
      #{blocks_html(cover.blocks, results)}
      <p class="colophon">#{escape(meta.colophon)}</p>
    </section>
    <nav class="toc">
      <h2>Contents</h2>
      <ol>
        #{Enum.map_join(slides, "\n", &~s(<li value="#{&1.n}"><a href="##{&1.id}">#{escape(&1.title)}</a></li>))}
      </ol>
    </nav>
    <main>
    #{Enum.map_join(slides, "\n", &section_html(&1, results))}
    <section class="slide appendix" id="setup">
      <h2><span class="n">A</span>Appendix: the setup cell</h2>
      <p>The first cell of the notebook installs the dependencies and defines the <code>Slides</code> helpers. <code>Slides.go_source/2</code> shows the Go listings and <code>Slides.go_run/2</code> builds and runs the Go programs.</p>
      #{blocks_html(preamble, results)}
    </section>
    </main>
    <script src="https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js"></script>
    <script>
      mermaid.initialize({startOnLoad: false, theme: "neutral", fontFamily: "Inter, sans-serif"});
      mermaid.run().then(() => { document.body.dataset.ready = "true"; });
    </script>
    </body>
    </html>
    """
  end

  defp structure(blocks) do
    {[{:title, title} | preamble], rest} =
      Enum.split_while(blocks, &(not match?({:section, _}, &1)))

    sections =
      rest
      |> Enum.chunk_while(
        nil,
        fn
          {:section, t}, nil -> {:cont, %{title: t, blocks: []}}
          {:section, t}, s -> {:cont, finish(s), %{title: t, blocks: []}}
          block, s -> {:cont, %{s | blocks: [block | s.blocks]}}
        end,
        fn s -> {:cont, finish(s), nil} end
      )
      |> Enum.with_index(1)
      |> Enum.map(fn {s, n} -> Map.merge(s, %{n: n, id: "slide-#{n}"}) end)

    {title, preamble, sections}
  end

  defp finish(section), do: %{section | blocks: Enum.reverse(section.blocks)}

  defp section_html(section, results) do
    classes =
      cond do
        section.title == "Questions" -> "slide questions"
        String.starts_with?(section.title, "Backup:") -> "slide backup"
        true -> "slide"
      end

    heading = ~s(<h2><span class="n">#{section.n}</span>#{escape(section.title)}</h2>)

    """
    <section class="#{classes}" id="#{section.id}">
      #{blocks_html(section.blocks, results, heading)}
    </section>
    """
  end

  # Chrome does not always obey break-after: avoid. So the blocks that must
  # stay on one page go into one element with break-inside: avoid. These are
  # the heading and the first block, and a lead-in paragraph and its cell.
  defp blocks_html(blocks, results, heading \\ nil) do
    units = Enum.map(units(blocks), fn unit -> Enum.map(unit, &block_html(&1, results)) end)

    units =
      case {heading, units} do
        {nil, units} -> units
        {heading, []} -> [[heading]]
        {heading, [first | rest]} -> [[heading | first] | rest]
      end

    Enum.map_join(units, "\n", fn
      [html] -> html
      htmls -> ~s(<div class="keep">#{Enum.join(htmls, "\n")}</div>)
    end)
  end

  defp units([{:markdown, text}, {kind, _, _} = next | rest]) when kind in [:cell, :code] do
    case split_lead(text) do
      {"", lead} -> [[{:markdown, lead}, next] | units(rest)]
      {before, lead} -> [[{:markdown, before}], [{:markdown, lead}, next] | units(rest)]
      nil -> [[{:markdown, text}] | units([next | rest])]
    end
  end

  defp units([block | rest]), do: [[block] | units(rest)]
  defp units([]), do: []

  # Returns the last paragraph of the Markdown, if it is not a list, a table or a heading.
  defp split_lead(text) do
    paragraphs = String.split(text, ~r/\n\s*\n/)
    lead = List.last(paragraphs)

    unless lead =~ ~r/\A(\* |- |\||\d+\. |#)/ do
      {paragraphs |> Enum.drop(-1) |> Enum.join("\n\n"), lead}
    end
  end

  defp block_html({:markdown, text}, _results), do: ~s(<div class="md">#{markdown(text)}</div>)

  defp block_html({:code, lang, source}, _results),
    do: ~s(<div class="cell static">#{source(lang, lang_label(lang), source)}</div>)

  defp block_html({:cell, _source, line} = cell, results),
    do: cell_html(cell, Map.fetch!(results, line))

  defp cell_html({:cell, _source, _line}, %{kind: {:go_source, path}} = result) do
    {:ok, kino} = result.value
    html = Output.render(kino)

    ~s(<div class="cell go"><div class="source"><div class="tag">Go · #{escape(path)}</div>#{html}</div></div>)
  end

  defp cell_html({:cell, _source, _line}, %{kind: {:go_run, name, race}} = result) do
    {:ok, kino} = result.value
    command = "go run#{if race, do: " -race"} ./go/#{name}"

    """
    <div class="cell go-run">
      <div class="output"><div class="tag">$ #{escape(command)}</div>#{Output.render(kino)}</div>
    </div>
    """
  end

  defp cell_html({:cell, source, _line}, result) do
    outputs =
      [
        stdout_html(result.stdout),
        Enum.map(result.diagnostics, &diagnostic_html/1),
        value_html(result.value)
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    """
    <div class="cell">
      #{source("elixir", "Elixir", source)}
      #{Enum.join(outputs, "\n")}
    </div>
    """
  end

  # A module definition returns {:module, ...}. Livebook shows it, but it is noise on paper.
  defp value_html({:ok, {:module, _, _, _}}), do: nil
  defp value_html({:ok, value}), do: ~s(<div class="output value">#{Output.render(value)}</div>)

  defp value_html({:error, message}), do: tagged_output("error", "Error", message)

  defp stdout_html(""), do: nil
  defp stdout_html(stdout), do: tagged_output("stdout", "Standard output", stdout)

  defp tagged_output(class, tag, text) do
    ~s(<div class="output #{class}"><div class="tag">#{tag}</div>#{Output.terminal(text)}</div>)
  end

  defp diagnostic_html(diagnostic) do
    line =
      case diagnostic.position do
        {line, _column} -> line
        line -> line
      end

    """
    <div class="output diagnostic #{diagnostic.severity}">
      <div class="tag">#{diagnostic.severity} · #{escape(Path.basename(diagnostic.file || ""))}:#{line}</div>
      <pre>#{escape(diagnostic.message)}</pre>
    </div>
    """
  end

  defp lang_label("elixir"), do: "Elixir"
  defp lang_label("bash"), do: "Shell"
  defp lang_label(lang), do: lang
end

# Livebook shows log messages in the cell output, and not in the terminal.
:logger.remove_handler(:default)

:ok =
  :logger.add_handler(:notebook_pdf, NotebookPdf.LogCapture, %{
    formatter: Logger.default_formatter(format: "\n[$level] $message\n", colors: [enabled: true])
  })

state = %{binding: [], env: Code.env_for_eval(file: notebook_path)}

{results, _state} =
  for {:cell, source, line} <- blocks, reduce: {%{}, state} do
    {results, state} ->
      IO.puts(:stderr, "Evaluating the cell at line #{line}")
      {result, state} = NotebookPdf.Evaluator.eval(source, line, state)
      {Map.put(results, line, result), state}
  end

{go_version, 0} = System.cmd("go", ["env", "GOVERSION"])

colophon =
  "All cells in this document ran on #{Calendar.strftime(Date.utc_today(), "%-d %B %Y")}, " <>
    "with Elixir #{System.version()}, Erlang/OTP #{System.otp_release()} and Go #{String.trim_leading(String.trim(go_version), "go")}. " <>
    "The outputs come from that run. PIDs, times and node names are different in each run. " <>
    "The notebook ran outside Livebook, as the hidden node #{node()}. Thus no Livebook server node shows in the node lists."

html =
  NotebookPdf.Page.render(blocks, results, %{
    file: Path.basename(notebook_path),
    colophon: colophon,
    css: File.read!(Path.join(__DIR__, "style.css"))
  })

File.write!(html_path, html)
IO.puts(:stderr, "Wrote #{html_path}")
