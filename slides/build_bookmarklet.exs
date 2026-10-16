# Builds slides/bookmarklet.txt from slides/livebook-slides.js.
#
#     elixir slides/build_bookmarklet.exs
#
# The bookmarklet is the script as a "javascript:" URL. The script is
# percent-encoded, so its comments and line breaks stay valid.
source = File.read!(Path.join(__DIR__, "livebook-slides.js"))
bookmarklet = "javascript:" <> URI.encode(source, &URI.char_unreserved?/1)

File.write!(Path.join(__DIR__, "bookmarklet.txt"), bookmarklet <> "\n")
IO.puts("Wrote slides/bookmarklet.txt (#{byte_size(bookmarklet)} bytes)")
