# Livebook slides bookmarklet

A bookmarklet that turns a Livebook notebook into a slideshow. This repository uses it to present [talk.livemd](../talk.livemd), but it works with any notebook.

## Why it is necessary

Livebook has no slideshow mode:

* In the usual view, the notebook is one long page.
* The **Presentation** view hides the sidebar, but it shows only the block (cell) with the focus. All other blocks are dim, also the blocks of the same slide.

A slide usually has more than one block: text, code and output. The bookmarklet shows one `##` section at a time, with all its blocks. The section heading is the slide title.

## What it does

* It shows only the current section, at full brightness, with a larger title.
* It hides the notebook header, the setup cell, the sidebar, the insert buttons and the other sections.
* It shows a slide counter, for example `5 / 21`, at the bottom right.
* It adds keys to move between slides.
* It changes nothing in the notebook. To stop the slideshow, click the bookmark again or reload the page.

## Files

| File | Contents |
| --- | --- |
| [livebook-slides.js](livebook-slides.js) | The script, with comments. Edit this file. |
| [bookmarklet.txt](bookmarklet.txt) | The same script as a `javascript:` URL. Paste it into a bookmark. |
| [build_bookmarklet.exs](build_bookmarklet.exs) | Builds `bookmarklet.txt` from `livebook-slides.js`. |

## Install

Do this one time for each browser:

1. Open [bookmarklet.txt](bookmarklet.txt) and copy all its text. The text starts with `javascript:`.
2. In your browser, add a new bookmark, for example "Livebook slides".
3. Paste the text as the URL of the bookmark.

## Use

1. Open the notebook in Livebook and run the cells that you want to show.
2. Put the focus on the slide where you want to start, or scroll to it.
3. Click the bookmark. The slideshow starts at the section with the focus. If no section has the focus, it starts at the first section in the window.
4. Move between slides with these keys:

   | Key | Action |
   | --- | --- |
   | `PageDown` or `→` | Next slide |
   | `PageUp` or `←` | Previous slide |
   | `Home` | First slide |
   | `End` | Last slide |

   Most presentation clickers send `PageDown` and `PageUp`. The keys do not change the slide while you type in a cell or an input.
5. Click the bookmark again to stop the slideshow.

You can run cells during the slideshow. Click into a cell and press `Cmd+Enter`, or use the Evaluate button of the cell.

## How it works

The script adds two `<style>` elements and a key handler to the Livebook page:

* One style hides the controls of Livebook.
* The other style shows only the section with the current `data-section-id`, and hides all other sections.

Livebook renders a section again when one of its cells runs. This removes classes and attributes that a script adds to the elements of Livebook. That is why the script changes only its own style elements.

## Limits

* The script uses internal HTML attributes of Livebook 0.19, for example `data-el-section` and `data-section-id`. A new Livebook version can change them and break the script.
* In the slideshow, the Livebook keys `j` and `k` move only inside the current slide.
* A slide that is taller than the window needs scrolling.

## Change the script

After a change to `livebook-slides.js`, build the bookmarklet again from the repository root:

```bash
elixir slides/build_bookmarklet.exs
```

Then copy the new text from `bookmarklet.txt` into your bookmark. A bookmark keeps the old script until you replace its URL.
