@echo off

set MINT_GEN_DIR=%~dp0

@rem ember to not use ragel without machine option
ragel -M test -RVp "%MINT_GEN_DIR%lexer\lexer.rbrl" | dot -Tpng "-o%MINT_GEN_DIR%gen\lexer.png"

set MINT_GEN_DIR=