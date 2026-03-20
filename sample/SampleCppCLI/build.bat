@echo off
setlocal

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

cl.exe /EHsc /Fe:%OUT_DIR%\pdf_cli_cpp.exe "%SCRIPT_DIR%main.cpp" /I. /link "%LIB_PATH%"
if %ERRORLEVEL% EQU 0 (
    echo Compilacion exitosa
    echo Ejecutando...
    %OUT_DIR%\pdf_cli_cpp.exe
)

endlocal
