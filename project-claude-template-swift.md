# Project Standards

This file extends the global `~/.claude/CLAUDE.md`. It defines stack-specific conventions for this project.

> **This is an Xcode/Apple-platform repo, not a containerized service.** Several global rules assume Docker and a running HTTP service; this template deliberately overrides them:
> - **Docker-first development (the other stack templates):** iOS builds require Xcode and the Apple toolchain on macOS — there are no containers. Build and test commands run on the host. See **Building the App** below.
> - **Operational Verification (global §6):** there is no `docker compose ps` or `/health` endpoint. "Did it work?" is answered by a clean build with no new warnings, a passing test run, and the app actually launching and behaving in a simulator. See **Verification** below.
> - **Orientation (global §1):** there is no `package.json`/`pyproject.toml`. Orient from `Package.swift`, the `.xcodeproj`/`.xcworkspace`, and the scheme list (`xcodebuild -list`).

---

## Stack

Swift 6 (language mode 6, strict concurrency), SwiftUI, Swift Package Manager, built with Xcode. Deployment target and supported platforms are recorded in the Project Architecture section below.

---

## Work Tracking

This project uses a hierarchy of Initiative → Epic → Story → Task. The vocabulary, label conventions, and lifecycle diagram are in `docs/glossary.md`. The discovery Q&A playbook is at `docs/discovery-qa.md`. Read both at the start of any session where work-tracking decisions might arise.

**Critical behaviors:**

- When the user describes a new product or feature idea, follow `docs/discovery-qa.md`. The playbook produces a draft PRD at `docs/prds/<slug>.md` via structured Q&A.
- After PRD approval, propose Epics and initial Stories as a markdown draft for user review **before** filing GitHub issues. Use `gh issue create --template <template>.md` only after the user signs off on the proposal.
- When making a non-trivial technical decision during implementation (persistence choice, navigation model, module boundary, dependency adoption, deployment target change), write an ADR using `docs/templates/adr-template.md` to `docs/adrs/NNN-<slug>.md`. Number sequentially.

Skip discovery for tactical work — bugs, refactors, security fixes, focused stories, or single tasks. Use the appropriate `.github/ISSUE_TEMPLATE/` directly.

If the scope is unclear, ask the user once: *"Is this a focused fix/feature or a multi-week effort that deserves a PRD?"* Then proceed accordingly.

---

## Building the App

- **Discover schemes before guessing:** `xcodebuild -list` (add `-workspace <App>.xcworkspace` or `-project <App>.xcodeproj`). If the repo has an `.xcworkspace`, always pass `-workspace` — building the bare `.xcodeproj` misses part of the dependency graph and fails in confusing ways.
- **Always pass `-destination`.** Without it xcodebuild picks a destination on its own and the resulting errors describe the wrong platform. List real simulators with `xcrun simctl list devices available`.
- **`set -o pipefail` when piping through `xcbeautify`/`xcpretty`.** xcodebuild output is enormous, so formatting it is standard — but without `pipefail` the shell reports the formatter's exit status and **a failed build looks green**.
- **`swift build` / `swift test` are not the app build.** They compile for the host (macOS) and skip the app target, resources, entitlements, and every `#if os(iOS)` branch. A green `swift test` never means the iOS app compiles.
- **Clean is not a debugging step.** If a build breaks straight after a branch switch or dependency change, `xcodebuild clean` (or removing that project's DerivedData) is reasonable. For an ordinary compile error, read the error.

---

## Xcode Project Files

- **A file on disk is not a file in the target.** Creating a `.swift` file does not add it to any Xcode target; it simply doesn't compile, and the failure surfaces as "cannot find X in scope" in *other* files. How to add it depends on how the project is generated:
  - **XcodeGen / Tuist** — edit `project.yml` / `Project.swift` and regenerate.
  - **Local SPM package** — dropping the file into the package's `Sources/` directory is enough. This is why new code belongs in packages.
  - **Raw `.xcodeproj`** — tell the user the file needs adding to the target in Xcode. Do **not** hand-edit `project.pbxproj`.
- **Treat `project.pbxproj` as generated.** It is a machine-managed file with UUID cross-references; hand edits corrupt it and merge conflicts in it are not resolvable by eye.
- **Commit shared schemes** (`xcshareddata/xcschemes/`) so CI and every developer build the same thing. Never commit `xcuserdata/` or `DerivedData/`.

---

## Code Style

- **Naming follows the Swift API Design Guidelines** — names read as phrases at the call site (`items.remove(at: i)`), no `get` prefix on accessors, no Objective-C-era type prefixes (`NS`, `MY`).
- **Formatting:** SwiftFormat or `swift-format`, plus SwiftLint if the project configures them. Let the formatter own layout; don't hand-tune it.
- **`let` by default** — `var` only where the value is actually mutated.
- **No force unwrap (`!`), `try!`, or `as!` in shipping code.** They crash in front of a user. Use `guard let … else`, `throws`, and `as?`. Tests may force-unwrap.
- **Access control:** `private` for anything not used outside its file, `internal` (the default) inside a module, `public` only for a deliberate module API.
- **`struct` over `class`** unless identity or shared mutable state is genuinely required.
- One primary type per file, named for the type; group with `// MARK: -`; put protocol conformances in extensions rather than one large type body.

---

## Project Layout

```
App/
  <App>App.swift             # @main entry point
  Info.plist
  Assets.xcassets
  PrivacyInfo.xcprivacy      # data-collection + required-reason API manifest
Features/<Feature>/          # views, view models, and feature-local models together
Packages/<Package>/          # local SPM packages — the preferred home for logic
  Sources/ Tests/
<App>Tests/                  # tests that need the app target
<App>UITests/                # XCUITest flows
project.yml | Project.swift  # XcodeGen / Tuist manifest, if the project uses one
```

- **Push logic down into local SPM packages.** Code there gets target membership automatically, builds without Xcode, and its tests run on the host in seconds instead of booting a simulator. The app target should hold composition, wiring, and platform glue.
- Feature directories own their views *and* their view models — don't split them into parallel `Views/`/`ViewModels/` trees, which forces every change to touch two distant places.

---

## Concurrency

Swift 6 language mode turns data races into compile errors. That diagnostic is the feature — treat it as a design signal, not an obstacle.

- **Never silence an isolation error to move on.** `@unchecked Sendable`, `nonisolated(unsafe)`, and `@preconcurrency import` suppress the check while leaving the race in place. Use them only to bridge a legacy or C API, with a comment saying why it's safe.
- **Annotate at the type level.** UI-driving types are `@MainActor` on the type, not `Task { @MainActor in … }` wrapped around each body — the wrapper defers work by a hop and reintroduces ordering bugs.
- **New async code uses `async`/`await`.** Don't add `DispatchQueue.main.async`, `DispatchSemaphore`, or completion-handler APIs to new code, and never block a thread waiting on async work.
- **Every `Task` needs an owner.** An unstructured `Task { }` outlives the view or view model that started it unless you store and cancel it. Prefer SwiftUI's `.task { }` (cancelled automatically when the view goes away) or structured children via `async let` / `TaskGroup`.
- **Honor cancellation** — check `Task.isCancelled` or call `try Task.checkCancellation()` inside loops and between expensive steps.
- **`actor` for shared mutable state** accessed from several contexts; `@MainActor` for state that only the UI touches. An actor for UI state just adds hops.

---

## SwiftUI

- **`@Observable` for new model types** (the Observation framework). `ObservableObject`/`@Published` only where the project already uses them.
- **State ownership is a correctness question, not a style one:** `@State` when this view creates and owns the value, `@Binding` to hand write access down, a plain `let` for read-only data. With `ObservableObject`, `@StateObject` creates the object once — `@ObservedObject` does not, so an object constructed inline and held with `@ObservedObject` is silently recreated on every re-render and loses its state.
- **`body` must be pure.** It runs arbitrarily often. No network calls, no persistence writes, no mutation of state it reads. Side effects belong in `.task`, `.onAppear`, or an action closure.
- **Prefer `.task { }` to `onAppear { Task { … } }`** — `.task` is tied to view lifetime and cancels.
- **Give `ForEach` stable identity** (`Identifiable`, or a real key). Index-based ids break animations and view reuse as soon as the collection mutates.
- **Decompose long bodies into subviews.** A hundred-line `body` produces unreadable type-checker errors and defeats SwiftUI's diffing.

---

## Error Handling

- **Model failures as a domain `Error` enum** when callers must distinguish them; use typed throws (`throws(MyError)`) where the project's Swift version supports it.
- **Never swallow.** An empty `catch { }` is banned, and `try?` throws away *why* it failed — use it only where the failure is genuinely uninteresting, never to make a compile error go away.
- **`fatalError` and `precondition` survive release builds** — they are for programmer error only. `assert`/`assertionFailure` compile out in release, so never use them to validate input or remote data.
- **Cancellation is not a failure.** `CancellationError` and `URLError.cancelled` must not surface as an error alert to the user.
- **Errors reach the user as state**, not as console output. An error printed and dropped is invisible in TestFlight and in production.
- **Use `Logger` (OSLog), not `print`,** in shipping code — `print` doesn't reach device logs.

---

## Security

- **The app binary is client-side and fully readable.** Anything embedded in source, `Info.plist`, an `.xcconfig`, or the asset catalog — API keys, secrets, private endpoints — ships to every user and is extractable from an IPA. Secrets belong on a server; if a third-party API needs one, proxy the call. Obfuscation is not a mitigation.
- **Credentials and tokens live in the Keychain**, never `UserDefaults`, a plist, or a file in Documents. Choose accessibility deliberately (`…ThisDeviceOnly` for anything that must not restore onto a new device).
- **Leave App Transport Security on.** No `NSAllowsArbitraryLoads` — an ATS exception added to make a local dev server work ships to production. If a scoped domain exception is genuinely unavoidable, flag it to the user.
- **Randomness from `SecRandomCopyRandomBytes` or CryptoKit** for tokens, salts, and IDs — never `arc4random` or `Int.random`, which are not cryptographically secure.
- **Never hand-roll crypto.** Use CryptoKit, never reuse a nonce, and compare secrets and MACs in constant time — not `==`.
- **Biometrics are a local convenience gate, not an authentication boundary.** `LocalAuthentication` proves someone unlocked this device; it says nothing to your server. Pair it with a Keychain item guarded by `.biometryCurrentSet` and keep the real authorization check server-side.
- **Never log PII or tokens.** `Logger` string interpolation redacts non-numeric values by default — don't defeat it with `privacy: .public`.
- **`PrivacyInfo.xcprivacy` must stay accurate** — it declares data collection and required-reason API use (`UserDefaults`, file timestamps, disk space, and friends). App Store review rejects a missing or incomplete manifest, and any new SDK can add requirements.
- **Add the `Info.plist` usage description whenever you touch camera, photos, location, mic, or contacts.** Without it the app *crashes* the first time the API is used — at runtime, in a code path you weren't editing.
- **Never commit signing material:** `*.p12`, `*.cer`, `*.mobileprovision`, `AuthKey_*.p8`, or an `ExportOptions.plist` carrying team identifiers (extends global §5).

---

## Testing

- **Swift Testing (`import Testing`, `@Test`, `#expect`/`#require`) for new tests.** Keep XCTest where it already exists, and note that **UI tests must remain XCTest** (`XCUIApplication`).
- **Keep logic tests out of the app target.** A test in a local SPM package runs on the host in seconds; the same test in the app target boots a simulator. Structure new code so its logic is testable without one.
- **Async tests `await` directly** — no `XCTestExpectation` + `waitForExpectations` in new async code, and never `Task.sleep` to "wait for" something to settle.
- **Mark tests `@MainActor` when they touch UI or view-model state**, so isolation matches production instead of accidentally passing off-actor.
- **UI tests select by accessibility identifier**, never by displayed text — text breaks on copy edits and localization. They are slow and flaky by nature: cover critical flows only.
- **Run the suite once on the project's minimum supported OS**, not only the latest simulator, before shipping.

---

## Dependency Management

- **Swift Package Manager only.** Do not introduce CocoaPods or Carthage into a project that doesn't already have them.
- **`Package.resolved` is committed.** In an app project it hides at `<App>.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (or inside the `.xcworkspace`) — easy to miss, so confirm it's staged after any dependency change.
- **Never depend on a `branch:` or a moving `revision:`** in a shipping app. Use `.upToNextMajor(from:)`, or an exact pin for anything that has broken you before.
- **Minimal dependencies.** Foundation, SwiftUI, Observation, `URLSession` + `Codable`, CryptoKit, and SwiftData cover most of what small packages offer — and every dependency is code you ship and Apple reviews.
- **Dependency bumps are their own change** with their own PR, so the `Package.resolved` diff is reviewable. Don't let them ride along.

---

## Validation Commands

```bash
set -o pipefail                       # required, or a failed build reads as success through xcbeautify
xcodebuild -list                      # discover schemes first; add -workspace/-project as appropriate
xcrun simctl list devices available   # pick a real destination

DEST='platform=iOS Simulator,name=<Simulator>'
xcodebuild -scheme <Scheme> -destination "$DEST" build | xcbeautify
xcodebuild -scheme <Scheme> -destination "$DEST" test  | xcbeautify

xcodebuild -scheme <Scheme> -destination 'generic/platform=iOS' build | xcbeautify  # device build
swift test --package-path Packages/<Package>   # fast logic tests, no simulator

swiftlint                             # if configured
swiftformat --lint .                  # or: swift-format lint -r Sources
```

All must pass — **and the build must introduce no new warnings** — before marking work complete.

---

## Verification

This replaces global §6 (Operational Verification) for this repo.

- **Build for a real device (`generic/platform=iOS`), not just the simulator.** Device builds catch signing, entitlement, and architecture problems the simulator hides entirely.
- **Launch it.** Compiling is not working: run the scheme in Xcode, or `xcrun simctl boot` / `install` / `launch`. Exercise the path you changed.
- **Watch the console** for crashes, runtime warnings, and main-thread hangs that a passing build says nothing about.
- **Never report complete** when the app builds but crashes on launch, hangs, or logs a purple runtime issue in the flow you touched.

---

## Swift/iOS-Specific Rules

- **Never raise the deployment target to use a newer API without surfacing it.** It drops users on older OS versions — that's a product decision, not an implementation detail (global §1). Guard newer APIs with `if #available(…)` instead.
- **Keep the main thread free.** File I/O, decoding large payloads, and image processing move off the main actor. A dropped frame is a bug, not a polish item.
- **Watch for retain cycles in escaping closures** — `[weak self]` where the closure outlives its owner; note that a `Task { }` capturing `self` keeps a view model alive past the view.
- **New capabilities are architecture changes.** Push notifications, background modes, App Groups, HealthKit, and similar entitlements alter provisioning and App Store review — surface before adding, per global §1.
- **Never delete or reset a SwiftData/Core Data store to resolve a schema mismatch** on anything that could hold real user data — write a migration. If a migration fails, stop and ask; there is no undo on a user's device.
- **User-facing strings go through the string catalog** (`String(localized:)`), and non-text controls get accessibility labels — retrofitting either is far more expensive than doing it inline.

---

## Project Architecture

<!-- Update this section when you start a new project -->

**Application type:** <!-- e.g., SwiftUI iOS app; iOS app + widget + watchOS companion; distributed Swift package -->

**Targets & platforms:**
<!-- e.g.,
| Target        | Platform | Minimum OS |
|---------------|----------|------------|
| App           | iOS      | 17.0       |
| WidgetKit ext | iOS      | 17.0       |
| AppTests      | iOS      | 17.0       |
-->

**Key directories:**
<!-- e.g.,
- App/ — entry point, app-level wiring, Info.plist, assets
- Features/Onboarding/ — onboarding views + view models
- Packages/Networking/ — API client (local SPM package)
- Packages/DesignSystem/ — shared components and tokens
-->

**Key decisions:**
<!-- e.g.,
- Project generation: XcodeGen (project.yml is the source of truth; .xcodeproj is gitignored)
- Persistence: SwiftData; migrations versioned under Packages/Persistence
- Networking: URLSession + Codable, no third-party client
- Navigation: NavigationStack driven by a Router in app state
- Signing: automatic in dev, manual with a CI-only certificate
- Backend: <API base URL / how auth tokens are obtained>
-->
