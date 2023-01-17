#!/bin/sh
set -e

if [ -n "$1" ]; then
    LATEST="go$1"
fi

API="https://go.dev/dl/?mode=json"
MIRROR="https://dl.google.com/go"

get_goarch() {
    case "$(arch)" in
    x86_64) echo "amd64" ;;
    x86) echo "386" ;;
    aarch64) echo "arm64" ;;
    armv7l) echo "armv6l" ;;
    *) echo "$1" ;;
    esac
}

GOARCH="$(get_goarch)"
echo "+ GOARCH=${GOARCH}"
GOOS="linux"
echo "+ GOOS=${GOOS}"
if command -v go >/dev/null 2>&1; then
    eval $(go env)
fi
if [ -z "${GOVERSION}" ]; then
    GOVERSION="(none)"
fi
echo "+ Installed: ${GOVERSION}"
if [ -z "${LATEST}" ]; then
    LATEST=$(curl -sL "${API}" |
        jq -r '[.[] | select(.stable)][0] | .version')
fi
if [ -z "${LATEST}" ]; then
    echo "Failed to get latest version." >&2
    exit 1
fi
echo "+ Latest: ${LATEST}"

if [ "${GOVERSION}" = "${LATEST}" ]; then
    exit 0
fi

GOVERSION="${LATEST}"
FILENAME="${GOVERSION}.${GOOS}-${GOARCH}.tar.gz"

WORKDIR="${HOME}/.local"
mkdir -p "${WORKDIR}"

if [ -d "${WORKDIR}/go" ]; then
    echo "Removing existing installation"
    chmod -R a+w "${WORKDIR}/go"
    rm -rf "${WORKDIR}/go"
fi
echo "Installing ${GOVERSION}.${GOOS}-${GOARCH}"
curl -sSL -- "${MIRROR}/${FILENAME}" | tar xzC "${WORKDIR}"
chmod -R a-w "${WORKDIR}/go"

echo '
Add these lines to your user profile
----------

# GOROOT
if [ -d "${HOME}/.local/go" ]; then
    GOROOT="${HOME}/.local/go"
    PATH="${PATH}:${GOROOT}/bin"
fi
# GOPATH
if [ -d "${HOME}/go" ]; then
    GOPATH="${HOME}/go"
    PATH="${PATH}:${GOPATH}/bin"
fi
export GOPROXY=https://proxy.golang.com.cn,direct

----------
'

set -x
"${WORKDIR}/go/bin/go" version
