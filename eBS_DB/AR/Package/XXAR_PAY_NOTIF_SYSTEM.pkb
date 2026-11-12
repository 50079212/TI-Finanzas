CREATE OR REPLACE PACKAGE BODY XXBOT.XXAR_PAY_NOTIF_SYSTEM
    AS
    procedure  XXAR_SEND_MAIL_XCUST (errbuf out varchar2,retcode out number)
    is 
    v_GEN_EC number;
    v_file varchar2(40);
    v_request_id number;
    v_user_id number;
    v_valid_line number;
    v_exit_notif varchar2(40);
    v_exit_create_tk varchar2(40);
    V_GEN_TICKET_C number;
    
    begin
    
                select nvl(fnd_global.conc_request_id,to_char(sysdate,'YYYYMMDDHH24MISS')),nvl(fnd_global.user_id,-1)
                                into v_request_id ,V_USER_ID 
                                from dual;
--Genero EC linea de aviso para las cadenas con status "Activa"
                      begin
                      for cur in (select distinct (b.customer_id),b.number_a,b.org_id,a.send_notice
                                            from xxwebc.xxar_bots_tbl_cust_mails_cs A,xxbot.xxar_bots_edo_cta B,apps.ar_customers C
                                            WHERE 1=1
--                                            and C.attribute15 in ( SELECT meaning
--                                                                        FROM apps.fnd_lookup_values_vl vl
--                                                                        WHERE lookup_type = 'XXAR_LISTA_EJECUTIVOS_CT'
--                                                                        AND SYSDATE BETWEEN start_date_active
--                                                                        AND NVL (end_date_active,SYSDATE + 1))
                                            and c.customer_id=b.customer_id
                                            and a.customer_id=b.customer_id
                                            AND nvl(a.STATUS,'Activo')='Activo'
                                            AND b.BALANCE_DUE >1
                                                and b.org_id not in (select flex_value 
                                                                           from APPS.XXGL_EMPRESAS_FUSIONADAS_VM)
                                            AND b.DUE_DATE<TRUNC(SYSDATE-10)
                                            AND (b.MESSAGE IS NULL or b.message='RESUELTO' or b.message='PROMESA DE PAGO' and to_date(scheduled_date,'dd-mm-yyyy')< to_date (sysdate,'dd-mm-yyyy'))
                                            order by customer_id,org_id )
                               loop
                               v_valid_line:=0;
                                       select count (*) into v_valid_line
                                               from XXBOT.XXAR_CONTROL_NOTIFY_H a
                                               where 1=1
                                               and a.REQUEST_ID=v_request_id
                                               and a.CONFIRMATION='N'
                                               and a.customer_id=cur.customer_id;
                IF v_valid_line=0
                THEN
                                   --genero ec e inserto registro en tabla control 
                                   v_GEN_EC:=0;
                                   v_file:=null;
                                   v_valid_line:=0;
                                   XXBOT.XXAR_PAY_NOTIF_SYSTEM.XXAR_EC_GEN(cur.org_id,cur.customer_id,v_GEN_EC);
                                   XXBOT.XXAR_PAY_NOTIF_SYSTEM.GEN_FILE_EDO_CTA(cur.number_a,cur.org_id,v_file);
                                   if v_GEN_EC=1 and v_file is not null
                                   then 
                                               select count (*) into v_valid_line
                                               from XXBOT.XXAR_CONTROL_NOTIFY_H a
                                               where 1=1
                                               and a.REQUEST_ID=v_request_id
                                               and a.customer_id=cur.customer_id;
                                                if v_valid_line=0
                                                then 
                                                insert into XXBOT.XXAR_CONTROL_NOTIFY_H (
                                                REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,attribute1,attribute2,attribute3,attribute4,status,send_notice,confirmation,error_confirmation) values 
                                                (v_request_id,cur.customer_id,cur.number_a,v_file,null,null,null,'Primer Aviso',cur.send_notice,null,null);
                                                
                                                insert into XXBOT.XXAR_CONTROL_NOTIFY_D (select v_request_id,CUSTOMER_TRX_ID,number_b,DUE_DATE,CUSTOMER_ID,number_a,ORG_ID
                                                                from xxbot.xxar_bots_edo_cta B
                                                                WHERE 1=1
                                                                AND b.BALANCE_DUE >1
                                                                and b.org_id=cur.org_id
                                                                and b.customer_id=cur.customer_id
                                                                AND b.DUE_DATE<TRUNC(SYSDATE-10)
                                                                AND (b.MESSAGE IS NULL or b.message='RESUELTO' or b.message='PROMESA DE PAGO' and to_date(scheduled_date,'dd-mm-yyyy')< to_date (sysdate,'dd-mm-yyyy')));
                                                
                                                update xxwebc.xxar_bots_tbl_cust_mails_cs cs
                                                set cs.status='Primer Aviso',cs.date_status=sysdate
                                                where 1=1
                                                and cs.CUSTOMER_ID=cur.customer_id;
                                                
                                                insert into xxbot.status_warnings_hist
                                                  (ID,REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,STATUS,CReATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATE_BY,PROCESO)
                                                  values (XXBOT.AR_SEQ_STATUS_HIST_CT.NEXTVAL,V_REQUEST_ID,cur.customer_id,cur.number_a,'Primer Aviso',sysdate,v_user_id,sysdate,v_user_id,'GEN_AUT_ADV');
                                                  commit; 
                                                  else 
                                                  update XXBOT.XXAR_CONTROL_NOTIFY_H h
                                                  set h.attribute2=v_file
                                                  where 1=1
                                                  and h.customer_id=cur.customer_id
                                                  and h.request_id=v_request_id;
                                                  
                                                  insert into XXBOT.XXAR_CONTROL_NOTIFY_D (select v_request_id,CUSTOMER_TRX_ID,number_b,DUE_DATE,CUSTOMER_ID,number_a,ORG_ID
                                                                from xxbot.xxar_bots_edo_cta B
                                                                WHERE 1=1
                                                                AND b.BALANCE_DUE >1
                                                                and b.org_id=cur.org_id
                                                                and b.customer_id=cur.customer_id
                                                                AND b.DUE_DATE<TRUNC(SYSDATE-10)
                                                                AND (b.MESSAGE IS NULL or b.message='RESUELTO' or b.message='PROMESA DE PAGO' and to_date(scheduled_date,'dd-mm-yyyy')< to_date (sysdate,'dd-mm-yyyy')));
                                                                
                                                  commit;
                                                  end if;
                                else 
                                    select count (*) into v_valid_line
                                               from XXBOT.XXAR_CONTROL_NOTIFY_H a
                                               where 1=1
                                               and a.REQUEST_ID=v_request_id
                                               and a.customer_id=cur.customer_id;
                                                if v_valid_line=0 then
                                                
                                                insert into XXBOT.XXAR_CONTROL_NOTIFY_H (
                                                REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,attribute1,attribute2,attribute3,attribute4,status,send_notice,confirmation,error_confirmation) values 
                                                (v_request_id,cur.customer_id,cur.number_a,null,null,null,null,'Activo',cur.send_notice,'N','Error al generar EC');
                                                COMMIT;
                                                ELSE 
                                                update XXBOT.XXAR_CONTROL_NOTIFY_H h
                                                  set h.attribute1=NULL,h.attribute2=NULL,H.confirmation='N',h.ERROR_CONFIRMATION='Error al generar EC'
                                                  where 1=1
                                                  and h.customer_id=cur.customer_id
                                                  and h.request_id=v_request_id;
                                                  commit;
                                                end if;
                                   end if;
                               
                               END IF;
                               end loop;
                               end;
                   
-----HAGO VALIDACIÓN DE CADENAS STATUS "Primer Aviso'
begin
for cur in (select distinct (b.customer_id),b.number_a,b.org_id,a.send_notice
                                from xxwebc.xxar_bots_tbl_cust_mails_cs A,xxbot.xxar_bots_edo_cta B,apps.AR_customers C
                                WHERE 1=1
--                                and C.attribute15 in ( SELECT meaning
--                                                            FROM apps.fnd_lookup_values_vl vl
--                                                            WHERE lookup_type = 'XXAR_LISTA_EJECUTIVOS_CT'
--                                                            AND SYSDATE BETWEEN start_date_active
--                                                            AND NVL (end_date_active,SYSDATE + 1))
                                and c.customer_id=b.customer_id
                                and a.customer_id=b.customer_id
                                AND a.STATUS='Primer Aviso'
                                and to_date (a.DATE_STATUS,'dd-mm-yyyy')<=to_date(sysdate-7,'dd-mm-yyyy')
                                AND b.BALANCE_DUE >1
                                    and b.org_id not in (select flex_value 
                                                               from APPS.XXGL_EMPRESAS_FUSIONADAS_VM)
                                AND b.DUE_DATE<TRUNC(SYSDATE-10)
                                AND (b.MESSAGE IS NULL or b.message='RESUELTO' or b.message='PROMESA DE PAGO' and to_date(scheduled_date,'dd-mm-yyyy')< to_date (sysdate,'dd-mm-yyyy'))
                                order by customer_id,org_id )
                   loop
                   v_valid_line:=0;
                           select count (*) into v_valid_line
                                   from XXBOT.XXAR_CONTROL_NOTIFY_H a
                                   where 1=1
                                   and a.REQUEST_ID=v_request_id
                                   and a.CONFIRMATION='N'
                                   and a.customer_id=cur.customer_id;
    IF v_valid_line=0
    THEN
                       --genero ec e inserto registro en tabla control 
                       v_GEN_EC:=0;
                       v_file:=null;
                       v_valid_line:=0;
                       XXBOT.XXAR_PAY_NOTIF_SYSTEM.XXAR_EC_GEN(cur.org_id,cur.customer_id,v_GEN_EC);
                       XXBOT.XXAR_PAY_NOTIF_SYSTEM.GEN_FILE_EDO_CTA(cur.number_a,cur.org_id,v_file);
                       if v_GEN_EC=1 and v_file is not null
                       then 
                                   select count (*) into v_valid_line
                                   from XXBOT.XXAR_CONTROL_NOTIFY_H a
                                   where 1=1
                                   and a.REQUEST_ID=v_request_id
                                   and a.customer_id=cur.customer_id;
                                    if v_valid_line=0
                                    then 
                                    insert into XXBOT.XXAR_CONTROL_NOTIFY_H (
                                    REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,attribute1,attribute2,attribute3,attribute4,status,send_notice,confirmation,error_confirmation) values 
                                    (v_request_id,cur.customer_id,cur.number_a,v_file,null,null,null,'Segundo Aviso',cur.send_notice,null,null);
                                    
                                    update xxwebc.xxar_bots_tbl_cust_mails_cs cs
                                    set cs.status='Segundo Aviso',cs.date_status=sysdate
                                    where 1=1
                                    and cs.CUSTOMER_ID=cur.customer_id;
                                    
                                    insert into XXBOT.XXAR_CONTROL_NOTIFY_D (select v_request_id,CUSTOMER_TRX_ID,number_b,DUE_DATE,CUSTOMER_ID,number_a,ORG_ID
                                                                from xxbot.xxar_bots_edo_cta B
                                                                WHERE 1=1
                                                                AND b.BALANCE_DUE >1
                                                                and b.org_id=cur.org_id
                                                                and b.customer_id=cur.customer_id
                                                                AND b.DUE_DATE<TRUNC(SYSDATE-10)
                                                                AND (b.MESSAGE IS NULL or b.message='RESUELTO' or b.message='PROMESA DE PAGO' and to_date(scheduled_date,'dd-mm-yyyy')< to_date (sysdate,'dd-mm-yyyy')));
                                    
                                    insert into xxbot.status_warnings_hist
                                      (ID,REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,STATUS,CReATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATE_BY,PROCESO)
                                      values (XXBOT.AR_SEQ_STATUS_HIST_CT.NEXTVAL,V_REQUEST_ID,cur.customer_id,cur.number_a,'Segundo Aviso',sysdate,v_user_id,sysdate,v_user_id,'GEN_AUT_ADV');
                                      commit; 
                                      else 
                                      update XXBOT.XXAR_CONTROL_NOTIFY_H h
                                      set h.attribute2=v_file
                                      where 1=1
                                      and h.customer_id=cur.customer_id
                                      and h.request_id=v_request_id;
                                      
                                      insert into XXBOT.XXAR_CONTROL_NOTIFY_D (select v_request_id,CUSTOMER_TRX_ID,number_b,DUE_DATE,CUSTOMER_ID,number_a,ORG_ID
                                                                from xxbot.xxar_bots_edo_cta B
                                                                WHERE 1=1
                                                                AND b.BALANCE_DUE >1
                                                                and b.org_id=cur.org_id
                                                                and b.customer_id=cur.customer_id
                                                                AND b.DUE_DATE<TRUNC(SYSDATE-10)
                                                                AND (b.MESSAGE IS NULL or b.message='RESUELTO' or b.message='PROMESA DE PAGO' and to_date(scheduled_date,'dd-mm-yyyy')< to_date (sysdate,'dd-mm-yyyy')));
                                                                
                                      commit;
                                      end if;
                    else 
                        select count (*) into v_valid_line
                                   from XXBOT.XXAR_CONTROL_NOTIFY_H a
                                   where 1=1
                                   and a.REQUEST_ID=v_request_id
                                   and a.customer_id=cur.customer_id;
                                    if v_valid_line=0 then
                                    
                                    insert into XXBOT.XXAR_CONTROL_NOTIFY_H (
                                    REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,attribute1,attribute2,attribute3,attribute4,status,send_notice,confirmation,error_confirmation) values 
                                    (v_request_id,cur.customer_id,cur.number_a,null,null,null,null,'Primer Aviso',cur.send_notice,'N','Error al generar EC');
                                    COMMIT;
                                    ELSE 
                                    update XXBOT.XXAR_CONTROL_NOTIFY_H h
                                      set h.attribute1=NULL,h.attribute2=NULL,H.confirmation='N',h.ERROR_CONFIRMATION='Error al generar EC'
                                      where 1=1
                                      and h.customer_id=cur.customer_id
                                      and h.request_id=v_request_id;
--                                      
--                                      update xxwebc.xxar_bots_tbl_cust_mails_cs cs
--                                    set cs.date_status=cs.date_status+1
--                                    where 1=1
--                                    and cs.CUSTOMER_ID=cur.customer_id;
                                    
                                      commit;
                                    end if;
                       end if;
                   END IF;
                   end loop;
                   end;
                   
-----HAGO VALIDACIÓN DE CADENAS STATUS "Segundo Aviso'
begin
for cur in (select distinct (b.customer_id),b.number_a,b.org_id,a.send_notice
                                from xxwebc.xxar_bots_tbl_cust_mails_cs A,xxbot.xxar_bots_edo_cta B,apps.AR_customers C
                                WHERE 1=1
--                                and C.attribute15 in ( SELECT meaning
--                                                            FROM apps.fnd_lookup_values_vl vl
--                                                            WHERE lookup_type = 'XXAR_LISTA_EJECUTIVOS_CT'
--                                                            AND SYSDATE BETWEEN start_date_active
--                                                            AND NVL (end_date_active,SYSDATE + 1))
                                and c.customer_id=b.customer_id
                                and a.customer_id=b.customer_id
                                AND a.STATUS='Segundo Aviso'
                                and to_date (a.date_status,'dd-mm-yyyy')<=to_date(sysdate-7,'dd-mm-yyyy')
                                AND b.BALANCE_DUE >1
                                    and b.org_id not in (select flex_value 
                                                               from APPS.XXGL_EMPRESAS_FUSIONADAS_VM)
                                AND b.DUE_DATE<TRUNC(SYSDATE-10)
                                AND (b.MESSAGE IS NULL or b.message='RESUELTO' or b.message='PROMESA DE PAGO' and to_date(scheduled_date,'dd-mm-yyyy')< to_date (sysdate,'dd-mm-yyyy'))
                                order by customer_id,org_id )
                   loop
                   v_valid_line:=0;
                           select count (*) into v_valid_line
                                   from XXBOT.XXAR_CONTROL_NOTIFY_H a
                                   where 1=1
                                   and a.REQUEST_ID=v_request_id
                                   and a.CONFIRMATION='N'
                                   and a.customer_id=cur.customer_id;
    IF v_valid_line=0
    THEN
                       --genero ec e inserto registro en tabla control 
                       v_GEN_EC:=0;
                       v_file:=null;
                       v_valid_line:=0;
                       XXBOT.XXAR_PAY_NOTIF_SYSTEM.XXAR_EC_GEN(cur.org_id,cur.customer_id,v_GEN_EC);
                       XXBOT.XXAR_PAY_NOTIF_SYSTEM.GEN_FILE_EDO_CTA(cur.number_a,cur.org_id,v_file);
                       if v_GEN_EC=1 and v_file is not null
                       then 
                                   select count (*) into v_valid_line
                                   from XXBOT.XXAR_CONTROL_NOTIFY_H a
                                   where 1=1
                                   and a.REQUEST_ID=v_request_id
                                   and a.customer_id=cur.customer_id;
                                    if v_valid_line=0
                                    then 
                                    insert into XXBOT.XXAR_CONTROL_NOTIFY_H (
                                    REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,attribute1,attribute2,attribute3,attribute4,status,send_notice,confirmation,error_confirmation) values 
                                    (v_request_id,cur.customer_id,cur.number_a,v_file,null,null,null,'Suspendido',cur.send_notice,null,null);
                                    
                                    update xxwebc.xxar_bots_tbl_cust_mails_cs cs
                                    set cs.status='Suspendido',cs.date_status=sysdate
                                    where 1=1
                                    and cs.CUSTOMER_ID=cur.customer_id;
                                    
                                    insert into XXBOT.XXAR_CONTROL_NOTIFY_D (select v_request_id,CUSTOMER_TRX_ID,number_b,DUE_DATE,CUSTOMER_ID,number_a,ORG_ID
                                                                from xxbot.xxar_bots_edo_cta B
                                                                WHERE 1=1
                                                                AND b.BALANCE_DUE >1
                                                                and b.org_id=cur.org_id
                                                                and b.customer_id=cur.customer_id
                                                                AND b.DUE_DATE<TRUNC(SYSDATE-10)
                                                                AND (b.MESSAGE IS NULL or b.message='RESUELTO' or b.message='PROMESA DE PAGO' and to_date(scheduled_date,'dd-mm-yyyy')< to_date (sysdate,'dd-mm-yyyy')));
                                                                
                                    
                                    insert into xxbot.status_warnings_hist
                                      (ID,REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,STATUS,CReATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATE_BY,PROCESO)
                                      values (XXBOT.AR_SEQ_STATUS_HIST_CT.NEXTVAL,V_REQUEST_ID,cur.customer_id,cur.number_a,'Suspendido',sysdate,v_user_id,sysdate,v_user_id,'GEN_AUT_ADV');
                                      commit; 
                                      else 
                                      update XXBOT.XXAR_CONTROL_NOTIFY_H h
                                      set h.attribute2=v_file
                                      where 1=1
                                      and h.customer_id=cur.customer_id
                                      and h.request_id=v_request_id;
                                      
                                      insert into XXBOT.XXAR_CONTROL_NOTIFY_D (select v_request_id,CUSTOMER_TRX_ID,number_b,DUE_DATE,CUSTOMER_ID,number_a,ORG_ID
                                                                from xxbot.xxar_bots_edo_cta B
                                                                WHERE 1=1
                                                                AND b.BALANCE_DUE >1
                                                                and b.org_id=cur.org_id
                                                                and b.customer_id=cur.customer_id
                                                                AND b.DUE_DATE<TRUNC(SYSDATE-10)
                                                                AND (b.MESSAGE IS NULL or b.message='RESUELTO' or b.message='PROMESA DE PAGO' and to_date(scheduled_date,'dd-mm-yyyy')< to_date (sysdate,'dd-mm-yyyy')));
                                                                
                                      commit;
                                      end if;
                    else 
                        select count (*) into v_valid_line
                                   from XXBOT.XXAR_CONTROL_NOTIFY_H a
                                   where 1=1
                                   and a.REQUEST_ID=v_request_id
                                   and a.customer_id=cur.customer_id;
                                    if v_valid_line=0 then
                                    
                                    insert into XXBOT.XXAR_CONTROL_NOTIFY_H (
                                    REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,attribute1,attribute2,attribute3,attribute4,status,send_notice,confirmation,error_confirmation) values 
                                    (v_request_id,cur.customer_id,cur.number_a,null,null,null,null,'Segundo Aviso',cur.send_notice,'N','Error al generar EC');
                                    COMMIT;
                                    ELSE 
                                    update XXBOT.XXAR_CONTROL_NOTIFY_H h
                                      set h.attribute1=NULL,h.attribute2=NULL,H.confirmation='N',h.ERROR_CONFIRMATION='Error al generar EC'
                                      where 1=1
                                      and h.customer_id=cur.customer_id
                                      and h.request_id=v_request_id;
--                                      
--                                      update xxwebc.xxar_bots_tbl_cust_mails_cs cs
--                                    set cs.date_status=cs.date_status+1
--                                    where 1=1
--                                    and cs.CUSTOMER_ID=cur.customer_id;
                                    
                                      commit;
                                    end if;
                       end if;
                   END IF;
                   end loop;
                   end;
                   
-----Mando los correos de Aviso a los clientes o al ejecutivo
begin
for cur in (select request_id,customer_id,customer_number,attribute1,attribute2,case when status='Primer Aviso' then 1
                                                                                     when status='Segundo Aviso' then 2
                                                                                     when status='Suspendido' then 3 end status,send_notice

                                from XXBOT.XXAR_CONTROL_NOTIFY_H
                                WHERE 1=1
                                and request_id=v_request_id)
                   loop
                   begin
                   XXBOT.XXAR_PAY_NOTIF_SYSTEM.XXAR_SEND_NOTIFICATION (cur.request_id,cur.customer_number,cur.status,cur.send_notice,cur.attribute1,cur.attribute2) ; 
                   exception when others then
                   apps.MESSAGE_LOG ('Error al enviar aviso: '||cur.status||' - de la cadena '||cur.customer_number||' regresa al status previo'); 
                   
                   UPDATE xxwebc.xxar_bots_tbl_cust_mails_cs cs
                   SET (status,date_status) = (SELECT case when status='Primer Aviso' then 'Activo'
                                                 when status='Segundo Aviso' then  'Primer Aviso'
                                                 when status='Suspendido' then 'Segundo Aviso' end status,sysdate-7
                         FROM XXBOT.XXAR_CONTROL_NOTIFY_H B
                              WHERE  1=1
                              and customer_id=cur.customer_id
                              and request_id=cur.request_id)
                              where 1=1
                              and cs.customer_id=cur.customer_id  ;
                              commit;
                   end;  
                   end loop;
                   end;
                   
                   ------Actualizo las cadenas de status "En Revisión"
--                   begin
--                   for cur in (select a.customer_id,a.status,cs.send_notice,cs.customer_number
--                                     from xxwebc.xxar_bots_tbl_cust_mails_cs cs,XXBOT.XXAR_CONTROL_NOTIFY_H a
--                                     where 1=1 
--                                     and a.customer_id=cs.customer_id
--                                     and a.request_id=v_request_id
--                                     and a.status='Suspendido'
--                                     and cs.send_notice='N')
--                    LOOP                 
--                   update xxwebc.xxar_bots_tbl_cust_mails_cs cs
--                   set status='En Revisión'
--                   where 1=1
--                   and status=cur.status
--                   and customer_id=cur.customer_id
--                   and cs.send_notice=cur.send_notice;
--                   
--                   insert into xxbot.status_warnings_hist
--                                      (ID,REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,STATUS,CReATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATE_BY,PROCESO)
--                                      values (XXBOT.AR_SEQ_STATUS_HIST_CT.NEXTVAL,V_REQUEST_ID,cur.customer_id,cur.customer_number,'En Revisión',sysdate,v_user_id,sysdate,v_user_id,'GEN_AUT_ADV');
--                                      commit;
--                                      end loop;
--                                      end;

	 
												
																				
																					   
	
----------------------GENERO TICKETS 
   begin
   V_GEN_TICKET_C:=0;
   SELECT COUNT (*) INTO V_GEN_TICKET_C
                FROM xxwebc.xxar_bots_tbl_cust_mails_cs
                WHERE 1=1
                AND SEND_NOTICE='Y'
                AND CUSTOMER_ID IN (
                                        SELECT CUSTOMER_ID 
                                      FROM xxbot.status_warnings_hist
                                      WHERE 1=1
                                      AND REQUEST_ID=V_REQUEST_ID
                                      AND STATUS='Suspendido');
    IF V_GEN_TICKET_C>0
    THEN 
    apps.MESSAGE_LOG ('Entra a generar Tickets');
    XXAR_CREATE_TICKETS (v_request_id,v_exit_create_tk);
    apps.MESSAGE_LOG ('Proceso de generación automática de tickets concluyó- '||v_exit_notif);
    DBMS_OUTPUT.PUT_LINE('Proceso de generación automática de tickets concluyó- '||v_exit_notif);
    else 
    apps.MESSAGE_LOG ('No hay cadenas para desactivar');
    end if;
     end;
     
     ---envío notificaciones
begin
XXAR_SEND_NOT_COORD (v_request_id,v_exit_notif);
apps.MESSAGE_LOG ('Proceso de envió de logs concluyó de forma- '||v_exit_notif);
    DBMS_OUTPUT.PUT_LINE('Proceso de envió de logs concluyó de forma- '||v_exit_notif);
end;


    end;
    procedure  XXAR_UPD_STATUS (errbuf out varchar2,retcode out number)
    IS 
    v_GEN_EC number;
    V_COUNT_NOT_PAY NUMBER;
    v_request_id number;
    V_USER_ID number;
    v_status_valid varchar2 (100);
    v_EXIT varchar2 (400);
    
    begin
    ------IDENTIFICO LOS CLIENTES A VALIDAR
    select nvl(fnd_global.conc_request_id,to_char(sysdate,'YYYYMMDDHH24MISS')),nvl(fnd_global.user_id,-1)
                                into v_request_id ,V_USER_ID 
                                from dual;
    
         BEGIN 

        for cur in ( select a.customer_id,a.customer_number,B.status
                            from apps.AR_customers a,xxwebc.xxar_bots_tbl_cust_mails_cs b
                            where 1=1
--                            and a.attribute15 in ( SELECT meaning
--                                                            FROM apps.fnd_lookup_values_vl vl
--                                                            WHERE lookup_type = 'XXAR_LISTA_EJECUTIVOS_CT'
--                                                            AND SYSDATE BETWEEN start_date_active
--                                                            AND NVL (end_date_active,SYSDATE + 1))
                            and a.customer_id=b.customer_id
                            AND B.STATUS ='Suspendido'
                            )
                              
                            loop
                            V_COUNT_NOT_PAY:=0;
                            v_status_valid:=null;
                            
                           select COUNT (*) INTO V_COUNT_NOT_PAY
                                from xxbot.xxar_bots_edo_cta ec
                                    WHERE 1=1
                                AND EC.BALANCE_DUE >1
                                and org_id not in (select flex_value 
                                                           from APPS.XXGL_EMPRESAS_FUSIONADAS_VM)
                                and EC.customer_id=cur.customer_id
                                AND EC.DUE_DATE<TRUNC(SYSDATE-10)
                                AND (ec.MESSAGE IS NULL or ec.message='RESUELTO' or ec.message='PROMESA DE PAGO' and to_date(scheduled_date,'dd-mm-yyyy')< to_date (sysdate,'dd-mm-yyyy'));
                          
                           IF V_COUNT_NOT_PAY=0
                           THEN 
--                               SELECT STATUS into v_status_valid
--                                      FROM xxwebc.xxar_bots_tbl_cust_mails_cs
--                                      WHERE 1=1
--                                      AND CUSTOMER_ID=cur.customer_id;
--                                      
--                                      if v_status_valid='Suspendido'
--                                      then 
--                                      update xxwebc.xxar_bots_tbl_cust_mails_cs
--                                      set status='Por Reactivar'
--                                      ,date_status=sysdate
--                                      where 1=1
--                                      and customer_id=cur.customer_id;
--                                      
--                                      insert into xxbot.status_warnings_hist
--                                      (ID,REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,STATUS,CReATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATE_BY,PROCESO)
--                                      values (XXBOT.AR_SEQ_STATUS_HIST_CT.NEXTVAL,V_REQUEST_ID,cur.customer_id,cur.customer_number,'Por Reactivar',sysdate,v_user_id,sysdate,v_user_id,'VAL_ACT_STS');
--                                      commit;
--                                      else

                                      update xxwebc.xxar_bots_tbl_cust_mails_cs
                                      set uo=status
                                      where 1=1
                                      and customer_id=cur.customer_id;
                                      commit;
                                      update xxwebc.xxar_bots_tbl_cust_mails_cs
                                      set status='Activo'
                                      ,date_status=sysdate
                                      where 1=1
                                      and customer_id=cur.customer_id;
                                      commit;
                                      
                                      insert into xxbot.status_warnings_hist
                                      (ID,REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,STATUS,CReATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATE_BY,PROCESO)
                                      values (XXBOT.AR_SEQ_STATUS_HIST_CT.NEXTVAL,V_REQUEST_ID,cur.customer_id,cur.customer_number,'Activo',sysdate,v_user_id,sysdate,v_user_id,'VAL_ACT_STS');
                                      commit; 
                                      end if;
                           --END IF;
                           END LOOP;
        END;
        commit;
        ---- genero el log de documentos 
        XXAR_LOG_INT_STATUS_NOT (V_REQUEST_ID,v_EXIT);
        
        IF v_EXIT='Correcto'
        then 
        apps.MESSAGE_LOG ('Generó log de forma correcta y se envió por correo');
        DBMS_OUTPUT.PUT_LINE('Generó log de forma correcta y se envió por correo');
        end if;
        --proceso las que estan en otro estatus
        
        BEGIN 

        for cur in ( select a.customer_id,a.customer_number,B.status
                            from apps.aR_customers a,xxwebc.xxar_bots_tbl_cust_mails_cs b
                            where 1=1
--                            and a.attribute15 in ( SELECT meaning
--                                                            FROM apps.fnd_lookup_values_vl vl
--                                                            WHERE lookup_type = 'XXAR_LISTA_EJECUTIVOS_CT'
--                                                            AND SYSDATE BETWEEN start_date_active
--                                                            AND NVL (end_date_active,SYSDATE + 1))
                            and a.customer_id=b.customer_id
                            AND B.STATUS in ('Primer Aviso','Segundo Aviso')
                            )
                              
                            loop
                            V_COUNT_NOT_PAY:=0;
                            v_status_valid:=null;
                            
                           select COUNT (*) INTO V_COUNT_NOT_PAY
                                from xxbot.xxar_bots_edo_cta ec
                                    WHERE 1=1
                                AND EC.BALANCE_DUE >1
                                and org_id not in (select flex_value 
                                                           from APPS.XXGL_EMPRESAS_FUSIONADAS_VM)
                                and EC.customer_id=cur.customer_id
                                AND EC.DUE_DATE<TRUNC(SYSDATE-10)
                                AND (ec.MESSAGE IS NULL or ec.message='RESUELTO' or ec.message='PROMESA DE PAGO' and to_date(scheduled_date,'dd-mm-yyyy')< to_date (sysdate,'dd-mm-yyyy'));
                          
                           IF V_COUNT_NOT_PAY=0
                           THEN 
                               
                                      update xxwebc.xxar_bots_tbl_cust_mails_cs
                                      set uo=status
                                      where 1=1
                                      and customer_id=cur.customer_id;
                                      commit;
                                      update xxwebc.xxar_bots_tbl_cust_mails_cs
                                      set status='Activo'
                                      ,date_status=sysdate
                                      where 1=1
                                      and customer_id=cur.customer_id;
                                      commit;
                                      
                                      insert into xxbot.status_warnings_hist
                                      (ID,REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,STATUS,CReATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATE_BY,PROCESO)
                                      values (XXBOT.AR_SEQ_STATUS_HIST_CT.NEXTVAL,V_REQUEST_ID,cur.customer_id,cur.customer_number,'Activo',sysdate,v_user_id,sysdate,v_user_id,'VAL_ACT_STS');
                                      commit; 
                                      end if;
                           END LOOP;
        END;
    apps.MESSAGE_LOG ('Proceso concluyó de Forma correcta');
    DBMS_OUTPUT.PUT_LINE('Proceso concluyó de Forma correcta');    
        
        
   EXCEPTION
    WHEN OTHERS
    THEN
    apps.MESSAGE_LOG ('ERROR- Ocurrió un error al ejecutar el proceso de Actualización de Estatus)- '||SQLERRM||CHR(10));
    DBMS_OUTPUT.PUT_LINE('ERROR- Ocurrió un error al ejecutar el proceso de Actualización de Estatus)- '||SQLERRM||CHR(10));
        
    
    END;
    
 procedure  XXAR_EC_GEN (P_ORG_ID IN number,P_CUSTOMER_ID IN NUMBER,P_GEN_EC OUT NUMBER)
IS 

 V_COUNT NUMBER ;
 begin
         
       
        begin
        apps.mo_global.set_policy_context('S', P_ORG_ID);
        DBMS_OUTPUT.PUT_LINE('OK_cias '||P_ORG_ID);
        exception 
        when others 
        then 
        apps.mo_global.set_policy_context('S', P_ORG_ID);
        DBMS_OUTPUT.PUT_LINE(' no OK_cias '||P_ORG_ID);
        end ;
        
        begin
        EXECUTE IMMEDIATE
                     'ALTER SESSION SET NLS_LANGUAGE =  "AMERICAN" ';
                     DBMS_OUTPUT.PUT_LINE('OK');
        EXCEPTION WHEN OTHERS 
        THEN 
        DBMS_OUTPUT.PUT_LINE('FALLA '||SQLERRM);
        
        end;
        
        begin
        delete XXBOT.XXAR_EC_NOT_TT;
        commit;
        end;
        
        
        INSERT INTO  XXBOT.XXAR_EC_NOT_TT
        WITH q_setup as
                (SELECT sob.name   Company_Name,
                          sob.chart_of_accounts_id   coa_id,
                          sob.currency_code   Functional_Currency,
                          cur.precision      Functional_Currency_Precision
                FROM    apps.gl_sets_of_books sob,
                              apps.AR_SYSTEM_PARAMETERS param,
                              apps.fnd_currencies cur
                WHERE  sob.set_of_books_id = param.set_of_books_id
                AND       sob.currency_code = cur.currency_code)
        ,q_main as
            (SELECT status.meaning status,
                       SUBSTRB (party.party_name, 1, 50) Name,
                       cust_acct.account_number Number_A,
                       cust_acct.cust_account_id Customer_Id,
                       NVL (cp_site.collector_id, cp_cust.collector_id) Collector_Id,
                       col.name Collector,
                       cust_acct.ATTRIBUTE15 Agent_name,
                       site_uses.site_use_id cp_site_use_id,
                       site_uses.location location
                       ,cust_acct.ATTRIBUTE15
                       --,cte.type_process  type_process
                  FROM apps.ar_lookups status,
                       apps.ar_collectors col,
                       apps.hz_customer_profiles cp_cust,
                       apps.hz_customer_profiles cp_site,
                       apps.hz_cust_accounts cust_acct,
                       apps.hz_parties party,
                       apps.hz_cust_site_uses site_uses,
                       apps.hz_cust_acct_sites acct_site
                       ,apps.xxar_bots_tbl_customers_mails cte
                 WHERE 1=1
                    --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                    and acct_site.cust_account_id = cust_acct.cust_account_id
                        AND cust_acct.cust_account_id  = P_CUSTOMER_ID                              
                       AND cust_acct.party_id = party.party_id
                       AND site_uses.cust_acct_site_id = acct_site.cust_acct_site_id
                       AND site_uses.site_use_code = 'BILL_TO'
                       AND cp_site.site_use_id(+) = site_uses.site_use_id
                       AND cp_cust.cust_account_id = cust_acct.cust_account_id
                       AND cp_cust.site_use_id IS NULL
                       AND col.collector_id =
                              NVL (cp_site.collector_id, cp_cust.collector_id)
                       AND DECODE (cp_site.collector_id,
                                   NULL, cp_cust.account_status,
                                   cp_site.account_status) = status.lookup_code
                       AND status.lookup_type = 'ACCOUNT_STATUS'
                       AND EXISTS
                              (SELECT 'x'
                                 FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
                                WHERE (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
                                      AND ps.customer_id = cust_acct.cust_account_id
                                      AND ps.customer_site_use_id = site_uses.site_use_id)
                UNION
                SELECT status.meaning status,
                       SUBSTRB (party.party_name, 1, 50) Name,
                       cust_acct.account_number Number_A,
                       cust_acct.cust_account_id Customer_Id,
                       NVL (cp_site.collector_id, cp_cust.collector_id) Collector_Id,
                       col.name Collector,
                       cust_acct.ATTRIBUTE15 Agent_name,
                       site_uses.site_use_id cp_site_use_id,
                       site_uses.location location
                       ,cust_acct.ATTRIBUTE15
                      -- ,cte.type_process type_process
                  FROM apps.ar_lookups status,
                       apps.ar_collectors col,
                       apps.hz_customer_profiles cp_cust,
                       apps.hz_customer_profiles cp_site,
                       apps.hz_cust_accounts cust_acct,
                       apps.hz_parties party,
                       apps.hz_cust_site_uses site_uses,
                       apps.hz_cust_acct_sites acct_site
                       ,apps.xxar_bots_tbl_customers_mails cte
                 WHERE 1=1
                    --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                    and acct_site.cust_account_id = cust_acct.cust_account_id
                        AND cust_acct.cust_account_id  = P_CUSTOMER_ID
                       AND cust_acct.party_id = party.party_id
                       AND site_uses.cust_acct_site_id = acct_site.cust_acct_site_id
                       AND site_uses.site_use_code = 'BILL_TO'
                       AND cp_site.site_use_id(+) = site_uses.site_use_id
                       AND cp_cust.cust_account_id = cust_acct.cust_account_id
                       AND cp_cust.site_use_id IS NULL
                       AND col.collector_id =
                              NVL (cp_site.collector_id, cp_cust.collector_id)
                       AND cp_site.collector_id IS NULL
                       AND cp_cust.account_status = status.lookup_code(+)
                       AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
                      AND EXISTS
                              (SELECT 'x'
                                 FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
                                WHERE      (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
                                      AND ps.customer_id = cust_acct.cust_account_id
                                      AND ps.customer_site_use_id = site_uses.site_use_id)
                UNION
                SELECT status.meaning status,
                       SUBSTRB (party.party_name, 1, 50) Name,
                       cust_acct.account_number Number_A,
                       cust_acct.cust_account_id Customer_Id,
                       NVL (cp_site.collector_id, cp_cust.collector_id) Collector_Id,
                       col.name Collector,
                       cust_acct.ATTRIBUTE15 Agent_name,
                       site_uses.site_use_id cp_site_use_id,
                       site_uses.location location
                       ,cust_acct.ATTRIBUTE15
                      -- ,cte.type_process
                  FROM apps.ar_lookups status,
                       apps.ar_collectors col,
                       apps.hz_customer_profiles cp_cust,
                       apps.hz_customer_profiles cp_site,
                       apps.hz_cust_accounts cust_acct,
                       apps.hz_parties party,
                       apps.hz_cust_site_uses site_uses,
                       apps.hz_cust_acct_sites acct_site
                       ,apps.xxar_bots_tbl_customers_mails cte
                 WHERE 1=1
                    --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                    and acct_site.cust_account_id = cust_acct.cust_account_id
                        AND cust_acct.cust_account_id  = P_CUSTOMER_ID
                       AND cust_acct.party_id = party.party_id
                       AND site_uses.cust_acct_site_id = acct_site.cust_acct_site_id
                       AND site_uses.site_use_code = 'BILL_TO'
                       AND cp_site.site_use_id(+) = site_uses.site_use_id
                       AND cp_cust.cust_account_id = cust_acct.cust_account_id
                       AND cp_cust.site_use_id IS NULL
                       AND col.collector_id =
                              NVL (cp_site.collector_id, cp_cust.collector_id)
                       AND cp_site.collector_id IS NOT NULL
                       AND cp_site.account_status = status.lookup_code(+)
                       AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
                       AND EXISTS
                              (SELECT 'x'
                                 FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
                                WHERE      (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
                                      AND ps.customer_id = cust_acct.cust_account_id
                                      AND ps.customer_site_use_id = site_uses.site_use_id)
                UNION
                SELECT status.meaning,
                       SUBSTRB (party.party_name, 1, 50),
                       cust_acct.account_number,
                       cust_acct.cust_account_id,
                       col.collector_id,
                       col.name,
                       cust_acct.ATTRIBUTE15 Agent_name,
                       DECODE ('Customer', NULL, 0, -88888),
                       TO_CHAR (NULL)
                       ,cust_acct.ATTRIBUTE15
                      -- ,cte.type_process
                  FROM apps.ar_lookups status,
                       apps.ar_collectors col,
                       apps.hz_customer_profiles cp_cust,
                       apps.hz_cust_accounts cust_acct,
                       apps.hz_parties party
                       ,apps.xxar_bots_tbl_customers_mails cte
                 WHERE 1=1
                    --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                    and cp_cust.cust_account_id = cust_acct.cust_account_id
                        AND cust_acct.cust_account_id  = P_CUSTOMER_ID
                       AND cust_acct.party_id = party.party_id
                       AND cp_cust.site_use_id IS NULL
                       AND cp_cust.collector_id = col.collector_id
                       AND cp_cust.account_status = status.lookup_code(+)
                       AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
                       AND EXISTS
                              (SELECT 'x'
                                 FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
                                WHERE   (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
                                      AND ps.customer_id = cust_acct.cust_account_id
                                      AND ps.customer_site_use_id IS NULL)
                    )

        SELECT distinct (ps.CUSTOMER_TRX_ID),
                rct.purchase_order,
                ps.trx_number Number_B,
                REPLACE(SUBSTR (DECODE (ctt.cust_trx_type_id, NULL, l.meaning, ctt.name),
                 -4,
                 4), '-', ' ')
                TYPE,
                ps.trx_date Trx_Date,
                ps.gl_date Gl_Date,
                ps.due_date Due_Date,
                ps.invoice_currency_code Currency_B,
                DECODE (
                ps.invoice_currency_code,
                s.Functional_Currency, ps.amount_due_original,
                DECODE (
                curr.minimum_accountable_unit,
                NULL, ROUND (ps.amount_due_original * ps.exchange_rate,
                            curr.precision),
                ROUND (
                    ps.amount_due_original
                  * ps.exchange_rate
                  / curr.minimum_accountable_unit)
               * curr.minimum_accountable_unit))
                Original_Amount,
                 ps.acctd_amount_due_remaining Balance_Due,
                 logr.uuid,
                 logr.estatus,
                 logr.DESCRIPCION_ESTATUS,
                 logr.ACCESO_DOCTO,
                 logr.url,
                 DECODE(null,null,'1',ctt.NAME) orden,
                 rct.attribute7 remision,
                 rct.attribute8 no_recibo,
                 case
                 WHEN  instr(rct.attribute9,'JAN') > 0 THEN replace(rct.attribute9,'JAN','ENE')
                 WHEN  instr(rct.attribute9,'APR') > 0 THEN replace(rct.attribute9,'APR','ABR')
                 WHEN  instr(rct.attribute9,'AUG') > 0 THEN replace(rct.attribute9,'AUG','AGO')
                 WHEN  instr(rct.attribute9,'DEC') > 0 THEN replace(rct.attribute9,'DEC','DIC')
                 ELSE rct.attribute9
                 end fecha_recibo,
                 rct.attribute12 tipo,
                 c.cm_addr referencia_direccion,
                 m.customer_id,
                 m.Agent_name ejecutivo,
                 m.COLLECTOR_ID,
                 m.Collector,
                 m.location,
                 m.name,
                 m.number_a,
                 m.CP_SITE_USE_ID
                  ,RCT.ORG_ID 
                  ,units.name
                  ,rct.ATTRIBUTE6
                  ,(
                            select B.STATUS_DESC
                            from xx_apex.XXAR_GRPCBZ_DCOMM_TBL@OCIPROD_TO_ORAPROD19 a,xx_apex.XXAR_GRPCBZ_STATUS_TBL@OCIPROD_TO_ORAPROD19 b
                            where 1=1
                            and b.source_type='D'
                            and a.status=b.status
                            AND ps.CUSTOMER_TRX_ID=A.CUSTOMER_TRX_ID) AS MENSAJE
                   ,(SELECT TRUNC(SYSDATE)- (ps.due_date) AS DAYS FROM DUAL) AS DAYS_DELAY 
                   ,c.nombre_site as direccion_envio
    FROM apps.ar_lookups l,
         apps.ra_cust_trx_types ctt,
         ar.cust_ar_factelec_log logr,
         apps.ra_customer_trx_all rct,
         apps.AR_PAYMENT_SCHEDULES_ALL ps,
         ar.ar_dispute_history dh,        
         apps.fnd_currencies curr
         ,q_setup s
         ,q_main m
         ,apps.cm_mstr c
         ,apps.hr_all_organization_units units
   WHERE 1=1
   and units.attribute15 is not null
   and units.organization_id=ps.ORG_ID
   and ps.class = l.lookup_code(+) AND l.lookup_type(+) = 'INV/CM'
   AND ps.payment_schedule_id=dh.payment_schedule_id(+)
   AND ps.gl_date<=sysdate
   AND ps.gl_date_closed>sysdate
   AND sysdate>=NVL(dh.start_date(+),sysdate)
                AND sysdate<NVL(dh.end_date(+),sysdate+1)
         AND ps.cust_trx_type_id = ctt.cust_trx_type_id(+)
         AND logr.NUMERO_DOCTO(+) = ps.trx_number
         AND logr.ORG_ID (+) = ps.ORG_ID
         AND rct.customer_trx_id = ps.customer_trx_id
         AND ps.status || '' = 'OP'
         AND abs(ps.amount_due_remaining) >= 1.00
         AND ps.customer_id = m.customer_id
         AND curr.currency_code = s.Functional_Currency
         and rct.org_id =c.org_id(+)
         and rct.SHIP_TO_CUSTOMER_ID = c.customer_id (+)
         and rct.SHIP_TO_SITE_USE_ID = c.site_use_id (+);
         commit;
         
         select count (*) into V_COUNT
         from XXBOT.XXAR_EC_NOT_TT
         where 1=1;
         
         if V_COUNT>=1
         then P_GEN_EC:=1;
         else P_GEN_EC:=0;
         end if;
         commit;
    EXCEPTION
    WHEN OTHERS
    THEN
    apps.MESSAGE_LOG ('ERR - EXC EN PROCESO DE ESTADO DE CUENTA '||SQLERRM||CHR(10));
    DBMS_OUTPUT.PUT_LINE('ERR - EXC EN PROCESO DE ESTADO DE CUENTA '||SQLERRM);
    --return false;
    END;

    PROCEDURE GEN_FILE_EDO_CTA( P_CADENA IN varchar2,P_ORG_ID IN number,P_FILE_NAME OUT VARCHAR2)
    AS
       
        gv_dir               VARCHAR (50) := 'CUST_AR_BOTS';
        v_file_name          VARCHAR2 (3000);
        v_worksheet_a VARCHAR2 (1000);
        ra                    NUMBER;
        --v_EstiloCabColumna   VARCHAR2 (100);
        V_estilo_celda       VARCHAR2 (100);
        --v_body               VARCHAR2 (4000);
        --V_FN              VARCHAR2(4000);
        V_UOP   NUMBER;
        v_COMPANY_NAME VARCHAR2(100);
        V_EJECUTIVO VARCHAR2(100);
        V_CLIENTE VARCHAR2(100);
        V_LOCALIDAD VARCHAR2(100);
        V_COBRADOR VARCHAR2(100);
        v_sum_orig_amount number;
        v_sum_balance_due number;
        V_USER_ID number;
        V_COUNT_FILE NUMBER;
        
        
        
        BEGIN
        
                        begin
                        EXECUTE IMMEDIATE
                        'ALTER SESSION SET NLS_LANGUAGE =  "latin american spanish" ';
                        DBMS_OUTPUT.PUT_LINE('OK');
                        EXCEPTION WHEN OTHERS 
                        THEN 
                        DBMS_OUTPUT.PUT_LINE('FALLA EN SETEO DE LENGUAJE'||SQLERRM);
                        end;
        
       
        
        V_USER_ID := NVL( FND_GLOBAL.USER_ID,0);
        
        
                            begin 
                                if P_org_id=180
                                then V_UOP :=204;
                                     v_worksheet_a:= 'IRSA';
                                elsif P_org_id=84
                                then
                                     V_UOP:=209;
                                     v_worksheet_a:= 'BEPUSA';
                                     else
                                     V_UOP:=202;
                                     v_worksheet_a:= 'CME';
                                end if;
                            end;
                            
                          
                           
        v_file_name :=
               V_UOP
            ||'-'
            ||P_CADENA
            ||'-'
            || TO_CHAR (SYSDATE, 'DDMMYYYY')
            || '.xls';

        -- Se crea el excel
        apps.gen_xl_xml.create_excel (gv_dir, v_file_name);

        --Stylos

       
        apps.gen_xl_xml.create_style ('titulo_pestana',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_bold      => true,
                                 --p_underline => 'Y',
                                 p_backcolor   => '#e7f3fd',
                                 p_border      => 'Y');--'LightBlue'  ); --'#3366FF');
                                 
        apps.gen_xl_xml.create_style ('texto_celda',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_bold      => TRUE);

        apps.gen_xl_xml.create_style ('texto_celda2',
                                 'Calibri',
                                 'Black',
                                 11);
                                 
        apps.gen_xl_xml.create_style ('texto_celda3',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_bold      => TRUE,
                                 p_border      => 'Y');
                                 
        apps.gen_xl_xml.create_style ('texto_celda4',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_border      => 'Y');
                                 
        apps.gen_xl_xml.create_style ('num_celda',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_border      => 'Y',
                                 p_formato_numero   => '3');
        
        
        
        apps.gen_xl_xml.create_worksheet_nogrid (v_worksheet_a);
        -- Tamaño de columna
        apps.gen_xl_xml.set_column_width (1,90, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (2, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (3, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (4, 90, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (5, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (6, 90, v_worksheet_a);
        --nuevas lineas
        apps.gen_xl_xml.set_column_width (7, 100, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (8, 90, v_worksheet_a);
        --
        apps.gen_xl_xml.set_column_width (9, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (10, 40, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (11, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (12, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (13, 90, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (14, 40, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (15, 170, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (16, 100, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (17, 90, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (18, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (19, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (20, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (21, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (22, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (23, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (24, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (25, 70, v_worksheet_a);
        apps.gen_xl_xml.set_row_height (8, 20, v_worksheet_a);
        
        select 
                     DISTINCT (company_name)
                    ,ejecutivo
                    ,TO_CHAR(number_a)||' '||name
                    ,location
                    ,collector INTO v_COMPANY_NAME,V_EJECUTIVO,V_CLIENTE,V_LOCALIDAD,V_COBRADOR
                    from XXBOT.XXAR_EC_NOT_TT a
                    where 1=1
                    and a.org_id=P_ORG_ID
                    and abs(a.balance_due)>=1.0
                    and a.number_a=P_CADENA
                    and rownum =1;
                    --order by due_date asc

        --r := 1;
        ra := 1;
        APPS.gen_xl_xml.write_cell_CHAR (ra,
                                    8,
                                    v_worksheet_a,
                                    'Informe Estado Cuenta (CUSTOM)',
                                    'texto_celda2');
                                    
        ra := ra + 1;
                                    
        APPS.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'ORACLE GEPP',
                                    'texto_celda');
               
        
                                    
        ra := ra + 1;                            

        APPS.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'Unidad Operativa:',
                                    'texto_celda');
                                    
        APPS.gen_xl_xml.write_cell_CHAR (ra,
                                    2,
                                    v_worksheet_a,
                                    v_COMPANY_NAME,
                                    'texto_celda2');
                                    
        ra := ra + 1;                            

        APPS.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'Ejecutivo:',
                                    'texto_celda');
                                    
        APPS.gen_xl_xml.write_cell_CHAR (ra,
                                    2,
                                    v_worksheet_a,
                                    v_ejecutivo,
                                    'texto_celda2');
                                    
        ra := ra + 1;                            

        APPS.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'Cliente:',
                                    'texto_celda');
                                    
        APPS.gen_xl_xml.write_cell_CHAR (ra,
                                    2,
                                    v_worksheet_a,
                                    v_cliente,
                                    'texto_celda2');
                                    
        ra := ra + 1;                            

        APPS.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'Localidad:',
                                    'texto_celda');
                                    
        APPS.gen_xl_xml.write_cell_CHAR (ra,
                                    2,
                                    v_worksheet_a,
                                    v_localidad,
                                    'texto_celda2');
                                    
        ra := ra + 1;                            

        APPS.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'Cobrador:',
                                    'texto_celda');
                                    
        APPS.gen_xl_xml.write_cell_CHAR (ra,
                                    2,
                                    v_worksheet_a,
                                    v_cobrador,
                                    'texto_celda2');
                                    
                                    
                                    

        ra := ra + 1;

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'Numero Factura',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    2,
                                    v_worksheet_a,
                                    'Numero Unico',
                                    'titulo_pestana');
                                    
        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    3,
                                    v_worksheet_a,
                                    'No. Editado',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    4,
                                    v_worksheet_a,
                                    'Remision',
                                    'titulo_pestana');
        
        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    5,
                                    v_worksheet_a,
                                    'No. de Recibo',
                                    'titulo_pestana');
                                    
        apps.gen_xl_xml.write_cell_CHAR (ra,
                                   6,
                                    v_worksheet_a,
                                    'Orden de Compra',
                                    'titulo_pestana');
-----------------nuevos campos 
apps.gen_xl_xml.write_cell_CHAR (ra,
                                   7,
                                    v_worksheet_a,
                                    'Referencia Direccion',
                                    'titulo_pestana');

apps.gen_xl_xml.write_cell_CHAR (ra,
                                   8,
                                    v_worksheet_a,
                                    'Direccion Envio',
                                    'titulo_pestana');


                                    
       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    9,
                                    v_worksheet_a,
                                    'Fecha Recibo',
                                    'titulo_pestana');
                                    
       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    10,
                                    v_worksheet_a,
                                    'Tipo',
                                    'titulo_pestana');                             

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    11,
                                    v_worksheet_a,
                                    'Fecha Documento',
                                    'titulo_pestana');
                                    
       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    12,
                                    v_worksheet_a,
                                    'Fecha Contable',
                                    'titulo_pestana');
                                    
       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    13,
                                    v_worksheet_a,
                                    'Fecha Vencimiento',
                                    'titulo_pestana');
                                    
       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    14,
                                    v_worksheet_a,
                                    'Divisa',
                                    'titulo_pestana');
                                    
       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    15,
                                    v_worksheet_a,
                                    'UUID',
                                    'titulo_pestana');
                                 
       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    16,
                                    v_worksheet_a,
                                    'Estatus',
                                    'titulo_pestana');
                                    
       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    17,
                                    v_worksheet_a,
                                    'Descripcion Estatus',
                                    'titulo_pestana');
      
apps.gen_xl_xml.write_cell_CHAR (ra,
                                    18,
                                    v_worksheet_a,
                                    'Comentario',
                                    'titulo_pestana');
                                    
      apps.gen_xl_xml.write_cell_CHAR (ra,
                                    19,
                                    v_worksheet_a,
                                    'Fecha Estatus',
                                    'titulo_pestana');
                                    
      apps.gen_xl_xml.write_cell_CHAR (ra,
                                    20,
                                    v_worksheet_a,
                                    'Importe Original',
                                    'titulo_pestana');
                                    
     apps.gen_xl_xml.write_cell_CHAR (ra,
                                    21,
                                    v_worksheet_a,
                                    'Saldo Debido',
                                    'titulo_pestana');
                                    
     apps.gen_xl_xml.write_cell_CHAR (ra,
                                    22,
                                    v_worksheet_a,
                                    'Importe Pago',
                                    'titulo_pestana');
                                    
                                    
                                    
                                    
        FOR CUR
            IN (
                    select 
                     number_b
                    ,customer_trx_id
                    ,NO_EDITADO
                    ,remision
                    ,no_recibo
                    ,purchase_order
                    ,fecha_recibo
                    ,type
                    ,trx_date
                    ,gl_date
                    ,due_date
                    ,currency_b
                    ,uuid
                    ,estatus
                    ,descripcion_estatus
                    ,acceso_docto
                    ,original_amount
                    ,balance_due
                    ,message
                    ,referencia_direccion
                    ,direccion_envio
                    from XXBOT.XXAR_EC_NOT_TT a
                    WHERE 1=1
                    and a.number_a=P_CADENA
                    and a.org_id=P_ORG_ID
                    order by due_date asc
                            )
        LOOP
            ra := ra + 1;

            

            
                                        
            apps.gen_xl_xml.write_cell_CHAR (ra,
                                        1,
                                        v_worksheet_a,
                                        CUR.number_b,
                                        'texto_celda4');
                                        
           apps.gen_xl_xml.write_cell_NUM (ra,
                                        2,
                                        v_worksheet_a,
                                        CUR.customer_trx_id,
                                        'texto_celda4');
            
            apps.gen_xl_xml.write_cell_CHAR (ra,
                                        3,
                                        v_worksheet_a,
                                        CUR.NO_EDITADO,
                                        'texto_celda4');
 
                  apps.gen_xl_xml.write_cell_CHAR (ra,
                                        4,
                                        v_worksheet_a,
                                        CUR.remision,
                                        'texto_celda4');
                                        
                                        --
                                        BEGIN
                                        
                        apps.gen_xl_xml.write_cell_NUM (ra,
                                        5,
                                        v_worksheet_a,
                                        TO_NUMBER(CUR.no_recibo),
                                        'texto_celda4');
                  EXCEPTION 
                  WHEN OTHERS 
                  THEN 
                  apps.gen_xl_xml.write_cell_CHAR (ra,
                                        5,
                                        v_worksheet_a,
                                        CUR.no_recibo,
                                        'texto_celda4');
                  END;
                                        --
                                        
--           apps.gen_xl_xml.write_cell_CHAR (ra,
--                                        5,
--                                        v_worksheet_a,
--                                        CUR.no_recibo,
--                                        'texto_celda4');
                                        
                                        --
                                        BEGIN
                                        
                        apps.gen_xl_xml.write_cell_NUM (ra,
                                        6,
                                        v_worksheet_a,
                                        TO_NUMBER(CUR.purchase_order),
                                        'texto_celda4');
                  EXCEPTION 
                  WHEN OTHERS 
                  THEN 
                  apps.gen_xl_xml.write_cell_CHAR (ra,
                                        6,
                                        v_worksheet_a,
                                        CUR.purchase_order,
                                        'texto_celda4');
                  END;
-------------------nuevos campos 
                BEGIN
                                                        
                                        apps.gen_xl_xml.write_cell_NUM (ra,
                                                        7,
                                                        v_worksheet_a,
                                                        TO_NUMBER(CUR.referencia_direccion),
                                                        'texto_celda4');
                                  EXCEPTION 
                                  WHEN OTHERS 
                                  THEN 

                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                                        7,
                                                        v_worksheet_a,
                                                        CUR.referencia_direccion,
                                                        'texto_celda4');
                                                        end;
 apps.gen_xl_xml.write_cell_CHAR (ra,
                                        8,
                                        v_worksheet_a,
                                        CUR.direccion_envio,
                                        'texto_celda4');


                                        
           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        9,
                                        v_worksheet_a,
                                        CUR.fecha_recibo,
                                        'texto_celda4');
                                        
           BEGIN
                                        
                        apps.gen_xl_xml.write_cell_NUM (ra,
                                        10,
                                        v_worksheet_a,
                                        TO_NUMBER(CUR.type),
                                        'texto_celda4');
                  EXCEPTION 
                  WHEN OTHERS 
                  THEN 
                  apps.gen_xl_xml.write_cell_CHAR (ra,
                                        10,
                                        v_worksheet_a,
                                        CUR.type,
                                        'texto_celda4');
                  END;
                                        
           
                                        
           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        11,
                                        v_worksheet_a,
                                        TO_CHAR(CUR.trx_date,'DD-MON-YYYY'),
                                        'texto_celda4');
                                        
           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        12,
                                        v_worksheet_a,
                                        TO_CHAR(CUR.gl_date,'DD-MON-YYYY'),
                                        'texto_celda4');
                                        
           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        13,
                                        v_worksheet_a,
                                        TO_CHAR(CUR.due_date,'DD-MON-YYYY'),
                                        'texto_celda4');
                                        
           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        14,
                                        v_worksheet_a,
                                        CUR.currency_b,
                                        'texto_celda4');
                                        
           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        15,
                                        v_worksheet_a,
                                        CUR.uuid,
                                        'texto_celda4');
                                        
           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        16,
                                        v_worksheet_a,
                                        cur.estatus,
                                        'texto_celda4');
                                        
           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        17,
                                        v_worksheet_a,
                                        CUR.descripcion_estatus,
                                        'texto_celda4');
           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        18,
                                        v_worksheet_a,
                                        CUR.message,
                                        'texto_celda4');
                                        
           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        19,
                                        v_worksheet_a,
                                        TO_CHAR (CUR.acceso_docto,'DD-MON-YYYY'),
                                        'texto_celda4');
                                        
           apps.gen_xl_xml.write_cell_num (ra,
                                        20,
                                        v_worksheet_a,
                                        CUR.original_amount,
                                        'num_celda');
                                        
           apps.gen_xl_xml.write_cell_num (ra,
                                        21,
                                        v_worksheet_a,
                                        CUR.balance_due,
                                        'num_celda');
                                        
           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        22,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');

            
        END LOOP;
        
        ra := ra + 1;
        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        1,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        2,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        3,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        4,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        5,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        6,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        7,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        8,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        9,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        10,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        11,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        12,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        13,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        14,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        15,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        16,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        17,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        18,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        19,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        20,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                         apps.gen_xl_xml.write_cell_CHAR (ra,
                                        21,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                         apps.gen_xl_xml.write_cell_CHAR (ra,
                                        22,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
        ra := ra + 1;
        
        select      sum (original_amount)
                    ,sum (balance_due) into v_sum_orig_amount,v_sum_balance_due
                    from XXBOT.XXAR_EC_NOT_TT a
                    where 1=1
                    and a.number_a=P_CADENA
                    and a.org_id=P_ORG_ID;
                    
                    apps.gen_xl_xml.write_cell_CHAR (ra,
                                        1,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        2,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        3,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        4,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        5,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        6,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        7,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        8,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        9,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        10,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        11,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        12,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        13,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        14,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        15,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        16,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
        
        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        17,
                                        v_worksheet_a,
                                        'Total Direción Cliente',
                                        'texto_celda3');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        18,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        19,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
        apps.gen_xl_xml.write_cell_num (ra,
                                        20,
                                        v_worksheet_a,
                                        v_sum_orig_amount,
                                        'num_celda');
                                        
        apps.gen_xl_xml.write_cell_num (ra,
                                        21,
                                        v_worksheet_a,
                                        v_sum_balance_due,
                                        'num_celda');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        22,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
        ra := ra + 1;
        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        1,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        2,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        3,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        4,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        5,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        6,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        7,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        8,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        9,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        10,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        11,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        12,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        13,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        14,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        15,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        16,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        17,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        18,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        19,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        20,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        21,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        22,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
        ra := ra + 1;   
        
        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        1,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        2,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        3,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        4,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        5,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        6,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        7,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        8,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        9,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        10,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        11,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        12,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        13,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        14,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');   
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        15,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4'); 
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        16,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');                           
                                        
        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        17,
                                        v_worksheet_a,
                                        'Total Estado de Cuenta',
                                        'texto_celda3');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        18,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        19,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        
        apps.gen_xl_xml.write_cell_num (ra,
                                        20,
                                        v_worksheet_a,
                                        v_sum_orig_amount,
                                        'num_celda');
                                        
        apps.gen_xl_xml.write_cell_num (ra,
                                        21,
                                        v_worksheet_a,
                                        v_sum_balance_due,
                                        'num_celda');
                                        
                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        22,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        commit;
                                        
                                        

        apps.gen_xl_xml.close_file;    
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('Estado de Cuenta Generado con Exito: '||v_file_name);
        apps.MESSAGE_LOG ('Estado de Cuenta Generado con Exito: '||v_file_name);
        P_FILE_NAME:=v_file_name;
        exception 
        when others then 
        DBMS_OUTPUT.PUT_LINE('ERROR: Estado de Cuenta NO Generado: '||SQLERRM);
        apps.MESSAGE_LOG ('ERROR: Estado de Cuenta NO Generado: '||SQLERRM);
        P_FILE_NAME:=null;
    END ;
    
-------------------------------------

procedure  XXAR_SEND_NOTIFICATION (P_REQUEST_ID IN NUMBER,P_CADENA IN varchar2,P_NOT_NUM IN NUMBER,P_SEND_NOTICE IN VARCHAR2,P_FILE_NAME_1 IN VARCHAR2,P_FILE_NAME_2 IN VARCHAR2)
     is 
   
   v_SENDER             VARCHAR2 (1000) ;
        v_subject            VARCHAR2 (1000);
        v_to_recipients      VARCHAR2 (1000):=NULL;
        v_cc_recipients      VARCHAR2 (1000):=NULL;
        v_bcc_recipients     VARCHAR2 (1000);
        p_err_msg            NUMBER;
        gv_dir               VARCHAR (50) := 'CUST_AR_BOTS';
        v_file_name          VARCHAR2 (3000);
        v_file_name_2         VARCHAR2 (3000);
        v_body               VARCHAR2 (4000);
        v_cc_recipients_gepp VARCHAR2 (1000);
        v_control_process EXCEPTION;
        v_exception exception;
        V_ERROR_SALIDA VARCHAR2 (4000);
        V_VALID_EMAIL_COORD NUMBER:=0;
		v_customer_name varchar2(400);	
		----nuevos paramtros
        P_LOG  VARCHAR2 (400);
        P_MAILBODY  VARCHAR2 (400);
        P_PHONE  VARCHAR2 (400);
        P_SENDMAIL  VARCHAR2 (400);
        P_MAILEC  VARCHAR2 (400);
        P_GS  VARCHAR2 (400);
        P_WAY  NUMBER;						  
   
   begin
   
   v_file_name:=P_file_name_1;
    v_file_name_2:=P_file_name_2;
    
    XXBOT_GET_DATA_PROFILE (P_CADENA,P_LOG,P_MAILBODY, P_PHONE,v_SENDER,P_MAILEC,P_GS,P_WAY);
    DBMS_OUTPUT.PUT_LINE ('OBTENGO DATOS DE GS');
DBMS_OUTPUT.PUT_LINE (P_CADENA||' - '||P_LOG||' - '||P_MAILBODY||' - '||P_PHONE||' - '||v_SENDER||' - '||P_MAILEC||' - '||P_GS||' - '||P_WAY);
    
    if p_way=1
    then raise v_exception;
    end if;
    
                               BEGIN 
                               IF P_SEND_NOTICE='Y'
                               THEN 
                               begin
                               SELECT C.EMAIL_ADDRESS into v_cc_recipients
                                                    FROM APPS.AR_CONTACTS_VCT A,apps.RA_CUSTOMERS B,apps.hz_contact_points C
                                                    WHERE 1=1
                                                    AND C.CONTACT_POINT_ID=A.CONTACT_POINT_ID
                                                    AND A.CONTACT_NUMBER  LIKE 'EC-%'
                                                    AND B.CUSTOMER_ID=A.CUSTOMER_ID
                                                    and C.contact_point_type='EMAIL'
                                                    AND C.PRIMARY_FLAG='N'
                                                    AND C.STATUS='A'
                                                    AND B.CUSTOMER_NUMBER=p_cadena;
                               exception 
                               when NO_DATA_FOUND
                               THEN 
                                v_cc_recipients:='NO';
                                XXAR_EMAIL_CONFIG (p_cadena);
                               END;
                               END IF;
                               
							select customer_name into v_customer_name
                                        from apps.ar_customers
                                        where 1=1
                                        and customer_number=p_cadena;											
   
   IF P_NOT_NUM=1
   THEN 
        v_body :=
               '<u><FONT COLOR="red">NOTA:</FONT>Esta cuenta de correo no es monitoreada, favor de no responder</u>'
                    || '<br>'
                    || '<br>'
                    ||'</b>Estimado Cliente:</b>'
                    || '<br>'
                    || '<br>'
                    ||'</b>'||v_customer_name||'</b>'
                    || '<br>'
                    || '<br>'
                    ||'</b>Para nosotros es muy importante mantener sana nuestra relación comercial. Hemos detectado que a la fecha tiene facturas vencidas que no han sido pagadas. Le invitamos a realizar su pago lo antes posible para evitar una suspensión en el servicio.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Anexamos a este correo el estado de cuenta actualizado y le recordamos que debe utilizar la referencia bancaria asignada a su número de cliente para facilitar la identificación de sus pagos.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Le recordamos que una vez que haya realizado el pago, deberá mandar un correo a la cuenta '||P_MAILBODY||' anexando el soporte del mismo y una relación de las facturas que lo integran verificando que el importe sumado de cada factura coincida con el importe total del pago realizado y que todas las facturas consideradas sean de la misma compañía emisora.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Favor de hacer caso omiso a este mensaje si ya realizó el pago de sus facturas vencidas.</b>'
                     || '<br>'
                    || '<br>'
                    || '</b>Si tiene dudas favor de contactarnos al número '||P_phone||'.</b>'
                     || '<br>'
                    || '<br>'
                    || '</b>Gracias.</b>'
                    || '<br>'
                    || '<br>'
                    || '<b>Atte.</b>'
                    || '<br>'
                    || '<b>Cobranza Telefónica</b>'
                    || '<br>'
                    || '<br>'
                    || '<b>Centro de Servicios GEPP</b>'
                    || '<br>'
                    || '<br>'
                    ;
        v_subject :='NO CONTESTAR - '||P_CADENA||' - 07 - Primer Aviso';
                  
------contactos a enviar correo   
                    
IF P_SEND_NOTICE='Y' THEN 
                            --DBMS_OUTPUT.PUT_LINE('ENTRO BIEN CEDC');
                    select c.EMAIL_ADDRESS INTO v_to_recipients
                                                FROM APPS.AR_CONTACTS_V A,apps.RA_CUSTOMERS B,apps.hz_contact_points C
                                                WHERE 1=1
                                                AND C.CONTACT_POINT_ID=A.CONTACT_POINT_ID
                                                AND A.CONTACT_NUMBER  LIKE 'EC-%'
                                                AND B.CUSTOMER_ID=A.CUSTOMER_ID
                                                and C.contact_point_type='EMAIL'
                                                AND B.CUSTOMER_NUMBER=p_cadena;
                            
                            IF v_cc_recipients='NO'
                            THEN 
                            APPS.MESSAGE_LOG('NO SE MANDA  AVISO 1 POR FALTA DE CONFIGURACIÓN');
                            ELSE 
                                               
                                                   SELECT C.EMAIL_ADDRESS into v_cc_recipients
                                                    FROM APPS.AR_CONTACTS_VCT A,apps.RA_CUSTOMERS B,apps.hz_contact_points C
                                                    WHERE 1=1
                                                    AND C.CONTACT_POINT_ID=A.CONTACT_POINT_ID
                                                    AND A.CONTACT_NUMBER  LIKE 'EC-%'
                                                    AND B.CUSTOMER_ID=A.CUSTOMER_ID
                                                    and C.contact_point_type='EMAIL'
                                                    AND C.PRIMARY_FLAG='N'
                                                    AND C.STATUS='A'
                                                    AND B.CUSTOMER_NUMBER=p_cadena;
                                                    END IF;                                                                              
                    ELSE
                    v_to_recipients:=P_LOG;
                    v_cc_recipients:=null;
                    
--                    SELECT vl.MEANING into v_to_recipients
--                                                                        FROM apps.fnd_lookup_values_vl vl,APPS.RA_CUSTOMERS B
--                                                                        WHERE 1=1
--                                                                        AND B.ATTRIBUTE15=vl.description
--                                                                        AND CUSTOMER_NUMBER=p_cadena
--                                                                        AND VL.lookup_type = 'XXAR_LISTA_EJECUTIVOS_CT'
--                                                                        AND SYSDATE BETWEEN VL.start_date_active
--                                                                        AND NVL (VL.end_date_active,SYSDATE + 1);
                    end if;


        apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                              P_RECIPIENT     =>v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                              P_CC            =>v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                              P_BCC           => v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                              P_BODY          => v_body,             -- Cuerpo
                              P_ATTACHMENT1   => v_file_name, --Archivo a enviar
                              P_ATTACHMENT2   => v_file_name_2,
                              P_ERROR         => p_err_msg);
                              
                              if v_file_name is not null and v_file_name_2 is not null
                              then 
                              DBMS_LOCK.SLEEP('4');
                              else 
                              DBMS_LOCK.SLEEP('1');
                              end if;

        COMMIT;
         
                            BEGIN
                            UTL_FILE.fremove (gv_dir, v_file_name);
                            APPS.MESSAGE_LOG(v_file_name|| ': Borrado');
                            if v_file_name_2 is not null then
                            UTL_FILE.fremove (gv_dir, v_file_name_2);
                            APPS.MESSAGE_LOG(v_file_name_2|| ': Borrado');
                            end if;
                            
                            EXCEPTION 
                            WHEN OTHERS 
                            then
                            APPS.MESSAGE_LOG( ' - Error al Intentar Borrar el Archivo .xls');
                            END;
                            
    ELSIF P_NOT_NUM=2
   THEN 
        v_body :=
		'<u><FONT COLOR="red">NOTA:</FONT>Esta cuenta de correo no es monitoreada, favor de no responder</u>'
                    || '<br>'
                    || '<br>'
                    ||'</b>Estimado Cliente:</b>'
                    || '<br>'
                    || '<br>'
                    ||'</b>'||v_customer_name||'</b>'
                    || '<br>'
                    || '<br>'
                    ||'</b>Le recordamos que para nosotros es muy importante mantener sana nuestra relación comercial. Hemos detectado que a la fecha sigue teniendo facturas vencidas que no han sido pagadas. Le invitamos a realizar su pago lo antes posible ya que su crédito está a punto de ser suspendido.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Anexamos a este correo el estado de cuenta actualizado y le recordamos que debe utilizar la referencia bancaria asignada a su número de cliente para facilitar la identificación de sus pagos.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Le recordamos que una vez que haya realizado el pago, deberá mandar un correo a la cuenta '||P_MAILBODY||' anexando el soporte del mismo y una relación de las facturas que lo integran verificando que el importe sumado de cada factura coincida con el importe total del pago realizado y que todas las facturas consideradas sean de la misma compañía emisora.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Favor de hacer caso omiso a este mensaje si ya realizó el pago de sus facturas vencidas.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Si tiene dudas favor de contactarnos al número '||P_phone||'.</b>'
                     || '<br>'
                    || '<br>'
                    || '</b>Gracias.</b>'
                    || '<br>'
                    || '<br>'
                    || '<b>Atte.</b>'
                    || '<br>'
                    || '<b>Cobranza Telefónica</b>'
                    || '<br>'
                    || '<br>'
                    || '<b>Centro de Servicios GEPP</b>'
                    || '<br>'
                    || '<br>'
                    ;

        v_subject :='NO CONTESTAR - '||P_CADENA||' - 08 - Segundo Aviso';

------contactos a enviar correo   
IF P_SEND_NOTICE='Y' THEN 
                            --DBMS_OUTPUT.PUT_LINE('ENTRO BIEN CEDC');
                    select c.EMAIL_ADDRESS INTO v_to_recipients
                                                FROM APPS.AR_CONTACTS_V A,apps.RA_CUSTOMERS B,apps.hz_contact_points C
                                                WHERE 1=1
                                                AND C.CONTACT_POINT_ID=A.CONTACT_POINT_ID
                                                AND A.CONTACT_NUMBER  LIKE 'EC-%'
                                                AND B.CUSTOMER_ID=A.CUSTOMER_ID
                                                and C.contact_point_type='EMAIL'
                                                AND B.CUSTOMER_NUMBER=p_cadena;
                            
                            IF v_cc_recipients='NO'
                            THEN 
                            APPS.MESSAGE_LOG('NO SE MANDA  AVISO 2 POR FALTA DE CONFIGURACIÓN');
                            ELSE 
                                               
                                                   SELECT C.EMAIL_ADDRESS into v_cc_recipients
                                                    FROM APPS.AR_CONTACTS_VCT A,apps.RA_CUSTOMERS B,apps.hz_contact_points C
                                                    WHERE 1=1
                                                    AND C.CONTACT_POINT_ID=A.CONTACT_POINT_ID
                                                    AND A.CONTACT_NUMBER  LIKE 'EC-%'
                                                    AND B.CUSTOMER_ID=A.CUSTOMER_ID
                                                    and C.contact_point_type='EMAIL'
                                                    AND C.PRIMARY_FLAG='N'
                                                    AND C.STATUS='A'
                                                    AND B.CUSTOMER_NUMBER=p_cadena;
                                                    END IF;                                                                              
                    ELSE
                    v_to_recipients:=P_LOG;
                    v_cc_recipients:=null;
                    
--                    SELECT vl.MEANING into v_to_recipients
--                                                                        FROM apps.fnd_lookup_values_vl vl,APPS.RA_CUSTOMERS B
--                                                                        WHERE 1=1
--                                                                        AND B.ATTRIBUTE15=vl.description
--                                                                        AND CUSTOMER_NUMBER=p_cadena
--                                                                        AND VL.lookup_type = 'XXAR_LISTA_EJECUTIVOS_CT'
--                                                                        AND SYSDATE BETWEEN VL.start_date_active
--                                                                        AND NVL (VL.end_date_active,SYSDATE + 1);
                    end if;


        apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                              P_RECIPIENT     =>v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                              P_CC            =>v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                              P_BCC           => v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                              P_BODY          => v_body,             -- Cuerpo
                              P_ATTACHMENT1   => v_file_name, --Archivo a enviar
                              P_ATTACHMENT2   => v_file_name_2,
                              P_ERROR         => p_err_msg);
                              
                              if v_file_name is not null and v_file_name_2 is not null
                              then 
                              DBMS_LOCK.SLEEP('4');
                              else 
                              DBMS_LOCK.SLEEP('1');
                              end if;

        COMMIT;
         
                            BEGIN
                            UTL_FILE.fremove (gv_dir, v_file_name);
                            APPS.MESSAGE_LOG(v_file_name|| ': Borrado');
                            if v_file_name_2 is not null then
                            UTL_FILE.fremove (gv_dir, v_file_name_2);
                            APPS.MESSAGE_LOG(v_file_name_2|| ': Borrado');
                            end if;
                            
                            EXCEPTION 
                            WHEN OTHERS 
                            then
                            APPS.MESSAGE_LOG( ' - Error al Intentar Borrar el Archivo .xls');
                            END;
                            
      ELSIF P_NOT_NUM=3
   THEN 
   DBMS_OUTPUT.PUT_LINE ('ENTRA A SUSPENSIÓN PRUEBAS');
        v_body :=
		 '<u><FONT COLOR="red">NOTA:</FONT>Esta cuenta de correo no es monitoreada, favor de no responder</u>'
                    || '<br>'
                    || '<br>'
                    ||'</b>Estimado Cliente:</b>'
                    || '<br>'
                    || '<br>'
                    ||'</b>'||v_customer_name||'</b>'
                    || '<br>'
                    || '<br>'
                    ||'</b>Le informamos que debido a la omisión de su pago la cuenta ha quedado suspendida.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Anexamos a este correo el estado de cuenta actualizado y le recordamos que debe utilizar la referencia bancaria asignada a su número de cliente para facilitar la identificación de sus pagos.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Le recordamos que una vez que haya realizado el pago, deberá mandar un correo a la cuenta  '||P_MAILBODY||' anexando el soporte del mismo y una relación de las facturas que lo integran verificando que el importe sumado de cada factura coincida con el importe total del pago realizado y que todas las facturas consideradas sean de la misma compañía emisora.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Si tiene dudas favor de contactarnos al número '||P_PHONE||'</b> '
                    || '<br>'
                    || '<br>'
                    || '</b>Gracias.</b>'
                    || '<br>'
                    || '<br>'
                    || '<b>Atte.</b>'
                    || '<br>'
                    || '<b>Cobranza Telefónica</b>'
                    || '<br>'
                    || '<br>'
                    || '<b>Centro de Servicios GEPP</b>'
                    || '<br>'
                    || '<br>';

        v_subject :='NO CONTESTAR - '||P_CADENA||' - 10 - Suspensión';

------contactos a enviar correo   
                    
                    IF P_SEND_NOTICE='Y' THEN 
                            DBMS_OUTPUT.PUT_LINE('ENTRO BIEN CEDC');
                    select c.EMAIL_ADDRESS INTO v_to_recipients
                                                FROM APPS.AR_CONTACTS_V A,apps.RA_CUSTOMERS B,apps.hz_contact_points C
                                                WHERE 1=1
                                                AND C.CONTACT_POINT_ID=A.CONTACT_POINT_ID
                                                AND A.CONTACT_NUMBER  LIKE 'EC-%'
                                                AND B.CUSTOMER_ID=A.CUSTOMER_ID
                                                and C.contact_point_type='EMAIL'
                                                AND B.CUSTOMER_NUMBER=p_cadena;
                                                DBMS_OUTPUT.PUT_LINE ('CORREOS CLIENTE - '||v_to_recipients);
                            
                            IF v_cc_recipients='NO'
                            THEN 
                            APPS.MESSAGE_LOG('NO SE MANDA TERCER AVISO POR FALTA DE CONFIGURACIÓN');
                            ELSE 
                                               
                                                   SELECT C.EMAIL_ADDRESS into v_cc_recipients
                                                    FROM APPS.AR_CONTACTS_VCT A,apps.RA_CUSTOMERS B,apps.hz_contact_points C
                                                    WHERE 1=1
                                                    AND C.CONTACT_POINT_ID=A.CONTACT_POINT_ID
                                                    AND A.CONTACT_NUMBER  LIKE 'EC-%'
                                                    AND B.CUSTOMER_ID=A.CUSTOMER_ID
                                                    and C.contact_point_type='EMAIL'
                                                    AND C.PRIMARY_FLAG='N'
                                                    AND C.STATUS='A'
                                                    AND B.CUSTOMER_NUMBER=p_cadena;
                                                    END IF;                                                                              
                    ELSE
                    v_to_recipients:=P_LOG;
                    v_cc_recipients:=null;
                    
--                    SELECT vl.MEANING into v_to_recipients
--                                                                        FROM apps.fnd_lookup_values_vl vl,APPS.RA_CUSTOMERS B
--                                                                        WHERE 1=1
--                                                                        AND B.ATTRIBUTE15=vl.description
--                                                                        AND CUSTOMER_NUMBER=p_cadena
--                                                                        AND VL.lookup_type = 'XXAR_LISTA_EJECUTIVOS_CT'
--                                                                        AND SYSDATE BETWEEN VL.start_date_active
--                                                                        AND NVL (VL.end_date_active,SYSDATE + 1);
                    end if;
                    DBMS_OUTPUT.PUT_LINE ('MANDA CORREO');


        apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                              P_RECIPIENT     =>v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                              P_CC            =>v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                              P_BCC           =>v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                              P_BODY          => v_body,             -- Cuerpo
                              P_ATTACHMENT1   => v_file_name, --Archivo a enviar
                              P_ATTACHMENT2   => v_file_name_2,
                              P_ERROR         => p_err_msg);
                              
                              if v_file_name is not null and v_file_name_2 is not null
                              then 
                              DBMS_LOCK.SLEEP('4');
                              else 
                              DBMS_LOCK.SLEEP('1');
                              end if;

        COMMIT;
         
                            BEGIN
                            UTL_FILE.fremove (gv_dir, v_file_name);
                            APPS.MESSAGE_LOG(v_file_name|| ': Borrado');
                            if v_file_name_2 is not null then
                            UTL_FILE.fremove (gv_dir, v_file_name_2);
                            APPS.MESSAGE_LOG(v_file_name_2|| ': Borrado');
                            end if;
                            
                            EXCEPTION 
                            WHEN OTHERS 
                            then
                            APPS.MESSAGE_LOG( ' - Error al Intentar Borrar el Archivo .xls');
                            END;
                            
                            update XXBOT.XXAR_CONTROL_NOTIFY_H
                            set CONFIRMATION='Y'
                            WHERE 1=1
                            AND CUSTOMER_NUMBER=P_CADENA
                            AND REQUEST_ID=P_REQUEST_ID;
                            COMMIT;
    
    ELSE 
        
        raise v_control_process;
    END IF;
    EXCEPTION
    WHEN v_control_process THEN 
    APPS.MESSAGE_LOG(P_NOT_NUM|| ' NO EXISTE UN MENSAJE DEFINIDO PARA ESTE VALOR');
    when v_exception then 
    APPS.MESSAGE_LOG(P_NOT_NUM|| ' NO SE ENCONTRÓ UN GRUPO DE SEGURIDAD CONFIGURADO PARA LA CADENA '||P_CADENA||' - SE ENVÍA AVISO DE CONFIG.');
    --DBMS_OUTPUT.PUT_LINE (P_NOT_NUM|| ' NO EXISTE UN MENSAJE DEFINIDO PARA ESTE VALOR');
    WHEN OTHERS
    THEN
    apps.MESSAGE_LOG ('ERROR- Ocurrió un error al envíar correo- '||SQLERRM||CHR(10));
    V_ERROR_SALIDA:=SQLERRM||CHR(10);
    --DBMS_OUTPUT.PUT_LINE('ERROR- Ocurrió un error al envíar correo- '||SQLERRM||CHR(10));
    --return false;
    update XXBOT.XXAR_CONTROL_NOTIFY_H
                            set CONFIRMATION='N',ERROR_CONFIRMATION='ERROR- Ocurrió un error al envíar correo- '||V_ERROR_SALIDA
                            WHERE 1=1
                            AND CUSTOMER_NUMBER=P_CADENA
                            AND REQUEST_ID=P_REQUEST_ID;
                            COMMIT;
   end;
   end;
   
procedure XXAR_LOG_INT_STATUS_NOT (P_REQUEST_ID IN NUMBER,P_EXIT OUT VARCHAR2)

IS 

        v_SENDER             VARCHAR2 (1000) := 'acobranzacs@gepp.com';
        v_subject            VARCHAR2 (1000);
        v_to_recipients      VARCHAR2 (1000);
        v_cc_recipients      VARCHAR2 (1000);
        v_bcc_recipients     VARCHAR2 (1000);
        p_err_msg            NUMBER;
        v_valid_env       number;
        gv_dir               VARCHAR (50) := 'CUST_AR_BOTS';
        v_file_name          VARCHAR2 (3000);
        v_worksheet_a  VARCHAR2 (1000);
        ra                    NUMBER;
        V_estilo_celda       VARCHAR2 (100);
        v_body               VARCHAR2 (4000);
        v_fname     utl_file.file_type;
        
        
        BEGIN
              FOR CUR IN (select NAME_GRPSEG
                            from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a
                            where 1=1
                            and a.ENABLED_FLAG='Y'
                            AND SYSDATE BETWEEN start_date 
                            AND NVL (end_date,SYSDATE + 1))
                            
                            loop
 ---    VALIDO SI DEBE GENERAR REPORTE
              v_valid_env:=0;
              
              select count (*) into v_valid_env
              from (select a.*,xxbot.XXAR_PAY_NOTIF_SYSTEM.XXBOT_GET_GS_PROFILE(a.customer_number) AS GS
              from xxbot.status_warnings_hist a,apps.ra_customers b,xxwebc.xxar_bots_tbl_cust_mails_cs c
              where 1=1 
              and a.request_id=P_request_id
              and a.customer_id=b.customer_id
              and a.customer_id=c.customer_id
              and c.customer_id=b.customer_id
              --and b.attribute15=cur.DESCRIPTION
              and c.send_notice='Y'
              and a.status='Activo'
              and c.uo='Suspendido')
              WHERE 1=1
              and GS=CUR.NAME_GRPSEG;
              
              IF v_valid_env >0 THEN 
                            
                            
                            
                     --genero reporte 
                        v_file_name :=
               'LOG_'||CUR.NAME_GRPSEG||'.xls';

        -- Se crea el excel
        apps.gen_xl_xml.create_excel (gv_dir, v_file_name);

        --Stylos

       v_worksheet_a:='Reporte';

        apps.gen_xl_xml.create_style ('titulo_pestana',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_bold      => true,
                                 --p_underline => 'Y',
                                 p_backcolor   => '#b8b9ba',
                                 p_border      => 'Y');--'LightBlue'  ); --'#3366FF');



        apps.gen_xl_xml.create_style ('texto_celda4',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_border      => 'Y');





        apps.gen_xl_xml.create_worksheet (v_worksheet_a);
        -- Tamaño de columna
        apps.gen_xl_xml.set_column_width (1,100, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (2, 100, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (3, 100, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (4, 100, v_worksheet_a);
        ra := 1;

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'No. Concurrente',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    2,
                                    v_worksheet_a,
                                    'Cadena',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    3,
                                    v_worksheet_a,
                                    'ESTATUS',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    4,
                                    v_worksheet_a,
                                    'FECHA_ESTATUS',
                                    'titulo_pestana');

        
                    FOR cura
                          IN (select request_id,customer_number,status,creation_date FROM (
                          SELECT A.*,xxbot.XXAR_PAY_NOTIF_SYSTEM.XXBOT_GET_GS_PROFILE(a.customer_number) AS GS
              from xxbot.status_warnings_hist a,apps.ra_customers b,xxwebc.xxar_bots_tbl_cust_mails_cs c
              where 1=1 
              and a.customer_id=b.customer_id
              and c.customer_id=b.customer_id
              and a.customer_id=c.customer_id
              and c.send_notice='Y'
              --and b.attribute15=cur.DESCRIPTION
              and a.request_id=P_request_id
              and a.status='Activo'
              and c.uo='Suspendido')
              WHERE 1=1
              AND GS=CUR.NAME_GRPSEG)
                                   
                            LOOP
                                ra := ra + 1;

                                apps.gen_xl_xml.write_cell_num (ra,
                                                            1,
                                                            v_worksheet_a,
                                                            cura.REQUEST_ID,
                                                            'texto_celda4');

                               apps.gen_xl_xml.write_cell_CHAR (ra,
                                                            2,
                                                            v_worksheet_a,
                                                            cura.customer_number,
                                                            'texto_celda4');

                                apps.gen_xl_xml.write_cell_CHAR (ra,
                                                            3,
                                                            v_worksheet_a,
                                                            cura.status,
                                                            'texto_celda4');

                                      apps.gen_xl_xml.write_cell_CHAR (ra,
                                                            4,
                                                            v_worksheet_a,
                                                            to_char(trunc(cura.creation_date)),
                                                            'texto_celda4');
                                        end loop;
                                        apps.gen_xl_xml.close_file;    
                                        commit;



        v_body :=
               '</b>Proceso- Validación para actualizar Estatus por Cadena</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Notas Importantes:</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Nombre del archivo adjunto ->    '||v_file_name||'</b>'
                    || '<br>'
                    || '<br>'
                    || '</b> El proceso Validación para actualizar Estatus por Cadena, concluyó correctamente, se adjunta resumen de cadenas que pasaron de estatus "Suspendido" a : "Activo".</b>'
                    || '<br>'
                    || '</b>';


        v_subject :=
               'Proceso Validación para actualizar Estatus por Cadena';
               
               --v_to_recipients:=cur.meaning;
               
               select TXT_ATTRIBUTE1 into v_to_recipients
from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a
where 1=1
and a.ENABLED_FLAG='Y'
AND SYSDATE BETWEEN start_date 
AND NVL (end_date,SYSDATE + 1)
AND NAME_GRPSEG=CUR.NAME_GRPSEG;


        apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                              P_RECIPIENT     =>v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                              P_CC            =>NULL,--v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                              P_BCC           => 'alejandro.romo@gepp.com',--v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                              P_BODY          => v_body,             -- Cuerpo
                              P_ATTACHMENT1   => v_file_name, --Archivo a enviar
                              P_ERROR         => p_err_msg);

        COMMIT;
         
                            BEGIN
                            UTL_FILE.fremove (gv_dir, v_file_name);
                            APPS.MESSAGE_LOG('- Archivo Borrado');
                            EXCEPTION 
                            WHEN OTHERS 
                            then
                            APPS.MESSAGE_LOG('- Error al Intentar Borrar el Archivo .xls');
                            END;
                            COMMIT;
                            P_EXIT:='Correcto';
     ELSE 
     
     --ENTRA 
     APPS.MESSAGE_LOG ('ENTRA A LOG SIN ACT- '||CUR.NAME_GRPSEG); 
     
     v_body :=
               '</b>Proceso- Validación para actualizar Estatus por Cadena</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Notas Importantes:</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>El proceso NO generó Archivo LOG ya que en esta ejecución no se actualizarón cadenas Suspendidas a estatus: "Activo"</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>';


        v_subject :=
               'Proceso Validación para actualizar Estatus por Cadena';

                select TXT_ATTRIBUTE1 into v_to_recipients
                from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a
                where 1=1
                and a.ENABLED_FLAG='Y'
                AND SYSDATE BETWEEN start_date 
                AND NVL (end_date,SYSDATE + 1)
                AND NAME_GRPSEG=CUR.NAME_GRPSEG;

        apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                              P_RECIPIENT     =>v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                              P_CC            =>NULL,--v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                              P_BCC           => 'alejandro.romo@gepp.com',--v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                              P_BODY          => v_body,             -- Cuerpo
                              P_ATTACHMENT1   => NULL, --Archivo a enviar
                              P_ERROR         => p_err_msg);
                              COMMIT;
                            P_EXIT:='Correcto';
        
        END IF;
                            
                            
                            END LOOP; 
                             
        
        
        EXCEPTION
    WHEN OTHERS
    THEN
    P_EXIT:='Incorrecto';
    apps.MESSAGE_LOG ('ERROR- Ocurrió un error al envíar correo -(Proceso Validación para actualizar Estatus por Cadena)- '||SQLERRM||CHR(10));
    DBMS_OUTPUT.PUT_LINE('ERROR- Ocurrió un error al envíar correo -(Proceso Validación para actualizar Estatus por Cadena)- '||SQLERRM||CHR(10));
    END;
    
    procedure XXAR_SEND_NOT_COORD (P_REQUEST_ID IN NUMBER,P_EXIT OUT VARCHAR2)
     IS 

v_SENDER             VARCHAR2 (1000) := 'acobranzacs@gepp.com';
        v_subject            VARCHAR2 (1000);
        v_to_recipients      VARCHAR2 (1000);
        v_cc_recipients      VARCHAR2 (1000);
        v_bcc_recipients     VARCHAR2 (1000);
        p_err_msg            NUMBER;
        v_valid_env       number;
        gv_dir               VARCHAR (50) := 'CUST_AR_BOTS';
        v_file_name          VARCHAR2 (3000);
        v_worksheet_a VARCHAR2 (1000);
        ra                    NUMBER;
        V_estilo_celda       VARCHAR2 (100);
        v_body               VARCHAR2 (4000);
        v_fname utl_file.file_type;
        v_num_ticket number;
        
        
        BEGIN
             FOR CUR IN (select NAME_GRPSEG
                            from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a
                            where 1=1
                            and a.ENABLED_FLAG='Y'
                            AND SYSDATE BETWEEN start_date 
                            AND NVL (end_date,SYSDATE + 1)
                            order by 1 asc )
                            loop
 ---    VALIDO SI DEBE GENERAR REPORTE
              v_valid_env:=0;
              select count (*) into v_valid_env
              from (select a.*,xxbot.XXAR_PAY_NOTIF_SYSTEM.XXBOT_GET_GS_PROFILE(a.customer_number) AS GS
              from xxbot.status_warnings_hist a,apps.ra_customers b,xxwebc.xxar_bots_tbl_cust_mails_cs c
              where 1=1 
              and a.request_id=P_request_id
              and a.customer_id=b.customer_id
              and c.customer_id=b.customer_id
              and a.customer_id=c.customer_id
              --and b.attribute15=cur.description
              and c.send_notice='Y'
              and a.status ='Suspendido')
              WHERE 1=1
              AND GS=CUR.NAME_GRPSEG;
              
              IF v_valid_env >0 THEN       
							
							
                            
                     --genero reporte 
                        v_file_name :=
               'PCT_STS_'||CUR.NAME_GRPSEG||'_'||abs(p_request_id)||'.xls';
               
               -----------------------------------------------------------------
               -----obtengo datos de encabezado:
               select TXT_ATTRIBUTE1 into v_to_recipients
                from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a
                where 1=1
                and a.ENABLED_FLAG='Y'
                AND SYSDATE BETWEEN start_date 
                AND NVL (end_date,SYSDATE + 1)
                AND NAME_GRPSEG=CUR.NAME_GRPSEG;
                
                select distinct num_ticket into v_num_ticket
                from xxbots_ctr_tickets_l
                where 1=1 
                and request_id=p_request_id
                and gs=CUR.NAME_GRPSEG;
                -----------------------------------------------------
                

        -- Se crea el excel
        apps.gen_xl_xml.create_excel (gv_dir, v_file_name);

        --Stylos

       v_worksheet_a:='Reporte';

        apps.gen_xl_xml.create_style ('titulo_pestana',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_bold      => true,
                                 --p_underline => 'Y',
                                 p_backcolor   => '#b8b9ba',
                                 p_border      => 'Y');--'LightBlue'  ); --'#3366FF');



        apps.gen_xl_xml.create_style ('texto_celda4',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_border      => 'Y');





        apps.gen_xl_xml.create_worksheet (v_worksheet_a);
        -- Tamaño de columna
        apps.gen_xl_xml.set_column_width (1,100, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (2, 100, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (3, 100, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (4, 100, v_worksheet_a);
        ra := 1;
        
         apps.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'Grupo de Seguridad:',
                                    'titulo_pestana');
         apps.gen_xl_xml.write_cell_CHAR (ra,
                                    2,
                                    v_worksheet_a,
                                    CUR.NAME_GRPSEG,
                                    'texto_celda4');
                                    
        
        ra:=ra+1; 
        
        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'Ticket de Suspensión:',
                                    'titulo_pestana');
         apps.gen_xl_xml.write_cell_CHAR (ra,
                                    2,
                                    v_worksheet_a,
                                    v_num_ticket,
                                    'texto_celda4');
                                    
        ra:=ra+1; 
        
        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'Correo Ejecutivo:',
                                    'titulo_pestana');
         apps.gen_xl_xml.write_cell_CHAR (ra,
                                    2,
                                    v_worksheet_a,
                                    v_to_recipients,
                                    'texto_celda4');
                                    
         ra:=ra+2; 


        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'No. Concurrente',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    2,
                                    v_worksheet_a,
                                    'Cadena',
                                    'titulo_pestana');
                                    
         apps.gen_xl_xml.write_cell_CHAR (ra,
                                    3,
                                    v_worksheet_a,
                                    'RAZON SOCIAL',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    4,
                                    v_worksheet_a,
                                    'ESTATUS',
                                    'titulo_pestana');
       

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    5,
                                    v_worksheet_a,
                                    'FECHA_ESTATUS',
                                    'titulo_pestana');

        
                    FOR cura
                          IN (
                          select request_id,customer_number,customer_name,status,creation_date FROM (
                          SELECT A.*,B.CUSTOMER_NAME,xxbot.XXAR_PAY_NOTIF_SYSTEM.XXBOT_GET_GS_PROFILE(a.customer_number) AS GS
              from xxbot.status_warnings_hist a,apps.ra_customers b,xxwebc.xxar_bots_tbl_cust_mails_cs C
              where 1=1 
              and a.customer_id=b.customer_id
              and a.customer_id=C.customer_id
              and C.customer_id=b.customer_id
              AND C.SEND_NOTICE='Y'
              --and b.attribute15=cur.description
              and a.request_id=P_request_id
              and a.status='Suspendido')
              WHERE 1=1
              AND GS=CUR.NAME_GRPSEG)
                                   
                            LOOP
                                ra := ra + 1;

                                apps.gen_xl_xml.write_cell_num (ra,
                                                            1,
                                                            v_worksheet_a,
                                                            cura.REQUEST_ID,
                                                            'texto_celda4');

                               apps.gen_xl_xml.write_cell_CHAR (ra,
                                                            2,
                                                            v_worksheet_a,
                                                            cura.customer_number,
                                                            'texto_celda4');

                                apps.gen_xl_xml.write_cell_CHAR (ra,
                                                            3,
                                                            v_worksheet_a,
                                                            cura.customer_nAME,
                                                            'texto_celda4');

                                apps.gen_xl_xml.write_cell_CHAR (ra,
                                                            4,
                                                            v_worksheet_a,
                                                            cura.status,
                                                            'texto_celda4');

                                      apps.gen_xl_xml.write_cell_CHAR (ra,
                                                            5,
                                                            v_worksheet_a,
                                                            to_char(trunc(cura.creation_date)),
                                                            'texto_celda4');
                                        end loop;
                                        apps.gen_xl_xml.close_file;    
                                        commit;
                                        DBMS_LOCK.SLEEP('4');



        v_body :=
               '</b>Correo de Notificación de "LOG" cadenas en estatus "Suspendido".</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Se Adjunta archivo con el detalle.</b>'
                    ;


        v_subject :=
               'LOG - Proceso de Notificaciones CT';
              
 select TXT_ATTRIBUTE1 into v_to_recipients
                from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a
                where 1=1
                and a.ENABLED_FLAG='Y'
                AND SYSDATE BETWEEN start_date 
                AND NVL (end_date,SYSDATE + 1)
                AND NAME_GRPSEG=CUR.NAME_GRPSEG;


        apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                              P_RECIPIENT     =>v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                              P_CC            =>NULL,--v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                              P_BCC           =>'alejandro.romo@gepp.com',-- v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                              P_BODY          => v_body,             -- Cuerpo
                              P_ATTACHMENT1   => v_file_name, --Archivo a enviar
                              P_ERROR         => p_err_msg);

        COMMIT;
         
                            BEGIN
                            UTL_FILE.fremove (gv_dir, v_file_name);
                            APPS.MESSAGE_LOG('- Archivo Borrado');
                            EXCEPTION 
                            WHEN OTHERS 
                            then
                            APPS.MESSAGE_LOG('- Error al Intentar Borrar el Archivo .xls');
                            END;
                            COMMIT;
                            DBMS_LOCK.SLEEP('4');
                            P_EXIT:='Correcto';
     
     ELSE 
     
     v_body :=
               '</b>Correo de Notificación de "LOG" cadenas en estatus "Suspendido".</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Notas Importantes:</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>El proceso NO generó Archivo LOG ya que en esta ejecución no se actualizarón cadenas a estatus "Suspendido"</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>';


        v_subject :=
               'LOG - Proceso de Notificaciones CT';
               
                select TXT_ATTRIBUTE1 into v_to_recipients
                from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a
                where 1=1
                and a.ENABLED_FLAG='Y'
                AND SYSDATE BETWEEN start_date 
                AND NVL (end_date,SYSDATE + 1)
                AND NAME_GRPSEG=CUR.NAME_GRPSEG;


        apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                              P_RECIPIENT     =>v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                              P_CC            =>NULL,--v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                              P_BCC           => 'alejandro.romo@gepp.com',--v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                              P_BODY          => v_body,             -- Cuerpo
                              P_ATTACHMENT1   => NULL, --Archivo a enviar
                              P_ERROR         => p_err_msg);
                              COMMIT;
                            P_EXIT:='Correcto';
                            DBMS_LOCK.SLEEP('4');
                            END IF;
        END LOOP; 
                             
        
        
        EXCEPTION
    WHEN OTHERS
    THEN
    P_EXIT:='Incorrecto';
    apps.MESSAGE_LOG ('ERROR- Ocurrió un error al envíar correo -(LOG Proceso Avisos CT)- '||SQLERRM||CHR(10));
    DBMS_OUTPUT.PUT_LINE('ERROR- Ocurrió un error al envíar correo -(LOG Proceso Avisos CT)- '||SQLERRM||CHR(10));
        END;
        
procedure XXAR_CREATE_TICKETS (P_REQUEST_ID IN NUMBER,P_EXIT OUT VARCHAR2)
        is
        
        gv_dir               VARCHAR (50) := 'CUST_AR_BOTS';
        v_file_name          VARCHAR2 (3000);
        v_worksheet_a VARCHAR2 (1000);
        ra                    NUMBER;
        V_estilo_celda       VARCHAR2 (100);
        v_fname utl_file.file_type;
        v_employee_id number;
        V_TICKET_NUMBER number;
        P_LOG_file varchar2(4000);
        P_LOG_attach varchar2(4000);
        v_file_name_end varchar2(4000);
        V_COUNT_VALID NUMBER:=0;
        V_EXCEPTION EXCEPTION;
        v_valid_eid number;
        

BEGIN
              FOR CUR IN (
                           SELECT b.NAME_GRPSEG,b.TXT_ATTRIBUTE1
                                    FROM XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 b
                                    WHERE 1=1
                                     and b.ENABLED_FLAG='Y'
                                                    AND SYSDATE BETWEEN b.start_date 
                                                    AND NVL (b.end_date,SYSDATE + 1)
                                                    and b.NAME_GRPSEG in (SELECT distinct xxbot.XXAR_PAY_NOTIF_SYSTEM.XXBOT_GET_GS_PROFILE(customer_number) AS GS
                                                        FROM xxwebc.xxar_bots_tbl_cust_mails_cs
                                                        WHERE 1=1
                                                        AND SEND_NOTICE='Y'
                                                        AND CUSTOMER_ID IN (
                                                                                SELECT CUSTOMER_ID 
                                                                              FROM xxbot.status_warnings_hist
                                                                              WHERE 1=1
                                                                              AND REQUEST_ID=P_REQUEST_ID
                                                                              AND STATUS='Suspendido')))
  --valido si genera ticket
  LOOP
  
  V_COUNT_VALID:=1;
              
--              SELECT COUNT (*) INTO V_COUNT_VALID FROM 
--              (SELECT customer_number,xxbot.XXAR_PAY_NOTIF_SYSTEM.XXBOT_GET_GS_PROFILE(customer_number) AS GS
--                                                        FROM xxwebc.xxar_bots_tbl_cust_mails_cs
--                                                        WHERE 1=1
--                                                        AND SEND_NOTICE='Y'
--                                                        AND CUSTOMER_ID IN (
--                                                                                SELECT CUSTOMER_ID 
--                                                                              FROM xxbot.status_warnings_hist
--                                                                              WHERE 1=1
--                                                                              AND REQUEST_ID=P_REQUEST_ID
--                                                                              AND STATUS='Suspendido'))
--                                                                              where 1=1
--                                                                              and GS=CUR.NAME_GRPSEG;
                                                                              
                                          IF V_COUNT_VALID<>0
                                          THEN 
                                          --RAISE V_EXCEPTION;
                                          insert into xxbots_ctr_tickets_l
                                         select * from (SELECT P_REQUEST_ID,null as num_ticket,customer_number,xxbot.XXAR_PAY_NOTIF_SYSTEM.XXBOT_GET_GS_PROFILE(customer_number) AS GS,sysdate
                                                        FROM xxwebc.xxar_bots_tbl_cust_mails_cs
                                                        WHERE 1=1
                                                        AND SEND_NOTICE='Y'
                                                        AND CUSTOMER_ID IN (
                                                                                SELECT CUSTOMER_ID 
                                                                              FROM xxbot.status_warnings_hist
                                                                              WHERE 1=1
                                                                              AND REQUEST_ID=P_REQUEST_ID
                                                                              AND STATUS='Suspendido'))
                                                                              where 1=1
                                                                              and gs=CUR.NAME_GRPSEG;
                                                                              commit;
                                                                       
 ---    genero excel para cargar al ticket      
                     --genero reporte 
                     v_file_name:=null;
                        v_file_name :=
               'BC'||to_char(sysdate,'YYYYMMDDHHMMSS')||'.xls';

        -- Se crea el excel
        apps.gen_xl_xml.create_excel (gv_dir, v_file_name);

        --Stylos

       v_worksheet_a:='BAJA_CAD';

        apps.gen_xl_xml.create_style ('titulo_pestana',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_bold      => true,
                                 --p_underline => 'Y',
                                 p_backcolor   => '#b8b9ba',
                                 p_border      => 'Y');--'LightBlue'  ); --'#3366FF');



        apps.gen_xl_xml.create_style ('texto_celda4',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_border      => 'Y');





        apps.gen_xl_xml.create_worksheet (v_worksheet_a);
        -- Tamaño de columna
        apps.gen_xl_xml.set_column_width (1,100, v_worksheet_a);
        ra := 1;

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet_a,
                                    'CADENA',
                                    'titulo_pestana');

        
                    FOR cura
                          IN (SELECT CUSTOMER_NUMBER FROM (
                                                        SELECT CUSTOMER_NUMBER,xxbot.XXAR_PAY_NOTIF_SYSTEM.XXBOT_GET_GS_PROFILE(customer_number) AS GS
                                                        FROM xxwebc.xxar_bots_tbl_cust_mails_cs
                                                        WHERE 1=1
                                                        AND SEND_NOTICE='Y'
                                                        AND CUSTOMER_ID IN (SELECT CUSTOMER_ID 
                                                                              FROM xxbot.status_warnings_hist
                                                                              WHERE 1=1
                                                                              AND REQUEST_ID=p_request_id
                                                                              AND STATUS='Suspendido'))
                                                                              WHERE 1=1
                                                                              AND GS=CUR.NAME_GRPSEG)
                                   
                            LOOP
                                ra := ra + 1;

                                apps.gen_xl_xml.write_cell_num (ra,
                                                            1,
                                                            v_worksheet_a,
                                                            cura.CUSTOMER_NUMBER,
                                                            'texto_celda4');
                                        end loop;
                                        apps.gen_xl_xml.close_file;   
                                        commit;
                                        
                                        v_valid_eid:=0;
                                        v_employee_id:=0;
                                        
                                        ------recupero EMPLOYEE_ID-----------------------
                                        
                                            SELECT count (*) into v_valid_eid
                                                     --fua.employee_id
                                            FROM apps.fnd_user_resp_groups_direct fud,
                                                      applsys.fnd_responsibility fr,
                                                      applsys.fnd_responsibility_tl frt,
                                                      fnd_user fua
                                            WHERE fr.responsibility_id = fud.responsibility_id
                                                AND frt.responsibility_id = fud.responsibility_id
                                                AND frt.language = 'ESA'
                                                AND fud.end_date IS NULL
                                                AND frt.responsibility_name like 'AR_%_ASIGNA_APLICA'
                                                AND fua.user_id = fud.user_id
                                                AND (fud.responsibility_id, fud.responsibility_application_id) IN
                                                        (SELECT responsibility_id, application_id
                                                           FROM fnd_responsibility
                                                          WHERE (   version = '4'
                                                                 OR version = 'W'
                                                                 OR version = 'M'
                                                                 OR version = 'H'))
                                                AND upper(fua.EMAIL_ADDRESS)= trim(upper(cur.TXT_ATTRIBUTE1))
                                                                                and fua.end_date is null
                                                                                and fua.ENCRYPTED_USER_PASSWORD !='INVALID';
                                                                                
                                                    if v_valid_eid<>0 then 
                                                    
                                                    SELECT distInct (fua.employee_id) into v_employee_id
                                            FROM apps.fnd_user_resp_groups_direct fud,
                                                      applsys.fnd_responsibility fr,
                                                      applsys.fnd_responsibility_tl frt,
                                                      fnd_user fua
                                            WHERE fr.responsibility_id = fud.responsibility_id
                                                AND frt.responsibility_id = fud.responsibility_id
                                                AND frt.language = 'ESA'
                                                AND fud.end_date IS NULL
                                                AND frt.responsibility_name like 'AR_%_ASIGNA_APLICA'
                                                AND fua.user_id = fud.user_id
                                                AND (fud.responsibility_id, fud.responsibility_application_id) IN
                                                        (SELECT responsibility_id, application_id
                                                           FROM fnd_responsibility
                                                          WHERE (   version = '4'
                                                                 OR version = 'W'
                                                                 OR version = 'M'
                                                                 OR version = 'H'))
                                                AND upper(fua.EMAIL_ADDRESS)= trim(upper(cur.TXT_ATTRIBUTE1))
                                                                                and fua.end_date is null
                                                                                and fua.ENCRYPTED_USER_PASSWORD !='INVALID'
                                                                                and rownum<=1;                           
                                    
                                    
                                       
                                        V_TICKET_NUMBER:=0;
                                        P_LOG_file:=null;
                                        P_LOG_attach:=null;
                                        
                                        apps.XXAR_CT_CREATION_TICKETS_OS.CT_CREATE_TICKET(v_employee_id,V_TICKET_NUMBER);
                                        if V_TICKET_NUMBER<>0 then 
                                        apps.MESSAGE_LOG ('Ticket Generado- '||V_TICKET_NUMBER);
                                         insert into xxbot.control_tickets_ct (v_request_id,collector_id,employee_id,attach_file,num_Ticket,creation_date) values
                                         (p_request_id,NULL,v_employee_id,v_file_name,V_TICKET_NUMBER,sysdate);
                                         update xxbots_ctr_tickets_l set num_ticket=V_TICKET_NUMBER
                                         where 1=1
                                         and request_id=P_REQUEST_ID
                                         and gs=CUR.NAME_GRPSEG;
                                         commit;
                                         apps.MESSAGE_LOG ('ingresa a clob- ');
                                         --DBMS_LOCK.SLEEP('5');
                                        apps.XXAR_CT_CREATION_TICKETS_OS.GENERATE_CLOB (V_TICKET_NUMBER,v_file_name,P_REQUEST_ID,v_employee_id,P_LOG_file);
                                        apps.MESSAGE_LOG ('r-clob- '||P_LOG_file);
                                        --DBMS_LOCK.SLEEP('30');
                                        commit;
                                        apps.MESSAGE_LOG ('entra atach');
                                        apps.XXAR_CT_CREATION_TICKETS_OS.ATTACH_FILE_TO_TICKET (V_TICKET_NUMBER,P_LOG_attach);
                                        apps.MESSAGE_LOG ('r-attach- '||P_LOG_attach);
                                         --DBMS_LOCK.SLEEP('30');
                                        end if;
                                        else 
                                          XXAR_EMAIL_TK_CREATION (cur.TXT_ATTRIBUTE1,CUR.NAME_GRPSEG);
                                         apps.MESSAGE_LOG ('ENVIA CORREO -no encontró employee id-'||cur.TXT_ATTRIBUTE1||' - '||CUR.NAME_GRPSEG);
                                         end if;
                                         else 
                                         apps.MESSAGE_LOG ('No hay cadenas a suspender para el grupo de seguridad: '||CUR.NAME_GRPSEG);
                                         
                                         end if;
                                        
                                        end loop;
                                        P_EXIT:='Correcto';
                                        exception 
                                      when v_exception then 
                                      apps.MESSAGE_LOG ('ENVIAR CORREO');
                                        when others then 
                                        apps.MESSAGE_LOG ('ERROR- Al levantar los tickets automaticos');
                                        
                                        P_EXIT:='Incorrecto';
                                        end;

procedure XXAR_EMAIL_CONFIG (P_CADENA varchar2)
IS
        v_SENDER             VARCHAR2 (1000);
        v_subject            VARCHAR2 (1000);
        v_to_recipients      VARCHAR2 (1000);
        v_cc_recipients      VARCHAR2 (1000);
        v_bcc_recipients     VARCHAR2 (1000);
        p_err_msg            NUMBER;
        v_valid_env       number;
        gv_dir               VARCHAR (50) := 'CUST_AR_BOTS';
        v_file_name          VARCHAR2 (3000);
        v_worksheet_a VARCHAR2 (1000);
        ra                    NUMBER;
        V_estilo_celda       VARCHAR2 (100);
        v_body               VARCHAR2 (4000);
P_LOG  VARCHAR2 (400);
P_MAILBODY  VARCHAR2 (400);
 P_PHONE  VARCHAR2 (400);
 P_SENDMAIL  VARCHAR2 (400);
 P_MAILEC  VARCHAR2 (400);
 P_GS  VARCHAR2 (400);
 P_WAY  NUMBER;
 v_exception exception;
        
        
        BEGIN
        
        XXBOT_GET_DATA_PROFILE (p_cadena,P_LOG,P_MAILBODY, P_PHONE,V_SENDER,P_MAILEC,P_GS,P_WAY);
        
        if p_way =1 then raise v_exception;
        end if;
             
        v_body :=
               '</b>Errores en Configuración proceso de "Avisos CT".</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Se detectó que no se han configurado los correos internos de la Cadena -'||p_cadena||'- Favor de concluir con el seteo.</b>'
                    ;


        v_subject :=
               'Errores en Configuración proceso de "Avisos CT".';


        apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                              P_RECIPIENT     =>P_LOG,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                              P_CC            =>NULL,--v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                              P_BCC           =>'alejandro.romo@gepp.com',-- v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                              P_BODY          => v_body,             -- Cuerpo
                              P_ATTACHMENT1   => v_file_name, --Archivo a enviar
                              P_ERROR         => p_err_msg);

        COMMIT; 
        EXCEPTION
        when v_exception then apps.MESSAGE_LOG ('ERROR- Ocurrió un error al envíar correo -(Errores de Configuración  CT (NO SE ENCONTRÓ EL GRUPO DE SEGURIDAD))- '||SQLERRM||CHR(10));
    WHEN OTHERS
    THEN
    apps.MESSAGE_LOG ('ERROR- Ocurrió un error al envíar correo -(Errores de Configuración  CT)- '||SQLERRM||CHR(10));
    DBMS_OUTPUT.PUT_LINE('ERROR- Ocurrió un error al envíar correo -(Errores de Configuración  CT)- '||SQLERRM||CHR(10));
    end;
    procedure XXAR_EMAIL_EC_PANTALLA (P_CADENA IN VARCHAR2,P_ORG_ID IN number)
    IS
     v_SENDER             VARCHAR2 (1000) := 'envioestadosCS@gepp.com';
        v_subject            VARCHAR2 (1000);
        V_customer_id     NUMBER;
        v_to_recipients      VARCHAR2 (1000);
        v_cc_recipients      VARCHAR2 (1000);
        v_bcc_recipients     VARCHAR2 (1000);
        p_err_msg            NUMBER;
        v_GEN_EC NUMBER;
        v_file VARCHAR2 (1000);
        v_valid_env       number;
        gv_dir               VARCHAR (50) := 'CUST_AR_BOTS';
        v_file_name          VARCHAR2 (3000);
        v_worksheet_a VARCHAR2 (1000);
        ra                    NUMBER;
        V_estilo_celda       VARCHAR2 (100);
        v_body               VARCHAR2 (4000);
        v_CADENA   varchar2(50);
        
        BEGIN
        
                        BEGIN
                        
                        v_CADENA:=P_CADENA;
                        
                        SELECT CUSTOMER_ID INTO V_CUSTOMER_id
                        from apps.ra_customers
                        where 1=1
                        and customer_number=v_CADENA;
                        
                        XXBOT.XXAR_PAY_NOTIF_SYSTEM.XXAR_EC_GEN(P_ORG_ID,V_customer_id,v_GEN_EC);
                       XXBOT.XXAR_PAY_NOTIF_SYSTEM.GEN_FILE_EDO_CTA(P_CADENA,P_ORG_ID,v_file);
                       
                        END;
        
            select c.EMAIL_ADDRESS INTO v_to_recipients
                                                FROM APPS.AR_CONTACTS_V A,apps.RA_CUSTOMERS B,apps.hz_contact_points C
                                                WHERE 1=1
                                                AND C.CONTACT_POINT_ID=A.CONTACT_POINT_ID
                                                AND A.CONTACT_NUMBER  LIKE 'EC-%'
                                                AND B.CUSTOMER_ID=A.CUSTOMER_ID
                                                and C.contact_point_type='EMAIL'
                                                AND B.CUSTOMER_NUMBER=v_CADENA;
                 
apps.MESSAGE_LOG (v_to_recipients); 
             
        v_body :=
               '</b>Buen día estimado cliente.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Por este medio le hacemos llegar su estado de cuenta al momento. Favor de hacer caso omiso si ya realizó el pago de los documentos vencidos.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Recuerde que por cada pago realizado es importante enviar un soporte del mismo, así como la relación de las facturas pagadas a la siguiente cuenta de correo CobranzaCS@gepp.com.</b>'
                    || '</b>Mismas que servirán para generar su complemento de pago.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Aprovechamos para recordarle que al momento de hacer sus transferencias debe utilizar la referencia de pago que se incluye en cada factura.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Finalmente, ponemos a ssu dissposición el siguiente portal https://www.facturagepp.com.mx para que pueda descargar sus facturas y la siguiente linea telefónica en caso de necesitar alguna ayuda:</b>'
                    || '</b> (33)3897 7901 - Opción Clientes.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Atentamente,</b>'
                    || '<br>'
                    || '</b>Departamento de Cobranza GEPP.</b>'
                    || '<br>'
                    || '<br>'
                    || '<b><FONT COLOR="red">NOTA:</FONT>Esta cuenta de correo no es monitoreada, favor de no responder</b>';
                    


        v_subject :='Envío Estado de cuenta GEPP -  '
                    || p_cadena;


        apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                              P_RECIPIENT     =>v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                              P_CC            =>v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                              P_BCC           =>v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                              P_BODY          => v_body,             -- Cuerpo
                              P_ATTACHMENT1   => v_file, --Archivo a enviar
                              P_ERROR         => p_err_msg);

        COMMIT; 
        
                                BEGIN
                            UTL_FILE.fremove (gv_dir, v_file);
                            APPS.MESSAGE_LOG('- Archivo Borrado-'||v_file);
                            EXCEPTION 
                            WHEN OTHERS 
                            then
                            APPS.MESSAGE_LOG('- Error al Intentar Borrar el Archivo .xls');
                            END;
                            COMMIT;
        EXCEPTION
    WHEN OTHERS
    THEN
    apps.MESSAGE_LOG ('ERROR- Ocurrió un error al envíar correo -(EC Desde Pantalla)- '||SQLERRM||CHR(10));
    DBMS_OUTPUT.PUT_LINE('ERROR- Ocurrió un error al envíar correo -(EC Desde Pantalla)- '||SQLERRM||CHR(10));
    end;
    procedure XXBOT_LOAD_LAY_CS_XLSX (
    errbuf out varchar2,
    retcode out number, 
    pFileName varchar2,p_process varchar2)
    is 
        v_file         UTL_FILE.file_type;
        vgDirectory varchar2(1000):= 'CUST_AR_BOTS_LAYOUT';
        v_file_name varchar2(1000);  
      V_REQUEST_ID number;
      V_USER_ID number;
      V_COUNT number;
      v_prefijo VARCHAR2(1000):='LAY_CS_CT_';
      v_SENDER             VARCHAR2 (1000) := 'ar_oracle@gepp.com';
        v_subject            VARCHAR2 (1000);
        v_to_recipients      VARCHAR2 (1000);
        v_cc_recipients      VARCHAR2 (1000);
        v_bcc_recipients     VARCHAR2 (1000);
        p_err_msg            NUMBER;
        v_worksheet_a VARCHAR2 (1000);
        ra                    NUMBER;
        v_body VARCHAR2 (4000);
        v_count_file number:=0;
        v_exception_file exception;
      
        
   BEGIN
        apps.MESSAGE_LOG('Parametros');
        apps.MESSAGE_LOG('Archivo:'||pFileName);
        apps.MESSAGE_LOG('Tipo de Proceso:'||p_process);
        
        -- Obtiene request_id y user_id
        select nvl(fnd_global.conc_request_id,to_char(sysdate,'YYYYMMDDHH24MISS')),nvl(fnd_global.user_id,-1)
        into v_request_id ,V_USER_ID 
        from dual;
        
        apps.MESSAGE_LOG('INICIA PROCESO CARGA DE LAYOUT ACTUALIZA CADENAS CT');
        
        begin 
        select count (*) into v_count_file 
        from XXBOT.XXBOT_CS_CRUP_CUST_LAY
        where 1=1
        and file_name=pFileName;
        if v_count_file>0
        then 
        apps.MESSAGE_LOG('Nombre de archivo utilizado anteriormente - '||pFileName);
        raise v_exception_file;
        else 
        apps.MESSAGE_LOG('Nombre de archivo correcto - '||pFileName);
        end if;
        end;
        
        -- 0 ¿ Program complete in normal
        -- 1 ¿ Program completed in warning
        -- 2 ¿ Program completed in error
        -- Se inserta la información
                        begin
                            insert into XXBOT.XXBOT_CS_CRUP_CUST_LAY
                            select v_request_id
                                 ,pFileName
                                 ,ROW_NR
                                 ,TO_CHAR(upper(MAX(DECODE (col_nr,1, TRIM(NUMBER_val))))) CUSTOMER_NUMBER
                                 ,null CUSTOMER_ID
                                 ,UPPER (MAX(DECODE (col_nr,2, TRIM(string_val)))) SEND_NOTICE
                                 ,p_process
                                 ,NULL
                                 ,v_user_id user_id
                                 ,sysdate as fechacreacion
                            FROM TABLE(apps.as_read_xlsx.read( apps.as_read_xlsx.file2blob(vgDirectory,pFileName)))
                            WHERE 1=1
                            and row_nr>1
                            group by row_nr;
                            commit;
--                        exception
--                            when others then
--                                RETCODE := 2; --error
--                                ERRBUF := 'Error al insertar en la tabla de validación';
                        end;
        
        --actualizo los customers_id validando que exista la cadena
                              update XXBOT_CS_CRUP_CUST_LAY a
                        set CUSTOMER_ID = (select CUSTOMER_ID from Apps.AR_CUSTOMERS B where 1=1 And B.CUSTOMER_NUMBER = a.CUSTOMER_NUMBER)
                        Where 1=1
                        And a.Request_Id = v_request_id;
                        COMMIT;
                        
                        update XXBOT_CS_CRUP_CUST_LAY a
                        set STATUS_PROCESS = 'No Existe la Cadena en el Módulo'
                        Where 1=1
                        and customer_id is null
                        And a.Request_Id = v_request_id;
                        COMMIT;
-- valido el dato del campo send_notice                         
                        update XXBOT_CS_CRUP_CUST_LAY a
                        set STATUS_PROCESS = 'Dato en Send_notice invalido'
                        Where 1=1
                        and send_notice not in ('Y','N')
                        And a.Request_Id = v_request_id;
                        COMMIT;
        
        --comienzo con las actualizaciones 
        
        
        IF p_process='N' 
        THEN 
            
            for cur in ( select *
                            from XXBOT_CS_CRUP_CUST_LAY
                            where 1=1 
                            and customer_id is not null
                            AND REQUEST_ID=v_request_id)
                            
                            loop
                          V_COUNT:=0;
                          select count (*) into v_count 
                          from xxwebc.xxar_bots_tbl_cust_mails_cs a
                          where 1=1
                          and customer_id=cur.customer_id;
                          
                          if v_count>0 then
                                            
                            update XXBOT_CS_CRUP_CUST_LAY 
                                        set STATUS_PROCESS = 'ERROR-Cadena ya existente'
                                            where 1=1
                                            and request_id=cur.request_id
                                            AND customer_id=cur.customer_id;
                            commit;
                            elsif v_count=0
                            then 
                            insert into xxwebc.xxar_bots_tbl_cust_mails_cs
                            (ID_LOAD,customer_id,CUSTOMER_NUMBER,UO,EMPLOYEE_EMAIL,CUSTOMER_EMAIL,TYPE_OPERATION,PAC,TYPE_TRX,TYPE_PROCESS,CLIENT,SEND_NOTICE,STATUS,DATE_STATUS) values 
                            (XXBOT.XXBOTSEQ_INSERT_CADENA.NEXTVAL,cur.customer_id,cur.customer_number,null,null,null,null,null,null,'CS_AR',null,cur.send_notice,'Activo',sysdate);
                            commit;
                            insert into xxbot.status_warnings_hist
                                                  (ID,REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,STATUS,CReATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATE_BY,PROCESO)
                                                  values (XXBOT.AR_SEQ_STATUS_HIST_CT.NEXTVAL,cur.request_id,cur.customer_id,cur.customer_number,'Activo',sysdate,cur.created_by,sysdate,cur.created_by,'PRO_MAN_ADV');
                                                  commit;  
                            update XXBOT_CS_CRUP_CUST_LAY 
                                        set STATUS_PROCESS = 'Cadena Agregada Correctamente'
                                            where 1=1
                                            and request_id=cur.request_id
                                            AND customer_id=cur.customer_id;
                            end if;
                            COMMIT;
                            END LOOP;
                            
        elsif p_process='A'
        THEN 
        
                            update XXBOT_CS_CRUP_CUST_LAY 
                                        set STATUS_PROCESS = 'ERROR-Cadena ya existente con las mismas caracteristicas'
                                            where 1=1
                                            and request_id=v_request_id
                                            AND customer_id in (select A.customer_id
                                                                      from XXBOT_CS_CRUP_CUST_LAY a,xxwebc.xxar_bots_tbl_cust_mails_cs b
                                                                      where 1=1
                                                                      and a.REQUEST_ID=v_request_id
                                                                      and a.SEND_NOTICE=b.send_notice
                                                                      and a.customer_id=b.customer_id);
                                                                      commit;
                                                                      
                            update XXBOT_CS_CRUP_CUST_LAY 
                                        set STATUS_PROCESS = 'ERROR-Cadena no existe en la lista'
                                            where 1=1
                                            and request_id=v_request_id
                                            AND customer_id not in (select A.customer_id
                                                                      from XXBOT_CS_CRUP_CUST_LAY a,xxwebc.xxar_bots_tbl_cust_mails_cs b
                                                                      where 1=1
                                                                      and a.REQUEST_ID=v_request_id
                                                                      and a.customer_id=b.customer_id);
                                                                      commit;
                                        
                                    for cur in ( select *
                                                    from XXBOT_CS_CRUP_CUST_LAY
                                                    where 1=1 
                                                    and STATUS_PROCESS is  null
                                                    and customer_id is not null
                                                    AND REQUEST_ID=v_request_id)
                                                    
                                                    loop
                                                  V_COUNT:=0;
                                                  select count (*) into v_count 
                                                  from xxwebc.xxar_bots_tbl_cust_mails_cs a
                                                  where 1=1
                                                  AND SEND_NOTICE<>cur.send_notice
                                                  and customer_id=cur.customer_id;
                                                  
                                                  if v_count=1 then
                                                  
                                                    update xxwebc.xxar_bots_tbl_cust_mails_cs
                                                    set send_notice=cur.send_notice,status='Activo',date_status=sysdate
                                                    where 1=1
                                                    and customer_id=cur.customer_id; 
                                                    commit; 
                                                    insert into xxbot.status_warnings_hist
                                                  (ID,REQUEST_ID,CUSTOMER_ID,CUSTOMER_NUMBER,STATUS,CReATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATE_BY,PROCESO)
                                                  values (XXBOT.AR_SEQ_STATUS_HIST_CT.NEXTVAL,cur.request_id,cur.customer_id,cur.customer_number,'Activo',sysdate,cur.created_by,sysdate,cur.created_by,'PRO_MAN_ADV');
                                                  commit;            
                                                    update XXBOT_CS_CRUP_CUST_LAY 
                                                                set STATUS_PROCESS = 'Cadena actualizada Correctamente'
                                                                    where 1=1
                                                                    and request_id=cur.request_id
                                                                    AND customer_id=cur.customer_id;
                                                    commit;
                                                    end if;
                                                    COMMIT;
                                                    END LOOP;
                                                    else 
                                                    apps.MESSAGE_LOG('Ejecución de Proceso Incorrecta');
                                                    
                        end if;
                        commit;
                -- genera excel 
                v_file_name :=
                            'Carga_cad_CT_'
                            || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                            || '.xls';

        -- Se crea el excel
        apps.gen_xl_xml.create_excel (vgDirectory, v_file_name);
        v_worksheet_a:='Reporte';

        --Stylos

       
        apps.gen_xl_xml.create_style ('titulo_pestana',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_bold      => true,
                                 --p_underline => 'Y',
                                 p_backcolor   => '#e7f3fd',
                                 p_border      => 'Y');--'LightBlue'  ); --'#3366FF');
                                 
        apps.gen_xl_xml.create_style ('texto_celda4',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_border      => 'Y');
                                 
                                 
        apps.gen_xl_xml.create_style ('texto_celda',
                                 'Calibri',
                                 'Black',
                                 11,
                                 p_bold      => TRUE);
                                 
apps.gen_xl_xml.create_worksheet_nogrid (v_worksheet_a);
        -- Tamaño de columna
        apps.gen_xl_xml.set_column_width (1,90, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (2, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (3, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (4, 90, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (5, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (6, 150, v_worksheet_a);
        
ra :=1;

        apps.gen_xl_xml.write_cell_char (ra,
                                    1,
                                    v_worksheet_a,
                                    'Request_id',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHar (ra,
                                    2,
                                    v_worksheet_a,
                                    'Num_Lin',
                                    'titulo_pestana');
                                    
        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    3,
                                    v_worksheet_a,
                                    'Cadena',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    4,
                                    v_worksheet_a,
                                    'Envía Not.',
                                    'titulo_pestana');
        
        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    5,
                                    v_worksheet_a,
                                    'Tipo Proceso',
                                    'titulo_pestana');
                                    
        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    6,
                                    v_worksheet_a,
                                    'Estatus',
                                    'titulo_pestana');
                                    
      FOR CUR
            IN (select*
                   from xxbot.XXBOT_CS_CRUP_CUST_LAY
                    WHERE 1=1
                    and request_id=v_request_id
                    order by num_lin_excel asc
                            )
        LOOP
            ra := ra + 1;                            
            apps.gen_xl_xml.write_cell_num (ra,
                                        1,
                                        v_worksheet_a,
                                        CUR.request_id,
                                        'texto_celda4');
                                        
           apps.gen_xl_xml.write_cell_NUM (ra,
                                        2,
                                        v_worksheet_a,
                                        CUR.num_lin_excel,
                                        'texto_celda4');
            
            apps.gen_xl_xml.write_cell_CHAR (ra,
                                        3,
                                        v_worksheet_a,
                                        CUR.customer_number,
                                        'texto_celda4');
 
                  apps.gen_xl_xml.write_cell_CHAR (ra,
                                        4,
                                        v_worksheet_a,
                                        CUR.send_notice,
                                        'texto_celda4');
                                        
             apps.gen_xl_xml.write_cell_CHAR (ra,
                                        5,
                                        v_worksheet_a,
                                        CUR.PROCESS_TYPE,
                                        'texto_celda4');
                                        
            apps.gen_xl_xml.write_cell_CHAR (ra,
                                        6,
                                        v_worksheet_a,
                                        CUR.status_PROCESS,
                                        'texto_celda4');
                                        end loop;
              apps.gen_xl_xml.close_file;
              
              apps.MESSAGE_LOG ('envía correo'); 
             
        v_body :=
               '</b>Reporte del proceso de Actualización o Carga de Nuevas Cadenas al proyecto de CT.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Proceso concluyó Correctamente.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Se adjunta el archivo con la salida del proceso.</b>';
                    
                    


        v_subject :='Notificación Concurrente - '
                    ||v_request_id ;


        apps.cust_mail.send_email (P_DIRECTORY     => vgDirectory,         -- Directorio
                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                              P_RECIPIENT     =>'paul.gutierrez@gepp.com;martha.gutierrez@gepp.com',--cur.description,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                              P_CC            =>NULL,--v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                              P_BCC           =>'alejandro.romo@gepp.com',-- v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                              P_BODY          => v_body,             -- Cuerpo
                              P_ATTACHMENT1   => v_file_name, --Archivo a enviar
                              P_ERROR         => p_err_msg); 
        
                                        BEGIN
                                        UTL_FILE.fremove (vgDirectory, v_file_name);
                                        APPS.MESSAGE_LOG('- Archivo de reporte Borrado-'||v_file_name);
                                        EXCEPTION 
                                        WHEN OTHERS 
                                        then
                                        APPS.MESSAGE_LOG('- Error al Intentar Borrar el Archivo .xls');
                                        END;
                                        COMMIT;
                                        BEGIN
                                        UTL_FILE.fremove (vgDirectory, pFileName);
                                        APPS.MESSAGE_LOG('- Archivo de Usuario Borrado-'||pFileName);
                                        EXCEPTION 
                                        WHEN OTHERS 
                                        then
                                        APPS.MESSAGE_LOG('- Error al Intentar Borrar el Archivo .xlsx');
                                        END;
                                        COMMIT;
    EXCEPTION
    when v_exception_file then 
    apps.MESSAGE_LOG('Nombre de archivo utilizado anteriormente - '||pFileName|| '-- Procesar la solicitud con un nombre de archivo diferente');
    WHEN OTHERS
    THEN
    apps.MESSAGE_LOG ('ERROR- Ocurrió un error al ejecutar el proceso de actualización de cadenas- '||SQLERRM||CHR(10));
    end;
    
    PROCEDURE XXBOT_GET_DATA_PROFILE (P_CADENA IN VARCHAR2 ,P_LOG OUT VARCHAR2,P_MAILBODY OUT VARCHAR2, P_PHONE OUT VARCHAR2,P_SENDMAIL OUT VARCHAR2,P_MAILEC OUT VARCHAR2,P_GS OUT VARCHAR2,P_WAY OUT NUMBER)
    IS
    v_count number:=0;
    V_COUNT1 number:=0;
    V_EXCEPTION EXCEPTION;
    BEGIN 
    
    select count (*) into v_count                                                 
from apps.AR_CONTACTS_V a
,apps.HZ_CONTACT_FIND_V b
,apps.ar_customers d
,apps.hz_parties f
,apps.hz_cust_accounts g
,xxwebc.xxar_bots_tbl_cust_mails_cs h
where 1=1
and d.customer_id =b.customer_id
and a.customer_id=d.customer_id
and a.CONTACT_NUMBER=b.CONTACT_NUMBER
and a.customer_id =b.customer_id
and d.customer_id=h.customer_id
and a.customer_id=h.customer_id
and b.customer_id=h.customer_id
AND g.cust_account_id  =d.customer_id                      
AND g.party_id = F.party_id
and b.CONTACT_NUMBER like 'EC-%'
and a.CONTACT_NUMBER like 'EC-%'
AND B.STATUS='A'
AND a.STATUS='A'
and b.phone is not null
AND d.CUSTOMER_number=P_CADENA;

IF V_COUNT =0 THEN 
RAISE V_EXCEPTION;
END IF;

select count (*) into v_count1
from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a,
XXAR_GRPCBZ_GRPSEGN2_TBL@OCIPROD_TO_ORAPROD19 b
where 1=1
and a.ID_GSN1=b.ID_GSN1
and a.ENABLED_FLAG=b.ENABLED_FLAG
and a.ENABLED_FLAG='Y'
AND SYSDATE BETWEEN a.start_date 
AND NVL (a.end_date,SYSDATE + 1)
AND B.CONTACT_NUMBER IN ( 
select B.CONTACT_NUMBER                                                 
from apps.AR_CONTACTS_V a
,apps.HZ_CONTACT_FIND_V b
,apps.ar_customers d
,apps.hz_parties f
,apps.hz_cust_accounts g
,xxwebc.xxar_bots_tbl_cust_mails_cs h
where 1=1
and d.customer_id =b.customer_id
and a.customer_id=d.customer_id
and a.CONTACT_NUMBER=b.CONTACT_NUMBER
and a.customer_id =b.customer_id
and d.customer_id=h.customer_id
and a.customer_id=h.customer_id
and b.customer_id=h.customer_id
AND g.cust_account_id  =d.customer_id                      
AND g.party_id = F.party_id
and b.CONTACT_NUMBER like 'EC-%'
and a.CONTACT_NUMBER like 'EC-%'
AND B.STATUS='A'
AND a.STATUS='A'
and b.phone is not null
AND d.CUSTOMER_number=P_CADENA)
and rownum<=1;

IF V_COUNT1 =0 THEN 
RAISE V_EXCEPTION;
END IF;

select a.NAME_GRPSEG,a.TXT_ATTRIBUTE1,a.TXT_ATTRIBUTE2,a.TXT_ATTRIBUTE3,a.TXT_ATTRIBUTE4,a.TXT_ATTRIBUTE5 into P_GS,P_LOG,P_MAILBODY,P_PHONE,P_SENDMAIL,P_MAILEC
from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a,
XXAR_GRPCBZ_GRPSEGN2_TBL@OCIPROD_TO_ORAPROD19 b
where 1=1
and a.ID_GSN1=b.ID_GSN1
and a.ENABLED_FLAG=b.ENABLED_FLAG
and a.ENABLED_FLAG='Y'
AND SYSDATE BETWEEN a.start_date 
AND NVL (a.end_date,SYSDATE + 1)
AND B.CONTACT_NUMBER IN ( 
select B.CONTACT_NUMBER                                                 
from apps.AR_CONTACTS_V a
,apps.HZ_CONTACT_FIND_V b
,apps.ar_customers d
,apps.hz_parties f
,apps.hz_cust_accounts g
,xxwebc.xxar_bots_tbl_cust_mails_cs h
where 1=1
and d.customer_id =b.customer_id
and a.customer_id=d.customer_id
and a.CONTACT_NUMBER=b.CONTACT_NUMBER
and a.customer_id =b.customer_id
and d.customer_id=h.customer_id
and a.customer_id=h.customer_id
and b.customer_id=h.customer_id
AND g.cust_account_id  =d.customer_id                      
AND g.party_id = F.party_id
and b.CONTACT_NUMBER like 'EC-%'
and a.CONTACT_NUMBER like 'EC-%'
AND B.STATUS='A'
AND a.STATUS='A'
and b.phone is not null
AND d.CUSTOMER_number=P_CADENA)
and rownum<=1;
P_WAY:=0;

EXCEPTION 
WHEN V_EXCEPTION THEN 
P_WAY:=1;
XXAR_EMAIL_CONFIG_REG (P_CADENA);

     END;
     
    FUNCTION XXBOT_GET_GS_PROFILE (P_CADENA IN VARCHAR2) RETURN VARCHAR2
    IS
    v_count number:=0;
    V_COUNT1 number:=0;
    v_gs varchar2(400):=null;
    V_EXCEPTION EXCEPTION;
    BEGIN 
    
    select count (*) into v_count                                                 
from apps.AR_CONTACTS_V a
,apps.HZ_CONTACT_FIND_V b
,apps.ar_customers d
,apps.hz_parties f
,apps.hz_cust_accounts g
,xxwebc.xxar_bots_tbl_cust_mails_cs h
where 1=1
and d.customer_id =b.customer_id
and a.customer_id=d.customer_id
and a.CONTACT_NUMBER=b.CONTACT_NUMBER
and a.customer_id =b.customer_id
and d.customer_id=h.customer_id
and a.customer_id=h.customer_id
and b.customer_id=h.customer_id
AND g.cust_account_id  =d.customer_id                      
AND g.party_id = F.party_id
and b.CONTACT_NUMBER like 'EC-%'
and a.CONTACT_NUMBER like 'EC-%'
AND B.STATUS='A'
AND a.STATUS='A'
and b.phone is not null
AND d.CUSTOMER_number=P_CADENA;

IF V_COUNT =0 THEN 
RAISE V_EXCEPTION;
END IF;

select count (*) into v_count1
from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a,
XXAR_GRPCBZ_GRPSEGN2_TBL@OCIPROD_TO_ORAPROD19 b
where 1=1
and a.ID_GSN1=b.ID_GSN1
and a.ENABLED_FLAG=b.ENABLED_FLAG
and a.ENABLED_FLAG='Y'
AND SYSDATE BETWEEN a.start_date 
AND NVL (a.end_date,SYSDATE + 1)
AND B.CONTACT_NUMBER IN ( 
select B.CONTACT_NUMBER                                                 
from apps.AR_CONTACTS_V a
,apps.HZ_CONTACT_FIND_V b
,apps.ar_customers d
,apps.hz_parties f
,apps.hz_cust_accounts g
,xxwebc.xxar_bots_tbl_cust_mails_cs h
where 1=1
and d.customer_id =b.customer_id
and a.customer_id=d.customer_id
and a.CONTACT_NUMBER=b.CONTACT_NUMBER
and a.customer_id =b.customer_id
and d.customer_id=h.customer_id
and a.customer_id=h.customer_id
and b.customer_id=h.customer_id
AND g.cust_account_id  =d.customer_id                      
AND g.party_id = F.party_id
and b.CONTACT_NUMBER like 'EC-%'
and a.CONTACT_NUMBER like 'EC-%'
AND B.STATUS='A'
AND a.STATUS='A'
and b.phone is not null
AND d.CUSTOMER_number=P_CADENA)
and rownum<=1;

IF V_COUNT1 =0 THEN 
RAISE V_EXCEPTION;
END IF;

select a.NAME_GRPSEG  into V_GS
from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a,
XXAR_GRPCBZ_GRPSEGN2_TBL@OCIPROD_TO_ORAPROD19 b
where 1=1
and a.ID_GSN1=b.ID_GSN1
and a.ENABLED_FLAG=b.ENABLED_FLAG
and a.ENABLED_FLAG='Y'
AND SYSDATE BETWEEN a.start_date 
AND NVL (a.end_date,SYSDATE + 1)
AND B.CONTACT_NUMBER IN ( 
select B.CONTACT_NUMBER                                                 
from apps.AR_CONTACTS_V a
,apps.HZ_CONTACT_FIND_V b
,apps.ar_customers d
,apps.hz_parties f
,apps.hz_cust_accounts g
,xxwebc.xxar_bots_tbl_cust_mails_cs h
where 1=1
and d.customer_id =b.customer_id
and a.customer_id=d.customer_id
and a.CONTACT_NUMBER=b.CONTACT_NUMBER
and a.customer_id =b.customer_id
and d.customer_id=h.customer_id
and a.customer_id=h.customer_id
and b.customer_id=h.customer_id
AND g.cust_account_id  =d.customer_id                      
AND g.party_id = F.party_id
and b.CONTACT_NUMBER like 'EC-%'
and a.CONTACT_NUMBER like 'EC-%'
AND B.STATUS='A'
AND a.STATUS='A'
and b.phone is not null
AND d.CUSTOMER_number=P_CADENA)
and rownum<=1;

RETURN V_GS;

EXCEPTION 
WHEN V_EXCEPTION THEN 
RETURN NULL;
     END;
     
procedure XXAR_EMAIL_CONFIG_REG (P_CADENA varchar2)
IS
        v_SENDER             VARCHAR2 (1000) := 'acobranzacs@gepp.com';
        v_subject            VARCHAR2 (1000);
        v_to_recipients      VARCHAR2 (1000);
        v_cc_recipients      VARCHAR2 (1000);
        v_bcc_recipients     VARCHAR2 (1000);
        p_err_msg            NUMBER;
        v_valid_env       number;
        gv_dir               VARCHAR (50) := 'CUST_AR_BOTS';
        v_file_name          VARCHAR2 (3000);
        v_body               VARCHAR2 (4000);
 v_GC  VARCHAR2 (400);
 v_region  VARCHAR2 (400);
 v_exception exception;
 v_count number:=0;
 v_count_r number:=0;
        
        
        BEGIN
        
        select count (*) into v_count --distinct (a.CONTACT_NUMBER),h.customer_number                                                
from apps.AR_CONTACTS_V a
,apps.HZ_CONTACT_FIND_V b
,apps.ar_customers d
,apps.hz_parties f
,apps.hz_cust_accounts g
,xxwebc.xxar_bots_tbl_cust_mails_cs h
where 1=1
and d.customer_id =b.customer_id
and a.customer_id=d.customer_id
and a.CONTACT_NUMBER=b.CONTACT_NUMBER
and a.customer_id =b.customer_id
and d.customer_id=h.customer_id
and a.customer_id=h.customer_id
and b.customer_id=h.customer_id
AND g.cust_account_id  =d.customer_id                      
AND g.party_id = F.party_id
and b.CONTACT_NUMBER like 'EC-%'
and a.CONTACT_NUMBER like 'EC-%'
AND B.STATUS='A'
AND a.STATUS='A'
and b.phone is not null
AND d.CUSTOMER_number=p_cadena;

        
        
        
        if v_count > 0 then
        
        select distinct (a.CONTACT_NUMBER) into v_GC                                               
from apps.AR_CONTACTS_V a
,apps.HZ_CONTACT_FIND_V b
,apps.ar_customers d
,apps.hz_parties f
,apps.hz_cust_accounts g
,xxwebc.xxar_bots_tbl_cust_mails_cs h
where 1=1
and d.customer_id =b.customer_id
and a.customer_id=d.customer_id
and a.CONTACT_NUMBER=b.CONTACT_NUMBER
and a.customer_id =b.customer_id
and d.customer_id=h.customer_id
and a.customer_id=h.customer_id
and b.customer_id=h.customer_id
AND g.cust_account_id  =d.customer_id                      
AND g.party_id = F.party_id
and b.CONTACT_NUMBER like 'EC-%'
and a.CONTACT_NUMBER like 'EC-%'
AND B.STATUS='A'
AND a.STATUS='A'
and b.phone is not null
AND d.CUSTOMER_number=p_cadena;

            SELECT count (*) into v_count_r
                    FROM (SELECT CASE 
             WHEN TO_NUMBER(REPLACE(v_GC,'EC-','')) BETWEEN TO_NUMBER(REPLACE (ATTRIBUTE1,'EC-','')) AND TO_NUMBER(REPLACE (ATTRIBUTE2,'EC-','')) THEN SHORT_NAME ELSE 'NO ENCONTRADO' END GS
            FROM XXAR_GRPCBZ_GS_REG_TBL@OCIPROD_TO_ORAPROD19
            WHERE 1=1)
            WHERE 1=1
            AND GS<>'NO ENCONTRADO';
            
            if v_count_r>0 then 
            
             SELECT GS into v_region
                    FROM (SELECT CASE 
             WHEN TO_NUMBER(REPLACE(v_GC,'EC-','')) BETWEEN TO_NUMBER(REPLACE (ATTRIBUTE1,'EC-','')) AND TO_NUMBER(REPLACE (ATTRIBUTE2,'EC-','')) THEN SHORT_NAME ELSE 'NO ENCONTRADO' END GS
            FROM XXAR_GRPCBZ_GS_REG_TBL@OCIPROD_TO_ORAPROD19
            WHERE 1=1)
            WHERE 1=1
            AND GS<>'NO ENCONTRADO';
            ELSE 
            v_region:='No Configurado';
            END IF;
            
            
        
        else 
        
        v_GC:='No Configurado';
        v_region:='No Configurado';
        
        end if;
        
             
        v_body := '</b>De acuerdo a la validación del sistema, se identificó que la siguiente cadena no cuenta con algún dato para identificar su Grupo de Seguridad.</b>'
                    || '<br>'
                    || '<br>'
                    || '<b>     Cadena: </b>'||p_cadena||' </b>'
                    || '<br>'
                    || '<br>'
                    || '<b>     Grupo de Cobranza: </b>'||v_GC||' </b>'
                    || '<br>'
                    || '<br>'
                    || '<b>     Región: </b>'||v_region||' </b>'
                    || '<br>'
                    || '<br>'
                    || '<b>NOTA IMPORTANTE: </b>'|| '</b>La región es calculada conforme al catálogo de regiones definido por el usuario y se toma como base el Grupo de Cobranza al que pertenece la cadena.</b>';


        v_subject :=
               ' URGENTE - Configuración de Cadenas Faltantes';


        apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                              P_RECIPIENT     =>'eduardo.ruizmares@gepp.com;Kenya.Perez@gepp.com;martha.gutierrez@gepp.com',--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                              P_CC            =>NULL,--v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                              P_BCC           =>'alejandro.romo@gepp.com',-- v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                              P_BODY          => v_body,             -- Cuerpo
                              P_ATTACHMENT1   => v_file_name, --Archivo a enviar
                              P_ERROR         => p_err_msg);
                              
        apps.MESSAGE_LOG ('Se envió correo por falta de configuración de Grupo de Seguridad o Grupo de Cobranza');

        COMMIT; 
        EXCEPTION
        when v_exception then apps.MESSAGE_LOG ('ERROR- Ocurrió un error al envíar correo -(Errores de Configuración  CT (NO SE ENCONTRÓ EL GRUPO DE SEGURIDAD))- '||SQLERRM||CHR(10));
    WHEN OTHERS
    THEN
    apps.MESSAGE_LOG ('ERROR- Ocurrió un error al envíar correo -(Errores de Configuración  CT)- '||SQLERRM||CHR(10));
    --DBMS_OUTPUT.PUT_LINE('ERROR- Ocurrió un error al envíar correo -(Errores de Configuración  CT)- '||SQLERRM||CHR(10));
    end;
    procedure XXAR_EMAIL_TK_CREATION (P_MAIL IN VARCHAR2,P_GS IN VARCHAR2)
IS
        v_SENDER             VARCHAR2 (1000) := 'acobranzacs@gepp.com';
        v_subject            VARCHAR2 (1000);
        v_to_recipients      VARCHAR2 (1000);
        v_cc_recipients      VARCHAR2 (1000);
        v_bcc_recipients     VARCHAR2 (1000);
        p_err_msg            NUMBER;
        v_valid_env       number;
        gv_dir               VARCHAR (50) := 'CUST_AR_BOTS';
        v_file_name          VARCHAR2 (3000);
        v_body               VARCHAR2 (4000);
 v_exception exception;
        
        
        BEGIN
        
        
        
             
        v_body := '</b>De acuerdo a la validación del sistema, no fue posible encontrar un usuario conforme a las reglas establecidas para generar el ticket de suspensión de cadenas en el Proyecto de CT.</b>'
                    || '<br>'
                    || '<br>'
                    || '<b>     Cuenta de correo: </b>'||p_mail||' </b>'
                    || '<br>'
                    || '<br>'
                    || '<b>     Grupo de Seguridad donde se encuentra configurada la cuenta de correo: </b>'||p_gs||' </b>'
                    || '<br>'
                    || '<br>'
                    || '<b>NOTA IMPORTANTE: </b>'|| '</b>El ticket de suspensión deberá ser generado de forma manual, de igual forma favor de realizar los ajustes correspondientes.</b>';


        v_subject :=
               ' URGENTE - Error en Alta de Ticket de Suspensión de Cadenas CT';


        apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                              P_RECIPIENT     =>'eduardo.ruizmares@gepp.com;Kenya.Perez@gepp.com;martha.gutierrez@gepp.com',--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                              P_CC            =>NULL,--v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                              P_BCC           =>'alejandro.romo@gepp.com;erick.cardenasrodriguez@gepp.com',-- v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                              P_BODY          => v_body,             -- Cuerpo
                              P_ATTACHMENT1   => v_file_name, --Archivo a enviar
                              P_ERROR         => p_err_msg);
                              
        apps.MESSAGE_LOG ('Se envió correo por falta de configuración de usuario para alta de ticket');

        COMMIT; 
        EXCEPTION
        when v_exception then apps.MESSAGE_LOG ('ERROR- Ocurrió un error al envíar correo -(Errores de Configuración  CT (Alta de Ticket Suspensión))- '||SQLERRM||CHR(10));
    WHEN OTHERS
    THEN
    apps.MESSAGE_LOG ('ERROR- Ocurrió un error al envíar correo -(Errores de Configuración  CT "Alta Ticket Suspensión")- '||SQLERRM||CHR(10));
    --DBMS_OUTPUT.PUT_LINE('ERROR- Ocurrió un error al envíar correo -(Errores de Configuración  CT)- '||SQLERRM||CHR(10));
    end;
    END XXAR_PAY_NOTIF_SYSTEM;