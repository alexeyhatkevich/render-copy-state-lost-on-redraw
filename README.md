# Render-copy state lost on redraw

A minimal Objective-C reproduction of a bug class that shows up in declarative UI
frameworks built on `NSCopying`: **UI state written only to a render copy of a model
is lost when the parent re-renders from the source model** - and the obvious fix
(write the value through to the source) leaks that state into the next visit when
screen models are cached and reused.

## The setup

- A container keeps SOURCE child models. To render, it creates `[sourceChild copy]`
  for every child, so the object behind each live view is a RENDER COPY whose
  `parent` points at the source container.
- Any layout change (a sibling collapsing or expanding) makes the container redraw:
  it throws the copies away and builds new ones from the sources.
- A consent screen has an "I agree" toggle and a Next button whose enabled state is
  updated from the toggle's `onChange`.

## What goes wrong

| Version | After the user taps ON and a sibling hides | Second visit to the cached page |
| --- | --- | --- |
| `RCNaiveToggle` | switch shows OFF, Next still enabled (desync) | OFF |
| `RCWriteThroughToggle` | ON, consistent | **already ON** - nobody tapped it |
| `RCFixedToggle` | ON, consistent | OFF (authored value) |

## The fix

1. **Write-through.** On every value change (user tap *and* the programmatic
   "set selected" path) also store the value on the source element, found through
   `self.parent` + `identifier`. Skip toggles bound to the data store - the store
   already owns their value.
2. **Reset on fresh presentation.** Capture `authoredSelected` in the initializer,
   copy it in `copyWithZone:`, and reset to it when the page is freshly presented
   (navigation in, re-entry, popup shown) - never on a plain redraw.

Code: [`Sources/RenderCopyState/RCToggle.m`](Sources/RenderCopyState/RCToggle.m).

## Run the tests

```bash
swift test
```

Tests are named `test_naive_*` (they assert the broken behaviour, so they pass and
document the bug), `test_writeThrough_*` (fix part 1 and its regression) and
`test_fixed_*` (the full fix). Foundation only, runs on macOS; no simulator needed.

## License

MIT

Write-up: https://alexeyhatkevich.blogspot.com
