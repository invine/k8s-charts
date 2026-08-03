#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

assert_single_line() {
  local rendered="$1"
  local expected="$2"
  local chart="$3"
  local matches

  matches="$(grep -Fxc -- "$expected" <<<"$rendered" || true)"
  if [[ "$matches" != "1" ]]; then
    printf 'expected exactly one %q line in %s, found %s\n' "$expected" "$chart" "$matches" >&2
    return 1
  fi
}

test_chart() {
  local chart="$1"
  local schedule_name="$2"
  local included_namespace="$3"
  local chart_path="$repo_root/$chart"
  local default_render
  local true_render
  local default_non_target
  local true_non_target

  default_render="$(helm template snapshot-regression "$chart_path" \
    --show-only templates/velero-schedule.yaml)"
  true_render="$(helm template snapshot-regression "$chart_path" \
    --show-only templates/velero-schedule.yaml \
    --set backup.snapshotVolumes=true)"

  assert_single_line "$default_render" "kind: Schedule" "$chart"
  assert_single_line "$default_render" "  name: $schedule_name" "$chart"
  assert_single_line "$default_render" "  namespace: velero" "$chart"
  assert_single_line "$default_render" "  schedule: 0 0 * * *" "$chart"
  assert_single_line "$default_render" "    ttl: 168h0m0s" "$chart"
  assert_single_line "$default_render" "    storageLocation: default" "$chart"
  assert_single_line "$default_render" "      - $included_namespace" "$chart"
  assert_single_line "$default_render" "    snapshotVolumes: false" "$chart"
  assert_single_line "$true_render" "    snapshotVolumes: true" "$chart"

  default_non_target="$(sed 's/^    snapshotVolumes: .*/    snapshotVolumes: <target>/' <<<"$default_render")"
  true_non_target="$(sed 's/^    snapshotVolumes: .*/    snapshotVolumes: <target>/' <<<"$true_render")"
  diff -u <(printf '%s\n' "$default_non_target") <(printf '%s\n' "$true_non_target")

  helm lint "$chart_path" >/dev/null
  printf 'PASS %s\n' "$chart"
}

test_chart echo-chart echo-app-backup-schedule echo
test_chart openvpn-chart ovpn-backup-schedule openvpn
test_chart vaultwarden-chart vaultwarden-backup-schedule vaultwarden
