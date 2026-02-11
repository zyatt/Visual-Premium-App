; ====================================
; 📦 VISUAL PREMIUM - INSTALADOR
; ====================================
; Suporta instalação inicial e atualizações automáticas

#define MyAppName "Visual Premium"
#define MyAppVersion "1.0.0"
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

; ✅ CONFIGURAÇÕES DE ATUALIZAÇÃO
CloseApplications=force
RestartApplications=yes
AllowNetworkDrive=no
DisableDirPage=auto
DisableProgramGroupPage=auto

; ✅ VERSIONAMENTO
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoCopyright=Copyright © 2024-2026 {#MyAppPublisher}

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Área de Trabalho"; GroupDescription: "Atalhos:"; Flags: checkablealone

[Files]
; Binários do app
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

; Config (só cria se não existir - preserva dados do usuário)
Source: "config.json"; DestDir: "{commonappdata}\VisualPremium"; Flags: onlyifdoesntexist uninsneveruninstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; ✅ Armazena a versão atual (usado para verificar se é atualização)
Root: HKLM; Subkey: "Software\{#MyAppPublisher}\{#MyAppName}"; ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"; Flags: uninsdeletekey

[Run]
; Executar após instalação (apenas em instalação nova, não em atualizações silenciosas)
Filename: "{app}\{#MyAppExeName}"; Description: "Iniciar {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
// ✅ FUNÇÃO: Detectar se é atualização
function IsUpgrade(): Boolean;
var
  OldVersion: String;
begin
  Result := RegQueryStringValue(HKLM, 'Software\{#MyAppPublisher}\{#MyAppName}', 'Version', OldVersion);
  if Result then
    Log('Versão anterior detectada: ' + OldVersion);
end;

// ✅ FUNÇÃO: Inicialização do instalador
function InitializeSetup(): Boolean;
begin
  Result := True;
  
  if IsUpgrade() then
  begin
    Log('Modo: ATUALIZAÇÃO');
  end
  else
  begin
    Log('Modo: INSTALAÇÃO NOVA');
  end;
end;

// ✅ EVENTO: Mudança de etapa (ÚNICO - SEM DUPLICAÇÃO)
procedure CurStepChanged(CurStep: TSetupStep);
begin
  // Antes de instalar
  if CurStep = ssInstall then
  begin
    if IsUpgrade() then
    begin
      Log('Atualizando aplicação existente...');
    end;
  end;
  
  // Após instalação
  if CurStep = ssPostInstall then
  begin
    Log('Instalação concluída com sucesso');
  end;
end;