#!/bin/bash

# When building 32-bits on 64-bit system this flags is not automatically set by conda-build
if [ $ARCH == 32 -a "${OSX_ARCH:-notosx}" == "notosx" ]; then
    export CFLAGS="${CFLAGS} -m32"
    export CXXFLAGS="${CXXFLAGS} -m32"
fi

BUILD_DIR=${SRC_DIR}/build
mkdir ${BUILD_DIR}
cd ${BUILD_DIR}


PYTHON_INCLUDE_DIR=$(${PYTHON} -c 'import sysconfig;print("{0}".format(sysconfig.get_path("platinclude")))')
PYTHON_LIBRARY=$(${PYTHON} -c 'import sysconfig;print("{0}/{1}".format(*map(sysconfig.get_config_var, ("LIBDIR", "LDLIBRARY"))))')

ITK_TAG="v5.1b01"
CMAKE_ARGS="${CMAKE_ARGS} \
    -D ITK_GIT_TAG:STRING=${ITK_TAG} \
    -D ITKV4_COMPATIBILITY:BOOL=ON \
    -D ITK_LEGACY_REMOVE:BOOL=OFF \
    -D ITK_USE_FFTWD:BOOL=ON \
    -D ITK_USE_FFTWF:BOOL=ON \
    -D ITK_USE_SYSTEM_FFTW:BOOL=ON \
    -D Module_SCIFIO:BOOL=ON \
    "

cmake \
    -G Ninja \
    ${CMAKE_ARGS} \
    -D "CMAKE_CXX_FLAGS:STRING=-fvisibility=hidden -fvisibility-inlines-hidden ${CXXFLAGS}" \
    -D "CMAKE_C_FLAGS:STRING=-fvisibility=hidden ${CFLAGS}" \
    -D "CMAKE_FIND_ROOT_PATH:PATH=${PREFIX}" \
    -D "CMAKE_FIND_ROOT_PATH_MODE_INCLUDE:STRING=ONLY" \
    -D "CMAKE_FIND_ROOT_PATH_MODE_LIBRARY:STRING=ONLY" \
    -D "CMAKE_FIND_ROOT_PATH_MODE_PROGRAM:STRING=NEVER" \
    -D "CMAKE_FIND_ROOT_PATH_MODE_PACKAGE:STRING=ONLY" \
    -D "CMAKE_FIND_FRAMEWORK:STRING=NEVER" \
    -D "CMAKE_FIND_APPBUNDLE:STRING=NEVER" \
    -D "CMAKE_PROGRAM_PATH=${BUILD_PREFIX}" \
    -D SimpleITK_GIT_PROTOCOL:STRING=git \
    -D SimpleITK_BUILD_DISTRIBUTE:BOOL=ON \
    -D SimpleITK_BUILD_STRIP:BOOL=ON \
    -D SimpleITK_EXPLICIT_INSTANTIATION:BOOL=OFF \
    -D CMAKE_BUILD_TYPE:STRING=RELEASE \
    -D BUILD_SHARED_LIBS:BOOL=OFF \
    -D BUILD_TESTING:BOOL=OFF \
    -D BUILD_EXAMPLES:BOOL=OFF \
    -D WRAP_DEFAULT:BOOL=OFF \
    -D WRAP_PYTHON:BOOL=ON \
    -D SimpleITK_USE_SYSTEM_SWIG:BOOL=ON \
    -D SimpleITK_PYTHON_USE_VIRTUALENV:BOOL=OFF \
    -D ITK_USE_SYSTEM_JPEG:BOOL=ON \
    -D ITK_USE_SYSTEM_PNG:BOOL=ON \
    -D ITK_USE_SYSTEM_TIFF:BOOL=ON \
    -D ITK_USE_SYSTEM_ZLIB:BOOL=ON \
    -D "PYTHON_EXECUTABLE:FILEPATH=${PYTHON}" \
    -D "PYTHON_INCLUDE_DIR:PATH=${PYTHON_INCLUDE_DIR}" \
    -D "PYTHON_LIBRARY=${PYTHON_LIBRARY_DIR}" \
    "${SRC_DIR}/SuperBuild"

cmake --build  . --config Release

( cd ${BUILD_DIR}/SimpleITK-build/Wrapping/Python &&
      ${PYTHON} Packaging/setup.py install)


# patch SimpleITK install with SCIFIO jars

PKG_DIR=$(${PYTHON} -c "from __future__ import print_function; import SimpleITK; import os; print(os.path.dirname(os.path.abspath(SimpleITK.__file__)))")
( cd ${BUILD_DIR} && cp -rv ./ITK-build/lib/jars/ ${PKG_DIR} )


simpleitk_patch="
import os

# path to bioformats_package.jar and scifio-itk-bridge.jar
os.environ['SCIFIO_PATH'] = os.path.dirname(os.path.abspath(SimpleITK.__file__))+'/jars'

#increase the maximum JVM heap size to 16Gb, working with large images
os.environ['JAVA_FLAGS'] = '-Xmx16g'

del os
"

echo "${simpleitk_patch}" >> ${PKG_DIR}/__init__.py
