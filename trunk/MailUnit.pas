unit MailUnit;
interface
uses SysUtils,DateUtils,PubUnit,mimemess,mimepart,synachar,POP3Send,
  stringr;
procedure runMail;
implementation
procedure runMail;
Var
nr,seq,i,j,mnum,attCount:integer;
Mess:TMimeMess;
nrs,msg,emsg,ffrom,cFrom,cSubj:string;
isLogin,delres:Boolean;
storename,attName:string;
hdate:string;
ActRule:TRule;
begin
   isLogin:=false;
try
   if pop3.Login then
     begin
      isLogin:=true;
      ProtAdd(true,'Login OK')
     end
               else
     begin
      isLogin:=false;
      ProtAdd(true,'ERROR: Login Fail');
      ProtAdd(false,'< -'+pop3.ResultString);
      ExitCode:=12;
      Exit;
     end;

   pop3.UIDL(0);
   mnum:=pop3.FullResult.Count;
   ProtAdd(false,'***Total in mailbox '+itos(mnum)+' limit '+itos(InputLimit));

   if mnum>InputLimit then mnum:=InputLimit;
   for i:=0 to mnum-1 do
    begin
     cFrom:='';
     ffrom:='';
     hdate:='';
     cSubj:='';
     Mess:=TMimeMess.Create;
     if not pop3.Retr(i+1) then
      begin
       ProtAdd(true,'ERROR: Can''t load msg ' +pop3.ResultString);
       Mess.Free;
       continue;
      end;
     Mess.Lines.Assign(pop3.FullResult);
     Mess.DecodeMessage;
     ffrom:=Mess.Header.From;
     cFrom:=UpperCase(GetUserId(ClearFrom(ffrom)));
     storename:=arch+itos(DayOfTheYear(now))+'_'+formatDatetime('hhnnss',now)+'_'+itos(i)+'_'+cFrom+'.eml';
     hdate:=FindHeaderValue('Date:',Mess.Lines);
     cSubj:=Mess.Header.Subject;

     ProtAdd(True,'From '''+ffrom+''' Subj '''+cSubj+'''');
//   имя для архива и корзины
     j:=0;
     while (Fileexists(arch+storename))or(Fileexists(trashcan+storename)) do
       begin
        storename:=itos(DayOfTheYear(now))+'_'+formatDatetime('hhnnss',now)+'_'+itos(i)+'-'+itos(j)+'_'+cFrom+'.eml';
        inc(j);
     end;
//

     if not CheckWhiteList(ffrom) then
      begin
       ProtAdd(false,'Skiped (not in whitelist).');
//проверить работу
       if (CheckBlackList(ffrom)) then
         begin
           if TrashCan<>'' then pop3.FullResult.SaveToFile(TrashCan+storename);
           if (not KeepMessage) then
              begin
                if not pop3.Dele(i+1) then
                  begin
                   ProtAdd(true,'ERROR: Can''t remove msg from '+ffrom);
                   ProtAdd(false,pop3.ResultString);
                  end
                                   else  ProtAdd(false,'Deleted (found in BlackList).');
              end;
         end;
       Mess.Free;
       continue;
      end;

     if StoreLocaly then pop3.FullResult.SaveToFile(arch+storename);
     storename:='';
     emsg:='';
     seq:=0;
     ActRule:=getRule(cSubj);
//изменить заголовки
     case ActRule.action of
     tma_none:begin
               ProtAdd(false,'leave over.');
               Mess.Free;
               continue;
              end;
    tma_store:begin
               storename:=ActRule.info+'ST'+itos(DayOfTheYear(now))+formatDatetime('hhnnss',now)+itos(i)+'.eml';
               while FileExists(storename) do storename:=ActRule.info+'ST'+itos(DayOfTheYear(now))+formatDatetime('hhnnss',now)+itos(i)+'.eml';
               nr:=CheckXHeaders(mess.Lines);
               nrs:='.';
               if nr>0 then
               nrs:=', '+itos(nr)+' RH.';
               AddHeader('X-MailProcessorInfo: FileName '+ExtractFileName(storename)+'Rule '+ActRule.subj+nrs,mess.Lines);
               InsertHeaderFirst('Received: by cgetmail from pokemon; '+MakeNewDate(now),mess.Lines);
               try
                 mess.Lines.SaveToFile(storename);
                 except on e:exception do
                   begin
                     ProtAdd(true,'ERROR: Ошибка при сохранении файла '+storename);
                     ProtAdd(false,e.message);
                     Mess.Free;
                     continue;
                   end;
               end;
               ProtAdd(false,'stored in '''+storename+'''');
              end;
    tma_extract:begin
                 attCount:=Mess.MessagePart.GetSubPartCount;
                 msg:='Частей :'+itos(attCount)+'  Файлы: ';
                 for j:=0 to attCount-1 do
                   begin
                    Mess.MessagePart.GetSubPart(j).decodePart;
                    attName:=Mess.MessagePart.GetSubPart(j).FileName;
                    if attName='' then continue;
                    msg:=msg+''''+attName+'''  ';
                   end;
                 ProtAdd(false,msg);
                 for j:=0 to attCount-1 do
                  begin
                    Mess.MessagePart.GetSubPart(j).decodePart;
                    try
                     attName:=Mess.MessagePart.GetSubPart(j).FileName;
                     if attName='' then continue;
                     Mess.MessagePart.GetSubPart(j).decodedlines.SaveToFile(ActRule.info+attName);
                     ProtAdd(false,attName+' Файл сохранен');
                    except on e:exception do
                      begin
                       ProtAdd(true,'ERROR: Ошибка при сохранении файла '+ActRule.info+attName);
                       ProtAdd(false,e.message);
                       Mess.Free;
                       continue;
                      end;
                    end;
                   end;
              end;
   tma_reject:begin
               ProtAdd(false,'rejected (by subj rule).');
              end;

     tma_mail:begin
               ProtAdd(False,'mailed to '''+ActRule.info+'''');
//пересылка
               if seq=-1 then raise Exception.Create('Ошибка при сохранении файла');
              end;
     else
              begin
               ProtAdd(true,'ERROR: Can''t process message. No rule.');
             end;
     end;//case

     if not KeepMessage then
       begin
         if not pop3.Dele(i+1) then
           begin
             ProtAdd(true,'ERROR: Can''t remove msg from '+cfrom);
             ProtAdd(false,''''+pop3.ResultString+'''');
           end
                                else ProtAdd(false,'DELETE Msg from '+cfrom);
       end;
     Mess.Free;
    end;//end process of one message
   ProtAdd(true,'Logout');
   pop3.Logout;

   if  mnum=InputLimit then ExitCode:=1;
   except
   on e:exception do
    begin
     ProtAdd(true,'ERROR: final exeption : '+e.Message);
     ExitCode:=11;
     if isLogin then
      begin
       pop3.Logout;
       ProtAdd(true,'Logout');
      end;
    end;
   end;
end;

end.
