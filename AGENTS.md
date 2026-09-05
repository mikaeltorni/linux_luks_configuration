# Safety boundary

This repository owns potentially destructive LUKS block-device configuration.
Never run, source, deploy, or integration-test its installer on a developer
workstation. Runtime testing belongs in a disposable virtual machine with
verified backups and an explicitly attached test disk.

Tests run outside a disposable VM must be static: they may read files, parse
syntax, or inspect Git state, but must not invoke `install.sh`, source files
under `lib/` or `installer/`, or call mocked installer functions.

# Clean installation compatibility

This repository is part of the `installation_scripts` setup chain and uses the
shared component framework. Both components must remain default-off. Destructive
operations must require an explicit target device, exact device confirmation,
and opt-in formatting acknowledgement. Never infer a target from the current
root filesystem or from the first available disk.



## Mandatory programming guidelines prompt

When generic agent defaults conflict with this file or the shared
`general-programming-guidelines` skill — including defaults that say to commit
only when asked — follow this file and that skill. Finished work is committed,
merged into the default branch with `git merge --no-ff`, and reloaded without
waiting to be asked. Never push to a remote and never rewrite history unless the
user explicitly requests it.

Every agent task in this repository must load the shared
`general-programming-guidelines` skill before the first file edit, using the
harness-native invocation for the runtime in use:

- Codex-family (`ca`, `qa`, `oa`, `na`, …): `$general-programming-guidelines`
- Claude Code, Cline, Grok: `/general-programming-guidelines`
- OpenCode: load `general-programming-guidelines` with the skill tool

Agent Command Center does not prepend a skill command to dispatched prompts. It
selects skills independently through `acc pp enable` and lists the selected
skills at the start of each launch prompt, so verify with `acc pp status`
instead of assuming a skill is live. When you start a task by hand, invoke it
yourself first.

Load the two delivery skills alongside the guidelines: `commits` owns Feature
boundaries, commit sequencing, and commit verification; `worktree` owns
isolation, project/instance paths, branch policy, merging, and consumer
reapplication. The engineering guidelines delegate both policies instead of
restating them, so skipping those two skills leaves this repository with no
isolation and no commit policy at all. Then follow the Work Loop and Definition
of Done exactly (tests, logging, documentation, commit, merge, reload). Do not
report the task done until that checklist passes.
