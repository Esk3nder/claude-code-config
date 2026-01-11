---
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
argument-hint: [plan-file]
description: Superpowers executor: iterate tasks in the plan file, updating status and running checks.
---

You are invoking **superpowers-executing-plans**. Plan file: `$ARGUMENTS` (default `task_plan.md`).

Execution loop per task:
- Re-read the plan, pick the next unchecked task, restate it.
- Execute minimally; touch only listed files.
- Update status and notes immediately in the plan file.
- Run the task’s verification step and record the result.
- If tasks change, edit the plan first.

Finish by running the plan’s verification block and summarizing outcomes.
