unit osregex;   //regular expression unit for opsi-script

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, RegExpr;

function isRegexMatch(inputtext,expr : string) : boolean; //Returns true if regex matches the inputtext.
function getSubListByContainingRegex(expr : string; inputlist : TStringList) : TStringList; //Returns list of matching lines for a single regex.
function getSubListByContainingRegex(exprlist : TStringList; inputlist : TStringList) : TStringList; //Returns list of matching lines for a list of regex.
function getRegexMatchList(expr : string; inputlist : TStringList) : TStringList; //Returns list of exact matches for a single regex.
function getRegexMatchList(exprlist : TStringList; inputlist : TStringList) : TStringList; //Returns list of exact matches for a list of regex.
function removeFromListByContainingRegex(expr : string; inputlist : TStringList) : TStringList; //remove matching lines for a single regex.
function removeFromListByContainingRegex(exprlist : TStringList; inputlist : TStringList) : TStringList; //remove matching lines for a list of regex.
function stringReplaceRegex(inputtext, expr, replacetext : string) : string; //Replace matches in string with replacetext.
function stringReplaceRegexInList(inputlist : TStringList; expr, replacetext : string) : TStringList; //Replace matches in the stringlist with replacetext.


implementation

function isRegexMatch(inputtext,expr : string) : boolean;
//Returns true if regex matches the inputtext.
var
  regexobj : TRegExpr;
begin
  result := false;
  regexobj := TRegExpr.Create;
  try
    regexobj.Expression := expr;
    if regexobj.Exec(inputtext) then
      result := true;
  finally
    regexobj.Free;
  end;
end;

function getSubListByContainingRegex(expr : string; inputlist : TStringList) : TStringList;
//Returns list of matching lines for a single regex.
var
  regexobj : TRegExpr;
  linecounter : integer;
  currentline : string;
begin
  try
    regexobj := TRegExpr.Create;
    regexobj.Expression := expr;

    result := TStringList.Create;
    for linecounter:=0 to inputlist.Count-1  do
    begin
      currentline := trim(inputlist.Strings[linecounter]);
      if regexobj.Exec(currentline) then
        result.Add(currentline);
    end;
  finally
    regexobj.Free;
  end;
end;

function getSubListByContainingRegex(exprlist : TStringList; inputlist : TStringList) : TStringList;
// Returns list of matching lines for a list of regex.
var
  regexobj : TRegExpr;
  linecounter : integer;
  currentline : string;
begin
  try
    result := TStringList.Create;
    regexobj := TRegExpr.Create;

    exprlist. Delimiter:= '|';
    regexobj.Expression := exprlist.DelimitedText;

    for linecounter:=0 to inputlist.Count-1  do
    begin
      currentline := trim(inputlist.Strings[linecounter]);
      if regexobj.Exec(currentline) then
      begin
        result.Add(currentline);
      end;
    end;
  finally
    regexobj.Free;
  end;
end;

function getRegexMatchList(expr : string; inputlist : TStringList) : TStringList;
//Returns list of exact matches for a single regex.
var
  regexobj : TRegExpr;
  linecounter : integer;
  currentline : string;
begin
  try
    regexobj := TRegExpr.Create;
    regexobj.Expression := expr;

    result := TStringList.Create;

    for linecounter:=0 to inputlist.Count-1  do
    begin
      currentline := trim(inputlist.Strings[linecounter]);
      if regexobj.Exec(currentline) then
      begin
        result.Add(regexobj.Match[0]);
        while regexobj.ExecNext do
          result.Add(regexobj.Match[0]);
      end;
    end;
  finally
    regexobj.Free;
  end;
end;

function getRegexMatchList(exprlist : TStringList; inputlist : TStringList) : TStringList;
//Returns list of exact matches for a list of regex.
var
  regexobj : TRegExpr;
  linecounter : integer;
  currentline : string;
begin
  try
    result := TStringList.Create;
    regexobj := TRegExpr.Create;

    exprlist. Delimiter:= '|';
    regexobj.Expression := exprlist.DelimitedText;

    for linecounter:=0 to inputlist.Count-1  do
    begin
      currentline := trim(inputlist.Strings[linecounter]);
      if regexobj.Exec(currentline) then
      begin
        result.Add(regexobj.Match[0]);
        while regexobj.ExecNext do
          result.Add(regexobj.Match[0]);
      end;
    end;
  finally
    regexobj.Free;
  end;
end;

function removeFromListByContainingRegex(expr : string; inputlist : TStringList) : TStringList;
//remove matching lines for a single regex.
var
  regexobj : TRegExpr;
  linecounter : integer;
  currentline : string;
begin
  try
    regexobj := TRegExpr.Create;
    regexobj.Expression := expr;

    result := TStringList.Create;

    for linecounter:=0 to inputlist.Count-1  do
    begin
      currentline := trim(inputlist.Strings[linecounter]);
      if not regexobj.Exec(currentline) then
      begin
        result.Add(currentline);
      end;
    end;
  finally
    regexobj.Free;
  end;
end;

function removeFromListByContainingRegex(exprlist : TStringList; inputlist : TStringList) : TStringList;
//remove matching lines for a list of regex.
var
  regexobj : TRegExpr;
  linecounter : integer;
  currentline : string;
begin
  try
    result := TStringList.Create;
    regexobj := TRegExpr.Create;

    exprlist. Delimiter:= '|';
    regexobj.Expression := exprlist.DelimitedText;

    for linecounter:=0 to inputlist.Count-1  do
    begin
      currentline := trim(inputlist.Strings[linecounter]);
      if not regexobj.Exec(currentline) then
        result.Add(currentline);
    end;
  finally
    regexobj.Free;
  end;
end;

function stringReplaceRegex(inputtext, expr, replacetext : string) : string;
//Replace matches in string with replacetext.
begin
  result:= '';
  inputtext:= ReplaceRegExpr(expr, inputtext, replacetext, True);
  result:= inputtext;
end;

function stringReplaceRegexInList(inputlist : TStringList; expr, replacetext : string) : TStringList;
//Replace matches in the stringlist with replacetext.
var
  linecounter : integer;
  currentline : string;
begin
  result:= TStringList.Create;
  for linecounter:=0 to inputlist.Count-1  do
  begin
    currentline := trim(inputlist.Strings[linecounter]);
    currentline:= ReplaceRegExpr(expr, currentline, replacetext, True);
    result.Add(currentline);
  end;
end;

end.


