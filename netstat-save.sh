#!/bin/sh -e

umask 222
mkdir -p /tmp/netstat
cd /tmp/netstat

rotate() {
    local NAME="$1"
    if ! [ -f "${NAME}.new" ]; then
        return
    fi
    local MAX=$(($2 - 1))
    for i in $(seq $MAX -1 1); do
        if [ -f "${NAME}.$i" ]; then
            mv "${NAME}.$i" "${NAME}.$(($i + 1))"
        fi
    done
    if [ -f "${NAME}" ]; then
        mv "${NAME}" "${NAME}.1"
    fi
    mv "${NAME}.new" "${NAME}"
}

cat /proc/net/dev >net-dev.new
rotate "net-dev" 10

# cat /proc/stat >stat.new
# rotate "stat" 10

exit 0
