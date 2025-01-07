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

unit lazconvmsgfrm;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ButtonPanel, StdCtrls, Clipbrd;

type

  { TMessageForm }

  TMessageForm = class(TForm)
    Button1: TButton;
    ButtonPanel1: TButtonPanel;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
  private

  public
    class procedure ShowMessage(AOwner: TForm; sMsg: string);
    class function InputText(AOwner: TForm; var sText: string): Boolean;
  end;

implementation

{$R *.lfm}

{ TMessageForm }

procedure TMessageForm.Button1Click(Sender: TObject);
begin
  Clipboard.AsText := Memo1.Text;
end;

class procedure TMessageForm.ShowMessage(AOwner: TForm; sMsg: string);
var
  f: TMessageForm;
begin
  f := TMessageForm.Create(AOwner);
  try
    f.Memo1.Text := sMsg;
    f.ShowModal;
  finally
    f.Free;
  end;
end;

class function TMessageForm.InputText(AOwner: TForm; var sText: string): Boolean;
var
  f: TMessageForm;
begin
  f := TMessageForm.Create(AOwner);
  try
    f.Memo1.Text := sText;
    Result := f.ShowModal = mrOK;
    if Result then
      sText := f.Memo1.Text;
  finally
    f.Free;
  end;
end;

end.

