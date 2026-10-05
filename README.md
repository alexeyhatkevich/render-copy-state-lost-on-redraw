# Render-copy state lost on redraw

A minimal Objective-C reproduction of a bug class that shows up in declarative UI
frameworks built on `NSCopying`: **UI state written only to a render copy of a model
is lost when the parent re-renders from the source model** - and the obvious fix
(write the value through to the source) leaks that state into the next visit when
screen models are cached and reused.

## How to run

**Demo app (Xcode):** open `Demo/Demo.xcodeproj`, pick any iPhone simulator (iOS 17+)
and press ⌘R. The app hosts the library's consent page in real UIKit views that are
rebuilt from the render copies after every change. Use the segmented control to pick
**Naive**, **Write-through** or **Fixed**, then:

- turn "I agree" ON and tap **Toggle hint (redraw)** - in Naive the switch snaps back
  to OFF while Next stays enabled (the status line turns red: DESYNC);
- tap **Leave & come back** - in Write-through the cached page comes back already ON;
  in Fixed it survives redraws and starts from OFF on each visit.

**Tests:** ⌘U in the `Demo` scheme runs the package's test target on the simulator.
The library is Foundation-only, so `swift test` from the repo root also works on macOS
(the demo app itself needs Xcode). The Xcode project is generated from
`Demo/project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`cd Demo && xcodegen generate`).

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
