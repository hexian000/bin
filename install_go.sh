#!/bin/sh
set -e

CHANNEL=1
while [ -n "$1" ]; do
    case "$1" in
    "-c")
        CHANNEL="$2"
        shift
        ;;
    "-v")
        VERSION="go$2"
        shift
        ;;
    "--arch")
        GOARCH="$2"
        shift
        ;;
    "--force")
        OVERWRITE=1
        ;;
    *)
        echo "usage: $0 [-c 0] [-v 1.19.5] [--arch amd64] [--force]" >&2
        exit 1
        ;;
    esac
    shift
done

API="https://go.dev/dl/?mode=json"
MIRROR="https://dl.google.com/go"

guess_arch() {
    case "$(arch)" in
    x86_64) echo "amd64" ;;
    x86) echo "386" ;;
    aarch64) echo "arm64" ;;
    armv7l) echo "armv6l" ;;
    *) echo "$1" ;;
    esac
}
if [ -z "${GOARCH}" ]; then
    GOARCH="$(guess_arch)"
fi
GOOS="linux"
echo "+ GOARCH=${GOARCH}"
echo "+ GOOS=${GOOS}"
if command -v go >/dev/null 2>&1; then
    eval $(go env)
fi
if [ -z "${GOVERSION}" ]; then
    GOVERSION="(none)"
fi
echo "+ Local: ${GOVERSION}"
if [ -z "${VERSION}" ] && command -v jq >/dev/null 2>&1; then
    VERSION=$(curl -sL "${API}" |
        jq -r "[.[] | select(.stable)][${CHANNEL}] | .version")
fi
if [ -z "${VERSION}" ]; then
    echo "Failed to get version." >&2
    exit 1
fi
echo "+ Install: ${VERSION}"

if [ "${OVERWRITE}" != 1 ] && [ "${GOVERSION}" = "${VERSION}" ]; then
    exit 0
fi

GOVERSION="${VERSION}"
FILENAME="${GOVERSION}.${GOOS}-${GOARCH}.tar.gz"

WORKDIR="${HOME}/.local"
mkdir -p "${WORKDIR}"

if [ -d "${WORKDIR}/go" ]; then
    echo "Removing existing installation"
    chmod -R +w "${WORKDIR}/go"
    rm -rf "${WORKDIR}/go"
fi
echo "Installing ${GOVERSION}.${GOOS}-${GOARCH}"
curl -SL -- "${MIRROR}/${FILENAME}" | tar xzC "${WORKDIR}"
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
