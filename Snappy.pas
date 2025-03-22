unit Snappy;

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Description:	Snappy decompressor in pure Pascal                            //
// Version:	0.1                                                           //
// Date:	22-MAR-2025                                                   //
// License:     MIT                                                           //
// Target:	Win64, Free Pascal, Delphi                                    //
// Base on:     PHP code by Norbert Orzechowicz                               //
// Copyright:	(c) 2025 Xelitan.com.                                         //
//		All rights reserved.                                          //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

interface

uses Classes, SysUtils;

const
  WORD_MASK: array[0..4] of Cardinal = (0, $FF, $FFFF, $FFFFFF, $FFFFFFFF);

  function SnappyDecode(const InBuffer: TBytes; var OutBuffer: TBytes): Boolean;
  function SnappyDecodeStream(InStream, OutStream: TStream): Boolean;

implementation

function SnappyDecode(const InBuffer: TBytes; var OutBuffer: TBytes): Boolean;
var InMem, OutMem: TMemoryStream;
begin
  InMem := TMemoryStream.Create;
  OutMem := TMemoryStream.Create;
  try
    InMem.Write(InBuffer[0], Length(InBuffer));
    InMem.Position := 0;

    Result := SnappyDecodeStream(InMem, OutMem);

    OutMem.Position := 0;
    SetLength(OutBuffer, OutMem.Size);
    OutMem.Read(OutBuffer[0], OutMem.Size);
  finally
    InMem.Free;
    OutMem.Free;
  end;
end;

function SnappyDecodeStream(InStream, OutStream: TStream): Boolean;
  function ReadUncompressedLength: Integer;
  var Res, Shift: Integer;
      C: Byte;
      Val: Integer;
  begin
    Res := 0;
    Shift := 0;
    while Shift < 32 do begin
      if InStream.Read(C, 1) <> 1 then Exit(-1);
      Val := C and $7F;
      if ((Val shl Shift) shr Shift) <> Val then Exit(-1);
      Res := Res or (Val shl Shift);
      if C < 128 then Exit(Res);
      Inc(Shift, 7);
    end;
    Result := -1;
  end;

var C: Byte;
    Len, SmallLen, Offset: Integer;
    Buf: array[0..3] of Byte;
    i: Integer;
    TempLen: Cardinal;
    LiteralBytes: TBytes;
    CopyBuf: TBytes;
    OutPos: Int64;
    UncompressedLength: Integer;
begin
  Result := False;
  UncompressedLength := ReadUncompressedLength;
  if UncompressedLength <= 0 then Exit;

  try
    OutStream.Size := UncompressedLength;
  except
    Exit(False);
  end;
  OutStream.Position := 0;
  OutPos := 0;

  while InStream.Position < InStream.Size do begin
    if InStream.Read(C, 1) <> 1 then Exit(False);

    if (C and $3) = 0 then begin
      // Handle literal
      Len := (C shr 2) + 1;

      if Len > 60 then begin
        SmallLen := Len - 60;
        if (SmallLen < 1) or (SmallLen > 4) then Exit(False);
        if InStream.Read(Buf, SmallLen) <> SmallLen then Exit(False);
        TempLen := 0;
        for i:=0 to SmallLen-1 do TempLen := TempLen or (Cardinal(Buf[i]) shl (i * 8));
        Len := (TempLen and WORD_MASK[SmallLen]) + 1;
      end;

      if InStream.Size - InStream.Position < Len then Exit(False);
      SetLength(LiteralBytes, Len);
      if InStream.Read(LiteralBytes[0], Len) <> Len then Exit(False);
      OutStream.Position := OutPos;
      if OutStream.Write(LiteralBytes[0], Len) <> Len then Exit(False);
      Inc(OutPos, Len);
    end
    else begin
      // Handle copy
      case C and $3 of
       1: begin
            Len := ((C shr 2) and $7) + 4;
            if InStream.Read(Buf[0], 1) <> 1 then Exit(False);
            Offset := Buf[0] or ((C shr 5) shl 8);
          end;
       2: begin
            Len := (C shr 2) + 1;
            if InStream.Read(Buf[0], 2) <> 2 then Exit(False);
            Offset := Buf[0] or (Buf[1] shl 8);
          end;
       3: begin
            Len := (C shr 2) + 1;
            if InStream.Read(Buf[0], 4) <> 4 then Exit(False);
            Offset := Buf[0] or (Buf[1] shl 8) or (Buf[2] shl 16) or (Buf[3] shl 24);
          end;
        else
          Exit(False);
      end;

      if (Offset = 0) or (Offset > OutPos) then Exit(False);

      SetLength(CopyBuf, Len);
      try
        OutStream.Position := OutPos - Offset;
        if OutStream.Read(CopyBuf[0], Len) <> Len then Exit(False);
        OutStream.Position := OutPos;
        if OutStream.Write(CopyBuf[0], Len) <> Len then Exit(False);
      except
        Exit(False);
      end;
      Inc(OutPos, Len);
    end;
  end;

  Result := (OutPos = UncompressedLength);
end;

end.


