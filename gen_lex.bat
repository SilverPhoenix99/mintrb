@echo off

set MINT_GEN_DIR=%~dp0

ragel -R -F0 "%MINT_GEN_DIR%lexer_exec.rbrl" -o "%MINT_GEN_DIR%gen\lexer.rb"
ragel -R -F0 "%MINT_GEN_DIR%lexer_data.rbrl" -o "%MINT_GEN_DIR%gen\lexer_data.rb"

if %errorlevel% neq 0 (pause)

set MINT_GEN_DIR=