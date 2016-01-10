@echo off

setlocal

set MINT_DIR=%~dp0
set MINT_GEN_DIR=%MINT_DIR%gen\

if not exist "%MINT_GEN_DIR%" mkdir "%MINT_GEN_DIR%"

racc -o "%MINT_GEN_DIR%parser.rb" "%MINT_DIR%parser.y"

if %errorlevel% neq 0 (pause)

endlocal