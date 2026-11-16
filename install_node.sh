#!/bin/sh
set -e

usage() {
    echo "usage: $0 [-c 0|-v 22.23.5] [--arch x64] [--reinstall] [--dry-run]"
    echo "    -c, --channel <channel>       0 for latest LTS, 1 for previous LTS, etc."
    echo "    -v, --version <version>       specify an exact version (with or without v)"
    echo "    --arch <arch>                 override the detected Linux architecture"
    echo "    --reinstall                   reinstall even if versions are the same"
    echo "    -n, --dry-run                 check updates only"
}

node_channel=0
node_version=
node_arch=
node_reinstall=0
node_dryrun=0
while [ "$#" -gt 0 ]; do
    case "$1" in
    -c|--channel|-v|--version|--arch)
        if [ "$#" -lt 2 ] || [ -z "$2" ]; then
            echo "Missing value for $1." >&2
            usage >&2
            exit 2
        fi
        case "$1" in
        -c|--channel) node_channel="$2" ;;
        -v|--version) node_version="v${2#v}" ;;
        --arch) node_arch="$2" ;;
        esac
        shift 2
        ;;
    --reinstall) node_reinstall=1; shift ;;
    -n|--dry-run) node_dryrun=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
    esac
done

case "$node_channel" in
''|*[!0-9]*) echo "Channel must be a nonnegative integer." >&2; exit 2 ;;
esac
if [ -n "$node_version" ] && ! printf '%s\n' "$node_version" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Version must have the form 22.23.5 or v22.23.5." >&2
    exit 2
fi
if [ "$(uname -s)" != Linux ]; then
    echo "This installer supports Linux only." >&2
    exit 1
fi
if [ -z "$node_arch" ]; then
    node_arch="$(uname -m)"
fi
case "$node_arch" in
x86_64|amd64|x64) node_arch=x64 ;;
aarch64|arm64) node_arch=arm64 ;;
armv7l|ppc64le|s390x) ;;
*) echo "Unsupported Node.js architecture: $node_arch" >&2; exit 2 ;;
esac

node_mirror=https://nodejs.org/dist
node_prefix="${HOME}/.local/node"
node_local_version="(none)"
if [ -x "${node_prefix}/bin/node" ]; then
    node_local_version="$("${node_prefix}/bin/node" --version 2>/dev/null)" || node_local_version="(unavailable)"
fi
echo "+ NODE_ARCH=${node_arch}"
echo "+ NODE_OS=linux"
echo "+ Local: ${node_local_version}"
if [ -z "$node_version" ]; then
    if ! command -v jq >/dev/null 2>&1; then
        echo "jq is required to select an LTS release; alternatively use --version X.Y.Z." >&2
        exit 1
    fi
    node_version=$(curl -fsSL "${node_mirror}/index.json" |
        jq -er --arg channel "$node_channel" '
            def version: .version | ltrimstr("v") | split(".") | map(tonumber);
            [.[] | select(.lts != false)]
            | group_by(.version | split(".")[0])
            | map(max_by(version))
            | sort_by(version) | reverse
            | .[($channel | tonumber)].version // empty
        ') || {
        echo "Failed to get an LTS version for channel ${node_channel}." >&2
        exit 1
    }
fi
echo "+ Install: ${node_version}"

if [ "$node_dryrun" = 1 ]; then
    exit 0
fi
if [ "$node_reinstall" != 1 ] && [ "$node_local_version" = "$node_version" ] && [ -x "${node_prefix}/bin/npm" ]; then
    exit 0
fi

node_filename="node-${node_version}-linux-${node_arch}.tar.xz"
mkdir -p "${HOME}/.local"
node_temp_dir="$(mktemp -d "${HOME}/.local/.node-install.XXXXXX")"
cleanup() {
    if { [ -e "${node_temp_dir}/node.old" ] || [ -L "${node_temp_dir}/node.old" ]; } &&
        [ ! -e "$node_prefix" ] && [ ! -L "$node_prefix" ]; then
        mv "${node_temp_dir}/node.old" "$node_prefix" || return 1
    fi
    chmod -R u+w "$node_temp_dir"
    rm -rf "$node_temp_dir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT QUIT TERM

echo "Downloading ${node_filename}"
curl -fSL "${node_mirror}/${node_version}/${node_filename}" -o "${node_temp_dir}/${node_filename}"
curl -fsSL "${node_mirror}/${node_version}/SHASUMS256.txt" -o "${node_temp_dir}/SHASUMS256.txt"
awk -v filename="$node_filename" '$2 == filename { print; found=1 } END { if (!found) exit 1 }' \
    "${node_temp_dir}/SHASUMS256.txt" > "${node_temp_dir}/checksum.txt"
(cd "$node_temp_dir" && sha256sum --check checksum.txt)
tar -xJf "${node_temp_dir}/${node_filename}" -C "$node_temp_dir"
node_extracted="${node_temp_dir}/node-${node_version}-linux-${node_arch}"
if [ "$("${node_extracted}/bin/node" --version)" != "$node_version" ]; then
    echo "Downloaded Node.js version does not match ${node_version}." >&2
    exit 1
fi
PATH="${node_extracted}/bin:${PATH}" "${node_extracted}/bin/npm" --version >/dev/null

echo "Installing ${node_filename}"
if [ -e "$node_prefix" ] || [ -L "$node_prefix" ]; then
    if [ ! -L "$node_prefix" ]; then
        chmod -R u+w "$node_prefix"
    fi
    mv "$node_prefix" "${node_temp_dir}/node.old"
fi
mv "$node_extracted" "$node_prefix"

echo '
Add these lines to your user profile
----------

if [ -d "${HOME}/.local/node/bin" ]; then
    export PATH="${HOME}/.local/node/bin:${PATH}"
fi

----------
'

echo "+ node --version"
"${node_prefix}/bin/node" --version
echo "+ npm --version"
PATH="${node_prefix}/bin:${PATH}" "${node_prefix}/bin/npm" --version
