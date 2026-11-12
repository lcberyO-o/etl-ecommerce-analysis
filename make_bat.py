# -*- coding: utf-8 -*-
from pathlib import Path

content = r'''@echo off
chcp 65001 >nul
cd /d "%~dp0"
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p --local-infile=1 --default-character-set=utf8mb4 < load_all.sql
echo.
echo Import finished. Check row counts in Navicat.
pause
'''

out = Path(__file__).resolve().parent / "一键导入.bat"
out.write_text(content.replace("\n", "\r\n"), encoding="ascii")
print(out)
