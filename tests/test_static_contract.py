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
