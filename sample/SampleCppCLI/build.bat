@echo off

set "VS_TOOLS=C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x64"
set "VS_LIB=C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.50.35717\lib\x64"
set "SDK_INC=C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\ucrt"
set "VS_INC=C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.50.35717\include"
set "SDK_LIB=C:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0"

set "SCRIPT_DIR=%~dp0"
set "DLL_PATH=%SCRIPT_DIR%..\..\bin\WinPdfGenerator.dll"
set "LIB_PATH=%SCRIPT_DIR%..\..\bin\WinPdfGenerator.lib"
set "OUT_DIR=%SCRIPT_DIR%..\..\bin"

if not exist "%DLL_PATH%" (
    echo Error: No se encontro %DLL_PATH%
    exit /b 1
)

if not exist "%LIB_PATH%" (
    echo Error: No se encontro %LIB_PATH%
    exit /b 1
)

set "PATH=%VS_TOOLS%;%PATH%"
set "INCLUDE=%SDK_INC%;%VS_INC%"
set "LIB=%SDK_LIB%\ucrt\x64;%VS_LIB%;%SDK_LIB%\um\x64"

"%VS_TOOLS%\cl.exe" /EHsc /Fe:"%OUT_DIR%\SampleCppCLI.exe" "%SCRIPT_DIR%main.cpp" /I. /link "%LIB_PATH%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo === Compilacion exitosa ===
    echo.
)
