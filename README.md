# Linux LUKS Configuration

This project provides scripts for configuring Linux Unified Key Setup (LUKS)
disk encryption. Disk-encryption operations can permanently destroy data,
render a system unbootable, or make encrypted data unrecoverable if a device,
passphrase, recovery key, or configuration value is incorrect.

Use this project entirely at your own risk and only after creating and
verifying independent backups. Test all changes in a disposable virtual machine
before using them on physical hardware. You are solely responsible for
reviewing commands, selecting the correct target device, protecting encryption
credentials and recovery material, and confirming that a recovery procedure
works.

The authors and contributors are not liable for data loss, hardware damage,
service interruption, loss of access, security incidents, lost profits, or any
other direct, indirect, incidental, special, exemplary, or consequential
damages arising from use of, inability to use, or reliance on this project.
There is no guarantee that these scripts are suitable for any particular
system or purpose. See [LICENSE.md](LICENSE.md) for the full warranty disclaimer
and limitation of liability.

## Safety model

Both installer components are default-off. The default setup chain therefore
performs no LUKS action. Volume provisioning refuses mounted targets and any
device in the running root filesystem's block-device ancestry. Every volume
action requires the exact canonical device confirmation. A new container also
requires the formatting acknowledgements below:

- `LUKS_TARGET_DEVICE` — the test block device.
- `LUKS_CONFIRM_DEVICE` — the exact canonical path of that same device.
- `LUKS_ALLOW_FORMAT=YES` — acknowledgement that formatting destroys data.
- `LUKS_ALLOW_WIPE_SIGNATURES=YES` — additionally required when signatures
  already exist on the target.

Optional `LUKS_MAPPING_NAME` and `LUKS_MOUNT_POINT` values default to
`secure_data` and `/mnt/secure_data`. Successful provisioning creates a LUKS2
container with an ext4 filesystem and idempotently records tagged entries in
`/etc/crypttab` and `/etc/fstab`.

### No uninstall step, by design

Neither component declares an uninstall function, and that is deliberate rather
than an omission. Reversing `encrypted_volume` would mean tearing down a
container that holds your data, and reversing `cryptsetup_tools` would remove
the very tooling needed to open any remaining LUKS volume on the machine —
including ones this installer never created. `bash install.sh --uninstall` on
these ids therefore only clears the install receipt; removing a container,
its `/etc/crypttab` / `/etc/fstab` entries, or the `cryptsetup` packages stays a
deliberate manual act.

## Disposable-VM usage

Review the source and attach a dedicated test disk before running anything.
Then select `cryptsetup_tools` and `encrypted_volume` through the component
menu, or invoke the selected components directly with the required environment
values. The installer collects `LUKS_PASSPHRASE` up front (`luks_prompt_passphrase`
or `--collect-config`) and feeds it to `cryptsetup` non-interactively with
`--key-file -`, so a detached-stdin master run cannot hang on a mid-run prompt.

The VM-only regression is `sudo bash tests/check_disposable_vm.sh "$PWD"`.
It expects the disposable guest hostname and cloud-init instance ID
`mt-stack-luks-fixture`, a blank 192 MiB VirtIO disk with serial
`mtstack-luks-fixture`, and Ubuntu package access. It exercises default-off
selection, required consent, detection, reconfiguring a closed volume, and
receipt removal while checking that the volume data survives.

## Disclaimer

This software is provided under the MIT License on an **“as is”** basis, without warranties of any kind. To the maximum extent permitted by applicable law, the authors and copyright holders shall not be liable for any claims, damages, losses, or other liability arising from the use of this software.

You are solely responsible for determining whether this software is suitable, safe, lawful, and appropriate for your intended use. Unless explicitly stated otherwise, this project is general-purpose software and is not designed, tested, certified, or approved for safety-critical, medical, automotive, aviation, industrial-control, life-support, cybersecurity-critical, financial-critical, or other high-risk use cases.

The authors and copyright holders make no guarantees regarding security, reliability, availability, correctness, compliance, non-infringement, or fitness for any particular purpose.

This notice is intended to clarify the nature of the project and does not impose additional restrictions beyond the MIT License.

## Installer lifecycle

Run these commands from this checkout. The component IDs printed by discovery
are the same IDs used by the terminal menu and programmatic actions.

| Command | Behavior |
| --- | --- |
| `bash install.sh` | Open component selection on a terminal; use the default/config selection otherwise. |
| `bash install.sh --help` | Show accepted options (`-h` is equivalent). |
| `bash install.sh --list-components` | Print component IDs, labels and defaults. |
| `bash install.sh --default` | Apply default-on components. |
| `bash install.sh --all` | Apply every component. |
| `bash install.sh --select ID,...` | Apply exactly the named components. |
| `bash install.sh --reconfigure ID,...` | Reapply those components through the same install operations. |
| `bash install.sh --uninstall ID,...` | Run the selected removal operations. |
| `bash install.sh --detect` | Print `ID<TAB>installed` or `ID<TAB>absent`. |
| `bash install.sh --export-selection` | Print selection JSON without applying it. |

The shared interface also accepts `--config NAME` (an installation JSON name
or path) and `--auth` (explicit permission for authenticated component actions).
`--config=NAME`, `--select=ID,...`, `--reconfigure=ID,...`,
`--uninstall=ID,...` and `--configure-component=ID` are equivalent forms.
Advanced discovery is available through `--list-configurable-components`,
`--list-select-configure-components` and `--list-component-config-values`;
`--configure-component ID` opens an available nested screen. Atomic owners
return empty advanced listings and reject unavailable nested configuration.

Explicit `--select ""` selects no optional components; a defined mandatory core
or installation preflight still runs. `--uninstall ""` is a no-op. Unknown or
duplicate IDs, missing operands and conflicting modes reject before component
installation/removal. Help, discovery, detection and export perform no installation.
Cancelling the component menu performs no install/removal. Configuration screens
may save their own settings when explicitly accepted.

The shared terminal screen uses arrows to move, Space to toggle, Enter to
apply and `q`/Escape to cancel; installed components support `u` for removal.
A right-arrow detail action appears where the owner provides configuration.
Removal-only selections skip core installation.

The licensed `.installer-support/` package is generated by
`linux_installation_scripts_functions`; `manifest.json` records provenance and
SHA-256 hashes, and `LICENSE.md` retains the MIT grant. It is a shared library
subset, not an application checkout. The default bootstrap requires no private
download or sibling repository. Explicit `ISC_COMPONENT_LIB_DIR` /
`ISC_FUNCTIONS_DIR` overrides remain available for development and the old setup
chain. Regenerate support from its owner rather than editing copies. Bash and
Python 3 are needed for this library; project build/runtime requirements above
still apply.

Components without a reversible uninstall callback clear their installation
receipt only; they do not undo installed packages, downloaded models or settings.
Live detection can therefore continue to report an installed resource afterward.
This applies to: `cryptsetup_tools`, `encrypted_volume`.

The command forms above describe the installer contract. Execute or test this
installer only in a disposable VM with disposable disks, as required by
`AGENTS.md`. The current verification is static; no disk operation or installer
command was run on the host.

For example, inspect IDs first, then use the same ID with either interface:

```bash
bash install.sh --list-components
bash install.sh --select cryptsetup_tools
bash install.sh --detect
bash install.sh --uninstall cryptsetup_tools
```
