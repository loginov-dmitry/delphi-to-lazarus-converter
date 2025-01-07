{
Copyright (c) 2025, Loginov Dmitry Sergeevich
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
}

unit lazconvutils;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

function FastStringReplace(const S: string; OldPattern: string; const NewPattern: string;
  Flags: TReplaceFlags = [rfReplaceAll]): string;

{ Возвращает часть строку по указанному номеру части. Если данной части нет, то вернёт пустую строку
  Нумерация выполняется с единицы}
function GetStringPart(const S: string; PartNum: Integer; Delim: Char = ','): string;

{Загружает текст из файла в string}
function LoadStringFromFile(const FileName: string): string;

{ Сохраняет заданную строку в текстовый файл }
procedure SaveStringToFile(S: string; FileName: string);

implementation

function FastStringReplace(const S: string; OldPattern: string; const NewPattern: string;
  Flags: TReplaceFlags = [rfReplaceAll]): string;
begin
  Result := StringReplace(S, OldPattern, NewPattern, Flags);
end;

function GetStringPart(const S: string; PartNum: Integer; Delim: Char = ','): string;
var
  L: TStringList;
begin
  Result := '';
  L := TStringList.Create;
  try
    L.Text := FastStringReplace(s, Delim, sLineBreak);
    if (PartNum >= 1) and (PartNum <= L.Count) then
      Result := L[PartNum - 1];
  finally
    L.Free;
  end;
end;

function LoadStringFromFile(const FileName: string): string;
var
  ms: TMemoryStream;
begin
  ms := TMemoryStream.Create;
  try
    ms.LoadFromFile(FileName);
    SetString(Result, PChar(ms.Memory), ms.Size);
  finally
    ms.Free;
  end;
end;

procedure SaveStringToFile(S: string; FileName: string);
var
  ms: TMemoryStream;
begin
  ms := TMemoryStream.Create;
  try
    ms.Size := Length(S);
    if ms.Size > 0 then
      //MoveMemory(ms.Memory, PChar(S), Length(S));
      Move(S[1], PChar(ms.Memory)^, Length(S));
    ms.SaveToFile(FileName);
  finally
    ms.Free;
  end;
end;

end.

