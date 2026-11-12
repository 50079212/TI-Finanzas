CREATE OR REPLACE PACKAGE BODY XXWEBC.XXCASH_CASHLESS_PKG
    IS
	
--	$Id: XXCASH_CASHLESS_PKG.pkb 4863 2026-01-21 23:43:50Z vvelasco $
--	$URL: http://mxapediprdl.gepp.pvt:18080/svn/r12/Developer/CASH/SantaderCashless/XXCASH_CASHLESS_PKG.pkb $
	
   PROCEDURE MESSAGE_LOG (P_MESSAGE IN VARCHAR2)
   AS
   BEGIN
      APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, P_MESSAGE);
      --DBMS_OUTPUT.PUT_LINE(P_MESSAGE);
   --MESSAGE_LOG ('LOG: ' || P_MESSAGE);
   END MESSAGE_LOG;

   /* CONTROL DE MENSAJES IMPRESOS EN EL OUPUT */
   PROCEDURE MESSAGE_OUTPUT (P_MESSAGE IN VARCHAR2)
   AS
   BEGIN
      APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, P_MESSAGE);
      --MESSAGE_LOG ('OUTPUT: ' || P_MESSAGE);
      --DBMS_OUTPUT.PUT_LINE(P_MESSAGE);
   END MESSAGE_OUTPUT;

   FUNCTION get_field (      p_data        IN VARCHAR2,
                                p_index       IN NUMBER,
                                p_character   IN VARCHAR2)
             RETURN VARCHAR2
          IS
             v_text          VARCHAR2 (32767);
             v_counter       NUMBER;
             v_firstcomma    NUMBER;
             v_secondcomma   NUMBER;
          BEGIN
             IF p_index = 1
             THEN
                v_firstcomma := 0;
             ELSE
                v_firstcomma :=
                   INSTR (p_data,
                          p_character,
                          1,
                          p_index - 1);
             END IF;

             v_secondcomma :=
                INSTR (p_data,
                       p_character,
                       1,
                       p_index);

             IF (v_secondcomma = 0 AND v_firstcomma <> 0)
             THEN
                v_secondcomma := LENGTH (p_data) + 1;
             END IF;

             v_text :=
                SUBSTR (p_data,
                        v_firstcomma + 1,
                        v_secondcomma - v_firstcomma - 1);

             IF v_firstcomma = v_secondcomma
             THEN
                v_text := NULL;
             END IF;

             RETURN v_text;
    END get_field;


    PROCEDURE READ_SEND_FILE_SANTANDER
    IS
        CURSOR CTXT
        IS 
        SELECT COLUMN_VALUE FILENAME
        FROM TABLE(APPS.LIST_FILES('/u07/cargas/ar/cashless/santanderfiles')) 
        WHERE 1=1
        AND COLUMN_VALUE != 'hist'
        and COLUMN_VALUE like '%df_.txt'
        --and rownum<=1
        order by 1;

        CURSOR CFILES(P_ID_LOAD varchar2)
        IS
        SELECT ID,FILE_NAME
        FROM XXCASH_HEAD_FILE_SANT_TBL
        WHERE 1=1
        AND ID_LOAD = P_ID_LOAD
        and status = 'NUEVO'
        ORDER BY 1;

        V_DIR VARCHAR2(200) := 'CUST_AR_CASHLESS_SANTANDER';   --CUST_AR_CASHLESS_SANTANDER_HIS
        V_ID_LOAD NUMBER;
        V_ID NUMBER;

        V_FILEHANDLER      UTL_FILE.FILE_TYPE;
        V_NEWLINE          VARCHAR2 (32767);

        V_NUMLIN NUMBER :=0;

        P_FILENAME VARCHAR2(1000);

        V_COL1  VARCHAR2(1000);
        V_COL2  VARCHAR2(1000);
        V_REFERENCIA_SIO  VARCHAR2(1000);
        V_COL4  VARCHAR2(1000);
        V_COL5  VARCHAR2(1000);
        V_TIPO_PAGO  VARCHAR2(1000);
        V_COL7  VARCHAR2(1000);
        V_COL8  VARCHAR2(1000);
        V_COL9  VARCHAR2(1000);
        V_COL10  VARCHAR2(1000);
        V_COL11  VARCHAR2(1000);
        V_COL12  VARCHAR2(1000);
        V_COL13  VARCHAR2(1000);
        V_MONTO  NUMBER(20,2);
        V_MONEDA  VARCHAR2(1000);
        V_FECHA_OPERACION  DATE;
        V_HORA_OPERACION  DATE;
        V_TIPO_TARJETA  VARCHAR2(1000);
        V_MARCA_TARJETA  VARCHAR2(1000);
        V_BANCO_EMISOR  VARCHAR2(1000);
        V_TIPO_OPERACION  VARCHAR2(1000);
        V_FECHA_DEPOSITO  DATE;
        V_UO_EBS VARCHAR2 (200);
        V_UO_EBS_DESC VARCHAR2 (200);
        V_REGIONCONTABLE VARCHAR2(1000);
        V_STATUS_L VARCHAR2(1000);
        V_MSJ_STATUS_L VARCHAR2(1000);

        V_CIA_NAME VARCHAR2(100);
        V_UNIDAD_OPERATIVA VARCHAR2(10);
        V_SEGMENT5 VARCHAR2(10);
        V_SEGMENT6 VARCHAR2(10);

        V_EXISTE_ARCHIVO NUMBER;
        err_num NUMBER;
        err_msg VARCHAR2(1000);

        v_check_point number;
        v_last_update_date date;
     BEGIN

        v_check_point := 1;
        V_ID_LOAD := nvl(apps.fnd_global.conc_request_id,to_char(sysdate,'yyyymmddhh24miss'));

        IF V_ID_LOAD = -1 THEN
            V_ID_LOAD := to_char(sysdate,'yyyymmddhh24miss');
        END IF;
        -- Se inserta en el cabecero los archivos a procesar
        FOR REC IN CTXT 
        LOOP
            V_EXISTE_ARCHIVO := 0;
            P_FILENAME := REC.FILENAME;
            -- Si existe el registro en status NUEVO lo intenta reprocesar, por lo tanto lo renombra y cambia a estatus WARNING
            update XXCASH_HEAD_FILE_SANT_TBL
            set file_name = file_name ||'_ERR'
                ,msj_status = 'ESTE ARCHIVO AL ESTAR EN ESTATUS NUEVO SE REEMPLAZARA POR ESTE PROCESAMIENTO'
                ,LAST_UPDATE_DATE = SYSDATE
                ,status = 'ADVERTENCIA'
            where 1=1
            and file_name = P_FILENAME
            AND status = 'NUEVO'; 

            -- Si existe en status diferente de NUEVO lo inserta en el cabecero como error y ya no lo procesa.
            -- Se inserta el cabecero del archivo
            SELECT XXWEBC.READ_SEND_FILE_SANTANDER_SEQ.NEXTVAL 
               INTO V_ID 
            FROM DUAL;

            SELECT COUNT(*) 
            INTO V_EXISTE_ARCHIVO
            FROM XXCASH_HEAD_FILE_SANT_TBL            
            where 1=1
            and file_name = P_FILENAME
            AND status != 'NUEVO';


            IF  V_EXISTE_ARCHIVO > 1 THEN

                INSERT INTO XXCASH_HEAD_FILE_SANT_TBL
                        (id,file_name,creation_date,last_update_date,STATUS,id_load,msj_status,SENT_TO_APEX,SENT_DATE)
                values  (v_id,P_FILENAME,sysdate,sysdate,'ERROR1',V_ID_LOAD,'Este Nombre de Archivo ya fue procesado',0,sysdate);
                commit;
            ELSE            
                INSERT INTO XXCASH_HEAD_FILE_SANT_TBL
                        (id,file_name,creation_date,last_update_date,STATUS,id_load,SENT_TO_APEX,SENT_DATE)
                values  (v_id,P_FILENAME,sysdate,sysdate,'NUEVO',V_ID_LOAD,0,sysdate);
                commit;
            END IF;
        END LOOP;

        FOR REC IN CFILES(V_ID_LOAD) 
        LOOP
            BEGIN
                --DBMS_OUTPUT.PUT_LINE(REC.FILE_NAME);
                V_ID := REC.ID;
                P_FILENAME := REC.FILE_NAME;
                V_NUMLIN := 0;

                V_FILEHANDLER := UTL_FILE.FOPEN (V_DIR, P_FILENAME,'R' );

                IF UTL_FILE.IS_OPEN (V_FILEHANDLER) THEN
                    LOOP                                                    
                         BEGIN                            
                            UTL_FILE.GET_LINE (V_FILEHANDLER, V_NEWLINE, 32767);
                         EXCEPTION 
                           WHEN NO_DATA_FOUND THEN 
                                -- SALE DEL CICLO
                                EXIT;
                         END;                          

                         V_NUMLIN := V_NUMLIN + 1;

                         V_COL1  := get_field (V_NEWLINE, 1,'|');


                         V_COL2  := get_field (V_NEWLINE, 2,'|');
                         V_REFERENCIA_SIO  := get_field (V_NEWLINE, 3,'|');
                         V_COL4  := get_field (V_NEWLINE, 4,'|');
                         V_COL5  := get_field (V_NEWLINE, 5,'|');
                         V_TIPO_PAGO  := get_field (V_NEWLINE, 6,'|');
                         V_COL7  := get_field (V_NEWLINE, 7,'|');
                         V_COL8  := get_field (V_NEWLINE, 8,'|');
                         V_COL9  := get_field (V_NEWLINE, 9,'|');
                         V_COL10 := get_field (V_NEWLINE, 10,'|');
                         V_COL11 := get_field (V_NEWLINE, 11,'|');
                         V_COL12 := get_field (V_NEWLINE, 12,'|');
                         V_COL13 := get_field (V_NEWLINE, 13,'|');
                         V_MONTO := get_field (V_NEWLINE, 14,'|');
                         --dbms_output.put_line('V_MONTO:'||V_MONTO);
                         V_MONEDA  := get_field (V_NEWLINE, 15,'|');
                         V_FECHA_OPERACION  := to_date(get_field (V_NEWLINE, 16,'|'),'dd/mm/yyyy');
                         --dbms_output.put_line('V_FECHA_OPERACION:'||get_field (V_NEWLINE, 16,'|'));
                         V_HORA_OPERACION  := to_date(get_field (V_NEWLINE, 17,'|'),'HH24:MI:SS');
                         --dbms_output.put_line('V_HORA_OPERACION:'||get_field (V_NEWLINE, 17,'|'));
                         V_TIPO_TARJETA  := get_field (V_NEWLINE, 18,'|');
                         V_MARCA_TARJETA  := get_field (V_NEWLINE, 19,'|');
                         V_BANCO_EMISOR  := get_field (V_NEWLINE, 20,'|');
                         V_TIPO_OPERACION  := get_field (V_NEWLINE, 21,'|');
                         V_FECHA_DEPOSITO  := to_date(get_field (V_NEWLINE,22,'|'),'dd/mm/yyyy');--get_field (V_NEWLINE, 22,'|'); 
                         --dbms_output.put_line('V_FECHA_DEPOSITO:'||get_field (V_NEWLINE, 22,'|'));

                         V_REGIONCONTABLE := GET_UOREGION_REGION(regexp_substr(v_referencia_sio,'[^-]+',1,1));

                         V_CIA_NAME := REPLACE(V_COL13,' 1','');
                         V_UNIDAD_OPERATIVA := regexp_substr(v_referencia_sio,'[^-]+',1,1);


                         /*select a.uo_region, a.region
                         into V_UO_EBS, V_UO_EBS_DESC
                         from apps.xxcash_uo_view a
                         where regexp_substr(v_referencia_sio,'[^-]+',1,1) = a.uo;*/
                         V_STATUS_L := 'NUEVO';
                         V_MSJ_STATUS_L := NULL;

                         declare
                            v_count_L NUMBER;
                         begin
                             select COUNT(*)
                             INTO v_count_L
                             from XXCASH_LINES_FILE_SANT_TBL
                             where 1=1                
                             and REFERENCIA_SIO =  V_REFERENCIA_SIO;

                             IF v_count_L >0 THEN
                                -- existe la referencia por lo que se marcará como error
                                V_STATUS_L := 'ERROR';
                                V_MSJ_STATUS_L := 'La referencia [' || V_REFERENCIA_SIO || '] ya existe y debe ser unica.';
                                V_REFERENCIA_SIO := V_REFERENCIA_SIO || '~ERRR~'||V_ID ||'~'||V_NUMLIN;
                             END IF;

                         end;

                         INSERT INTO XXCASH_LINES_FILE_SANT_TBL
                                (   ID,
                                    LINE_NUMBER,
                                    COL1,
                                    COL2,
                                    REFERENCIA_SIO,
                                    COL4,
                                    COL5,
                                    TIPO_PAGO,
                                    COL7,
                                    COL8,
                                    COL9,
                                    COL10,
                                    COL11,
                                    COL12,
                                    COL13,
                                    MONTO,
                                    MONEDA,
                                    FECHA_OPERACION,
                                    HORA_OPERACION,
                                    TIPO_TARJETA,
                                    MARCA_TARJETA,
                                    BANCO_EMISOR,
                                    TIPO_OPERACION,
                                    FECHA_DEPOSITO,
                                    ESTATUS,
                                    CREATION_DATE,
                                    REGION,
                                    LAST_UPDATED_DATE
                                    ,CIA_NAME
                                    ,UNIDAD_OPERATIVA
                                    --,SEGMENT5
                                    --,SEGMENT6
                                    --UO_EBS,
                                    --UO_EBS_DESC
                                    ,MSJ_STATUS
                                    )
                              VALUES(V_ID,
                                    V_NUMLIN,
                                    V_COL1,
                                    V_COL2,
                                    V_REFERENCIA_SIO,
                                    V_COL4,
                                    V_COL5,
                                    V_TIPO_PAGO,
                                    V_COL7,
                                    V_COL8,
                                    V_COL9,
                                    V_COL10,
                                    V_COL11,
                                    V_COL12,
                                    V_COL13,
                                    V_MONTO,
                                    V_MONEDA,
                                    V_FECHA_OPERACION,
                                    V_HORA_OPERACION,
                                    V_TIPO_TARJETA,
                                    V_MARCA_TARJETA,
                                    V_BANCO_EMISOR,
                                    V_TIPO_OPERACION,
                                    V_FECHA_DEPOSITO,
                                    V_STATUS_L,--'NUEVO',
                                    SYSDATE,
                                    --V_UO_EBS,
                                    --v_uo_ebs_desc
                                    V_REGIONCONTABLE
                                    ,SYSDATE
                                    ,V_CIA_NAME
                                    ,V_UNIDAD_OPERATIVA
                                    --,V_SEGMENT5
                                    --,V_SEGMENT6
                                    ,V_MSJ_STATUS_L
                                    );    
                            COMMIT;
                            -- Validamos que la referencia bancaria no exista ya que es la llave primaria de la tabla a nivel lineas

                              --dbms_output.put_line('PASO V_NUMLIN:'||P_FILENAME || '-'||V_NUMLIN);
                    END LOOP;                    
                    UTL_FILE.FCLOSE(V_FILEHANDLER); 

                END IF;
                dbms_output.put_line('CIERRA:'||P_FILENAME || '-'||V_NUMLIN);


                begin
                    UTL_FILE.FCOPY (
                                    V_DIR, -- THIS IS A ORACLE DIRECTORY
                                    P_FILENAME, --FILE NAME
                                    'CUST_AR_CASHLESS_SANTANDER_HIS'   , -- THIS IS A ORACLE DIRECTORY
                                    P_FILENAME ); -- DESTINATION FILE
                end;  
                COMMIT;              
                BEGIN
                    UTL_FILE.FREMOVE (V_DIR,P_FILENAME);   
                    commit;             
                END;

                update XXCASH_HEAD_FILE_SANT_TBL
                set status = 'COMPLETE'
                    , last_update_date = sysdate
                    ,rows_num = v_numlin
                where 1=1
                and id = v_id
                and id_load = V_ID_LOAD;

                commit;
            EXCEPTION
                WHEN OTHERS THEN
                    err_num := SQLCODE;
                    err_msg := SUBSTR(SQLERRM,1,100);

                     update XXCASH_HEAD_FILE_SANT_TBL
                    set status = 'ERROR FILE'
                        , last_update_date = sysdate
                        ,msj_status = err_num || '-'|| err_msg  
                    where 1=1
                    and id = v_id
                    and id_load = V_ID_LOAD;
                    COMMIT;
            END;
       END LOOP;  --REC

       -- TODO:
            -- Falta ver si traemos información de otros dias?
            -- marcar en CASH que tomamos la info?
            -- Si regresa error, ¿solo mandamos mensaje o abortamos el proceso?


       -- Extrameos la informacion de CODI que se encuentra en el modulo de CASH MANAGMENT.
        BEGIN
            XXWEBC.XXCM_CODI_CASH_PRC (sysdate - 1, err_msg);

            if err_msg like 'err%' then
                MESSAGE_OUTPUT (err_msg);
            end if;


        END;

        UPDATE XXCASH_LINES_FILE_SANT_TBL bancol
        SET (SEGMENT5, SEGMENT6) = (SELECT regexp_substr(lookup_code, '[^-"]+', 1, 2) segment5
                                           ,regexp_substr(lookup_code, '[^-"]+', 1, 3) segment6
                                    FROM apps.fnd_lookup_values       fl
                                    WHERE 1=1
                                    AND fl.language = 'ESA'
                                    AND fl.lookup_type = 'XXCASH_REG_CASHLESS_LV'
                                    AND regexp_substr(fl.description, '[^|"]+', 1, 2) = TRIM(bancol.region)
                                    )
            --,cia_name = REPLACE(cOL13,' 1','')
            --,unidad_operativa = regexp_substr(REFERENCIA_SIO,'[^-]+',1,1)
            ,period_name = to_char(fecha_operacion,'MON-YY','NLS_DATE_LANGUAGE=SPANISH')
            ,org_id = (select organization_id
                        from apps.hr_all_organization_units
                        where 1=1
                        and name = cia_name)
        WHERE 1=1
        AND ESTATUS = 'NUEVO';
        commit;

       v_check_point :=2;


       -- Empieza el proceso para pasar la información de Oracle eBS a la BD 19c de Apex
--       UPDATE XXCASH_HEAD_FILE_SANT_TBL
--            SET SENT_TO_APEX = 0
--                ,SENT_DATE = SYSDATE
--        where 1=1
--        and status = 'COMPLETE';
--        commit;
        -- coloco en 0 los encabezados de archivos que se van a pasar a la BD Apex

        -- Se insertan los archivos que estan sen sent_to_apex=0
        for cur in (select *
                    from XXCASH_HEAD_FILE_SANT_TBL
                    where 1=1
                    and SENT_TO_APEX = 0)
        loop
            insert into cfdi_ap_ar.XXCASH_LINES_FILE_SANT_TBL@OCIPROD_TO_ORAPROD19(
                ID,
                LINE_NUMBER,
                COL1,
                COL2,
                REFERENCIA_SIO,
                COL4,
                COL5,
                TIPO_PAGO,
                COL7,
                COL8,
                COL9,
                COL10,
                COL11,
                COL12,
                COL13,
                MONTO,
                MONEDA,
                FECHA_OPERACION,
                HORA_OPERACION,
                TIPO_TARJETA,
                MARCA_TARJETA,
                BANCO_EMISOR,
                TIPO_OPERACION,
                FECHA_DEPOSITO,
                ESTATUS,
                CREATION_DATE,
                UO_EBS,
                UO_EBS_DESC,
                REGION,
                LAST_UPDATED_DATE,
                CIA_NAME
                ,UNIDAD_OPERATIVA
                ,SEGMENT5
                ,SEGMENT6
                ,period_name
                ,org_id
                ,MSJ_STATUS)
            select ID,
                LINE_NUMBER,
                COL1,
                COL2,
                REFERENCIA_SIO,
                COL4,
                COL5,
                TIPO_PAGO,
                COL7,
                COL8,
                COL9,
                COL10,
                COL11,
                COL12,
                COL13,
                MONTO,
                MONEDA,
                FECHA_OPERACION,
                HORA_OPERACION,
                TIPO_TARJETA,
                MARCA_TARJETA,
                BANCO_EMISOR,
                TIPO_OPERACION,
                FECHA_DEPOSITO,
                ESTATUS,
                CREATION_DATE,
                UO_EBS,
                UO_EBS_DESC,
                REGION,
                LAST_UPDATED_DATE,
                CIA_NAME
                ,UNIDAD_OPERATIVA
                ,SEGMENT5
                ,SEGMENT6
                ,period_name
                ,org_id
                ,MSJ_STATUS
            from XXCASH_LINES_FILE_SANT_TBL l
            where 1=1
            and l.id = cur.id;

            insert into cfdi_ap_ar.XXCASH_HEAD_FILE_SANT_TBL@OCIPROD_TO_ORAPROD19(
                    ID,
                    FILE_NAME,
                    STATUS,
                    ID_LOAD,
                    CREATION_DATE,
                    LAST_UPDATE_DATE,
                    SENT_TO_APEX,
                    SENT_DATE,
                    MSJ_STATUS,
                    ROWS_NUM)
            select ID,
                    FILE_NAME,
                    STATUS,
                    ID_LOAD,
                    CREATION_DATE,
                    LAST_UPDATE_DATE,
                    SENT_TO_APEX,
                    SENT_DATE,
                    MSJ_STATUS,
                    ROWS_NUM
            from XXCASH_HEAD_FILE_SANT_TBL
            where 1=1
            and sent_to_apex= 0
            and id = cur.id;

            commit;

            --Actualizo el estatus sent_to_apex
            v_last_update_date := sysdate;
            update XXCASH_HEAD_FILE_SANT_TBL
            set sent_to_apex = 1
                ,SENT_DATE = v_last_update_date
            where 1=1
            and id = cur.id;

            update cfdi_ap_ar.XXCASH_HEAD_FILE_SANT_TBL@OCIPROD_TO_ORAPROD19
            set sent_to_apex = 1
                ,SENT_DATE = v_last_update_date
            where 1=1
            and id = cur.id;

            commit;
        end loop;

    /*EXCEPTION
        WHEN OTHERS THEN
            if v_check_point = 1 then
                update XXCASH_HEAD_FILE_SANT_TBL
                set status = 'ERROR GENERAL'
                    , last_update_date = sysdate
                where 1=1
                and id = v_id
                and id_load = V_ID_LOAD;
                commit;
             elsif v_check_point = 2 then
                UPDATE XXCASH_HEAD_FILE_SANT_TBL
                SET SENT_TO_APEX = -1
                    ,SENT_DATE = SYSDATE
                where 1=1
                and SENT_TO_APEX = 0;
                commit;
             end if;*/
    END READ_SEND_FILE_SANTANDER;

    FUNCTION GET_UOREGION_REGION(pin_uo in varchar2) RETURN VARCHAR2
    IS
        V_RETURN VARCHAR2(4000);
    BEGIN
      SELECT region_contable
        INTO V_RETURN
      FROM XXCASH_UO_VIEW
      where 1=1
         AND uo = Pin_Uo;

        RETURN V_RETURN;
    EXCEPTION
        WHEN OTHERS THEN
            V_RETURN := 'NOMAPEADA';
            RETURN V_RETURN;
    END GET_UOREGION_REGION;

    PROCEDURE EXEC_CASHLESS(o_errbuf OUT VARCHAR2, o_retcode OUT VARCHAR)
    IS
        v_out varchar2(1000);
        V_NOFUNCION NUMBER;
    BEGIN
        MESSAGE_LOG('INICIA PROCESO DE CASHLESS');
        MESSAGE_LOG(' ');
        MESSAGE_LOG('***************************************');
        MESSAGE_LOG('INICIA LECTURA DE ARCHIVOS DEL BANCO -> READ_SEND_FILE_SANTANDER');
        READ_SEND_FILE_SANTANDER;
        MESSAGE_LOG('TERMINA LECTURA DE ARCHIVOS DEL BANCO');
        MESSAGE_LOG(' ');
        MESSAGE_LOG('***************************************');
        MESSAGE_LOG('INICIA LECTURA DE POLIZAS -> imp_gl_fnc'); 
            v_out := NULL;
            v_out := cfdi_ap_ar.XXCASH_APEX_CASHLESS_PKG.imp_gl_fnc@OCIPROD_TO_ORAPROD19;
        MESSAGE_LOG('TERMINA -> imp_gl_fnc -> ' || v_out);
        MESSAGE_LOG(' ');
        MESSAGE_LOG('***************************************');
        MESSAGE_LOG('INICIA LECTURA DE INFORMACION DETALLE SIO -> imp_dw_sio_fnc'); 
            v_out := NULL;
            v_out := cfdi_ap_ar.XXCASH_APEX_CASHLESS_PKG.imp_dw_sio_fnc@OCIPROD_TO_ORAPROD19;
        MESSAGE_LOG('TERMINA -> imp_dw_sio_fnc -> ' || v_out);
        MESSAGE_LOG(' ');
        MESSAGE_LOG('***************************************');
        MESSAGE_LOG('INICIA CONCILIACION SIO VS GL -> ConciliaSIOvsGL'); 
            v_out := NULL;
            v_out := cfdi_ap_ar.XXCASH_APEX_CASHLESS_PKG.ConciliaSIOvsGL@OCIPROD_TO_ORAPROD19;
        MESSAGE_LOG('TERMINA -> ConciliaSIOvsGL -> ' || v_out);
        MESSAGE_LOG(' ');
        MESSAGE_LOG('***************************************');
        MESSAGE_LOG('INICIA CONCILIACION SIO VS BANCO -> conciliacionbancovssio'); 
            v_out := NULL;
            v_out := cfdi_ap_ar.XXCASH_APEX_CASHLESS_PKG.conciliacionbancovssio@OCIPROD_TO_ORAPROD19;
        MESSAGE_LOG('TERMINA -> conciliacionbancovssio -> ' || v_out);
        MESSAGE_LOG(' ');
        MESSAGE_LOG('*************************************** FIN' );
        MESSAGE_LOG('TERMINA PROCESO DE CASHLESS');
    END EXEC_CASHLESS;
END XXCASH_CASHLESS_PKG;