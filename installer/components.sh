#!/usr/bin/env bash
# components.sh - Default-off LUKS installer component declarations.

ISC_REPO_NAME="linux_luks_configuration"
ISC_REPO_LABEL="LUKS encrypted volume configuration"

declare -a ISC_COMPONENTS=(
  "cryptsetup_tools|Install LUKS tooling|off|install_cryptsetup_tools|detect_cryptsetup_tools"
  "encrypted_volume|Configure an encrypted LUKS volume|off|configure_encrypted_volume|detect_encrypted_volume"
)

