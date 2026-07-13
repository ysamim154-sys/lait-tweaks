@echo off
title Adicionar Plano Desempenho Maximo

:: Verifica se está como Administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit
)

echo.
echo =====================================
echo  Adicionando Desempenho Maximo...
echo =====================================
echo.

powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61

echo.
echo Abrindo Opcoes de Energia...
start control.exe /name Microsoft.PowerOptions

echo.
echo Concluido!
pause