@echo off

setlocal

set MINT_DIR=%~dp0
set MINT_LEX_DIR=%MINT_DIR%lexer\
set MINT_GEN_DIR=%MINT_DIR%gen\

if not exist "%MINT_GEN_DIR%" mkdir "%MINT_GEN_DIR%"

rem ember to use ragel only with machine option
ragel -M test -RVp "%MINT_LEX_DIR%lexer.rbrl" | dot -Tpng "-o%MINT_GEN_DIR%lexer.png"

if %errorlevel% neq 0 (pause)

endlocal