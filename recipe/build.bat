@echo off
echo Build MFRONT/TFEL

REM The source cache location is typically in output/src_cache
REM We need to find and copy the tarball from the source cache
set TARBALL_PATTERN=tfel-TFEL-5_0_0*.tar.gz

REM First check if tarball is already in SRC_DIR
if exist "%SRC_DIR%\tfel-TFEL-%PKG_VERSION%.tar.gz" (
    echo Found tarball in SRC_DIR
    set TARBALL_PATH=%SRC_DIR%\tfel-TFEL-%PKG_VERSION%.tar.gz
) else (
    REM Look for it in the source cache (parent of work dir)
    for %%f in ("%SRC_DIR%\..\..\src_cache\%TARBALL_PATTERN%") do (
        if exist "%%f" (
            echo Found tarball in source cache: %%f
            copy "%%f" "%SRC_DIR%\tfel-TFEL-%PKG_VERSION%.tar.gz"
            set TARBALL_PATH=%SRC_DIR%\tfel-TFEL-%PKG_VERSION%.tar.gz
        )
    )
)

if not exist "%SRC_DIR%\tfel-TFEL-%PKG_VERSION%.tar.gz" (
    echo ERROR: Source tarball not found
    echo Looking in: %SRC_DIR%
    dir "%SRC_DIR%"
    echo Looking in source cache: %SRC_DIR%\..\..\src_cache\
    dir "%SRC_DIR%\..\..\src_cache\"
    exit /b 1
)

REM Extract the source tarball
echo Extracting source tarball...
cd /d "%SRC_DIR%"
REM Windows tar has issues with symlinks - extract what we can and handle errors
tar -xzf "tfel-TFEL-%PKG_VERSION%.tar.gz" 2>tar_errors.txt
set TAR_EXIT_CODE=%ERRORLEVEL%

REM Check if extraction created the main directory
if not exist "tfel-TFEL-%PKG_VERSION%" (
    echo ERROR: Failed to extract tarball - main directory not created
    if exist tar_errors.txt type tar_errors.txt
    exit /b 1
)

REM If there were errors (likely symlink issues), check and fix them
if %TAR_EXIT_CODE% NEQ 0 (
    echo Warning: tar reported errors during extraction:
    type tar_errors.txt

    REM Fix common symlink issue: README -> README.md
    if exist "tfel-TFEL-%PKG_VERSION%\README.md" (
        if not exist "tfel-TFEL-%PKG_VERSION%\README" (
            echo Fixing README symlink by copying README.md to README...
            copy "tfel-TFEL-%PKG_VERSION%\README.md" "tfel-TFEL-%PKG_VERSION%\README" >nul
        )
    )
    echo Continuing despite tar warnings...
)

if exist tar_errors.txt del tar_errors.txt

cd /d "tfel-TFEL-%PKG_VERSION%"
echo Extraction complete, current directory: %CD%

REM Apply patches
echo Applying patches...
patch -p1 -i "%RECIPE_DIR%\patches\support_llvm-flang.patch"
if errorlevel 1 exit /b 1

patch -p1 -i "%RECIPE_DIR%\patches\fix_Issue_703.patch"
if errorlevel 1 exit /b 1

patch -p1 -i "%RECIPE_DIR%\patches\remove_numpy_init_wrap.patch"
if errorlevel 1 exit /b 1

echo Patches applied successfully

set FC=flang-new
set "CXXFLAGS=%CXXFLAGS% -Wno-error=missing-template-arg-list-after-template-kw"

REM Debug: Print environment variables
echo.
echo Environment variables:
echo PREFIX=%PREFIX%
echo LIBRARY_PREFIX=%LIBRARY_PREFIX%
echo PYTHON=%PYTHON%
echo CONDA_PY=%CONDA_PY%
echo SP_DIR=%SP_DIR%
echo.

REM Find Python library - it's named python<version>.lib, not python.lib
set PYTHON_LIB=%PREFIX%\libs\python%CONDA_PY%.lib
if not exist "%PYTHON_LIB%" (
    echo Warning: %PYTHON_LIB% not found, trying alternative locations...
    if exist "%PREFIX%\libs\python3.lib" (
        set PYTHON_LIB=%PREFIX%\libs\python3.lib
    ) else if exist "%LIBRARY_LIB%\python%CONDA_PY%.lib" (
        set PYTHON_LIB=%LIBRARY_LIB%\python%CONDA_PY%.lib
    ) else (
        echo ERROR: Cannot find Python library file
        dir "%PREFIX%\libs\"
        exit /b 1
    )
)
echo Using Python library: %PYTHON_LIB%

REM Use forward slashes for CMake paths to avoid issues
set "CMAKE_PREFIX=%PREFIX:\=/%"
set "CMAKE_LIBRARY_PREFIX=%LIBRARY_PREFIX:\=/%"
set "CMAKE_PYTHON=%PYTHON:\=/%"
set "CMAKE_PYTHON_LIB=%PYTHON_LIB:\=/%"
set "CMAKE_SP_DIR=%SP_DIR:\=/%"

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
    -D PYTHON_EXECUTABLE:FILEPATH=%CMAKE_PYTHON% ^
    -D PYTHON_LIBRARY:FILEPATH=%CMAKE_PYTHON_LIB% ^
    -D PYTHON_INCLUDE_DIRS:PATH=%CMAKE_LIBRARY_PREFIX%/include ^
    -D TFEL_PYTHON_SITE_PACKAGES_DIR:PATH=%SP_DIR% ^
    -D USE_EXTERNAL_COMPILER_FLAGS=ON

IF ERRORLEVEL 1 (
  echo ERROR: CMake configuration failed
  exit /b 1
)

echo.
echo CMake configuration successful, starting build...
echo.

REM Adjust the parallel build command as needed; for example, you can replace $(nproc) with the number of cores on your machine
cmake --build build --target install

IF ERRORLEVEL 1 (
  echo ERROR: Build failed
  if exist configure.log type configure.log
  exit /b 1
)
echo MFRONT/TFEL build complete
