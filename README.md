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

## Disclaimer

This software is provided under the MIT License on an **“as is”** basis, without warranties of any kind. To the maximum extent permitted by applicable law, the authors and copyright holders shall not be liable for any claims, damages, losses, or other liability arising from the use of this software.

You are solely responsible for determining whether this software is suitable, safe, lawful, and appropriate for your intended use. Unless explicitly stated otherwise, this project is general-purpose software and is not designed, tested, certified, or approved for safety-critical, medical, automotive, aviation, industrial-control, life-support, cybersecurity-critical, financial-critical, or other high-risk use cases.

The authors and copyright holders make no guarantees regarding security, reliability, availability, correctness, compliance, non-infringement, or fitness for any particular purpose.

This notice is intended to clarify the nature of the project and does not impose additional restrictions beyond the MIT License.
