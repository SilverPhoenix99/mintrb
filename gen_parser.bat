@echo off

set MINT_GEN_DIR=%~dp0

racc "%MINT_GEN_DIR%parser.y" -o "%MINT_GEN_DIR%gen\parser.rb"

set MINT_GEN_DIR=