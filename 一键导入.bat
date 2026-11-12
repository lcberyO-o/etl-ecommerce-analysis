@echo off
chcp 65001 >nul
cd /d "%~dp0"
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p --local-infile=1 --default-character-set=utf8mb4 < load_all.sql
echo.
echo Import finished. Check row counts in Navicat.
pause
