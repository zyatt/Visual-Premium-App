[Setup]
AppId={{7B8E0F9A-2C4D-4B1E-9A0A-3C8E2F5A1234}
AppName=Visual Premium
AppVersion=1.0.0
AppPublisher=Matheus Vinícius
UninstallDisplayName=Visual Premium
DefaultDirName={autopf}\Visual Premium
PrivilegesRequired=admin
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\visualpremium.exe
SetupIconFile=logo.ico
OutputDir=.
OutputBaseFilename=VisualPremiumSetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "config.json"; DestDir: "{commonappdata}\VisualPremium"; Flags: onlyifdoesntexist

[Icons]
Name: "{group}\Visual Premium"; Filename: "{app}\visualpremium.exe"
Name: "{commondesktop}\Visual Premium"; Filename: "{app}\visualpremium.exe"

[Registry]
; Remove a versão do Painel de Controle (Programas e Recursos)
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting('AppId')}_is1"; \
    ValueName: "DisplayVersion"; Flags: deletevalue
