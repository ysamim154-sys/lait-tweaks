# LAIT TWEAKS

Painel gráfico (GUI) de otimização para Windows, em PowerShell + WPF, organizado em:

- 🎮 **Gaming** — timer resolution, prioridade de jogos, Win32PrioritySeparation, plano de energia, Game DVR
- 🌐 **Rede** — TCP tuning, Nagle, heurísticas TCP, IPv6, ICMP/Chimney, Active Probing
- 🛡️ **Privacidade** — telemetria (DiagTrack), tarefas agendadas de CEIP/Office, Error Reporting, Activity Feed, Advertising ID, Localização, Delivery Optimization
- 🧹 **Debloat** — remove ~26 apps embutidos da Microsoft (Weather, Skype, Solitaire, Cortana, Copilot, etc.)
- ⚙️ **Sistema** — Bluetooth, SysMain, serviços Xbox, MapsBroker, SmartScreen, ETW Autologgers

Cada tweak tem **Aplicar** e **Reverter** independentes, e um log ao vivo mostra o que está sendo feito.

> ⚠️ Use por sua conta e risco. Crie um ponto de restauração (botão no painel) antes de aplicar tweaks de sistema.

---

## Como usar (local)

```powershell
powershell -ExecutionPolicy Bypass -File .\LaitTweaksGUI.ps1
```

O script pede elevação de Administrador automaticamente.

## Como hospedar no GitHub para rodar via `irm | iex`

1. Crie um repositório público, por exemplo `lait-tweaks`, e suba o arquivo `LaitTweaksGUI.ps1` na branch `main`.
2. Pegue a URL **raw** do arquivo. Formato:
   ```
   https://raw.githubusercontent.com/SEU-USUARIO/lait-tweaks/main/LaitTweaksGUI.ps1
   ```
3. Abra `LaitTweaksGUI.ps1` e edite a linha perto do topo:
   ```powershell
   $Global:RepoRawUrl = "https://raw.githubusercontent.com/SEU-USUARIO/lait-tweaks/main/LaitTweaksGUI.ps1"
   ```
   Troque `SEU-USUARIO` (e o nome do repo, se for diferente) pela sua URL real. Isso é usado apenas como
   fallback: quando o script roda via `irm | iex` (sem estar salvo em disco) e precisa se re-abrir como
   Administrador, ele usa essa URL para baixar e rodar a si mesmo de novo já elevado.
4. Faça commit dessa alteração.
5. Qualquer pessoa agora pode rodar o painel com um único comando no PowerShell:
   ```powershell
   irm https://raw.githubusercontent.com/SEU-USUARIO/lait-tweaks/main/LaitTweaksGUI.ps1 | iex
   ```

### Por que isso funciona sem admin de primeira?

Quando o script roda local (`-File`), ele reabre a si mesmo usando `$PSCommandPath`.
Quando roda via `irm | iex`, não existe arquivo em disco (`$PSCommandPath` fica vazio), então o script
detecta isso e reabre a si mesmo com `Start-Process powershell -Verb RunAs -ArgumentList "-Command irm '<RepoRawUrl>' | iex"`,
baixando e reexecutando o script já como Administrador.

## Estrutura do repositório

```
lait-tweaks/
├── LaitTweaksGUI.ps1   # painel completo (self-contained, sem dependências externas)
└── README.md
```

## Aviso legal

Este projeto mexe em registro do Windows, serviços e pacotes de sistema. Não há garantias.
Recomenda-se sempre criar um ponto de restauração antes de aplicar qualquer tweak.
