#define MyAppName "BirdNET Live"
#define MyAppPublisher "BirdNET"
#define MyAppExeName "birdnet_live.exe"

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#ifndef MySourceDir
  #define MySourceDir "build\\windows\\x64\\runner\\Release"
#endif

#ifndef MyOutputDir
  #define MyOutputDir "build\\windows\\x64\\runner"
#endif

#ifndef MyOutputBaseFilename
  #define MyOutputBaseFilename "BirdNET_Live_v" + MyAppVersion + "_windows_x64_setup"
#endif

[Setup]
AppId={{A26F9469-032F-48BB-949C-7C7087CFAE87}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/AndyB1979/birdnet-live-app
AppSupportURL=https://github.com/AndyB1979/birdnet-live-app
AppUpdatesURL=https://github.com/AndyB1979/birdnet-live-app/releases
DefaultDirName={autopf}\BirdNET Live
DefaultGroupName=BirdNET Live
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma
SolidCompression=yes
WizardStyle=modern
OutputDir={#MyOutputDir}
OutputBaseFilename={#MyOutputBaseFilename}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#MySourceDir}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\BirdNET Live"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall BirdNET Live"; Filename: "{uninstallexe}"
Name: "{autodesktop}\BirdNET Live"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch BirdNET Live"; Flags: nowait postinstall skipifsilent
