@echo off

setlocal

set MINT_DIR=%~dp0
set MINT_GEN_DIR=%MINT_DIR%gen\

if not exist "%MINT_GEN_DIR%" mkdir "%MINT_GEN_DIR%"

ragel -R -F0 "%MINT_DIR%lexer_exec.rbrl" -o "%MINT_GEN_DIR%lexer.rb"
ragel -R -F0 "%MINT_DIR%lexer_data.rbrl" -o "%MINT_GEN_DIR%lexer_data.rb"

if %errorlevel% neq 0 (pause)

endlocal