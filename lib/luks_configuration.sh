#!/usr/bin/env bash
# luks_configuration.sh - Guarded LUKS2 volume provisioning and persistence.
#
# Public component functions are called by installer/components.sh. Provisioning
# requires LUKS_TARGET_DEVICE, LUKS_CONFIRM_DEVICE, and LUKS_ALLOW_FORMAT=YES for
# a new container. Existing signatures require the additional explicit
# LUKS_ALLOW_WIPE_SIGNATURES=YES acknowledgement.

# luks_prompt_passphrase - Collect the LUKS passphrase once, up front, into the
# LUKS_PASSPHRASE environment variable. The volume step then formats/opens the
# device non-interactively (cryptsetup --key-file -), so a passphrase prompt
# never appears mid-install when stdin is detached under the master installer.
# No-op when LUKS_PASSPHRASE is already set; errors when no terminal is available.
luks_prompt_passphrase() {
  [ -n "${LUKS_PASSPHRASE:-}" ] && return 0
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    msg "ERROR: LUKS passphrase required; set LUKS_PASSPHRASE or run on a terminal"
    return 1
  fi
  local first second
  while true; do
    printf 'Enter LUKS passphrase for the encrypted volume: ' >&2
    IFS= read -rs first; printf '\n' >&2
    printf 'Confirm LUKS passphrase: ' >&2
    IFS= read -rs second; printf '\n' >&2
    if [ -z "$first" ]; then
      printf 'Passphrase must not be empty.\n' >&2
    elif [ "$first" != "$second" ]; then
      printf 'Passphrases did not match; try again.\n' >&2
    else
      break
    fi
  done
  export LUKS_PASSPHRASE="$first"
}

# install_cryptsetup_tools - install the distro-supported LUKS and ext4 tools.
install_cryptsetup_tools() {
  msg "Installing LUKS tooling from Ubuntu repositories"
  apt_install cryptsetup cryptsetup-initramfs e2fsprogs util-linux
}

# detect_cryptsetup_tools - return success when required packages are installed.
detect_cryptsetup_tools() {
  local package_name
  for package_name in cryptsetup cryptsetup-initramfs e2fsprogs util-linux; do
    [ "$(dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null || true)" = \
      "install ok installed" ] || return 1
  done
  return 0
}

# require_luks_commands - validate runtime tools before inspecting a target.
require_luks_commands() {
  local command_name
  for command_name in cryptsetup findmnt lsblk wipefs blkid mkfs.ext4 mount; do
    need_cmd "$command_name"
  done
}

# canonical_luks_device - print and validate the explicitly configured device.
canonical_luks_device() {
  local requested="${LUKS_TARGET_DEVICE:-}"
  if [ -z "$requested" ]; then
    msg "ERROR: LUKS_TARGET_DEVICE must name the disposable-VM test device"
    return 1
  fi

  local device
  device="$(readlink -f -- "$requested")"
  if ! test -b "$device"; then
    msg "ERROR: LUKS target is not a block device: $requested"
    return 1
  fi

  printf '%s\n' "$device"
}

# assert_safe_luks_target - reject mounted devices and the running root chain.
# Args: $1 canonical block-device path.
assert_safe_luks_target() {
  local device="$1"
  local root_source ancestor mountpoint

  if findmnt -rn -S "$device" | grep -q .; then
    msg "ERROR: Refusing mounted LUKS target: $device"
    return 1
  fi

  while IFS= read -r mountpoint; do
    if [ -n "$mountpoint" ]; then
      msg "ERROR: Refusing target with mounted descendants: $device"
      return 1
    fi
  done < <(lsblk -nrpo MOUNTPOINT "$device")

  root_source="$(findmnt -nro SOURCE /)"
  if [ -b "$root_source" ]; then
    while IFS= read -r ancestor; do
      if [ "$(readlink -f -- "$ancestor")" = "$device" ]; then
        msg "ERROR: Refusing device that backs the running root filesystem: $device"
        return 1
      fi
    done < <(lsblk -sno PATH "$root_source")
  fi
}

# validate_luks_options - validate mapping and mount values used in system files.
validate_luks_options() {
  local mapping_name="$1" mount_point="$2"
  if [[ ! "$mapping_name" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,126}$ ]]; then
    msg "ERROR: LUKS_MAPPING_NAME must contain only safe mapper-name characters"
    return 1
  fi
  if [[ "$mount_point" != /* || "$mount_point" == "/" || "$mount_point" =~ [[:space:]] ]]; then
    msg "ERROR: LUKS_MOUNT_POINT must be an absolute non-root path without whitespace"
    return 1
  fi
}

# require_format_confirmation - enforce exact acknowledgements for a new LUKS volume.
# Args: $1 canonical block-device path.
require_format_confirmation() {
  local device="$1" signatures
  if [ "${LUKS_ALLOW_FORMAT:-}" != "YES" ]; then
    msg "ERROR: Set LUKS_ALLOW_FORMAT=YES to acknowledge destructive formatting"
    return 1
  fi
  if [ "${LUKS_CONFIRM_DEVICE:-}" != "$device" ]; then
    msg "ERROR: LUKS_CONFIRM_DEVICE must exactly equal the canonical target: $device"
    return 1
  fi

  signatures="$(wipefs --no-act "$device" 2>/dev/null || true)"
  if [ -n "$signatures" ] && [ "${LUKS_ALLOW_WIPE_SIGNATURES:-}" != "YES" ]; then
    msg "ERROR: Existing signatures detected; set LUKS_ALLOW_WIPE_SIGNATURES=YES after review"
    return 1
  fi
}

# require_target_confirmation - require the canonical device for every volume action.
# Args: $1 canonical block-device path.
require_target_confirmation() {
  local device="$1" confirmation="${LUKS_CONFIRM_DEVICE:-}"
  if [ "$confirmation" != "$device" ]; then
    msg "ERROR: LUKS_CONFIRM_DEVICE must exactly equal the canonical target: $device"
    return 1
  fi
}

# open_luks_mapping - open the target or verify an existing mapping.
# Args: $1 device, $2 mapping name. Prints "opened" when it opens the mapping.
open_luks_mapping() {
  local device="$1" mapping_name="$2" mapped_device="/dev/mapper/$2"
  if [ -e "$mapped_device" ]; then
    local active_device
    active_device="$(cryptsetup status "$mapping_name" | awk '$1 == "device:" { print $2; exit }')"
    if [ "$(readlink -f -- "$active_device")" != "$device" ]; then
      msg "ERROR: Existing mapping $mapping_name points to another device"
      return 1
    fi
    return 0
  fi

  msg "Opening LUKS mapping $mapping_name with the pre-collected passphrase"
  printf '%s' "${LUKS_PASSPHRASE:-}" | cryptsetup open --key-file - "$device" "$mapping_name"
  printf 'opened\n'
}

# replace_tagged_line - atomically replace one repository-owned config record.
# Args: $1 file, $2 unique tag, $3 complete replacement line.
replace_tagged_line() {
  local target_file="$1" tag="$2" replacement="$3" temporary
  temporary="$(mktemp "$(dirname "$target_file")/.linux-luks.XXXXXX")"

  if [ -f "$target_file" ]; then
    grep -Fv -- "$tag" "$target_file" >"$temporary" || true
  fi
  printf '%s\n' "$replacement" >>"$temporary"
  install -m 0644 "$temporary" "$target_file"
  rm -f "$temporary"
}

# persist_luks_mapping - add idempotent crypttab and fstab records.
# Args: $1 device, $2 mapping name, $3 mount point.
persist_luks_mapping() {
  local device="$1" mapping_name="$2" mount_point="$3" uuid tag
  uuid="$(cryptsetup luksUUID "$device")"
  tag="# linux_luks_configuration:$mapping_name"

  [ -e /etc/crypttab ] || install -m 0644 /dev/null /etc/crypttab
  [ -e /etc/crypttab.linux_luks_configuration.bak ] || \
    cp -a /etc/crypttab /etc/crypttab.linux_luks_configuration.bak
  [ -e /etc/fstab.linux_luks_configuration.bak ] || \
    cp -a /etc/fstab /etc/fstab.linux_luks_configuration.bak

  replace_tagged_line /etc/crypttab "$tag" \
    "$mapping_name UUID=$uuid none luks $tag"
  replace_tagged_line /etc/fstab "$tag" \
    "/dev/mapper/$mapping_name $mount_point ext4 defaults,nofail 0 2 $tag"
  msg "Recorded $mapping_name in /etc/crypttab and /etc/fstab"
}

# configure_encrypted_volume - create or reuse one LUKS2/ext4 data volume.
configure_encrypted_volume() {
  if ! is_root; then
    msg "ERROR: Encrypted-volume configuration requires sudo"
    return 1
  fi

  require_luks_commands
  local device mapping_name mount_point mapping_state filesystem
  device="$(canonical_luks_device)"
  mapping_name="${LUKS_MAPPING_NAME:-secure_data}"
  mount_point="${LUKS_MOUNT_POINT:-/mnt/secure_data}"
  validate_luks_options "$mapping_name" "$mount_point"
  assert_safe_luks_target "$device"
  require_target_confirmation "$device"

  # The passphrase is collected up front (luks_prompt_passphrase) so the format
  # and open steps run non-interactively. Re-prompt here only as a fallback when
  # a terminal is available; under the master installer it is already set.
  luks_prompt_passphrase || return 1

  if ! cryptsetup isLuks "$device"; then
    require_format_confirmation "$device"
    msg "Formatting confirmed target as LUKS2: $device"
    printf '%s' "$LUKS_PASSPHRASE" | cryptsetup luksFormat --type luks2 --batch-mode --key-file - "$device"
  else
    msg "Reusing existing LUKS container: $device"
  fi

  mapping_state="$(open_luks_mapping "$device" "$mapping_name")"
  filesystem="$(blkid -o value -s TYPE "/dev/mapper/$mapping_name" || true)"
  if [ -z "$filesystem" ]; then
    msg "Creating ext4 filesystem inside $mapping_name"
    if ! mkfs.ext4 -L "$mapping_name" "/dev/mapper/$mapping_name"; then
      [ "$mapping_state" = "opened" ] && cryptsetup close "$mapping_name"
      return 1
    fi
  elif [ "$filesystem" != "ext4" ]; then
    msg "ERROR: Existing mapped filesystem is $filesystem, expected ext4"
    [ "$mapping_state" = "opened" ] && cryptsetup close "$mapping_name"
    return 1
  fi

  persist_luks_mapping "$device" "$mapping_name" "$mount_point"
  install -d -m 0755 "$mount_point"
  if ! findmnt -rn "$mount_point" >/dev/null; then
    if ! mount "/dev/mapper/$mapping_name" "$mount_point"; then
      [ "$mapping_state" = "opened" ] && cryptsetup close "$mapping_name"
      return 1
    fi
  fi
  msg "Encrypted volume is mounted at $mount_point"
}

# detect_encrypted_volume - detect only an explicitly named existing LUKS target.
detect_encrypted_volume() {
  local requested="${LUKS_TARGET_DEVICE:-}"
  command -v cryptsetup >/dev/null 2>&1 && \
    [ -n "$requested" ] && [ -b "$requested" ] && cryptsetup isLuks "$requested"
}
