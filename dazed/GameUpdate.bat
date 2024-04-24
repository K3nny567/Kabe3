@echo off
setlocal enabledelayedexpansion
cd dazed

REM Check if patch-config.txt exists
if not exist patch-config.txt (
    echo "Config file (patch-config.txt) not found! Assuming no patching needed."
    exit /b
)

REM Read configuration from file
for /f "tokens=1,2 delims==" %%a in (patch-config.txt) do (
    if "%%a"=="username" set "username=%%b"
    if "%%a"=="repo" set "repo=%%b"
    if "%%a"=="branch" set "branch=%%b"
)

REM Get the latest hash
echo "Getting latest commit SHA hash"
powershell -Command "(Invoke-WebRequest -Uri 'https://api.github.com/repos/%username%/%repo%/branches/%branch%').Content | ConvertFrom-Json | Select-Object -ExpandProperty commit | Select-Object -ExpandProperty sha" > latest_patch_sha.txt

REM Read the latest SHA from the file
set /p latest_patch_sha=<latest_patch_sha.txt

REM Check if previous_patch_sha.txt exists
if not exist previous_patch_sha.txt (
    echo "Previous SHA hash not found!"
    echo "Assuming first time patching..."
    goto download_extract
)

REM Read the stored SHA from previous check
set /p previous_patch_sha=<previous_patch_sha.txt

REM Trim whitespace from SHA strings
set "previous_patch_sha=%previous_patch_sha: =%"
set "latest_patch_sha=%latest_patch_sha: =%"

REM Compare trimmed SHAs
if "%latest_patch_sha%" neq "%previous_patch_sha%" (
    echo "Update found! Patching...
    goto download_extract
) else (
    echo "Patch is up to date."
)

REM Delete latest_patch_sha.txt
del latest_patch_sha.txt

endlocal
exit /b

:download_extract
REM Download zip file
echo "Downloading latest patch..."
powershell -Command "Invoke-WebRequest -Uri 'https://codeload.github.com/%username%/%repo%/zip/refs/heads/%branch%' -OutFile 'repo.zip'"

REM Extract contents, overwriting conflicts
echo "Extracting..."
powershell -Command "Expand-Archive -Path '.\repo.zip' -DestinationPath '.' -Force"
echo "Applying patch..."
xcopy /s /e /y "%repo%-%branch%\*" ".."

REM Clean up
echo "Cleaning up..."
del repo.zip
rmdir /s /q "%repo%-main"
del latest_patch_sha.txt

REM Store latest SHA for next check
echo %latest_patch_sha% > previous_patch_sha.txt
endlocal
exit /b