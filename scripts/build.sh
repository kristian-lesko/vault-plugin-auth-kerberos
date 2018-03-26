#!/usr/bin/env bash

TOOL=vault-plugin-auth-kerberos
#
# This script builds the application from source for multiple platforms.
set -e

# Get the parent directory of where this script is.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
DIR="$( cd -P "$( dirname "$SOURCE" )/.." && pwd )"

# Change into that directory
cd "$DIR"

# Set build tags
BUILD_TAGS="${BUILD_TAGS}:-${TOOL}"

# Determine the arch/os combos we're building for
XC_ARCH=${XC_ARCH:-"amd64"}
XC_OS=${XC_OS:-linux}
XC_OSARCH=${XC_OSARCH:-"linux/amd64"}

GOPATH=${GOPATH:-$(go env GOPATH)}
case $(uname) in
    CYGWIN*)
        GOPATH="$(cygpath $GOPATH)"
        ;;
esac

# Delete the old dir
echo "==> Removing old directory..."
rm -f bin/*
rm -rf pkg/*
mkdir -p bin/

# If its dev mode, only build for our self
if [ "${VAULT_DEV_BUILD}x" != "x" ]; then
    XC_OS="linux"
    XC_ARCH="amd64"
    XC_OSARCH="linux/amd64"
fi

# Build!
echo "==> Building..."
gox \
    -osarch="${XC_OSARCH}" \
    -ldflags "-X github.com/hashicorp/${TOOL}/version.GitCommit='e0d8d6ea67d8515dcbe6c81fe44268eb3fe00b10'" \
    -output "pkg/{{.OS}}_{{.Arch}}/${TOOL}" \
    -tags="${BUILD_TAGS}" \
    ./cmd/$TOOL

# Move all the compiled things to the $GOPATH/bin
OLDIFS=$IFS
IFS=: MAIN_GOPATH=($GOPATH)
IFS=$OLDIFS

# Copy our OS/Arch to the bin/ directory
DEV_PLATFORM="./pkg/linux_amd64"
for F in $(find ${DEV_PLATFORM} -mindepth 1 -maxdepth 1 -type f); do
    cp ${F} bin/
    cp ${F} ${MAIN_GOPATH}/bin/
done

if [ "${VAULT_DEV_BUILD}x" = "x" ]; then
    # Zip and copy to the dist dir
    echo "==> Packaging..."
    for PLATFORM in $(find ./pkg -mindepth 1 -maxdepth 1 -type d); do
        OSARCH=$(basename ${PLATFORM})
        echo "--> ${OSARCH}"

        pushd $PLATFORM >/dev/null 2>&1
        zip ../${OSARCH}.zip ./*
        popd >/dev/null 2>&1
    done
fi

# Done!
echo
echo "==> Results:"
ls -hl bin/
