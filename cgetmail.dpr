program cgetmail;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  PubUnit,
  Windows,
  Classes,
  stringr,
  POP3Send,
  MailUnit in 'MailUnit.pas';

Var
iniFileName:string;
function InitTask:integer;
Var
i:integer;
CfgBlock:TStringList;
actStr:string;
begin
result:=0;
 ProtAdd(True,'Mailer started.');
 ProtAdd(False,'INI File: '+iniFileName);
 ProtAdd(False,'Server POP3: '+POP3Server+' Port: '+POP3Port);
 ProtAdd(False,'Server SMTP: '+SMTPServer+' Port: '+SMTPPort);
// ProtAdd(False,'Mail User: '+MailUser);
 if InputLimit=0 then InputLimit:=10;
 ProtAdd(False,'Input limit: '+itos(InputLimit));
 if KeepMessage then ProtAdd(False,'ERROR: Test mode active, message will be dublicated');
 if TrashCan<>'' then
  begin
    if at(TrashCan,':',1)=0 then TrashCan:=apppath+TrashCan;
    if TrashCan[length(TrashCan)]<>'\' then TrashCan:=TrashCan+'\';
    if directoryexists(TrashCan) then
    ProtAdd(False,'Message marked as "in Black List" will bee stored localy in '+TrashCan)
                           else TrashCan:='';
  end;

 if at(arch,':',1)=0 then arch:=apppath+arch;
 if arch[length(arch)]<>'\' then arch:=arch+'\';
 ProtAdd(False,'Archive path: '+arch);
 if  StoreLocaly then ProtAdd(False,'Message will bee stored localy in '+Arch);
 WhiteList:=TstringList.Create;
 BlackList:=TstringList.Create;
 RemoveHeadersList:=TstringList.Create;
 if at(WhiteListName,':',1)=0 then WhiteListName:=apppath+WhiteListName;
  if Fileexists(WhiteListName) then WhiteList.LoadFromFile(WhiteListName);
 if WhiteList.count<>0 then  //BlackList не будет использоваться если нет WhiteList
    begin
      ProtAdd(False,'Used White List from file '+WhiteListName);
      if at(BlackListName,':',1)=0 then BlackListName:=apppath+BlackListName;
      if Fileexists(BlackListName) then BlackList.LoadFromFile(BlackListName);
      if BlackList.count<>0 then ProtAdd(False,'Used Black List from file '+BlackListName);
    end;
 if Fileexists(RemoveHeadersListName) then RemoveHeadersList.LoadFromFile(RemoveHeadersListName);
 if RemoveHeadersList.count<>0 then ProtAdd(False,'RemoveHeadersList from file '+RemoveHeadersListName);

 ShortDateFormat:='mm/dd/yy';
 CfgBlock:=TStringList.create;
 CfgBlock.loadFromFile(iniFileName);
 for i:=0 to CfgBlock.count-1 do
   if at(CfgBlock[i],'subj=',1)=1 then
    begin
     setlength(rule,length(rule)+1);
     rule[length(rule)-1].subj:=trim(substr(CfgBlock[i],at(CfgBlock[i],'=',1)+1,at(CfgBlock[i],',',1)-at(CfgBlock[i],'=',1)-1));
     actStr:=substr(CfgBlock[i],at(CfgBlock[i],',',1)+1,at(CfgBlock[i],',',2)-at(CfgBlock[i],',',1)-1);
     rule[length(rule)-1].action:=tma_none;
     rule[length(rule)-1].info:='';
     if actStr='store' then rule[length(rule)-1].action:=tma_store;
     if actStr='mail' then rule[length(rule)-1].action:=tma_mail;
     if actStr='reject' then rule[length(rule)-1].action:=tma_reject;
     if actStr='extract' then rule[length(rule)-1].action:=tma_extract;

     rule[length(rule)-1].info:=substr(CfgBlock[i],at(CfgBlock[i],',',2)+1,length(CfgBlock[i]));
     ProtAdd(False,'Subj: '''+rule[length(rule)-1].subj+''' Action: '+UpperCase(actStr)+' Info: '''+rule[length(rule)-1].info+'''');
    end;
CfgBlock.Free;

if getRule('любая дурацкая тема').info='' then
 begin
  ProtAdd(False,'Can''t find default rule. deault action - NONE');
 end;

try
pop3:=TPOP3Send.Create;
except
on E:Exception do
 begin
  ProtAdd(False,'ERROR: Can''t create POP3 object.');
  ProtAdd(False,E.Message);
  result:=3;
 end;
end;
pop3.TargetHost:=POP3Server;
pop3.TargetPort:=POP3Port;
POP3.Username:=lowerCase(MailUser);
POP3.Password:=MailPassword;
POP3.AuthType:=POP3AuthLogin;
end;
// main proc
begin
  { TODO -oUser -cConsole Main : Insert code here }
  apppath:=ExtractFilePath(paramstr(0));
  appName:=ExtractFileName(paramstr(0));
  writeln(formatDateTime('dd/mm/yy hh:nn:ss',now)+' '+paramstr(0));
  if paramcount()<1 then
   begin
    writeln('Usage: '+appName+' ini-filename [oem]');
    ExitCode:=3;
    exit;
   end;
   iniFileName:=apppath+paramstr(1);
   if not FileExists(iniFileName) then
     begin
       ExitCode:=3;
       writeln('Не найден файл конфигурации '+iniFileName);
       exit;
     end;
  oem:=false;
  if (paramcount()>1) then
    if (paramstr(2)='oem') then oem:=true;

  readIni(iniFileName);
  ExitCode:=InitTask;
  if ExitCode<>0 then
   begin
    ProtAdd(TRUE,'ERROR: Can''t start, Init ERROR: '+itos(ExitCode));
    exit;
   end;
    runmail;
    WhiteList.Destroy;
    RemoveHeadersList.Destroy;
  if WaitBeforeExit then
   begin
      ProtAdd(TRUE,'*** Press any key...');
      readln;
   end;

  end.
