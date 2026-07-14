@echo off
setlocal enabledelayedexpansion
title Remover Copilot Completamente + Bloquear Reinstalacao

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
echo   Removendo Copilot - By Lait
echo ==========================================
echo.

echo [1/9] Encerrando processos do Copilot...
taskkill /f /im Copilot.exe >nul 2>&1
taskkill /f /im msedgewebview2.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo [2/9] Removendo o pacote Appx do Copilot (usuario atual)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-AppxPackage -Name 'Microsoft.Copilot' | Remove-AppxPackage -ErrorAction SilentlyContinue; ^
     Get-AppxPackage -Name 'Microsoft.Windows.Ai.Copilot.Provider' | Remove-AppxPackage -ErrorAction SilentlyContinue"

echo [3/9] Removendo o pacote Appx do Copilot (todos os usuarios do PC)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-AppxPackage -AllUsers -Name 'Microsoft.Copilot' | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue; ^
     Get-AppxPackage -AllUsers -Name 'Microsoft.Windows.Ai.Copilot.Provider' | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue"

echo [4/9] Removendo o provisionamento (impede reinstalar em novos perfis/updates)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like '*Copilot*' } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue"

echo [5/9] Aplicando politica de registro TurnOffWindowsCopilot (maquina + usuario)...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f >nul 2>&1

echo [6/9] Bloqueando reinstalacao silenciosa via ContentDeliveryManager...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SilentInstalledAppsEnabled" /t REG_DWORD /d 0 /f >nul 2>&1

echo [7/9] Tentando bloqueio novo do build (RemoveMicrosoftCopilotApp), se suportado...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "RemoveMicrosoftCopilotApp" /t REG_DWORD /d 1 /f >nul 2>&1

echo [8/9] Removendo icone/atalho da barra de tarefas e Edge sidebar...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "HubsSidebarEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d 1 /f >nul 2>&1

echo [9/9] Removendo tarefas agendadas relacionadas ao Copilot (se existirem)...
for /f "tokens=*" %%T in ('schtasks /query /fo LIST 2^>nul ^| findstr /i "Copilot"') do (
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
echo   Copilot removido e bloqueado!
echo ==========================================
echo.
echo O que este script fez:
echo  - Removeu o app Copilot (pacote Appx) do usuario atual e de
echo    todos os usuarios do PC
echo  - Removeu o provisionamento, para que novos perfis de usuario
echo    nao recebam o Copilot automaticamente
echo  - Aplicou a politica TurnOffWindowsCopilot via registro
echo  - Desativou instalacoes silenciosas de apps (mecanismo que a
echo    Microsoft usa para reinstalar Copilot sem avisar)
echo  - Desativou a barra lateral do Copilot no Edge
echo  - Removeu tarefas agendadas relacionadas
echo.
echo IMPORTANTE / LIMITACOES HONESTAS:
echo  - O Copilot tem varios pontos de entrada: taskbar, Win+C,
echo    Notepad, Paint, Explorer (botao direito), Edge, Office.
echo    Alguns desses (ex: botao dentro do Notepad/Paint) podem
echo    continuar aparecendo mesmo com o app removido, pois sao
echo    integracoes separadas dentro de cada programa.
echo  - Grandes atualizacoes do Windows (Feature Updates) podem
echo    reinstalar o Copilot do zero e resetar essas politicas.
echo    Se isso acontecer, rode este script novamente.
echo  - Em versoes mais novas do Windows, a Microsoft tem mudado
echo    o mecanismo de entrega do Copilot, entao alguma dessas
echo    chaves pode nao ter efeito dependendo do seu build.
echo    Recomendo reiniciar o PC apos rodar o script e verificar.
echo.
pause