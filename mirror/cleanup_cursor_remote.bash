#!/bin/bash
## use at CLIENT — after sourcing a context (e.g. source mirror/context/<name>.bash)
##
## Removes the Cursor remote server install so the next connection can download a
## fresh build (helps with stale / mismatched server vs desktop app).
## Cleans both:
##   (1) the SSH host user home:  ~/.cursor-server
##   (2) the context container:  <container_cursor_home>/.cursor-server  (default: /root, like install_vscode.bash)
##
## Disconnect Cursor from the remote (or close the window) before running.

set -euo pipefail

DRY_RUN=0
ASSUME_YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    -y|--yes)     ASSUME_YES=1 ;;
    -h|--help)
      sed -n '1,25p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

USERNAME="${username:-}"
HOSTNAME="${hostname:-}"
SSHPORT="${sshport:-22}"
CONTAINER_NAME="${container_name:-}"
# Directory inside the container that holds ~/.cursor-server (default: root home)
CONTAINER_CURSOR_HOME="${container_cursor_home:-/root}"

die() { echo "Error: $*" >&2; exit 1; }

[ -n "$USERNAME" ] || die "username is not set (source a mirror/context/*.bash first)"
[ -n "$HOSTNAME" ] || die "hostname is not set (source a mirror/context/*.bash first)"
[ -n "$CONTAINER_NAME" ] || die "container_name is not set (source a mirror/context/*.bash first)"

echo "Context: remove Cursor remote server for"
echo "  SSH:     ${USERNAME}@${HOSTNAME} -p ${SSHPORT}"
echo "  Docker:  ${CONTAINER_NAME} (server dir in container: ${CONTAINER_CURSOR_HOME}/.cursor-server)"
echo

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] Would run remote cleanup (host + docker exec). No changes made."
  exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  echo "This deletes ~/.cursor-server on the host and ${CONTAINER_CURSOR_HOME}/.cursor-server in the container."
  read -r -p "Continue? [y/N] " ans
  case "$ans" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

# Remote host: Cursor SSH server lives under the login user's home.
# shellcheck disable=SC2029
ssh -p "$SSHPORT" "${USERNAME}@${HOSTNAME}" bash -s <<'HOSTSCRIPT'
set -e
pkill -f "${HOME}/.cursor-server" 2>/dev/null || true
rm -rf "${HOME}/.cursor-server"
echo "Host: removed ~/.cursor-server"
HOSTSCRIPT

# Container: path must match the user Cursor uses inside docker (often root).
# shellcheck disable=SC2029
ssh -p "$SSHPORT" "${USERNAME}@${HOSTNAME}" \
  "docker exec ${CONTAINER_NAME} bash -c 'pkill -f \"${CONTAINER_CURSOR_HOME}/.cursor-server\" 2>/dev/null || true; rm -rf \"${CONTAINER_CURSOR_HOME}/.cursor-server\"'"

echo "Container: removed ${CONTAINER_CURSOR_HOME}/.cursor-server"

echo
echo "Done. Reconnect with Cursor; it will install a new remote server."
