@echo off
REM Automatisch alle wijzigingen committen en pushen naar GitHub
cd /d "%~dp0"
git add .
set /p MSG=Commit boodschap: 
if "%MSG%"=="" set MSG=Automatische commit

git commit -m "%MSG%"
git push origin main
pause