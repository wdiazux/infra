---
name: code-review
description: Run comprehensive IaC code review
---

Run code review: $ARGUMENTS

Use the **code-review** skill to perform a comprehensive review.

If no path specified, auto-detect technologies in current directory.
If path specified, review that specific path.

Generate report to `docs/reviews/YYYY-MM-DD-<technology>-review.md`.

After review, ask if user wants to work through fixes interactively.
