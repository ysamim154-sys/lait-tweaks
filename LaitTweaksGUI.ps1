#Requires -Version 5.0
<#
    ============================================================================
     LAIT TWEAKS - Painel Grafico (GUI) - v2
    ----------------------------------------------------------------------------
     Reconstruido a partir do LAIT_TWEAKS.cmd original (menu texto) em um painel
     WPF estilo WinUtil: navegacao em duas colunas, cards com Aplicar/Reverter,
     log ao vivo. Categorias:
        Geral | Debloat | Armazenamento | Rede | Energia | CPU | GPU |
        Memoria | Teclado e Mouse | Limpeza | Adicional

     O tweak de MLD/ICMP em Rede aparece em VERMELHO porque ele quebra o FiveM -
     reverta antes de jogar.

     Como rodar localmente:
        powershell -ExecutionPolicy Bypass -File .\LaitTweaksGUI.ps1

     Como rodar direto do GitHub (depois de hospedar - ver README.md):
        irm https://raw.githubusercontent.com/SEU-USUARIO/lait-tweaks/main/LaitTweaksGUI.ps1 | iex
    ============================================================================
#>

$Global:RepoRawUrl = "https://raw.githubusercontent.com/SEU-USUARIO/lait-tweaks/main/LaitTweaksGUI.ps1"

# ==========================================================================
# ETAPA 0: Auto-elevacao
# ==========================================================================
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    try {
        if ($PSCommandPath) {
            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        }
        else {
            $cmd = "irm '$($Global:RepoRawUrl)' | iex"
            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`"" -Verb RunAs
        }
    }
    catch {
        Write-Host "Nao foi possivel elevar automaticamente. Rode o PowerShell como Administrador e tente de novo." -ForegroundColor Red
        Start-Sleep -Seconds 4
    }
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# ==========================================================================
# ETAPA 1: Utilitarios
# ==========================================================================
$Global:LogBox = $null
function Write-Log($msg) {
    if ($Global:LogBox) {
        $Global:LogBox.AppendText("$msg`r`n")
        $Global:LogBox.ScrollToEnd()
    }
}

function Get-ActiveAdapterGuids {
    (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }).InterfaceGuid
}

function Set-ServiceStart {
    param([string]$ServiceName, [int]$StartValue)
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\$ServiceName" /v "Start" /t REG_DWORD /d $StartValue /f | Out-Null
}

function Set-ScheduledTaskState {
    param([string[]]$Tasks, [switch]$Enable)
    foreach ($t in $Tasks) {
        if ($Enable) { schtasks /Change /TN "$t" /Enable 2>$null | Out-Null }
        else { schtasks /Change /TN "$t" /Disable 2>$null | Out-Null }
    }
}

function Set-NicPowerSaving {
    param([int]$Value)
    $key = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    $props = @('EEE', '*EEE', 'AdvancedEEE', 'AutoPowerSaveModeEnabled', 'EnableGreenEthernet',
        'EnableSavePowerNow', 'EnablePowerManagement', 'NicAutoPowerSaver', 'PowerSavingMode',
        'GigaLite', 'ULPMode', 'EnableDynamicPowerGating', 'EnableConnectedPowerGating')
    Get-ChildItem $key -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
        foreach ($p in $props) {
            try { Set-ItemProperty -Path $_.PSPath -Name $p -Value $Value -ErrorAction SilentlyContinue } catch {}
        }
    }
}

# Tarefas de telemetria/CEIP/compatibilidade
$TelemetryTasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Application Experience\AitAgent",
    "\Microsoft\Windows\Application Experience\StartupAppTask",
    "\Microsoft\Windows\Autochk\Proxy",
    "\Microsoft\Windows\Customer Experience Improvement Program\BthSQM",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
    "\Microsoft\Windows\Customer Experience Improvement Program\Uploader",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver",
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
    "\Microsoft\Windows\Maintenance\WinSAT",
    "\Microsoft\Office\OfficeTelemetryAgentLogOn",
    "\Microsoft\Office\OfficeTelemetryAgentFallBack",
    "\Microsoft\Office\Office 15 Subscription Heartbeat"
)

# CLSIDs dos complementos legados do Internet Explorer / addons (usados por HKCU\...\Ext)
$IEAddonCLSIDs = @(
    "{2933BF90-7B36-11D2-B20E-00C04F983E60}", "{2933BF91-7B36-11D2-B20E-00C04F983E60}",
    "{2933BF94-7B36-11D2-B20E-00C04F983E60}", "{3050F819-98B5-11CF-BB82-00AA00BDCE0B}",
    "{333C7BC4-460F-11D0-BC04-0080C7055A83}", "{373984C9-B845-449B-91E7-45AC83036ADE}",
    "{64AB4BB7-111E-11D1-8F79-00C04FC2FBE1}", "{6BF52A52-394A-11D3-B153-00C04F79FAA6}",
    "{884E2049-217D-11DA-B2A4-000E7BBB2B09}", "{884E2051-217D-11DA-B2A4-000E7BBB2B09}",
    "{88D96A05-F192-11D4-A65F-0040963251E5}", "{88D96A06-F192-11D4-A65F-0040963251E5}",
    "{88D96A07-F192-11D4-A65F-0040963251E5}", "{88D96A08-F192-11D4-A65F-0040963251E5}",
    "{88D96A0A-F192-11D4-A65F-0040963251E5}", "{8E4062D9-FE1B-4B9E-AA16-5E8EEF68F48E}",
    "{D2517915-48CE-4286-970F-921E881B8C5C}", "{EE09B103-97E0-11CF-978F-00A02463E06F}",
    "{F5078F32-C551-11D3-89B9-0000F81FE221}", "{F5078F33-C551-11D3-89B9-0000F81FE221}",
    "{F5078F34-C551-11D3-89B9-0000F81FE221}", "{F5078F35-C551-11D3-89B9-0000F81FE221}",
    "{F5078F36-C551-11D3-89B9-0000F81FE221}", "{F5078F39-C551-11D3-89B9-0000F81FE221}",
    "{F6D90F12-9C73-11D3-B32E-00C04F990BB4}", "{F6D90F14-9C73-11D3-B32E-00C04F990BB4}"
)

# Apps embutidos para o Debloat
$DebloatApps = @(
    @{ Display = "3D Builder";               Pattern = "Microsoft.3DBuilder" }
    @{ Display = "Clima (Weather)";           Pattern = "Microsoft.BingWeather" }
    @{ Display = "Obter Ajuda";               Pattern = "Microsoft.GetHelp" }
    @{ Display = "Introducao ao Windows";     Pattern = "Microsoft.Getstarted" }
    @{ Display = "Extensao de imagem HEIF";   Pattern = "Microsoft.HEIFImageExtension" }
    @{ Display = "Mensagens";                 Pattern = "Microsoft.Messaging" }
    @{ Display = "Visualizador 3D";           Pattern = "Microsoft.Microsoft3DViewer" }
    @{ Display = "Paciencia (Solitaire)";     Pattern = "Microsoft.MicrosoftSolitaireCollection" }
    @{ Display = "Notas Adesivas";            Pattern = "Microsoft.MicrosoftStickyNotes" }
    @{ Display = "Mixed Reality Portal";      Pattern = "Microsoft.MixedReality.Portal" }
    @{ Display = "OneConnect";                Pattern = "Microsoft.OneConnect" }
    @{ Display = "Pessoas";                   Pattern = "Microsoft.People" }
    @{ Display = "Print3D";                   Pattern = "Microsoft.Print3D" }
    @{ Display = "Skype";                     Pattern = "Microsoft.SkypeApp" }
    @{ Display = "Extensao Web Media";        Pattern = "Microsoft.WebMediaExtensions" }
    @{ Display = "Extensao WebP";             Pattern = "Microsoft.WebpImageExtension" }
    @{ Display = "Alarmes e Relogio";         Pattern = "Microsoft.WindowsAlarms" }
    @{ Display = "Camera";                    Pattern = "Microsoft.WindowsCamera" }
    @{ Display = "Feedback Hub";              Pattern = "Microsoft.WindowsFeedbackHub" }
    @{ Display = "Mapas";                     Pattern = "Microsoft.WindowsMaps" }
    @{ Display = "Gravador de Som";           Pattern = "Microsoft.WindowsSoundRecorder" }
    @{ Display = "Seu Telefone (Phone Link)"; Pattern = "Microsoft.YourPhone" }
    @{ Display = "Groove Music";              Pattern = "Microsoft.ZuneMusic" }
    @{ Display = "Mail e Calendario";         Pattern = "microsoft.windowscommunicationsapps" }
    @{ Display = "Cortana";                   Pattern = "Microsoft.549981C3F5F10" }
    @{ Display = "Copilot";                   Pattern = "Microsoft.Windows.Ai.Copilot.Provider" }
    @{ Display = "Sway";                      Pattern = "Sway" }
    @{ Display = "Drawboard PDF";             Pattern = "Drawboard PDF" }
    @{ Display = "Bing (todos)";              Pattern = "bing" }
)

# ==========================================================================
# ETAPA 2: Tweaks - Name / Category / Description / Danger / Apply / Revert
# ==========================================================================
$Tweaks = @()

# -------------------------------------------------------------------------
# GERAL
# -------------------------------------------------------------------------
$Tweaks += [PSCustomObject]@{
    Name = "Timer Resolution / System Responsiveness"; Category = "Geral"; Danger = $false
    Description = "Remove o limite de throttling multimidia e prioriza apps em primeiro plano."
    Apply  = {
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /t REG_DWORD /d 0xffffffff /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "SystemResponsiveness" /t REG_DWORD /d 0 /f | Out-Null
    }
    Revert = {
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /t REG_DWORD /d 10 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "SystemResponsiveness" /t REG_DWORD /d 20 /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Prioridade de Jogos (Tasks\Games)"; Category = "Geral"; Danger = $false
    Description = "GPU Priority=8, Priority=6, Scheduling Category=High, SFIO Priority=High."
    Apply  = {
        $k = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        reg add $k /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
        reg add $k /v "Priority" /t REG_DWORD /d 6 /f | Out-Null
        reg add $k /v "Scheduling Category" /t REG_SZ /d "High" /f | Out-Null
        reg add $k /v "SFIO Priority" /t REG_SZ /d "High" /f | Out-Null
    }
    Revert = {
        $k = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        reg add $k /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
        reg add $k /v "Priority" /t REG_DWORD /d 2 /f | Out-Null
        reg add $k /v "Scheduling Category" /t REG_SZ /d "Medium" /f | Out-Null
        reg add $k /v "SFIO Priority" /t REG_SZ /d "Normal" /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Win32PrioritySeparation"; Category = "Geral"; Danger = $false
    Description = "Define 38 decimal (0x26) - prioriza apps em foco (jogos)."
    Apply  = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v "Win32PrioritySeparation" /t REG_DWORD /d 0x26 /f | Out-Null }
    Revert = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v "Win32PrioritySeparation" /t REG_DWORD /d 0xa /f | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "Reduzir tempo de resposta de apps travados"; Category = "Geral"; Danger = $false
    Description = "AutoEndTasks, HungAppTimeout, WaitToKillAppTimeout e MenuShowDelay bem mais rapidos."
    Apply  = {
        reg add "HKCU\Control Panel\Desktop" /v "AutoEndTasks" /t REG_SZ /d 1 /f | Out-Null
        reg add "HKCU\Control Panel\Desktop" /v "HungAppTimeout" /t REG_SZ /d "1000" /f | Out-Null
        reg add "HKCU\Control Panel\Desktop" /v "WaitToKillAppTimeout" /t REG_SZ /d "1000" /f | Out-Null
        reg add "HKCU\Control Panel\Desktop" /v "MenuShowDelay" /t REG_SZ /d 0 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v "WaitToKillServiceTimeout" /t REG_SZ /d "1000" /f | Out-Null
    }
    Revert = {
        reg add "HKCU\Control Panel\Desktop" /v "AutoEndTasks" /t REG_SZ /d 0 /f | Out-Null
        reg add "HKCU\Control Panel\Desktop" /v "HungAppTimeout" /t REG_SZ /d "5000" /f | Out-Null
        reg add "HKCU\Control Panel\Desktop" /v "WaitToKillAppTimeout" /t REG_SZ /d "5000" /f | Out-Null
        reg add "HKCU\Control Panel\Desktop" /v "MenuShowDelay" /t REG_SZ /d "400" /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v "WaitToKillServiceTimeout" /t REG_SZ /d "5000" /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Dynamic Tick"; Category = "Geral"; Danger = $false
    Description = "bcdedit /set disabledynamictick yes - reduz interrupcoes do timer do sistema."
    Apply  = { bcdedit /set Disabledynamictick yes | Out-Null }
    Revert = { bcdedit /deletevalue Disabledynamictick | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Sincronizacao de Configuracoes"; Category = "Geral"; Danger = $false
    Description = "Impede sincronizar tema, layout do menu iniciar e credenciais entre PCs."
    Apply  = {
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v "DisableSettingSync" /t REG_DWORD /d 2 /f | Out-Null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v "DisableSettingSyncUserOverride" /t REG_DWORD /d 1 /f | Out-Null
    }
    Revert = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v "DisableSettingSync" /f 2>$null | Out-Null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v "DisableSettingSyncUserOverride" /f 2>$null | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Apps em Segundo Plano"; Category = "Geral"; Danger = $false
    Description = "Impede que apps UWP continuem rodando/atualizando em segundo plano."
    Apply  = {
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v "GlobalUserDisabled" /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v "BackgroundAppGlobalToggle" /t REG_DWORD /d 0 /f | Out-Null
    }
    Revert = {
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v "GlobalUserDisabled" /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v "BackgroundAppGlobalToggle" /t REG_DWORD /d 1 /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Parar de Reinstalar Apps Pre-instalados"; Category = "Geral"; Danger = $false
    Description = "Impede que a Microsoft reinstale sugestoes/apps promovidos apos limpeza."
    Apply  = {
        $k = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        foreach ($v in "PreInstalledAppsEnabled", "SilentInstalledAppsEnabled", "OemPreInstalledAppsEnabled", "ContentDeliveryAllowed", "SubscribedContentEnabled", "PreInstalledAppsEverEnabled") {
            reg add $k /v $v /t REG_DWORD /d 0 /f | Out-Null
        }
    }
    Revert = {
        $k = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        foreach ($v in "PreInstalledAppsEnabled", "SilentInstalledAppsEnabled", "OemPreInstalledAppsEnabled", "ContentDeliveryAllowed", "SubscribedContentEnabled", "PreInstalledAppsEverEnabled") {
            reg add $k /v $v /t REG_DWORD /d 1 /f | Out-Null
        }
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Transparencia Visual"; Category = "Geral"; Danger = $false
    Description = "Desliga efeito de transparencia (menus/barra de tarefas) - libera GPU/CPU."
    Apply  = { reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "EnableTransparency" /t REG_DWORD /d 0 /f | Out-Null }
    Revert = { reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "EnableTransparency" /t REG_DWORD /d 1 /f | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Notificacoes"; Category = "Geral"; Danger = $false
    Description = "Desliga toasts e a Central de Notificacoes."
    Apply  = {
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" /v "ToastEnabled" /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "DisableNotificationCenter" /t REG_DWORD /d 1 /f | Out-Null
    }
    Revert = {
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" /v "ToastEnabled" /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "DisableNotificationCenter" /t REG_DWORD /d 0 /f | Out-Null
    }
}

# -------------------------------------------------------------------------
# DEBLOAT (apps + telemetria + servicos de bloatware, igual a categoria "System Debloat" do cmd)
# -------------------------------------------------------------------------
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar GameDVR e Xbox Game Bar"; Category = "Debloat"; Danger = $false
    Description = "Desliga a gravacao em segundo plano do Xbox Game Bar (nao remove o app)."
    Apply  = {
        reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /t REG_DWORD /d 0 /f | Out-Null
    }
    Revert = {
        reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d 1 /f | Out-Null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /f 2>$null | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Servicos Xbox em segundo plano"; Category = "Debloat"; Danger = $false
    Description = "XblAuthManager, XblGameSave, XboxNetApiSvc, XboxGipSvc."
    Apply  = { foreach ($s in "XblAuthManager", "XblGameSave", "XboxNetApiSvc", "XboxGipSvc") { Set-ServiceStart -ServiceName $s -StartValue 4 } }
    Revert = { foreach ($s in "XblAuthManager", "XblGameSave", "XboxNetApiSvc", "XboxGipSvc") { Set-ServiceStart -ServiceName $s -StartValue 3 } }
}
$Tweaks += [PSCustomObject]@{
    Name = "Bluetooth (Desligar servicos)"; Category = "Debloat"; Danger = $false
    Description = "Desativa BTAGService, bthserv, BthAvctpSvc, BluetoothUserService - use se nao tem bluetooth."
    Apply  = { foreach ($s in "BTAGService", "bthserv", "BthAvctpSvc", "BluetoothUserService") { Set-ServiceStart -ServiceName $s -StartValue 4 } }
    Revert = {
        Set-ServiceStart -ServiceName "BTAGService" -StartValue 3
        Set-ServiceStart -ServiceName "bthserv" -StartValue 2
        Set-ServiceStart -ServiceName "BthAvctpSvc" -StartValue 3
        Set-ServiceStart -ServiceName "BluetoothUserService" -StartValue 3
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Impressao e Mapas"; Category = "Debloat"; Danger = $false
    Description = "Spooler de impressao, PrintNotify e MapsBroker - so desligue se nao usa impressora."
    Apply  = {
        foreach ($s in "Spooler", "PrintNotify", "MapsBroker") { Set-ServiceStart -ServiceName $s -StartValue 4 }
        schtasks /Change /TN "Microsoft\Windows\Printing\EduPrintProv" /Disable 2>$null | Out-Null
        schtasks /Change /TN "Microsoft\Windows\Printing\PrinterCleanupTask" /Disable 2>$null | Out-Null
    }
    Revert = {
        Set-ServiceStart -ServiceName "Spooler" -StartValue 2
        Set-ServiceStart -ServiceName "PrintNotify" -StartValue 3
        Set-ServiceStart -ServiceName "MapsBroker" -StartValue 3
        schtasks /Change /TN "Microsoft\Windows\Printing\EduPrintProv" /Enable 2>$null | Out-Null
        schtasks /Change /TN "Microsoft\Windows\Printing\PrinterCleanupTask" /Enable 2>$null | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Telemetria (DiagTrack)"; Category = "Debloat"; Danger = $false
    Description = "DiagTrack, dmwappushservice e AllowTelemetry=0."
    Apply  = {
        sc.exe config DiagTrack start= demand | Out-Null
        sc.exe config dmwappushservice start= demand | Out-Null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f | Out-Null
    }
    Revert = {
        sc.exe config DiagTrack start= auto | Out-Null
        sc.exe config dmwappushservice start= auto | Out-Null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /f 2>$null | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Tarefas Agendadas de Telemetria/CEIP/Office"; Category = "Debloat"; Danger = $false
    Description = "Compatibility Appraiser, Consolidator, KernelCeipTask, Office Telemetry etc."
    Apply  = { Set-ScheduledTaskState -Tasks $TelemetryTasks }
    Revert = { Set-ScheduledTaskState -Tasks $TelemetryTasks -Enable }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar ETW Autologgers"; Category = "Debloat"; Danger = $false
    Description = "Varios loggers internos (DiagLog, ReadyBoot, SQMLogger, WiFiSession...) que gastam I/O."
    Apply  = {
        $loggers = "AppModel", "Cellcore", "CloudExperienceHostOobe", "DiagLog", "ReadyBoot", "SQMLogger", "TCPIPLOGGER", "WiFiSession", "AutoLogger-Diagtrack-Listener", "Diagtrack-Listener"
        foreach ($l in $loggers) { reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$l" /v "Start" /t REG_DWORD /d 0 /f | Out-Null }
    }
    Revert = {
        $loggers = "AppModel", "Cellcore", "CloudExperienceHostOobe", "DiagLog", "ReadyBoot", "SQMLogger", "TCPIPLOGGER", "WiFiSession", "AutoLogger-Diagtrack-Listener", "Diagtrack-Listener"
        foreach ($l in $loggers) { reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$l" /v "Start" /t REG_DWORD /d 1 /f | Out-Null }
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Windows Error Reporting"; Category = "Debloat"; Danger = $false
    Description = "Impede o envio automatico de relatorios de erro para a Microsoft."
    Apply  = {
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v "Disabled" /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v "DoReport" /t REG_DWORD /d 0 /f | Out-Null
    }
    Revert = {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v "Disabled" /f 2>$null | Out-Null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v "DoReport" /f 2>$null | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Activity Feed / Advertising ID"; Category = "Debloat"; Danger = $false
    Description = "Historico de atividades e ID de publicidade usado para personalizar anuncios."
    Apply  = {
        $k = "HKLM\SOFTWARE\Policies\Microsoft\Windows\System"
        reg add $k /v "EnableActivityFeed" /t REG_DWORD /d 0 /f | Out-Null
        reg add $k /v "PublishUserActivities" /t REG_DWORD /d 0 /f | Out-Null
        reg add $k /v "UploadUserActivities" /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d 0 /f | Out-Null
    }
    Revert = {
        $k = "HKLM\SOFTWARE\Policies\Microsoft\Windows\System"
        reg add $k /v "EnableActivityFeed" /t REG_DWORD /d 1 /f | Out-Null
        reg add $k /v "PublishUserActivities" /t REG_DWORD /d 1 /f | Out-Null
        reg add $k /v "UploadUserActivities" /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d 1 /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar SmartScreen e Mitigacoes basicas"; Category = "Debloat"; Danger = $false
    Description = "SmartScreen, ASLR/CFG/SEHOP basicos - so use se sabe o que esta fazendo."
    Apply  = {
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "Off" /f | Out-Null
    }
    Revert = {
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "On" /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Microsoft Store / Delivery Optimization"; Category = "Debloat"; Danger = $false
    Description = "Desativa a Store e o P2P de update (voce ainda pode reverter aqui)."
    Apply  = {
        reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v "DisableStoreApps" /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v "DODownloadMode" /t REG_DWORD /d 0 /f | Out-Null
    }
    Revert = {
        reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v "DisableStoreApps" /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v "DODownloadMode" /t REG_DWORD /d 1 /f | Out-Null
    }
}

foreach ($app in $DebloatApps) {
    $pattern = $app.Pattern
    $display = $app.Display
    $Tweaks += [PSCustomObject]@{
        Name = "Remover: $display"; Category = "Debloat"; Danger = $false
        Description = "Desinstala '$display' ($pattern) para todos os usuarios e remove o pacote provisionado."
        Apply  = {
            Get-AppxPackage -AllUsers "*$pattern*" -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$pattern*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        }.GetNewClosure()
        Revert = {
            Write-Log "  [INFO] Apps removidos nao voltam sozinhos - reinstale pela Microsoft Store se precisar."
        }.GetNewClosure()
    }
}

# -------------------------------------------------------------------------
# ARMAZENAMENTO
# -------------------------------------------------------------------------
$Tweaks += [PSCustomObject]@{
    Name = "Otimizar Comportamento NTFS"; Category = "Armazenamento"; Danger = $false
    Description = "memoryusage=2, mftzone=4, deletenotify=1(TRIM), encryptpagingfile=0."
    Apply  = {
        fsutil behavior set memoryusage 2 | Out-Null
        fsutil behavior set mftzone 4 | Out-Null
        fsutil behavior set disabledeletenotify 0 | Out-Null
        fsutil behavior set encryptpagingfile 0 | Out-Null
    }
    Revert = {
        fsutil behavior set memoryusage 1 | Out-Null
        fsutil behavior set mftzone 1 | Out-Null
        fsutil behavior set disabledeletenotify 0 | Out-Null
        fsutil behavior set encryptpagingfile 0 | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Perfil SSD (Last Access Time / 8dot3)"; Category = "Armazenamento"; Danger = $false
    Description = "Desliga Last Access Time e nomes curtos 8.3 - recomendado se o disco de boot e SSD/NVMe."
    Apply  = {
        fsutil behavior set disableLastAccess 1 | Out-Null
        fsutil behavior set disable8dot3 1 | Out-Null
    }
    Revert = {
        fsutil behavior set disableLastAccess 2 | Out-Null
        fsutil behavior set disable8dot3 2 | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Perfil HDD (Last Access Time / 8dot3)"; Category = "Armazenamento"; Danger = $false
    Description = "Mantem Last Access Time e nomes curtos 8.3 ativos - recomendado para HD mecanico."
    Apply  = {
        fsutil behavior set disableLastAccess 0 | Out-Null
        fsutil behavior set disable8dot3 0 | Out-Null
    }
    Revert = {
        fsutil behavior set disableLastAccess 2 | Out-Null
        fsutil behavior set disable8dot3 2 | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Economia de Energia do SSD"; Category = "Armazenamento"; Danger = $false
    Description = "Impede o SSD de entrar em estados de baixa energia (Idle States) durante o uso."
    Apply  = {
        $paths = "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\1",
                 "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\2",
                 "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\3"
        foreach ($p in $paths) {
            reg add $p /v "IdleExitEnergyMicroJoules" /t REG_DWORD /d 0 /f | Out-Null
            reg add $p /v "IdleExitLatencyMs" /t REG_DWORD /d 0 /f | Out-Null
            reg add $p /v "IdlePowerMw" /t REG_DWORD /d 0 /f | Out-Null
            reg add $p /v "IdleTimeLengthMs" /t REG_DWORD /d 4294967295 /f | Out-Null
        }
    }
    Revert = {
        $paths = "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\1",
                 "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\2",
                 "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\3"
        foreach ($p in $paths) {
            reg delete $p /v "IdleExitEnergyMicroJoules" /f 2>$null | Out-Null
            reg delete $p /v "IdleExitLatencyMs" /f 2>$null | Out-Null
            reg delete $p /v "IdlePowerMw" /f 2>$null | Out-Null
            reg delete $p /v "IdleTimeLengthMs" /f 2>$null | Out-Null
        }
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Habilitar HDD Parking / Power Saving"; Category = "Armazenamento"; Danger = $false
    Description = "Alterna o estacionamento de cabecote em HDs mecanicos por todos os servicos que suportam."
    Apply  = {
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services" -ErrorAction SilentlyContinue | ForEach-Object {
            try { if (Get-ItemProperty -Path $_.PSPath -Name "EnableHDDParking" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EnableHDDParking" -Value 1 } } catch {}
        }
    }
    Revert = {
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services" -ErrorAction SilentlyContinue | ForEach-Object {
            try { if (Get-ItemProperty -Path $_.PSPath -Name "EnableHDDParking" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EnableHDDParking" -Value 0 } } catch {}
        }
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Trim/Retrim do disco C:"; Category = "Armazenamento"; Danger = $false
    Description = "Roda Optimize-Volume -ReTrim no disco C: (SSD/NVMe). Sem reverter - e uma acao unica."
    Apply  = {
        try { Optimize-Volume -DriveLetter C -ReTrim -ErrorAction Stop; Write-Log "  [OK] TRIM executado no disco C:." }
        catch { Write-Log "  [ERRO] $($_.Exception.Message)" }
    }
    Revert = { Write-Log "  [INFO] TRIM e uma acao unica, nao ha o que reverter." }
}

# -------------------------------------------------------------------------
# REDE
# -------------------------------------------------------------------------
$Tweaks += [PSCustomObject]@{
    Name = "Otimizacao TCP (MaxUserPort / TcpTimedWaitDelay / DefaultTTL)"; Category = "Rede"; Danger = $false
    Description = "Libera mais portas dinamicas e reduz o tempo de espera de conexoes fechadas."
    Apply  = {
        $k = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        reg add $k /v "MaxUserPort" /t REG_DWORD /d 65534 /f | Out-Null
        reg add $k /v "TcpTimedWaitDelay" /t REG_DWORD /d 30 /f | Out-Null
        reg add $k /v "DefaultTTL" /t REG_DWORD /d 64 /f | Out-Null
        netsh int tcp set supplemental internet congestionprovider=ctcp | Out-Null
    }
    Revert = {
        $k = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        reg delete $k /v "MaxUserPort" /f 2>$null | Out-Null
        reg delete $k /v "TcpTimedWaitDelay" /f 2>$null | Out-Null
        reg delete $k /v "DefaultTTL" /f 2>$null | Out-Null
        netsh int tcp set supplemental internet congestionprovider=default | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Nagle's Algorithm"; Category = "Rede"; Danger = $false
    Description = "TCPNoDelay + AckFrequency - reduz latencia de pacotes pequenos em adaptadores ativos."
    Apply  = {
        foreach ($g in (Get-ActiveAdapterGuids)) {
            $k = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$g"
            reg add $k /v "TCPNoDelay" /t REG_DWORD /d 1 /f | Out-Null
            reg add $k /v "TcpAckFrequency" /t REG_DWORD /d 1 /f | Out-Null
            reg add $k /v "TcpDelAckTicks" /t REG_DWORD /d 0 /f | Out-Null
        }
    }
    Revert = {
        foreach ($g in (Get-ActiveAdapterGuids)) {
            $k = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$g"
            reg delete $k /v "TCPNoDelay" /f 2>$null | Out-Null
            reg delete $k /v "TcpAckFrequency" /f 2>$null | Out-Null
            reg delete $k /v "TcpDelAckTicks" /f 2>$null | Out-Null
        }
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Heuristicas de TCP"; Category = "Rede"; Danger = $false
    Description = "Desativa o auto-tuning de janela TCP (heuristics + scaling)."
    Apply  = {
        netsh int tcp set heuristics Disabled | Out-Null
        try { Set-NetTCPSetting -SettingName internet -ScalingHeuristics Disabled -ErrorAction SilentlyContinue } catch {}
    }
    Revert = {
        netsh int tcp set heuristics Enabled | Out-Null
        try { Set-NetTCPSetting -SettingName internet -ScalingHeuristics Enabled -ErrorAction SilentlyContinue } catch {}
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar IPv6"; Category = "Rede"; Danger = $false
    Description = "Desativa componentes IPv6 (util se sua rede nao usa IPv6)."
    Apply  = { reg add "HKLM\SYSTEM\CurrentControlSet\services\TCPIP6\Parameters" /v "DisabledComponents" /t REG_DWORD /d 255 /f | Out-Null }
    Revert = { reg delete "HKLM\SYSTEM\CurrentControlSet\services\TCPIP6\Parameters" /v "DisabledComponents" /f 2>$null | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "MLD / ICMP / Chimney / DCA (avancado)"; Category = "Rede"; Danger = $true
    Description = "⚠️ QUEBRA O FIVEM! So aplique se nao joga FiveM. Reverta este tweak antes de abrir o FiveM."
    Apply  = {
        netsh int ip set global dhcpmediasense=disabled | Out-Null
        netsh int ip set global icmpredirects=disabled | Out-Null
        netsh int tcp set global chimney=enabled | Out-Null
        netsh int tcp set global dca=enabled | Out-Null
        netsh int tcp set global rsc=disabled | Out-Null
        netsh int tcp set global timestamps=disabled | Out-Null
        netsh int tcp set global ecncapability=disabled | Out-Null
    }
    Revert = {
        netsh int ip set global dhcpmediasense=enabled | Out-Null
        netsh int ip set global icmpredirects=enabled | Out-Null
        netsh int tcp set global chimney=disabled | Out-Null
        netsh int tcp set global dca=disabled | Out-Null
        netsh int tcp set global rsc=enabled | Out-Null
        netsh int tcp set global timestamps=enabled | Out-Null
        netsh int tcp set global ecncapability=enabled | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Active Probing (NLA)"; Category = "Rede"; Danger = $false
    Description = "Impede que o Windows verifique conectividade real da internet a cada rede."
    Apply  = { reg add "HKLM\System\CurrentControlSet\services\NlaSvc\Parameters\Internet" /v "EnableActiveProbing" /t REG_DWORD /d 0 /f | Out-Null }
    Revert = { reg add "HKLM\System\CurrentControlSet\services\NlaSvc\Parameters\Internet" /v "EnableActiveProbing" /t REG_DWORD /d 1 /f | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "Prioridades de DNS/Local/Hosts/NetBT"; Category = "Rede"; Danger = $false
    Description = "Ajusta a ordem de resolucao de nomes (DnsPriority, LocalPriority, HostsPriority, NetbtPriority)."
    Apply  = {
        $k = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider"
        reg add $k /v "DnsPriority" /t REG_DWORD /d 6 /f | Out-Null
        reg add $k /v "LocalPriority" /t REG_DWORD /d 4 /f | Out-Null
        reg add $k /v "HostsPriority" /t REG_DWORD /d 5 /f | Out-Null
        reg add $k /v "NetbtPriority" /t REG_DWORD /d 7 /f | Out-Null
    }
    Revert = {
        $k = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider"
        foreach ($v in "DnsPriority", "LocalPriority", "HostsPriority", "NetbtPriority") { reg delete $k /v $v /f 2>$null | Out-Null }
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Offload / Chimney / LSO / Checksum (PowerShell)"; Category = "Rede"; Danger = $false
    Description = "Desativa RSC, RSS, Chimney, LSO e checksum offload via cmdlets Set-NetOffloadGlobalSetting."
    Apply  = {
        try {
            Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Disabled -ErrorAction SilentlyContinue
            Set-NetOffloadGlobalSetting -ReceiveSideScaling Disabled -ErrorAction SilentlyContinue
            Set-NetOffloadGlobalSetting -Chimney Disabled -ErrorAction SilentlyContinue
            Disable-NetAdapterLso -Name * -ErrorAction SilentlyContinue
            Disable-NetAdapterChecksumOffload -Name * -ErrorAction SilentlyContinue
        } catch {}
    }
    Revert = {
        try {
            Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Enabled -ErrorAction SilentlyContinue
            Set-NetOffloadGlobalSetting -ReceiveSideScaling Enabled -ErrorAction SilentlyContinue
            Set-NetOffloadGlobalSetting -Chimney Enabled -ErrorAction SilentlyContinue
            Enable-NetAdapterLso -Name * -ErrorAction SilentlyContinue
            Enable-NetAdapterChecksumOffload -Name * -ErrorAction SilentlyContinue
        } catch {}
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "TCP Settings (Ecn / Timestamps / Rto)"; Category = "Rede"; Danger = $false
    Description = "Set-NetTCPSetting: EcnCapability, Timestamps, MaxSynRetransmissions=2, InitialRto=2000, MinRto=300."
    Apply  = {
        try {
            Set-NetTCPSetting -SettingName internet -EcnCapability Enabled -ErrorAction SilentlyContinue
            Set-NetTCPSetting -SettingName internet -Timestamps Enabled -ErrorAction SilentlyContinue
            Set-NetTCPSetting -SettingName internet -MaxSynRetransmissions 2 -ErrorAction SilentlyContinue
            Set-NetTCPSetting -SettingName internet -InitialRto 2000 -ErrorAction SilentlyContinue
            Set-NetTCPSetting -SettingName internet -MinRto 300 -ErrorAction SilentlyContinue
        } catch {}
    }
    Revert = {
        try {
            Set-NetTCPSetting -SettingName internet -EcnCapability Disabled -ErrorAction SilentlyContinue
            Set-NetTCPSetting -SettingName internet -Timestamps Disabled -ErrorAction SilentlyContinue
            Set-NetTCPSetting -SettingName internet -MaxSynRetransmissions 5 -ErrorAction SilentlyContinue
            Set-NetTCPSetting -SettingName internet -InitialRto 3000 -ErrorAction SilentlyContinue
            Set-NetTCPSetting -SettingName internet -MinRto 300 -ErrorAction SilentlyContinue
        } catch {}
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Complementos Legados de Internet (Ext CLSIDs)"; Category = "Rede"; Danger = $false
    Description = "Desativa complementos legados do Internet Explorer/WebBrowser Control usados por apps antigos."
    Apply  = {
        foreach ($id in $IEAddonCLSIDs) {
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Ext\Settings\$id" /v "Flags" /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Ext\Settings\$id" /v "Version" /t REG_SZ /d "*" /f | Out-Null
        }
    }
    Revert = {
        foreach ($id in $IEAddonCLSIDs) {
            reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Ext\Settings\$id" /v "Flags" /f 2>$null | Out-Null
            reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Ext\Settings\$id" /v "Version" /f 2>$null | Out-Null
        }
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Economia de Energia da Placa de Rede"; Category = "Rede"; Danger = $false
    Description = "Desativa EEE/Green Ethernet/ULPS nas placas de rede - evita micro-quedas de conexao."
    Apply  = { Set-NicPowerSaving -Value 0 }
    Revert = { Set-NicPowerSaving -Value 1 }
}

# -------------------------------------------------------------------------
# ENERGIA
# -------------------------------------------------------------------------
$Tweaks += [PSCustomObject]@{
    Name = "Plano de Energia: Desempenho Maximo"; Category = "Energia"; Danger = $false
    Description = "Cria/ativa o plano 'Ultimate Performance' da Microsoft."
    Apply  = {
        $out = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
        if ($out -match '([a-f0-9\-]{36})') { powercfg /setactive $matches[1] }
    }
    Revert = { powercfg /setactive SCHEME_BALANCED }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Hibernacao e Fast Startup"; Category = "Energia"; Danger = $false
    Description = "powercfg /h off + HiberbootEnabled=0. Recomendado: sempre desligar, nunca hibernar/suspender."
    Apply  = {
        powercfg /h off | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v "HiberbootEnabled" /t REG_DWORD /d 0 /f | Out-Null
    }
    Revert = {
        powercfg /h on | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v "HiberbootEnabled" /t REG_DWORD /d 1 /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Power Throttling"; Category = "Energia"; Danger = $false
    Description = "Impede que o Windows reduza a performance de apps em segundo plano pra economizar bateria."
    Apply  = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v "PowerThrottlingOff" /t REG_DWORD /d 1 /f | Out-Null }
    Revert = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v "PowerThrottlingOff" /t REG_DWORD /d 0 /f | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Economia USB/HDD (HIPM/DIPM/StorPort)"; Category = "Energia"; Danger = $false
    Description = "Desativa Link State Power Management e Idle Power Management dos discos/USB."
    Apply  = {
        foreach ($i in "EnableHIPM", "EnableDIPM") {
            Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services" -Recurse -ErrorAction SilentlyContinue | Where-Object { (Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue).$i -ne $null } | ForEach-Object { Set-ItemProperty -Path $_.PSPath -Name $i -Value 0 -ErrorAction SilentlyContinue }
        }
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum" -Recurse -ErrorAction SilentlyContinue -Include "StorPort" | ForEach-Object { try { Set-ItemProperty -Path $_.PSPath -Name "EnableIdlePowerManagement" -Value 0 -ErrorAction SilentlyContinue } catch {} }
    }
    Revert = {
        foreach ($i in "EnableHIPM", "EnableDIPM") {
            Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services" -Recurse -ErrorAction SilentlyContinue | Where-Object { (Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue).$i -ne $null } | ForEach-Object { Set-ItemProperty -Path $_.PSPath -Name $i -Value 1 -ErrorAction SilentlyContinue }
        }
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum" -Recurse -ErrorAction SilentlyContinue -Include "StorPort" | ForEach-Object { try { Set-ItemProperty -Path $_.PSPath -Name "EnableIdlePowerManagement" -Value 1 -ErrorAction SilentlyContinue } catch {} }
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Telemetria de Energia"; Category = "Energia"; Danger = $false
    Description = "TaggedEnergy logging + EnergyEstimationEnabled=0 (menos coleta de dados de uso)."
    Apply  = {
        $k = "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy"
        reg add $k /v "DisableTaggedEnergyLogging" /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "EnergyEstimationEnabled" /t REG_DWORD /d 0 /f | Out-Null
    }
    Revert = {
        $k = "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy"
        reg add $k /v "DisableTaggedEnergyLogging" /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "EnergyEstimationEnabled" /t REG_DWORD /d 1 /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Deletar Planos de Energia Padrao"; Category = "Energia"; Danger = $false
    Description = "Remove Balanceado/Economia/Alto Desempenho (deixe so o seu plano customizado)."
    Apply  = {
        powercfg -delete 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null | Out-Null
        powercfg -delete 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null | Out-Null
        powercfg -delete a1841308-3541-4fab-bc81-f71556f20b4a 2>$null | Out-Null
    }
    Revert = { powercfg -restoredefaultschemes | Out-Null }
}

# -------------------------------------------------------------------------
# CPU
# -------------------------------------------------------------------------
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Core Parking"; Category = "CPU"; Danger = $false
    Description = "Impede o Windows de 'estacionar' nucleos ociosos - mais consistencia em jogos."
    Apply  = {
        powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 100 | Out-Null
        powercfg /setactive SCHEME_CURRENT | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "CoreParkingDisabled" /t REG_DWORD /d 1 /f | Out-Null
    }
    Revert = {
        powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 10 | Out-Null
        powercfg /setactive SCHEME_CURRENT | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "CoreParkingDisabled" /t REG_DWORD /d 0 /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar C-States (Sleep States da CPU)"; Category = "CPU"; Danger = $false
    Description = "Desativa hybrid sleep/standby idle da CPU - reduz latencia ao sair do idle."
    Apply  = {
        powercfg -setacvalueindex scheme_current sub_sleep hybridsleep 0 | Out-Null
        powercfg -setacvalueindex scheme_current sub_sleep standbyidle 0 | Out-Null
        reg add "HKLM\System\CurrentControlSet\Control\Power" /v "CsEnabled" /t REG_DWORD /d 0 /f | Out-Null
    }
    Revert = {
        powercfg -setacvalueindex scheme_current sub_sleep hybridsleep 1 | Out-Null
        powercfg -setacvalueindex scheme_current sub_sleep standbyidle 1 | Out-Null
        reg add "HKLM\System\CurrentControlSet\Control\Power" /v "CsEnabled" /t REG_DWORD /d 1 /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "AMD: Desabilitar Estados de Economia"; Category = "CPU"; Danger = $false
    Description = "Ajustes especificos para CPUs AMD (energia/estados ociosos). So aplique se sua CPU e AMD."
    Apply  = {
        powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 100 | Out-Null
        powercfg /setactive SCHEME_CURRENT | Out-Null
    }
    Revert = {
        powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 10 | Out-Null
        powercfg /setactive SCHEME_CURRENT | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Intel: Desabilitar Estados de Economia"; Category = "CPU"; Danger = $false
    Description = "Ajustes especificos para CPUs Intel (energia/estados ociosos). So aplique se sua CPU e Intel."
    Apply  = {
        powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 100 | Out-Null
        powercfg /setactive SCHEME_CURRENT | Out-Null
    }
    Revert = {
        powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 10 | Out-Null
        powercfg /setactive SCHEME_CURRENT | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Ajustar Processor Performance Time Check Interval"; Category = "CPU"; Danger = $false
    Description = "Reduz o intervalo de checagem de performance do processador (mais responsivo)."
    Apply  = { powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 4d2b0152-7d5c-498b-88e2-34345392a2c5 1; powercfg -setactive scheme_current | Out-Null }
    Revert = { powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 4d2b0152-7d5c-498b-88e2-34345392a2c5 15; powercfg -setactive scheme_current | Out-Null }
}

# -------------------------------------------------------------------------
# GPU
# -------------------------------------------------------------------------
$Tweaks += [PSCustomObject]@{
    Name = "NVIDIA: Desabilitar Telemetria"; Category = "GPU"; Danger = $false
    Description = "Desativa tarefas agendadas de telemetria da NVIDIA (NvTmRep/NvTmMon)."
    Apply  = {
        $tasks = "NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}", "NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
                 "NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}", "NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
                 "NvDriverUpdateCheckDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}", "NvTmMon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"
        foreach ($t in $tasks) { schtasks /Change /TN "$t" /Disable 2>$null | Out-Null }
        reg add "HKCU\SOFTWARE\NVIDIA Corporation\NVControlPanel2\Client" /v "OptInOrOutPreference" /t REG_DWORD /d 0 /f | Out-Null
    }
    Revert = {
        $tasks = "NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}", "NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
                 "NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}", "NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
                 "NvDriverUpdateCheckDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}", "NvTmMon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"
        foreach ($t in $tasks) { schtasks /Change /TN "$t" /Enable 2>$null | Out-Null }
        reg delete "HKCU\SOFTWARE\NVIDIA Corporation\NVControlPanel2\Client" /v "OptInOrOutPreference" /f 2>$null | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "NVIDIA: Forcar Memoria Contigua"; Category = "GPU"; Danger = $false
    Description = "PreferSystemMemoryContiguous=1 - pode reduzir stutter em algumas GPUs NVIDIA."
    Apply  = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" /v "PreferSystemMemoryContiguous" /t REG_DWORD /d 1 /f | Out-Null }
    Revert = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" /v "PreferSystemMemoryContiguous" /t REG_DWORD /d 0 /f | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "AMD: Desabilitar Servicos de Telemetria"; Category = "GPU"; Danger = $false
    Description = "AMD Telemetry Service, Crash Defender e External Events Utility."
    Apply  = {
        foreach ($s in "AMD Telemetry Service", "AMD Crash Defender Service", "AMD External Events Utility") { reg add "HKLM\SYSTEM\CurrentControlSet\Services\$s" /v "Start" /t REG_DWORD /d 4 /f | Out-Null }
    }
    Revert = {
        foreach ($s in "AMD Telemetry Service", "AMD Crash Defender Service", "AMD External Events Utility") { reg add "HKLM\SYSTEM\CurrentControlSet\Services\$s" /v "Start" /t REG_DWORD /d 2 /f | Out-Null }
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "AMD: Shader Cache e Triple Buffering"; Category = "GPU"; Danger = $false
    Description = "Ativa Shader Cache e Triple Buffering no driver AMD (index 0000)."
    Apply  = {
        $k = "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000\UMD"
        reg add $k /v "ShaderCache" /t REG_BINARY /d 3100 /f | Out-Null
        reg add $k /v "EnableTripleBuffering" /t REG_BINARY /d 3000 /f | Out-Null
    }
    Revert = {
        $k = "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000\UMD"
        reg delete $k /v "ShaderCache" /f 2>$null | Out-Null
        reg delete $k /v "EnableTripleBuffering" /f 2>$null | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Intel: Ajustes de Overlay/DVI/eDP"; Category = "GPU"; Danger = $false
    Description = "Ajustes de qualidade/latencia para GPUs Intel integradas."
    Apply  = {
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -ErrorAction SilentlyContinue | Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DriverDesc -match "Intel" } | ForEach-Object {
            try {
                Set-ItemProperty -Path $_.PSPath -Name "Disable_OverlayDSQualityEnhancement" -Value 1 -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $_.PSPath -Name "NoFastLinkTrainingForeDP" -Value 0 -ErrorAction SilentlyContinue
            } catch {}
        }
    }
    Revert = {
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -ErrorAction SilentlyContinue | Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DriverDesc -match "Intel" } | ForEach-Object {
            try {
                Set-ItemProperty -Path $_.PSPath -Name "Disable_OverlayDSQualityEnhancement" -Value 0 -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $_.PSPath -Name "NoFastLinkTrainingForeDP" -Value 1 -ErrorAction SilentlyContinue
            } catch {}
        }
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Habilitar Hardware-Accelerated GPU Scheduling"; Category = "GPU"; Danger = $false
    Description = "HwSchMode=2 - deixa a GPU gerenciar sua propria fila de memoria de video (Win10 2004+)."
    Apply  = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v "HwSchMode" /t REG_DWORD /d 2 /f | Out-Null }
    Revert = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v "HwSchMode" /t REG_DWORD /d 1 /f | Out-Null }
}

# -------------------------------------------------------------------------
# MEMORIA
# -------------------------------------------------------------------------
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar SysMain (Superfetch)"; Category = "Memoria"; Danger = $false
    Description = "Desativa o pre-carregamento de apps em memoria - recomendado para SSD/NVMe."
    Apply  = { Set-ServiceStart -ServiceName "SysMain" -StartValue 4 }
    Revert = { Set-ServiceStart -ServiceName "SysMain" -StartValue 2 }
}
$Tweaks += [PSCustomObject]@{
    Name = "Habilitar Compressao de Memoria"; Category = "Memoria"; Danger = $false
    Description = "Recomendado se voce tem pouca RAM (4-12 GB) - comprime paginas em vez de usar swap."
    Apply  = { try { Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue } catch {} }
    Revert = { try { Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue } catch {} }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Paging Executive"; Category = "Memoria"; Danger = $false
    Description = "Mantem o kernel/drivers sempre na RAM (nunca vao pro pagefile) - recomendado com 16GB+."
    Apply  = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "DisablePagingExecutive" /t REG_DWORD /d 1 /f | Out-Null }
    Revert = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "DisablePagingExecutive" /t REG_DWORD /d 0 /f | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Large System Cache"; Category = "Memoria"; Danger = $false
    Description = "Prioriza a memoria pra aplicativos em vez do cache de sistema (bom para desktop/gaming)."
    Apply  = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "LargeSystemCache" /t REG_DWORD /d 0 /f | Out-Null }
    Revert = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "LargeSystemCache" /t REG_DWORD /d 1 /f | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "Habilitar Page Combining"; Category = "Memoria"; Danger = $false
    Description = "Deduplica paginas de memoria identicas entre processos, liberando RAM."
    Apply  = { try { Enable-MMAgent -PageCombining -ErrorAction SilentlyContinue } catch {} }
    Revert = { try { Disable-MMAgent -PageCombining -ErrorAction SilentlyContinue } catch {} }
}
$Tweaks += [PSCustomObject]@{
    Name = "Ajustar SvcHostSplitThresholdInKB"; Category = "Memoria"; Danger = $false
    Description = "Aumenta o limiar de RAM para o Windows agrupar menos svchost.exe (recomendado com 16GB+)."
    Apply  = { reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v "SvcHostSplitThresholdInKB" /t REG_DWORD /d 16777216 /f | Out-Null }
    Revert = { reg delete "HKLM\SYSTEM\CurrentControlSet\Control" /v "SvcHostSplitThresholdInKB" /f 2>$null | Out-Null }
}

# -------------------------------------------------------------------------
# TECLADO E MOUSE
# -------------------------------------------------------------------------
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Aceleracao do Mouse"; Category = "TecladoMouse"; Danger = $false
    Description = "MouseSpeed=0, MouseThreshold1/2=0 - resposta 1:1 do mouse (recomendado pra jogos)."
    Apply  = {
        reg add "HKCU\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d 0 /f | Out-Null
        reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold1" /t REG_SZ /d 0 /f | Out-Null
        reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold2" /t REG_SZ /d 0 /f | Out-Null
    }
    Revert = {
        reg add "HKCU\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d 1 /f | Out-Null
        reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold1" /t REG_SZ /d 6 /f | Out-Null
        reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold2" /t REG_SZ /d 10 /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Teclado: Delay Minimo / Repeticao Maxima"; Category = "TecladoMouse"; Danger = $false
    Description = "KeyboardDelay=0, KeyboardSpeed=31 - teclado mais responsivo."
    Apply  = {
        reg add "HKCU\Control Panel\Keyboard" /v "KeyboardDelay" /t REG_SZ /d 0 /f | Out-Null
        reg add "HKCU\Control Panel\Keyboard" /v "KeyboardSpeed" /t REG_SZ /d 31 /f | Out-Null
    }
    Revert = {
        reg add "HKCU\Control Panel\Keyboard" /v "KeyboardDelay" /t REG_SZ /d 1 /f | Out-Null
        reg add "HKCU\Control Panel\Keyboard" /v "KeyboardSpeed" /t REG_SZ /d 31 /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Filter/Toggle/Sticky/Mouse Keys"; Category = "TecladoMouse"; Danger = $false
    Description = "Desliga os atalhos de acessibilidade que ativam sozinhos ao segurar teclas (Shift 5x etc)."
    Apply  = {
        reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v "Flags" /t REG_SZ /d "122" /f | Out-Null
        reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v "Flags" /t REG_SZ /d "58" /f | Out-Null
        reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v "Flags" /t REG_SZ /d "506" /f | Out-Null
        reg add "HKCU\Control Panel\Accessibility\MouseKeys" /v "Flags" /t REG_SZ /d 0 /f | Out-Null
    }
    Revert = {
        reg delete "HKCU\Control Panel\Accessibility\Keyboard Response" /v "Flags" /f 2>$null | Out-Null
        reg delete "HKCU\Control Panel\Accessibility\ToggleKeys" /v "Flags" /f 2>$null | Out-Null
        reg delete "HKCU\Control Panel\Accessibility\StickyKeys" /v "Flags" /f 2>$null | Out-Null
        reg delete "HKCU\Control Panel\Accessibility\MouseKeys" /v "Flags" /f 2>$null | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Prioridade Alta para CSRSS (drivers de KBM)"; Category = "TecladoMouse"; Danger = $false
    Description = "CpuPriorityClass=4, IoPriority=3 - da mais prioridade ao processo que trata entrada de teclado/mouse."
    Apply  = {
        $k = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions"
        reg add $k /v "CpuPriorityClass" /t REG_DWORD /d 4 /f | Out-Null
        reg add $k /v "IoPriority" /t REG_DWORD /d 3 /f | Out-Null
    }
    Revert = {
        $k = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions"
        reg add $k /v "CpuPriorityClass" /t REG_DWORD /d 3 /f | Out-Null
        reg add $k /v "IoPriority" /t REG_DWORD /d 2 /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Data Queue Size do Mouse/Teclado"; Category = "TecladoMouse"; Danger = $false
    Description = "Reduz o tamanho da fila de dados (valor 80, equilibrado) - pode ajudar em polling rate alto."
    Apply  = {
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d 80 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d 80 /f | Out-Null
    }
    Revert = {
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d 100 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d 100 /f | Out-Null
    }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar Suspensao Seletiva USB"; Category = "TecladoMouse"; Danger = $false
    Description = "Impede que portas USB durmam sozinhas - evita mouse/teclado 'travando' por um instante."
    Apply  = { reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v "DisableSelectiveSuspend" /t REG_DWORD /d 1 /f | Out-Null }
    Revert = { reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v "DisableSelectiveSuspend" /t REG_DWORD /d 0 /f | Out-Null }
}

# -------------------------------------------------------------------------
# LIMPEZA
# -------------------------------------------------------------------------
$Tweaks += [PSCustomObject]@{
    Name = "Remover Dispositivos Fantasma (desconhecidos)"; Category = "Limpeza"; Danger = $false
    Description = "Remove entradas de dispositivos com status 'Desconhecido' no gerenciador de dispositivos."
    Apply  = {
        try {
            Get-PnpDevice | Where-Object { $_.Status -eq "Unknown" } | ForEach-Object { pnputil /remove-device $_.InstanceId 2>$null | Out-Null }
            Write-Log "  [OK] Dispositivos fantasma removidos."
        }
        catch { Write-Log "  [ERRO] $($_.Exception.Message)" }
    }
    Revert = { Write-Log "  [INFO] Nao ha reversao - Windows detecta os dispositivos de novo se forem conectados." }
}
$Tweaks += [PSCustomObject]@{
    Name = "Abrir Limpeza de Disco do Windows"; Category = "Limpeza"; Danger = $false
    Description = "Abre o cleanmgr.exe (Limpeza de Disco) para voce escolher o que apagar."
    Apply  = { Start-Process cleanmgr.exe }
    Revert = { Write-Log "  [INFO] Essa opcao so abre a ferramenta nativa do Windows - nada a reverter." }
}
$Tweaks += [PSCustomObject]@{
    Name = "Limpar Pasta Temp do Usuario e do Windows"; Category = "Limpeza"; Danger = $false
    Description = "Apaga arquivos de %TEMP% e C:\Windows\Temp (ignora arquivos em uso)."
    Apply  = {
        Get-ChildItem -Path $env:TEMP, "$env:WINDIR\Temp" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Log "  [OK] Pastas temporarias limpas (o que estava em uso foi ignorado)."
    }
    Revert = { Write-Log "  [INFO] Limpeza de temporarios nao tem reversao." }
}

# -------------------------------------------------------------------------
# ADICIONAL
# -------------------------------------------------------------------------
$Tweaks += [PSCustomObject]@{
    Name = "Ativar Modo Escuro"; Category = "Adicional"; Danger = $false
    Description = "Aplica o tema escuro do Windows para apps e sistema."
    Apply  = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "AppsUseLightTheme" /t REG_DWORD /d 0 /f | Out-Null }
    Revert = { reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "AppsUseLightTheme" /t REG_DWORD /d 1 /f | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "Mostrar Extensoes de Arquivo"; Category = "Adicional"; Danger = $false
    Description = "Mostra a extensao (.exe, .txt...) de todos os arquivos no Explorer."
    Apply  = { reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d 0 /f | Out-Null }
    Revert = { reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d 1 /f | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "Melhorar Qualidade do Papel de Parede"; Category = "Adicional"; Danger = $false
    Description = "JPEGImportQuality=256 - evita compressao excessiva do wallpaper pelo Windows."
    Apply  = { reg add "HKCU\Control Panel\Desktop" /v "JPEGImportQuality" /t REG_DWORD /d 256 /f | Out-Null }
    Revert = { reg delete "HKCU\Control Panel\Desktop" /v "JPEGImportQuality" /f 2>$null | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "Desabilitar UAC"; Category = "Adicional"; Danger = $true
    Description = "⚠️ Todo programa roda como admin automaticamente. Reduz seguranca do sistema - use com cautela."
    Apply  = { reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableLUA" /t REG_DWORD /d 0 /f | Out-Null }
    Revert = { reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableLUA" /t REG_DWORD /d 1 /f | Out-Null }
}
$Tweaks += [PSCustomObject]@{
    Name = "Criar Ponto de Restauracao Manual"; Category = "Adicional"; Danger = $false
    Description = "Cria um ponto de restauracao extra a qualquer momento (alem do botao no rodape)."
    Apply  = {
        try { Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue; Checkpoint-Computer -Description "LAIT TWEAKS manual" -RestorePointType "MODIFY_SETTINGS"; Write-Log "  [OK] Ponto de restauracao criado." }
        catch { Write-Log "  [ERRO] $($_.Exception.Message)" }
    }
    Revert = { Write-Log "  [INFO] Use 'rstrui.exe' pra restaurar o Windows a partir de um ponto salvo." }
}

# ==========================================================================
# ETAPA 3: Interface Grafica (XAML + WPF)
# ==========================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="LAIT TWEAKS" Height="800" Width="1180"
        WindowStartupLocation="CenterScreen" Background="#FF0D0D10">

    <Window.Resources>
        <LinearGradientBrush x:Key="AccentGradient" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#FF8B5CF6" Offset="0"/>
            <GradientStop Color="#FF6366F1" Offset="1"/>
        </LinearGradientBrush>
        <SolidColorBrush x:Key="AccentBrush" Color="#FF8B5CF6"/>
        <SolidColorBrush x:Key="DangerBrush" Color="#FFEF4444"/>
        <SolidColorBrush x:Key="CardBrush" Color="#FF1B1B22"/>
        <SolidColorBrush x:Key="CardBorderBrush" Color="#FF2A2A34"/>

        <Style x:Key="NavButton" TargetType="Button">
            <Setter Property="Foreground" Value="#FFD6D6DE"/>
            <Setter Property="FontSize" Value="13.5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Height" Value="42"/>
            <Setter Property="Margin" Value="0,0,8,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="#FF17151D" CornerRadius="8" BorderBrush="{StaticResource CardBorderBrush}" BorderThickness="1">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="4"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Border x:Name="AccentBar" Grid.Column="0" Width="4" CornerRadius="2" Background="{StaticResource AccentBrush}" Opacity="0"/>
                                <ContentPresenter Grid.Column="1" Margin="10,0,4,0" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="Tag" Value="active">
                                <Setter TargetName="Bd" Property="Background" Value="#FF201C2B"/>
                                <Setter TargetName="AccentBar" Property="Opacity" Value="1"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#FF1D1B24"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="TweakCheck" TargetType="CheckBox">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Border x:Name="CardBd" Background="{StaticResource CardBrush}" CornerRadius="10" Padding="14,12" Margin="0,0,0,10" BorderBrush="{StaticResource CardBorderBrush}" BorderThickness="1">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Border x:Name="Box" Grid.Column="0" Width="20" Height="20" CornerRadius="5" BorderBrush="#FF4B4B58" BorderThickness="2" Background="Transparent" VerticalAlignment="Top" Margin="0,2,12,0">
                                    <Path x:Name="Check" Data="M2,7 L6,11 L14,2" Stroke="White" StrokeThickness="2.4" StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round" Visibility="Collapsed"/>
                                </Border>
                                <ContentPresenter Grid.Column="1" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Box" Property="Background" Value="{StaticResource AccentBrush}"/>
                                <Setter TargetName="Box" Property="BorderBrush" Value="{StaticResource AccentBrush}"/>
                                <Setter TargetName="Check" Property="Visibility" Value="Visible"/>
                                <Setter TargetName="CardBd" Property="BorderBrush" Value="{StaticResource AccentBrush}"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="CardBd" Property="Background" Value="#FF212129"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="BtnPrimary" TargetType="Button">
            <Setter Property="Background" Value="{StaticResource AccentGradient}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="8">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="10,0"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Opacity" Value="0.88"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="BtnGhost" TargetType="Button">
            <Setter Property="Background" Value="#FF19191F"/>
            <Setter Property="Foreground" Value="#FFD6D6DE"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="8" BorderBrush="{StaticResource CardBorderBrush}" BorderThickness="1">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="10,0"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#FF232330"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <DockPanel LastChildFill="True">

        <Border DockPanel.Dock="Top" Background="#FF141218" Padding="20,16">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Border Grid.Column="0" Width="46" Height="46" CornerRadius="12" Background="{StaticResource AccentGradient}" VerticalAlignment="Center">
                    <TextBlock Text="L" FontSize="24" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="14,0,0,0">
                    <TextBlock Text="LAIT TWEAKS" FontSize="22" FontWeight="Bold" Foreground="White"/>
                    <TextBlock Text="Painel de Otimizacao para Windows" Foreground="#FF9A9AA5" FontSize="12" Margin="0,2,0,0"/>
                </StackPanel>
                <StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Right">
                    <TextBlock x:Name="CounterText" Text="0 selecionados" Foreground="{StaticResource AccentBrush}" FontWeight="Bold" FontSize="13" HorizontalAlignment="Right"/>
                    <TextBlock x:Name="TotalText" Text="" Foreground="#FF7A7A85" FontSize="11" HorizontalAlignment="Right" Margin="0,2,0,0"/>
                </StackPanel>
            </Grid>
        </Border>

        <Border DockPanel.Dock="Bottom" Background="#FF141218" Padding="18,14">
            <StackPanel>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
                    <Button x:Name="BtnRestore" Content="Criar Ponto de Restauracao" Style="{StaticResource BtnGhost}" Width="195" Height="36" Margin="0,0,10,0"/>
                    <Button x:Name="BtnSelectAll" Content="Marcar Todos (aba atual)" Style="{StaticResource BtnGhost}" Width="185" Height="36" Margin="0,0,10,0"/>
                    <Button x:Name="BtnClearAll" Content="Limpar Selecao" Style="{StaticResource BtnGhost}" Width="145" Height="36" Margin="0,0,10,0"/>
                    <Button x:Name="BtnRevert" Content="Reverter Selecionados" Style="{StaticResource BtnGhost}" Width="175" Height="36" Margin="0,0,10,0"/>
                    <Button x:Name="BtnApply" Content="Aplicar Selecionados" Style="{StaticResource BtnPrimary}" Width="185" Height="36"/>
                </StackPanel>
                <Border Background="#FF0A0A0C" CornerRadius="8" Margin="0,12,0,0" Padding="10">
                    <TextBox x:Name="LogBox" Height="100" Background="Transparent" Foreground="#FF8DFFA0" BorderThickness="0"
                             FontFamily="Consolas" FontSize="12" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"/>
                </Border>
            </StackPanel>
        </Border>

        <Grid Margin="18,12,18,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="270"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <UniformGrid x:Name="NavGrid" Grid.Column="0" Columns="2" VerticalAlignment="Top"/>

            <Border Grid.Column="1" Margin="16,0,0,0">
                <Grid x:Name="ContentHost"/>
            </Border>
        </Grid>

    </DockPanel>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$NavGrid      = $window.FindName("NavGrid")
$ContentHost  = $window.FindName("ContentHost")
$BtnApply     = $window.FindName("BtnApply")
$BtnRevert    = $window.FindName("BtnRevert")
$BtnRestore   = $window.FindName("BtnRestore")
$BtnSelectAll = $window.FindName("BtnSelectAll")
$BtnClearAll  = $window.FindName("BtnClearAll")
$CounterText  = $window.FindName("CounterText")
$TotalText    = $window.FindName("TotalText")
$Global:LogBox = $window.FindName("LogBox")

$categoryMeta = [ordered]@{
    "Geral"         = "🧩  Geral"
    "Debloat"       = "🧹  Debloat"
    "Armazenamento" = "💽  Armazenamento"
    "Rede"          = "🌐  Rede"
    "Energia"       = "🔋  Energia"
    "CPU"           = "🔲  CPU"
    "GPU"           = "🎨  GPU"
    "Memoria"       = "💾  Memoria"
    "TecladoMouse"  = "🖱️  Teclado e Mouse"
    "Limpeza"       = "🧼  Limpeza"
    "Adicional"     = "➕  Adicional"
}

$checkboxMap   = @{}
$categoryPanel = @{}
$navButtons    = @{}

function Update-Counter {
    $checked = @($checkboxMap.Keys | Where-Object { $_.IsChecked -eq $true })
    $CounterText.Text = "$($checked.Count) selecionados"
}

function Show-Category($cat) {
    foreach ($k in $categoryPanel.Keys) { $categoryPanel[$k].Visibility = "Collapsed" }
    $categoryPanel[$cat].Visibility = "Visible"
    foreach ($k in $navButtons.Keys) { $navButtons[$k].Tag = $(if ($k -eq $cat) { "active" } else { "" }) }
    $Global:CurrentCategory = $cat
}

foreach ($catKey in $categoryMeta.Keys) {
    if (-not ($Tweaks.Category -contains $catKey)) { continue }

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = "0,0,4,4"

    foreach ($t in ($Tweaks | Where-Object { $_.Category -eq $catKey })) {
        $title = New-Object System.Windows.Controls.TextBlock
        $title.Text = $t.Name
        $title.FontSize = 14
        $title.FontWeight = "SemiBold"
        $title.TextWrapping = "Wrap"
        $title.Foreground = $(if ($t.Danger) { "#FFEF4444" } else { "#FFECECF1" })

        $desc = New-Object System.Windows.Controls.TextBlock
        $desc.Text = $t.Description
        $desc.FontSize = 11.5
        $desc.Margin = "0,4,0,0"
        $desc.TextWrapping = "Wrap"
        $desc.Foreground = $(if ($t.Danger) { "#FFEF9A9A" } else { "#FF9A9AA5" })

        $stack = New-Object System.Windows.Controls.StackPanel
        $stack.Children.Add($title) | Out-Null
        $stack.Children.Add($desc) | Out-Null

        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Style = $window.Resources["TweakCheck"]
        $cb.Content = $stack
        $cb.Add_Checked({ Update-Counter })
        $cb.Add_Unchecked({ Update-Counter })

        $panel.Children.Add($cb) | Out-Null
        $checkboxMap[$cb] = $t
    }

    $scroll.Content = $panel
    $scroll.Visibility = "Collapsed"
    $categoryPanel[$catKey] = $scroll
    $ContentHost.Children.Add($scroll) | Out-Null

    $btn = New-Object System.Windows.Controls.Button
    $btn.Style = $window.Resources["NavButton"]
    $btn.Content = $categoryMeta[$catKey]
    $btn.Tag = ""
    $capturedKey = $catKey
    $btn.Add_Click({ Show-Category $capturedKey }.GetNewClosure())
    $NavGrid.Children.Add($btn) | Out-Null
    $navButtons[$catKey] = $btn
}

$firstCat = ($Tweaks.Category | Select-Object -Unique | Select-Object -First 1)
Show-Category $firstCat

$TotalText.Text = "$($Tweaks.Count) tweaks em $($categoryPanel.Count) categorias"

# ==========================================================================
# ETAPA 4: Logica dos botoes
# ==========================================================================
$BtnRestore.Add_Click({
    Write-Log "Criando ponto de restauracao..."
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Antes do LAIT TWEAKS" -RestorePointType "MODIFY_SETTINGS"
        Write-Log "[OK] Ponto de restauracao criado."
    }
    catch { Write-Log "[ERRO] Nao foi possivel criar o ponto de restauracao: $($_.Exception.Message)" }
})

$BtnSelectAll.Add_Click({
    if (-not $Global:CurrentCategory) { return }
    $scroll = $categoryPanel[$Global:CurrentCategory]
    foreach ($child in $scroll.Content.Children) {
        if ($child -is [System.Windows.Controls.CheckBox]) { $child.IsChecked = $true }
    }
    Update-Counter
})

$BtnClearAll.Add_Click({
    foreach ($cb in $checkboxMap.Keys) { $cb.IsChecked = $false }
    Update-Counter
})

$BtnApply.Add_Click({
    $selected = $checkboxMap.GetEnumerator() | Where-Object { $_.Key.IsChecked -eq $true }
    if (@($selected).Count -eq 0) { Write-Log "Nenhum tweak selecionado."; return }
    foreach ($item in $selected) {
        $t = $item.Value
        Write-Log "Aplicando: $($t.Name)..."
        try { & $t.Apply; Write-Log "  [OK]" }
        catch { Write-Log "  [ERRO] $($_.Exception.Message)" }
    }
    Write-Log "Concluido."
})

$BtnRevert.Add_Click({
    $selected = $checkboxMap.GetEnumerator() | Where-Object { $_.Key.IsChecked -eq $true }
    if (@($selected).Count -eq 0) { Write-Log "Nenhum tweak selecionado."; return }
    foreach ($item in $selected) {
        $t = $item.Value
        Write-Log "Revertendo: $($t.Name)..."
        try { & $t.Revert; Write-Log "  [OK]" }
        catch { Write-Log "  [ERRO] $($_.Exception.Message)" }
    }
    Write-Log "Concluido."
})

Write-Log "LAIT TWEAKS carregado. $($Tweaks.Count) tweaks em $($categoryPanel.Count) categorias."
Write-Log "O tweak de MLD/ICMP em Rede esta em VERMELHO porque quebra o FiveM - reverta antes de jogar."
Write-Log "Dica: crie um ponto de restauracao antes de aplicar tweaks de sistema."
$window.ShowDialog() | Out-Null
