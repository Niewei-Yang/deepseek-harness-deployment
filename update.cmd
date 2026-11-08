@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1"
if errorlevel 1 echo Update failed. Review the error above.
pause
