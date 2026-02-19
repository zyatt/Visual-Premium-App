; ====================================
; 📦 VISUAL PREMIUM - INSTALADOR
; ====================================
#define MyAppName "Visual Premium"
#define MyAppVersion "3.2.0"
#define MyAppPublisher "Matheus Vinícius"
#define MyAppExeName "visualpremium.exe"
#define MyAppId "{{7B8E0F9A-2C4D-4B1E-9A0A-3C8E2F5A1234}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=logo.ico
OutputDir=.
OutputBaseFilename=VisualPremiumSetup-{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
; --- Atualização inteligente ---
CloseApplications=force
RestartApplications=yes
DisableDirPage=auto
DisableProgramGroupPage=auto
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoCopyright=Copyright © 2024-2026 {#MyAppPublisher}

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Área de Trabalho"; GroupDescription: "Atalhos:"; Flags: checkablealone

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "config.json"; DestDir: "{commonappdata}\VisualPremium"; Flags: onlyifdoesntexist uninsneveruninstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKLM; Subkey: "Software\{#MyAppPublisher}\{#MyAppName}"; \
ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"; \
Flags: uninsdeletekey

; ============================
; 🚀 ABRIR APP AUTOMATICAMENTE
; ============================
[Run]
; Para atualização silenciosa (Flutter) — abre automaticamente
Filename: "{app}\{#MyAppExeName}"; \
Flags: nowait; \
Check: ShouldRunApp

; Para instalação manual — mostra checkbox pro usuário
Filename: "{app}\{#MyAppExeName}"; \
Description: "Abrir {#MyAppName}"; \
Flags: nowait postinstall skipifsilent

[Code]
var
  IsUpgradeInstall: Boolean;

function IsUpgrade(): Boolean;
var
  OldVersion: String;
begin
  Result := RegQueryStringValue(
    HKLM,
    'Software\{#MyAppPublisher}\{#MyAppName}',
    'Version',
    OldVersion
  );
end;

function InitializeSetup(): Boolean;
begin
  IsUpgradeInstall := IsUpgrade();
  if IsUpgradeInstall then
    Log('Modo: ATUALIZAÇÃO')
  else
    Log('Modo: INSTALAÇÃO NOVA');
  Result := True;
end;

function ShouldRunApp(): Boolean;
begin
  // Só executa na atualização silenciosa (vindo do Flutter)
  // Na instalação manual o segundo [Run] com checkbox cuida disso
  if WizardSilent and IsUpgradeInstall then
  begin
    Log('Abrindo app após atualização silenciosa...');
    Result := True;
    Exit;
  end;

  Result := False;
end;
