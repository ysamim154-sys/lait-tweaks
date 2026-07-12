#Requires -Version 5.0
<#
    ============================================================================
     LAIT TWEAKS - Painel Grafico (GUI)
    ----------------------------------------------------------------------------
     Painel estilo WinUtil (sidebar + cards + Aplicar/Reverter), construido com
     base nos tweaks originais do LAIT_TWEAKS.cmd, agora organizado em:
        - Gaming / Performance
        - Rede
        - Privacidade / Telemetria
        - Debloat (apps embutidos da Microsoft)
        - Sistema

     Como rodar localmente:
        powershell -ExecutionPolicy Bypass -File .\LaitTweaksGUI.ps1

     Como rodar direto do GitHub (depois de hospedar - ver README.md):
        irm https://raw.githubusercontent.com/SEU-USUARIO/lait-tweaks/main/LaitTweaksGUI.ps1 | iex
    ============================================================================
#>

# ==========================================================================
# ETAPA -1: URL do script cru no GitHub (edite depois de subir o repositorio)
# Usado apenas como fallback de auto-elevacao quando o script roda via
# "irm | iex" (nesse modo nao existe $PSCommandPath para reabrir o arquivo).
# ==========================================================================
$Global:RepoRawUrl = "https://raw.githubusercontent.com/SEU-USUARIO/lait-tweaks/main/LaitTweaksGUI.ps1"

# ==========================================================================
# ETAPA 0: Auto-elevacao (pede Admin sozinho, funciona rodando local OU via iex)
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
        if ($Enable) {
            schtasks /Change /TN "$t" /Enable 2>$null | Out-Null
        }
        else {
            schtasks /Change /TN "$t" /Disable 2>$null | Out-Null
        }
    }
}

# Lista de tarefas agendadas de telemetria/CEIP/compatibilidade (extraidas do LAIT_TWEAKS.cmd)
$TelemetryTasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Application Experience\AitAgent",
    "\Microsoft\Windows\Autochk\Proxy",
    "\Microsoft\Windows\Customer Experience Improvement Program\BthSQM",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
    "\Microsoft\Windows\Customer Experience Improvement Program\Uploader",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Office\OfficeTelemetryAgentLogOn",
    "\Microsoft\Office\OfficeTelemetryAgentFallBack"
)

# Lista de apps embutidos (Debloat) - extraida do LAIT_TWEAKS.cmd
$DebloatApps = @(
    @{ Display = "3D Builder";                 Pattern = "Microsoft.3DBuilder" }
    @{ Display = "Clima (Weather)";             Pattern = "Microsoft.BingWeather" }
    @{ Display = "Obter Ajuda";                 Pattern = "Microsoft.GetHelp" }
    @{ Display = "Introducao ao Windows";       Pattern = "Microsoft.Getstarted" }
    @{ Display = "Extensao de imagem HEIF";     Pattern = "Microsoft.HEIFImageExtension" }
    @{ Display = "Mensagens";                   Pattern = "Microsoft.Messaging" }
    @{ Display = "Visualizador 3D";             Pattern = "Microsoft.Microsoft3DViewer" }
    @{ Display = "Paciencia (Solitaire)";       Pattern = "Microsoft.MicrosoftSolitaireCollection" }
    @{ Display = "Notas Adesivas";              Pattern = "Microsoft.MicrosoftStickyNotes" }
    @{ Display = "Mixed Reality Portal";        Pattern = "Microsoft.MixedReality.Portal" }
    @{ Display = "OneConnect";                  Pattern = "Microsoft.OneConnect" }
    @{ Display = "Pessoas";                     Pattern = "Microsoft.People" }
    @{ Display = "Print3D";                     Pattern = "Microsoft.Print3D" }
    @{ Display = "Skype";                       Pattern = "Microsoft.SkypeApp" }
    @{ Display = "Extensao Web Media";          Pattern = "Microsoft.WebMediaExtensions" }
    @{ Display = "Extensao WebP";               Pattern = "Microsoft.WebpImageExtension" }
    @{ Display = "Alarmes e Relogio";           Pattern = "Microsoft.WindowsAlarms" }
    @{ Display = "Camera";                      Pattern = "Microsoft.WindowsCamera" }
    @{ Display = "Feedback Hub";                Pattern = "Microsoft.WindowsFeedbackHub" }
    @{ Display = "Mapas";                       Pattern = "Microsoft.WindowsMaps" }
    @{ Display = "Gravador de Som";             Pattern = "Microsoft.WindowsSoundRecorder" }
    @{ Display = "Seu Telefone (Phone Link)";   Pattern = "Microsoft.YourPhone" }
    @{ Display = "Groove Music";                Pattern = "Microsoft.ZuneMusic" }
    @{ Display = "Mail e Calendario";           Pattern = "microsoft.windowscommunicationsapps" }
    @{ Display = "Cortana";                     Pattern = "Microsoft.549981C3F5F10" }
    @{ Display = "Copilot";                     Pattern = "Microsoft.Windows.Ai.Copilot.Provider" }
)

# ==========================================================================
# ETAPA 2: Definicao dos Tweaks (Nome, Categoria, Descricao, Apply, Revert)
# ==========================================================================
$Tweaks = @(

    # -------------------- GAMING / PERFORMANCE --------------------
    [PSCustomObject]@{
        Name        = "Timer Resolution de Multimidia"
        Category    = "Gaming"
        Description = "Remove o limite de throttling multimidia e prioriza apps em primeiro plano (NetworkThrottlingIndex / SystemResponsiveness)."
        Apply       = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /t REG_DWORD /d 0xffffffff /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "SystemResponsiveness" /t REG_DWORD /d 0 /f | Out-Null
        }
        Revert      = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /t REG_DWORD /d 10 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "SystemResponsiveness" /t REG_DWORD /d 20 /f | Out-Null
        }
    }

    [PSCustomObject]@{
        Name        = "Prioridade de Jogos (Tasks\Games)"
        Category    = "Gaming"
        Description = "Ajusta GPU Priority=8, Priority=6, Scheduling Category=High, SFIO Priority=High."
        Apply       = {
            $k = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            reg add $k /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
            reg add $k /v "Priority" /t REG_DWORD /d 6 /f | Out-Null
            reg add $k /v "Scheduling Category" /t REG_SZ /d "High" /f | Out-Null
            reg add $k /v "SFIO Priority" /t REG_SZ /d "High" /f | Out-Null
        }
        Revert      = {
            $k = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            reg add $k /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
            reg add $k /v "Priority" /t REG_DWORD /d 2 /f | Out-Null
            reg add $k /v "Scheduling Category" /t REG_SZ /d "Medium" /f | Out-Null
            reg add $k /v "SFIO Priority" /t REG_SZ /d "Normal" /f | Out-Null
        }
    }

    [PSCustomObject]@{
        Name        = "Win32PrioritySeparation"
        Category    = "Gaming"
        Description = "Define o valor 38 decimal (0x26) - prioriza apps em foco (jogos)."
        Apply       = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v "Win32PrioritySeparation" /t REG_DWORD /d 0x26 /f | Out-Null }
        Revert      = { reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v "Win32PrioritySeparation" /t REG_DWORD /d 0x2 /f | Out-Null }
    }

    [PSCustomObject]@{
        Name        = "Plano de Energia: Desempenho Maximo"
        Category    = "Gaming"
        Description = "Cria/ativa o plano 'Ultimate Performance' da Microsoft."
        Apply       = {
            $out = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            if ($out -match '([a-f0-9\-]{36})') { powercfg /setactive $matches[1] }
        }
        Revert      = { powercfg /setactive SCHEME_BALANCED }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar Game DVR / Xbox Game Bar"
        Category    = "Gaming"
        Description = "Reduz overhead do gravador de jogos em segundo plano."
        Apply       = {
            reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /t REG_DWORD /d 0 /f | Out-Null
        }
        Revert      = {
            reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 1 /f | Out-Null
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /f 2>$null | Out-Null
        }
    }

    # -------------------- REDE --------------------
    [PSCustomObject]@{
        Name        = "Otimizacao TCP (MaxUserPort / TcpTimedWaitDelay / DefaultTTL)"
        Category    = "Rede"
        Description = "Libera mais portas dinamicas e reduz o tempo de espera de conexoes fechadas."
        Apply       = {
            $k = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            reg add $k /v "MaxUserPort" /t REG_DWORD /d 65534 /f | Out-Null
            reg add $k /v "TcpTimedWaitDelay" /t REG_DWORD /d 30 /f | Out-Null
            reg add $k /v "DefaultTTL" /t REG_DWORD /d 64 /f | Out-Null
            netsh int tcp set supplemental internet congestionprovider=ctcp | Out-Null
        }
        Revert      = {
            $k = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            reg delete $k /v "MaxUserPort" /f 2>$null | Out-Null
            reg delete $k /v "TcpTimedWaitDelay" /f 2>$null | Out-Null
            reg delete $k /v "DefaultTTL" /f 2>$null | Out-Null
            netsh int tcp set supplemental internet congestionprovider=default | Out-Null
        }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar Nagle's Algorithm"
        Category    = "Rede"
        Description = "TCPNoDelay + AckFrequency - reduz latencia de pacotes pequenos em todos os adaptadores ativos."
        Apply       = {
            foreach ($g in (Get-ActiveAdapterGuids)) {
                $k = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$g"
                reg add $k /v "TCPNoDelay" /t REG_DWORD /d 1 /f | Out-Null
                reg add $k /v "TcpAckFrequency" /t REG_DWORD /d 1 /f | Out-Null
                reg add $k /v "TcpDelAckTicks" /t REG_DWORD /d 0 /f | Out-Null
            }
        }
        Revert      = {
            foreach ($g in (Get-ActiveAdapterGuids)) {
                $k = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$g"
                reg delete $k /v "TCPNoDelay" /f 2>$null | Out-Null
                reg delete $k /v "TcpAckFrequency" /f 2>$null | Out-Null
                reg delete $k /v "TcpDelAckTicks" /f 2>$null | Out-Null
            }
        }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar Heuristicas de TCP"
        Category    = "Rede"
        Description = "Desativa o auto-tuning de janela TCP que pode causar throttling em alguns roteadores."
        Apply       = { netsh int tcp set heuristics Disabled | Out-Null }
        Revert      = { netsh int tcp set heuristics Enabled | Out-Null }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar IPv6"
        Category    = "Rede"
        Description = "Desativa componentes IPv6 (util se sua rede nao usa IPv6)."
        Apply       = { reg add "HKLM\SYSTEM\CurrentControlSet\services\TCPIP6\Parameters" /v "DisabledComponents" /t REG_DWORD /d 255 /f | Out-Null }
        Revert      = { reg delete "HKLM\SYSTEM\CurrentControlSet\services\TCPIP6\Parameters" /v "DisabledComponents" /f 2>$null | Out-Null }
    }

    [PSCustomObject]@{
        Name        = "Otimizar MLD / ICMP / Chimney"
        Category    = "Rede"
        Description = "Ajusta parametros globais de TCP/IP recomendados para gaming."
        Apply       = {
            netsh int ip set global dhcpmediasense=disabled | Out-Null
            netsh int ip set global icmpredirects=disabled | Out-Null
            netsh int tcp set global chimney=enabled | Out-Null
            netsh int tcp set global dca=enabled | Out-Null
            netsh int tcp set global rsc=disabled | Out-Null
            netsh int tcp set global timestamps=disabled | Out-Null
            netsh int tcp set global ecncapability=disabled | Out-Null
        }
        Revert      = {
            netsh int ip set global dhcpmediasense=enabled | Out-Null
            netsh int ip set global icmpredirects=enabled | Out-Null
            netsh int tcp set global chimney=disabled | Out-Null
            netsh int tcp set global dca=disabled | Out-Null
            netsh int tcp set global rsc=enabled | Out-Null
            netsh int tcp set global timestamps=enabled | Out-Null
            netsh int tcp set global ecncapability=enabled | Out-Null
        }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar Active Probing (NLA)"
        Category    = "Rede"
        Description = "Impede que o Windows verifique conectividade real da internet a cada rede."
        Apply       = { reg add "HKLM\System\CurrentControlSet\services\NlaSvc\Parameters\Internet" /v "EnableActiveProbing" /t REG_DWORD /d 0 /f | Out-Null }
        Revert      = { reg add "HKLM\System\CurrentControlSet\services\NlaSvc\Parameters\Internet" /v "EnableActiveProbing" /t REG_DWORD /d 1 /f | Out-Null }
    }

    # -------------------- PRIVACIDADE / TELEMETRIA --------------------
    [PSCustomObject]@{
        Name        = "Desabilitar Servicos de Telemetria (DiagTrack / dmwappushservice)"
        Category    = "Privacidade"
        Description = "Coloca os servicos de coleta de dados como 'manual' (nao iniciam sozinhos) e bloqueia AllowTelemetry."
        Apply       = {
            sc.exe config DiagTrack start= demand | Out-Null
            sc.exe config dmwappushservice start= demand | Out-Null
            sc.exe config diagnosticshub.standardcollector.service start= demand | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f | Out-Null
        }
        Revert      = {
            sc.exe config DiagTrack start= auto | Out-Null
            sc.exe config dmwappushservice start= auto | Out-Null
            sc.exe config diagnosticshub.standardcollector.service start= demand | Out-Null
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /f 2>$null | Out-Null
        }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar Tarefas Agendadas de Telemetria (CEIP / Compatibilidade / Office)"
        Category    = "Privacidade"
        Description = "Desativa as tarefas do Agendador de Tarefas usadas para coletar telemetria e dados de compatibilidade."
        Apply       = { Set-ScheduledTaskState -Tasks $TelemetryTasks }
        Revert      = { Set-ScheduledTaskState -Tasks $TelemetryTasks -Enable }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar Windows Error Reporting"
        Category    = "Privacidade"
        Description = "Impede o envio automatico de relatorios de erro para a Microsoft."
        Apply       = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v "Disabled" /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v "DoReport" /t REG_DWORD /d 0 /f | Out-Null
        }
        Revert      = {
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v "Disabled" /f 2>$null | Out-Null
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v "DoReport" /f 2>$null | Out-Null
        }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar Activity Feed / Timeline"
        Category    = "Privacidade"
        Description = "Impede o upload/publicacao do seu historico de atividades."
        Apply       = {
            $k = "HKLM\SOFTWARE\Policies\Microsoft\Windows\System"
            reg add $k /v "EnableActivityFeed" /t REG_DWORD /d 0 /f | Out-Null
            reg add $k /v "PublishUserActivities" /t REG_DWORD /d 0 /f | Out-Null
            reg add $k /v "UploadUserActivities" /t REG_DWORD /d 0 /f | Out-Null
        }
        Revert      = {
            $k = "HKLM\SOFTWARE\Policies\Microsoft\Windows\System"
            reg add $k /v "EnableActivityFeed" /t REG_DWORD /d 1 /f | Out-Null
            reg add $k /v "PublishUserActivities" /t REG_DWORD /d 1 /f | Out-Null
            reg add $k /v "UploadUserActivities" /t REG_DWORD /d 1 /f | Out-Null
        }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar Advertising ID"
        Category    = "Privacidade"
        Description = "Impede que apps usem seu ID de publicidade para personalizar anuncios."
        Apply       = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v "DisabledByGroupPolicy" /t REG_DWORD /d 1 /f | Out-Null
        }
        Revert      = {
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d 1 /f | Out-Null
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v "DisabledByGroupPolicy" /f 2>$null | Out-Null
        }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar Localizacao (GPS/Location)"
        Category    = "Privacidade"
        Description = "Bloqueia o rastreamento de localizacao em nivel de sistema."
        Apply       = {
            $k = "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
            reg add $k /v "DisableLocation" /t REG_DWORD /d 1 /f | Out-Null
            reg add $k /v "DisableWindowsLocationProvider" /t REG_DWORD /d 1 /f | Out-Null
            reg add $k /v "DisableSensors" /t REG_DWORD /d 1 /f | Out-Null
        }
        Revert      = {
            $k = "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
            reg delete $k /v "DisableLocation" /f 2>$null | Out-Null
            reg delete $k /v "DisableWindowsLocationProvider" /f 2>$null | Out-Null
            reg delete $k /v "DisableSensors" /f 2>$null | Out-Null
        }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar Delivery Optimization (P2P de updates)"
        Category    = "Privacidade"
        Description = "Impede que seu PC compartilhe/baixe updates de outros PCs pela internet."
        Apply       = { reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v "DODownloadMode" /t REG_DWORD /d 0 /f | Out-Null }
        Revert      = { reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v "DODownloadMode" /t REG_DWORD /d 1 /f | Out-Null }
    }

    # -------------------- SISTEMA / SERVICOS --------------------
    [PSCustomObject]@{
        Name        = "Desabilitar Bluetooth (servicos)"
        Category    = "Sistema"
        Description = "Desativa os servicos de Bluetooth caso voce nao use. Marque pra desligar, desmarque e reverta pra religar."
        Apply       = {
            foreach ($svc in @("BTAGService", "bthserv", "BthAvctpSvc", "BluetoothUserService")) { Set-ServiceStart -ServiceName $svc -StartValue 4 }
        }
        Revert      = {
            Set-ServiceStart -ServiceName "BTAGService" -StartValue 3
            Set-ServiceStart -ServiceName "bthserv" -StartValue 2
            Set-ServiceStart -ServiceName "BthAvctpSvc" -StartValue 3
            Set-ServiceStart -ServiceName "BluetoothUserService" -StartValue 3
        }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar SysMain (Superfetch)"
        Category    = "Sistema"
        Description = "Desativa o pre-carregamento de apps em memoria - recomendado para SSD/NVMe."
        Apply       = { Set-ServiceStart -ServiceName "SysMain" -StartValue 4 }
        Revert      = { Set-ServiceStart -ServiceName "SysMain" -StartValue 2 }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar Servicos Xbox em segundo plano"
        Category    = "Sistema"
        Description = "Desativa XblAuthManager, XblGameSave, XboxNetApiSvc e XboxGipSvc (nao afeta o Xbox Game Bar em si)."
        Apply       = {
            foreach ($svc in @("XblAuthManager", "XblGameSave", "XboxNetApiSvc", "XboxGipSvc")) { Set-ServiceStart -ServiceName $svc -StartValue 4 }
        }
        Revert      = {
            foreach ($svc in @("XblAuthManager", "XblGameSave", "XboxNetApiSvc", "XboxGipSvc")) { Set-ServiceStart -ServiceName $svc -StartValue 3 }
        }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar Mapas Baixados (MapsBroker)"
        Category    = "Sistema"
        Description = "Desativa o gerenciador de mapas offline em segundo plano."
        Apply       = { Set-ServiceStart -ServiceName "MapsBroker" -StartValue 4 }
        Revert      = { Set-ServiceStart -ServiceName "MapsBroker" -StartValue 3 }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar SmartScreen"
        Category    = "Sistema"
        Description = "Desativa a verificacao do SmartScreen ao abrir apps/arquivos desconhecidos."
        Apply       = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "Off" /f | Out-Null
        }
        Revert      = {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "On" /f | Out-Null
        }
    }

    [PSCustomObject]@{
        Name        = "Desabilitar ETW Autologgers"
        Category    = "Sistema"
        Description = "Desativa multiplos loggers internos do Windows que consomem I/O e CPU em segundo plano."
        Apply       = {
            $loggers = "AppModel", "Cellcore", "CloudExperienceHostOobe", "DiagLog", "ReadyBoot", "SQMLogger", "TCPIPLOGGER", "WiFiSession"
            foreach ($l in $loggers) { reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$l" /v "Start" /t REG_DWORD /d 0 /f | Out-Null }
        }
        Revert      = {
            $loggers = "AppModel", "Cellcore", "CloudExperienceHostOobe", "DiagLog", "ReadyBoot", "SQMLogger", "TCPIPLOGGER", "WiFiSession"
            foreach ($l in $loggers) { reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$l" /v "Start" /t REG_DWORD /d 1 /f | Out-Null }
        }
    }
)

# -------------------- DEBLOAT (gerado a partir de $DebloatApps) --------------------
foreach ($app in $DebloatApps) {
    $pattern = $app.Pattern
    $display = $app.Display
    $Tweaks += [PSCustomObject]@{
        Name        = "Remover: $display"
        Category    = "Debloat"
        Description = "Desinstala o app '$display' ($pattern) para todos os usuarios e remove o pacote provisionado."
        Apply       = {
            Get-AppxPackage -AllUsers "*$pattern*" -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$pattern*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        }.GetNewClosure()
        Revert      = {
            Write-Log "  [INFO] Apps removidos nao podem ser reinstalados automaticamente pelo painel."
            Write-Log "  [INFO] Reinstale pela Microsoft Store, se necessario."
        }.GetNewClosure()
    }
}

# ==========================================================================
# ETAPA 3: Interface Grafica (XAML + WPF) - estilo sidebar, inspirado no
# painel do Chris Titus Tech (WinUtil), com tema escuro e cards.
# ==========================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="LAIT TWEAKS" Height="760" Width="1080"
        WindowStartupLocation="CenterScreen" Background="#FF0D0D10">

    <Window.Resources>
        <LinearGradientBrush x:Key="AccentGradient" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#FF8B5CF6" Offset="0"/>
            <GradientStop Color="#FF6366F1" Offset="1"/>
        </LinearGradientBrush>
        <SolidColorBrush x:Key="AccentBrush" Color="#FF8B5CF6"/>
        <SolidColorBrush x:Key="CardBrush" Color="#FF1B1B22"/>
        <SolidColorBrush x:Key="CardBorderBrush" Color="#FF2A2A34"/>

        <Style x:Key="SideTabItem" TargetType="TabItem">
            <Setter Property="Foreground" Value="#FFD6D6DE"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border x:Name="Bd" Background="Transparent" CornerRadius="8" Padding="12,11" Margin="0,3,10,0">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="4"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Border x:Name="AccentBar" Grid.Column="0" Width="4" CornerRadius="2" Background="{StaticResource AccentBrush}" Opacity="0"/>
                                <ContentPresenter Grid.Column="1" ContentSource="Header" Margin="12,0,0,0" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#FF201C2B"/>
                                <Setter TargetName="AccentBar" Property="Opacity" Value="1"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#FF17151D"/>
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
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Opacity" Value="0.88"/>
                            </Trigger>
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
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#FF232330"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <DockPanel LastChildFill="True">

        <!-- HEADER -->
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
                    <TextBlock Text="Painel de Otimizacao para Windows - Gaming, Rede, Privacidade e Debloat" Foreground="#FF9A9AA5" FontSize="12" Margin="0,2,0,0"/>
                </StackPanel>

                <StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Right">
                    <TextBlock x:Name="CounterText" Text="0 selecionados" Foreground="{StaticResource AccentBrush}" FontWeight="Bold" FontSize="13" HorizontalAlignment="Right"/>
                    <TextBlock x:Name="TotalText" Text="" Foreground="#FF7A7A85" FontSize="11" HorizontalAlignment="Right" Margin="0,2,0,0"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- FOOTER: BOTOES + LOG -->
        <Border DockPanel.Dock="Bottom" Background="#FF141218" Padding="18,14">
            <StackPanel>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
                    <Button x:Name="BtnRestore" Content="Criar Ponto de Restauracao" Style="{StaticResource BtnGhost}" Width="200" Height="36" Margin="0,0,10,0"/>
                    <Button x:Name="BtnSelectAll" Content="Marcar Todos (aba atual)" Style="{StaticResource BtnGhost}" Width="190" Height="36" Margin="0,0,10,0"/>
                    <Button x:Name="BtnClearAll" Content="Limpar Selecao" Style="{StaticResource BtnGhost}" Width="150" Height="36" Margin="0,0,10,0"/>
                    <Button x:Name="BtnRevert" Content="Reverter Selecionados" Style="{StaticResource BtnGhost}" Width="180" Height="36" Margin="0,0,10,0"/>
                    <Button x:Name="BtnApply" Content="Aplicar Selecionados" Style="{StaticResource BtnPrimary}" Width="190" Height="36"/>
                </StackPanel>

                <Border Background="#FF0A0A0C" CornerRadius="8" Margin="0,12,0,0" Padding="10">
                    <TextBox x:Name="LogBox" Height="110" Background="Transparent" Foreground="#FF8DFFA0" BorderThickness="0"
                             FontFamily="Consolas" FontSize="12" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"/>
                </Border>
            </StackPanel>
        </Border>

        <!-- CORPO: SIDEBAR + CARDS -->
        <TabControl x:Name="Tabs" Margin="18,10,18,0" Background="Transparent" BorderThickness="0"
                    TabStripPlacement="Left" ItemContainerStyle="{StaticResource SideTabItem}"/>

    </DockPanel>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$Tabs         = $window.FindName("Tabs")
$BtnApply     = $window.FindName("BtnApply")
$BtnRevert    = $window.FindName("BtnRevert")
$BtnRestore   = $window.FindName("BtnRestore")
$BtnSelectAll = $window.FindName("BtnSelectAll")
$BtnClearAll  = $window.FindName("BtnClearAll")
$CounterText  = $window.FindName("CounterText")
$TotalText    = $window.FindName("TotalText")
$Global:LogBox = $window.FindName("LogBox")

# --- Ordem fixa das categorias (Rede, Debloat e Privacidade bem separados) ---
$categoryOrder = @("Gaming", "Rede", "Privacidade", "Debloat", "Sistema")
$categories = $categoryOrder | Where-Object { $Tweaks.Category -contains $_ }

$checkboxMap = @{}   # CheckBox -> objeto tweak

function Update-Counter {
    $checked = @($checkboxMap.Keys | Where-Object { $_.IsChecked -eq $true })
    $CounterText.Text = "$($checked.Count) selecionados"
}

foreach ($cat in $categories) {
    $tab = New-Object System.Windows.Controls.TabItem
    $tab.Header = $cat
    $tab.Background = "Transparent"

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = "16,4,4,4"

    foreach ($t in ($Tweaks | Where-Object { $_.Category -eq $cat })) {
        $title = New-Object System.Windows.Controls.TextBlock
        $title.Text = $t.Name
        $title.FontSize = 14
        $title.FontWeight = "SemiBold"
        $title.Foreground = "#FFECECF1"
        $title.TextWrapping = "Wrap"

        $desc = New-Object System.Windows.Controls.TextBlock
        $desc.Text = $t.Description
        $desc.FontSize = 11.5
        $desc.Foreground = "#FF9A9AA5"
        $desc.Margin = "0,4,0,0"
        $desc.TextWrapping = "Wrap"

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
    $tab.Content = $scroll
    $Tabs.Items.Add($tab) | Out-Null
}

$TotalText.Text = "$($Tweaks.Count) tweaks em $($categories.Count) categorias"

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
    catch {
        Write-Log "[ERRO] Nao foi possivel criar o ponto de restauracao: $($_.Exception.Message)"
    }
})

$BtnSelectAll.Add_Click({
    $activeTab = $Tabs.SelectedItem
    if (-not $activeTab) { return }
    $panel = $activeTab.Content.Content
    foreach ($child in $panel.Children) {
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
        try {
            & $t.Apply
            Write-Log "  [OK]"
        }
        catch {
            Write-Log "  [ERRO] $($_.Exception.Message)"
        }
    }
    Write-Log "Concluido."
})

$BtnRevert.Add_Click({
    $selected = $checkboxMap.GetEnumerator() | Where-Object { $_.Key.IsChecked -eq $true }
    if (@($selected).Count -eq 0) { Write-Log "Nenhum tweak selecionado."; return }
    foreach ($item in $selected) {
        $t = $item.Value
        Write-Log "Revertendo: $($t.Name)..."
        try {
            & $t.Revert
            Write-Log "  [OK]"
        }
        catch {
            Write-Log "  [ERRO] $($_.Exception.Message)"
        }
    }
    Write-Log "Concluido."
})

Write-Log "LAIT TWEAKS carregado. $($Tweaks.Count) tweaks disponiveis em $($categories.Count) categorias."
Write-Log "Dica: crie um ponto de restauracao antes de aplicar tweaks de sistema."
$window.ShowDialog() | Out-Null
