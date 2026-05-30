#!/usr/bin/env bash
# Do not use `set -e`; checks aggregate pass/warn/fail state and report all findings.
set -u -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE_CHECKS=false
FAILURES=0
WARNINGS=0

for arg in "$@"; do
  case "$arg" in
    --live)
      LIVE_CHECKS=true
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/homelab-readiness-check.sh [--live]

Runs local, read-only readiness checks for the homelab GitOps repo.
Pass --live to also run read-only kubectl/flux cluster checks.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

info() { printf '[INFO] %s\n' "$*"; }
pass() { printf '[PASS] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
fail() { printf '[FAIL] %s\n' "$*"; FAILURES=$((FAILURES + 1)); }

have() {
  command -v "$1" >/dev/null 2>&1
}

run_build() {
  local target="$1"

  if have kustomize; then
    kustomize build "$target"
  elif have kubectl; then
    kubectl kustomize "$target"
  else
    return 127
  fi
}

build_quiet() {
  run_build "$1" >/dev/null
}

check_required_files() {
  local files=(
    "README.md"
    "docs/operations-baseline-2026-05-28.md"
    "docs/postgres-backup-restore.md"
    "docs/public-ingress-exposure.md"
    "docs/resilience-topology.md"
    "docs/secrets-workflow.md"
    "infra/metrics-server/kustomization.yaml"
    "infra/longhorn/helmrelease.yaml"
    "infra/networking/cloudflared/config/config.yaml"
  )

  info "Checking required operations docs and manifests"
  for file in "${files[@]}"; do
    if [[ -f "$ROOT_DIR/$file" ]]; then
      pass "$file exists"
    else
      fail "$file is missing"
    fi
  done
}

check_kustomize_roots() {
  local all_file roots_file root rel parent siblings output

  info "Building discovered Kustomize roots"
  if ! have kustomize && ! have kubectl; then
    warn "kustomize and kubectl are unavailable; skipping manifest build checks"
    return
  fi

  all_file="$(mktemp)"
  roots_file="$(mktemp)"
  trap "rm -f '$all_file' '$roots_file'" RETURN

  find "$ROOT_DIR" \
    \( -path "$ROOT_DIR/.git" -o -path "$ROOT_DIR/workspace" \) -prune -o \
    -type f -name 'kustomization.yaml' -print \
    | sed "s|/kustomization.yaml$||" \
    | sort -u > "$all_file"

  # Convention-based de-duplication:
  #   Skip a `*/base` directory when a sibling `*/overlays/*/kustomization.yaml`
  #   exists, because the overlay's build transitively exercises the base.
  #   Bases without any overlay are still built so they cannot bypass checks.
  while IFS= read -r root; do
    if [[ "$root" == "$ROOT_DIR" ]]; then
      rel="."
    else
      rel="${root#"$ROOT_DIR"/}"
    fi
    if [[ "$rel" == */base ]]; then
      parent="${root%/base}"
      siblings="$(find "$parent/overlays" -mindepth 2 -maxdepth 2 -name 'kustomization.yaml' -print 2>/dev/null | head -1)"
      if [[ -n "$siblings" ]]; then
        continue
      fi
    fi
    printf '%s\n' "$rel" >> "$roots_file"
  done < "$all_file"

  if [[ ! -s "$roots_file" ]]; then
    fail "no kustomization.yaml roots discovered"
    return
  fi

  while IFS= read -r rel; do
    if output="$(cd "$ROOT_DIR" && build_quiet "$rel" 2>&1)"; then
      pass "$rel builds"
    else
      fail "$rel build failed: ${output//$'\n'/; }"
    fi
  done < "$roots_file"
}

write_sorted_unique() {
  sort -u | sed '/^[[:space:]]*$/d' > "$1"
}

require_yq() {
  local check_name="$1"

  if have yq; then
    return 0
  fi

  fail "yq is required for $check_name"
  return 1
}

check_flux_inventory() {
  local inventory_file output count

  info "Checking Flux Kustomization inventory"
  if ! require_yq "Flux Kustomization inventory"; then
    return
  fi

  inventory_file="$(mktemp)"
  trap "rm -f '$inventory_file'" RETURN

  if output="$(find "$ROOT_DIR/clusters/mugiwara" -type f -name '*.yaml' -print0 \
    | xargs -0 yq -r 'select(.apiVersion == "kustomize.toolkit.fluxcd.io/v1" and .kind == "Kustomization") | [.metadata.name, .spec.path] | @tsv' 2>&1 \
    > "$inventory_file")"; then
    :
  else
    warn "could not parse Flux Kustomization inventory: ${output//$'\n'/; }"
    return
  fi

  count="$(wc -l < "$inventory_file" | tr -d ' ')"
  if [[ "$count" -eq 0 ]]; then
    fail "no Flux Kustomization resources found under clusters/mugiwara"
    return
  fi
  pass "found $count Flux Kustomization resources under clusters/mugiwara"

  while IFS=$'\t' read -r name path; do
    local resolved

    if [[ -z "$name" || -z "$path" ]]; then
      fail "Flux Kustomization inventory contains an entry without name or spec.path"
      continue
    fi

    resolved="${path#./}"
    if [[ -d "$ROOT_DIR/$resolved" ]]; then
      pass "Flux Kustomization $name path exists: $path"
    else
      fail "Flux Kustomization $name path is missing: $path"
      continue
    fi

    if [[ -f "$ROOT_DIR/$resolved/kustomization.yaml" ]]; then
      pass "Flux Kustomization $name path has kustomization.yaml"
    else
      fail "Flux Kustomization $name path lacks kustomization.yaml: $path"
    fi
  done < "$inventory_file"
}

check_exposure_inventory() {
  local ingress_count tunnel_count ingress_hosts tunnel_hosts doc_hosts missing_tunnel missing_ingress undocumented output err_file

  info "Checking ingress and Cloudflared exposure inventory"
  ingress_count="$(find "$ROOT_DIR/apps" "$ROOT_DIR/infra" -path '*/ingress*.yaml' -type f 2>/dev/null | wc -l | tr -d ' ')"
  tunnel_count="$(grep -E '^[[:space:]]*-?[[:space:]]*hostname:' "$ROOT_DIR/infra/networking/cloudflared/config/config.yaml" 2>/dev/null | wc -l | tr -d ' ')"

  if [[ "$ingress_count" -gt 0 ]]; then
    pass "found $ingress_count ingress manifest files"
  else
    fail "no ingress manifest files found"
  fi

  if [[ "$tunnel_count" -gt 0 ]]; then
    pass "found $tunnel_count Cloudflared hostname routes"
  else
    warn "no Cloudflared hostname routes found"
  fi

  if [[ -s "$ROOT_DIR/docs/public-ingress-exposure.md" ]]; then
    pass "public ingress exposure doc is present"
  else
    fail "public ingress exposure doc is missing or empty"
  fi

  if ! require_yq "ingress to Cloudflared hostname cross-reference"; then
    return
  fi

  if ! have kustomize && ! have kubectl; then
    warn "kustomize and kubectl are unavailable; skipping ingress to Cloudflared hostname cross-reference"
    return
  fi

  ingress_hosts="$(mktemp)"
  tunnel_hosts="$(mktemp)"
  doc_hosts="$(mktemp)"
  missing_tunnel="$(mktemp)"
  missing_ingress="$(mktemp)"
  undocumented="$(mktemp)"
  err_file="$(mktemp)"
  trap "rm -f '$ingress_hosts' '$tunnel_hosts' '$doc_hosts' '$missing_tunnel' '$missing_ingress' '$undocumented' '$err_file'" RETURN

  if output="$(cd "$ROOT_DIR" && {
      run_build clusters/mugiwara/apps 2>/dev/null
      run_build infra/monitoring 2>/dev/null
    } | yq -r '
      if .kind == "Ingress" then
        .spec.rules[]?.host // ""
      elif .kind == "HelmRelease" then
        .spec.values.grafana.ingress.hosts[]? // ""
      else
        ""
      end
    ' 2>"$err_file" | write_sorted_unique "$ingress_hosts")"; then
    :
  else
    warn "could not extract built ingress hostnames from apps and monitoring manifests: $(tr '\n' ';' < "$err_file") ${output//$'\n'/; }"
    return
  fi

  if output="$(yq -r '.ingress[]?.hostname // ""' "$ROOT_DIR/infra/networking/cloudflared/config/config.yaml" 2>"$err_file" | write_sorted_unique "$tunnel_hosts")"; then
    :
  else
    warn "could not extract Cloudflared hostname routes: $(tr '\n' ';' < "$err_file") ${output//$'\n'/; }"
    return
  fi

  grep -Eo '[[:alnum:].-]+\.jamaguchi\.xyz' "$ROOT_DIR/docs/public-ingress-exposure.md" 2>/dev/null | write_sorted_unique "$doc_hosts"

  comm -23 "$ingress_hosts" "$tunnel_hosts" > "$missing_tunnel"
  comm -13 "$ingress_hosts" "$tunnel_hosts" > "$missing_ingress"

  if [[ -s "$missing_tunnel" ]]; then
    comm -23 "$missing_tunnel" "$doc_hosts" > "$undocumented"
    if [[ -s "$undocumented" ]]; then
      fail "undocumented ingress hosts without Cloudflared routes: $(paste -sd ', ' "$undocumented")"
    else
      warn "documented ingress hosts without Cloudflared routes: $(paste -sd ', ' "$missing_tunnel")"
    fi
  else
    pass "all built ingress hosts have Cloudflared routes"
  fi

  if [[ -s "$missing_ingress" ]]; then
    comm -23 "$missing_ingress" "$doc_hosts" > "$undocumented"
    if [[ -s "$undocumented" ]]; then
      fail "undocumented Cloudflared routes without built ingress hosts: $(paste -sd ', ' "$undocumented")"
    else
      warn "documented Cloudflared routes without built ingress hosts: $(paste -sd ', ' "$missing_ingress")"
    fi
  else
    pass "all Cloudflared routes have built ingress hosts"
  fi
}

check_workload_hygiene() {
  local built_file image_file missing_requests_file output

  info "Checking workload image tags and resource requests"
  if ! require_yq "workload hygiene checks"; then
    return
  fi

  if ! have kustomize && ! have kubectl; then
    warn "kustomize and kubectl are unavailable; skipping workload hygiene checks"
    return
  fi

  built_file="$(mktemp)"
  image_file="$(mktemp)"
  missing_requests_file="$(mktemp)"
  trap "rm -f '$built_file' '$image_file' '$missing_requests_file'" RETURN

  if output="$(cd "$ROOT_DIR" && {
      run_build clusters/mugiwara/apps
      run_build infra/monitoring
    } > "$built_file" 2>&1)"; then
    :
  else
    warn "could not build manifests for workload hygiene checks: ${output//$'\n'/; }"
    return
  fi

  yq -r '
    select(.kind == "Deployment" or .kind == "StatefulSet" or .kind == "DaemonSet")
    | .metadata.namespace as $ns
    | .metadata.name as $name
    | .kind as $kind
    | .spec.template.spec.containers[]?
    | [$kind, ($ns // "default"), $name, .name, .image] | @tsv
  ' "$built_file" > "$image_file"

  if [[ ! -s "$image_file" ]]; then
    warn "no Deployment/StatefulSet/DaemonSet container images found in built manifests"
  else
    while IFS=$'\t' read -r kind namespace workload container image; do
      local image_name tag_part

      image_name="${image##*/}"
      tag_part="${image_name##*:}"
      if [[ -z "$image" ]]; then
        fail "$kind $namespace/$workload container $container has no image"
      elif [[ "$image" == *"@sha256:"* ]]; then
        pass "$kind $namespace/$workload container $container image is digest-pinned"
      elif [[ "$image_name" != *:* ]]; then
        fail "$kind $namespace/$workload container $container image has no tag: $image"
      elif [[ "$tag_part" == "latest" ]]; then
        fail "$kind $namespace/$workload container $container image uses :latest: $image"
      else
        pass "$kind $namespace/$workload container $container image has explicit tag"
      fi
    done < "$image_file"
  fi

  yq -r '
    select(.kind == "Deployment" or .kind == "StatefulSet")
    | .metadata.namespace as $ns
    | .metadata.name as $name
    | .kind as $kind
    | .spec.template.spec.containers[]?
    | select(.resources.requests == null)
    | [$kind, ($ns // "default"), $name, .name] | @tsv
  ' "$built_file" > "$missing_requests_file"

  if [[ -s "$missing_requests_file" ]]; then
    while IFS=$'\t' read -r kind namespace workload container; do
      warn "$kind $namespace/$workload container $container has no resources.requests"
    done < "$missing_requests_file"
  else
    pass "all built Deployment/StatefulSet containers define resources.requests"
  fi
}

check_backup_posture() {
  local overlays=(keycloak ledger-dev metabase)

  info "Checking backup and restore posture"
  for overlay in "${overlays[@]}"; do
    local cronjob="$ROOT_DIR/apps/postgres/overlays/$overlay/backup-cronjob.yaml"
    local kustomization="$ROOT_DIR/apps/postgres/overlays/$overlay/kustomization.yaml"

    if [[ -f "$cronjob" ]]; then
      pass "$overlay Postgres backup CronJob exists"
    else
      fail "$overlay Postgres backup CronJob is missing"
    fi

    if grep -q 'backup-cronjob.yaml' "$kustomization" 2>/dev/null; then
      pass "$overlay includes backup CronJob in kustomization"
    else
      fail "$overlay kustomization does not include backup-cronjob.yaml"
    fi

    if [[ -f "$cronjob" ]] && have yq; then
      if [[ -n "$(yq -r 'select(.kind == "CronJob") | .spec.schedule // ""' "$cronjob")" ]]; then
        pass "$overlay Postgres backup CronJob has a schedule"
      else
        fail "$overlay Postgres backup CronJob is missing kind CronJob or spec.schedule"
      fi

      if [[ -n "$(yq -r 'select(.kind == "CronJob") | .. | select(has("persistentVolumeClaim")?) | .persistentVolumeClaim.claimName // ""' "$cronjob")" ]] || grep -Eq 'S3|AWS|BUCKET|OBJECT' "$cronjob"; then
        pass "$overlay Postgres backup CronJob has a backup target"
      else
        fail "$overlay Postgres backup CronJob has no PVC or object-store target"
      fi

      if [[ -n "$(yq -r 'select(.kind == "CronJob") | .spec.successfulJobsHistoryLimit // ""' "$cronjob")" ]] && [[ -n "$(yq -r 'select(.kind == "CronJob") | .spec.failedJobsHistoryLimit // ""' "$cronjob")" ]]; then
        pass "$overlay Postgres backup CronJob has job history limits"
      else
        fail "$overlay Postgres backup CronJob is missing successfulJobsHistoryLimit or failedJobsHistoryLimit"
      fi
    elif [[ -f "$cronjob" ]]; then
      warn "yq unavailable; skipping $overlay Postgres backup CronJob shape checks"
    fi
  done

  if grep -q 'backupTarget:' "$ROOT_DIR/infra/longhorn/helmrelease.yaml" 2>/dev/null; then
    pass "Longhorn backup target is configured"
  else
    fail "Longhorn backup target is not configured"
  fi

  if [[ -s "$ROOT_DIR/docs/postgres-backup-restore.md" ]]; then
    pass "Postgres backup/restore runbook is present"
  else
    fail "Postgres backup/restore runbook is missing or empty"
  fi
}

check_secret_examples() {
  info "Checking secret workflow guardrails"
  if [[ -s "$ROOT_DIR/docs/secrets-workflow.md" ]]; then
    pass "secrets workflow doc is present"
  else
    fail "secrets workflow doc is missing or empty"
  fi

  if find "$ROOT_DIR" -path "$ROOT_DIR/.git" -prune -o -type f -iname '*secret*.yaml' ! -iname '*example*.yaml' -print | grep -q .; then
    warn "non-example secret-like YAML files exist; inspect before committing raw secrets"
  else
    pass "no non-example secret-like YAML files detected"
  fi

  scan_plaintext_secret_patterns
}

is_example_path() {
  case "$1" in
    *example*|*.example.yaml|*.example.yml) return 0 ;;
  esac
  return 1
}

scan_plaintext_secret_patterns() {
  local candidates rel hits=0

  info "Scanning YAML for plaintext secret patterns (file paths only, no values)"

  candidates="$(mktemp)"
  trap "rm -f '$candidates'" RETURN

  find "$ROOT_DIR" \
    \( -path "$ROOT_DIR/.git" -o -path "$ROOT_DIR/workspace" \) -prune -o \
    -type f \( -iname '*.yaml' -o -iname '*.yml' \) -print > "$candidates"

  while IFS= read -r f; do
    rel="${f#"$ROOT_DIR"/}"

    if grep -qE -- '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----' "$f" 2>/dev/null; then
      fail "PEM private key block found in: $rel"
      hits=$((hits + 1))
    fi

    if grep -qE 'AKIA[0-9A-Z]{16}' "$f" 2>/dev/null; then
      fail "AWS access key id pattern found in: $rel"
      hits=$((hits + 1))
    fi

    if is_example_path "$f"; then
      continue
    fi

    if grep -qE '^kind:[[:space:]]*Secret[[:space:]]*$' "$f" 2>/dev/null \
       && ! grep -qE '^kind:[[:space:]]*SealedSecret[[:space:]]*$' "$f" 2>/dev/null; then
      fail "non-example kind: Secret manifest committed in plaintext: $rel"
      hits=$((hits + 1))
    fi
  done < "$candidates"

  if [[ "$hits" -eq 0 ]]; then
    pass "no plaintext secret patterns detected"
  fi
}

check_live_cluster() {
  local repo_flux live_flux missing_live missing_repo

  info "Running optional live cluster checks"
  if ! have kubectl; then
    warn "kubectl unavailable; skipping live checks"
    return
  fi

  if kubectl get nodes >/dev/null 2>&1; then
    pass "kubectl can reach the cluster"
    kubectl get nodes
    kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
  else
    warn "kubectl cannot reach the cluster with the current context"
  fi

  if have flux; then
    flux get kustomizations -n flux-system || warn "flux kustomization check failed"
    flux get sources git -n flux-system || warn "flux source check failed"

    if have yq && flux get kustomizations -n flux-system -o json >/dev/null 2>&1; then
      repo_flux="$(mktemp)"
      live_flux="$(mktemp)"
      missing_live="$(mktemp)"
      missing_repo="$(mktemp)"
      trap "rm -f '$repo_flux' '$live_flux' '$missing_live' '$missing_repo'" RETURN

      find "$ROOT_DIR/clusters/mugiwara" -type f -name '*.yaml' -print0 \
        | xargs -0 yq -r 'select(.apiVersion == "kustomize.toolkit.fluxcd.io/v1" and .kind == "Kustomization") | .metadata.name // ""' \
        | write_sorted_unique "$repo_flux"
      flux get kustomizations -n flux-system -o json \
        | yq -r '.items[]?.metadata.name // ""' \
        | write_sorted_unique "$live_flux"

      comm -23 "$repo_flux" "$live_flux" > "$missing_live"
      comm -13 "$repo_flux" "$live_flux" > "$missing_repo"

      if [[ -s "$missing_live" ]]; then
        fail "Flux Kustomizations declared in repo but missing live: $(paste -sd ', ' "$missing_live")"
      else
        pass "all repo Flux Kustomizations are present live"
      fi

      if [[ -s "$missing_repo" ]]; then
        fail "live Flux Kustomizations missing from repo inventory: $(paste -sd ', ' "$missing_repo")"
      else
        pass "all live Flux Kustomizations are present in repo inventory"
      fi
    fi
  else
    warn "flux CLI unavailable; skipping Flux live checks"
  fi
}

main() {
  cd "$ROOT_DIR" || exit 1
  check_required_files
  check_kustomize_roots
  check_flux_inventory
  check_exposure_inventory
  check_workload_hygiene
  check_backup_posture
  check_secret_examples

  if [[ "$LIVE_CHECKS" == true ]]; then
    check_live_cluster
  else
    info "Skipping live cluster checks; pass --live to enable read-only kubectl/flux checks"
  fi

  printf '\nSummary: %s failure(s), %s warning(s)\n' "$FAILURES" "$WARNINGS"
  if [[ "$FAILURES" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
