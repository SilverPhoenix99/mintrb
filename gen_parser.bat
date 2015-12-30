@echo off

set MINT_GEN_DIR=%~dp0

racc -o "%MINT_GEN_DIR%gen\parser.rb" "%MINT_GEN_DIR%parser.y"

set MINT_GEN_DIR=