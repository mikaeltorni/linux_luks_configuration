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



## Shared workflow

This file intentionally contains project-specific ownership, data-safety,
component, integration, and deployment facts. The reusable workflow rules
live in the selected skills and must not be copied into every project file.

Before editing, read this project file, then load:

- `general-programming-guidelines` for the engineering workflow;
- `commits` for capability boundaries and commit verification;
- `worktree` for isolation, branch, merge, and consumer reapplication; and
- `linux-configuration` when the task touches GNOME, desktop settings,
  systemd user services, or any `install.sh`.

Those skills are the cross-project source of truth for workflow, delivery,
desktop deployment, clean-install compatibility, and root-optional installer
rules. Project-specific sections here may narrow ownership or add required
verification, but must not restate or contradict those shared policies.
