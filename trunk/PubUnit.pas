unit PubUnit;

interface
uses IniFiles,Classes,SysUtils,Forms,Windows,DateUtils,StringR,
mimemess,mimepart,synachar,POP3Send,StdCtrls,Buttons;
const
tma_none=0;
tma_store=1;
tma_mail=2;
tma_reject=3;
tma_extract=4;

Type
TInputMailMessage=record
UIDL:string;
MAILFROM:string;
SUBJECT:string;
end;
TRule =record
subj:string;
action:smallint;
info:string;
end;
Var
Mailini:TIniFile;
Password:string;
pop3:TPOP3Send;
POP3Server:string;
POP3Port:string;
SMTPServer:string;
SMTPPort:string;
MailUser:string;
MailPassword:string;
InputLimit:integer;
WaitBeforeExit:boolean;
ill:integer;
arch:string;
log:string;
oem:boolean;
//msgFilename:string;
KeepMessage:boolean;
StoreLocaly:boolean;
apppath:string;
appName:string;
UserName:string;
rule:array of TRule;
WhiteListName:string;
WhiteList:TstringList;
BlackListName:string;
BlackList:TstringList;
TrashCan:string;
RemoveHeadersListName:string;
RemoveHeadersList:TstringList;
mID:integer;

procedure ReadIni(fn:string);
Function  ReadFileList(files:string):TStringList;
Function newspoolname:string;
//procedure Removeheaders(var Txt:TStringList);
function FindSubj(data:tstringList):string;
//function FindCTCS(Data:TStringList):string;
Function GetLocalUserName:string;
function ClearFrom(from:string):string;
function GetUserId(from:string):string;
function GetDefRule:Trule;
function getRule(subj:string):TRule;
procedure ChangeHeader(headerold,headernew:string;messLines:TStringList);
procedure AddHeader(header:string;messLines:TStringList);
procedure InsertHeaderFirst(header:string;messLines:TStringList);
function RemoveHeader(HeaderName:string;messLines:TStringList):integer;
function FindHeaderValue(header:string;messLines:TStringList):string;
function MakeNewDate(Date:TDateTime):string;
function ProtAdd(timeStamp:boolean;str:string):boolean;
function CheckWhiteList(email:string):boolean;
function ClearEMail(email:string):string;
function CheckXHeaders(messLines:TStringList):integer;
function CheckBlackList(email:string):boolean;
implementation
{*****************************************************************************}
function ProtAdd(timeStamp:boolean;str:string):boolean;
Var
i:integer;
dtins:string;
MsgList:TStringList;
Begin
result:=true;
if timeStamp then dtins:=formatDateTime('         hh:nn:ss',now)
             else dtins:='                 ';
if str<>'' then
 begin
  if oem then cchartooem(str);
  MsgList:=TStringList.create;
  MsgList.SetText(PChar(str));
  Writeln(dtins+' '+MsgList[0]);
  if MsgList.count>1 then
   for i:=1 to MsgList.count-1 do Writeln('                 '+' '+MsgList[i]);
  MsgList.free;
 end
           else   Writeln(dtins);

end;

function MakeNewDate(Date:TDateTime):string;
Var
sm:array [1..12] of string;
sw:array [1..7] of string;
df:integer;
day,month,year:word;
begin
sm[1]:='Jan';sm[2]:='Feb';sm[3]:='Mar';sm[4]:='Apr';
sm[5]:='May';sm[6]:='Jun';sm[7]:='Jul';sm[8]:='Aug';
sm[9]:='Sep';sm[10]:='Oct';sm[11]:='Nov';sm[12]:='Dec';

sw[1]:='Mon';sw[2]:='Tue';sw[3]:='Wed';sw[4]:='Thu';
sw[5]:='Fri';sw[6]:='Sat';sw[7]:='Sun';

df:=DayOfTheWeek(Date);
DecodeDate(Date,year,month,day);
result:= sw[df]+', '+formatDatetime('dd',Date)+' '+sm[Month]+' '+formatDatetime('yy hh:nn:ss',Date);

end;
function FindHeaderValue(header:string;messLines:TStringList):string;
Var
i:integer;
begin
result:='';
for i:=0 to messLines.Count-1 do
if messLines[i]='' then break
                   else
                   if at(messLines[i],header,1)=1 then
                                   begin
                                    result:=substr(messLines[i],length(header)+1,length(messLines[i]));
                                    break;
                                   end;
end;

procedure ChangeHeader(headerold,headernew:string;messLines:TStringList);
Var
i:integer;
begin
for i:=0 to messLines.Count-1 do
if at(messLines[i],headerold,1)=1 then
   begin
    messLines[i]:=headernew;
    break;
   end;
end;
function CheckXHeaders(messLines:TStringList):integer;
Var
i,j:integer;
begin
 result:=0;
 if messLines.Count=0 then exit;
 if RemoveHeadersList.count=0 then exit;

  for j:=0 to RemoveHeadersList.count-1 do
    begin
      i:=0;
      while messLines[i]<>'' do
        begin
          if at(UpperCase(messLines[i]),UpperCase(RemoveHeadersList[j])+':',1)=1 then
            begin
             messLines.delete(i);
             if messLines[i]<>'' then
               if (messLines[i][1]=#9) or (messLines[i][1]=' ')or (messLines[i][1]=',') then messLines.delete(i);
             inc(result);
             Continue;
           end;
          inc(i);
        end;
    end;
end;
function RemoveHeader(HeaderName:string;messLines:TStringList):integer;
Var
i:integer;
begin
 result:=0;
 if messLines.Count=0 then exit;
 i:=0;
 while messLines[i]<>'' do
  begin
   if at(UpperCase(messLines[i]),UpperCase(HeaderName)+':',1)=1 then
      begin
        messLines.delete(i);
        if messLines[i]<>'' then
        if (messLines[i][1]=#9) or (messLines[i][1]=' ')or (messLines[i][1]=',') then messLines.delete(i);
        inc(result);
        Continue;
       end;
   inc(i);
  end;

end;
procedure InsertHeaderFirst(header:string;messLines:TStringList);
begin
if messLines.Count=0 then exit;
messLines.Insert(0,header);
end;


procedure AddHeader(header:string;messLines:TStringList);
Var
lastline:integer;
i:integer;
begin
lastline:=0;
if messLines.Count=0 then exit;
for i:=0 to messLines.Count-1 do
if messLines[i]='' then
   begin
    lastline:=i;
    break;
   end;
messLines.Insert(lastline,header);
end;

function GetDefRule:Trule;
Var
i:integer;
begin
result.subj:='*';
result.action:=tma_none;
result.info:='';
for i:=0 to length(rule)-1 do
 if rule[i].subj='*' then
  begin
   result.action:=rule[i].action;
   result.info:=rule[i].info;
  end;
end;

function getRule(subj:string):TRule;
Var
i:integer;
begin
result:=GetDefRule;

for i:=0 to length(rule)-1 do
 if at(UpperCase(subj+' '),UpperCase(rule[i].subj+' '),1)=1 then
  begin
   result:=rule[i];
   exit;
  end;
end;

{*****************************************************************************}
{*****************************************************************************}
{*****************************************************************************}
Function GetLocalUserName:string;
Var
unbuff:PChar;
count:DWORD;
begin
 count:=256;
 unbuff:=StrAlloc(count);
 windows.GetUserName(unbuff,count);
 result:=UpperCase(unbuff);
 strDispose(unbuff);
end;

function FindSubj(data:tstringList):string;
Var
i:integer;
tstr:string;
begin
result:='';
for i:=0 to data.Count-1 do
 begin
 tstr:=upperCase(data[i]);
 if tstr='' then break;
 if at(tstr,'SUBJECT:',1)=1 then
    result:=substr(tstr,at(tstr,'SUBJECT:',1)+9,length(tstr));
 end;
end;

function GetUserId(from:string):string;
begin
result:='';
   if at(from,'@',1)<>0 then
    result:=substr(from,1,at(from,'@',1)-1)
                        else  result:=from;
end;

function ClearFrom(from:string):string;
begin
result:='';
   if at(from,'<',1)<>0 then
    result:=substr(from,at(from,'<',1)+1,at(from,'>',1)-at(from,'<',1)-1)
                        else
    result:=from;
end;
{*****************************************************************************}
//procedure Removeheaders(var Txt:TStringList);
//begin
//While (txt.Count>1) and (Txt[0]<>'') do txt.Delete(0);
//txt.delete(0);
//end;
{*****************************************************************************}
Function newspoolname:string;
Var
Ticks:DWORD;
begin
ticKs:=GetTickCount;
ticKs:=ticks and $00001111;
result:='@'+FormatDateTime('ddmmyyyy-hhnnss-',now)+format('%.5d',[TickS]);
end;
{*****************************************************************************}
function ReadFileList(files:string):TStringList;
Var
fs:SysUtils.TSearchRec;
envList:TstringList;
i:integer;
begin
EnvList:=TstringList.Create;
i:=SysUtils.FindFirst(files,FaAnyFile,FS);
while i=0 do
 begin
  Application.ProcessMessages;
  envList.add(fs.name);
  i:=SysUtils.FindNext(fs);
 end;
SysUtils.findClose(fs);
result:=envList;
end;
{*****************************************************************************}
function CheckWhiteList(email:string):boolean;
Var
i:integer;
begin
result:=true;
if WhiteList.Count=0 then exit;
result:=false;
email:=ClearEMail(email);
//FileAddLn('email.txt',email); //remove after test
for i:=0 to WhiteList.Count-1 do
 if (Uppercase(email)=Uppercase(WhiteList.Strings[i]))or(WhiteList.Strings[i]='*')  then
  begin
   result:=true;
   break;
  end;
end;
function CheckBlackList(email:string):boolean;
Var
i:integer;
begin
result:=false;
if BlackList.Count=0 then exit;
email:=ClearEMail(email);
for i:=0 to BlackList.Count-1 do
 if (Uppercase(email)=Uppercase(BlackList.Strings[i]))or(BlackList.Strings[i]='*') then
  begin
   result:=true;
   break;
  end;
end;

{*****************************************************************************}
function ClearEMail(email:string):string;
begin
result:=trim(email);
if email='' then exit;
if (pos('<',email)<>0)and(pos('>',email)<>0) then email:=substr(email,pos('<',email)+1,pos('>',email)-pos('<',email)-1);
if (pos(' ',email)>0) then email:=substr(email,1,pos(' ',email));
result:=trim(email);
end;
{*****************************************************************************}
procedure ReadIni(fn:string);
Begin
MailIni:=TiniFile.create(fn);
POP3Server:=MailIni.readstring('general','SERVERPOP3','127.0.0.1');
POP3Port:=MailIni.readstring('general','PORTPOP3','110');
SMTPServer:=MailIni.readstring('general','SERVERSMTP','127.0.0.1');
SMTPPort:=MailIni.readstring('general','PORTSMTP','25');
MailUser:=MailIni.readstring('general','USER','');
MailPassword:=MailIni.readstring('general','PASSWORD',MailUser);
InputLimit:=MailIni.readinteger('general','INPUTLIMIT',10);
KeepMessage:=MailIni.readbool('general','KEEPMESSAGE',false);
arch:=MailIni.readstring('general','ARCH','arch');
StoreLocaly:=MailIni.readbool('general','STORELOCALY',false);
WaitBeforeExit:=MailIni.readbool('general','waitexit',false);
log:=MailIni.readstring('general','LOG','log');
WhiteListName:=MailIni.readstring('general','WHITELIST','');
BlackListName:=MailIni.readstring('general','BLACKLIST','');
RemoveHeadersListName:=MailIni.readstring('general','RemoveHeadersList','');
trashcan:=MailIni.readstring('general','trashcan','');
MailIni.free;
end;
{*****************************************************************************}
{*****************************************************************************}

end.
