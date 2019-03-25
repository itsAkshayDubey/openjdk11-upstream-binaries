#!/bin/bash
set -e

UPDATE="11.0.3"
BUILD=4
NAME="openjdk-11u-${UPDATE}+${BUILD}"
TARBALL_BASE_NAME="OpenJDK11U"
EA_SUFFIX="_ea"
PLATFORM="x64_linux"
TARBALL_VERSION="${UPDATE}_${BUILD}${EA_SUFFIX}"
TARBALL_NAME="${TARBALL_BASE_NAME}-${PLATFORM}_${TARBALL_VERSION}"
SOURCE_NAME="${TARBALL_BASE_NAME}-sources_${TARBALL_VERSION}"
# Release string for the vendor. Use the GA date.
VENDOR="18.9"

CLONE_URL=https://hg.openjdk.java.net/jdk-updates/jdk11u
TAG="jdk-${UPDATE}+${BUILD}"

clone() {
  url=$1
  tag=$2
  targetdir=$3
  if [ -d $targetdir ]; then
    echo "Target directory $targetdir already exists. Skipping clone"
    return
  fi
  hg clone -u $tag $url $targetdir
}

build() {
  rm -rf build

  # Add patch to be able to build on EL 6
  wget https://bugs.openjdk.java.net/secure/attachment/81704/JDK-8219879.jdk11.export.patch
  patch -p1 < JDK-8219879.jdk11.export.patch
  
  # Create a source tarball archive corresponding to the
  # binary build
  tar -c -z -f ../${SOURCE_NAME}.tar.gz --exclude-vcs --exclude='**.patch*' --exclude='overall-build.log' .
  # NOTE: Boot JDK built with build-openjdk10.sh
  for debug in release slowdebug; do
    bash configure \
       --with-boot-jdk="/opt/openjdk-10u10.0.1-b10/" \
       --with-debug-level="$debug" \
       --with-conf-name="$debug" \
       --enable-unlimited-crypto \
       --with-version-build=$BUILD \
       --with-version-pre="" \
       --with-version-opt="" \
       --with-vendor-version-string="$VENDOR" \
       --with-native-debug-symbols=external \
       --disable-warnings-as-errors
    target="bootcycle-images"
    if [ "${debug}_" == "slowdebug_" ]; then
      target="images"
    fi
    make LOG=debug CONF=$debug $target
    # Package it up
    pushd build/$debug/images
      if [ "${debug}_" == "slowdebug_" ]; then
	NAME="$NAME-$debug"
	TARBALL_NAME="$TARBALL_NAME-$debug"
      fi
      mv jdk $NAME    
      tar -c -f ${TARBALL_NAME}.tar $NAME --exclude='**.debuginfo'
      gzip ${TARBALL_NAME}.tar
      tar -c -f ${TARBALL_NAME}-debuginfo.tar $(find ${NAME}/ -name \*.debuginfo)
      gzip ${TARBALL_NAME}-debuginfo.tar
      mv $NAME jdk
    popd
  done
  mv ../${SOURCE_NAME}.tar.gz build/
  find $(pwd)/build -name \*.tar.gz
}

clone $CLONE_URL $TAG jdk11u
pushd jdk11u
  build
popd
