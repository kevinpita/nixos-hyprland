set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${PI_SESSIONS_STATUS_BIN:-}" ]]; then
  status_command=("$PI_SESSIONS_STATUS_BIN")
else
  status_command=(go run "$script_dir/main.go")
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
proc_root="$tmp_dir/proc"
state_dir="$tmp_dir/state"
mkdir -p "$proc_root"/{101,202,303} "$state_dir" "$tmp_dir/work"/{app,scratch,ignored}
printf '%s\n' pi >"$proc_root/101/comm"
printf '%s\n' pi >"$proc_root/202/comm"
printf '%s\n' bash >"$proc_root/303/comm"
ln -s "$tmp_dir/work/app" "$proc_root/101/cwd"
ln -s "$tmp_dir/work/scratch" "$proc_root/202/cwd"
ln -s "$tmp_dir/work/ignored" "$proc_root/303/cwd"

cat >"$state_dir/101.json" <<'JSON'
{
  "version": 1,
  "pid": 101,
  "sessionId": "session-101",
  "label": "Writer",
  "status": "working",
  "windowAddress": "0xABC",
  "project": "app",
  "revision": 4,
  "updatedAt": 1787518800000
}
JSON
cat >"$state_dir/202.json" <<'JSON'
{
  "version": 1,
  "pid": 999,
  "sessionId": "wrong-process",
  "label": "Stale",
  "status": "done",
  "project": "wrong",
  "revision": 9,
  "updatedAt": 1787518800000
}
JSON
cat >"$state_dir/404.json" <<'JSON'
{
  "version": 1,
  "pid": 404,
  "sessionId": "stale-process",
  "label": "Not running",
  "status": "blocked",
  "project": "old",
  "revision": 2,
  "updatedAt": 1787518800000
}
JSON

output="$(
  PI_SESSIONS_PROC_ROOT="$proc_root" \
    PI_SESSIONS_STATE_DIR="$state_dir" \
    "${status_command[@]}"
)"
printf '%s' "$output" | jq -e '
  .error == null
  and (.sessions | length == 2)
  and ([.sessions[].status] == ["working", "unknown"])
  and (.sessions[0] == {
    id: "pid:101",
    pid: 101,
    sessionId: "session-101",
    label: "Writer",
    status: "working",
    windowAddress: "0xabc",
    project: "app",
    revision: 4,
    source: "extension"
  })
  and (.sessions[1].id == "pid:202")
  and (.sessions[1].label == "scratch")
  and (.sessions[1].windowAddress == "")
  and (.sessions[1].source == "process")
' >/dev/null

cat >"$state_dir/202.json" <<'JSON'
{
  "version": 1,
  "pid": 202,
  "sessionId": "session-202",
  "label": "Reviewer",
  "status": "blocked",
  "windowAddress": "not-an-address",
  "project": "scratch",
  "revision": 3,
  "updatedAt": 1787518800000
}
JSON

attention_output="$(
  PI_SESSIONS_PROC_ROOT="$proc_root" \
    PI_SESSIONS_STATE_DIR="$state_dir" \
    "${status_command[@]}"
)"
printf '%s' "$attention_output" | jq -e '
  [.sessions[].label] == ["Reviewer", "Writer"]
  and [.sessions[].status] == ["blocked", "working"]
  and [.sessions[].windowAddress] == ["", "0xabc"]
' >/dev/null

other_user_output="$(
  PI_SESSIONS_UID=99999 \
    PI_SESSIONS_PROC_ROOT="$proc_root" \
    PI_SESSIONS_STATE_DIR="$state_dir" \
    "${status_command[@]}"
)"
printf '%s' "$other_user_output" | jq -e '
  .sessions == [] and .error == null
' >/dev/null

missing_output="$(
  PI_SESSIONS_PROC_ROOT="$tmp_dir/missing-proc" \
    PI_SESSIONS_STATE_DIR="$state_dir" \
    "${status_command[@]}"
)"
printf '%s' "$missing_output" | jq -e '
  .sessions == [] and .error == "Cannot read the process table"
' >/dev/null

printf '%s\n' "pi-sessions tests passed"
