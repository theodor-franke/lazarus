unit IconCollector;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF UNIX}
   cthreads,
  {$ENDIF}
  Classes, SysUtils, FileUtil, LazFileUtils, StrUtils, ShellApi, LCLType, Graphics;

type

  TSearchShift = (ssFirst, ssAll);

  TFoundFiles = procedure (FileNames: TStringList) of object;

  { TFindScriptFilesThread }

  TFindScriptFilesThread = class(TThread)
      FFileNames : TStringList;
      FDepotPath : String;
      FCallback : TFoundFiles;
    protected
      procedure Execute; override;
      procedure SendCallBack(FileNames: TStringList);
      procedure DoCallBack;
  public
    constructor Create(DepotPath:String);
  end;


  { TIconCollector }

  TIconCollector = class(TObject)
    private
      FFileNames : TStringList;
      FIconsList  : TStringList;
      FPathToDepot : string;
      FFindScriptFilesThread : TFindScriptFilesThread;
      function ExtractLine(const SearchString:String; PathToScript:String):String;
      procedure ParseLineShowBitmap(Line:String; PathToScript:String);
      function PrepareLine(Line:String):String;
      function IsVariable(Token:String):boolean;
      function ReplaceTokenWithValue(Token:String; PathToScript:String):String;
      procedure SendCallBack(FileNames:TStringList);
      //function ConcatenateTokens
      //function ExtractIcon(OpsiScriptPath:String):String;
      //function ExtractProductID(OpsiScriptPath:String):String;
    public
      procedure ExtractIconFromExe(PathToExe:String);
      function ShowOpsiScriptFilenames:String;
      function ShowIconList:String;
      constructor Create(DepotPath: String);overload;
      destructor Destroy; override;
      procedure GetPathToIcon;
  end;



implementation

{ TFindScriptFilesThread }

procedure TFindScriptFilesThread.Execute;
begin
  //FFileNames := FindAllFiles(FDepotPath,'setup.opsiscript;setup32.opsiscript');
  SendCallBack(FindAllFiles(FDepotPath,'setup.opsiscript;setup32.opsiscript'));
  //Synchronize(@ReturnScriptFiles);
  //Terminate;
  //Synchronize(@ReturnScriptFiles);
end;

procedure TFindScriptFilesThread.SendCallBack(FileNames: TStringList);
begin
  FFileNames := FileNames;
  Synchronize(@DoCallback);
end;

procedure TFindScriptFilesThread.DoCallBack;
begin
  FCallback(FFileNames);
  write('.');
  //FFileNames;
end;

constructor TFindScriptFilesThread.Create(DepotPath: String);
begin
  inherited Create(false);
  FDepotPath := DepotPath;
end;

{ TIconCollector }

function TIconCollector.ExtractLine(const SearchString: String; PathToScript: String): String;
var
  ScriptFile: TextFile;
  Line :string;
begin
  Result := '';
  if FileExists(PathToScript) then
  begin
    try
      AssignFile(ScriptFile,PathToScript);
      Reset(ScriptFile);
      while not EOF(ScriptFile) do
      begin
        ReadLn(ScriptFile, Line);
        if AnsiContainsText(PrepareLine(Line), SearchString) then Break;
      end;
      Result:= Line;
    finally
      CloseFile(ScriptFile);
    end;
  end;
end;

procedure TIconCollector.ParseLineShowBitmap(Line: String; PathToScript:String);
var
  SplittedLine : TStringList;
  i            : integer;
  Concatenate  : boolean;
  IconPath     : String;
  ProductID    : String;
begin
  IconPath := '';
  ProductID := '';
  Line := PrepareLine(Line);//one white space between every token
  Line := Trim(StringReplace(Line,'ShowBitmap','',[rfIgnoreCase]));//remove ShowBitmap
  //PathToScriptFolder := ExtractFilePath(PathToScript);//ExcludeTrailingPathDelimiter
  Line := StringReplace(Line,'%ScriptPath%', ExtractFilePath(PathToScript),[rfIgnoreCase]);//replace %ScriptPath% with path
  SplittedLine := TStringList.Create;
  try
    { Splitt line into tokens }
    SplittedLine.Delimiter := ' ';
    SplittedLine.DelimitedText := Line;
    //SplittedLine := Line.Split(' ');
    //Line := DelChars(Line, '+');
    //Line := ExtractWord(0,Line,[' ']);
    { Parse tokens }
    Concatenate := True;
    for i := 0 to SplittedLine.Count-1 do
    begin
      if IsVariable(SplittedLine[i]) then
      begin
        if (LowerCase(SplittedLine[i]) = LowerCase('$ProductId$'))
          and (ProductID = '') then
        begin
          ProductID := ReplaceTokenWithValue(SplittedLine[i], PathToScript);
          SplittedLine[i] := ProductID;
        end
        else
          SplittedLine[i] := ReplaceTokenWithValue(SplittedLine[i], PathToScript);
      end;
      if Concatenate then IconPath := IconPath + SplittedLine[i];
      if SplittedLine[i] = '+' then Concatenate := True else Concatenate := False;
    end;
    //SplittedLine.Text := TrimFilename(SplittedLine.Text); //for testing/debugging
    //WriteLn(SplittedLine.Text); //for testing/debugging
    IconPath := TrimFilename(IconPath);
    { Copy icon to new destination }
    if CopyFile(IconPath, 'C:\Users\Jan\Test' + PathDelim + ExtractFilename(IconPath))
      and (ProductID <> '') then
    begin
      FIconsList.Add(ProductID + '=' + ExtractFilename(IconPath));
    end;
  finally
    if Assigned(SplittedLine) then
      FreeAndNil(SplittedLine);
  end;
end;

function TIconCollector.PrepareLine(Line: String): String;
begin
  Line := StringReplace(Line,'+',' + ',[rfReplaceAll, rfIgnoreCase]); //if no white spaces are between + and string(variable)
  Line := StringReplace(Line,'=',' = ',[rfReplaceAll, rfIgnoreCase]); //if no white spaces are between = and string(variable)
  Result:= DelSpace1(Trim(Line));//removes all not needed white spaces except of one white space between every token
end;

function TIconCollector.IsVariable(Token: String): boolean;
begin
  if (Token[1] = '$') and  (Token[Token.Length] = '$') then Result := True
  else  Result := False;
  //if Result then WriteLn('Token[1]: ', Token[1], ' Token[Token.Length]: ', Token[Token.Length]); //just for testing
end;

function TIconCollector.ReplaceTokenWithValue(Token: String;
  PathToScript: String):String;
var
  Line : String;
begin
  Line := ExtractLine('Set ' + Token + ' = ', PathToScript);
  Line := PrepareLine(Line);
  Result := Trim(StringReplace(Line,'Set ' + Token + ' = ','',[rfIgnoreCase])).DeQuotedString('"');
end;

procedure TIconCollector.SendCallback(FileNames: TStringList);
begin
  FFileNames := FileNames;
end;

function TIconCollector.ShowOpsiScriptFilenames:String;
begin
  Result := FFileNames.Text;
end;

function TIconCollector.ShowIconList:String;
begin
  Result := FIconsList.Text;
end;

constructor TIconCollector.Create(DepotPath: String);
begin
  inherited Create;
  FPathToDepot := DepotPath;
  FIconsList := TStringList.Create;
  FFindScriptFilesThread := TFindScriptFilesThread.Create(FPathToDepot);
  //while not FindScriptFilesThread.Terminated do begin
    //write('.');
  //end;
  //FoundFiles(FFileNames);
  //FFindScriptFilesThread.Terminate;
  FFindScriptFilesThread.Free;

  //FFileNames := FindAllFiles(DepotPath,'setup.opsiscript;setup32.opsiscript');
end;

destructor TIconCollector.Destroy;
begin
  inherited Destroy;
  FIconsList.SaveToFile('C:\Users\Jan\Test\IconsList.txt');
  FFileNames.Free;
  FIconsList.Free;
end;

procedure TIconCollector.GetPathToIcon;
var
  i : integer;
  Line : String;
begin
  for i := 0 to FFileNames.Count-1 do
  begin
    Line := ExtractLine('ShowBitmap', FFileNames[i]);
    ParseLineShowBitmap(Line,FFileNames[i]);
  end;
end;

{Procedure is just a test not shure if useful in this application}
procedure TIconCollector.ExtractIconFromExe(PathToExe: String);
var
  IconLarge :HICON;
  IconSmall :HICON;
  Picture : TPicture;
begin
  if ExtractIconEx(PChar(PathToExe),0,IconLarge,IconSmall,1) > NULL then
  begin
    Picture := TPicture.Create;
    try
      Picture.Icon.Handle := IconLarge;
      Picture.SaveToFile('C:\Users\Jan\Test\anydesk\TestIcon_1.ico');
     finally
      Picture.Free;
    end;
   end;
end;

end.

