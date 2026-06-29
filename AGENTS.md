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

