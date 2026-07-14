@echo off
setlocal enabledelayedexpansion
title Remover Cortana Completamente + Bloquear Reinstalacao

:: Verifica se esta rodando como administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo [ERRO] Este script precisa ser executado como Administrador.
    echo Clique com o botao direito no arquivo .bat e escolha "Executar como administrador".
    echo.
    pause
    exit /b 1
)

echo ==========================================
echo   Removendo Cortana - By Lait
echo ==========================================
echo.

echo [1/8] Encerrando processos da Cortana...
taskkill /f /im Cortana.exe >nul 2>&1
taskkill /f /im SearchApp.exe >nul 2>&1
taskkill /f /im SearchUI.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo [2/8] Removendo o pacote da Cortana (usuario atual)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-AppxPackage -Name '*549981C3F5F10*' | Remove-AppxPackage -ErrorAction SilentlyContinue"

echo [3/8] Removendo o pacote da Cortana (todos os usuarios do PC)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-AppxPackage -AllUsers -Name '*549981C3F5F10*' | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue"

echo [4/8] Removendo o provisionamento (impede reinstalar em novos perfis/updates)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like '*549981C3F5F10*' -or $_.DisplayName -like '*Cortana*' } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue"

echo [5/8] Apagando pastas e dados residuais...
for /d %%U in ("C:\Users\*") do (
    rmdir /s /q "%%U\AppData\Local\Packages\Microsoft.549981C3F5F10_8wekyb3d8bbwe" >nul 2>&1
)
del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Cortana.lnk" >nul 2>&1
del /f /q "C:\Users\Public\Desktop\Cortana.lnk" >nul 2>&1

echo [6/8] Removendo entradas de inicializacao automatica...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "Cortana" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "Cortana" /f >nul 2>&1

echo [7/8] Aplicando politica AllowCortana = 0 (bloqueia execucao mesmo que reinstale)...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "AllowCortana" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "AllowCortana" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "CortanaConsent" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "BingSearchEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v "CortanaConsent" /t REG_DWORD /d 0 /f >nul 2>&1

echo [8/8] Removendo tarefas agendadas relacionadas (se existirem)...
for /f "tokens=*" %%T in ('schtasks /query /fo LIST 2^>nul ^| findstr /i "Cortana"') do (
    echo %%T | findstr /i "TaskName" >nul
    if not errorlevel 1 (
        for /f "tokens=2 delims=:" %%N in ("%%T") do (
            schtasks /delete /tn "%%N" /f >nul 2>&1
        )
    )
)

echo Reiniciando o Explorer...
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe

echo.
echo ==========================================
echo   Cortana removida e bloqueada!
echo ==========================================
echo.
echo O que este script fez:
echo  - Removeu o pacote Appx da Cortana do usuario atual e de
echo    todos os usuarios do PC
echo  - Removeu o provisionamento, para que novos perfis de usuario
echo    nao recebam a Cortana automaticamente
echo  - Aplicou a politica AllowCortana=0, que bloqueia a execucao
echo    mesmo que o binario volte a existir apos um update
echo  - Removeu atalhos e entradas de inicializacao
echo.
echo LIMITACOES HONESTAS:
echo  - A Cortana standalone ja foi descontinuada pela Microsoft,
echo    mas o pacote as vezes volta pre-instalado apos grandes
echo    Feature Updates. Nesses casos, rode o script novamente -
echo    a politica AllowCortana=0 garante que mesmo se o pacote
echo    voltar, ele nao vai conseguir funcionar.
echo  - Em builds mais antigas do Windows 10, remover a Cortana
echo    via linha de comando as vezes deixa a busca da barra de
echo    tarefas instavel. Se isso acontecer, reinicie o PC; se
echo    persistir, pode ser necessario um "sfc /scannow" para
echo    reparar arquivos de sistema.
echo.
pause