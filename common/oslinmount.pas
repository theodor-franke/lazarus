unit oslinmount;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  CustApp ,
  process,
  blowfish,
  DCPblowfish,
  DCPcrypt2,
  DCPblockciphers,
  baseunix,
  fileinfo,
  elfreader,
  inifiles,
  oslog,
  oswebservice,
  superobject;

const
  SW_HIDE = 0;

type
  bytearray = array[0..255] of byte;

function isMounted(mountpoint : string) : boolean;
function mountSmbShare(mymountpoint, myshare, mydomain, myuser, mypass, myoption: string) : integer;
function umount(mymountpoint : string) : integer;
procedure transformHex(const hexstring : String; var hexarray : bytearray);
function decrypt(hexkey, hexpass : String) : String;
function DecryptBlowfish(const myencrypted,mykey: string): string;
function RunCommandAndCaptureOut
  (cmd: string; catchOut: boolean; var outlines: TStringList;
  var report: string; showcmd: integer; var ExitCode: longint): boolean;
procedure mount_depotshare(mymountpoint : string; myhostkey : string);

implementation

function divideAtFirst(const partialS, S: string; var part1, part2: string): boolean;
  (* teilt den String S beim ersten Vorkommen des Teilstrings partialS;
     liefert true, wenn partialS vorkommt,
     andernfalls false;

     wenn partialS nicht vorkommt, enthaelt part1 den Gesamtstring, part2 ist leer *)

var
  i: integer = 0;
begin
  i := pos(lowercase(partialS), lowercase(s));
  if i > 0 then
  begin
    part1 := copy(S, 1, i - 1);
    part2 := copy(S, i + length(partialS), length(S));
    Result := True;
  end
  else
  begin
    part1 := s;
    part2 := '';
    Result := False;
  end;
end;

function RunCommandAndCaptureOut
  (cmd: string; catchOut: boolean; var outlines: TStringList;
  var report: string; showcmd: integer; var ExitCode: longint): boolean;
const
  ReadBufferSize = 2048;

var
  //myStringlist : TStringlist;
  S: TStringList;
  M: TMemoryStream;
  FpcProcess: TProcess;
  n: longint;
  BytesRead: longint;

begin
  Result := True;
  try
    try
      M := TMemoryStream.Create;
      BytesRead := 0;
      FpcProcess := process.TProcess.Create(nil);
      FpcProcess.CommandLine := cmd;
      FpcProcess.Options := [poUsePipes, poStderrToOutput];
      FpcProcess.ShowWindow := swoMinimize;
      FpcProcess.Execute;
      //Logdatei.DependentAdd('RunCommandAndCaptureOut: started: ' + cmd, LLdebug2);
      while FpcProcess.Running do
      begin
        // stellt sicher, dass wir Platz haben
        M.SetSize(BytesRead + ReadBufferSize);

        // versuche, es zu lesen
        if FpcProcess.Output.NumBytesAvailable > 0 then
        begin
          n := FpcProcess.Output.Read((M.Memory + BytesRead)^, ReadBufferSize);
          //Logdatei.DependentAdd('RunCommandAndCaptureOut: read: ' +
          //  IntToStr(n) + ' bytes', LLdebug2);
          if n > 0 then
          begin
            Inc(BytesRead, n);
            //Logdatei.DependentAdd('RunCommandAndCaptureOut: read: ' +
            // IntToStr(n) + ' bytes', LLdebug2);
            //Write('.')
          end;
        end
        else
        begin
          // keine Daten, warte 100 ms
          //Logdatei.DependentAdd('RunCommandAndCaptureOut: no data - waiting....',
          // LLdebug2);
          Sleep(100);
        end;
      end;
      exitCode := FpcProcess.ExitCode;
      // lese den letzten Teil
      repeat
        // stellt sicher, dass wir Platz haben
        M.SetSize(BytesRead + ReadBufferSize);
        if FpcProcess.Output.NumBytesAvailable > 0 then
        begin
          // versuche es zu lesen
          n := FpcProcess.Output.Read((M.Memory + BytesRead)^, ReadBufferSize);
          if n > 0 then
          begin
            Inc(BytesRead, n);
            //Logdatei.DependentAdd('RunCommandAndCaptureOut: read: ' +
            //IntToStr(n) + ' bytes', LLdebug2);
            //Write('.');
          end;
        end
        else
          n := 0;
      until n <= 0;
      //if BytesRead > 0 then WriteLn;
      M.SetSize(BytesRead);
      //Logdatei.DependentAdd('RunCommandAndCaptureOut: -- executed --', LLdebug2);
      //WriteLn('-- executed --');

      S := TStringList.Create;
      S.LoadFromStream(M);
      //Logdatei.DependentAdd('RunCommandAndCaptureOut: -- linecount = ' +
      //  IntToStr(S.Count), LLdebug2);
      //WriteLn('-- linecount = ', S.Count, ' --');
      for n := 0 to S.Count - 1 do
      begin
        //WriteLn('| ', S[n]);
        outlines.Add(S[n]);
      end;
      //WriteLn('-- end --');
      LogDatei.log('ExitCode ' + IntToStr(exitCode), LLInfo);
    except
      on e: Exception do
      begin
        LogDatei.log('Exception in RunCommandAndCaptureOut: ' +
          e.message, LLError);
        Result := False;
      end;
    end;
  finally
    S.Free;
    FpcProcess.Free;
    M.Free;
  end;
end;


function isMounted(mountpoint : string) : boolean;
var
  output:string;
  exename:string;
  commands:array of string;
begin
  result := false;
  if not RunCommand('/usr/bin/which',['findmnt'],output) then
   writeln('Could not find mount binary')
  else
  begin
    exename := output;
    exename := exename.Replace(#10,'');
    exename := exename.Replace('''','');
  end;
  if RunCommand(exename,[mountpoint],output) then
  begin
    result := true;
  end;
end;

function mountSmbShare(mymountpoint, myshare, mydomain, myuser, mypass, myoption: string) : integer;
var
  cmd, report: string;
  outlines: TStringlist;
  ExitCode: longint;
  i: integer;
begin
  outlines := TStringList.Create;
  Result := -1;
  try
    if not directoryexists(mymountpoint) then
     mkdir(mymountpoint);
  except
    LogDatei.log('Error: could not create moutpoint: '+mymountpoint, LLError);
  end;
  if mydomain = '' then
    cmd := '/bin/bash -c "/sbin/mount.cifs ' + myshare+' '+mymountpoint+' -o '+myoption+'ro,noperm,user='+myuser+',pass='+mypass+'"'
  else
    cmd := '/bin/bash -c "/sbin/mount.cifs ' + myshare+' '+mymountpoint+' -o '+myoption+'ro,noperm,user='+myuser+',dom='+mydomain+',pass='+mypass+'"';
  LogDatei.DependentAdd('calling: '+cmd,LLNotice);
  if not RunCommandAndCaptureOut(cmd, True, outlines, report,
    SW_HIDE, ExitCode) then
  begin
    LogDatei.log('Error: ' + Report + 'Exitcode: ' + IntToStr(ExitCode), LLError);
    Result := -1;
  end
  else
  begin
    LogDatei.LogSIndentLevel := LogDatei.LogSIndentLevel + 6;
    LogDatei.log('', LLDebug);
    LogDatei.log('output:', LLDebug);
    LogDatei.log('--------------', LLDebug);
    for i := 0 to outlines.Count - 1 do
    begin
      LogDatei.log(outlines.strings[i], LLDebug);
    end;
    LogDatei.LogSIndentLevel := LogDatei.LogSIndentLevel - 6;
    LogDatei.log('', LLDebug);
    Result := ExitCode;
  end;
  outlines.Free;
end;

function umount(mymountpoint : string) : integer;
var
  cmd, report: string;
  outlines: TStringlist;
  ExitCode: longint;
  i: integer;
begin
  outlines := TStringList.Create;
  Result := -1;
  cmd := '/bin/bash -c "/bin/umount ' +mymountpoint+'"';
  LogDatei.log('calling: '+cmd,LLNotice);
  if not RunCommandAndCaptureOut(cmd, True, outlines, report,
    SW_HIDE, ExitCode) then
  begin
    LogDatei.log('Error: ' + Report + 'Exitcode: ' + IntToStr(ExitCode), LLError);
    Result := -1;
  end
  else
  begin
    LogDatei.LogSIndentLevel := LogDatei.LogSIndentLevel + 6;
    LogDatei.log('', LLDebug);
    LogDatei.log('output:', LLDebug);
    LogDatei.log('--------------', LLDebug);
    for i := 0 to outlines.Count - 1 do
    begin
      LogDatei.log(outlines.strings[i], LLDebug);
    end;
    LogDatei.LogSIndentLevel := LogDatei.LogSIndentLevel - 6;
    LogDatei.log('', LLDebug);
    Result := ExitCode;
  end;
  outlines.Free;
end;


procedure transformHex(const hexstring : String; var hexarray : bytearray);
var
   section : String;
   thesize : integer;
   onehex : string;
   i: integer;
 begin
   theSize := length (hexstring) div 2;
   section := hexstring;
   for i:=0 to theSize -1 do
   begin
    onehex := copy(section,1,2);
    HexToBin(Pchar(onehex),@hexarray[i],1);
    section := copy(section,3,length(section));
   end;
 end;

function decrypt(hexkey, hexpass : String) : String;
Var
 passByte, keyByte : bytearray;
 passByteDecry : bytearray;
 passSize : Integer;
 keySize : Integer;
 i: integer;
 Cipher: TDCP_blowfish;
begin
 transformHex (hexkey, keyByte);
 transformHex (hexpass, passByte);

 passSize := length (hexpass) div 2;
 keySize := length (hexkey) div 2;

 //DCP_blowfish1.Init(keyByte,keySize*8,PChar('OPSI1234'));
 //DCP_blowfish1.Decrypt(passByte,passByteDecry,passSize);

  Cipher:= TDCP_blowfish.Create(nil);
  Cipher.Init(keyByte,keySize*8,PChar('OPSI1234')); // remember key size is in BITS

  Cipher.DecryptCBC(passByte,passByteDecry,passSize);
  Cipher.Burn;
  Cipher.Free;

 result := '';
 for i :=0 to passSize - 1 do
  result := result + char (passByteDecry [i])
end;


function DecryptBlowfish(const myencrypted,mykey: string): string;
var
Cipher: TDCP_blowfish;
Key: array[0..15] of byte; // key can be any size upto 448bits with blowfish (56bytes)
//Buffer: array[0..127] of byte; // buffer can be any size
s: string;
i : integer;
begin
  //Cipher.Reset;
  //Cipher.DecryptCBC(Buffer,Buffer,Sizeof(Buffer));
  s:= myencrypted;
  for i := 0 to 15 do
  begin
    key[i] := strtoint('$'+mykey[i*2+1]+mykey[i*2+2]);
  end;
  Cipher:= TDCP_blowfish.Create(nil);
  Cipher.Init(Key,Sizeof(Key)*8,nil); // remember key size is in BITS

  Cipher.DecryptCBC(s[1],s[1],Length(s));
  Cipher.Burn;
  Cipher.Free;
  result := s;
end;

function MyOpsiMethodCall(const method: string; parameters: array of string) : string;
var
  omc: TOpsiMethodCall;
  errorOccured: boolean;
  resultstring : string;
begin
  result := '';
  try
    //if param = '' then
      omc := TOpsiMethodCall.Create(method,parameters);
    //else
    //  omc := TOpsiMethodCall.Create(method,[param]);
    resultstring := opsidata.checkAndRetrieve(omc,errorOccured);
    result := resultstring;
  except
    //LogDatei.DependentAdd('Exception calling method: '+method+'  - with param: '+param, LLerror);
    LogDatei.DependentAdd('Exception calling method: '+method+' - wait and retry', LLerror);
    sleep(2000);
    try
      resultstring := opsidata.checkAndRetrieve(omc,errorOccured);
      result := resultstring;
    except
      LogDatei.DependentAdd('Exception calling method: '+method+' - wait and retry', LLerror);
      sleep(2000);
      try
        resultstring := opsidata.checkAndRetrieve(omc,errorOccured);
        result := resultstring;
      except
        LogDatei.DependentAdd('Exception calling method: '+method+' - wait and retry', LLerror);
        sleep(2000);
        try
          resultstring := opsidata.checkAndRetrieve(omc,errorOccured);
          result := resultstring;
        except
          LogDatei.DependentAdd('Exception calling method: '+method+' - wait and retry', LLerror);
          sleep(2000);
          try
            resultstring := opsidata.checkAndRetrieve(omc,errorOccured);
            result := resultstring;
          except
             LogDatei.DependentAdd('Exception calling method: '+method+' - giving up', LLerror);
          end;
        end;
      end;
    end;
  end;
end;


procedure mount_depotshare(mymountpoint : string; myhostkey : string);
var
  resultstring, mydepotuser, myclientId, mydomain, mydepot : string;
  myuser, myencryptedpass, myshare, mypass, mountoption  : string;
  mounttry : integer;
begin
     mydepot := opsidata.depotId;
      //writeln('depotId=',mydepot);
      resultstring := MyOpsiMethodCall('getGeneralConfigValue', ['clientconfig.depot.user',myclientid]);
      mydepotuser := SO(resultstring).S['result'];
      LogDatei.log('Got depot user from service: '+ mydepotuser ,LLNotice);
      if mydepotuser <> '' then
        if divideAtFirst('\',mydepotuser,mydomain,myuser) then ;
      LogDatei.log('Will use as domain: '+ mydomain + ' as user: '+myuser,LLNotice);
      resultstring := MyOpsiMethodCall('user_getCredentials', ['pcpatch',myclientid]);
      myencryptedpass := SO(resultstring).O['result'].S['password'];
      LogDatei.log('Will use as encryptedpass: '+ myencryptedpass + ' clear pass: '+mypass,LLInfo);
      mypass := decrypt(myhostkey,myencryptedpass);
      logdatei.AddToConfidentials(mypass);
      LogDatei.log('Will use as encryptedpass: '+ myencryptedpass + ' clear pass: '+mypass,LLInfo);
      //writeln('mypass=',mypass);
      resultstring := MyOpsiMethodCall('host_getObjects', ['','{"type":"OpsiDepotserver","id":["'+myDepot+'"]}']);
      myshare := SO(resultstring).S['result'];
      myshare := SO(resultstring).O['result'].AsArray.O[0].S['depotRemoteUrl'];
      myshare := copy(myshare,5,length(myshare));
      //writeln('myshare=',myshare);
      umount(mymountpoint);

      mounttry := 0;
      repeat
        if (mounttry div 3) = 0 then mountoption := ' vers=3.0,';
        if (mounttry div 3) = 1 then mountoption := ' vers=2.0,';
        if (mounttry div 6) = 1 then mountoption := ' vers=1.0,';
        if (mounttry div 9) = 1 then mountoption := '';
        errorcode := mountSmbShare(mymountpoint, myshare, mydomain, myuser, mypass,mountoption);
        if (errorcode <> 0) or (not isMounted(mymountpoint)) then
        begin
          inc(mounttry);
          LogDatei.log('Failed to mount '+myshare+' with option: '+mountoption+' to '+mymountpoint+' Error code: '+inttostr(errorcode)+' - retry ...',LLWarning);
          sleep(2000);
        end;
      until isMounted(mymountpoint) or (mounttry > 12);
end;

end.

