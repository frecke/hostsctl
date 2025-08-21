#!/usr/bin/env zsh
# hostsctl — quick macOS /etc/hosts manager (zsh)
# https://github.com/<YOUR_GH_USERNAME>/hostsctl
#
# Features:
#   add <ip> <host> [aliases...] [-t tag]     Add or replace a tagged line
#   rm  (<host>... | --tag <tag>)             Remove hs-managed lines by host(s) or tag
#   on  <tag>                                 Uncomment hs:<tag> lines
#   off <tag>                                 Comment   hs:<tag> lines
#   list [tag]                                Show hs-managed lines (optionally by tag)
#   flush                                     Flush macOS DNS cache
#   backup                                    Copy /etc/hosts to /etc/hosts.bak-YYYYmmddHHMMSS
#
# Notes:
#   - All modifications auto-backup once per run.
#   - Only lines containing "# hs:<tag>" are touched by on/off/rm operations.

set -euo pipefail

: "${HOSTS_FILE:=/etc/hosts}"       # override in tests: HOSTS_FILE=/tmp/hosts
: "${SUDO:=sudo}"                   # override in tests: SUDO=
: "${SKIP_FLUSH:=0}"                # override in tests: SKIP_FLUSH=1
: "${DRY_RUN:=0}"                   # if 1, print changes but don't write
VERSION="0.1.0"

HS_TAG_PREFIX="# hs:"
BACKED_UP="0"

die() {
  print -u2 -- "Error: $*"
  exit 1
}
need() {
  command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"
}

backup_once() {
  [[ "$BACKED_UP" = "1" ]] && return 0
  local ts
  ts="$(date +%Y%m%d%H%M%S)"
  local bak="${HOSTS_FILE}.bak-${ts}"
  if [[ "$DRY_RUN" = "1" ]]; then
    print -- "DRY-RUN Backup: $bak"
  else
    $SUDO cp "$HOSTS_FILE" "$bak"
    print -- "Backup: $bak"
  fi
  BACKED_UP="1"
}

flush_dns() {
  [[ "$SKIP_FLUSH" = "1" ]] && {
    print -- "DNS cache flush skipped (SKIP_FLUSH=1)."
    return 0
  }
  if pgrep -q mDNSResponder; then
    $SUDO killall -HUP mDNSResponder || true
  fi
  command -v dscacheutil >/dev/null 2>&1 && $SUDO dscacheutil -flushcache || true
  print -- "DNS cache flushed."
}

usage() {
  cat <<'EOF'
Usage:
  hostsctl add <ip> <host> [alias ...] [-t tag]
  hostsctl rm (<host>... | --tag <tag>)
  hostsctl on <tag>
  hostsctl off <tag>
  hostsctl list [tag]
  hostsctl flush
  hostsctl backup
  hostsctl --version

Examples:
  hostsctl add 1.2.3.4 example.com www.example.com -t demo
  hostsctl off demo
  hostsctl on demo
  hostsctl rm --tag demo
  hostsctl list
EOF
}

ensure_tmp() {
  [[ -n "${_TMP_FILE:-}" && -f "${_TMP_FILE}" ]] || _TMP_FILE="$(mktemp)"
}
finish() {
  [[ -n "${_TMP_FILE:-}" && -f "${_TMP_FILE}" ]] && rm -f "${_TMP_FILE}" || true
}
trap finish EXIT

ensure_tools() {
  need awk
  need sed
  need grep
  need mktemp
}

sanitize_tag() {
  local t="${1:-default}"
  print -- "${t:l}" | sed -E 's/[^a-z0-9]+/./g'
}

cmd_list() {
  local tag="${1:-}"
  if [[ -n "$tag" ]]; then
    tag="$(sanitize_tag "$tag")"
    grep -E "^[# ]*.*${HS_TAG_PREFIX}${tag}\b" "$HOSTS_FILE" | sed -E 's/^[ ]+//'
  else
    grep -E "${HS_TAG_PREFIX}" "$HOSTS_FILE" | sed -E 's/^[ ]+//'
  fi
}

cmd_add() {
  (( $# >= 2 )) || { usage; die "add: need <ip> <host> [aliases...] [-t tag]"; }
  local ip="$1"
  shift
  local tag="default"
  local names=()
  while (( $# )); do
    case "$1" in
      -t)
        shift
        tag="${1:-default}"
        shift
        ;;
      *)
        names+=("$1")
        shift
        ;;
    esac
  done
  (( ${#names[@]} > 0 )) || die "add: no hostnames provided"
  tag="$(sanitize_tag "$tag")"

  backup_once
  ensure_tmp
  cp "$HOSTS_FILE" "$_TMP_FILE"

  local pat=""
  for n in "${names[@]}"; do
    pat+="|[[:space:]]${n//\./\\.}([[:space:]]|$)"
  done
  pat="${pat#|}"
  awk -v re="$pat" '
    {
      if ($0 ~ /# hs:/) {
        if ($0 ~ re) next;
      }
      print $0
    }' "$_TMP_FILE" > "${_TMP_FILE}.new"

  mv "${_TMP_FILE}.new" "$_TMP_FILE"

  local joined_names=""
  for n in "${names[@]}"; do
    if [[ -z "$joined_names" ]]; then
      joined_names="$n"
    else
      joined_names="$joined_names $n"
    fi
  done
  local line
  line="$ip\t$joined_names\t${HS_TAG_PREFIX}${tag}"
  if [[ "$DRY_RUN" = "1" ]]; then
    print -- "$line" >> "$_TMP_FILE"
    print -- "DRY-RUN: would write to ${HOSTS_FILE}"
  else
    print -- "$line" >> "$_TMP_FILE"
    $SUDO cp "$_TMP_FILE" "$HOSTS_FILE"
  fi
  print -- "Added: $line"
  flush_dns
}

cmd_rm() {
  (( $# >= 1 )) || { usage; die "rm: need one or more hosts OR --tag <tag>"; }
  local mode="hosts"
  local tag=""
  local hosts=()
  if [[ "${1:-}" == "--tag" ]]; then
    mode="tag"
    shift
    tag="${1:-}"
    [[ -n "$tag" ]] || die "rm --tag: missing tag"
    tag="$(sanitize_tag "$tag")"
  else
    hosts=("$@")
  fi

  backup_once
  ensure_tmp
  cp "$HOSTS_FILE" "$_TMP_FILE"

  if [[ "$mode" == "tag" ]]; then
    awk -v t="${HS_TAG_PREFIX}${tag}" '
      $0 ~ t { next }
      { print $0 }
    ' "$_TMP_FILE" > "${_TMP_FILE}.new"
  else
    local pat=""
    for n in "${hosts[@]}"; do
      pat+="|[[:space:]]${n//\./\\.}([[:space:]]|$)"
    done
    pat="${pat#|}"
    awk -v re="$pat" '
      {
        if ($0 ~ /# hs:/) {
          if ($0 ~ re) next;
        }
        print $0
      }' "$_TMP_FILE" > "${_TMP_FILE}.new"
  fi

  mv "${_TMP_FILE}.new" "$_TMP_FILE"
  if [[ "$DRY_RUN" = "1" ]]; then
    print -- "DRY-RUN: would write to ${HOSTS_FILE}"
  else
    $SUDO cp "$_TMP_FILE" "$HOSTS_FILE"
  fi
  print -- "Removed."
  flush_dns
}

cmd_toggle() {
  local action="$1"
  shift
  (( $# == 1 )) || { usage; die "$action: need <tag>"; }
  local tag
  tag="$(sanitize_tag "$1")"

  backup_once
  ensure_tmp
  cp "$HOSTS_FILE" "$_TMP_FILE"

  if [[ "$action" == "off" ]]; then
    awk -v t="${HS_TAG_PREFIX}${tag}" '
      index($0,t) {
        if ($0 ~ /^[[:space:]]*#/) { print $0; next }
        print "# " $0; next
      }
      { print $0 }
    ' "$_TMP_FILE" > "${_TMP_FILE}.new"
  else
    awk -v t="${HS_TAG_PREFIX}${tag}" '
      index($0,t) {
        sub(/^[[:space:]]*#[[:space:]]*/,"",$0)
        print $0; next
      }
      { print $0 }
    ' "$_TMP_FILE" > "${_TMP_FILE}.new"
  fi

  mv "${_TMP_FILE}.new" "$_TMP_FILE"
  if [[ "$DRY_RUN" = "1" ]]; then
    print -- "DRY-RUN: would write to ${HOSTS_FILE}"
  else
    $SUDO cp "$_TMP_FILE" "$HOSTS_FILE"
  fi
  print -- "${action:u} ${tag}"
  flush_dns
}

main() {
  ensure_tools
  local cmd="${1:-}"
  if (( $# )); then shift; fi
  case "$cmd" in
    add) cmd_add "$@" ;;
    rm) cmd_rm "$@" ;;
    on) cmd_toggle "on" "$@" ;;
    off) cmd_toggle "off" "$@" ;;
    list) cmd_list "$@" ;;
    flush) flush_dns ;;
    backup) backup_once ;;
    -v | --version | version) print -- "$VERSION" ;;
    "" | -h | --help | help) usage ;;
    *)
      usage
      die "unknown command: $cmd"
      ;;
  esac
}
main "$@"
