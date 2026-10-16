@echo off
chcp 65001 >nul
cd /d "%~dp0"
python build.py %*
if errorlevel 1 (
  echo.
  echo Не удалось запустить Python. Установите Python 3 с python.org и поставьте галочку "Add to PATH".
)
pause
