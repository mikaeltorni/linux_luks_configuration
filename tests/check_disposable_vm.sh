#!/usr/bin/env bash
set -euo pipefail
test "$(hostname)" = mt-stack-luks-fixture
test "$(cat /var/lib/cloud/data/instance-id)" = mt-stack-luks-fixture
test -b /dev/disk/by-id/virtio-mtstack-luks-fixture
target="$(readlink -f /dev/disk/by-id/virtio-mtstack-luks-fixture)"
test "$(lsblk -nd -o SERIAL "$target")" = mtstack-luks-fixture
test "$(blockdev --getsize64 "$target")" = 201326592
test -z "$(wipefs --no-act "$target")"
cd "$1"
export DEBIAN_FRONTEND=noninteractive
export LUKS_TARGET_DEVICE="$target" LUKS_MAPPING_NAME=mtstack_fixture LUKS_MOUNT_POINT=/mnt/mtstack_fixture
export LUKS_PASSPHRASE=disposable-test-only
bash install.sh --list-components > ~/components.log 2>&1
grep -Fxq $'encrypted_volume\tConfigure an encrypted LUKS volume\toff' ~/components.log
bash install.sh --default > ~/defaults.log 2>&1
test -z "$(wipefs --no-act "$target")"
printf '%s\n' 'PASS: discovery and the default selection leave the test disk blank'
apt-get update > ~/apt-update.log 2>&1
bash install.sh --select cryptsetup_tools > ~/tools.log 2>&1
command -v cryptsetup >/dev/null
if LUKS_CONFIRM_DEVICE="$target" bash install.sh --select encrypted_volume > ~/no-opt-in.log 2>&1; then
    printf '%s\n' 'Unacknowledged formatting unexpectedly returned success' >&2
    exit 1
fi
grep -q 'LUKS_ALLOW_FORMAT=YES' ~/no-opt-in.log
test -z "$(wipefs --no-act "$target")"
if LUKS_CONFIRM_DEVICE=/dev/incorrect-fixture LUKS_ALLOW_FORMAT=YES bash install.sh --select encrypted_volume > ~/wrong-disk.log 2>&1; then
    printf '%s\n' 'Incorrect target confirmation unexpectedly returned success' >&2
    exit 1
fi
grep -q 'LUKS_CONFIRM_DEVICE must exactly equal' ~/wrong-disk.log
test -z "$(wipefs --no-act "$target")"
printf '%s\n' 'PASS: missing format acknowledgement and mismatched device confirmation leave disk blank'
export LUKS_CONFIRM_DEVICE="$target"
LUKS_ALLOW_FORMAT=YES bash install.sh --select encrypted_volume > ~/install-volume.log 2>&1
cryptsetup isLuks "$target"
uuid=$(cryptsetup luksUUID "$target")
[[ "$(findmnt -nro FSTYPE "$LUKS_MOUNT_POINT")" == ext4 ]]
printf '%s\n' 'preserved fixture data' > "$LUKS_MOUNT_POINT/witness"
bash install.sh --detect > ~/detect.log 2>&1
grep -Fxq $'encrypted_volume\tinstalled' ~/detect.log
umount "$LUKS_MOUNT_POINT"
cryptsetup close "$LUKS_MAPPING_NAME"
bash install.sh --reconfigure encrypted_volume > ~/reconfigure.log 2>&1
test "$(cryptsetup luksUUID "$target")" = "$uuid"
grep -Fxq 'preserved fixture data' "$LUKS_MOUNT_POINT/witness"
bash install.sh --uninstall encrypted_volume > ~/receipt.log 2>&1
test "$(cryptsetup luksUUID "$target")" = "$uuid"
grep -Fxq 'preserved fixture data' "$LUKS_MOUNT_POINT/witness"
printf '%s\n' 'PASS: install, detect, closed-volume reconfigure, and receipt removal preserve the expected volume and data'
