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

set "SCRIPT_PATH=%SCRIPT_DIR%send_image_gitbash.sh"

if "%~1"=="" (
    "%BASH_EXE%" --noprofile --norc "%SCRIPT_PATH%"
) else if "%~2"=="" (
    "%BASH_EXE%" --noprofile --norc "%SCRIPT_PATH%" "%~1"
) else (
    "%BASH_EXE%" --noprofile --norc "%SCRIPT_PATH%" "%~1" "%~2"
)

set "EXIT_CODE=%ERRORLEVEL%"

endlocal & exit /b %EXIT_CODE%
