<!--
PR title = squash commit message. Use Conventional Commits: feat|fix|chore|docs|refactor|ci(scope): summary
-->

## Why
<!-- The problem this solves. Link the ticket so it closes on merge: Closes CUBE-123 -->

## What changed
<!-- Short summary. The diff shows the details; tell reviewers what to focus on. -->

## How I tested it
<!-- Steps a reviewer can repeat, and what you saw. Paste screenshots, URLs or command output. -->

## Risk and rollback
<!-- What could break and who notices. How to undo it.
For Terraform: does the plan destroy or replace anything? Why is that safe? -->

## Checklist
- [ ] I read the Terraform plan comment and nothing is destroyed or replaced unexpectedly
- [ ] No secrets in code, tfvars, logs or screenshots
- [ ] README/docs updated if behaviour or a manual step changed
