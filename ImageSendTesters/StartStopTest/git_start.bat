@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "BASH_EXE="

if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH_EXE if exist "%ProgramFiles%\Git\usr\bin\bash.exe" set "BASH_EXE=%ProgramFiles%\Git\usr\bin\bash.exe"
if not defined BASH_EXE if exist "%ProgramW6432%\Git\bin\bash.exe" set "BASH_EXE=%ProgramW6432%\Git\bin\bash.exe"
if not defined BASH_EXE if exist "%ProgramW6432%\Git\usr\bin\bash.exe" set "BASH_EXE=%ProgramW6432%\Git\usr\bin\bash.exe"
if not defined BASH_EXE if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH_EXE=%LocalAppData%\Programs\Git\bin\bash.exe"
if not defined BASH_EXE if exist "%LocalAppData%\Programs\Git\usr\bin\bash.exe" set "BASH_EXE=%LocalAppData%\Programs\Git\usr\bin\bash.exe"

if not defined BASH_EXE (
    echo ERROR: Git Bash was not found.
    echo Install Git for Windows from https://git-scm.com/download/win
    exit /b 1
)

set "SCRIPT_PATH=%SCRIPT_DIR%git_start.sh"

set "PORT_ARG=%~2"
if not defined PORT_ARG if defined SERIAL_PORT set "PORT_ARG=%SERIAL_PORT%"
if not defined PORT_ARG set "PORT_ARG=COM3"

set "MODE_PORT="
if /I "%PORT_ARG:~0,3%"=="COM" set "MODE_PORT=%PORT_ARG%"

if /I "%PORT_ARG:~0,9%"=="/dev/ttyS" (
    set "TTY_NUM=%PORT_ARG:~9%"
    for /f "tokens=1 delims=^0123456789" %%A in ("%TTY_NUM%") do set "TTY_NUM="
    if defined TTY_NUM (
        set /a COM_NUM=TTY_NUM+1
        call set "MODE_PORT=COM%%COM_NUM%%"
    )
)

if defined MODE_PORT (
    mode %MODE_PORT%: BAUD=1000000 PARITY=n DATA=8 STOP=1 >nul 2>&1
    if errorlevel 1 (
        echo WARN: Could not configure %MODE_PORT% with MODE. Continuing anyway.
    )
)

if "%~1"=="" (
    "%BASH_EXE%" --noprofile --norc "%SCRIPT_PATH%" "" "%PORT_ARG%"
) else (
    "%BASH_EXE%" --noprofile --norc "%SCRIPT_PATH%" "%~1" "%PORT_ARG%"
)

set "EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %EXIT_CODE%
