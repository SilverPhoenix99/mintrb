@echo off

set MINT_GEN_DIR=%~dp0

rem ragel -R -F1 "%MINT_GEN_DIR%lexer.rl" -o "%MINT_GEN_DIR%gen\lexer.rb"
ragel -R -T0 "%MINT_GEN_DIR%lexer\lexer_exec.rbrl" -o "%MINT_GEN_DIR%gen\lexer.rb"
ragel -R -T0 "%MINT_GEN_DIR%lexer\lexer_data.rbrl" -o "%MINT_GEN_DIR%gen\lexer_data.rb"

if %errorlevel% neq 0 (pause)

set MINT_GEN_DIR=