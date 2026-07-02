#!/usr/bin/env bash
# install.sh - Selectable LUKS tooling and encrypted-volume installer.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for __isc_d in "${ISC_FUNCTIONS_DIR:-}" \
               "$SCRIPT_DIR/../linux_installation_scripts_functions" \
               "$HOME/projects/linux_installation_scripts_functions"; do
  [ -n "$__isc_d" ] && [ -f "$__isc_d/component_loader.sh" ] && {
    # shellcheck source=/dev/null
    source "$__isc_d/component_loader.sh"
    break
  }
done

declare -F isc_load_helpers >/dev/null 2>&1 || \
  source <(curl -fsSL "https://raw.githubusercontent.com/mikaeltorni/linux_installation_scripts_functions/${ISC_FUNCTIONS_REF:-master}/component_loader.sh")
isc_load_helpers

# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/luks_configuration.sh"

isc_activate_components
# shellcheck source=/dev/null
source "$SCRIPT_DIR/installer/components.sh"

# luks_selection_requests_volume - true when the requested action will configure
# the encrypted volume (so the passphrase must be collected up front).
luks_selection_requests_volume() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --all|*encrypted_volume*) return 0 ;;
    esac
  done
  return 1
}

# main - dispatch the explicitly selected LUKS components.
main() {
  msg "Starting explicitly selected LUKS configuration"
  # Ask for the target device and passphrase at the very beginning when the
  # encrypted volume is selected, mirroring the master installer, so the
  # (non-interactive) volume step never blocks for input later in the run.
  # Both no-op when their LUKS_* env values are already provided.
  if luks_selection_requests_volume "$@"; then
    luks_prompt_target_device || exit 1
    luks_prompt_passphrase || exit 1
  fi
  component_main "$@"
  msg "Selected LUKS configuration completed"
}

case "${1:-}" in
  --list-components|--export-selection|--detect|--help|-h|--uninstall|--uninstall=*)
    component_main "$@"
    exit $?
    ;;
  --collect-config)
    # Used by the master installer: prompt for the target device + passphrase on
    # the terminal it owns, write the resolved env to the given file, and exit
    # without installing. The master then exports it for the Phase-2 child.
    luks_collect_config "${2:-}"
    exit $?
    ;;
esac

main "$@"

