@echo off
echo Build MFRONT/TFEL

set FC=flang-new
set "CXXFLAGS=%CXXFLAGS% -Wno-error=missing-template-arg-list-after-template-kw"

cmake -B build . -G "Ninja" -Wno-dev ^
    %CMAKE_ARGS% ^
    -D CMAKE_CXX_COMPILER=clang-cl ^
    -D CMAKE_C_COMPILER=clang-cl ^
    -D CMAKE_LINKER=lld-link ^
    -D CMAKE_NM=llvm-nm ^
    -D CMAKE_BUILD_TYPE=Release ^
    -D enable-fortran=ON ^
    -D enable-python-bindings=ON ^
    -D enable-cyrano=ON ^
    -D enable-aster=ON ^
    -D enable-lsdyna=ON ^
    -D enable-abaqus=ON ^
    -D enable-calculix=ON ^
    -D enable-comsol=ON ^
    -D enable-diana-fea=ON ^
    -D enable-ansys=ON ^
    -D disable-website=ON ^
    -D enable-portable-build=ON ^
    -D Python_ADDITIONAL_VERSIONS=%CONDA_PY% ^
    -D enable-python=ON ^
    -D PYTHON_EXECUTABLE:FILEPATH=%PYTHON% ^
    -D PYTHON_LIBRARY:FILEPATH=%PREFIX%\libs\python%CONDA_PY%.lib ^
    -D PYTHON_INCLUDE_DIRS:PATH=%LIBRARY_PREFIX%\include ^
    -D TFEL_PYTHON_SITE_PACKAGES_DIR:PATH=%SP_DIR% ^
    -D USE_EXTERNAL_COMPILER_FLAGS=ON

REM Adjust the parallel build command as needed; for example, you can replace $(nproc) with the number of cores on your machine
cmake --build build --target install

IF ERRORLEVEL 1 (
  type configure.log
  exit /b 1
)
echo MFRONT/TFEL build complete
