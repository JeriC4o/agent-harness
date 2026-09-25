---
id: a-checker-is-a-gate
category: testing
kind: correction
created: 2026-09-26
---

**Rule:** A script written for one pass to answer a question about the repository is a gate, not a query.
Validate it against one input whose correct answer is known independently before reading its output as
findings, and give it an exit status rather than only printed lines.

**Why:** Its first output is a claim someone will act on. A checker that reports by printing and always
exits zero cannot be distinguished from one whose matcher silently matched nothing, so "no findings" and
"the check never ran" arrive looking identical. A checker feels like a query and is therefore exempted by
habit, but a gate that cannot fail is not a gate.

**Signal:** A one-off analysis script. Any block of shell embedded in an instruction file that reports
findings by printing them. A check whose only failure mode is empty output.
