#!/usr/bin/env python3
"""Static safety and integration checks that never execute installer code."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def read(relative_path: str) -> str:
    """Return a repository file as text without sourcing or executing it."""
    return ROOT.joinpath(relative_path).read_text(encoding="utf-8")


def test_components_are_explicitly_opt_in() -> None:
    """No LUKS action may be selected by the default installation path."""
    manifest = read("installer/components.sh")

    assert "cryptsetup_tools|Install LUKS tooling|off|" in manifest
    assert "encrypted_volume|Configure an encrypted LUKS volume|off|" in manifest
    assert "|on|" not in manifest


def test_entrypoint_uses_component_framework() -> None:
    """The repository must expose the shared selectable-component contract."""
    installer = read("install.sh")

    assert "isc_activate_components" in installer
    assert 'source "$SCRIPT_DIR/installer/components.sh"' in installer
    assert 'component_main "$@"' in installer


def test_formatting_requires_explicit_confirmation() -> None:
    """Formatting must remain behind exact, separately named acknowledgements."""
    implementation = read("lib/luks_configuration.sh")

    assert 'LUKS_ALLOW_FORMAT:-' in implementation
    assert 'LUKS_CONFIRM_DEVICE:-' in implementation
    assert 'LUKS_ALLOW_WIPE_SIGNATURES:-' in implementation
    assert '${LUKS_CONFIRM_DEVICE:-}' in implementation
    assert '!= "$device"' in implementation


def test_target_validation_rejects_live_or_mounted_devices() -> None:
    """The implementation must guard the running system and mounted media."""
    implementation = read("lib/luks_configuration.sh")

    assert 'test -b "$device"' in implementation
    assert 'findmnt -rn -S "$device"' in implementation
    assert 'lsblk -sno PATH "$root_source"' in implementation
    assert 'wipefs --no-act "$device"' in implementation


def test_persistent_configuration_is_idempotent() -> None:
    """crypttab and fstab entries must be replaced by stable tagged records."""
    implementation = read("lib/luks_configuration.sh")

    assert "# linux_luks_configuration:" in implementation
    assert "replace_tagged_line" in implementation
    assert 'cryptsetup luksUUID "$device"' in implementation


def test_passphrase_collected_up_front_and_used_non_interactively() -> None:
    """The passphrase is prompted up front and fed to cryptsetup non-interactively.

    Under the master installer stdin is detached, so a mid-run cryptsetup prompt
    would hang. The encrypted-volume step must collect LUKS_PASSPHRASE first and
    pass it via --key-file -."""
    implementation = read("lib/luks_configuration.sh")
    installer = read("install.sh")

    assert "luks_prompt_passphrase()" in implementation
    assert "LUKS_PASSPHRASE" in implementation
    # Format and open must not prompt interactively.
    assert "--verify-passphrase" not in implementation
    assert "luksFormat --type luks2 --batch-mode --key-file -" in implementation
    assert "cryptsetup open --key-file -" in implementation
    # Standalone installer prompts at the beginning when the volume is selected.
    assert "luks_selection_requests_volume" in installer
    assert "luks_prompt_passphrase" in installer


def test_components_declare_repo_identity() -> None:
    """components.sh must set ISC_REPO_NAME; the shared run path references it
    unconditionally (under set -u), so omitting it aborts every component run
    with 'ISC_REPO_NAME: unbound variable'."""
    manifest = read("installer/components.sh")
    assert 'ISC_REPO_NAME="linux_luks_configuration"' in manifest
    assert "ISC_REPO_LABEL=" in manifest


def test_target_device_prompted_explicitly_not_inferred() -> None:
    """The interactive path must require an explicitly typed, re-confirmed device
    (never inferred from root or the first disk), satisfying the safety boundary,
    and expose --collect-config for the master to delegate to."""
    implementation = read("lib/luks_configuration.sh")
    installer = read("install.sh")

    assert "luks_prompt_target_device()" in implementation
    assert "luks_collect_config()" in implementation
    # Explicit entry + exact re-type confirmation; no auto-selection of a disk.
    assert "[ ! -b " in implementation or "[ -b " in implementation
    assert "Re-type the device path to confirm" in implementation
    # Must not auto-pick a device (no `head -1`/`awk NR==1` style first-disk grab).
    assert "LUKS_TARGET_DEVICE=" in implementation
    # Standalone prompts both device and passphrase up front; master delegates.
    assert "luks_prompt_target_device" in installer
    assert "--collect-config" in installer
