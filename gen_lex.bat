@echo off

set MINT_GEN_DIR=%~dp0

ragel -R -F1 "%MINT_GEN_DIR%lexer.rl" -o "%MINT_GEN_DIR%gen\lexer.rb"

if %errorlevel% neq 0 (pause)

set MINT_GEN_DIR=