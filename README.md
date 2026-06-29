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

## Disclaimer

This software is provided under the MIT License on an **“as is”** basis, without warranties of any kind. To the maximum extent permitted by applicable law, the authors and copyright holders shall not be liable for any claims, damages, losses, or other liability arising from the use of this software.

You are solely responsible for determining whether this software is suitable, safe, lawful, and appropriate for your intended use. Unless explicitly stated otherwise, this project is general-purpose software and is not designed, tested, certified, or approved for safety-critical, medical, automotive, aviation, industrial-control, life-support, cybersecurity-critical, financial-critical, or other high-risk use cases.

The authors and copyright holders make no guarantees regarding security, reliability, availability, correctness, compliance, non-infringement, or fitness for any particular purpose.

This notice is intended to clarify the nature of the project and does not impose additional restrictions beyond the MIT License.
