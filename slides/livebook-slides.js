// Livebook slides: shows one notebook section at a time.
//
// Each "##" section is one slide, and the section heading is the slide
// title. Run the script one time to start the slide mode. Run it again
// to stop the slide mode.
//
// Keys in the slide mode:
//   PageDown, ArrowRight: next slide
//   PageUp, ArrowLeft:    previous slide
//   Home, End:            first and last slide
//
// The keys do not change the slide while a cell editor or an input has
// the focus. Most presentation clickers send PageDown and PageUp.
//
// The script uses the internal HTML attributes of Livebook 0.19
// (data-el-section and similar). A new Livebook version can change them.
(() => {
  const STATE = "__livebookSlides";

  // A second run stops the slide mode.
  if (window[STATE]) {
    window[STATE].stop();
    return;
  }

  // Livebook renders its elements again when a cell runs, and this
  // removes classes and attributes that a script adds to them. So the
  // script changes only its own style elements, and the slide style
  // selects the current section by its data-section-id.
  const baseStyle = document.createElement("style");
  baseStyle.textContent = `
    /* Hide the notebook header, the setup cell and the controls */
    [data-el-notebook-content] > :not([data-el-sections-container]),
    [data-el-sidebar],
    [data-el-side-panel],
    [data-el-toggle-sidebar],
    [data-el-section-actions],
    [data-el-insert-buttons],
    [data-el-views],
    [data-el-notebook-indicators] {
      display: none !important;
    }

    /* Show the outputs also when a Livebook view dims them */
    [data-el-js-view-iframes] iframe {
      opacity: 1 !important;
    }

    [data-el-sections-container] {
      margin-top: 0 !important;
    }

    /* Space above the slide title */
    [data-el-sections-container] > [data-el-section] {
      padding-top: 3rem;
    }

    .lbs-counter {
      position: fixed;
      right: 16px;
      bottom: 12px;
      z-index: 100;
      color: #9ca3af;
      font: 500 14px/1 system-ui, sans-serif;
    }
  `;

  const slideStyle = document.createElement("style");
  document.head.append(baseStyle, slideStyle);

  const counter = document.createElement("div");
  counter.className = "lbs-counter";
  document.body.appendChild(counter);

  const sections = () =>
    Array.from(
      document.querySelectorAll("[data-el-sections-container] > [data-el-section]"),
    );

  let currentId = null;

  function currentIndex() {
    return sections().findIndex((section) => section.dataset.sectionId === currentId);
  }

  function show(next) {
    const all = sections();
    if (all.length === 0) return;

    const index = Math.max(0, Math.min(next, all.length - 1));
    currentId = all[index].dataset.sectionId;

    const id = `[data-section-id="${CSS.escape(currentId)}"]`;
    slideStyle.textContent = `
      /* Hide the other slides */
      [data-el-sections-container] > [data-el-section]:not(${id}) {
        display: none !important;
      }

      /* Show all blocks of the slide, also when a Livebook view dims them */
      [data-el-section]${id} :is([data-el-section-headline], [data-el-cell]) {
        opacity: 1 !important;
      }

      [data-el-section]${id} [data-el-section-headline] h2 {
        font-size: 2.5rem;
        line-height: 1.2;
      }
    `;

    all[index].scrollIntoView({ block: "start" });
    counter.textContent = `${index + 1} / ${all.length}`;
  }

  // Start at the section with the focus. If no section has the focus,
  // start at the first section that is in the viewport.
  function startIndex() {
    const all = sections();
    const focused = all.findIndex((section) => section.querySelector("[data-js-focused]"));
    if (focused !== -1) return focused;

    const inViewport = all.findIndex((section) => section.getBoundingClientRect().bottom > 0);
    return Math.max(inViewport, 0);
  }

  function isTyping(target) {
    return (
      target instanceof Element &&
      target.closest("input, textarea, select, [contenteditable='true']") !== null
    );
  }

  function onKeyDown(event) {
    if (isTyping(event.target) || event.metaKey || event.ctrlKey || event.altKey) return;

    const index = currentIndex();
    const moves = {
      PageDown: index + 1,
      ArrowRight: index + 1,
      PageUp: index - 1,
      ArrowLeft: index - 1,
      Home: 0,
      End: sections().length - 1,
    };
    if (!(event.key in moves)) return;

    // Stop Livebook from also handling the key
    event.preventDefault();
    event.stopPropagation();
    show(moves[event.key]);
  }

  window.addEventListener("keydown", onKeyDown, true);
  show(startIndex());

  window[STATE] = {
    stop() {
      window.removeEventListener("keydown", onKeyDown, true);
      baseStyle.remove();
      slideStyle.remove();
      counter.remove();
      delete window[STATE];
    },
  };
})();
