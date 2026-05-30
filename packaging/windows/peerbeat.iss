; Inno Setup script for PeerBeat (Windows installer).
; Build:  iscc packaging\windows\peerbeat.iss   (after `flutter build windows --release`)
; Produces dist\PeerBeat-Setup-<version>.exe

#define AppName "PeerBeat"
#define AppVersion "0.1.0"
#define AppPublisher "RamazanBerk20"
#define AppURL "https://github.com/RamazanBerk20/PeerBeat"
#define AppExe "peerbeat.exe"
; Flutter release output dir (relative to this .iss):
#define BuildDir "..\..\apps\peerbeat\build\windows\x64\runner\Release"
#define IconFile "..\..\assets\icon\generated\windows\peerbeat.ico"

[Setup]
AppId={{B7E1B0E2-9C3A-4E7A-9A2E-PEERBEAT0001}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}
OutputDir=..\..\dist
OutputBaseFilename=PeerBeat-Setup-{#AppVersion}
SetupIconFile={#IconFile}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Allow silent install:  PeerBeat-Setup-x.y.z.exe /VERYSILENT /NORESTART
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
