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

{
SmartHolder - https://github.com/loginov-dmitry/loginovprojects/tree/master/smartholder
}

unit LazConvMainFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, EditBtn,
  FileCtrl, IniPropStorage, ExtCtrls, Buttons, FileUtil, Math,
  widestrutils, LConvEncoding, StrUtils, lazconvmsgfrm, lazconvutils, SmartHolder;

type

  { TDFMObjProcessState }

  TDFMObjProcessState = class
    ObjName: string;
    ObjClass: string;
    NeedDelAllContent: Boolean;
    NeedDelThisObj: Boolean;
    BegLineIdx, EndLineIdx: Integer;
  public
    constructor Create(AObjName, AObjClass: string; ANeedDelAllContent, ANeedDelThisObj: Boolean);
  end;

  { TLazConvMainForm }

  TLazConvMainForm = class(TForm)
    btnProcess: TButton;
    btnConvertDFMBlock: TButton;
    DirectoryEdit1: TDirectoryEdit;
    FileListBox1: TFileListBox;
    IniPropStorage1: TIniPropStorage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    labFileName: TLabel;
    memInfo: TMemo;
    memErrors: TMemo;

    procedure btnConvertDFMBlockClick(Sender: TObject);
    procedure btnProcessClick(Sender: TObject);
    procedure DirectoryEdit1Change(Sender: TObject);
    procedure FileListBox1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    LReplClass: TStringList;
    LDelProps: TStringList;
    LReplProps: TStringList;
    LReplUnits: TStringList;
    LUnitsForTypes: TStringList;
    DFMText: string;
    procedure ProcessDFM(DFMFile: string; ADFMText: string);
    procedure ProcessPAS(PASFile: string);
    function ProcessUsesSection(var sContent: string; IsTopUses: Boolean): Boolean;
    procedure Log(s: string);
    procedure LogError(s: string);

    // Перечислены названия классов для замены
    // Укажите необходимые заменямые классы вручную. Список заменяемых классов встроенного конвертера
    // перечислен в модуле ConvertSettings.pas проекта lazarus.lpi
    procedure FillReplClassList;

    // Перечислены названия свойств для удаления
    procedure FillDelPropsList;

    // Перечислены названия свойств для замены
    procedure FillReplPropsList;

    // Перечислены названия модулей (для замены модулей в USES)
    // Укажите необходимые модули вручную. Список заменяемых модулей встроенного конвертера
    // перечислен в модуле ConvertSettings.pas проекта lazarus.lpi
    procedure FillReplUnitsList;

    // Перечислены названия модулей для некоторых классов компонентов
    procedure FillUnitsForTypes;

    function NeedDelProp(sPropName: string; sClassName: string): Boolean;
    function NeedReplProp(sPropName: string; sClassName: string; out NewPropName: string): Boolean;
  public

  end;

var
  LazConvMainForm: TLazConvMainForm;
  strLineBreak: string = #13#10; // Перевод строки в паскале обычно #13#10
                                 // Возможно, есть смысл реализовать автодетектирование

implementation

{$R *.lfm}

{ TDFMObjProcessState }

constructor TDFMObjProcessState.Create(AObjName, AObjClass: string;
  ANeedDelAllContent, ANeedDelThisObj: Boolean);
begin
  ObjName:=AObjName;
  ObjClass:=AObjClass;
  NeedDelAllContent:=ANeedDelAllContent;
end;

{ TLazConvMainForm }

procedure TLazConvMainForm.DirectoryEdit1Change(Sender: TObject);
begin
  FileListBox1.Directory:=DirectoryEdit1.Directory;
end;

procedure TLazConvMainForm.FileListBox1Change(Sender: TObject);
begin
    labFileName.Caption:=FileListBox1.FileName;
end;

procedure TLazConvMainForm.FormCreate(Sender: TObject);
begin
  LReplClass := TStringList.Create();
  LDelProps  := TStringList.Create();
  LReplProps := TStringList.Create();
  LReplUnits := TStringList.Create();
  LUnitsForTypes := TStringList.Create();

  FillDelPropsList;
  FillReplClassList;
  FillReplPropsList;
  FillReplUnitsList;
  FillUnitsForTypes;
end;

procedure TLazConvMainForm.FormDestroy(Sender: TObject);
begin
  LReplClass.Free;
  LDelProps.Free;
  LReplProps.Free;
  LReplUnits.Free;
  LUnitsForTypes.Free;
end;

procedure TLazConvMainForm.ProcessDFM(DFMFile: string; ADFMText: string);
var
  LFMFile, s, sTmp, sPropVal, sNewPropVal, sTrim, sTmpLower, sPropName, sNewPropName: string;
  L, ObjLevels: TStringList;
  h: TSmartHolder;
  I, J: Integer;
  NeedBreak: Boolean;
  CurObjName, CurClassName, sNewClassName, CurDelProp: string;
  CurObjBegIdx, Idx, APos: Integer;
  CurObj: TDFMObjProcessState;
  NeedDelContent, NeedDelThisObj: Boolean;
  IsCollection, InDelPropState, NeedRoundPropValue: Boolean;
begin
  if ADFMText <> '' then
    Log('Начало обработки блока: ' + ADFMText)
  else
    Log('Начало обработки файла: ' + DFMFile);

  L := h.CreateStringList();

  if ADFMText <> '' then
  begin
    L.Text := ADFMText;
  end else
  begin
    LFMFile := FastStringReplace(DFMFile, '.dfm', '.lfm', [rfIgnoreCase]);
    if FileExists(LFMFile) then
    begin
      Log('Файл уже существует: ' + LFMFile);
      Exit;
    end;
    L.LoadFromFile(DFMFile);
  end;

  ObjLevels := h.CreateStringList();
  CurObj := nil;
  CurObjName := '';
  CurClassName := '';
  CurObjBegIdx := -1;
  IsCollection := False;
  // Перебираем все строки в DFM с самого начала
  for I := 0 to L.Count - 1 do
  begin
    s := L[I];
    sTrim := Trim(s);
    if (Pos('inherited ', sTrim) = 1) or (Pos('object ', sTrim) = 1) or (Pos('inline ', sTrim) = 1) then
    begin // Начало описание объекта                  // inherited MainPanel: TPanel //object Label1: TLabel
      s := FastStringReplace(s, 'object ', '');       //inline DefGSMFrame: TDefGSMFrame
      s := FastStringReplace(s, 'inherited ', '');
      s := FastStringReplace(s, 'inline ', '');
      s := Trim(s); //Label1: TLabel [0]
      s := FastStringReplace(s, ' ', '');  // Label1:TLabel[0]
      CurObjName := GetStringPart(s, 1, ':');   // Label1
      CurClassName := GetStringPart(s, 2, ':'); // TLabel либо TLabel[0]
      if Pos('[', CurClassName) > 0 then
        CurClassName := GetStringPart(CurClassName, 1, '['); // TLabel[0] -> TLabel

      sNewClassName := LReplClass.Values[CurClassName]; //TImageList:delprops
      NeedDelContent := False;
      if Pos(':', sNewClassName) > 0 then
      begin
        NeedDelContent := Pos(':delprops', sNewClassName) > 0;
        sNewClassName := GetStringPart(sNewClassName, 1, ':');          // TImageList:delprops  -> TImageList
      end;
      NeedDelThisObj := False;
      if Assigned(CurObj) then // Если есть родительский объект
        NeedDelThisObj := CurObj.NeedDelAllContent or CurObj.NeedDelThisObj;

      CurObj := TDFMObjProcessState.Create(CurObjName, CurClassName, NeedDelContent, NeedDelThisObj);
      CurObj.BegLineIdx:=I;
      ObjLevels.AddObject(Format('%s=%s', [CurObjName, CurClassName]), CurObj);

      //Log(Format('%s BEGIN %s:%s', [StrLPad(' ', ObjLevels.Count * 4, ' '), CurObjName, CurClassName]));

      if sNewClassName <> '' then
      begin
        L[I] := FastStringReplace(L[I], CurClassName, sNewClassName, [rfReplaceAll]); // TJvSpinEdit -> TSpinEdit
        Log(Format('Замена класса для %s: %s -> %s', [CurObjName, CurClassName, sNewClassName]));
      end;

      if InDelPropState then
      begin
        InDelPropState := False;
        CurDelProp := '';
      end;

    end else if (not IsCollection) and (LowerCase(Trim(s)) = 'end') then
    begin // Окончание описания объекта

      if CurObj = nil then
        raise Exception.CreateFmt('CurObj=nil (LineIdx=%d: "%s")', [I, s]);
      CurObj.EndLineIdx:=I;

      //Log(Format('%s END %s:%s', [StrLPad(' ', ObjLevels.Count * 4, ' '), CurObjName, CurClassName]));

      if CurObj.NeedDelThisObj then
      begin
        for J := CurObj.BegLineIdx to CurObj.EndLineIdx do
          L[J] := '';
        Log(Format('Удаление объекта %s: %s', [CurObjName, CurClassName]));
      end else if CurObj.NeedDelAllContent then
      begin
        for J := CurObj.BegLineIdx + 1 to CurObj.EndLineIdx - 1 do
        begin
          sTmp := ' ' + LowerCase(Trim(FastStringReplace(L[J], ' ', '')));
          if (Pos(' left=', sTmp) = 0) and (Pos(' top=', sTmp) = 0) then // Свойства Left и Top - оставляем
          begin
            Log(CurObjName + ': удалено свойство [ALL]: ' + L[J]);
            L[J] := '';
          end;
        end;
      end;
      CurObj.Free;
      CurObj := nil;

      if ObjLevels.Count = 0 then
        raise Exception.Create('ObjLevels.Count = 0');
      ObjLevels.Delete(ObjLevels.Count - 1);

      // Переходим к родительскому объекту
      Idx := ObjLevels.Count - 1;
      if Idx >= 0 then
      begin
        CurObjName := ObjLevels.Names[Idx];
        CurClassName := ObjLevels.ValueFromIndex[Idx];
        CurObj := ObjLevels.Objects[Idx] as TDFMObjProcessState;
      end;

      if InDelPropState then
      begin
        InDelPropState := False;
        CurDelProp := '';
      end;
    end else
    begin
      // Внутренности объекта
      sTmp := Trim(FastStringReplace(s, ' ', ''));
      sTmpLower:= LowerCase(sTmp);
      if not IsCollection then
      begin
        IsCollection := Pos('=<', sTmpLower) > 0;
      end else // Если находимся внутри коллекции
      begin
        if sTmpLower = 'end>' then
          IsCollection := False;
      end;

      if Assigned(CurObj) then
        if not CurObj.NeedDelAllContent then
        begin // Выполняем замену или удаление некоторых свойств
          if (Pos(' = ', s) > 1) then
          begin
            if InDelPropState then
            begin
              InDelPropState := False;
              CurDelProp := '';
            end;
            sPropName := GetStringPart(sTmp, 1, '=');
            if NeedDelProp(sPropName, CurClassName) then
            begin
              Log(CurObjName + ': удалено свойство: ' + L[I]);
              CurDelProp := sPropName;
              L[I] := '';
              InDelPropState := True;
            end else if NeedReplProp(sPropName, CurClassName, sNewPropName) then
            begin
              L[I] := FastStringReplace(L[I], sPropName, sNewPropName);
              Log(CurObjName + Format(': заменено свойство: %s -> %s', [sPropName, sNewPropName]));
            end;
            if Pos('GeneratorField.ApplyEvent = gamOnPost', L[I]) > 0 then
              L[I] := FastStringReplace(L[I], 'GeneratorField.ApplyEvent = gamOnPost', 'GeneratorField.ApplyOnEvent = gaeOnPostRecord');

            NeedRoundPropValue := ((sNewClassName = 'TSpinEdit') and ((sPropName = 'MaxValue') or (sPropName = 'Value'))) or
                                  ((CurClassName = 'TDateTimePicker') and (sPropName = 'Date'));

            if NeedRoundPropValue then
            begin
              //MaxValue = 65535.000000000
              sPropVal := Trim(GetStringPart(L[I], 2, '='));
              APos := Pos('.', sPropVal);
              if APos > 1 then
              begin
                sNewPropVal := Copy(sPropVal, 1, APos-1); //12.23 -> 12
                L[I] := FastStringReplace(L[I], sPropVal, sNewPropVal);
                Log(CurObjName + Format(': заменено значение свойства "%s": %s -> %s', [sPropName, sPropVal, sNewPropVal]));
              end;
            end;
{
// TDateTimePicker.Time - дробное
}
          end else
          begin
            if InDelPropState then
            begin
              Log(CurObjName + ': удалено свойство: ' + L[I] + '. Строка: ' + I.ToString);
              L[I] := '';
            end;
          end;

        end;
    end;


  end; // for L

  for I := L.Count - 1 downto 0 do
    if L[I] = '' then
      L.Delete(I);

  if ADFMText <> '' then
  begin
    Log('Обработка DFMText завершена');
    TMessageForm.ShowMessage(Self, L.Text);
  end else
  begin
    L.SaveToFile(LFMFile);

    Log(Format('Обработка завершена: %s -> %s', [DFMFile, LFMFile]));
  end;

end;

procedure TLazConvMainForm.ProcessPAS(PASFile: string);
var
  sContent, sContentUpper, s: string;
  sOldClass, sNewClass, sBackup: string;
  HasBom: Boolean;
  ExistsTagCodePage, ExistsTagLongStr, ExistsTagModeDelphi: Boolean;
  EncodedOk: Boolean;
  I: Integer;

  procedure ReplaceClassName(var sContent: string; const Prefix, Suffix, sOldClass, sNewClass: string);
  var
    s: string;
  begin
    if Pos(Prefix + sOldClass + Suffix, sContent) > 0 then
    begin
      s := Format(Prefix + '{$IFnDEF FPC}%s{$ELSE}%s{$ENDIF}' + Suffix, [sOldClass, sNewClass]);
      sContent := FastStringReplace(sContent, Prefix + sOldClass + Suffix, s);
      Log('Замена класса: ' + s);
    end;
  end;
begin
  Log('Начало обработки: ' + PASFile);

  sContent:=LoadStringFromFile(PASFile);
  HasBom:= HasUTF8BOM(sContent);
  if HasBom then
    sContent := Copy(sContent, 4, MaxInt); // Избавляемся от символов BOM в начале файла

  if not HasBom then
    if not IsUTF8String(sContent) then
    begin
      sContent := ConvertEncodingToUTF8(sContent, EncodingCP1251, EncodedOk);
      if EncodedOk then
        Log('Выполнена перекодировка текста в UTF8')
      else
        Log('Не удалось перекодировать текст в UTF8')
    end;

  sContentUpper := UpperCase(sContent);

  ExistsTagCodePage   := Pos('{$CODEPAGE UTF8}', sContentUpper) > 0;
  ExistsTagLongStr    := Pos('{$H+}', sContentUpper) > 0;
  ExistsTagModeDelphi := Pos('{$MODE DELPHI}', sContentUpper) > 0;

  if not (ExistsTagCodePage or ExistsTagLongStr or ExistsTagModeDelphi) then
  begin
    s := '';
    if not ExistsTagCodePage then
      s := s + '{$CODEPAGE UTF8}';
    if not ExistsTagLongStr then
      s := s + '{$H+}';
    if not ExistsTagModeDelphi then
      s := s + '{$MODE DELPHI}';
    s := '{$IFDEF FPC}' + s + '{$ENDIF}';
    sContent := s + strLineBreak + sContent;
    Log('Добавлена директива: ' + s);

  end;

  if not ProcessUsesSection(sContent, True) then Exit;
  if not ProcessUsesSection(sContent, False) then Exit;

  // Заменяем классы компонентов
  for I := 0 to LReplClass.Count - 1 do
  begin
    sOldClass := LReplClass.Names[I];
    sNewClass := LReplClass.ValueFromIndex[I];
    if Pos(':', sNewClass) > 0 then
      sNewClass := GetStringPart(sNewClass, 1, ':');          // TImageList:delprops  -> TImageList
    ReplaceClassName(sContent, ':', ';', sOldClass, sNewClass);
    ReplaceClassName(sContent, ' ', ';', sOldClass, sNewClass);
    ReplaceClassName(sContent, ':', ')', sOldClass, sNewClass);
    ReplaceClassName(sContent, ' ', ')', sOldClass, sNewClass);
  end;

  // Заменяем строку включения ресурса
  if Pos('{$R *.dfm}', sContent) > 0 then
    if Pos('{$R *.lfm}', sContent) = 0 then
    begin
      s := '{$IFnDEF FPC}' + strLineBreak +
           '  {$R *.dfm}' + strLineBreak +
           '{$ELSE}' +strLineBreak+
           '  {$R *.lfm}' +strLineBreak+
           '{$ENDIF}';
      if Pos('  {$R *.dfm}', sContent) > 0 then
        sContent := FastStringReplace(sContent, '  {$R *.dfm}', s)
      else
        sContent := FastStringReplace(sContent, '{$R *.dfm}', s);
      Log('Добавлено: {$R *.lfm}');
    end;

  // Добавьте (для Линукса) функции CoInitialize и CoUnInitialize (без реализации) в отдельный модуль
  // и укажите его в Uses. Лишние директивы условной компиляции могут ухудшить качество кода
  //if Pos('CoInitialize(nil);', sContent) > 0 then
  //  if Pos('}CoInitialize(nil);', sContent) = 0 then
  //  begin
  //    sContent := FastStringReplace(sContent, 'CoInitialize(nil);', '{$IFnDEF FPC}CoInitialize(nil);{$ENDIF}');
  //    Log('Изменено: ' + '{$IFnDEF FPC}CoInitialize(nil);{$ENDIF}');
  //  end;

  //if Pos('CoUnInitialize();', sContent) > 0 then
  //  if Pos('}CoUnInitialize();', sContent) = 0 then
  //  begin
  //    sContent := FastStringReplace(sContent, 'CoUnInitialize();', '{$IFnDEF FPC}CoUnInitialize();{$ENDIF}');
  //    Log('Изменено: ' + '{$IFnDEF FPC}CoUnInitialize();{$ENDIF}');
  //  end;

  Insert('   ', sContent, 1);
  for I := 1 to 3 do
    sContent[I] := sUTF8BOMString[I];

  sBackup := PASFile + FormatDateTime('_yymmdd_hhnnss', Now) + '.pas';

  if not CopyFile(PASFile, sBackup) then
     RaiseLastOSError;

  Log('Создан файл бэкапа: ' + sBackup);

  SaveStringToFile(sContent, PASFile);

  Log('Обработка завершена: ' + PASFile);
end;

function TLazConvMainForm.ProcessUsesSection(var sContent: string;
  IsTopUses: Boolean): Boolean;
var
  IsLastUnit, CanProcessUsesBlock: Boolean;
  PosUses, PosEndUses, PosStart: Integer;
  sUses, sUsesOrig, sUpper, sTmp, sLine, sContentUpper, s, sSectionName: string;
  LUnits, LUnitsCommon, LUnitsForFPC, LUnitsOrig, LUnitsNew, LRepl, LUntsForTypes, LUnitsForDelphi: TStringList;
  h: TSmartHolder;
  I, J: Integer;
  NeedMessagesUnitForWindows: Boolean;
  PosImplem, PosInterface: Integer;
  UnitOnlyForDelphi: Boolean;
begin
  Result := True;
  CanProcessUsesBlock := True;
  sContentUpper := UpperCase(sContent);
  sSectionName := IfThen(IsTopUses, 'interface', 'implementation');

  PosInterface := Pos(strLineBreak + 'INTERFACE' + strLineBreak, sContentUpper);
  if PosInterface = 0 then
  begin
    LogError('Прервано! Не обнаружено обязательное ключевое слово "interface"');
    Exit(False);
  end;

  PosImplem := Pos(strLineBreak + 'IMPLEMENTATION' + strLineBreak, sContentUpper);
  if PosImplem = 0 then
  begin
    LogError('Прервано! Не обнаружено обязательное ключевое слово "implementation"');
    Exit(False);
  end;

  NeedMessagesUnitForWindows := IsTopUses and ((Pos(UpperCase('PostMessage'), sContentUpper) > 0) or (Pos(UpperCase('SendMessage'), sContentUpper) > 0) or (Pos('WM_', sContentUpper) > 0));

  PosStart := Math.IfThen(IsTopUses, PosInterface, PosImplem);

  PosUses := PosEx('USES' + strLineBreak, sContentUpper, PosStart);
  if PosUses = 0 then
    PosUses := Pos('USES ', sContentUpper, PosStart);
  if PosUses = 0 then
  begin
    LogError('Не удалось найти ключевое слово USES!');
    Exit;
  end;
  PosEndUses := PosEx(';', sContentUpper, PosUses);
  if PosEndUses <= PosUses then
  begin
    LogError('Прервано! Не удалось найти ";" в конце USES. Вероятно файл повреждён!');
    Exit(False);
  end;

  if IsTopUses and (PosUses > PosImplem) then
  begin
    Log('Не найдено ключевое слово USES в секции "interface", но оно есть в секции "implementation"!');
    CanProcessUsesBlock := False;
  end;

  sUses := Trim(Copy(sContent, PosUses, PosEndUses - PosUses)); // Копируем модули (кроме ";")
  sUsesOrig := sUses;
  sUpper := UpperCase(sUses);

  {$REGION 'Отказываемся обрабатывать секцию USES, если в ней обнаружены комментарии либо директивы'}
  // Отказываемся обрабатывать секцию USES, если в ней обнаружены комментарии либо директивы
  // условной компиляции.
  // Утилита не использует инструменты CodeTools для парсинга исходников, поэтому
  // требует, чтобы разработчик предоставил модуль с "очищенной" секцией USES.
  if (Pos('{$IFDEF', sUpper) > 0) or (Pos('{$IFNDEF', sUpper) > 0) then
  begin
    LogError('В USES обнаружена опция $IFDEF. Обработка USES выполнена не будет!');
    CanProcessUsesBlock := False;
  end;

  if (Pos('{', sUpper) > 0) or (Pos('//', sUpper) > 0) then
  begin
    LogError('В USES обнаружен комментарий. Обработка USES выполнена не будет!');
    CanProcessUsesBlock := False;
  end;
  {$ENDREGION}

  if CanProcessUsesBlock then
  begin
    sUses := FastStringReplace(sUses, strLineBreak, ' ');
    while Pos('  ', sUses) > 0 do
      sUses := FastStringReplace(sUses, '  ', ' ');
    sUses := FastStringReplace(sUses, ' ,', ',');
    sUses := FastStringReplace(sUses, ', ', ',');
    sUses := FastStringReplace(sUses, ',,', ',');
    sUses := FastStringReplace(sUses, strLineBreak, ',');
    // Убираем слово USES
    sUses := FastStringReplace(sUses, 'uses ', '');

    LUnits := h.CreateStringListWithText(sUses, ',');
    LUnitsOrig := h.CreateStringListWithText(sUses, ',');
    LUnitsNew := h.CreateStringList();
    LUnitsCommon := h.CreateStringList(); // Все модули для FPC (могут быть общие для FPC и для Delphi)
    LUntsForTypes := h.CreateStringList();
    LUnitsForDelphi := h.CreateStringList(); // Модули только для Delphi
    LUnitsForFPC := h.CreateStringList(); // Модули только для FPC

    for I := LUnits.Count - 1 downto 0 do
      if LReplUnits.Values[LUnits[I]] <> '' then // Если модуль находится в списке на замену
        LUnits.Delete(I); // Удаляем этот модуль из LReplUnits

    // Удаляем модули Windows, Messages, если их необходимо объявить вверху
    if NeedMessagesUnitForWindows then
      for I := LUnits.Count - 1 downto 0 do
      begin
        if SameText(LUnits[I], 'Windows') or SameText(LUnits[I], 'Messages') then
          LUnits.Delete(I);
      end;

    LUnitsCommon.Assign(LUnits);

    if IsTopUses then
    begin
      for I := 0 to LUnitsForTypes.Count - 1 do
      begin
        s := UpperCase(LUnitsForTypes.Names[I]);
        // Если в исходном коде обнаружено упоминание типа, за которым следует разделитель...
        if (Pos(s + ';', sContentUpper) > 0) or     // dt: TDateTimePicker;
           (Pos(s + '.', sContentUpper) > 0) or     // dt := TDateTimePicker.Create;
           (Pos(s + '{', sContentUpper) > 0) or     // dt: {$IFDEF...}TDateTimePicker{$ELSE}...;
           (Pos(s + ' ', sContentUpper) > 0) or     // dt := TDateTimePicker ;
           (Pos(s + '(', sContentUpper) > 0) then   // dt := TDateTimePicker( ;
        begin
          sTmp := LUnitsForTypes.ValueFromIndex[I];
          LRepl := h.CreateStringListWithText(sTmp, ',');
          for J := 0 to LRepl.Count - 1 do
            if (LUnitsCommon.IndexOf(LRepl[J]) = -1) and (LUntsForTypes.IndexOf(LRepl[J]) = -1) then
              LUntsForTypes.Add(LRepl[J]);
        end;
      end;
    end;

    if (LUnits.Count <> LUnitsOrig.Count) or (LUntsForTypes.Count > 0) or NeedMessagesUnitForWindows then
    begin
      if NeedMessagesUnitForWindows then
        LUnitsNew.Add('#WIN_MESSAGES#');

      // Готовим список модулей для Delphi
      for I := 0 to LUnitsOrig.Count - 1 do
      begin
        s := LUnitsOrig[I];
        UnitOnlyForDelphi := LUnits.IndexOf(s) = -1;
        if UnitOnlyForDelphi then
        begin
          if NeedMessagesUnitForWindows and (SameText(s, 'Windows') or SameText(s, 'Messages')) then
            s := '';

          if s <> '' then
            LUnitsForDelphi.Add(s);
        end;
      end;

      // Готовим список модулей для FPC
      for I := 0 to LUnitsOrig.Count - 1 do
      begin
        sTmp := LReplUnits.Values[LUnitsOrig[I]];
        if sTmp = 'del' then
          sTmp := '';

        if sTmp <> '' then
        begin
          LRepl := h.CreateStringListWithText(sTmp, ',');
          for J := 0 to LRepl.Count - 1 do
            if (LUnitsCommon.IndexOf(LRepl[J]) = -1) then
            begin
              LUnitsForFPC.Add(LRepl[J]);
              LUnitsCommon.Add(LRepl[J]);
            end;
        end;
      end;

      // Добавляем в список модулей для FPC модули найденных типов компонентов
      if IsTopUses then
      begin
        for I := 0 to LUntsForTypes.Count - 1 do
        begin
          s := LUntsForTypes[I];
          if (LUnitsCommon.IndexOf(s) = -1) then
          begin
            LUnitsForFPC.Add(LUntsForTypes[J]);
            LUnitsCommon.Add(LUntsForTypes[J]);
          end;
        end;
      end;

      if LUnitsForDelphi.Count > 0 then
      begin
        LUnitsNew.Add('{$IFnDEF FPC}');
        for I := 0 to LUnitsForDelphi.Count - 1 do
          LUnitsNew.Add(LUnitsForDelphi[I]);

        if LUnitsForFPC.Count > 0 then
          LUnitsNew.Add('{$ELSE}')
        else
          LUnitsNew.Add('{$ENDIF FPC}');
      end;

      if LUnitsForFPC.Count > 0 then
      begin
        if LUnitsForDelphi.Count = 0 then
          LUnitsNew.Add('{$IFDEF FPC}');

        for I := 0 to LUnitsForFPC.Count - 1 do
          LUnitsNew.Add(LUnitsForFPC[I]);

        LUnitsNew.Add('{$ENDIF FPC}');
      end;

      // Добавляем общие модули:
      for I := 0 to LUnits.Count - 1 do
        if LUnitsNew.IndexOf(LUnits[I]) = -1 then
          LUnitsNew.Add(LUnits[I]);

      // Формируем строку USES
      sUses := 'uses' + strLineBreak;
      sLine := '';
      for I := 0 to LUnitsNew.Count - 1 do
      begin
        IsLastUnit := I = LUnitsNew.Count - 1;
        s := LUnitsNew[I];

        if s = '#WIN_MESSAGES#' then
          s := '{$IFDEF MSWINDOWS}Windows, Messages,{$ENDIF}';

        if (sLine <> '') and (s[1] = '{') then
        begin
          sUses := sUses + sLine + strLineBreak;
          sLine := '';
        end;

        if sLine = '' then
        begin
          sLine := sLine + '  ';
          if s[1] <> '{' then
            sLine := sLine + '  ';
        end;

        sLine := sLine + s;
        if (s[1] <> '{') and (s[1] <> '#') and (not IsLastUnit) then
          sLine := sLine + ', ';
        if (Length(sLine) > 90) or (sLine[Length(sLine)] = '}') then
        begin
          sUses := sUses + sLine;
          sLine := '';
          if not IsLastUnit then
            sUses := sUses + strLineBreak;
        end;
        if IsLastUnit and (sLine <> '') then
          sUses := sUses + sLine;
      end;

      // Вырезаем старый блок USES
      Delete(sContent, PosUses, PosEndUses - PosUses);

      // Вставляем новый блок USES
      Insert(sUses, sContent, PosUses);

      Log('Обработан блок uses в секции "'+sSectionName+'". Старый блок:');
      Log(sUsesOrig);
      Log('Новый блок:');
      Log(sUses);
    end;
  end;
end;

procedure TLazConvMainForm.Log(s: string);
begin
  memInfo.Append(s);
end;

procedure TLazConvMainForm.LogError(s: string);
begin
  memErrors.Append(s);
end;

procedure TLazConvMainForm.FillReplClassList;
begin
  LReplClass.Add('TJvSpinEdit=TSpinEdit');
  //LReplClass.Add('TRxSpinEdit=TSpinEdit'); // Не требуется, т.к. для лазаруса есть TRxSpinEdit в пакете RxNew
  LReplClass.Add('TJvDirectoryEdit=TDirectoryEdit');
  LReplClass.Add('IXMLDocument=TXMLDocument');
  LReplClass.Add('IXMLNode=TDOMNode');
  LReplClass.Add('TMessage=TLMessage');
  LReplClass.Add('TJvMemoryData=TRxMemoryData');
  LReplClass.Add('TPngBitBtn=TBitBtn');
  LReplClass.Add('TPngImage=TImage'); // либо Graphics.TPortableNetworkGraphic
  LReplClass.Add('TPngSpeedButton=TSpeedButton');
  LReplClass.Add('TFormStorage=TIniPropStorage:delprops');
  LReplClass.Add('TFormPlacement=TIniPropStorage:delprops');
  LReplClass.Add('TRichEdit=TMemo');
  LReplClass.Add('TPngImageCollection=TImageList:delprops'); //delprops - удалить все св-ва (кроме Left и Top)
  LReplClass.Add('TPngImageList=TImageList:delprops');
  LReplClass.Add('TApplicationEvents=TApplicationProperties');
  LReplClass.Add('TPointSeries=TLineSeries'); // Дополнительно потребуется отключить св-во ShowLines, включить ShowPoints, Pointer


  //TSpinEdit.MaxValue - нужно скорректировать на целое
  // TDateTimePicker.Date - целое
  // TDateTimePicker.Time - дробное
end;

procedure TLazConvMainForm.FillDelPropsList;
begin
  //LDelProps.Add('*.PngImage');  // Закомметировано, т.к. свойство - сложное
  LDelProps.Add('*.Margins');
  LDelProps.Add('*.ExplicitWidth');
  LDelProps.Add('*.ExplicitHeight');
  LDelProps.Add('*.ExplicitLeft');
  LDelProps.Add('*.ExplicitTop');
  LDelProps.Add('*.TextHeight');
  LDelProps.Add('*.AlignWithMargins');
  LDelProps.Add('*.OldCreateOrder');
  LDelProps.Add('*.PngImage');
  LDelProps.Add('*.DesignSize');
  //LDelProps.Add('*.Padding'); // Замена на BorderSpacing
  LDelProps.Add('TJvDirectoryEdit.DialogKind');
  LDelProps.Add('TDirectoryEdit.DialogKind');
  LDelProps.Add('TButton.WordWrap');
  LDelProps.Add('TPanel.BevelEdges');
  LDelProps.Add('TCheckBox.WordWrap');
  LDelProps.Add('TIBStringField.FixedChar');
  LDelProps.Add('TDateTimePicker.Format');
  LDelProps.Add('TPanel.BevelKind');
  LDelProps.Add('TRxSpinEdit.DisplayFormat');
  LDelProps.Add('TFormPlacement.OnSavePlacement');
  LDelProps.Add('TFormPlacement.OnRestorePlacement');
  LDelProps.Add('TTabSheet.Constraints');
  LDelProps.Add('TRadioButton.WordWrap');
  LDelProps.Add('TScrollBox.BevelInner');
  LDelProps.Add('TScrollBox.BevelOuter');
  LDelProps.Add('TStringGrid.BevelInner');
  LDelProps.Add('TStringGrid.BevelKind');
  LDelProps.Add('TStringGrid.BevelOuter');
  LDelProps.Add('TTreeView.Items.NodeData');
  LDelProps.Add('TListBox.OnData');

  // К сожалению, у компонента TChart в Лазарусе огромное количество свойств не
  // совместимо с Delphi. Потребуется значительный объём работы по ручной корректировки кода

  // Для TChart:
  LDelProps.Add('TChart.Legend.CheckBoxes');
  LDelProps.Add('TChart.Legend.TopPos');
  LDelProps.Add('TChart.MarginBottom');
  LDelProps.Add('TChart.MarginLeft');
  LDelProps.Add('TChart.MarginRight');
  LDelProps.Add('TChart.MarginTop');
  LDelProps.Add('TChart.OnClickLegend');
  LDelProps.Add('TChart.BottomAxis.DateTimeFormat');
  LDelProps.Add('TChart.BottomAxis.LabelsAngle');
  LDelProps.Add('TChart.RightAxis');
  LDelProps.Add('TChart.ScaleLastPage');
  LDelProps.Add('TChart.TopAxis');
  LDelProps.Add('TChart.View3D');
  LDelProps.Add('TChart.Zoom');
  LDelProps.Add('TChart.TabOrder');

  // Для TLineSeries:
  LDelProps.Add('TLineSeries.Marks.Callout');
  LDelProps.Add('TLineSeries.Pointer.InflateMargins');
  LDelProps.Add('TLineSeries.XValues');
  LDelProps.Add('TLineSeries.YValues');
  LDelProps.Add('TLineSeries.VertAxis');
  LDelProps.Add('TLineSeries.AfterDrawValues');
  LDelProps.Add('TLineSeries.ClickableLine');
  LDelProps.Add('TLineSeries.HorizAxis');

  // Для TPointSeries:
  LDelProps.Add('TPointSeries.Marks.Callout');
  LDelProps.Add('TPointSeries.Pointer.InflateMargins');
  LDelProps.Add('TPointSeries.XValues');
  LDelProps.Add('TPointSeries.YValues');
  LDelProps.Add('TPointSeries.VertAxis');
  LDelProps.Add('TPointSeries.AfterDrawValues');
  LDelProps.Add('TPointSeries.ClickableLine');
  LDelProps.Add('TPointSeries.HorizAxis');
end;

procedure TLazConvMainForm.FillReplPropsList;
begin
  LReplProps.Add('*.Padding=BorderSpacing'); // TControl.BorderSpacing (свойство может быть закрыто у компонентов!)
end;

procedure TLazConvMainForm.FillReplUnitsList;
begin
  LReplUnits.Add('Windows=LCLIntf,LCLType');
  LReplUnits.Add('Messages=LMessages');

  LReplUnits.Add('TeEngine=TAGraph,TASeries');
  LReplUnits.Add('Series=TAGraph,TASeries');
  LReplUnits.Add('TeeProcs=TAGraph,TASeries');
  LReplUnits.Add('Chart=TAGraph,TASeries');

  LReplUnits.Add('Mask=MaskEdit');
  LReplUnits.Add('JvExMask=MaskEdit');
  LReplUnits.Add('JvToolEdit=EditBtn');
  LReplUnits.Add('ToolEdit=EditBtn');
  LReplUnits.Add('JvSpin=del');
  LReplUnits.Add('JvMemoryDataset=RxMemDS');
  LReplUnits.Add('Placemnt=IniPropStorage');
  LReplUnits.Add('PngBitBtn=Buttons');
  LReplUnits.Add('PngSpeedButton=Buttons');
  LReplUnits.Add('PngImageList=del');
  LReplUnits.Add('PngFunctions=del');

  LReplUnits.Add('pngimage=Graphics');
  LReplUnits.Add('png_image=Graphics');
  LReplUnits.Add('jpeg=Graphics');

  LReplUnits.Add('ProgressViewer=del'); // Модуль ProgressViewer недоступен для Lazarus
  LReplUnits.Add('ActiveX=del');

  // Внимание! В Лазарусе для XML используются другие классы и методы!
  // Лучше заранее перейти на XML-библиотеку, которая работает одинаково и в Delphi и в Лазарусе
  LReplUnits.Add('XMLDoc=XMLRead');
  LReplUnits.Add('XMLIntf=DOM');

  LReplUnits.Add('WinSvc=JwaWinSvc'); // Требуется установить Jedi с помощью OPM

  LReplUnits.Add('AppEvnts=del');

  // del - означает, что модуль не будет подключен в секции USES для Лазаруса

end;

procedure TLazConvMainForm.FillUnitsForTypes;
begin
  // Для некоторых компонентов в Лазарусе используется другое название модуля

  LUnitsForTypes.Add('TDateTimePicker=DateTimePicker');
  LUnitsForTypes.Add('TPrintDialog=PrintersDlgs'); // В Delphi используется модуль Dialogs, но он нужен и для Лазаруса
  LUnitsForTypes.Add('TPrinterSetupDialog=PrintersDlgs');
end;

function TLazConvMainForm.NeedDelProp(sPropName: string; sClassName: string): Boolean;
var
  I: Integer;
  sPropFullName, sCurDelProp: string;
begin
  Result := False;
  sPropFullName := sClassName + '.' + sPropName;
  //sPropNameShort := sPropName;
  //if Pos('.', sPropName) > 0 then
  //  sPropNameShort := GetStringPart(sPropName, 1, '.'); //PngImage.Data -> PngImage
  for I := 0 to LDelProps.Count - 1 do
  begin
    sCurDelProp := FastStringReplace(LDelProps[I], '*', sClassName);
    if Pos(sCurDelProp, sPropFullName) > 0 then
      Exit(True);

    {if (LDelProps[I] = '*.' + sPropNameShort) or (LDelProps[I] = '*.' + sPropName) then
      Exit(True);
    if (LDelProps[I] = sClassName + '.' + sPropNameShort) or (LDelProps[I] = sClassName + '.' + sPropName) then
      Exit(True);  }

    //LDelProps.Add('TLineSeries.Pointer.InflateMargins');
  end;
end;

function TLazConvMainForm.NeedReplProp(sPropName: string; sClassName: string;
  out NewPropName: string): Boolean;
var
  I: Integer;
  s, sNew: string;
begin
  Result := False;
  s := sPropName;
  if Pos('.', s) > 0 then
    s := GetStringPart(s, 1, '.'); //Padding.Top -> Padding
  for I := 0 to LReplProps.Count - 1 do
  begin
    if (LReplProps.Names[I] = '*.' + s) or (LReplProps.Names[I] = sClassName + '.' + s) then
    begin
      sNew := LReplProps.ValueFromIndex[I];
      NewPropName := FastStringReplace(sPropName, s, sNew);
      Exit(True);
    end;
  end;
  //LReplProps.Add('*.Padding=BorderSpacing');
end;

procedure TLazConvMainForm.btnProcessClick(Sender: TObject);
var
  sFileName: string;
begin
  sFileName := FileListBox1.FileName;
  if not FileExists(sFileName) then
  begin
    Log('File not found: ' + sFileName);
    Exit;
  end;
  memErrors.Clear;
  if LowerCase(ExtractFileExt(sFileName)) = '.dfm' then
    ProcessDFM(sFileName, '');
  if LowerCase(ExtractFileExt(sFileName)) = '.pas' then
    ProcessPAS(sFileName);
end;

procedure TLazConvMainForm.btnConvertDFMBlockClick(Sender: TObject);
begin
  if TMessageForm.InputText(Self, DFMText) then
    ProcessDFM('', DFMText);

end;

end.

