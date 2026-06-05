# MASTER PLAN: LOCAL LIGHTWEIGHT MACOS INPUT METHOD WITH AUTOCOMPLETE

## 🎯 PROJECT OVERVIEW

Build a lightweight, native macOS input method app to replace EVKey/OpenKey.

* **Core Functionality:** Toggle between 2 modes: Vietnamese (Telex) and English.
* **Key Feature:** Smart autocomplete/suggestion overlay when typing in English mode, using Apple's native `NSSpellChecker` API (100% local, zero external dependencies).
* **Performance Goal:** Minimal resource footprints (< 20MB RAM, ~0% CPU idle).

---

## 🛠 TECH STACK

* **Language:** Swift 5+
* **Frameworks:** Cocoa, CoreGraphics (for Event Taps), AppKit, Foundation.
* **Architecture:** Agentic-friendly modular architecture (Separation of Input Engine, UI Overlay, and Core Logic).

---

## 📋 SEQUENCE OF TASKS FOR AGENTIC CODE

### TASK 0: SETUP PROJECT ENVIRONMENT & CURSOR RULES

*Before generating any functional code, establish the workspace guidelines.*

1. **Create File:** `.cursorrules` (or system prompt instruction) with the following strict constraints:
* **Language & Style:** Write clean, idiomatic Swift. Use structured concurrency (`async/await`) where appropriate, but favor simple, synchronous callbacks for low-latency input event handling.
* **Memory Management:** Strictly avoid memory leaks. Use `[weak self]` in closures, especially within event loops or timer-based observers.
* **No External Dependencies:** Do not add CocoaPods, Swift Package Manager (SPM) packages, or external libraries. Use Apple's built-in frameworks only.
* **Logging Rule:** Use a centralized logger utility or `os_log` instead of raw `print()` statements to prevent polluting console logs during active typing.
* **Incremental Commit Strategy:** Complete one module at a time, verify compilation, and verify safety before proceeding to the next file.



---

### TASK 1: BASE SYSTEM INTEGRATION (EVENT TAP & MODE TOGGLE)

*Objective: Intercept system-wide keystrokes and handle input mode switching.*

1. **Implement `EventTapManager`:**
* Use `CGEventTapCreate` to intercept low-level keyboard events (`NX_KEYDOWN`, `NX_KEYUP`, `NX_FLAGSCHANGED`).
* Run the event tap on a high-priority loop (`CFRunLoopGetMain()`).


2. **Implement Mode State Machine:**
* Create an `InputMode` enum: `.vietnamese` and `.english`.
* Implement a configurable global shortcut to instantly toggle states (Default shortcut: `Right-Command` or `Ctrl+Space`).


3. **Vietnamese Core Stub:**
* In `.vietnamese` mode, pass the captured key events through a basic telemetry pipeline (prepare hooks for Telex processing later). For this initial implementation, prioritize the English Autocomplete engine.
* In `.english` mode, forward characters straight to the autocomplete module.



---

### TASK 2: LOCAL SUGGESTION ENGINE (`NSSpellChecker`)

*Objective: Leverage macOS built-in dictionaries to query words instantly based on a prefix.*

1. **Implement `SuggestionEngine` class:**
* Keep track of the currently active "word buffer" (characters typed since the last boundary like Space, Enter, or punctuation).
* When the buffer length is greater than or equal to 2 (e.g., `ha`), pass the prefix string to `NSSpellChecker.shared.completions(forPartialWordRange:in:language:inSpellDocumentWithTag:)`.
* Specify language as `"en"`.


2. **Result Formatting:**
* Filter and sort the returned array to pick the top 3 most relevant choices.
* Map these completions into an array of strings (e.g., `["happy", "hat", "hate"]`).



---

### TASK 3: FLOATING SUGGESTION OVERLAY (UI)

*Objective: Display options visually under the cursor without stealing focus from the active text field.*

1. **Create `SuggestionPanel` (`NSPanel` subclass):**
* Configure properties: `.nonactivatingPanel`, `.borderless`, `.floatingWindowLevel`. This ensures it never steals focus from other apps (like Chrome, Word, Xcode).
* Set background behavior to be transparent or match system dark/light appearance with rounded corners.


2. **Layout Design:**
* Create a simple horizontal layout displaying exactly 3 options.
* Add visual styling to indicate the "Currently Highlighted Option" (defaults to the 1st option).


3. **Coordinate Tracking (Cursor Positioning):**
* Fetch the current caret screen coordinates using accessibility APIs (`AXUIElementCopyAttributeValue` for `AXSelectedTextRange`).
* *Fallback:* If accessibility permissions are missing, position the panel relative to the active mouse cursor coordinate.



---

### TASK 4: KEY NAVIGATION & INTERACTION LOGIC

*Objective: Bind keyboard controls to seamlessly select and commit suggestions.*

1. **Intercept Navigation Keys:**
* While the `SuggestionPanel` is visible, intercept specific keys within the Event Tap:
* `Tab` key $\rightarrow$ Instantly commits the **first** suggested option.
* `Down Arrow` / `Up Arrow` $\rightarrow$ Change selection highlights within the 3 options.
* `Return` / `Space` $\rightarrow$ Commit the currently highlighted option.
* `Escape` $\rightarrow$ Dismiss the suggestion overlay without inserting anything.




2. **Commit Automation Mechanism:**
* When an option is committed (e.g., user selects `happy` when they typed `ha`):
* Calculate how many characters are currently in the active prefix buffer (e.g., 2 characters for `ha`).
* Programmatically send Backspace events (`CGEventCreateKeyboardEvent`) matching that buffer count to erase the prefix.
* Programmatically send keyboard events to type out the completed word (e.g., typing out `happy`) followed by a space trailing character.
* Clear the active prefix buffer and hide the `SuggestionPanel`.





---

### TASK 5: RESOURCE OPTIMIZATION & BACKGROUND EXECUTION

*Objective: Strip down any overhead so the app runs invisibly.*

1. **Configure Menu Bar App Status:**
* Modify `Info.plist` to set `LSUIElement = true` (Transforms the app into an agent/background utility so it doesn't show in the Dock).
* Add an `NSStatusItem` on the system menu bar showing a simple minimalist icon indicating current state (`EN` or `VI`). Clicking it provides an option to "Quit".


2. **Lifecycle Optimization:**
* Ensure the Suggestion Engine completely frees up buffers when hidden.
* Validate that no polling timers are active. The entire app must be purely event-driven based on key presses.



---

### TASK 6: GENERATE DOCUMENTATION & RUN INSTRUCTIONS

*Objective: Deliver clear configuration instructions for the end-user.*

1. **Create a `README.md` file in the root directory containing:**
* **Project Summary:** Concise overview of the utility.
* **Prerequisites:** macOS version, Xcode version, and critical Privacy Permissions notice (**Accessibility** and **Input Monitoring** configuration under System Settings).
* **Step-by-step Execution Guide:**
1. How to open the project workspace in Xcode.
2. How to build and compile (`Product -> Build` or `Cmd+B`).
3. How to archive and run the standalone application.


* **Usage Manual:** Detailing the toggle shortcut, how typing triggering works, and navigation controls (`Tab`, `Arrows`, `Return`).



---

## 🛑 AGENT STOPPING CRITERIA

* The Agent may stop and request validation once **Task 1** and **Task 2** compile successfully together.
* The Agent must perform a manual sanity check on any CoreGraphics key code map values (e.g., checking that keycode `48` represents Tab) before proceeding to Task 4.