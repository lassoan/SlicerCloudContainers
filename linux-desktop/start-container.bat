@echo off
setlocal

set SCRIPT_DIR=%~dp0
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set IMAGE_NAME=linux-desktop
set CONTAINER_NAME=linux-desktop
set "DOCKER_DESKTOP_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set STORAGE_DIR=
if not exist "%SCRIPT_DIR%\.env.local" (
  echo ERROR: Missing env file: %SCRIPT_DIR%\.env.local
  echo Define STORAGE_DIR in .env.local before running this script.
  exit /b 1
)
for /f "usebackq tokens=1* delims==" %%K in ("%SCRIPT_DIR%\.env.local") do (
  if /i "%%~K"=="STORAGE_DIR" set "STORAGE_DIR=%%~L"
)
if not defined STORAGE_DIR (
  echo ERROR: STORAGE_DIR is not set in %SCRIPT_DIR%\.env.local
  exit /b 1
)

where docker >nul 2>nul
if errorlevel 1 (
  echo ERROR: Docker CLI was not found in PATH.
  echo Install Docker Desktop and reopen the terminal before running this script.
  exit /b 1
)

call :ensure_docker_engine
if errorlevel 1 exit /b %errorlevel%

if not exist "%SCRIPT_DIR%\data" mkdir "%SCRIPT_DIR%\data"
if not exist "%STORAGE_DIR%\config" mkdir "%STORAGE_DIR%\config"
if not exist "%STORAGE_DIR%\workspace" mkdir "%STORAGE_DIR%\workspace"
if not exist "%STORAGE_DIR%\data" mkdir "%STORAGE_DIR%\data"
if not exist "%STORAGE_DIR%" mkdir "%STORAGE_DIR%"

docker build -t %IMAGE_NAME% "%SCRIPT_DIR%"
if errorlevel 1 exit /b %errorlevel%

docker rm -f %CONTAINER_NAME% >nul 2>nul

docker run -d ^
  --name %CONTAINER_NAME% ^
  --restart unless-stopped ^
  --env-file "%SCRIPT_DIR%\.env.local" ^
  -v "%STORAGE_DIR%\config:/config" ^
  -v "%STORAGE_DIR%\workspace:/workspace" ^
  -v "%STORAGE_DIR%\data:/data" ^
  %IMAGE_NAME%

if errorlevel 1 exit /b %errorlevel%

echo noVNC desktop is not exposed on localhost; access it through the Cloudflare tunnel.
echo Syncthing UI is not exposed on localhost; open it inside the container desktop at http://localhost:8384.

::pause
exit /b 0

:ensure_docker_engine
docker context inspect desktop-linux >nul 2>nul
if not errorlevel 1 (
  docker context use desktop-linux >nul 2>nul
)

docker version >nul 2>nul
if not errorlevel 1 exit /b 0

if exist "%DOCKER_DESKTOP_EXE%" (
  echo Docker daemon is not available. Starting Docker Desktop...
  start "" "%DOCKER_DESKTOP_EXE%"
) else (
  echo ERROR: Docker daemon is not available and Docker Desktop was not found at:
  echo   %DOCKER_DESKTOP_EXE%
  echo Start your Docker engine manually, then rerun this script.
  exit /b 1
)

set /a DOCKER_WAIT_SECONDS=0
:wait_for_docker
docker version >nul 2>nul
if not errorlevel 1 exit /b 0

if %DOCKER_WAIT_SECONDS% geq 120 (
  echo ERROR: Docker Desktop did not become ready within 120 seconds.
  echo Open Docker Desktop and wait for the engine to finish starting.
  echo If the problem persists, run: docker context use desktop-linux
  exit /b 1
)

set /a DOCKER_WAIT_SECONDS+=2
timeout /t 2 /nobreak >nul
goto wait_for_docker
