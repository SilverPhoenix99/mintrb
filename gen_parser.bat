@echo off

set MINT_GEN_DIR=%~dp0

racc -o "%MINT_GEN_DIR%gen\parser.rb" "%MINT_GEN_DIR%parser.y" 1> scratch\parser.output.log 2> scratch\parser.error.log"

echo %errorlevel%

set MINT_GEN_DIR=