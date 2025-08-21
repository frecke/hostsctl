#!/usr/bin/env bats

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  export HOSTS_FILE="${TMPDIR}/hosts"
  export SUDO=""              # avoid sudo in tests
  export SKIP_FLUSH=1         # no DNS flush in CI
  printf "# base\n127.0.0.1 localhost\n" > "$HOSTS_FILE"
  cp "$BATS_TEST_DIRNAME/../bin/hostsctl.zsh" "$TMPDIR/hostsctl.zsh"
  chmod +x "$TMPDIR/hostsctl.zsh"
}

@test "add creates a tagged line" {
  run "$TMPDIR/hostsctl.zsh" add 1.2.3.4 example.com www.example.com -t demo
  [ "$status" -eq 0 ]
  grep -q "# hs:demo" "$HOSTS_FILE"
  grep -q "1.2.3.4" "$HOSTS_FILE"
  grep -q "example.com" "$HOSTS_FILE"
}

@test "off comments tagged lines; on uncomments" {
  "$TMPDIR/hostsctl.zsh" add 1.2.3.4 example.com -t demo
  "$TMPDIR/hostsctl.zsh" off demo
  run grep -E "^[[:space:]]*#.*hs:demo" "$HOSTS_FILE"
  [ "$status" -eq 0 ]
  "$TMPDIR/hostsctl.zsh" on demo
  run grep -E "^[[:space:]]*#.*hs:demo" "$HOSTS_FILE"
  [ "$status" -ne 0 ]
}

@test "rm by tag removes lines" {
  "$TMPDIR/hostsctl.zsh" add 1.2.3.4 example.com -t demo
  "$TMPDIR/hostsctl.zsh" rm --tag demo
  run grep -q "hs:demo" "$HOSTS_FILE"
  [ "$status" -ne 0 ]
}
