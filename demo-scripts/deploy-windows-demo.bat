@echo off
REM Elite Golf Cookbook - Windows Demo Deployment Script
REM Quick deployment for customer POC demonstrations

echo ============================================
echo Elite Golf Club - Chef POC Demo Deployment
echo ============================================
echo.

REM Configuration (can be passed as arguments)
set CUSTOMER_NAME=%1
set DEMO_PORT=%2
set CHEF_MODE=%3

if "%CUSTOMER_NAME%"=="" set CUSTOMER_NAME=Demo Customer Corp
if "%DEMO_PORT%"=="" set DEMO_PORT=8080
if "%CHEF_MODE%"=="" set CHEF_MODE=client

echo Configuration:
echo - Customer: %CUSTOMER_NAME%
echo - Demo Port: %DEMO_PORT%
echo - Chef Mode: %CHEF_MODE%
echo.

REM Create demo node configuration
echo Creating demo configuration...
echo {> %TEMP%\golf-demo-node.json
echo   "golf_app": {>> %TEMP%\golf-demo-node.json
echo     "lab_mode": true,>> %TEMP%\golf-demo-node.json
echo     "customer_name": "%CUSTOMER_NAME%",>> %TEMP%\golf-demo-node.json
echo     "port": %DEMO_PORT%,>> %TEMP%\golf-demo-node.json
echo     "enable_ssl": false,>> %TEMP%\golf-demo-node.json
echo     "quick_setup": true,>> %TEMP%\golf-demo-node.json
echo     "compliance_mode": true,>> %TEMP%\golf-demo-node.json
echo     "audit_logging": true>> %TEMP%\golf-demo-node.json
echo   },>> %TEMP%\golf-demo-node.json
echo   "run_list": ["recipe[elite-golf-cookbook::lab_demo]"]>> %TEMP%\golf-demo-node.json
echo }>> %TEMP%\golf-demo-node.json

echo Demo configuration created at %TEMP%\golf-demo-node.json
echo.

REM Check if Chef is installed
chef-client --version >nul 2>&1
if errorlevel 1 (
    echo Chef Client not found. Please install Chef Client from chef.io
    echo Download: https://downloads.chef.io/tools/infra-client
    pause
    exit /b 1
) else (
    echo Chef Client found!
    chef-client --version
    echo.
)

REM Enable IIS features if not already enabled
echo Enabling IIS features for demo...
powershell -Command "Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole,IIS-WebServer,IIS-CommonHttpFeatures,IIS-DefaultDocument,IIS-StaticContent -All" >nul 2>&1

REM Run Chef based on mode
if "%CHEF_MODE%"=="zero" (
    echo Starting Chef Zero server for demo...
    start /b chef-zero --port 8889
    timeout /t 5 >nul
    
    echo Uploading cookbook...
    knife cookbook upload elite-golf-cookbook --chef-repo-path %~dp0\.. --server-url http://localhost:8889
    
    echo Running Chef Client against Chef Zero...
    chef-client --server-url http://localhost:8889 --json-attributes %TEMP%\golf-demo-node.json
) else if "%CHEF_MODE%"=="solo" (
    echo Running Chef Solo...
    chef-solo --json-attributes %TEMP%\golf-demo-node.json --cookbook-path %~dp0\..
) else (
    echo Running Chef Client in local mode...
    chef-client --local-mode --json-attributes %TEMP%\golf-demo-node.json --cookbook-path %~dp0\..
)

REM Get server information
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do set SERVER_IP=%%a
set SERVER_IP=%SERVER_IP: =%

echo.
echo ============================================
echo POC Deployment Complete!
echo ============================================
echo.
echo Access your demo at:
echo - Main Application: http://%SERVER_IP%:%DEMO_PORT%
echo - Health Check:     http://%SERVER_IP%:%DEMO_PORT%/health
echo - Metrics API:      http://%SERVER_IP%:%DEMO_PORT%/metrics.json
echo - Demo Config:      http://%SERVER_IP%:%DEMO_PORT%/demo-config.txt
echo.
echo Customer: %CUSTOMER_NAME%
echo Platform: Windows %OS%
for /f "tokens=*" %%a in ('chef-client --version') do echo Chef Version: %%a
echo.
echo Demo is ready for customer presentation!
echo ============================================
echo.
echo Press any key to open the demo in your browser...
pause >nul
start http://%SERVER_IP%:%DEMO_PORT%