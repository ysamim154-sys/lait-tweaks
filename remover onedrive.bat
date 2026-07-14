@echo off
setlocal enabledelayedexpansion
title Remover OneDrive Completamente + Bloquear Reinstalacao

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
echo   Removendo OneDrive - By Lait
echo ==========================================
echo.

echo [1/10] Encerrando processos do OneDrive...
taskkill /f /im OneDrive.exe >nul 2>&1
taskkill /f /im OneDriveSetup.exe >nul 2>&1
taskkill /f /im FileCoAuth.exe >nul 2>&1
taskkill /f /im FileSyncHelper.exe >nul 2>&1
taskkill /f /im OneDriveStandaloneUpdater.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo [2/10] Executando desinstalador oficial do OneDrive...
if exist "%SystemRoot%\SysWOW64\OneDriveSetup.exe" (
    "%SystemRoot%\SysWOW64\OneDriveSetup.exe" /uninstall
) else if exist "%SystemRoot%\System32\OneDriveSetup.exe" (
    "%SystemRoot%\System32\OneDriveSetup.exe" /uninstall
)
timeout /t 3 /nobreak >nul

taskkill /f /im OneDrive.exe >nul 2>&1
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 1 /nobreak >nul

echo [3/10] Removendo pastas e arquivos residuais do usuario...
rmdir /s /q "%USERPROFILE%\OneDrive" >nul 2>&1
rmdir /s /q "%LOCALAPPDATA%\Microsoft\OneDrive" >nul 2>&1
rmdir /s /q "%PROGRAMDATA%\Microsoft OneDrive" >nul 2>&1
rmdir /s /q "%SYSTEMDRIVE%\OneDriveTemp" >nul 2>&1
rmdir /s /q "C:\Windows.old\OneDrive" >nul 2>&1

echo [4/10] Removendo OneDrive de perfis de outros usuarios (se existirem)...
for /d %%U in ("C:\Users\*") do (
    if exist "%%U\OneDrive" (
        rmdir /s /q "%%U\OneDrive" >nul 2>&1
    )
    if exist "%%U\AppData\Local\Microsoft\OneDrive" (
        rmdir /s /q "%%U\AppData\Local\Microsoft\OneDrive" >nul 2>&1
    )
)

echo [5/10] Removendo atalhos...
del /f /q "%USERPROFILE%\Links\OneDrive.lnk" >nul 2>&1
del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk" >nul 2>&1
del /f /q "%PUBLIC%\Desktop\OneDrive.lnk" >nul 2>&1
del /f /q "%USERPROFILE%\Desktop\OneDrive.lnk" >nul 2>&1

echo [6/10] Removendo entradas de inicializacao automatica (Run keys)...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f >nul 2>&1

echo [7/10] Removendo do Agendador de Tarefas...
schtasks /delete /tn "OneDrive Standalone Update Task-S-1-5-21" /f >nul 2>&1
schtasks /delete /tn "OneDrive Reporting Task-S-1-5-21" /f >nul 2>&1
for /f "tokens=*" %%T in ('schtasks /query /fo LIST 2^>nul ^| findstr /i "OneDrive"') do (
    echo %%T | findstr /i "TaskName" >nul
    if not errorlevel 1 (
        for /f "tokens=2 delims=:" %%N in ("%%T") do (
            schtasks /delete /tn "%%N" /f >nul 2>&1
        )
    )
)

echo [8/10] Removendo CLSID e integracao com o Explorer/navegador de arquivos...
reg delete "HKCR\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f >nul 2>&1
reg delete "HKCR\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f >nul 2>&1

echo [9/10] Bloqueando reinstalacao automatica via politica de grupo...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v "DisableFileSyncNGSC" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v "DisableFileSync" /t REG_DWORD /d 1 /f >nul 2>&1

echo [10/10] Impedindo que o instalador rode novamente...
takeown /f "%SystemRoot%\SysWOW64\OneDriveSetup.exe" >nul 2>&1
icacls "%SystemRoot%\SysWOW64\OneDriveSetup.exe" /deny Everyone:F >nul 2>&1
takeown /f "%SystemRoot%\System32\OneDriveSetup.exe" >nul 2>&1
icacls "%SystemRoot%\System32\OneDriveSetup.exe" /deny Everyone:F >nul 2>&1

echo Reiniciando o Explorer...
start explorer.exe

echo.
echo ==========================================
echo   OneDrive removido e bloqueado!
echo ==========================================
echo.
echo O que este script fez, alem de desinstalar:
echo  - Removeu pastas do OneDrive de todos os perfis de usuario
echo  - Removeu tarefas agendadas relacionadas ao OneDrive
echo  - Aplicou politica de grupo bloqueando sincronizacao/OneDrive
echo  - Negou permissao de execucao ao OneDriveSetup.exe (impede
echo    reinstalacao automatica pelo proprio Windows)
echo.
echo IMPORTANTE: em Feature Updates grandes do Windows (ex: passar
echo de 22H2 para a proxima versao), a Microsoft pode reconstruir
echo o OneDriveSetup.exe do zero e resetar essa permissao. Se isso
echo acontecer, so rodar o script de novo resolve.
echo.
pause