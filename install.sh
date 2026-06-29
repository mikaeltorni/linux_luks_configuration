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

# main - dispatch the explicitly selected LUKS components.
main() {
  msg "Starting explicitly selected LUKS configuration"
  component_main "$@"
  msg "Selected LUKS configuration completed"
}

case "${1:-}" in
  --list-components|--detect|--help|-h|--uninstall|--uninstall=*)
    component_main "$@"
    exit $?
    ;;
esac

main "$@"

