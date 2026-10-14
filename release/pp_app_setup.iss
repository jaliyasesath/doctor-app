#ifndef AppVersion
  #error Supply AppVersion from build_windows_release.ps1
#endif
#ifndef BuildNumber
  #error Supply BuildNumber
#endif
#ifndef AppExe
  #error Supply AppExe
#endif
#ifndef ReleaseDir
  #error Supply ReleaseDir
#endif
#ifndef InstallerOutput
  #error Supply InstallerOutput
#endif

#ifndef ArtifactSuffix
  #define ArtifactSuffix ""
#endif

[Setup]
; Permanent identity: never regenerate this ID between releases.
AppId={{4B749F0C-F39A-474F-8E2E-9586F2540179}
AppName=PP App
AppVersion={#AppVersion}
AppVerName=PP App {#AppVersion}
DefaultDirName={localappdata}\Programs\PP App
DefaultGroupName=PP App
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#InstallerOutput}
OutputBaseFilename=PP_App_Setup_{#AppVersion}_{#BuildNumber}{#ArtifactSuffix}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=app_icon.ico
UninstallDisplayIcon={app}\pp_app_icon.ico
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#AppVersion}.{#BuildNumber}

[Tasks]
Name: desktopicon; Description: "Create a desktop shortcut"

[Files]
; Ship the ENTIRE bundle, including plugins, encryption runtime, and assets.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

Source: "app_icon.ico"; DestDir: "{app}"; DestName: "pp_app_icon.ico"; Flags: ignoreversion

[Icons]
Name: "{group}\PP App"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; IconFilename: "{app}\pp_app_icon.ico"; IconIndex: 0
Name: "{autodesktop}\PP App"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; IconFilename: "{app}\pp_app_icon.ico"; IconIndex: 0; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Open PP App"; Flags: nowait postinstall skipifsilent

; Deliberately no user-data deletion, firewall changes or auto-start registration.
