#!/bin/sh
set -e

CHANNEL=0
while [ -n "$1" ]; do
    case "$1" in
    "-c")
        CHANNEL="$2"
        shift
        ;;
    "--version"|"-v")
        VERSION="go$2"
        shift
        ;;
    "--arch")
        GOARCH="$2"
        shift
        ;;
    "--reinstall")
        REINSTALL=1
        ;;
    "--channel"|"-c")
        CHANNEL="$2"
        shift
        ;;
    "--dry-run"|"-n")
        DRYRUN=1
        ;;
    *)
        echo "usage: $0 [-c 0|-v 1.19.5] [--arch amd64] [--force] [--dry-run]" >&2
        echo "    -c, --channel                 0 for current, 1 for previous" >&2
        echo "    -v, --version <version>       manual specify version" >&2
        echo "    --arch <arch>                 manual specify architecture" >&2
        echo "    --reinstall                   reinstall even if versions are the same" >&2
        echo "    -n, --dry-run                 check updates only" >&2
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

if [ "${DRYRUN}" = 1 ]; then
    exit 0
fi

if [ "${REINSTALL}" != 1 ] && [ "${GOVERSION}" = "${VERSION}" ]; then
    exit 0
fi

GOVERSION="${VERSION}"
FILENAME="${GOVERSION}.${GOOS}-${GOARCH}.tar.gz"

PREFIX="${HOME}/.local"
mkdir -p "${PREFIX}"
TMPDIR="$(mktemp -dp "${PREFIX}")"
trap "rm -rf \"${TMPDIR}\" || true" EXIT HUP INT QUIT TERM

echo "Downloading ${GOVERSION}.${GOOS}-${GOARCH}"
curl -SL -- "${MIRROR}/${FILENAME}" | tar xzC "${TMPDIR}"

echo "Installing ${GOVERSION}.${GOOS}-${GOARCH}"
if [ -e "${PREFIX}/go" ]; then
    chmod -R +w "${PREFIX}/go"
    mv "${PREFIX}/go" "${TMPDIR}/go.old"
    mv "${TMPDIR}/go" "${PREFIX}/go"
else
    mv "${TMPDIR}/go" "${PREFIX}/go"
fi
chmod -R a-w "${PREFIX}/go"

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
export GOPROXY=https://goproxy.io,direct

----------
'

echo "+ go version"
"${PREFIX}/go/bin/go" version
