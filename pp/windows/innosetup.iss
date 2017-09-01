# define APP	"EekBoek"
# define V_MAJ	0
# define V_MIN	85
# define V_AUX	0
# define BuildNum	27
# define PUBLISHER "Squirrel Consultancy"
# define SRC	"C:\Users\Johan\Documents\EekBoek"
# define DEST	"C:\Users\Johan\Documents\EekBoek"

; Increment the build number by one.
;#define BuildNum Int(ReadIni(SourcePath	+ "BuildInfo.ini","Info","Build","0"))
;#expr BuildNum = BuildNum + 1
;#expr WriteIni(SourcePath + "BuildInfo.ini","Info","Build", BuildNum)

[Setup]
AppID={{4f534cd5-1583-4eb5-8db2-b363db470831}
AppName={#APP}
AppVersion={#V_MAJ}.{#V_MIN}.{#V_AUX}.{#BuildNum}.0
AppVerName={#APP} {#V_MAJ}.{#V_MIN}
AppPublisher={#PUBLISHER}
DefaultDirName={pf}\{#PUBLISHER}\{#APP}
DefaultGroupName=\{#PUBLISHER}\{#APP}
OutputDir={#DEST}
OutputBaseFilename={#APP}-{#V_MAJ}-{#V_MIN}-{#V_AUX}-{#BuildNum}-x64
Compression=lzma/Max
SolidCompression=true
AppCopyright=Copyright (C) 2017 {#PUBLISHER}
PrivilegesRequired=none
InternalCompressLevel=Max
ShowLanguageDialog=no
LanguageDetectionMethod=none
WizardImageFile={#SRC}\ebinst.bmp

[Languages]
Name: "nl"; MessagesFile: "compiler:Languages\Dutch.isl"

[Tasks]
Name: desktopicon; Description: "Aanmaken bureaublad ikonen"; GroupDescription: "Extra ikonen:"; Languages: nl
Name: desktopicon\common; Description: "Voor alle gebruikers"; GroupDescription: "Extra ikonen:"; Flags: exclusive; Languages: nl
Name: desktopicon\user; Description: "Alleen voor de huidige gebruiker"; GroupDescription: "Extra ikonen:"; Flags: exclusive unchecked; Languages: nl

[Files]
Source: {#SRC}\ebwxshell.exe; DestDir: {app}\bin; Flags: ignoreversion recursesubdirs createallsubdirs overwritereadonly 64bit;

[Icons]
Name: {group}\{#APP}; Filename: {app}\bin\ebwxshell.exe; IconFilename: "{#SRC}\eb.ico";
Name: "{group}\{cm:UninstallProgram,{#APP}}"; Filename: "{uninstallexe}"

Name: "{commondesktop}\{#APP}"; Filename: "{app}\bin\ebwxshell.exe"; Tasks: desktopicon\common; IconFilename: "{#SRC}\eb.ico";
Name: "{userdesktop}\{#APP}"; Filename: "{app}\bin\ebwxshell.exe"; Tasks: desktopicon\user; IconFilename: "{#SRC}\eb.ico";

[Run]
Filename: "{app}\bin\ebwxshell.exe"; Description: "Voorbereiden"; Parameters: "--quit"; StatusMsg: "Voorbereiden... (even geduld)..."; Languages: nl

[Messages]
BeveledLabel=Perl Powered Software by Squirrel Consultancy
