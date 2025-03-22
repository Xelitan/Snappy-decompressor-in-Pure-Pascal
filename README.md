# Snappy decompressor in pure Pascal
Snappy decompressor in pure Pascal. Should work in most Delphi and Lazarus versions. No DLLs required or any non-standard libraries.

## Usage example
Decoding TBytes:
```
var InData, OutData: TBytes;
    F: TFileStream;
    Str: String;
begin
  F := TFileStream.Create('test.Snappy', fmOpenRead);
  SetLength(InData, F.Size);
  F.Read(InData[0], F.Size);
  F.Free;

  OutData := SnappyDecode(InData);
  SetLength(Str, Length(OutData));
  Move(OutData[0], Str[1], Length(Str));

  Memo1.Lines.Add(Str);
end;
```
Decoding Streams:
```
var F,P: TFileStream;
begin
  F := TFileStream.Create('test.Snappy', fmOpenRead);
  P := TFileStream.Create('test.txt', fmCreate);

  SnappyDecodeStream(F, P);

  p.Free;
  F.Free;
end;
```
