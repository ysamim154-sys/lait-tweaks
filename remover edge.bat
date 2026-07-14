@echo off
setlocal enabledelayedexpansion
title Remover Microsoft Edge Completamente + Bloquear Reinstalacao

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
echo   Removendo Microsoft Edge - By Lait
echo ==========================================
echo.

echo [1/12] Encerrando todos os processos do Edge...
taskkill /f /im msedge.exe >nul 2>&1
taskkill /f /im msedgewebview2.exe >nul 2>&1
taskkill /f /im MicrosoftEdgeUpdate.exe >nul 2>&1
taskkill /f /im identity_helper.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo [2/12] Parando e removendo servicos do Edge Update...
net stop edgeupdate >nul 2>&1
net stop edgeupdatem >nul 2>&1
sc delete edgeupdate >nul 2>&1
sc delete edgeupdatem >nul 2>&1

echo [3/12] Removendo tarefas agendadas do Edge Update...
schtasks /delete /tn "MicrosoftEdgeUpdateTaskMachineCore" /f >nul 2>&1
schtasks /delete /tn "MicrosoftEdgeUpdateTaskMachineUA" /f >nul 2>&1
for /f "tokens=*" %%T in ('schtasks /query /fo LIST 2^>nul ^| findstr /i "Edge"') do (
    echo %%T | findstr /i "TaskName" >nul
    if not errorlevel 1 (
        for /f "tokens=2 delims=:" %%N in ("%%T") do (
            schtasks /delete /tn "%%N" /f >nul 2>&1
        )
    )
)

echo [4/12] Rodando o desinstalador nativo do Edge (system-level)...
for /d %%V in ("C:\Program Files (x86)\Microsoft\Edge\Application\*") do (
    if exist "%%V\Installer\setup.exe" (
        echo   Encontrado: %%V
        "%%V\Installer\setup.exe" --uninstall --system-level --verbose-logging --force-uninstall
    )
)
for /d %%V in ("C:\Program Files\Microsoft\Edge\Application\*") do (
    if exist "%%V\Installer\setup.exe" (
        echo   Encontrado: %%V
        "%%V\Installer\setup.exe" --uninstall --system-level --verbose-logging --force-uninstall
    )
)
timeout /t 2 /nobreak >nul

echo [5/12] Removendo o desinstalador do Edge Update...
if exist "C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" (
    "C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" /unregsvc >nul 2>&1
)

echo [6/12] Apagando pastas do programa (Program Files)...
rmdir /s /q "C:\Program Files (x86)\Microsoft\Edge" >nul 2>&1
rmdir /s /q "C:\Program Files\Microsoft\Edge" >nul 2>&1
rmdir /s /q "C:\Program Files (x86)\Microsoft\EdgeCore" >nul 2>&1
rmdir /s /q "C:\Program Files\Microsoft\EdgeCore" >nul 2>&1
rmdir /s /q "C:\Program Files (x86)\Microsoft\EdgeUpdate" >nul 2>&1
rmdir /s /q "C:\Program Files\Microsoft\EdgeUpdate" >nul 2>&1
rmdir /s /q "C:\Program Files (x86)\Microsoft\EdgeWebView" >nul 2>&1
rmdir /s /q "C:\Program Files\Microsoft\EdgeWebView" >nul 2>&1
rmdir /s /q "C:\Program Files (x86)\Microsoft\Temp" >nul 2>&1

echo [7/12] Apagando dados de usuario (perfil, cache, historico)...
for /d %%U in ("C:\Users\*") do (
    rmdir /s /q "%%U\AppData\Local\Microsoft\Edge" >nul 2>&1
    rmdir /s /q "%%U\AppData\Local\Microsoft\EdgeUpdate" >nul 2>&1
    rmdir /s /q "%%U\AppData\Local\Microsoft\EdgeCore" >nul 2>&1
    rmdir /s /q "%%U\AppData\Local\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe" >nul 2>&1
    del /f /q "%%U\Desktop\Microsoft Edge.lnk" >nul 2>&1
    del /f /q "%%U\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk" >nul 2>&1
)

echo [8/12] Apagando dados de sistema (ProgramData)...
rmdir /s /q "C:\ProgramData\Microsoft\EdgeUpdate" >nul 2>&1

echo [9/12] Removendo atalhos publicos...
del /f /q "C:\Users\Public\Desktop\Microsoft Edge.lnk" >nul 2>&1
del /f /q "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk" >nul 2>&1

echo [10/12] Limpando o registro (chaves de instalacao e integracao)...
reg delete "HKLM\SOFTWARE\Microsoft\Edge" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Edge" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Clients\StartMenuInternet\Microsoft Edge" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Edge" /f >nul 2>&1

echo [11/12] Aplicando politicas para IMPEDIR reinstalacao automatica...
reg add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v "InstallDefault" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v "Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v "UpdateDefault" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v "Update{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" /t REG_DWORD /d 0 /f >nul 2>&1

echo [12/12] Bloqueando execucao futura do instalador (permissao negada)...
if exist "C:\Windows\SystemApps\Microsoft.Windows.Edge_neutral_neutral_cw5n1h2txyewy" (
    takeown /f "C:\Windows\SystemApps\Microsoft.Windows.Edge_neutral_neutral_cw5n1h2txyewy" /r /d y >nul 2>&1
    icacls "C:\Windows\SystemApps\Microsoft.Windows.Edge_neutral_neutral_cw5n1h2txyewy" /deny Everyone:(OI)(CI)F /t >nul 2>&1
)

echo.
echo ==========================================
echo   Microsoft Edge removido!
echo ==========================================
echo.
echo O que este script fez:
echo  - Encerrou processos e servicos do Edge/EdgeUpdate
echo  - Rodou o desinstalador oficial em modo system-level forcado
echo  - Apagou pastas em Program Files, Program Files (x86),
echo    ProgramData e AppData de TODOS os perfis de usuario
echo  - Removeu atalhos, chaves de registro e tarefas agendadas
echo  - Aplicou politicas EdgeUpdate que bloqueiam reinstalacao
echo    e atualizacao automatica
echo.
echo LIMITACOES HONESTAS (leia antes de reiniciar):
echo  - Fora da Uniao Europeia, a Microsoft normalmente reforca
echo    o Edge via Windows Update. Grandes atualizacoes de
echo    funcionalidade (feature updates) tendem a reinstalar o
echo    Edge do zero, ignorando as politicas acima. Se isso
echo    acontecer, rode o script novamente.
echo  - O WebView2 Runtime pode ter sido removido junto. Isso pode
echo    quebrar partes do Windows (widgets, alguns apps da Store,
echo    Teams, Outlook novo) que dependem dele para renderizar
echo    conteudo. Se algo parar de funcionar, o proprio app
echo    costuma reinstalar o WebView2 sozinho quando necessario.
echo  - Recomendo instalar outro navegador (Chrome, Firefox etc)
echo    ANTES de rodar este script, ja que o Edge tambem e usado
echo    como navegador padrao para abrir links do sistema.
echo.
pause