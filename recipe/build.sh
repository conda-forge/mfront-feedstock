#!/bin/bash
set -e

echo "**************** M F R O N T  B U I L D  S T A R T S  H E R E ****************"

# The source cache location is typically in output/src_cache
# We need to find and copy the tarball from the source cache
TARBALL_NAME="tfel-TFEL-${PKG_VERSION}.tar.gz"

# First check if tarball is already in SRC_DIR
if [ -f "${SRC_DIR}/${TARBALL_NAME}" ]; then
    echo "Found tarball in SRC_DIR"
else
    # Look for it in the source cache (parent of work dir)
    CACHED_TARBALL=$(find "${SRC_DIR}/../../src_cache" -name "tfel-TFEL-5_0_0*.tar.gz" 2>/dev/null | head -n 1)
    if [ -n "$CACHED_TARBALL" ] && [ -f "$CACHED_TARBALL" ]; then
        echo "Found tarball in source cache: $CACHED_TARBALL"
        cp "$CACHED_TARBALL" "${SRC_DIR}/${TARBALL_NAME}"
    else
        echo "ERROR: Source tarball not found"
        echo "Looking in: ${SRC_DIR}"
        ls -la "${SRC_DIR}"
        echo "Looking in source cache: ${SRC_DIR}/../../src_cache/"
        ls -la "${SRC_DIR}/../../src_cache/" || true
        exit 1
    fi
fi

# Extract the source tarball
echo "Extracting source tarball..."
cd "${SRC_DIR}"
tar -xzf "${TARBALL_NAME}"
cd "tfel-TFEL-${PKG_VERSION}"
echo "Extraction complete, current directory: $(pwd)"

# https://docs.conda.io/projects/conda-build/en/latest/resources/compiler-tools.html#an-aside-on-cmake-and-sysroots
if [[ "${target_platform}" == osx-* ]]; then
  export LDFLAGS="$LDFLAGS -lm -lpthread -ldl -lz -lomp"
else
  export LDFLAGS="$LDFLAGS -L$PREFIX/lib -lm -lpthread -lrt -ldl -lz -lgomp"
fi

export LIBPATH="$PREFIX/lib $LIBPATH"
cmake ${CMAKE_ARGS} -Wno-dev \
         -DCMAKE_BUILD_TYPE=Release \
         -Dlocal-castem-header=ON \
         -Denable-fortran=ON \
         -Denable-aster=ON \
         -Denable-cyrano=ON \
         -Denable-lsdyna=ON \
         -Denable-abaqus=ON \
         -Denable-calculix=ON \
         -Denable-comsol=ON \
         -Denable-diana-fea=ON \
         -Denable-ansys=ON \
         -DPython_ADDITIONAL_VERSIONS=${CONDA_PY} \
         -DPYTHON_INCLUDE_DIRS=${PREFIX}/include \
         -DPYTHON_INCLUDE_DIR=${PREFIX}/include/python${PY_VER} \
         -DPYTHON_LIBRARY="${PREFIX}/lib/libpython${PY_VER}${SHLIB_EXT}" \
         -DCOMPILER_CXXFLAGS="-I${PREFIX}/include -w" \
         -Denable-python=ON \
         -Denable-python-bindings=ON \
         -Denable-numpy-support=ON \
         -Denable-portable-build=ON \
         -DCMAKE_INSTALL_PREFIX=$PREFIX \
         -DUSE_EXTERNAL_COMPILER_FLAGS=ON \
         -S . -B build

cmake --build ./build --config Release -j ${CPU_COUNT}
cmake --install ./build --verbose

echo "**************** M F R O N T  B U I L D  E N D S  H E R E ****************"
