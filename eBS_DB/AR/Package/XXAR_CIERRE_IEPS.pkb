CREATE OR REPLACE PACKAGE BODY XXWEBC.XXAR_CIERRE_IEPS 
AS
    PROCEDURE l (p_in_msg IN VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE (p_in_msg);
        apps.fnd_file.put_line (apps.fnd_file.LOG, p_in_msg);
    END l;

    PROCEDURE MSJOUT (p_in_message IN VARCHAR2)
    IS
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.output, p_in_message);
    END MSJOUT;

    PROCEDURE LogPrc(P_SEC IN NUMBER, P_PERIOD_OR_DATE IN VARCHAR2, P_TEXT IN VARCHAR2, P_REQUEST_ID IN NUMBER DEFAULT NULL)
    IS
    BEGIN
        insert into XXAR_CIERRE_IEPS_LOG_TBL
            (SEC,PERIOD_OR_DATE,TEXT,REQUEST_ID)
            select P_SEC, P_PERIOD_OR_DATE, P_TEXT, P_REQUEST_ID
            from dual; 
        commit;
    END LogPrc;

    PROCEDURE EXECUTE_CUBE(p_date IN VARCHAR2
                           ,p_copy_to_history IN VARCHAR2) -- 'S' 'Y' or 'N' 

    IS
        v_period_or_date_str VARCHAR2(25);
        v_period_or_date date;
        exit_raise EXCEPTION;
        v_count NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''LATIN AMERICAN SPANISH''';
        --
        v_period_or_date_str := p_date;
        v_period_or_date := to_date(v_period_or_date_str, 'YYYY-MM-DD');

        logprc(1, v_period_or_date_str, 'INICIA PROCESO CUBO');
        logprc(1, v_period_or_date_str, 'INICIA PROCESO CUBO p_date='||v_period_or_date_str||' p_copy_to_history='||p_copy_to_history);

        --delete XXWEBC.CUST_AR_LOAD_CUBO;
        --commit;
        IF UPPER(p_copy_to_history) IN ('S','Y','SI') THEN
            BEGIN
                v_count := 0;
                SELECT COUNT(1) INTO v_count 
                FROM XXWEBC.CUST_AR_LOAD_CUBO_H
                WHERE 1=1
                AND DIA_OPERACION = v_period_or_date;
                
                IF v_count > 0 THEN
                    logprc(1, v_period_or_date_str, 'YA EXISTEN DATOS EN HISTORICO, POR LO QUE NO ES POSIBLE SEGUIR EL PROCESO');
                    raise exit_raise;
                END IF;
            END;
        END IF;

        logprc(1, v_period_or_date_str, 'TRUNCA TABLA CUBO');
        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXWEBC.CUST_AR_LOAD_CUBO';
        commit;

        logprc(1, v_period_or_date_str, 'INICIA EJECUCION CUBO');
        APPS.CUBO_INFO(v_period_or_date);
        logprc(1, v_period_or_date_str, 'TERMINA EJECUCION CUBO');

        IF UPPER(p_copy_to_history) IN ('S','Y','SI') THEN
            logprc(1, v_period_or_date_str, 'COPIANDO DATOS A HISTORICO');
            INSERT INTO XXWEBC.CUST_AR_LOAD_CUBO_H
            SELECT * 
            FROM XXWEBC.CUST_AR_LOAD_CUBO;
            COMMIT;
        END IF;

        SELECT COUNT(1) 
            INTO v_count
        FROM XXWEBC.CUST_AR_LOAD_CUBO;
        
        logprc(1, v_period_or_date_str, 'CONTEO DE CUBO: '||v_count);

        SELECT COUNT(1)
            INTO v_count
        FROM XXWEBC.CUST_AR_LOAD_CUBO_H
        WHERE DIA_OPERACION = v_period_or_date;
        logprc(1, v_period_or_date_str, 'CONTEO DE HISTORICO: '||v_count);
        
        logprc(1, v_period_or_date_str, 'TERMINO PROCESO CUBO');
    EXCEPTION
        WHEN exit_raise THEN
            LOGPRC(1, v_period_or_date_str, 'SALIENDO DEL PROCESO EXECUTE_CUBE');
        WHEN OTHERS THEN
            LOGPRC(1, v_period_or_date_str, 'ERROR EN PROCESO EXECUTE_CUBE: '||SQLERRM);
    END EXECUTE_CUBE;

    PROCEDURE EXECUTE_CUBE_INTERCO(p_date IN VARCHAR2)
    IS
        v_period_or_date_str VARCHAR2(25);
        v_period_or_date date;
        exit_raise EXCEPTION;
        v_count NUMBER;
        v_dato boolean;
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
        --v_period_or_date := p_date;
        v_period_or_date_str := p_date;--TO_CHAR(p_date, 'YYYY-MM-DD');
        v_period_or_date := to_date(v_period_or_date_str, 'YYYY-MM-DD');

        logprc(2, v_period_or_date_str, 'INICIA PROCESO CUBO INTERCO');
        logprc(2, v_period_or_date_str, 'INICIA PROCESO CUBO INTERCO p_date='||v_period_or_date_str);

        v_count := 0;
        SELECT COUNT(1) INTO v_count 
        FROM XXWEBC.CUST_AR_LOAD_CUBO_INT
        WHERE 1=1
        AND DIA_OPERACION = v_period_or_date;

        
        IF v_count > 0 THEN
            logprc(2, v_period_or_date_str, 'YA EXISTEN DATOS EN CUST_AR_LOAD_CUBO_INT, POR LO QUE NO ES POSIBLE SEGUIR EL PROCESO');
            raise exit_raise;
        END IF;

        logprc(2, v_period_or_date_str, 'INICIA PROCESO CUBO INTERCOMPANY');

        V_DATO := APPS.CUST_AR_ANTIGUEDAD_SALDO.LOAD_TRX(v_period_or_date,
                                                        null,                         -- p_cte_desde,
                                                        null,                         -- p_cte_hasta,
                                                        null,                         -- p_ejecutivo,
                                                        1000,                         -- p_mayor,
                                                        'IN',                         -- p_tipo_trx,
                                                        null,                         -- p_cia,
                                                        'Y');                         -- p_tipo_trx,
        --
        IF (V_DATO) THEN
        --
            INSERT INTO XXWEBC.CUST_AR_LOAD_CUBO_INT
                    select /*+ index(c ar_payment_schedules_u1)*/ 
                    c.TRX_NUMBER,
                    NULL,
                    NULL,
                    NULL,
                    NULL,
                    NULL,
                    c.TRX_DATE,
                    c.INVOICE_CURRENCY_CODE,
                    NULL,
                    NULL,
                    NULL,
                    NULL,
                    v_period_or_date,
                    NULL,
                    NULL,
                    NULL,
                    NULL,
                    NULL,
                    a.SHORT_CUST_NAME,
                    a.CUST_ID,
                    a.CUST_NO,
                    a.SORT_FIELD1,
                    a.SORT_FIELD2,
                    a.PAYMENT_SCHED_ID,
                    a.CLASS,
                    a.DUE_DATE,
                    a.AMT_DUE_REMAINING,
                    a.DAYS_PAST_DUE,
                    a.AMOUNT_ADJUSTED,
                    a.AMOUNT_APPLIED,
                    a.AMOUNT_CREDITED,
                    a.GL_DATE,
                    a.DATA_CONVERTED,
                    a.PS_EXCHANGE_RATE,
                    a.B0,
                    a.B1,
                    a.B2,
                    a.B3,
                    a.B4,
                    a.B5,
                    a.B6,
                    a.B7,
                    a.B8,
                    a.B9,
                    a.B10,
                    a.B11,
                    a.B12,
                    a.B13,
                    a.B14,
                    a.B15,
                    a.B16,
                    a.B17,
                    a.B18,
                    a.B19,
                    a.B20,
                    a.BAL_SEGMENT_VALUE,
                    a.INV_TID,
                    a.INVOICE_TYPE,
                    a.ORG_ID,
                    a.ZONA,
                    a.REGION,
                    a.GERENTE,
                    a.EJECUTIVO,
                    a.CANAL,
                    a.PLAZO,
                    a.VTAS,
                    a.CREDITO,
                    a.PORC_CRED,
                    a.VIGENTE,
                    a.PORC_VIGENTE,
                    a.VENCIDO,
                    a.PORC_VENCIDO,
                    NULL,
                    c.customer_trx_id 
                    from apps.Cust_Tt_Ar_Load_Trx_As a
                        ,apps.ar_payment_schedules_all c
                    WHERE 1=1
                    and A.PAYMENT_SCHED_ID = C.PAYMENT_SCHEDULE_ID;

                    COMMIT;
                    
                    UPDATE XXWEBC.CUST_AR_LOAD_CUBO_INT A
                    SET 
                    (A.NUMERO_EDITADO ,A.REMISION,A.NUMERO_RECIBO, A.FECHA_RECIBO,A.PURCHASE_ORDER) = 
                                    (SELECT SUBSTR(B.ATTRIBUTE6,1,50),SUBSTR(B.ATTRIBUTE7,1,50),B.ATTRIBUTE8,B.ATTRIBUTE9,B.PURCHASE_ORDER
                                    FROM AR.RA_CUSTOMER_TRX_ALL B
                                    WHERE   1=1 
                                    AND     B.CUSTOMER_TRX_ID = A.CUSTOMER_TRX_ID)
                    WHERE 1=1
                    AND DIA_OPERACION=v_period_or_date;
                    commit;       
                
                    UPDATE XXWEBC.CUST_AR_LOAD_CUBO_INT A
                    SET A.EMPRESA = (SELECT B.NAME
                            FROM hr.hr_all_organization_units B
                            WHERE  A.ORG_ID = B.organization_id)
                    WHERE 1=1
                    AND DIA_OPERACION=v_period_or_date;  
                    commit; 

                    UPDATE XXWEBC.CUST_AR_LOAD_CUBO_INT A
                    SET A.COBRADOR = (SELECT E.NAME
                            FROM   AR.HZ_CUST_ACCOUNTS B,          
                                    AR.HZ_PARTIES C,               
                                    AR.HZ_CUSTOMER_PROFILES D,      
                                    AR.AR_COLLECTORS E                 
                            WHERE  B.CUST_ACCOUNT_ID = A.CUST_ID
                            AND    A.CUST_ID = D.CUST_ACCOUNT_ID
                            AND    B.PARTY_ID = C.PARTY_ID
                            AND    C.PARTY_ID = D.PARTY_ID
                            AND    D.SITE_USE_ID IS NULL
                            AND    D.STATUS = 'A'
                            AND    E.STATUS = 'A'
                            AND    D.COLLECTOR_ID = E.COLLECTOR_ID)
                    WHERE 1=1
                    AND DIA_OPERACION=v_period_or_date;
                    commit;

                    UPDATE XXWEBC.CUST_AR_LOAD_CUBO_INT A
                    SET A.OVERALL_CREDIT_LIMIT = (SELECT E.OVERALL_CREDIT_LIMIT
                            FROM   AR.HZ_CUST_ACCOUNTS B,                         
                                    AR.HZ_PARTIES C,                              
                                    AR.HZ_CUSTOMER_PROFILES D,                     
                                    AR.HZ_CUST_PROFILE_AMTS E
                            WHERE  B.CUST_ACCOUNT_ID = A.CUST_ID
                            AND    A.CUST_ID = D.CUST_ACCOUNT_ID
                            AND    B.PARTY_ID = C.PARTY_ID
                            AND    C.PARTY_ID = D.PARTY_ID
                            AND    D.SITE_USE_ID IS NULL
                            AND    D.STATUS = 'A'
                            AND    B.CUST_ACCOUNT_ID = E.CUST_ACCOUNT_ID
                            AND    D.CUST_ACCOUNT_PROFILE_ID = E.CUST_ACCOUNT_PROFILE_ID)
                    WHERE 1=1
                    AND DIA_OPERACION=v_period_or_date;
                    commit;
                    --Operadora

                    UPDATE XXWEBC.CUST_AR_LOAD_CUBO_INT A
                    SET ID_OPERADORA =(
                                        SELECT  DISTINCT ATTRIBUTE3 
                                        FROM    AR.HZ_CUST_ACCT_SITES_ALL
                                        WHERE   CUST_ACCOUNT_ID = A.CUST_ID
                                        AND     ORIG_SYSTEM_REFERENCE = A.CUST_NO 
                                        AND     ORG_ID = A.ORG_ID 
                                        AND     STATUS = 'A'
                                        AND     BILL_TO_FLAG = 'P')
                    WHERE 1=1
                    AND DIA_OPERACION=v_period_or_date;
                    commit;

                    -- Descripci�n corta de la operadora

                    UPDATE XXWEBC.CUST_AR_LOAD_CUBO_INT A
                    SET DESC_CORTA =(
                        SELECT  DESC_CORTA
                        FROM    APPS.CUST_AR_OPERADORAS
                        WHERE   ID_OPERADORA = A.ID_OPERADORA)
                    WHERE 1=1
                    AND DIA_OPERACION=v_period_or_date;  
                    commit;  

                    -- Actualizar monto original

                    UPDATE XXWEBC.CUST_AR_LOAD_CUBO_INT A
                    SET AMOUNT_DUE_ORIGINAL =(
                        SELECT  AMOUNT_DUE_ORIGINAL 
                        FROM    AR.AR_PAYMENT_SCHEDULES_ALL B 
                        WHERE   B.CUSTOMER_TRX_ID = A.CUSTOMER_TRX_ID)
                    WHERE 1=1
                    AND DIA_OPERACION=v_period_or_date;
                    commit;
                    
                    -- Actualiza ejecutivo
                    UPDATE XXWEBC.CUST_AR_LOAD_CUBO_INT
                    SET EJECUTIVO=(SELECT  ATTRIBUTE15 
                        FROM    apps.ra_customers rc 
                        WHERE   CUST_ID = rc.customer_id)
                    WHERE 1=1
                    AND DIA_OPERACION=v_period_or_date;
                    commit;
                    
                    UPDATE XXWEBC.CUST_AR_LOAD_CUBO_INT A
                    SET (A.UUID,A.STATUS,A.DES_STATUS,A.FECHA_STATUS) = (SELECT B.UUID ,B.ESTATUS, B.DESCRIPCION_ESTATUS,B.FECHA_CERTIFICADO
                            FROM AR.CUST_AR_FACTELEC_LOG B
                            WHERE   1=1 
                            AND     B.CUSTOMER_TRX_ID = A.CUSTOMER_TRX_ID
                            AND     B.NUMERO_DOCTO = A.TRX_NUMBER)
                    WHERE 1=1
                    AND DIA_OPERACION=v_period_or_date;
                    COMMIT;
                END IF;

        logprc(2, v_period_or_date_str, 'TERMINA PROCESO CUBO INTERCOMPANY');


    EXCEPTION
        WHEN exit_raise THEN
            LOGPRC(2, v_period_or_date_str, 'SALIENDO DEL PROCESO EXECUTE_CUBE_INTERCO');
        WHEN OTHERS THEN
            LOGPRC(2, v_period_or_date_str, 'ERROR EN PROCESO EXECUTE_CUBE_INTERCO: '||SQLERRM);

    END EXECUTE_CUBE_INTERCO;

    PROCEDURE EXECUTE_PORTFOLIO_RECEIVABLE(p_date IN VARCHAR2)
    IS
        v_period_or_date_str VARCHAR2(25);
        v_period_or_date date;
        exit_raise EXCEPTION;
        v_count NUMBER;
        v_existe_carga_cubo number;
        
        V_FECHA_CARGA_CUBO date;
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
        --v_period_or_date := p_date;
        v_period_or_date_str := p_date;
         v_period_or_date := to_date(v_period_or_date_str, 'YYYY-MM-DD');
        V_FECHA_CARGA_CUBO := v_period_or_date;

        LOGPRC(3, v_period_or_date_str, 'INICIA PROCESO EXECUTE_PORTFOLIO_RECEIVABLE');
        LOGPRC(3, v_period_or_date_str, 'INICIA PROCESO EXECUTE_PORTFOLIO_RECEIVABLE p_date='||v_period_or_date_str);

        select COUNT(*)
          INTO v_existe_carga_cubo
        from XXWEBC.CUST_AR_LOAD_CUBO c
        WHERE 1 = 1
        AND DIA_OPERACION = V_FECHA_CARGA_CUBO
        AND ROWNUM=1;

        logprc(3, v_period_or_date_str, '3 v_existe_carga_cubo:'||v_existe_carga_cubo);

            
            /*SELECT COUNT(*)
            INTO v_existe_carga
            FROM XXWEBC.REPORTE_CART_VENC_IEPS_2026_H CVH
            WHERE 1=1
            AND fecha_cubo =V_FECHA_CARGA_CUBO
            AND ROWNUM=1;*/ -- Se guardaba el historico pero nunca se ha ocupado

        if v_existe_carga_cubo = 0 then
            logprc(3, v_period_or_date_str, '3 No existe carga del cubo para la fecha indicada, por lo que no se puede continuar con el proceso');
            raise exit_raise;
        else
            logprc(3, v_period_or_date_str, '3 Si existe carga del cubo para la fecha indicada, se continua con el proceso');
        end if;

        IF v_existe_carga_cubo >0  THEN
                -- respalda ejecición anterior
                --insert into xxar_log_prc_ieps2026
                --select 2, '2 inicia respaldo ejecición anterior' ,sysdate from dual; commit;
                /*
                DECLARE
                    v_limit PLS_INTEGER := 500;
                    CURSOR cur_d IS
                        SELECT *
                        FROM XXWEBC.REPORTE_CART_VENC_IEPS_2026 CV
                        WHERE 1=1
                        AND fecha_cubo =V_FECHA_CARGA_CUBO;

                TYPE cur_d_tb IS TABLE OF cur_d%ROWTYPE INDEX BY PLS_INTEGER;
                    cur_d_arr cur_d_tb;

                BEGIN
                        
                            OPEN  cur_d ;
                            LOOP
                                FETCH cur_d BULK COLLECT INTO cur_d_arr LIMIT v_limit;
                                FORALL i IN 1 .. cur_d_arr.COUNT
                                insert into  REPORTE_CART_VENC_IEPS_2026_H values cur_d_arr(i);
                                
                                COMMIT;

                                insert into xxar_log_prc_ieps2026
                                select 2, '2 inserta ' ,sysdate from dual; commit;
                                EXIT WHEN cur_d%NOTFOUND;
                            END LOOP;
                            CLOSE cur_d;
                            COMMIT;                
                END;*/

            logprc(3, v_period_or_date_str, '3 Se quitan los customer_trx_id que ya no juegan en el cubo');
               
            -- Se quitan los customer_trx_id que ya no juegan en el cubo
            DECLARE
                v_limit PLS_INTEGER := 500;
                CURSOR cur_d IS
                select distinct customer_trx_id 
                    from REPORTE_CART_VENC_IEPS_2026 cv
                    where 1=1
                    and not exists (select 'ex'
                                    from XXWEBC.CUST_AR_LOAD_CUBO c
                                    WHERE 1 = 1
                                    AND c.DIA_OPERACION = V_FECHA_CARGA_CUBO--TO_DATE('08-12-2025','DD-MM-YYYY')
                                    and c.customer_trx_id = cv.customer_trx_id)
                    --and rownum<200
                    ;
                TYPE cur_d_tb IS TABLE OF cur_d%ROWTYPE INDEX BY PLS_INTEGER;
                cur_d_arr cur_d_tb;
            BEGIN
                logprc(3, v_period_or_date_str, '3 ini quitar customers_trx_id' );

                OPEN  cur_d ;
                LOOP
                    FETCH cur_d BULK COLLECT INTO cur_d_arr LIMIT v_limit;
                    FORALL i IN 1 .. cur_d_arr.COUNT
                    DELETE FROM REPORTE_CART_VENC_IEPS_2026 WHERE customer_trx_id = cur_d_arr(i).customer_trx_id;
                    COMMIT;
                    EXIT WHEN cur_d%NOTFOUND;
                END LOOP;
                CLOSE cur_d;
                COMMIT;
                logprc(3, v_period_or_date_str, '3 fin quitar customers_trx_id' );
            END;
                
            -- De lo que se quedo en la tabla se actualiza el monto remanente en caso que haya cambiado
            BEGIN
                
                logprc(4, v_period_or_date_str, '4 ini actualiza monto remanente' );
                for cur in (select cva.*, p.amount_due_original, p.amount_due_remaining,p.status
                            from (
                                    SELECT cv.CUSTOMER_TRX_ID, cv.TOTAL_DOCUMENTO, cv.TOTAL_REMANENTE
                                    FROM XXWEBC.REPORTE_CART_VENC_IEPS_2026 CV                    
                                    WHERE 1=1
                                    GROUP BY cv.CUSTOMER_TRX_ID, cv.TOTAL_DOCUMENTO, cv.TOTAL_REMANENTE) cva
                                ,AR.AR_PAYMENT_SCHEDULES_ALL P
                            where 1=1
                            AND cva.CUSTOMER_TRX_ID = P.CUSTOMER_TRX_ID
                            AND TOTAL_REMANENTE != p.amount_due_remaining)
                LOOP
                    update REPORTE_CART_VENC_IEPS_2026 cv
                    set TOTAL_REMANENTE = cur.amount_due_remaining
                        ,status = cur.status
                        ,columna ='R'
                    WHERE cv.customer_trx_id = cur.customer_trx_id;
                end loop;
                COMMIT;
                logprc(4, v_period_or_date_str, '4 fin actualiza monto remanente' );
            END;

            -- Se actualizan los datos exsitentes
            DECLARE
                v_limit PLS_INTEGER := 500;
                CURSOR cur_d IS
                select  customer_trx_id 
                    from REPORTE_CART_VENC_IEPS_2026 cv
                    WHERE 1=1
                    AND FECHA_ACTUALIZACION_TI !=trunc(sysdate)
                    group by customer_trx_id
                    --and rownum<200
                    ;
                TYPE cur_d_tb IS TABLE OF cur_d%ROWTYPE INDEX BY PLS_INTEGER;
                cur_d_arr cur_d_tb;
            BEGIN
                logprc(4.1, v_period_or_date_str, '4.1 ini actualiza datos existentes' );

                OPEN  cur_d ;
                LOOP
                    FETCH cur_d BULK COLLECT INTO cur_d_arr LIMIT v_limit;
                    FORALL i IN 1 .. cur_d_arr.COUNT
                    UPDATE  REPORTE_CART_VENC_IEPS_2026 
                    SET fecha_actualizacion_ti = trunc(sysdate)
                        ,columna = case when columna= 'R' THEN 'R' ELSE 'O' END -- R refresch, O original
                        ,fecha_cubo=V_FECHA_CARGA_CUBO
                    WHERE customer_trx_id = cur_d_arr(i).customer_trx_id
                    ;
                    COMMIT;
                    EXIT WHEN cur_d%NOTFOUND;
                END LOOP;
                CLOSE cur_d;
                COMMIT;
                logprc(4.2, v_period_or_date_str, '4.2 fin actualiza datos existentes' );
            END;

            -- Se insertan solo los nuevos customer_trx_id que no estan y que esten en estatus OP
            declare
                v_limit PLS_INTEGER := 500;
                CURSOR cur_d IS
                WITH TRX_GL AS (select -666 fila,p.customer_trx_id, p.trx_number, p.amount_due_remaining as TOTAL_REMANENTE, p.status, p.amount_due_original as TOTAL_DOCUMENTO
                                                from XXWEBC.CUST_AR_LOAD_CUBO c
                                                    ,AR.AR_PAYMENT_SCHEDULES_ALL P
                                                WHERE 1 = 1
                                                --and rownum <100
                                                AND c.DIA_OPERACION = V_FECHA_CARGA_CUBO--TO_DATE('08-12-2025','DD-MM-YYYY')
                                                and not exists (select 'ex'
                                                                from REPORTE_CART_VENC_IEPS_2026 cv
                                                                where 1=1
                                                                and cv.customer_trx_id = c.customer_trx_id )
                                                and p.customer_trx_id = c.customer_trx_id
                                                and p.status = 'OP'
                            )
                select rownum consecutivo, g.fila registro_interno, Trxl.Customer_Trx_Line_Id ,trx1.customer_trx_id, cte.tax_reference rfc_cliente, cte.customer_name nombre_cliente, 
                cte.customer_number no_cliente,
                cte.attribute20 pais_cliente, trx1.trx_number as no_factura , tt.name as tipo_transaccion, trx1.trx_date as fecha_factura, 
                trx1.INVOICE_CURRENCY_CODE divisa, NVL(trx1.EXCHANGE_RATE,1) TIPO_CAMBIO,tt.type as tipo
                ,case when trxl.line_type != 'TAX' THEN
                trxl.line_number
                else
                (select trxl2.line_number
                from apps.ra_customer_trx_lines_all trxl2
                where 1=1
                and trxl2.line_type != 'TAX'
                and trxl2.Customer_Trx_Line_Id = TRXL.LINK_TO_CUST_TRX_LINE_ID)
                END line_number
                , trxl.INVENTORY_ITEM_ID, i.segment1 Articulo, trxl.description
                ,trxl.line_type, trxl.UOM_CODE udm
                ,case when trxl.line_type != 'TAX' THEN
                trxl.TAX_CLASSIFICATION_CODE
                else
                (select trxl2.TAX_CLASSIFICATION_CODE
                from apps.ra_customer_trx_lines_all trxl2
                where 1=1
                and trxl2.Customer_Trx_Line_Id = TRXL.LINK_TO_CUST_TRX_LINE_ID)
                END TAX_CODE
                ,trxl.LINE_RECOVERABLE
                ,trxl.TAX_RECOVERABLE
                ,NVL (trxl.quantity_invoiced,trxl.quantity_credited) cantidad
                , trxl.UNIT_SELLING_PRICE precio_unitario, trxl.EXTENDED_AMOUNT importe_linea
                ,d1.ACCOUNT_CLASS
                ,d1.amount
                ,g.TOTAL_DOCUMENTO
                ,g.TOTAL_REMANENTE
                ,g.STATUS 
                ,d1.code_combination_id
                --,'''' || gcc.segment1
                --,'''' || gcc.segment2
                --,'''' || gcc.segment3
                --,'''' || gcc.segment4
                --,'''' || gcc.segment5
                --,'''' || gcc.segment6
                --,'''' || gcc.segment7
                ,gcc.segment1
                ,gcc.segment2
                ,gcc.segment3
                ,gcc.segment4
                ,gcc.segment5
                ,gcc.segment6
                ,gcc.segment7
                ,case when trxl.line_type is null then 'CXC'
                    when line_type = 'LINE' and substr(trxl.description,1,4) = 'IEPS' THEN 'IEPS'
                    when line_type = 'TAX' then 'IVA'
                    WHEN tt.TYPE= 'CM' AND d1.amount>0 THEN 'DESC'
                    WHEN tt.TYPE= 'INV' AND d1.amount< 0 THEN 'DESC'
                    else 'SKU'
                end tipo_dato,
                DECODE(NVL((SELECT e.IEPS_LITRO
                            from apps.XXAR_IEPS e
                            Where e.org_id   = Trx1.Org_Id
                            and e.segment1 = i.segment1),
                            0),0,'NO','SI') EXISTE,
                (TO_NUMBER(NVL(NVL(trxl.attribute2, NVL(trxl.quantity_invoiced,trxl.quantity_credited)),'0'))) CANTIDAD_USAR,
                NVL((SELECT e.IEPS_LITRO
                    from apps.XXAR_IEPS e
                    Where e.org_id   = Trx1.Org_Id
                        and e.segment1 = i.segment1),
                    0) factor_ieps_azucar_2026,
                CASE WHEN d1.amount > 0 THEN
                    CASE WHEN trxl.line_type IS NULL THEN 0
                        WHEN line_type = 'LINE' AND SUBSTR(trxl.description,1,4) = 'IEPS' THEN 0
                        WHEN line_type = 'TAX'  THEN 0
                    ELSE
                        CASE WHEN NVL((SELECT e.IEPS_LITRO 
                                    from apps.XXAR_IEPS e
                                    Where e.org_id   = Trx1.Org_Id
                                    and e.segment1 = i.segment1), 0) <= 0 THEN
                            
                                777
                        ELSE
                            (TO_NUMBER(NVL(NVL(trxl.attribute2, NVL(trxl.quantity_invoiced,trxl.quantity_credited)),'0')) * 
                            (SELECT e.IEPS_LITRO
                                FROM apps.XXAR_IEPS e
                                WHERE e.org_id   = Trx1.Org_Id
                                AND e.segment1 = i.segment1))
                        END
                    END
                ELSE 0
                END IEPS_AZUCAR_2026,
                NVL((SELECT e.IEPS_LITRO_ED
                    from apps.XXAR_IEPS e
                    Where e.org_id   = Trx1.Org_Id
                        and e.segment1 = i.segment1),
                    0) FACTOR_IEPS_EDUL_2026,
                CASE WHEN d1.amount > 0 THEN
                    CASE WHEN trxl.line_type IS NULL THEN 0
                        WHEN line_type = 'LINE' AND SUBSTR(trxl.description,1,4) = 'IEPS' THEN 0
                        WHEN line_type = 'TAX'  THEN 0
                    ELSE
                        (TO_NUMBER(NVL(NVL(trxl.attribute2, NVL(trxl.quantity_invoiced,trxl.quantity_credited)),'0')) * 
                        NVL((SELECT E.IEPS_LITRO_ED
                                FROM apps.XXAR_IEPS E
                            WHERE E.ORG_ID   = Trx1.Org_Id
                                AND E.SEGMENT1 = i.segment1),0))
                    END
                ELSE 0
                END IEPS_EDUL_2026,
                'N' COLUMNA,
                --''''||TO_CHAR(d1.gl_date,'DD-MM-YYYY') AS FECHA_CONTABLE,
                --''''||to_char (d1.gl_DATE,'MON-YY') AS PERIODO ,
                TO_CHAR(d1.gl_date,'DD-MM-YYYY') AS FECHA_CONTABLE,
                to_char (d1.gl_DATE,'MON-YY') AS PERIODO ,
                trxl.attribute2 cantidad_SIO,
                trxl.attribute3 precio_SIO,
                trxl.ATTRIBUTE6 imp_linea_SIO
                ,NULL IEPS_OROIGINAL
                ,NULL TASA_IMPUESTO
                ,NULL FACTOR_IEPS_ORIG
                ,NULL CALCULO_IEPS_ORIG
                ,SYSDATE FECHA_ACT_TI
                ,V_FECHA_CARGA_CUBO fecha_cubo
                from apps.ra_customer_trx_all trx1
                ,apps.ar_payment_schedules_all p1
                ,apps.ra_cust_trx_line_gl_dist_all d1
                ,apps.gl_code_combinations gl1
                ,apps.hr_all_organization_units hro
                ,apps.ra_customer_trx_lines_all trxl
                ,apps.mtl_system_items_b i
                ,apps.Ra_Cust_Trx_Types_All Tt
                ,apps.ra_customers cte
                ,apps.gl_code_combinations gcc
                ,trx_gl g
                where 1=1
                --and trx1.trx_number = 'KO957374'
                and trx1.customer_trx_id    = g.customer_trx_id
                AND trx1.TRX_NUMBER         = g.TRX_NUMBER
                And Trx1.Org_Id             = P1.Org_Id(+)
                And Trx1.Customer_Trx_Id    = P1.Customer_Trx_Id(+)
                And Trx1.Org_Id             = Tt.Org_Id
                And Trx1.Cust_Trx_Type_Id   = Tt.Cust_Trx_Type_Id
                And D1.Org_Id               = Trx1.Org_Id
                And D1.Customer_Trx_Id      = Trx1.Customer_Trx_Id
                And Gl1.Code_Combination_Id = D1.Code_Combination_Id
                And Hro.Organization_Id     = Trx1.Org_Id
                And D1.Org_Id               = Trxl.Org_Id(+)
                And D1.Customer_Trx_Id      = Trxl.Customer_Trx_Id(+)
                And D1.Customer_Trx_Line_Id = Trxl.Customer_Trx_Line_Id(+)
                And I.Organization_Id(+)    = 91
                And I.Inventory_Item_Id(+)  = Trxl.Inventory_Item_Id
                and cte.customer_id         = Trx1.bill_to_customer_id
                and gcc.code_combination_id = d1.code_combination_id
                --and d1.amount               > 0                        -- descartar descuentos
                order by trx1.trx_number, line_number, inventory_item_id;

                TYPE cur_d_tb IS TABLE OF cur_d%ROWTYPE INDEX BY PLS_INTEGER;
                cur_d_arr cur_d_tb;

            BEGIN
                    logprc(5, v_period_or_date_str, '5 ini inserta customer_trx_id faltantes' );                    
                    OPEN  cur_d ;
                    LOOP
                        FETCH cur_d BULK COLLECT INTO cur_d_arr LIMIT v_limit;
                        FORALL i IN 1 .. cur_d_arr.COUNT
                        insert into  REPORTE_CART_VENC_IEPS_2026 values cur_d_arr(i);
                        
                        COMMIT;
                        EXIT WHEN cur_d%NOTFOUND;
                    END LOOP;
                    CLOSE cur_d;
                    COMMIT;
                    logprc(5, v_period_or_date_str, '5 Fin inserta customer_trx_id faltantes' );
            END; -- terminainsert

            -- se eliminan los remanente es 0;
            logprc(5, v_period_or_date_str, '5.5 ini  se eliminan los remanente es 0;' ); 

            delete XXWEBC.REPORTE_CART_VENC_IEPS_2026 B
            where 1=1
            and total_remanente<=10;
            commit;

            logprc(5, v_period_or_date_str, '5.5 fin  se eliminan los remanente es 0;' ); 
            -- Actualiza el tipo de dato descuento
            UPDATE XXWEBC.REPORTE_CART_VENC_IEPS_2026 B
            SET EXISTE ='NA'
                ,FACTOR_IEPS_AZUCAR_2026=0
                , IEPS_AZUCAR_2026=0  
                ,FACTOR_IEPS_EDUL_2026=0  
                ,IEPS_EDUL_2026=0        
            WHERE 1=1
            --AND CUSTOMER_TRX_ID = 123544746
            AND TIPO_DATO ='DESC';

            commit;
            logprc(6, v_period_or_date_str, '6 Fin  Actualiza el tipo de dato descuento' ); 

            -- Actualiza factor ieps_2026 solo para los nuevos
            logprc(7, v_period_or_date_str, '7 ini  Actualiza factor ieps_2026 solo para los nuevos' ); 
            UPDATE XXWEBC.REPORTE_CART_VENC_IEPS_2026 B
            SET IEPS_AZUCAR_2026 = ( (SELECT IEPS_LITRO
                    FROM apps.XXAR_IEPS E
                    WHERE 1=1 AND ORG_ID=84 AND SEGMENT1= B.ARTICULO )* CANTIDAD_USAR)
                ,IEPS_EDUL_2026 = ( (SELECT IEPS_LITRO_ED
                    FROM apps.XXAR_IEPS E
                    WHERE 1=1 AND ORG_ID=84 AND SEGMENT1= B.ARTICULO )* CANTIDAD_USAR)
                ,FACTOR_IEPS_AZUCAR_2026=(SELECT IEPS_LITRO
                                            FROM apps.XXAR_IEPS E
                                            WHERE 1=1 AND ORG_ID=84 AND SEGMENT1= B.ARTICULO )
                ,FACTOR_IEPS_EDUL_2026=(SELECT IEPS_LITRO_ED
                                        FROM apps.XXAR_IEPS E
                                        WHERE 1=1 AND ORG_ID=84 AND SEGMENT1= B.ARTICULO )
            where 1=1
            AND TIPO_DATO ='SKU'
            AND EXISTE ='SI'
            and columna = 'N';

            commit;
            logprc(7, v_period_or_date_str, '7 fin  Actualiza factor ieps_2026 solo para los nuevos' ); 
            

            logprc(8, v_period_or_date_str, '8 ini  Se calcula factor_ieps_orig' );

            -- Se calcula factor_ieps_orig
            UPDATE  REPORTE_CART_VENC_IEPS_2026
                SET factor_ieps_orig =xxwebc.xxar_obtener_ieps_anho(84, TO_CHAR(FECHA_FACTURA,'MM'), TO_CHAR(FECHA_FACTURA,'YYYY'), ARTICULO)                    
                    ,tasa_impuesto = case when tax_code IN ('IEPS INC 25% INC 16%','IVA 16%','INC 16%') THEN 16
                                        WHEN TAX_CODE IN ('IEPS 8% INC 0%','IVA 0%','INC 0%') then 0
                                        when TAX_CODE IN ('INC 8%','IVA 8%') then 8
                                        else
                                            -666
                                        end

            where 1=1
            --AND IEPS_ORIGINAL =0
            --and calculo_ieps_orig >0
            --AND CUSTOMER_TRX_ID =96334091
            AND TIPO_DATO ='SKU'
            and columna = 'N';

            COMMIT;

            logprc(8, v_period_or_date_str, '8 fin  Se calcula factor_ieps_orig' ); commit;

            logprc(9, v_period_or_date_str, '9 ini  Se calcula calculo_ieps_orig y IEPS_ORIGINAL' );

            -- Se calcula calculo_ieps_orig y IEPS_ORIGINAL
            UPDATE  REPORTE_CART_VENC_IEPS_2026
                SET calculo_ieps_orig = factor_ieps_orig * CANTIDAD_USAR
                    ,IEPS_ORIGINAL = factor_ieps_orig * CANTIDAD_USAR

            where 1=1
            AND TIPO_DATO ='SKU'
            and columna = 'N';

            COMMIT;
            logprc(9, v_period_or_date_str, '9 fin  Se calcula calculo_ieps_orig y IEPS_ORIGINAL' ); commit;
            -- Si no existiera el mapeo del IEPS se pasa el del azucarado anterior
            logprc(10, v_period_or_date_str, '10 ini Si no existiera el mapeo del IEPS se pasa el del azucarado anterior' );
            
            update XXWEBC.REPORTE_CART_VENC_IEPS_2026 B
                set IEPS_AZUCAR_2026 = IEPS_ORIGINAL
            WHERE 1=1
            --AND CUSTOMER_TRX_ID = 123544746
            AND TIPO_DATO ='SKU'
            AND EXISTE ='NO'
            AND COLUMNA='N';

            commit;
            logprc(10, v_period_or_date_str, '10 fin Si no existiera el mapeo del IEPS se pasa el del azucarado anterior' );
            
        END IF;
    EXCEPTION
        WHEN exit_raise THEN
            LOGPRC(3, v_period_or_date_str, 'SALIENDO DEL PROCESO EXECUTE_PORTFOLIO_RECEIVABLE');
        WHEN OTHERS THEN
            LOGPRC(3, v_period_or_date_str, 'ERROR EN PROCESO EXECUTE_PORTFOLIO_RECEIVABLE: '||SQLERRM);
    END EXECUTE_PORTFOLIO_RECEIVABLE;

    PROCEDURE EXECUTE_COLLECTED_RECEIPTS(p_period_name IN VARCHAR2)
    IS
        
        exit_raise EXCEPTION;
        v_return NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
        
        LOGPRC(4, p_period_name, 'INICIA PROCESO EXECUTE_COLLECTED_RECEIPTS');
        LOGPRC(4, p_period_name, 'INICIA PROCESO EXECUTE_COLLECTED_RECEIPTS p_period_name='||p_period_name);
        v_return := 0;

        DECLARE
            P_ORG_ID       NUMBER := 84;
            P_PERIODO      VARCHAR2 (10) := p_period_name;
            LV_SEGMENT1    VARCHAR2 (10);
            LV_RFCEMISOR   VARCHAR2 (20);
            LN_ORG_ID      NUMBER;
            LV_FECHA_INI   VARCHAR2 (50);
            LV_FECHA_FIN   VARCHAR2 (50);
            v_count NUMBER;
        BEGIN

            SELECT SEGMENT1, RFC, ORG_ID
            INTO LV_SEGMENT1, LV_RFCEMISOR, LN_ORG_ID
            FROM apps.XXCUST_GL_LEGAL_ENTITIES
            WHERE ORG_ID = P_ORG_ID;
            LOGPRC(4, p_period_name, '4.0 Empíeza el proceso de recibos XXGEPP_RECIBOS_AR_X_PERIODO' );
            logprc(4, p_period_name, '4.1 Datos de la organización: '||LV_SEGMENT1 || ' - ' || LV_RFCEMISOR || ' - ' || LN_ORG_ID);
            
            logprc(4, p_period_name, '4.2 Se eliminan los datos previos DELETE XXGEPP_RECIBOS_AR_X_PERIODO' );
            DELETE FROM XXWEBC.XXGEPP_RECIBOS_AR_X_PERIODO
            WHERE 1 = 1;

            logprc(4, p_period_name, '4.3 Se eliminan los datos previos  DELETE XXFIS_RECIBOS_FACTURAS_AR' );
            DELETE FROM XXWEBC.XXFIS_RECIBOS_FACTURAS_AR
            WHERE 1 = 1 AND ORG_ID = P_ORG_ID AND PERIODO = P_PERIODO;

            COMMIT;
            logprc(4, p_period_name, '4.4 Se terminan de eliminar los datos previos' );

            -- Se valida que ya existan datos en cust_ar_sla2_polizas
            logprc(4, p_period_name, '4.4.1 Se valida que ya existan datos en cust_ar_sla2_polizas' );

            SELECT COUNT(*)
            INTO v_count
            FROM apps.cust_ar_sla2_polizas
            WHERE periodo = p_period_name
            and rownum=1;

            if v_count = 0 then
                logprc(4, p_period_name, '4.4.2 No existen datos en cust_ar_sla2_polizas para el periodo: '||p_period_name);
                logprc(4, p_period_name, '4.4.2 Se termina el proceso EXECUTE_COLLECTED_RECEIPTS');
                raise exit_raise;
            else
                logprc(4, p_period_name, '4.4.3 Si existen datos en cust_ar_sla2_polizas para el periodo: '||p_period_name);
            end if;


            logprc(4, p_period_name, '4.5 Se insertan los recibos del periodo en XXGEPP_RECIBOS_AR_X_PERIODO' );

            INSERT INTO XXWEBC.XXGEPP_RECIBOS_AR_X_PERIODO
                SELECT /*+INDEX (A CUST_AR_SLA2_POLIZAS_IDX10)*/
                    DISTINCT LN_ORG_ID                ORG_ID,
                                A.SEGMENT1,
                                A.CATEGORIA,
                                A.PERIODO,
                                A.MONEDA,
                                A.CUSTOMER_TRX_ID        CASH_RECEIPT_ID,
                                A.NUMERO_TRANSACCION     NUMERO_RECIBO
                FROM APPS.CUST_AR_SLA2_POLIZAS A
                WHERE     1 = 1
                    AND CATEGORIA = 'Recibos'
                    AND PERIODO = P_PERIODO
                    AND RFCEMISOR = LV_RFCEMISOR
                    AND SEGMENT1 = LV_SEGMENT1;

            COMMIT;

            SELECT TO_CHAR(START_DATE,'DD-MM-YYYY HH24:MI:SS'), TO_CHAR(END_DATE,'DD-MM-YYYY') || ' 23:59:59'
            INTO LV_FECHA_INI, LV_FECHA_FIN
            FROM APPS.GL_PERIODS
            WHERE PERIOD_NAME = P_PERIODO;

           LOGPRC(4, p_period_name, '4.6 Fechas del periodo: '||LV_FECHA_INI || ' - ' || LV_FECHA_FIN );

           LOGPRC(4, p_period_name, '4.7 Se insertan los datos en XXFIS_RECIBOS_FACTURAS_AR' );

            INSERT INTO XXWEBC.XXFIS_RECIBOS_FACTURAS_AR (NUMERO_CLIENTE,
                                                        RFC,
                                                        NOMBRE_CLIENTE,
                                                        SEGMENT1,
                                                        ORG_ID,
                                                        DIVISA,
                                                        FECHA_FACTURA,
                                                        CATEGORIA,
                                                        PERIODO,
                                                        CASH_RECEIPT_ID,
                                                        RECEIPT_NUMBER,
                                                        APPLIED_CUSTOMER_TRX_ID,
                                                        RECEIPT_DATE,
                                                        APPL_GL_DATE,
                                                        APPLY_DATE,
                                                        APPL_GL_POSTED_DATE,
                                                        APPL_TRX_NUMBER,
                                                        MONTO_FACTURA,
                                                        MONTO_APLICADO)
                SELECT HCA.ACCOUNT_NUMBER        NUMERO_CLIENTE,
                    HP.TAX_REFERENCE          RFC,
                    HP.PARTY_NAME             NOMBRE_CLIENTE,
                    LV_SEGMENT1               SEGMENT1,
                    C.ORG_ID                  ORG_ID,
                    A.MONEDA,
                    C.TRX_DATE                FECHA_FACTURA,
                    A.CATEGORIA,
                    P_PERIODO,
                    A.CASH_RECEIPT_ID,
                    A.NUMERO_RECIBO,
                    B.APPLIED_CUSTOMER_TRX_ID,
                    B.CREATION_DATE           RECEIPT_DATE,
                    B.GL_DATE                 APPL_GL_DATE,
                    B.APPLY_DATE,
                    B.GL_POSTED_DATE          APPL_GL_POSTED_DATE,
                    C.TRX_NUMBER              APPL_TRX_NUMBER,
                    D.AMOUNT_DUE_ORIGINAL     MONTO_FACTURA,
                    B.AMOUNT_APPLIED          MONTO_APLICADO
                    --traer tipo de cambio
                FROM XXGEPP_RECIBOS_AR_X_PERIODO        A,
                    AR.AR_RECEIVABLE_APPLICATIONS_ALL  B,
                    AR.RA_CUSTOMER_TRX_ALL             C,
                    AR.AR_PAYMENT_SCHEDULES_ALL        D,
                    APPS.HZ_CUST_ACCOUNTS              HCA,
                    APPS.HZ_PARTIES                    HP
                WHERE     B.CASH_RECEIPT_ID = A.CASH_RECEIPT_ID
                    AND B.GL_DATE BETWEEN TO_DATE (LV_FECHA_INI,
                                                    'DD-MM-RR HH24:MI:SS')
                                        AND TO_DATE (LV_FECHA_FIN,
                                                    'DD-MM-RR HH24:MI:SS')
                    AND B.STATUS = 'APP'
                    --AND B.DISPLAY = 'Y'
                    AND B.APPLIED_CUSTOMER_TRX_ID = C.CUSTOMER_TRX_ID
                    AND C.CUSTOMER_TRX_ID = D.CUSTOMER_TRX_ID
                    AND C.BILL_TO_CUSTOMER_ID = HCA.CUST_ACCOUNT_ID
                    AND HCA.PARTY_ID = HP.PARTY_ID
                    AND B.AMOUNT_APPLIED <> 0;

            COMMIT;

            DELETE FROM
                XXFIS_RECIBOS_FACTURAS_AR
                WHERE (CASH_RECEIPT_ID, APPLIED_CUSTOMER_TRX_ID, 0) IN
                            (SELECT *
                            FROM (  SELECT CASH_RECEIPT_ID,
                                            APPLIED_CUSTOMER_TRX_ID,
                                            SUM (MONTO_APLICADO)     MONTO_APLICADO
                                        FROM XXFIS_RECIBOS_FACTURAS_AR
                                        WHERE 1 = 1 AND PERIODO = P_PERIODO
                                            AND ORG_ID = P_ORG_ID
                                    GROUP BY CASH_RECEIPT_ID,
                                            APPLIED_CUSTOMER_TRX_ID)
                            WHERE MONTO_APLICADO = 0);
                            
            UPDATE XXFIS_RECIBOS_FACTURAS_AR
                SET FACTOR = ABS((100 / MONTO_FACTURA) * MONTO_APLICADO)
                WHERE 1 = 1
                    AND PERIODO = P_PERIODO
                    AND ORG_ID = P_ORG_ID;
            COMMIT;
            
            UPDATE XXWEBC.XXFIS_RECIBOS_FACTURAS_AR XRCA
            SET XRCA.LIN_IVA16 =
                    (
                    --SE SUMA LOS IMPUESTOS (IVA) EXCLUYENDO EXPLICITAMENTE LAS LINEAS DE IEPS
                        SELECT SUM(EXTENDED_AMOUNT) FROM(
                            SELECT L.EXTENDED_AMOUNT, A.TAX_CLASSIFICATION_CODE
                                FROM AR.RA_CUSTOMER_TRX_LINES_ALL L, AR.RA_CUSTOMER_TRX_LINES_ALL a
                                            WHERE 1 = 1
                                            and a.customer_Trx_line_id = l.LINK_TO_CUST_TRX_LINE_ID
                                                AND L.CUSTOMER_TRX_ID = XRCA.APPLIED_CUSTOMER_TRX_ID
                                                AND L.LINE_TYPE = 'TAX'
                                                AND l.TAX_RATE IN (8, 16, 15,10))
                            WHERE TAX_CLASSIFICATION_CODE NOT IN ('IEPS 8% INC 0%')
                    ),
                XRCA.LIN_IEPS_1XL =
                    (
                    SELECT SUM(L.EXTENDED_AMOUNT)
                        FROM AR.RA_CUSTOMER_TRX_LINES_ALL L
                        WHERE 1 = 1
                            AND L.CUSTOMER_TRX_ID = XRCA.APPLIED_CUSTOMER_TRX_ID
                            AND L.DESCRIPTION LIKE 'IEPS_LT.%'
                    ),
                XRCA.LIN_IEPS_EDULC = (
                    SELECT SUM(L.EXTENDED_AMOUNT)
                        FROM AR.RA_CUSTOMER_TRX_LINES_ALL L
                        WHERE 1 = 1
                            AND L.CUSTOMER_TRX_ID = XRCA.APPLIED_CUSTOMER_TRX_ID
                            AND L.DESCRIPTION LIKE 'IEPS_LT_ED.%'),
                XRCA.LIN_IEPS25 =
                    (SELECT SUM (AMOUNT)
                        FROM ar.RA_CUST_TRX_LINE_GL_DIST_ALL  gl,
                            gl.gl_code_combinations          gcc
                        WHERE     1 = 1
                            AND gcc.CODE_COMBINATION_ID = gl.CODE_COMBINATION_ID
                            AND gcc.segment5 = '2308'
                            AND gcc.segment6 = '4381'
                            AND gl.customer_trx_id = XRCA.APPLIED_CUSTOMER_TRX_ID),
                XRCA.LIN_IEPS8 =
                    (SELECT SUM (AMOUNT)
                        FROM ar.RA_CUST_TRX_LINE_GL_DIST_ALL  gl,
                            gl.gl_code_combinations          gcc
                        WHERE     1 = 1
                            AND gcc.CODE_COMBINATION_ID = gl.CODE_COMBINATION_ID
                            AND gcc.segment5 IN ('2308', '1303')
                            AND gcc.segment6 IN ('4385', '4360')
                            AND gl.customer_trx_id = XRCA.APPLIED_CUSTOMER_TRX_ID),
                XRCA.IVA_RETENIDO =
                    (SELECT SUM (AMOUNT)     IVA
                        FROM ar.RA_CUST_TRX_LINE_GL_DIST_ALL  gl,
                            gl.gl_code_combinations          gcc
                        WHERE     1 = 1
                            AND gcc.CODE_COMBINATION_ID = gl.CODE_COMBINATION_ID
                            AND gcc.segment5 = '1301'
                            AND gcc.segment6 IN ('4122', '4127')
                            AND gl.customer_trx_id = XRCA.APPLIED_CUSTOMER_TRX_ID)
                , LIN_IVA16_CC = (SELECT SUM (AMOUNT)
                        FROM ar.RA_CUST_TRX_LINE_GL_DIST_ALL  gl,
                            gl.gl_code_combinations          gcc
                        WHERE     1 = 1
                            AND gcc.CODE_COMBINATION_ID = gl.CODE_COMBINATION_ID
                            AND gcc.segment5 = '2306'
                            AND gcc.segment6 IN ('4165', '4167','4172', '4174')
                            and gcc.segment7 = '000'
                            AND gl.CUSTOMER_TRX_ID = XRCA.APPLIED_CUSTOMER_TRX_ID) 
                , LIN_IVA8_CC = (SELECT SUM (AMOUNT)
                        FROM ar.RA_CUST_TRX_LINE_GL_DIST_ALL  gl,
                            gl.gl_code_combinations          gcc
                        WHERE     1 = 1
                            AND gcc.CODE_COMBINATION_ID = gl.CODE_COMBINATION_ID
                            AND gcc.segment5 IN ('2306')
                            AND gcc.segment6 IN ('4182', '4184')
                            AND gl.CUSTOMER_TRX_ID = XRCA.APPLIED_CUSTOMER_TRX_ID)                       
            WHERE 1 = 1 AND XRCA.PERIODO = P_PERIODO AND XRCA.ORG_ID = P_ORG_ID;

            UPDATE XXWEBC.XXFIS_RECIBOS_FACTURAS_AR XRCA
            SET XRCA.LIN_IVA8 = XRCA.LIN_IVA16,
                XRCA.LIN_IVA16 = null
            where 1=1
                and periodo = P_PERIODO 
                AND XRCA.ORG_ID = P_ORG_ID
                and NUMERO_CLIENTE  between 88000 and 88999;
            
            update XXFIS_RECIBOS_FACTURAS_AR XRCA
            set LIN_IVA16 = (nvl(LIN_IVA16,0) * FACTOR) / 100, 
                        LIN_IEPS25 = (nvl(LIN_IEPS25,0) * FACTOR) / 100, 
                        LIN_IEPS8 = (nvl(LIN_IEPS8 ,0) * FACTOR) / 100, 
                        LIN_IEPS_1XL = (nvl(LIN_IEPS_1XL ,0) * FACTOR) / 100, 
                        LIN_IEPS_EDULC = (nvl(LIN_IEPS_EDULC ,0) * FACTOR) / 100, 
                        IVA_RETENIDO = (nvl(IVA_RETENIDO ,0) * FACTOR) / 100, 
                        LIN_IVA8 = (nvl(LIN_IVA8 ,0) * FACTOR) / 100, 
                        LIN_IVA16_CC = (nvl(LIN_IVA16_CC ,0) * FACTOR) / 100, 
                        LIN_IVA8_CC = (nvl(LIN_IVA8_CC ,0) * FACTOR) / 100
                    where 1=1
                and periodo = P_PERIODO 
                AND XRCA.ORG_ID = P_ORG_ID;
            COMMIT;    
            
                update XXFIS_RECIBOS_FACTURAS_AR XRCA
                set LIN_IVA16 = (nvl(LIN_IVA16,0) * -1), 
                    LIN_IEPS25 = (nvl(LIN_IEPS25,0) * -1), 
                    LIN_IEPS8 = (nvl(LIN_IEPS8 ,0) * -1), 
                    LIN_IEPS_1XL = (nvl(LIN_IEPS_1XL ,0)* -1), 
                    LIN_IEPS_EDULC = (nvl(LIN_IEPS_EDULC ,0)* -1), 
                    LIN_IVA8 = (nvl(LIN_IVA8 ,0) * -1), 
                    LIN_IVA16_CC = (nvl(LIN_IVA16_CC ,0) * -1), 
                    LIN_IVA8_CC = (nvl(LIN_IVA8_CC ,0) * -1)
                where 1=1    
                    and periodo = P_PERIODO 
                    AND XRCA.ORG_ID = P_ORG_ID
                    and monto_aplicado < 0;
            
                UPDATE XXFIS_RECIBOS_FACTURAS_AR XRCA
                SET IVA_RETENIDO = IVA_RETENIDO * (-1)
                WHERE 1=1
                    AND IVA_RETENIDO < 0
                    and periodo = P_PERIODO 
                    AND XRCA.ORG_ID = P_ORG_ID;
            
            COMMIT;
            
            update XXFIS_RECIBOS_FACTURAS_AR XRCA
            set
            IMP_TOTAL_IMPUEST = nvl(LIN_IVA0,0) + nvl(LIN_IVA8,0) + nvl(LIN_IVA16,0) + nvl(LIN_IEPS25,0) +  nvl(LIN_IEPS8,0) + nvl(LIN_IEPS_1XL,0)+ nvl(LIN_IEPS_EDULC,0), 
            IMP_TOT_IMPUEST_CC = nvl(LIN_IVA0,0) + nvl(LIN_IVA8_CC,0) + nvl(LIN_IVA16_CC,0) + nvl(LIN_IEPS25,0) +  nvl(LIN_IEPS8,0) + nvl(LIN_IEPS_1XL,0)+ nvl(LIN_IEPS_EDULC,0)
            where
            1=1    
                and periodo = P_PERIODO 
                AND XRCA.ORG_ID = P_ORG_ID;
            
            update XXFIS_RECIBOS_FACTURAS_AR XRCA
            set IMP_TOTAL_LINEAS = nvl(MONTO_APLICADO,0) - nvl(IMP_TOTAL_IMPUEST,0) + nvl(IVA_RETENIDO,0)
                where
            1=1    
                and periodo = P_PERIODO 
                AND XRCA.ORG_ID = P_ORG_ID;
            
            COMMIT;
            
            update XXWEBC.XXFIS_RECIBOS_FACTURAS_AR XRCA set
                DIF_IVA16_CC = ABS(NVL(LIN_IVA16,0) - NVL(LIN_IVA16_CC,0)), 
                DIF_IVA8_CC = ABS(NVL(LIN_IVA8,0) - NVL(LIN_IVA8_CC,0))
            where 1=1 and periodo = P_PERIODO 
                AND XRCA.ORG_ID = P_ORG_ID;


            COMMIT;

            logprc(4, p_period_name, '4.8 Se eliminan los datos en XXFIS_IEPS_COBR_X_PERIODO' );
            delete XXFIS_IEPS_COBR_X_PERIODO
            where 1=1
            and periodo = p_period_name
            and org_id = 84;
            commit;

            logprc(4, p_period_name, '4.9 Se insertan los datos en XXFIS_IEPS_COBR_X_PERIODO' );            

            insert into XXFIS_IEPS_COBR_X_PERIODO (NUMERO_CLIENTE, RFC, NOMBRE_CLIENTE, SEGMENT1, ORG_ID, DIVISA, FECHA_FACTURA, CATEGORIA, PERIODO, CASH_RECEIPT_ID, RECEIPT_NUMBER, APPLIED_CUSTOMER_TRX_ID, RECEIPT_DATE, APPL_GL_DATE, APPLY_DATE, APPL_GL_POSTED_DATE, APPL_TRX_NUMBER, MONTO_FACTURA, MONTO_APLICADO, IMP_TOTAL_LINEAS, IMP_TOTAL_IMPUEST, LIN_IEPS_1XL, LIN_IEPS_EDULC, FACTOR)
            select /*+index (f XXFIS_RECIBOS_FACT_AR_IDX2)*/
                NUMERO_CLIENTE, RFC, NOMBRE_CLIENTE, SEGMENT1, ORG_ID, DIVISA, FECHA_FACTURA, CATEGORIA, PERIODO, CASH_RECEIPT_ID, RECEIPT_NUMBER, APPLIED_CUSTOMER_TRX_ID, RECEIPT_DATE, APPL_GL_DATE, APPLY_DATE, APPL_GL_POSTED_DATE, APPL_TRX_NUMBER, MONTO_FACTURA, MONTO_APLICADO, IMP_TOTAL_LINEAS, IMP_TOTAL_IMPUEST, LIN_IEPS_1XL, LIN_IEPS_EDULC, FACTOR 
            from XXWEBC.XXFIS_RECIBOS_FACTURAS_AR f
            where periodo = p_period_name
            and org_id = 84;

            commit;

            LOGPRC(4, p_period_name, '4.20 Se borran los datos en XXAR_REPORTE_COBRADO_X_PERIODO del periodo ' || p_period_name );
            DELETE XXAR_REPORTE_COBRADO_X_PERIODO 
            WHERE 1=1
            AND PERIODO_PROCESO = p_period_name;
    	
    	    COMMIT;
    	
    	    logprc(4, p_period_name, '4.21 Se insertan los datos en XXAR_REPORTE_COBRADO_X_PERIODO del periodo ' || p_period_name );
            DECLARE
                v_limit   PLS_INTEGER := 500;
                CURSOR cur_d IS
                    SELECT
                        ROWNUM                     consecutivo,
                        g.PERIODO PERIODO_PROCESO,
                        G.ORG_ID,
                        - 666                      fila,
                        trxl.customer_trx_line_id,
                        trx1.customer_trx_id,
                        cte.tax_reference          rfc_cliente,
                        cte.customer_name          nombre_cliente,
                        cte.customer_number        no_cliente,
                        cte.attribute20            pais_cliente,
                        trx1.trx_number            AS no_factura,
                        tt.name                    AS tipo_transaccion,
                        trx1.trx_date              AS fecha_factura,
                        trx1.invoice_currency_code divisa,
                        nvl(
                            trx1.exchange_rate, 1
                        )                          tipo_cambio,
                        tt.type                    AS tipo,
                        CASE
                        WHEN trxl.line_type != 'TAX' THEN
                        trxl.line_number
                        ELSE
                        (
                            SELECT
                                trxl2.line_number
                            FROM
                                apps.ra_customer_trx_lines_all trxl2
                            WHERE
                                1 = 1
                                AND trxl2.line_type != 'TAX'
                                AND trxl2.customer_trx_line_id = trxl.link_to_cust_trx_line_id
                        )
                        END                        line_number,
                        trxl.inventory_item_id,
                        i.segment1                 articulo,
                        trxl.description,
                        trxl.line_type,
                        trxl.uom_code              udm,
                        CASE
                        WHEN trxl.line_type != 'TAX' THEN
                        trxl.tax_classification_code
                        ELSE
                        (
                            SELECT
                                trxl2.tax_classification_code
                            FROM
                                apps.ra_customer_trx_lines_all trxl2
                            WHERE
                                1 = 1
                                AND trxl2.customer_trx_line_id = trxl.link_to_cust_trx_line_id
                        )
                        END                        tax_code,
                        trxl.line_recoverable,
                        trxl.tax_recoverable,
                        nvl(
                            trxl.quantity_invoiced, trxl.quantity_credited
                        )                          cantidad,
                        trxl.unit_selling_price    precio_unitario,
                        trxl.extended_amount       importe_linea,
                        d1.account_class,
                        d1.amount,
                        g.monto_factura,
                        null ,
                        NULL                       status,
                        gcc.code_combination_id,
                        gcc.segment1,
                        gcc.segment2,
                        gcc.segment3,
                        gcc.segment4,
                        gcc.segment5,
                        gcc.segment6,
                        gcc.segment7,
                        case when trxl.line_type is null then 'CXC'
                                when line_type = 'LINE' and substr(trxl.description,1,4) = 'IEPS' THEN 'IEPS'
                                when line_type = 'TAX' then 'IVA'
                                WHEN tt.TYPE= 'CM' AND d1.amount>0 THEN 'DESC'
                                WHEN tt.TYPE= 'INV' AND d1.amount< 0 THEN 'DESC'
                                else 'SKU'
                        END  tipo_dato,
                        decode(
                            nvl(
                                (
                                    SELECT e.ieps_litro
                                    FROM apps.XXAR_IEPS e
                                    WHERE e.org_id = trx1.org_id
                                    AND e.segment1 = i.segment1
                                ), 0
                            ), 0, 'NO', 'SI'
                        )                          existe,
                        ( TO_NUMBER(nvl(
                            nvl(
                                trxl.attribute2, nvl(
                                    trxl.quantity_invoiced, trxl.quantity_credited
                                )
                            ), '0'
                        )) )                       cantidad_usar,
                        nvl(
                            (
                                SELECT
                                    e.ieps_litro
                                FROM
                                    apps.XXAR_IEPS e
                                WHERE
                                    e.org_id = trx1.org_id
                                    AND e.segment1 = i.segment1
                            ), 0
                        )                          factor_ieps_azucar_2026,
                        CASE
                        WHEN d1.amount > 0 THEN
                            CASE
                            WHEN trxl.line_type IS NULL THEN
                            0
                            WHEN line_type = 'LINE'
                                AND substr(
                                trxl.description, 1, 4
                            ) = 'IEPS' THEN
                            0
                            WHEN line_type = 'TAX' THEN
                            0
                            ELSE
                            CASE
                            WHEN nvl(
                                    (
                                        SELECT
                                            e.ieps_litro
                                        FROM
                                            apps.XXAR_IEPS e
                                        WHERE
                                            e.org_id = trx1.org_id
                                            AND e.segment1 = i.segment1
                                    ), 0
                                ) <= 0 THEN
                                777
                            ELSE
                            ( TO_NUMBER(nvl(
                                    nvl(
                                        trxl.attribute2, nvl(
                                            trxl.quantity_invoiced, trxl.quantity_credited
                                        )
                                    ), '0'
                                )) * (
                                    SELECT
                                        e.ieps_litro
                                    FROM
                                        apps.XXAR_IEPS e
                                    WHERE
                                        e.org_id = trx1.org_id
                                        AND e.segment1 = i.segment1
                                ) )
                            END
                            END
                        ELSE
                        0
                        END                        ieps_azucar_2026,
                        nvl(
                            (
                                SELECT
                                    e.ieps_litro_ed
                                FROM
                                    apps.XXAR_IEPS e
                                WHERE
                                    e.org_id = trx1.org_id
                                    AND e.segment1 = i.segment1
                            ), 0
                        )                          factor_ieps_edul_2026,
                        CASE
                        WHEN d1.amount > 0 THEN
                            CASE
                            WHEN trxl.line_type IS NULL THEN
                            0
                            WHEN line_type = 'LINE'
                                AND substr(
                                trxl.description, 1, 4
                            ) = 'IEPS' THEN
                            0
                            WHEN line_type = 'TAX' THEN
                            0
                            ELSE
                            ( TO_NUMBER(nvl(
                                nvl(
                                    trxl.attribute2, nvl(
                                        trxl.quantity_invoiced, trxl.quantity_credited
                                    )
                                ), '0'
                            )) * nvl(
                                (
                                    SELECT
                                        e.ieps_litro_ed
                                    FROM
                                        apps.XXAR_IEPS e
                                    WHERE
                                        e.org_id = trx1.org_id
                                        AND e.segment1 = i.segment1
                                ), 0
                            ) )
                            END
                        ELSE
                        0
                        END                        ieps_edul_2026,
                        'N'                        columna,
                                        --''''||TO_CHAR(d1.gl_date,'DD-MM-YYYY') AS FECHA_CONTABLE,
                                        --''''||to_char (d1.gl_DATE,'MON-YY') AS PERIODO ,
                        to_char(
                            d1.gl_date, 'DD-MM-YYYY'
                        )                          AS fecha_contable,
                        to_char(
                            d1.gl_date, 'MON-YY'
                        )                          AS periodo,
                        trxl.attribute2            cantidad_sio,
                        trxl.attribute3            precio_sio,
                        trxl.attribute6            imp_linea_sio,
                        NULL                       ieps_original,
                        NULL                       tasa_impuesto,
                        NULL                       factor_ieps_orig,
                        NULL                       calculo_ieps_orig,
                        SYSDATE                    fecha_actualizacion_ti,
                        NULL                       fecha_cubo,
                        NULL                       cash_receipt_id_gl,
                        g.APPL_GL_DATE             appl_gl_date,
                        g.APPL_GL_POSTED_DATE      appl_gl_posted_date,
                        g.MONTO_FACTURA            monto_factura_gl,
                        g.MONTO_APLICADO           monto_aplicado_gl,
                        g.IMP_TOTAL_LINEAS         imp_total_lineas_gl,
                        g.IMP_TOTAL_IMPUEST        imp_total_impuest_gl,
                        g.LIN_IEPS_1XL             lin_ieps_1xl_gl,
                        g.factor                   factor_gl
                    FROM
                        apps.ra_customer_trx_all          trx1,
                        apps.ar_payment_schedules_all     p1,
                        apps.ra_cust_trx_line_gl_dist_all d1,
                        apps.gl_code_combinations         gl1,
                        apps.hr_all_organization_units    hro,
                        apps.ra_customer_trx_lines_all    trxl,
                        apps.mtl_system_items_b           i,
                        apps.ra_cust_trx_types_all        tt,
                        apps.ra_customers                 cte,
                        apps.gl_code_combinations         gcc,
                        xxwebc.XXFIS_IEPS_COBR_X_PERIODO  g
                    WHERE 1=1    
                        and g.periodo = p_period_name                
                        AND trx1.customer_trx_id = g.applied_customer_trx_id
                        AND trx1.org_id = p1.org_id (+)
                        AND trx1.customer_trx_id = p1.customer_trx_id (+)
                        AND trx1.org_id = tt.org_id
                        AND trx1.cust_trx_type_id = tt.cust_trx_type_id
                        AND d1.org_id = trx1.org_id
                        AND d1.customer_trx_id = trx1.customer_trx_id
                        AND gl1.code_combination_id = d1.code_combination_id
                        AND hro.organization_id = trx1.org_id
                        AND d1.org_id = trxl.org_id (+)
                        AND d1.customer_trx_id = trxl.customer_trx_id (+)
                        AND d1.customer_trx_line_id = trxl.customer_trx_line_id (+)
                        AND i.organization_id (+) = 91
                        AND i.inventory_item_id (+) = trxl.inventory_item_id
                        AND cte.customer_id = trx1.bill_to_customer_id
                        AND gcc.code_combination_id = d1.code_combination_id
                        
                                --and d1.amount               > 0                        -- descartar descuentos
                    ORDER BY
                        trx1.trx_number,
                        line_number,
                        trxl.inventory_item_id;
                    
            TYPE cur_d_tb IS
                TABLE OF cur_d%rowtype INDEX BY PLS_INTEGER;
            cur_d_arr cur_d_tb;
        BEGIN
                logprc(4, p_period_name, '4.21.1 Se inicia proceso de inserción masiva a XXAR_REPORTE_COBRADO_X_PERIODO' );                
                
                OPEN cur_d;
                LOOP
                    FETCH cur_d
                    BULK COLLECT INTO cur_d_arr LIMIT v_limit;
                    FORALL i IN 1..cur_d_arr.count
                        INSERT INTO XXAR_REPORTE_COBRADO_X_PERIODO VALUES cur_d_arr ( i );
        
                    COMMIT;
                    EXIT WHEN cur_d%notfound;
                END LOOP;
        
                CLOSE cur_d;
                COMMIT;
                logprc(4, p_period_name, '4.21.2 Se finaliza proceso de inserción masiva a XXAR_REPORTE_COBRADO_X_PERIODO' );                
        END; -- terminainsert
			
    	
            UPDATE XXWEBC.XXAR_REPORTE_COBRADO_X_PERIODO B
            SET EXISTE ='NA'
                ,FACTOR_IEPS_AZUCAR_2026=0
                , IEPS_AZUCAR_2026=0  
                ,FACTOR_IEPS_EDUL_2026=0  
                ,IEPS_EDUL_2026=0        
            WHERE 1=1
            AND PERIODO_PROCESO = p_period_name
            AND TIPO_DATO ='DESC';
        
            commit;
            logprc(4, p_period_name, '4.22.1 Se actualizan facturas en XXAR_REPORTE_COBRADO_X_PERIODO' );
            UPDATE XXWEBC.XXAR_REPORTE_COBRADO_X_PERIODO B
            SET IEPS_AZUCAR_2026 = ( (SELECT IEPS_LITRO
                                        FROM apps.XXAR_IEPS E
                                        WHERE 1=1 AND ORG_ID=b.org_id AND SEGMENT1= B.ARTICULO )* CANTIDAD_USAR)
                ,IEPS_EDUL_2026 = ( (SELECT IEPS_LITRO_ED
                                        FROM apps.XXAR_IEPS E
                                        WHERE 1=1 AND ORG_ID=b.org_id AND SEGMENT1= B.ARTICULO )* CANTIDAD_USAR)
                ,FACTOR_IEPS_AZUCAR_2026=(SELECT IEPS_LITRO
                                            FROM apps.XXAR_IEPS E
                                            WHERE 1=1 AND ORG_ID=b.org_id AND SEGMENT1= B.ARTICULO )
                ,FACTOR_IEPS_EDUL_2026=(SELECT IEPS_LITRO_ED
                                        FROM apps.XXAR_IEPS E
                                        WHERE 1=1 AND ORG_ID=b.org_id AND SEGMENT1= B.ARTICULO )
            where 1=1
            AND PERIODO_PROCESO = p_period_name
            AND TIPO_DATO ='SKU'
            AND EXISTE ='SI'
            and columna = 'N';

            commit;
            logprc(4, p_period_name, '4.22.2 Se actualizan factores en XXAR_REPORTE_COBRADO_X_PERIODO' );

 
            logprc(4, p_period_name, '4.23 Se inicia proceso de calculo de IEPS original' );

            -- Se calcula factor_ieps_orig
            UPDATE  XXAR_REPORTE_COBRADO_X_PERIODO
                SET factor_ieps_orig =xxwebc.xxar_obtener_ieps_anho(org_id, TO_CHAR(FECHA_FACTURA,'MM'), TO_CHAR(FECHA_FACTURA,'YYYY'), ARTICULO)                    
                    ,tasa_impuesto = case when tax_code IN ('IEPS INC 25% INC 16%','IVA 16%','INC 16%') THEN 16
                                          WHEN TAX_CODE IN ('IEPS 8% INC 0%','IVA 0%','INC 0%') then 0
                                          when TAX_CODE IN ('INC 8%','IVA 8%') then 8
                                          else
                                            -666
                                          end

            where 1=1
            AND PERIODO_PROCESO = p_period_name
            AND TIPO_DATO ='SKU'
            and columna = 'N';

            COMMIT;

            logprc(4, p_period_name, '4.23.1 Se calcula factor_ieps_orig' );

            logprc(4, p_period_name, '4.23.2 Se calcula calculo_ieps_orig y IEPS_ORIGINAL' );

            -- Se calcula calculo_ieps_orig y IEPS_ORIGINAL
            UPDATE  XXAR_REPORTE_COBRADO_X_PERIODO
                SET calculo_ieps_orig = round(factor_ieps_orig * CANTIDAD_USAR,2)
                    ,IEPS_ORIGINAL = round(factor_ieps_orig * CANTIDAD_USAR,2)
            where 1=1
            AND PERIODO_PROCESO = p_period_name
            AND TIPO_DATO ='SKU'
            and columna = 'N';

            COMMIT;

            logprc(4, p_period_name, '4.23.4 Se pasa el IEPS del azucarado anterior' );
            update XXWEBC.XXAR_REPORTE_COBRADO_X_PERIODO B
                set IEPS_AZUCAR_2026 = IEPS_ORIGINAL
            WHERE 1=1
            AND PERIODO_PROCESO = p_period_name
            --AND CUSTOMER_TRX_ID = 123544746
            AND TIPO_DATO ='SKU'
            AND EXISTE ='NO'
            AND COLUMNA='N';

            commit;


            LOGPRC(4, p_period_name, '4.10 Termina el proceso de recibos XXGEPP_RECIBOS_AR_X_PERIODO' );

        EXCEPTION
            WHEN OTHERS
            THEN
                LOGPRC(4, p_period_name, '4.11 ERROR EN PROCESO EN SUBPROCESO EXECUTE_COLLECTED_RECEIPTS: '||SQLERRM);
                v_return := 1;
                RAISE exit_raise;
        END;

        LOGPRC(4, p_period_name, '4.12 Inicia el proceso de recibos XXGEPP_RECIBOS_AR_X_PERIODO' );
        logprc(4, p_period_name, '4.12.1 Se insertan los datos en XXGEPP_RECIBOS_X_PERIODO' );
        insert into XXGEPP_RECIBOS_X_PERIODO (PERIODO, CASH_RECEIPT_ID, NUMERO_RECIBO, FECHA_TRANSACCION, ORG_ID)
        select distinct p.periodo, p.customer_trx_id, p.numero_transaccion, p.fecha_transaccion, l.org_id
        from apps.cust_ar_sla2_polizas p
            ,xxcust_gl_legal_entities@EBSPROD_TO_CFDIPROD19 l
        where p.periodo = p_period_name
            AND p.CATEGORIA = 'Recibos'
            and p.segment1 =  l.segment1
            and p.segment1 = '209';
        commit;

        logprc(4, p_period_name, '4.13 Se actualiza el monto de los recibos en XXGEPP_RECIBOS_X_PERIODO' );

        update XXGEPP_RECIBOS_X_PERIODO b 
        set b.MONTO =  (select a.AMOUNT 
                        from ar.ar_cash_receipts_all a
                        where 1=1
                        and a.CASH_RECEIPT_ID = b.CASH_RECEIPT_ID)
        where periodo = p_period_name;

        logprc(4, p_period_name, '4.14 Se actualiza el campo APLICACION en XXGEPP_RECIBOS_X_PERIODO' );

        declare
            v_fecha_ini date;
            v_fecha_fin date;
        begin

            select start_date, end_date
            into v_fecha_ini, v_fecha_fin
            from apps.gl_periods
            where period_name = p_period_name;

            MERGE INTO XXGEPP_RECIBOS_X_PERIODO r
            USING (
                    SELECT distinct CASH_RECEIPT_ID,ORG_ID
                    FROM ar.AR_RECEIVABLE_APPLICATIONS_ALL
                    WHERE GL_DATE BETWEEN v_fecha_ini AND v_fecha_fin
                    AND STATUS = 'APP'
                ) b
            ON (b.CASH_RECEIPT_ID = r.CASH_RECEIPT_ID
                AND b.ORG_ID = r.ORG_ID
                AND r.PERIODO = p_period_name
                )
            WHEN MATCHED THEN
            UPDATE SET r.APLICACION = 'SI';

            commit;
        end;

        logprc(4, p_period_name, '4.15 Termina en XXGEPP_RECIBOS_X_PERIODO' );

    exception
        WHEN exit_raise THEN
            LOGPRC(4, p_period_name, '4.101 SALIENDO DEL PROCESO EXECUTE_COLLECTED_RECEIPTS');
            v_return := 2;
        WHEN OTHERS THEN
            LOGPRC(4, p_period_name, '4.100ERROR EN PROCESO EXECUTE_COLLECTED_RECEIPTS: '||SQLERRM);
            v_return := 3;
    END EXECUTE_COLLECTED_RECEIPTS;

    PROCEDURE SEND_MAIL(p_period_name IN VARCHAR2,p_date IN VARCHAR2)
    IS 
        v_body varchar2(4000);
        v_subject varchar2(1000);
        v_to_recipients varchar2(250);
        v_cc_recipients varchar2(250);
        v_bcc_recipients  varchar2(250);
        v_service_name varchar2(100);
        v_SENDER varchar2(100):='oracle_ebs@gepp.com';
        p_err_msg VARCHAR2(4000);
        v_existe NUMBER;
    BEGIN
        SELECT VALUE
          INTO v_service_name
          FROM v$parameter
         WHERE 1 = 1 AND NAME = 'instance_name';

        v_body :=
               '<B>XXAR - Proceso cierre de mes IEPS AR ['||p_period_name||']</B>'
            || '<br>'
            || 'Lista de Valores: XXAR_CIERRE_IEPS'
            || '<br>';
        
        -- Se valida REPORTE_CART_VENC_IEPS_2026
        v_existe := 0;
        SELECT COUNT(*)
          INTO v_existe
          FROM XXWEBC.REPORTE_CART_VENC_IEPS_2026
         WHERE 1 = 1
           AND fecha_cubo = TO_DATE(p_date, 'YYYY/MM/DD')
           and rownum=1;

        if v_existe = 0 then
            v_body := v_body || '<br><B>Reporte Cartera</B><br>' 
                             || '<B>NO</B> Se encontraron registros en <B>REPORTE_CART_VENC_IEPS_2026</B> para la fecha: ' || p_date
                             || '<br><br>';
        else
            v_body := v_body || '<br><B>Reporte Cartera</B><br>' 
                             || 'Se encontraron registros en <B>REPORTE_CART_VENC_IEPS_2026</B> para la fecha: ' || p_date                               
                             || '<br><br><B>SELECT * <br>FROM XXWEBC.REPORTE_CART_VENC_IEPS_2026;<br></B>';
        end if;

        -- Se valida XXAR_REPORTE_COBRADO_X_PERIODO
        v_existe := 0;
        SELECT COUNT(*)
          INTO v_existe
          FROM XXWEBC.XXAR_REPORTE_COBRADO_X_PERIODO
         WHERE 1 = 1
           AND PERIODO_PROCESO = p_period_name
           and rownum=1;

        if v_existe = 0 then
            v_body := v_body || '<br><br><B>Reporte de lo Cobrado</B><br>' 
                             || '<B>NO</B> Se encontraron registros en <B>XXAR_REPORTE_COBRADO_X_PERIODO</B> para el periodo: ' || p_period_name
                             || '<br><br>';
        else
            v_body := v_body || '<br><br><B>Reporte de lo Cobrado</B><br>' 
                              || 'Se encontraron registros en <B>XXAR_REPORTE_COBRADO_X_PERIODO</B> para el periodo: ' || p_period_name                               
                              || '<br><br><B>SELECT * <br>FROM XXWEBC.XXAR_REPORTE_COBRADO_X_PERIODO <br>WHERE PERIODO_PROCESO = ''' || p_period_name || ''';</B><br>';
        end if;

        -- Se valida XXGEPP_RECIBOS_X_PERIODO
        v_existe := 0;
        SELECT COUNT(*)
          INTO v_existe
          FROM XXWEBC.XXGEPP_RECIBOS_X_PERIODO 
         WHERE 1 = 1
           AND PERIODO= p_period_name
           and rownum=1;

        if v_existe = 0 then
            v_body := v_body || '<br><br><B>Recibos del mes '||p_period_name||' aplicados y no aplicados</B><br>' 
                             || '<B>NO</B> Se encontraron registros en <B>XXGEPP_RECIBOS_X_PERIODO</B> para el periodo: ' || p_period_name
                             || '<br><br>';
        else
            v_body := v_body || '<br><br><B>Recibos del mes '||p_period_name||' aplicados y no aplicados</B><br>' 
                              || 'Se encontraron registros en <B>XXGEPP_RECIBOS_X_PERIODO</B> para el periodo: ' || p_period_name 
                              || '<br><br><B>SELECT * <br>FROM XXWEBC.XXGEPP_RECIBOS_X_PERIODO <br>WHERE PERIODO = ''' || p_period_name || ''';</B><br>';
        end if;
        
        v_subject :=
               'XXAR - Proceso cierre de mes IEPS AR ['||p_period_name||'] ('
            || v_service_name
            || ')  :)';

        begin
            SELECT to_recipients, cc_recipients, bcc_recipients
            INTO v_to_recipients, v_cc_recipients, v_bcc_recipients
            FROM apps.alr_distribution_lists
            WHERE NAME = 'XXAR_CIERRE_IEPS';
        exception
            when NO_DATA_FOUND then
                l('No se encontraron destinatarios para la lista de distribución XXAR_CIERRE_IEPS');
        end;

        --v_to_recipients :='carloseduardo.davila@gepp.com';
        
        apps.cust_mail.send_email ( P_DIRECTORY     => NULL,         -- Directorio
                                    P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                                    P_RECIPIENT     =>v_to_recipients, --'alejandro.romo@gepp.com',--v_to_recipients, --;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                                    P_CC            =>v_cc_recipients, --'carloseduardo.davila@pepsico.com',    -- Con Copia para
                                    P_BCC           => v_bcc_recipients,
                                    P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                                    P_BODY          => v_body,             -- Cuerpo
                                    --P_ATTACHMENT1   => v_file_name, --Archivo a enviar
                                    P_ERROR         => p_err_msg);
                                    

    END SEND_MAIL;

    PROCEDURE CARGA_CUENTAS_CONTABLES_A_SLA2(p_period_name IN VARCHAR2)
    IS
        v_count NUMBER;
        v_raise EXCEPTION;
    BEGIN
        logprc(4, p_period_name, '4.30 Se inicia proceso de carga de cuentas contables a SLA2' );

        SELECT COUNT(*)
          INTO v_count
        FROM apps.cust_ar_sla2_polizas
        WHERE periodo = p_period_name
        and rownum=1;


        if v_count > 0 then
            logprc(4, p_period_name, '4.31 Se encontraron registros en cust_ar_sla2_polizas para el periodo: ' || p_period_name || '. Se omite la carga de cuentas contables a SLA2' );
            RAISE v_raise;
        else
            logprc(4, p_period_name, '4.32 No se encontraron registros en cust_ar_sla2_polizas para el periodo: ' || p_period_name || '. Se procede a la carga de cuentas contables a SLA2' );
        end if;

        DECLARE
            V_ERRBUF                VARCHAR2(4000);
            V_RETCODE               NUMBER;
            P_TIPO_EJECUCION   VARCHAR2(100):='CARGA';
            P_MODULO           VARCHAR2(100):='AR';
            P_EJECUCION        NUMBER:=0;
            P_PERIODO          VARCHAR2(100):=p_period_name;
            P_CORREO           VARCHAR2(100):='jaime.hernandez@gepp.com';
        BEGIN
            APPS.CUST_GL_POPULATE_SLA2_PKG.MAIN_VALIDACIONES(V_ERRBUF,
                                                             V_RETCODE,
                                                             P_TIPO_EJECUCION,
                                                             P_MODULO,
                                                             P_EJECUCION,
                                                             P_PERIODO,
                                                             P_CORREO) ;
            COMMIT;
        END;
        logprc(4, p_period_name, '4.35 Se finaliza proceso de carga de cuentas contables a SLA2' );
    EXCEPTION
        WHEN v_raise THEN
            logprc(4, p_period_name, '4.33 Raise Se omite la carga de cuentas contables a SLA2 para el periodo: ' || p_period_name || '. Ya existen registros en cust_ar_sla2_polizas' );
        WHEN OTHERS THEN
            logprc(4, p_period_name, '4.34 ERROR EN PROCESO DE CARGA DE CUENTAS CONTABLES A SLA2: '||SQLERRM);
    END CARGA_CUENTAS_CONTABLES_A_SLA2;

    PROCEDURE MAIN_PROCEDURE(errbuf out varchar2
                             ,retcode out number 
                             ,p_execute_cube IN VARCHAR2
                             ,p_execute_cube_interco IN VARCHAR2                             
                             ,p_copy_to_history_cube IN VARCHAR2
                             ,p_execute_portfolio_receivable IN VARCHAR2
                             ,p_execute_carga_cuentas_a_sla2 IN VARCHAR2
                             ,p_execute_collected_receipts IN VARCHAR2
                             ,p_period_name IN VARCHAR2
                             --,p_date_str IN VARCHAR2
                             ,p_send_mail IN VARCHAR2)
    IS
        v_date DATE;
        v_strdate VARCHAR2(10);
        l_request_id NUMBER;
        v_raise EXCEPTION;
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''LATIN AMERICAN SPANISH''';
        logprc(0, '0', '1. INICIA PROCESO DE CIERRE DE IEPS');
        l('1. INICIA PROCESO DE CIERRE DE IEPS');

        -- Obtener el request_id del concurrent program actual
        l_request_id := FND_GLOBAL.CONC_REQUEST_ID;

        -- Validar que exista
        IF l_request_id IS NULL OR l_request_id = 0 THEN
            l('No se pudo obtener el request_id.');
        ELSE
            l('El request_id es: ' || l_request_id);
        END IF;

        l('Los parametros de ejecución son:');
        l('p_execute_cube: ' || p_execute_cube);
        l('p_execute_cube_interco: ' || p_execute_cube_interco);
        l('p_copy_to_history_cube: ' || p_copy_to_history_cube);
        l('p_execute_portfolio_receivable: ' || p_execute_portfolio_receivable);
        l('p_execute_collected_receipts: ' || p_execute_collected_receipts);
        l('p_period_name: ' || p_period_name);
        --l('p_date_str: ' || p_date_str);
        l('p_send_mail: ' || p_send_mail);

        

        DECLARE
            v_count NUMBER := 0;
        BEGIN
            -- Validate if the period exists in the database
            SELECT COUNT(*) 
            INTO v_count
            FROM APPS.GL_PERIODS
            WHERE PERIOD_NAME = p_period_name;

            IF v_count = 0 THEN
                l('El periodo ' || p_period_name || ' no existe en la base de datos.');                
                RAISE v_raise;
            END IF;

            SELECT END_DATE 
            INTO v_date
            FROM APPS.GL_PERIODS
            WHERE PERIOD_NAME = p_period_name;

            v_strdate := TO_CHAR(v_date, 'YYYY-MM-DD');

        END;

        l('v_date: ' || TO_CHAR(v_date, 'YYYY-MM-DD'));
        l('v_strdate: ' || v_strdate);

        logprc(0, '0', 'v_strdate:'||v_strdate);


        if p_execute_cube IN ('SI') then
            EXECUTE_CUBE(v_strdate, p_copy_to_history_cube);
            --null; -- Se comenta la ejecución del cubo para evitar errores de ejecución
        end if;

        if p_execute_cube_interco IN ('SI') then
           EXECUTE_CUBE_INTERCO(v_strdate);
           -- null; -- Se comenta la ejecución del cubo para evitar errores de ejecución
        end if;

        if p_execute_portfolio_receivable IN ('SI') then
            EXECUTE_PORTFOLIO_RECEIVABLE(v_strdate);
            --null; -- Se comenta la ejecución del cubo para evitar errores de ejecución
        end if;

        if p_execute_carga_cuentas_a_sla2 IN ('SI') then
            CARGA_CUENTAS_CONTABLES_A_SLA2(p_period_name);
            --null; -- Se comenta la ejecución del cubo para evitar errores de ejecución
        end if;

        if p_execute_collected_receipts IN ('SI') then
            EXECUTE_COLLECTED_RECEIPTS(p_period_name);
            --null; -- Se comenta la ejecución del cubo para evitar errores de ejecución
        end if;

        if p_send_mail IN ('SI') then
            SEND_MAIL(p_period_name, v_strdate);           
            --null;

        end if;

        logprc(0, '0', '1.1.1. TERMINA PROCESO DE CIERRE DE IEPS');
        l('1.1.1. TERMINA PROCESO DE CIERRE DE IEPS');
        
    EXCEPTION
        WHEN v_raise THEN
            errbuf := 'Error al convertir la fecha (v_strdate - ' || v_strdate || '): ' || SQLERRM;
            retcode := 1;
        WHEN OTHERS THEN
            errbuf := 'Error inesperado: ' || SQLERRM;
            retcode := 2;
    END MAIN_PROCEDURE;
END XXAR_CIERRE_IEPS;