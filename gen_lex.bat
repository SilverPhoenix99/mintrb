@echo off

set MINT_GEN_DIR=%~dp0

ragel -R -F1 "%MINT_GEN_DIR%lexer.rl" -o "%MINT_GEN_DIR%gen\lexer.rb"

set MINT_GEN_DIR=