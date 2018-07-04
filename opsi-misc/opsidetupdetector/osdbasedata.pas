unit osdbasedata;

{$mode delphi}

interface

uses
  Classes, SysUtils;

type
  TArchitectureMode = (am32only_fix, am64only_fix, amBoth_fix, amSystemSpecific_fix,
    amSelectable);
  TKnownInstaller = (stAdvancedMSI, stInno, stInstallShield, stInstallShieldMSI,
    stMsi, stNsis, st7zip, stUnknown);


  TdetectInstaller = function(parent: TClass; markerlist: TStringList): boolean;


  TInstallerData = class
    installerId: TKnownInstaller;
    Name: string;
    description: string;
    patterns: TStringList;
    silentsetup: string;
    unattendedsetup: string;
    silentuninstall: string;
    unattendeduninstall: string;
    uninstall_waitforprocess: string;
    comment: string;
    Link: string;
  private
  public
    detected: TdetectInstaller;
    { public declarations }
    constructor Create;
    destructor Destroy;

  end;

  TInstallers = array of TInstallerData;

  TProductData = record
    setup32FileNamePath: string;
    setup32FileName: string;
    setup32FileSize: cardinal;
    setup64FileNamePath: string;
    setup64FileName: string;
    setup64FileSize: cardinal;
    architectureMode: TArchitectureMode;
    msiId: string;
    mst32FileNamePath: string;
    mst32FileName: string;
    mst64FileNamePath: string;
    mst64FileName: string;
    msi32FullFileName: string;
    msi64FullFileName: string;
    istallerId: TKnownInstaller;
    requiredSpace: cardinal;
    installDirectory: string;
    comment: string;
    description: string;
    advice: string;
    productId: string;
    productName: string;
    productversion: string;
    packageversion: cardinal;
    versionstr: string;
    priority: integer;
    producttype: string;
    setupscript: string;
    uninstallscript: string;
    licenserequired: boolean;
    markerlist: TStringList;
  end;

function archModeStrToArchmode(modestr: string): TArchitectureMode;
function installerToInstallerstr(installerId: TKnownInstaller): string;
function instIdToint(installerId: TKnownInstaller): integer;
procedure initaktproduct;

var
  aktProduct: TProductData;
  knownInstallerList: TStringList;
  architectureModeList: TStringList;
  installerArray: TInstallers;
  counter: integer;

implementation

constructor TInstallerData.Create;
begin
  patterns := TStringList.Create;
  inherited;
end;

destructor TInstallerData.Destroy;
begin
  patterns.Free;
  inherited;
end;

function archModeStrToArchmode(modestr: string): TArchitectureMode;
begin
  Result := TArchitectureMode(architectureModeList.IndexOf(modestr));
end;

function installerToInstallerstr(installerId: TKnownInstaller): string;
begin
  Result := knownInstallerList.Strings[integer(installerId)];
end;

function instIdToint(installerId: TKnownInstaller): integer;
begin
  Result := integer(installerId);
end;

function detecteddummy(parent: TClass; markerlist: TStringList): boolean;
var
  i1, i2, i3, i4, i5, i6: integer;
begin
  Result := False;
end;


function detectedinno(parent: TClass; markerlist: TStringList): boolean;
var
  i1, i2, i3, i4, i5, i6: integer;
begin
  Result := False;
  markerlist.Sort;
  if markerlist.Find(TInstallerData(parent).patterns[0], i1) or
    markerlist.Find(TInstallerData(parent).patterns[1], i2) then
    Result := True;
end;

function detectedbypatternwithor(parent: TClass; markerlist: TStringList): boolean;
var
  tmpint: integer;
  patternindex: integer;
  pattern: string;
begin
  Result := False;
  //markerlist.Sort;
  for patternindex := 0 to TInstallerData(parent).patterns.Count - 1 do
  begin
    pattern := TInstallerData(parent).patterns[patternindex];
    if markerlist.IndexOf(LowerCase(pattern)) >= 0 then
      Result := True;
  end;
end;

procedure initaktproduct;
begin
  with aktProduct do
  begin
    setup32FileNamePath := '';
    setup32FileName := '';
    setup32FileSize := 0;
    setup64FileNamePath := '';
    setup64FileName := '';
    setup64FileSize := 0;
    architectureMode := am32only_fix;
    msiId := '';
    mst32FileNamePath := '';
    mst32FileName := '';
    mst64FileNamePath := '';
    mst64FileName := '';
    msi32FullFileName := '';
    msi64FullFileName := '';
    istallerId := stUnknown;
    requiredSpace := 0;
    installDirectory := '';
    comment := '';
    description := '';
    advice := '';
    productId := '';
    productName := '';
    productversion := '';
    packageversion := 1;
    versionstr := '';
    priority := 0;
    producttype := 'localboot';
    setupscript := 'setup.opsiscript';
    uninstallscript := 'uninstall.psiscript';
    licenserequired := False;
    markerlist.Clear;
  end;
end;

begin
  knownInstallerList := TStringList.Create;
  knownInstallerList.Add('AdvancedMSI');
  knownInstallerList.Add('Inno');
  knownInstallerList.Add('InstallShield');
  knownInstallerList.Add('InstallShieldMSI');
  knownInstallerList.Add('MSI');
  knownInstallerList.Add('NSIS');
  knownInstallerList.Add('7zip');

  for counter := 0 to knownInstallerList.Count - 1 do
  begin
    SetLength(installerArray, counter + 1);
    installerArray[counter] := TInstallerData.Create;
    installerArray[counter].installerId := TKnownInstaller(counter);
    installerArray[counter].Name := knownInstallerList.Strings[counter];
  end;
  // inno
  installerArray[integer(stInno)].description := 'Inno Setup';
  installerArray[integer(stInno)].silentsetup :=
    '/sp- /verysilent /norestart /nocancel /SUPPRESSMSGBOXES';
  installerArray[integer(stInno)].unattendedsetup :=
    '/sp- /silent /norestart /nocancel /SUPPRESSMSGBOXES';
  installerArray[integer(stInno)].silentuninstall :=
    '/verysilent /norestart /nocancel /SUPPRESSMSGBOXES';
  installerArray[integer(stInno)].unattendeduninstall :=
    '/silent /norestart /nocancel /SUPPRESSMSGBOXES';
  installerArray[integer(stInno)].uninstall_waitforprocess := '';
  installerArray[integer(stInno)].patterns.Add('<description>inno setup</description>');
  installerArray[integer(stInno)].patterns.Add('jr.inno.setup');
  installerArray[integer(stInno)].link :=
    'http://www.jrsoftware.org/ishelp/topic_setupcmdline.htm';
  installerArray[integer(stInno)].comment := '';
  installerArray[integer(stInno)].detected := @detectedbypatternwithor;
  // NSIS
  installerArray[integer(stNsis)].description := 'Nullsoft Install System';
  installerArray[integer(stNsis)].silentsetup := '/S';
  installerArray[integer(stNsis)].unattendedsetup := '/S';
  installerArray[integer(stNsis)].silentuninstall := '/S';
  installerArray[integer(stNsis)].unattendeduninstall := '/S';
  installerArray[integer(stNsis)].uninstall_waitforprocess := 'Au_.exe';
  installerArray[integer(stNsis)].patterns.Add('Nullsoft.NSIS.exehead');
  installerArray[integer(stNsis)].patterns.Add('nullsoft install system');
  installerArray[integer(stNsis)].link :=
    'http://nsis.sourceforge.net/Docs/Chapter3.html#installerusage';
  installerArray[integer(stNsis)].comment := '';
  installerArray[integer(stNsis)].detected := @detectedbypatternwithor;
  // InstallShieldMSI
  installerArray[integer(stInstallShieldMSI)].description :=
    'InstallShield+MSI Setup (InstallShield with embedded MSI)';
  installerArray[integer(stInstallShieldMSI)].silentsetup :=
    '/s /v" /qn ALLUSERS=1 REBOOT=ReallySuppress"';
  installerArray[integer(stInstallShieldMSI)].unattendedsetup :=
    '/s /v" /qb-! ALLUSERS=1 REBOOT=ReallySuppress"';
  installerArray[integer(stInstallShieldMSI)].silentuninstall :=
    '/s /v" /qn ALLUSERS=1 REBOOT=ReallySuppress"';
  installerArray[integer(stInstallShieldMSI)].unattendeduninstall :=
    '/s /v" /qb-! ALLUSERS=1 REBOOT=ReallySuppress"';
  installerArray[integer(stInstallShieldMSI)].uninstall_waitforprocess := '';
  installerArray[integer(stInstallShieldMSI)].patterns.Add('nstallshield');
  installerArray[integer(stInstallShieldMSI)].patterns.Add('installer,msi,database');
  installerArray[integer(stInstallShieldMSI)].link :=
    'http://helpnet.flexerasoftware.com/installshield19helplib/helplibrary/IHelpSetup_EXECmdLine.htm';
  installerArray[integer(stInstallShieldMSI)].comment := '';
  installerArray[integer(stInstallShieldMSI)].detected := @detectedbypatternwithor;
  // InstallShield
  installerArray[integer(stInstallShield)].description :=
    'InstallShield Setup (classic)';
  installerArray[integer(stInstallShield)].silentsetup := '/s /sms';
  installerArray[integer(stInstallShield)].unattendedsetup := '/s /sms';
  installerArray[integer(stInstallShield)].silentuninstall := '/s /sms';
  installerArray[integer(stInstallShield)].unattendeduninstall := '/s /sms';
  installerArray[integer(stInstallShield)].uninstall_waitforprocess := '';
  installerArray[integer(stInstallShield)].patterns.Add('InstallShield');
  installerArray[integer(stInstallShield)].patterns.Add(
    '<description>InstallShield.Setup</description>');
  installerArray[integer(stInstallShield)].link :=
    'http://helpnet.flexerasoftware.com/installshield19helplib/helplibrary/IHelpSetup_EXECmdLine.htm';
  installerArray[integer(stInstallShield)].comment := '';
  installerArray[integer(stInstallShield)].detected := @detectedbypatternwithor;

  architectureModeList := TStringList.Create;
  architectureModeList.Add('32BitOnly - fix');
  architectureModeList.Add('64BitOnly - fix');
  architectureModeList.Add('both - fix');
  architectureModeList.Add('systemSpecific - fix');
  architectureModeList.Add('selectable');



  aktProduct.markerlist := TStringList.Create;

end.
