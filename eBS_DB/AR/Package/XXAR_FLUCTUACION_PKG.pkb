create or replace package body        xxar_fluctuacion_pkg
as
    procedure ejecuta_fluctuacion(pin_no_error in out number, pin_msj_error in out varchar2, pin_period_name varchar2,pin_modo_ejecucion varchar2, pin_user_apex varchar2)
    as
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_id number;
        v_period_name varchar2(100);
        v_period_name_ok NUMBER;
        v_period_name_last varchar2(100);
        v_period_name_last_ok number;
        period_name_error exception;
        v_user_id number;
        v_existe number;
    begin
        pin_no_error := 0;
        v_period_name := pin_period_name;
        
        -- Se obtiene el periodo anterior
        SELECT PL.PERIOD_NAME
        into v_period_name_last
        FROM APPS.GL_PERIODS PC
            ,APPS.GL_PERIODS PL
        WHERE 1=1
        AND PC.PERIOD_NAME = v_period_name
        AND PL.END_DATE = PC.START_DATE-1
        AND PL.PERIOD_NAME NOT LIKE 'AJU%';
        
        -- Valida si el mes anterior ya existe en la tabla y es FIJO o esta procesado en modo FINAL
        SELECT count(*)
        into v_period_name_last_ok
        FROM XXAR_FLUCTUACION_CTRL_TBL
        WHERE 1=1
        AND PERIOD_NAME = v_period_name_last
        AND ESTATUS IN ('FIJO','FINAL');
        
        IF v_period_name_last_ok =0 THEN
            pin_no_error := 1;
            pin_msj_error := 'El periodo ' || v_period_name_last || ' no existe o no esta en estatus FINAL o FIJO. Es necesario primero procesar este periodo para poder continuar con el periodo '||v_period_name||'.';
            raise period_name_error;
            
        END IF;
        -- Valida si el mes actual puede procesarse es decir que este en estatus PREVIO o no existe en la tabla
        SELECT count(*)
        into v_period_name_ok
        FROM XXAR_FLUCTUACION_CTRL_TBL
        WHERE 1=1
        AND PERIOD_NAME = v_period_name;
        
        if v_period_name_ok > 0 then
            v_period_name_ok := 0;
            
            SELECT count(*)
            into v_period_name_last_ok
            FROM XXAR_FLUCTUACION_CTRL_TBL
            WHERE 1=1
            AND PERIOD_NAME = v_period_name
            AND ESTATUS IN ('FIJO','FINAL');
        end if;
        
        if v_period_name_ok > 0 then
            pin_no_error := 2;
            pin_msj_error := 'El periodo ' || v_period_name || ' tiene estatus FINAL o FIJO por lo que NO es posible procesarlo.';
            raise period_name_error;
        end if;
        
        v_user_id := get_user_id_ebs(pin_user_apex);
        if v_user_id = -666 then
            pin_no_error := 3;
            pin_msj_error := 'El usuario ' || pin_user_apex || ' no tiene la configuración correcta en eBS.';
            raise period_name_error;
        end if;
        
        -- Se valida si ya existe el registro sino se crea
        
        v_existe := 0;
            
        select count(*)
        into v_existe
        from XXAR_FLUCTUACION_CTRL_TBL
        where 1=1
        and period_name = v_period_name;
            
        if v_existe=0 then        
            v_id :=  XXAR_FLUCTUACION_CTRL_seq.nextval;            
            
            insert into XXAR_FLUCTUACION_CTRL_TBL
                (ID,PERIOD_NAME,ESTATUS,CREATED_BY,CREATION_DATE,LAST_UPDATE_BY,LAST_UPDATED_DATE)
            VALUES(v_id,v_period_name,'EN PROCESO',v_user_id,SYSDATE,v_user_id,SYSDATE);
            COMMIT;
            pin_no_error := 0;
            pin_msj_error := 'Se INSERTO el registro para el periodo '||v_period_name;
        ELSE 
            UPDATE XXAR_FLUCTUACION_CTRL_TBL
            SET ESTATUS ='EN PROCESO'
                ,LAST_UPDATED_DATE = SYSDATE
                ,LAST_UPDATE_BY = v_user_id
            where 1=1
            and period_name = v_period_name;                        
            
            pin_no_error := 0;
            pin_msj_error := 'Se ACTUALIZO el registro para el periodo '||v_period_name;
        END IF;
        commit;
        -- Ejecuta el proceso de fluctuación
        declare
            v_pin_no_error number;
            v_pin_msj_error varchar2(4000);
        begin
            ejecuta_fluctuacion_db(v_pin_no_error, v_pin_msj_error, pin_period_name,pin_modo_ejecucion, v_user_id);
            pin_no_error := v_pin_no_error;
            pin_msj_error := pin_msj_error || v_pin_msj_error;
        end;
        
    exception
        when  period_name_error then
            -- Se regresa el mensaje en las variables de entrada
            rollback;
    end ejecuta_fluctuacion;
    
    function get_status_periodo_ar(pin_period_name varchar2) return varchar2
    as
        v_period_name varchar2(100);
        v_return varchar2(100);
    begin
        
        IF pin_period_name IS NULL THEN
            v_period_name := get_last_period_name();
        ELSE
            v_period_name := pin_period_name;
        END IF;
        
        
        select PS.CLOSING_STATUS
        into  v_return
        from APPS.GL_PERIOD_STATUSES ps
        where 1=1
        AND PS.APPLICATION_ID = 222--101
        AND PS.CLOSING_STATUS IN ('C','O')
        and period_name = v_period_name;
        
        if v_return = 'C' THEN
            v_return := 'CERRADO';
        ELSIF v_return = 'O' THEN
            v_return := 'ABIERTO';
        END IF;
        
                
        return v_return;
    end get_status_periodo_ar;
    
    function get_status_periodo_fluct(pin_period_name varchar2) return varchar2
    as
        v_return varchar2(100);
        v_period_name varchar2(10);
    begin
        IF pin_period_name IS NULL THEN
            v_period_name := get_last_period_name();
        ELSE
            v_period_name := pin_period_name;
        END IF;
        
        SELECT  NVL(FC.ESTATUS,'NO PROCESADO')
        into v_return
        FROM APPS.GL_PERIOD_STATUSES PS
            ,XXWEBC.XXAR_FLUCTUACION_CTRL_TBL FC
        WHERE 1=1
        AND PS.APPLICATION_ID = 222--101
        AND PS.CLOSING_STATUS IN ('C','O')
        AND PS.PERIOD_NAME = FC.PERIOD_NAME (+)
        AND Ps.PERIOD_NAME = v_period_name;

        RETURN v_return;
    end get_status_periodo_fluct;
    
    function get_last_period_name return varchar2
    as
        v_period_name varchar2(10);
    begin        
        for cur in (
                SELECT PC.PERIOD_NAME
                FROM APPS.GL_PERIODS PC
                    ,APPS.GL_PERIOD_STATUSES PS
                WHERE 1=1
                AND PC.PERIOD_SET_NAME = 'GEPP'
                AND PC.START_DATE >= TO_DATE('01-05-2023','DD-MM-YYYY')
                AND PC.PERIOD_NAME NOT LIKE 'AJU%'
                AND PC.PERIOD_NAME = PS.PERIOD_NAME
                AND PS.APPLICATION_ID = 222--101
                AND PS.CLOSING_STATUS IN ('C','O')
                ORDER BY PC.PERIOD_NUM DESC,PC.PERIOD_YEAR
            )loop
                IF v_period_name IS NULL THEN
                    v_period_name := cur.period_name;
                    exit;
                END IF;
            end loop;
            
        return v_period_name;
    end get_last_period_name;
    
    FUNCTION get_user_id_ebs(pin_no_empleado varchar2) return number
    as
        v_return number;
    begin
        
        select user_id
        into v_return
        from fnd_user
        where 1=1
        and fax = pin_no_empleado;
        
        return v_return;
    exception
        when no_data_found then
            v_return := -666;
            return v_return;
    end  get_user_id_ebs;
    
    procedure ejecuta_fluctuacion_db(pin_no_error in out number, pin_msj_error in out varchar2, pin_period_name varchar2,pin_modo_ejecucion varchar2, pin_user_id number)
    as
        v_period_name_last VARCHAR2(100);
    --p_recalcular 
    BEGIN
        
        -- Se tiene como base el periodo MAY-23
                
        delete XXAR_FLUCTUACION_GL_TBL
        where 1=1
        and periodo =pin_period_name;
        COMMIT;
        
        delete XXAR_FLUCTUACION_PERIODO_D
        where 1=1
        and period_name =pin_period_name;
        COMMIT;
        
        delete XXAR_FLUCTUACION_PERIODO_sum
        where 1=1
        and period_name =pin_period_name;
        
        commit;
        
        -- Se obtiene el periodo anterior
        SELECT PL.PERIOD_NAME
        into v_period_name_last
        FROM APPS.GL_PERIODS PC
            ,APPS.GL_PERIODS PL
        WHERE 1=1
        AND PC.PERIOD_NAME = pin_period_name
        AND PL.END_DATE = PC.START_DATE-1
        AND PL.PERIOD_NAME NOT LIKE 'AJU%';
        
        -- Se insertan las facturas del periodo ---**** XXAR_FLUCTUACION_TRX_ALL
        INSERT INTO XXAR_FLUCTUACION_TRX_ALL
            SELECT ps.org_id, ps.customer_trx_id,AR.TRX_NUMBER,ar.trx_date,ar.BILL_TO_CUSTOMER_ID,ps.INVOICE_CURRENCY_CODE,ps.class,PS.TAX_ORIGINAL,ps.tax_remaining     
                , PS.EXCHANGE_DATE, PS.EXCHANGE_RATE--sysdate, -1, sysdate, -1
                ,ROUND(PS.TAX_ORIGINAL *PS.EXCHANGE_RATE,2) AS TAX_ORIGINAL_MXN
                ,GL.JE_CATEGORY je_category
                ,GL.JE_HEADER_ID JE_HEADER_ID
                ,to_char(ar.trx_date,'MON-YY','NLS_DATE_LANGUAGE=SPANISH') period_name_trx
                ,PS.AMOUNT_LINE_ITEMS_ORIGINAL, ps.amount_line_items_remaining , PS.AMOUNT_DUE_ORIGINAL, ps.amount_due_remaining
                ,TRUNC(SYSDATE)
                ,(select case when prov_invalidos is null then
                                    'TERCERO'
                              when prov_invalidos like 'ASOCI%' then
                                    'ASOCIADA'
                              when prov_invalidos like 'INTERCO%' then
                                    'ICIA'
                              else
                                'OTRA'
                         end 
                   from apps.cm_mstr cmm
                    where 1=1
                    and cmm.org_id = ar.org_id
                    and cmm.customer_id = ar.bill_to_customer_id
                    and cmm.tipo='BILL_TO')
                    ,ar.bill_to_customer_id
            FROM APPS.RA_CUSTOMER_TRX_ALL AR
                ,APPS.AR_PAYMENT_SCHEDULES_ALL PS
                ,(SELECT DISTINCT XTE.SOURCE_ID_INT_1                      CUSTOMER_TRX_ID
                        ,GJH.JE_CATEGORY
                        ,GJH.JE_HEADER_ID
                      FROM APPS.GL_JE_HEADERS            GJH,
                           APPS.GL_JE_LINES              GJL,
                           APPS.GL_CODE_COMBINATIONS     GCC,
                           APPS.GL_IMPORT_REFERENCES     IMP,
                           APPS.XLA_AE_LINES             XAL,
                           APPS.XLA_AE_HEADERS           XAH,
                           APPS.XLA_EVENTS               XE,
                           XLA.XLA_TRANSACTION_ENTITIES  XTE
                     WHERE     1 = 1
                           AND GJH.PERIOD_NAME =pin_period_name
                           AND GJH.JE_SOURCE = 'Receivables'
                           AND GJH.JE_CATEGORY IN ('Sales Invoices')--('Credit Memos', 'Debit Memos')
                           AND GJH.CURRENCY_CODE != 'MXN'
                           AND GJL.JE_HEADER_ID = GJH.JE_HEADER_ID
                           AND GCC.CODE_COMBINATION_ID = GJL.CODE_COMBINATION_ID
                           AND IMP.JE_HEADER_ID = GJL.JE_HEADER_ID
                           AND IMP.JE_LINE_NUM = GJL.JE_LINE_NUM
                           AND XAL.GL_SL_LINK_ID = IMP.GL_SL_LINK_ID
                           AND XAL.GL_SL_LINK_TABLE = IMP.GL_SL_LINK_TABLE
                           AND XAL.APPLICATION_ID = 222
                           AND XAH.APPLICATION_ID = XAL.APPLICATION_ID
                           AND XAH.AE_HEADER_ID = XAL.AE_HEADER_ID
                           AND XE.APPLICATION_ID = XAH.APPLICATION_ID
                           AND XE.EVENT_ID = XAH.EVENT_ID
                           AND XTE.APPLICATION_ID = XE.APPLICATION_ID
                           AND XTE.ENTITY_ID = XE.ENTITY_ID
                           AND XTE.ENTITY_CODE = 'TRANSACTIONS'
                           AND NOT EXISTS (SELECT 'EX' FROM XXAR_FLUCTUACION_TRX_ALL WHERE CUSTOMER_TRX_ID =XTE.SOURCE_ID_INT_1)
                   ) gl
            WHERE 1=1
            AND AR.CUSTOMER_TRX_ID = PS.CUSTOMER_TRX_ID
            and ar.INVOICE_CURRENCY_CODE != 'MXN'
            AND AR.CUSTOMER_TRX_ID = gl.CUSTOMER_TRX_ID;
            
            COMMIT;
        
            -- Con base a los customer_trx_id se obtienen los pagos y NC de las transacciones --***XXAR_FLUCTUACION_PAYMENTS_ALL
            ---  NOTAS DE CREDITO
            INSERT INTO XXAR_FLUCTUACION_PAYMENTS_ALL
            select a.APPLICATION_TYPE,a.RECEIVABLE_APPLICATION_ID,A.ORG_ID,a.amount_applied ,a.AMOUNT_APPLIED_FROM, a.TRANS_TO_RECEIPT_RATE, a.code_combination_id
                    ,A.LINE_APPLIED , A.TAX_APPLIED,b.invoice_currency_code as currency_code_pay, b.exchange_rate exchange_rate_pay,b.exchange_date exchange_date_pay,A.GL_POSTED_DATE, TO_CHAR(b.trx_date,'MON-YY','NLS_DATE_LANGUAGE=SPANISH') AS PERIOD_NAME, A.ACCTD_AMOUNT_APPLIED_FROM, A.ACCTD_AMOUNT_APPLIED_TO, A.POSTING_CONTROL_ID
                    ,A.EARNED_DISCOUNT_CCID, A.UNEARNED_DISCOUNT_CCID, A.APPLICATION_REF_NUM, A.EVENT_ID
                    ,a.customer_trx_id as id_transaccion,b.TRX_NUMBER as no_transaccion, b.TRX_date as fecha_transaccion, A.APPLY_DATE as fecha_aplicacion
                    ,C.CUSTOMER_TRX_ID,c.trx_number, c.trx_date, c.exchange_date, c.exchange_rate, c.invoice_currency_code        
            FROM   AR.AR_RECEIVABLE_APPLICATIONS_ALL A
                    ,AR.RA_CUSTOMER_TRX_ALL B
                  ,AR.RA_CUSTOMER_TRX_ALL C      
            where 1=1
            and a.APPLICATION_TYPE = 'CM'
            AND    A.customer_trx_id = B.customer_trx_id
            AND    A.APPLIED_CUSTOMER_TRX_ID = C.CUSTOMER_TRX_ID
            AND C.CUSTOMER_TRX_ID in (select customer_trx_id 
                                       from  XXAR_FLUCTUACION_TRX_ALL) 
            AND A.RECEIVABLE_APPLICATION_ID NOT  IN (SELECT RECEIVABLE_APPLICATION_ID 
                                                    FROM XXAR_FLUCTUACION_PAYMENTS_ALL
                                                    where 1=1
                                                    and APPLICATION_TYPE = 'CM');
            
            COMMIT;
            
            ---  RECIBOS
            INSERT INTO XXAR_FLUCTUACION_PAYMENTS_ALL
            select a.APPLICATION_TYPE,a.RECEIVABLE_APPLICATION_ID,A.ORG_ID,a.amount_applied ,a.AMOUNT_APPLIED_FROM, a.TRANS_TO_RECEIPT_RATE, a.code_combination_id
                    ,A.LINE_APPLIED , A.TAX_APPLIED, b.currency_code, b.exchange_rate, b.exchange_date,A.gl_date, TO_CHAR(A.gl_date,'MON-YY','NLS_DATE_LANGUAGE=SPANISH') AS PERIOD_NAME, A.ACCTD_AMOUNT_APPLIED_FROM, A.ACCTD_AMOUNT_APPLIED_TO, A.POSTING_CONTROL_ID
                    ,A.EARNED_DISCOUNT_CCID, A.UNEARNED_DISCOUNT_CCID, A.APPLICATION_REF_NUM, A.EVENT_ID
                    ,a.cash_receipt_id as id_transaccion,b.receipt_number, b.receipt_date, deposit_date
                    ,C.CUSTOMER_TRX_ID ,c.trx_number, c.trx_date, c.exchange_date, c.exchange_rate, c.invoice_currency_code
            FROM   AR.AR_RECEIVABLE_APPLICATIONS_ALL A
                  ,AR.AR_CASH_RECEIPTS_ALL B
                  ,AR.RA_CUSTOMER_TRX_ALL C      
            where 1=1
            and a.APPLICATION_TYPE = 'CASH'
            AND    A.CASH_RECEIPT_ID = B.CASH_RECEIPT_ID
            AND    A.APPLIED_CUSTOMER_TRX_ID = C.CUSTOMER_TRX_ID
            And C.Customer_Trx_Id In (Select Customer_Trx_Id From Xxar_Fluctuacion_Trx_All)
            AND A.RECEIVABLE_APPLICATION_ID NOT  IN (SELECT RECEIVABLE_APPLICATION_ID FROM XXAR_FLUCTUACION_PAYMENTS_ALL
            where 1=1
            and APPLICATION_TYPE = 'CASH');
            
            --------------------------------SE AGREGA AJUSTES 
            INSERT INTO XXAR_FLUCTUACION_PAYMENTS_ALL
            select 'ADJUS',ada.ADJUSTMENT_ID,ADA.ORG_ID,abs(ada.amount) ,null, null, ada.code_combination_id
                    ,abs(Ada.LINE_ADJUSTED) , abs(Ada.TAX_ADJUSTED), trx.INVOICE_CURRENCY_CODE, trx.exchange_rate, trx.exchange_date,ada.gl_date, TO_CHAR(ada.gl_date,'MON-YY','NLS_DATE_LANGUAGE=SPANISH') AS PERIOD_NAME, abs(ada.ACCTD_AMOUNT), null, ada.POSTING_CONTROL_ID
                    ,null, null, null, Ada.EVENT_ID
                    ,ada.ADJUSTMENT_ID as id_transaccion,Ada.ADJUSTMENT_NUMBER, ada.APPLY_DATE, ada.APPLY_DATE
                    ,trx.CUSTOMER_TRX_ID ,trx.trx_number, trx.trx_date, trx.exchange_date, trx.exchange_rate, trx.invoice_currency_code
                    FROM ar.ar_adjustments_all ada, 
                    --hr.hr_all_organization_units hou,
                    ar.ra_customer_trx_all trx
                    --apps.AR_RECEIVABLES_TRX_ALL art
         WHERE 1 = 1
         --and    ada.receivables_trx_id = art.receivables_trx_id
         --and    art.name like 'IN_SU_BANCOAR_AJ'
         and    ada.status = 'A'
         and    ada.customer_trx_id = trx.customer_trx_id
         and    ada.org_id = trx.org_id 
         And trx.Customer_Trx_Id In (Select Customer_Trx_Id From Xxar_Fluctuacion_Trx_All)
            AND ADA.ADJUSTMENT_ID NOT  IN (SELECT RECEIVABLE_APPLICATION_ID FROM XXAR_FLUCTUACION_PAYMENTS_ALL
            where 1=1
            and APPLICATION_TYPE = 'ADJUS');
            --------------TERMINA LO DE AJUSTES -------------------------
            
            COMMIT;
            
            
            -- 1 inserta lo que se creo y tiene un pago en el mismo mes.
            insert into XXAR_FLUCTUACION_PERIODO_D
            select pin_period_name PERIOD_NAME,
                    SYSDATE CREATION_DATE,
                    F.CUSTOMER_TRX_ID,
                    F.TRX_NUMBER,
                    F.EXCHANGE_RATE TRX_TC,
                    F.ORG_ID,
                    F.INVOICE_CURRENCY_CODE TRX_CURRENCY,        
                    F.TRX_DATE,
                    F.PERIOD_NAME_TRX TRX_PERIOD_NAME,
                    F.TAX_ORIGINAL TRX_TAX_ORIGINAL,
                    F.TAX_ORIGINAL TRX_FACTURADO
                    ,ROUND(F.EXCHANGE_RATE*F.TAX_ORIGINAL,2) TRX_FACTURADO_MXN
                    ,P.ID_TRANSACCION P_ID_TRANSACCION
                    ,SUM(P.TAX_APPLIED) P_COBRADO
                    ,ROUND(SUM(P.TAX_APPLIED) *CASE WHEN P.TRANS_TO_RECEIPT_RATE IS NULL THEN 
                            P.EXCHANGE_RATE_PAY
                        ELSE
                            P.TRANS_TO_RECEIPT_RATE
                        END,2) P_COBRADO_MXN
                    
                    ,CASE WHEN P.TRANS_TO_RECEIPT_RATE IS NULL THEN 
                            P.EXCHANGE_RATE_PAY
                        ELSE
                            P.TRANS_TO_RECEIPT_RATE
                        END P_TC
                    ,P.NO_TRANSACCION P_NO_TRANSACCION
                    ,p.FECHA_TRANSACCION P_DATE
                    ,P.APPLICATION_TYPE P_TYPE
                    ,P.CURRENCY_CODE_PAY P_CURRENCY
                    ,P.PERIOD_NAME P_PERIOD_NAME
                    ,SUM(P.TAX_APPLIED)*F.EXCHANGE_RATE
                    ,f.tipo_cliente
                    ,f.customer_id
            from XXAR_FLUCTUACION_TRX_ALL f
                ,XXAR_FLUCTUACION_PAYMENTS_ALL p 
            where 1=1
            and f.period_name_TRX =pin_period_name
            and p.period_name =pin_period_name
            AND f.customer_trx_id = p.customer_trx_id 
            --and p.customer_trx_id not in (select customer_trx_id
            and (p.customer_trx_id,P.id_transaccion) not in (select customer_trx_id,p_id_transaccion
                                            from XXAR_FLUCTUACION_PERIODO_D
                                            WHERE 1=1
                                            AND PERIOD_NAME =pin_period_name)
            GROUP BY F.CUSTOMER_TRX_ID,
                    F.TRX_NUMBER,
                    F.EXCHANGE_RATE,
                    F.ORG_ID,
                    F.INVOICE_CURRENCY_CODE,        
                    F.PERIOD_NAME_TRX,
                    F.TAX_ORIGINAL,
                    F.TAX_ORIGINAL 
                    ,P.ID_TRANSACCION        
                    ,P.TAX_APPLIED        
                    ,CASE WHEN P.TRANS_TO_RECEIPT_RATE IS NULL THEN 
                            P.EXCHANGE_RATE_PAY
                        ELSE
                            P.TRANS_TO_RECEIPT_RATE
                        END
                    ,P.NO_TRANSACCION
                    ,p.FECHA_TRANSACCION
                    ,P.APPLICATION_TYPE
                    ,F.TRX_DATE
                    ,P.CURRENCY_CODE_PAY
                    ,P.PERIOD_NAME
                    ,f.tipo_cliente
                    ,f.customer_id;
            
            COMMIT;

            -- 2 inserta lo que se creo y NO tiene un pago en el mismo mes y tiene un pago en un mes posterior
            insert into XXAR_FLUCTUACION_PERIODO_D
            select pin_period_name PERIOD_NAME,
                    SYSDATE CREATION_DATE,
                    F.CUSTOMER_TRX_ID,
                    F.TRX_NUMBER,
                    F.EXCHANGE_RATE TRX_TC,
                    F.ORG_ID,
                    F.INVOICE_CURRENCY_CODE TRX_CURRENCY,        
                    F.TRX_DATE,
                    F.PERIOD_NAME_TRX TRX_PERIOD_NAME,
                    F.TAX_ORIGINAL TRX_TAX_ORIGINAL,
                    F.TAX_ORIGINAL TRX_FACTURADO
                    ,ROUND(F.EXCHANGE_RATE*F.TAX_ORIGINAL,2) TRX_FACTURADO_MXN
                    ,null--P.ID_TRANSACCION P_ID_TRANSACCION
                    ,0--SUM(P.TAX_APPLIED) P_COBRADO
                    ,0 /*ROUND(SUM(P.TAX_APPLIED) *CASE WHEN P.TRANS_TO_RECEIPT_RATE IS NULL THEN 
                            P.EXCHANGE_RATE_PAY
                        ELSE
                            P.TRANS_TO_RECEIPT_RATE
                        END,2) P_COBRADO_MXN*/
                    
                    ,0 /*CASE WHEN P.TRANS_TO_RECEIPT_RATE IS NULL THEN 
                            P.EXCHANGE_RATE_PAY
                        ELSE
                            P.TRANS_TO_RECEIPT_RATE
                        END P_TC*/
                    ,null--P.NO_TRANSACCION P_NO_TRANSACCION
                    ,null--p.FECHA_TRANSACCION P_DATE
                    ,null--P.APPLICATION_TYPE P_TYPE
                    ,null--P.CURRENCY_CODE_PAY P_CURRENCY
                    ,null--P.PERIOD_NAME P_PERIOD_NAME
                    ,null --cobrado_original
                    ,f.tipo_cliente
                    ,f.customer_id
            from XXAR_FLUCTUACION_TRX_ALL f
                ,XXAR_FLUCTUACION_PAYMENTS_ALL p 
            where 1=1
            and f.period_name_TRX =pin_period_name
            and p.period_name !=pin_period_name
            AND f.customer_trx_id = p.customer_trx_id 
            and p.customer_trx_id not in (select customer_trx_id
                                            from XXAR_FLUCTUACION_PERIODO_D
                                            WHERE 1=1
                                            AND PERIOD_NAME =pin_period_name)
            GROUP BY F.CUSTOMER_TRX_ID,
                    F.TRX_NUMBER,
                    F.EXCHANGE_RATE,
                    F.ORG_ID,
                    F.INVOICE_CURRENCY_CODE,
                    --SYSDATE,
                    F.PERIOD_NAME_TRX,
                    F.TAX_ORIGINAL,
                    F.TAX_ORIGINAL 
                    ,F.TRX_DATE
                    ,f.tipo_cliente
                    ,f.customer_id
            ;
            
            COMMIT;

            -- 3 inserta lo que se creo y NO tiene un pago en ningun mes
            insert into XXAR_FLUCTUACION_PERIODO_D
            select pin_period_name  PERIOD_NAME,
                    SYSDATE CREATION_DATE,
                    F.CUSTOMER_TRX_ID,
                    F.TRX_NUMBER,
                    F.EXCHANGE_RATE TRX_TC,
                    F.ORG_ID,
                    F.INVOICE_CURRENCY_CODE TRX_CURRENCY,        
                    F.TRX_DATE,
                    F.PERIOD_NAME_TRX TRX_PERIOD_NAME,
                    F.TAX_ORIGINAL TRX_TAX_ORIGINAL,
                    F.TAX_ORIGINAL TRX_FACTURADO
                    ,ROUND(F.EXCHANGE_RATE*F.TAX_ORIGINAL,2) TRX_FACTURADO_MXN
                    ,null--P.ID_TRANSACCION P_ID_TRANSACCION
                    ,0--SUM(P.TAX_APPLIED) P_COBRADO
                    ,0 /*ROUND(SUM(P.TAX_APPLIED) *CASE WHEN P.TRANS_TO_RECEIPT_RATE IS NULL THEN 
                            P.EXCHANGE_RATE_PAY
                        ELSE
                            P.TRANS_TO_RECEIPT_RATE
                        END,2) P_COBRADO_MXN*/
                    
                    ,0 /*CASE WHEN P.TRANS_TO_RECEIPT_RATE IS NULL THEN 
                            P.EXCHANGE_RATE_PAY
                        ELSE
                            P.TRANS_TO_RECEIPT_RATE
                        END P_TC*/
                    ,null--P.NO_TRANSACCION P_NO_TRANSACCION
                    ,null--p.FECHA_TRANSACCION P_DATE
                    ,null--P.APPLICATION_TYPE P_TYPE
                    ,null--P.CURRENCY_CODE_PAY P_CURRENCY
                    ,null--P.PERIOD_NAME P_PERIOD_NAME
                    ,null --cobra_original_mxn
                    ,f.tipo_cliente
                    ,f.customer_id
            from XXAR_FLUCTUACION_TRX_ALL f
                ,XXAR_FLUCTUACION_PAYMENTS_ALL p 
            where 1=1
            and f.period_name_TRX =pin_period_name
            AND f.customer_trx_id = p.customer_trx_id (+)
            and p.customer_trx_id is null 
            and f.customer_trx_id not in (select customer_trx_id
                                            from XXAR_FLUCTUACION_PERIODO_D
                                            WHERE 1=1
                                            AND PERIOD_NAME =pin_period_name)
            GROUP BY F.CUSTOMER_TRX_ID,
                    F.TRX_NUMBER,
                    F.EXCHANGE_RATE,
                    F.ORG_ID,
                    F.INVOICE_CURRENCY_CODE,
                    F.PERIOD_NAME_TRX,
                    F.TAX_ORIGINAL,
                    F.TAX_ORIGINAL 
                    ,F.TRX_DATE
                    ,f.tipo_cliente
                    ,f.customer_id
            ;
            
            COMMIT;

            -- 4 inserta lo que se pago en el mes y se creo antes.
            insert into XXAR_FLUCTUACION_PERIODO_D
            select pin_period_name  PERIOD_NAME,
                    SYSDATE CREATION_DATE,
                    F.CUSTOMER_TRX_ID,
                    F.TRX_NUMBER,
                    F.EXCHANGE_RATE TRX_TC,
                    F.ORG_ID,
                    F.INVOICE_CURRENCY_CODE TRX_CURRENCY,        
                    F.TRX_DATE,
                    F.PERIOD_NAME_TRX TRX_PERIOD_NAME,
                    F.TAX_ORIGINAL TRX_TAX_ORIGINAL,
                    0 TRX_FACTURADO
                    ,0 TRX_FACTURADO_MXN
                    ,P.ID_TRANSACCION P_ID_TRANSACCION
                    ,SUM(P.TAX_APPLIED) P_COBRADO
                    ,ROUND(SUM(P.TAX_APPLIED) *CASE WHEN P.TRANS_TO_RECEIPT_RATE IS NULL THEN 
                            P.EXCHANGE_RATE_PAY
                        ELSE
                            P.TRANS_TO_RECEIPT_RATE
                        END,2) P_COBRADO_MXN
                    
                    ,CASE WHEN P.TRANS_TO_RECEIPT_RATE IS NULL THEN 
                            P.EXCHANGE_RATE_PAY
                        ELSE
                            P.TRANS_TO_RECEIPT_RATE
                        END P_TC
                    ,P.NO_TRANSACCION P_NO_TRANSACCION
                    ,p.FECHA_TRANSACCION P_DATE
                    ,P.APPLICATION_TYPE P_TYPE
                    ,P.CURRENCY_CODE_PAY P_CURRENCY
                    ,P.PERIOD_NAME P_PERIOD_NAME
                    ,SUM(P.TAX_APPLIED)*F.EXCHANGE_RATE
                    ,f.tipo_cliente
                    ,f.customer_id
            from XXAR_FLUCTUACION_TRX_ALL f
                ,XXAR_FLUCTUACION_PAYMENTS_ALL p 
            where 1=1
            and f.period_name_TRX !=pin_period_name
            and p.period_name =pin_period_name
            AND f.customer_trx_id = p.customer_trx_id 
            --and p.customer_trx_id not in (select customer_trx_id
            and (p.customer_trx_id,P.id_transaccion) not in (select customer_trx_id,p_id_transaccion
                                            from XXAR_FLUCTUACION_PERIODO_D
                                            WHERE 1=1
                                            AND PERIOD_NAME =pin_period_name)
            GROUP BY F.CUSTOMER_TRX_ID,
                    F.TRX_NUMBER,
                    F.EXCHANGE_RATE,
                    F.ORG_ID,
                    F.INVOICE_CURRENCY_CODE,
                    --SYSDATE,
                    F.PERIOD_NAME_TRX,
                    F.TAX_ORIGINAL,
                    F.TAX_ORIGINAL 
                    ,P.ID_TRANSACCION        
                    ,P.TAX_APPLIED        
                    ,CASE WHEN P.TRANS_TO_RECEIPT_RATE IS NULL THEN 
                            P.EXCHANGE_RATE_PAY
                        ELSE
                            P.TRANS_TO_RECEIPT_RATE
                        END
                    ,P.NO_TRANSACCION
                    ,p.FECHA_TRANSACCION
                    ,P.APPLICATION_TYPE
                    ,F.TRX_DATE
                    ,P.CURRENCY_CODE_PAY
                    ,P.PERIOD_NAME
                    ,f.tipo_cliente
                    ,f.customer_id;
                    
                    COMMIT;
                    
                    

            -- Se inserta lo que quedo vivo de MAY y no se afecto en el mes
            insert into XXAR_FLUCTUACION_PERIODO_D
            select pin_period_name  PERIOD_NAME,
                    SYSDATE CREATION_DATE,
                    F.CUSTOMER_TRX_ID,
                    F.TRX_NUMBER,
                    F.EXCHANGE_RATE TRX_TC,
                    F.ORG_ID,
                    F.INVOICE_CURRENCY_CODE TRX_CURRENCY,        
                    F.TRX_DATE,
                    F.PERIOD_NAME_TRX TRX_PERIOD_NAME,
                    F.TAX_ORIGINAL TRX_TAX_ORIGINAL,
                    0 TRX_FACTURADO
                    ,0 TRX_FACTURADO_MXN
                    ,null--P.ID_TRANSACCION P_ID_TRANSACCION
                    ,0--SUM(P.TAX_APPLIED) P_COBRADO
                    ,0 /*ROUND(SUM(P.TAX_APPLIED) *CASE WHEN P.TRANS_TO_RECEIPT_RATE IS NULL THEN 
                            P.EXCHANGE_RATE_PAY
                        ELSE
                            P.TRANS_TO_RECEIPT_RATE
                        END,2) P_COBRADO_MXN*/
                    
                    ,0 /*CASE WHEN P.TRANS_TO_RECEIPT_RATE IS NULL THEN 
                            P.EXCHANGE_RATE_PAY
                        ELSE
                            P.TRANS_TO_RECEIPT_RATE
                        END P_TC*/
                    ,null--P.NO_TRANSACCION P_NO_TRANSACCION
                    ,null--p.FECHA_TRANSACCION P_DATE
                    ,null--P.APPLICATION_TYPE P_TYPE
                    ,null--P.CURRENCY_CODE_PAY P_CURRENCY
                    ,null--P.PERIOD_NAME P_PERIOD_NAME
                    ,null --cobrado original mxn
                    ,f.tipo_cliente
                    ,f.customer_id
            from XXAR_FLUCTUACION_TRX_ALL f 
            where 1=1        
            -- mes anterior
            and f.customer_trx_id in (select customer_trx_id from XXAR_FLUCTUACION_PERIODO_SUM S
                                        where 1=1
                                        and period_name = v_period_name_last
                                        AND trx_pen_mes_act >0
                                        ) 
            and f.customer_trx_id not in (select customer_trx_id
                                            from XXAR_FLUCTUACION_PERIODO_D
                                            WHERE 1=1
                                            AND PERIOD_NAME =pin_period_name)
            GROUP BY F.CUSTOMER_TRX_ID,
                    F.TRX_NUMBER,
                    F.EXCHANGE_RATE,
                    F.ORG_ID,
                    F.INVOICE_CURRENCY_CODE,
                    --SYSDATE,
                    F.PERIOD_NAME_TRX,
                    F.TAX_ORIGINAL,
                    F.TAX_ORIGINAL 
                    ,F.TRX_DATE
                    ,f.tipo_cliente
                    ,f.customer_id;
                    
            COMMIT;
            
        -- Se llena la tabla con la suma
        INSERT INTO XXAR_FLUCTUACION_PERIODO_SUM
        SELECT PERIOD_NAME,
            sysdate,
            TRX_DATE,
            TRX_TC,
            TRX_TAX_ORIGINAL,
            0 TRX_PEN_MES_ANT,
            0 TRX_PEN_MES_ANT_MXN,
            TRX_FACTURADO,
            TRX_FACTURADO_MXN,
            SUM(P_COBRADO) P_SCOBRADO,
            SUM(P_COBRADO_MXN) P_SCOBRADO_MXN,
            0  TRX_PEN_MES_ACT,
            0  TRX_PEN_MES_ACT_MXN,
            CUSTOMER_TRX_ID,
            ORG_ID,
            TRX_PERIOD_NAME,
            TRX_CURRENCY,
            TRX_NUMBER,
            sum(TRX_FACTURADO_ORIGINAL_MXN)
            ,0 
            ,tipo_cliente
            ,null
            ,null
            ,null
            ,case when SUM(P_COBRADO) >0 then count(customer_trx_id) else 0 end
            ,customer_id
            ,null
        FROM XXAR_FLUCTUACION_PERIODO_D d
        WHERE 1=1
          AND PERIOD_NAME = pin_period_name
          and not exists (SELECT 'ex'
                           from XXAR_FLUCTUACION_PERIODO_SUM s
                           where 1=1
                           and d.customer_trx_id =s.customer_trx_id
                           and d.period_name = s.period_name)
        GROUP BY PERIOD_NAME,
            CREATION_DATE,
            TRX_DATE,
            TRX_TC,
            TRX_TAX_ORIGINAL,
            TRX_FACTURADO,
            TRX_FACTURADO_MXN,
            CUSTOMER_TRX_ID,
            ORG_ID,
            TRX_PERIOD_NAME,
            TRX_CURRENCY,
            TRX_NUMBER
            ,tipo_cliente
            ,customer_id;
            
            COMMIT;
            
            UPDATE XXAR_FLUCTUACION_PERIODO_SUM N
            set (TRX_PEN_MES_ANT,TRX_PEN_MES_ANT_MXN) =(select TRX_PEN_MES_ACT, TRX_PEN_MES_ACT_mxn
                                                        from XXAR_FLUCTUACION_PERIODO_SUM O
                                                        where 1=1
                                                        and O.period_name = v_period_name_last
                                                        AND O.CUSTOMER_TRX_ID = N.CUSTOMER_TRX_ID)
                 
            WHERE 1=1
            AND PERIOD_NAME =pin_period_name
            AND TRX_FACTURADO =0;
            
            COMMIT;
            
            ----actualiza pendiente del mes
            update XXAR_FLUCTUACION_PERIODO_SUM S
                set trx_pen_mes_act = trx_facturado -p_scobrado
                    ,trx_pen_mes_act_mxn = round((trx_facturado -p_scobrado)*trx_tc,2)
            where 1=1
            and period_name =pin_period_name
            and trx_facturado !=0;

            update XXAR_FLUCTUACION_PERIODO_SUM S
                set trx_pen_mes_act = trx_pen_mes_ant -p_scobrado
                    ,trx_pen_mes_act_mxn = round((trx_pen_mes_ant -nvl(p_scobrado,0))*trx_tc,2)
            where 1=1
            and period_name =pin_period_name
            and trx_facturado =0;
            
            COMMIT;
            
            --SE ACTUALIZA EL MONTO DE FLUCTUACION
            UPDATE XXAR_FLUCTUACION_PERIODO_SUM N
            set monto_fluctuacion_mxn = trx_facturado_original_mxn - p_scobrado_mxn
            WHERE 1=1
            AND PERIOD_NAME =pin_period_name
            AND p_scobrado !=0;
            
            COMMIT;
            
            UPDATE XXAR_FLUCTUACION_PERIODO_SUM
            SET GAIN_LOST_TYPE = CASE WHEN MONTO_FLUCTUACION_MXN<0 THEN 'GANANCIA' ELSE 'PERDIDA' END
            where 1=1
            and period_name = pin_period_name
            AND MONTO_FLUCTUACION_MXN!=0;
            
            COMMIT;
            
            update XXAR_FLUCTUACION_PERIODO_SUM s
            set (s.gain_lost_cta, s.iva_cta) = (SELECT
                                                    FL.DESCRIPTION AS CTA_PERDIDA
                                                    ,FL.TAG AS CTA_IVA
                                                FROM apps.fnd_lookup_values  fl
                                                WHERE 1=1
                                                AND fl.language = 'ESA'
                                                AND fl.lookup_type = 'XXAR_CUENTAS_PERDIDA_GANANCIA'
                                                AND enabled_flag='Y'
                                                and regexp_substr(fl.meaning, '[^_"]+', 1, 1) = s.gain_lost_type --GAIN_LOST
                                                and regexp_substr(fl.meaning, '[^_"]+', 1, 2) = s.tipo_cliente--TIPO_CLIENTE
                                                and regexp_substr(fl.meaning, '[^_"]+', 1, 3) = s.org_id--ORG_ID
                                                )
            where 1=1
            and period_name = pin_period_name
            AND MONTO_FLUCTUACION_MXN!=0;
            
            COMMIT;
            
            -- Si es Asociada o ICIA se coloca en el segmento7 el no de cliente 
--            update XXAR_FLUCTUACION_PERIODO_SUM s
--            set gain_lost_cta = substr(gain_lost_cta,1,26) || (select c.CUSTOMER_NUMBER 
--                                                                 from apps.ra_customers c
--                                                                where 1=1
--                                                                  and c.customer_id = s.customer_id)
--            where 1=1
--            and gain_lost_cta is not null
--            and tipo_cliente in ('ASOCIADA','ICIA');

-----alex ingresa el update separado para ICIAS Y ASOCIADAS 

update XXAR_FLUCTUACION_PERIODO_SUM s
            set gain_lost_cta = substr(gain_lost_cta,1,26) || (select c.CUSTOMER_NUMBER 
                                                                 from apps.ra_customers c
                                                                where 1=1
                                                                  and c.customer_id = s.customer_id)
            where 1=1
            and gain_lost_cta is not null
            and tipo_cliente in ('ICIA');
            
            
            update XXAR_FLUCTUACION_PERIODO_SUM s
            set gain_lost_cta = substr(gain_lost_cta,1,26) || (select  valor
				from    apps.xxar_mapeo_lines_cust
				where   1 = 1
				and     tipo_transaccion = 'INGRESOS'
				and     tipo_cliente = 'ASOCIADA'
				and     no_cadena = (select c.CUSTOMER_NUMBER 
                                                                 from apps.ra_customers c
                                                                where 1=1
                                                                  and c.customer_id = s.customer_id))
            where 1=1
            and gain_lost_cta is not null
            and tipo_cliente in ('ASOCIADA');
            
            commit;
            
            -- Clasificacion
            update XXAR_FLUCTUACION_PERIODO_SUM
            set clasificacion = 'V'
            WHERE 1=1
            and period_name = pin_period_name
            AND TRX_FACTURADO != 0 ;
            
            DECLARE
                v_fecha_atraso date;
            BEGIN
                select ADD_MONTHS(start_date,-3)
                INTO v_fecha_atraso
                from APPS.GL_PERIODS PC
                where 1=1
                and period_name = pin_period_name;
                
                update XXAR_FLUCTUACION_PERIODO_SUM
                set clasificacion = 'A'
                WHERE 1=1
                and period_name = pin_period_name
                AND TRX_FACTURADO = 0 
                AND TRX_PEN_MES_ACT != 0
                AND TRX_DATE >= v_fecha_atraso;
                
                update XXAR_FLUCTUACION_PERIODO_SUM
                set clasificacion = 'R'
                WHERE 1=1
                and period_name = pin_period_name
                AND TRX_FACTURADO = 0 
                AND TRX_PEN_MES_ACT != 0
                AND TRX_DATE < v_fecha_atraso;
                
                update XXAR_FLUCTUACION_PERIODO_SUM
                set clasificacion = 'V2'
                WHERE 1=1
                and period_name = pin_period_name
                AND CLASIFICACION IS NULL;
                COMMIT;
            END;
            
            
           
            -- Se inserta la distribucion de GL
            INSERT INTO XXAR_FLUCTUACION_GL_TBL
            SELECT GJH.JE_HEADER_ID,
                   GJH.JE_SOURCE,
                   GJH.JE_CATEGORY,
                   GJH.PERIOD_NAME                           PERIODO,
                   GCC.CODE_COMBINATION_ID,
                   
                   GCC.SEGMENT1 ||'-'|| 
                   GCC.SEGMENT2 ||'-'|| 
                   GCC.SEGMENT3 ||'-'|| 
                   GCC.SEGMENT4 ||'-'|| 
                   GCC.SEGMENT5 ||'-'|| 
                   GCC.SEGMENT6 ||'-'|| GCC.SEGMENT7 as cta,
                   GCC.SEGMENT1,
                   GCC.SEGMENT2,
                   GCC.SEGMENT3,
                   GCC.SEGMENT4,
                   GCC.SEGMENT5,
                   GCC.SEGMENT6,
                   GCC.SEGMENT7,
                   NVL (XAL.ENTERED_DR, 0)                   DEBITO_MON_TRANSACCION,
                   NVL (XAL.ENTERED_CR, 0)                   CREDITO_MON_TRANSACCION,
                   NVL (XAL.ACCOUNTED_DR, 0)                 DEBITO_MON_NACIONAL,
                   NVL (XAL.ACCOUNTED_CR, 0)                 CREDITO_MON_NACIONAL,
                   XAL.CURRENCY_CODE                         MONEDA,
                   NVL (XAL.CURRENCY_CONVERSION_RATE, 1)     TIPO_CAMBIO,
                   XAL.ACCOUNTING_CLASS_CODE                 CLASE_CUENTA
                   ,XTE.SOURCE_ID_INT_1                      ID_TRANSACCION
                   ,trunc(gjh.posted_date) as GL_POSTED_DATE
                   ,XAL.AE_LINE_NUM
                   ,xe.event_id
                   ,C.TRX_NUMBER
              FROM APPS.GL_JE_HEADERS            GJH,
                   APPS.GL_JE_LINES              GJL,
                   APPS.GL_CODE_COMBINATIONS     GCC,
                   APPS.GL_IMPORT_REFERENCES     IMP,
                   APPS.XLA_AE_LINES             XAL,
                   APPS.XLA_AE_HEADERS           XAH,
                   APPS.XLA_EVENTS               XE,
                   XLA.XLA_TRANSACTION_ENTITIES  XTE,
                   APPS.RA_CUSTOMER_TRX_ALL      C
             WHERE     1 = 1
                   AND GJH.PERIOD_NAME =pin_period_name
                   AND GJH.JE_SOURCE = 'Receivables'
                   AND GJH.JE_CATEGORY IN ('Sales Invoices','Credit Memos', 'Debit Memos')
                   AND GJH.CURRENCY_CODE != 'MXN'
                   AND GJL.JE_HEADER_ID = GJH.JE_HEADER_ID
                   AND GCC.CODE_COMBINATION_ID = GJL.CODE_COMBINATION_ID
                   AND IMP.JE_HEADER_ID = GJL.JE_HEADER_ID
                   AND IMP.JE_LINE_NUM = GJL.JE_LINE_NUM
                   AND XAL.GL_SL_LINK_ID = IMP.GL_SL_LINK_ID
                   AND XAL.GL_SL_LINK_TABLE = IMP.GL_SL_LINK_TABLE
                   AND XAL.APPLICATION_ID = 222
                   AND XAH.APPLICATION_ID = XAL.APPLICATION_ID
                   AND XAH.AE_HEADER_ID = XAL.AE_HEADER_ID
                   AND XE.APPLICATION_ID = XAH.APPLICATION_ID
                   AND XE.EVENT_ID = XAH.EVENT_ID
                   AND XTE.APPLICATION_ID = XE.APPLICATION_ID
                   AND XTE.ENTITY_ID = XE.ENTITY_ID
                   AND XTE.ENTITY_CODE = 'TRANSACTIONS'
                   AND XTE.SOURCE_ID_INT_1 = C.CUSTOMER_TRX_ID
                   AND NOT EXISTS (SELECT 'EX' FROM XXAR_FLUCTUACION_GL_TBL GL WHERE 1=1 AND GL.PERIODO = GJH.PERIOD_NAME) 
            UNION (
                SELECT GJH.JE_HEADER_ID,
                   GJH.JE_SOURCE,
                   GJH.JE_CATEGORY,
                   GJH.PERIOD_NAME                           PERIODO,
                   GCC.CODE_COMBINATION_ID,
                   GCC.SEGMENT1 ||'-'|| 
                   GCC.SEGMENT2 ||'-'|| 
                   GCC.SEGMENT3 ||'-'|| 
                   GCC.SEGMENT4 ||'-'|| 
                   GCC.SEGMENT5 ||'-'|| 
                   GCC.SEGMENT6 ||'-'|| GCC.SEGMENT7 as cta,
                   GCC.SEGMENT1,
                   GCC.SEGMENT2,
                   GCC.SEGMENT3,
                   GCC.SEGMENT4,
                   GCC.SEGMENT5,
                   GCC.SEGMENT6,
                   GCC.SEGMENT7,
                   NVL (XAL.ENTERED_DR, 0)                   DEBITO_MON_TRANSACCION,
                   NVL (XAL.ENTERED_CR, 0)                   CREDITO_MON_TRANSACCION,
                   NVL (XAL.ACCOUNTED_DR, 0)                 DEBITO_MON_NACIONAL,
                   NVL (XAL.ACCOUNTED_CR, 0)                 CREDITO_MON_NACIONAL,
                   XAL.CURRENCY_CODE                         MONEDA,
                   NVL (XAL.CURRENCY_CONVERSION_RATE, 1)     TIPO_CAMBIO,
                   XAL.ACCOUNTING_CLASS_CODE                 CLASE_CUENTA
                   ,XTE.SOURCE_ID_INT_1                      ID_TRANSACCION
                   ,trunc(gjh.posted_date) as GL_POSTED_DATE
                   ,XAL.AE_LINE_NUM
                   ,xe.event_id
                   ,ACR.RECEIPT_NUMBER
              FROM APPS.GL_JE_HEADERS            GJH,
                   APPS.GL_JE_LINES              GJL,
                   APPS.GL_CODE_COMBINATIONS     GCC,
                   APPS.GL_IMPORT_REFERENCES     IMP,
                   APPS.XLA_AE_LINES             XAL,
                   APPS.XLA_AE_HEADERS           XAH,
                   APPS.XLA_EVENTS               XE,
                   XLA.XLA_TRANSACTION_ENTITIES  XTE,
                   APPS.AR_CASH_RECEIPTS_ALL     ACR
             WHERE     1 = 1
                   AND GJH.PERIOD_NAME =pin_period_name
                   AND GJH.JE_SOURCE = 'Receivables'
                   AND GJH.JE_CATEGORY IN ('Receipts')
                   AND GJH.CURRENCY_CODE != 'MXN'
                   AND GJL.JE_HEADER_ID = GJH.JE_HEADER_ID
                   AND GCC.CODE_COMBINATION_ID = GJL.CODE_COMBINATION_ID
                   AND IMP.JE_HEADER_ID = GJL.JE_HEADER_ID
                   AND IMP.JE_LINE_NUM = GJL.JE_LINE_NUM
                   AND XAL.GL_SL_LINK_ID = IMP.GL_SL_LINK_ID
                   AND XAL.GL_SL_LINK_TABLE = IMP.GL_SL_LINK_TABLE
                   AND XAL.APPLICATION_ID = 222
                   AND XAH.APPLICATION_ID = XAL.APPLICATION_ID
                   AND XAH.AE_HEADER_ID = XAL.AE_HEADER_ID
                   AND XE.APPLICATION_ID = XAH.APPLICATION_ID
                   AND XE.EVENT_ID = XAH.EVENT_ID
                   AND XTE.APPLICATION_ID = XE.APPLICATION_ID
                   AND XTE.ENTITY_ID = XE.ENTITY_ID
                   AND XTE.ENTITY_CODE = 'RECEIPTS'
                   AND XTE.SOURCE_ID_INT_1 = ACR.CASH_RECEIPT_ID
                   AND NOT EXISTS (SELECT 'EX' FROM XXAR_FLUCTUACION_GL_TBL GL WHERE 1=1 AND GL.PERIODO = GJH.PERIOD_NAME) 
           )
           UNION (
                SELECT GJH.JE_HEADER_ID,
                   GJH.JE_SOURCE,
                   GJH.JE_CATEGORY,
                   GJH.PERIOD_NAME                           PERIODO,
                   GCC.CODE_COMBINATION_ID,
                   GCC.SEGMENT1 ||'-'|| 
                   GCC.SEGMENT2 ||'-'|| 
                   GCC.SEGMENT3 ||'-'|| 
                   GCC.SEGMENT4 ||'-'|| 
                   GCC.SEGMENT5 ||'-'|| 
                   GCC.SEGMENT6 ||'-'|| GCC.SEGMENT7 as cta,
                   GCC.SEGMENT1,
                   GCC.SEGMENT2,
                   GCC.SEGMENT3,
                   GCC.SEGMENT4,
                   GCC.SEGMENT5,
                   GCC.SEGMENT6,
                   GCC.SEGMENT7,
                   NVL (XAL.ENTERED_DR, 0)                   DEBITO_MON_TRANSACCION,
                   NVL (XAL.ENTERED_CR, 0)                   CREDITO_MON_TRANSACCION,
                   NVL (XAL.ACCOUNTED_DR, 0)                 DEBITO_MON_NACIONAL,
                   NVL (XAL.ACCOUNTED_CR, 0)                 CREDITO_MON_NACIONAL,
                   XAL.CURRENCY_CODE                         MONEDA,
                   NVL (XAL.CURRENCY_CONVERSION_RATE, 1)     TIPO_CAMBIO,
                   XAL.ACCOUNTING_CLASS_CODE                 CLASE_CUENTA
                   ,XTE.SOURCE_ID_INT_1                      ID_TRANSACCION
                   ,trunc(gjh.posted_date) as GL_POSTED_DATE
                   ,XAL.AE_LINE_NUM
                   ,xe.event_id
                   ,AAA.ADJUSTMENT_NUMBER
              FROM APPS.GL_JE_HEADERS            GJH,
                   APPS.GL_JE_LINES              GJL,
                   APPS.GL_CODE_COMBINATIONS     GCC,
                   APPS.GL_IMPORT_REFERENCES     IMP,
                   APPS.XLA_AE_LINES             XAL,
                   APPS.XLA_AE_HEADERS           XAH,
                   APPS.XLA_EVENTS               XE,
                   XLA.XLA_TRANSACTION_ENTITIES  XTE,
                   APPS.AR_ADJUSTMENTS_ALL       AAA
             WHERE     1 = 1
                   AND GJH.PERIOD_NAME =pin_period_name
                   AND GJH.JE_SOURCE = 'Receivables'
                   AND GJH.JE_CATEGORY IN ('Adjustment')
                   AND GJH.CURRENCY_CODE != 'MXN'
                   AND GJL.JE_HEADER_ID = GJH.JE_HEADER_ID
                   AND GCC.CODE_COMBINATION_ID = GJL.CODE_COMBINATION_ID
                   AND IMP.JE_HEADER_ID = GJL.JE_HEADER_ID
                   AND IMP.JE_LINE_NUM = GJL.JE_LINE_NUM
                   AND XAL.GL_SL_LINK_ID = IMP.GL_SL_LINK_ID
                   AND XAL.GL_SL_LINK_TABLE = IMP.GL_SL_LINK_TABLE
                   AND XAL.APPLICATION_ID = 222
                   AND XAH.APPLICATION_ID = XAL.APPLICATION_ID
                   AND XAH.AE_HEADER_ID = XAL.AE_HEADER_ID
                   AND XE.APPLICATION_ID = XAH.APPLICATION_ID
                   AND XE.EVENT_ID = XAH.EVENT_ID
                   AND XTE.APPLICATION_ID = XE.APPLICATION_ID
                   AND XTE.ENTITY_ID = XE.ENTITY_ID
                   AND XTE.ENTITY_CODE = 'ADJUSTMENTS'  
                   AND XTE.SOURCE_ID_INT_1 = AAA.ADJUSTMENT_ID
                   AND NOT EXISTS (SELECT 'EX' FROM XXAR_FLUCTUACION_GL_TBL GL WHERE 1=1 AND GL.PERIODO = GJH.PERIOD_NAME) 
           );
           
       COMMIT;
       
       UPDATE XXAR_FLUCTUACION_CTRL_TBL c
        SET ESTATUS = pin_modo_ejecucion
            ,LAST_UPDATED_DATE = SYSDATE
            ,LAST_UPDATE_BY = pin_user_id
            ,(SUM_PEND_MES_ANTERIOR_MXN,SUM_FACTURADO_MXN,SUM_COBRADO_MXN,SUM_PEND_PERIODO_MXN,SUM_MONTO_FLUCTUACION_MXN) =
                (select sum(TRX_PEN_MES_ANT_MXN),SUM(TRX_FACTURADO_MXN),SUM(P_SCOBRADO_MXN),SUM(TRX_PEN_MES_ACT_mxn),SUM(MONTO_FLUCTUACION_MXN)
                    from XXAR_FLUCTUACION_PERIODO_SUM s
                    where 1=1
                    and s.period_name = c.period_name
                    group by period_name)
        where 1=1
        and period_name = pin_period_name;                        
        
        pin_no_error := 0;
        pin_msj_error := '<br>Termino Correctamente el procesamiento para el periodo '||pin_period_name;
        
        commit;
    exception 
        when others then
            pin_no_error := 1111;
            pin_msj_error := 'ERROR: ERRENO NO CONTROLADO AL EJECUTAR LA FLUCTUACIÓN DE IVA AR EN LA BASE DE DATOS. REPORTAR A SISTEMAS';
    end ejecuta_fluctuacion_db;
end xxar_fluctuacion_pkg;