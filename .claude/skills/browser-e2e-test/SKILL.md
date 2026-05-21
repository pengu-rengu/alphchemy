---
name: browser-e2e-test
description: Generate an end-to-end UI test plan for a browser-use agent verifying recently implemented frontend changes. Plan assumes the agent acts like an end user with no codebase knowledge and no developer tools.
user-invocable: true
allowed-tools: [Read, Grep, Glob, Bash]
---

# Browser-use E2E Test Plan

You are generating a test plan for a **browser-use agent** that will act as an end user of the app. Output the test plan directly to the conversation in markdown so the user can hand it to the browser-use agent.

## Constraints — the test plan reader CAN ONLY

- Open the app in a browser at the URL the user already has running.
- Log in if prompted (using credentials they already have).
- Click visible UI elements (buttons, icons, list rows, tabs, dialog actions).
- Type into visible text fields and dropdowns.
- Read text rendered on the page.


## Constraints — the test plan reader CANNOT

- Open browser DevTools, Inspect Element, Network tab, Console, Application/Storage, or Sources.
- Edit the database directly, hit Supabase admin, or run SQL.
- Navigate by typing URLs / paths (only via UI clicks).
- Open a terminal, run any shell command, or read code/config files.
- Use keyboard shortcuts that DevTools would intercept (no F12, no Cmd+Opt+I).
- Make assumptions about internal state — only verify what is visible.
- Take screenshots of the rendered page.

Reflect these constraints in the plan you write. Never instruct the agent to "open DevTools", "go to Network tab", "set offline mode in DevTools", "look at the database row", "check the console", or "navigate to /path/to/page".

## Required scoping step (do BEFORE writing the plan)

1. Inspect the recent conversation context to identify what was just implemented or changed.
2. Map each code change to the user-facing flow it affects (which page, which UI element, which interaction triggers it).
3. If the changes are ambiguous, the user-facing flow isn't clear, or there are multiple plausible flows to cover, ask the user briefly which flows to focus on before generating the plan.
4. If exploring the codebase is needed to identify navigation paths / button labels / dialog structure, use `Read` / `Grep` / `Glob` to look at the relevant Flutter widget files. Extract the visible button labels and placeholder text the user actually sees — do NOT use widget class names in the plan.

## Plan structure template

Always produce these sections in this order:

### 1. Tester orientation

Describe the app's UI to a reader who has never seen it. Cover:
- Left navigation rail icons + labels (top to bottom).
- The layout of any page the test will touch (left column / right column / split view, dialogs).
- Visual cues for any element the agent must find: icon names (e.g. "trash icon", "pencil edit icon", "paper-plane send icon", "book icon", "science flask icon", "hourglass icon"), button colors (e.g. "blue filled button"), placement (e.g. "upper-right of the right sidebar").

No widget class names, no "bloc", no file paths.

### 2. Setup

Numbered steps to reach the starting state, via UI only:
- Login if the app prompts.
- Navigate via nav rail clicks (named by visible label).
- Create any fresh fixtures the test needs via UI buttons.

### 3. Per-test sections

One section per user-facing behavior changed. Each section:
- Numbered click/input steps.
- For every text input: a fenced code block containing the **exact** string to type. Example:
  ````markdown
  Type exactly:
  ```
  My exact text here
  ```
  ````
- Every click step names: button label, icon name, color, and approximate location ("upper-right of sidebar", "bottom of dialog").
- Each step ends with a `**Verify**:` line stating what should be observed when applicable.
- Verify steps reference visible UI state only (text, color, presence of widget, absence of widget).

### 4. Pass criteria

Bulleted list of must-pass checkpoints. Phrase as user-observable conditions.

### 5. Reporting per failure

What the agent should report for any failed Verify:
- Test section + step number.
- Visible observations from the page.
- Observed vs expected (in plain English, no internal terms).
- Browser URL at the moment of failure.

### 6. Cleanup

Explicit UI steps to delete any test fixtures created (click trash icons, confirm deletion dialogs).

## Style rules

- Plain language. No `NotebookView`, `FeatureSetBloc`, `lib/widgets/...`, etc.
- Refer to UI by what the user sees: button label, placeholder text, icon shape.
- Code blocks for every text-field input value.
- Imperative voice: "Click X", "Type Y", "Verify Z".
- Keep each step atomic — one click or one input per numbered step.

## Agent system fixture rule

If the feature under test requires the user to create an agent system (e.g. testing submissions, prompts, chat threads, agent-produced outputs), the Setup section MUST instruct creation via these UI steps:

1. Click "Agents" in the left nav rail.
2. Click the blue "New Agent System" button in the upper-right of the right sidebar.
3. In the editor, name the agent system, add at least one agent card via the "+" icon in the "Agents" section, and fill its fields. Subagent pool, agent ID, and additional instructions are flexible — pick whatever fits the feature under test.
4. Click the blue "Save" button in the upper-right.

**Hard constraints on every agent card you instruct the tester to fill:**

- **Max Context Length**: `15` (field counts messages, not tokens — never use 100000 or any token-scale value).
- **# Of Messages to Delete**: `5`.
- All four model fields (Chat Model, Chat Fallback Model, Summarize Model, Summarize Fallback Model): `google/gemini-3.5-flash`.

Everything else (title, agent ID, count of agents, subagents, instructions) is up to the plan author.

## Guardrails

The plan you write must NEVER instruct the browser-use agent to:

- Open DevTools / Inspect / Console / Network tab / any browser developer mode.
- Set the network to offline via DevTools, throttle requests, or simulate failures via dev tools.
- Read or write Supabase rows directly, run SQL, or hit any admin URL.
- Navigate by typing a path into the URL bar.
- Read or modify source code, config files, environment variables, or run terminal commands.
- Assume any internal state ("the row in the notebooks table should have ...", "the bloc should emit ..."). Only assertions about visible UI.
- Use keyboard shortcuts that risk opening dev tools (F12, Cmd+Opt+I, Ctrl+Shift+I).
- Skip the cleanup section.

If the change under test can ONLY be triggered via a non-UI path (e.g. a backend cron job, a manually inserted DB row), note that limitation up front and either:
- Suggest a UI-driven proxy that exercises the same code path, or
- Tell the user the test cannot be done via browser-use and recommend a different verification approach.

## Output

Produce the test plan as a single markdown response in the conversation. Do not write the plan to a file unless the user asks. Do not include this skill's instructions in the output.
