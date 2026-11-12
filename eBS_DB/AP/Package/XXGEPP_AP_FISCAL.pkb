 CREATE OR REPLACE PACKAGE BODY SI2EBS.XXGEPP_AP_FISCAL AS

 PROCEDURE CREATE_DATA_GL_AP(P_USER VARCHAR2
                            ,P_APP_ID NUMBER
                            ,P_APP_PAGE NUMBER
                            ,P_PERIOD_NAME VARCHAR2  
                            ,P_CIA VARCHAR2                          
                            ,P_OUT_CODE OUT NUMBER
                            ,P_OUT_MESSAGE OUT VARCHAR2
                            )
IS
    v_count NUMBER;
    V_EXCEPTION_PROC EXCEPTION;

    v_allow_processing NUMBER;
    V_ALLOW_REGENERATION NUMBER;

    V_OUT_CODE number;
    V_OUT_MESSAGE varchar2(2000);
    V_CONTROL_ID NUMBER;
    V_FILE_NAME VARCHAR2(30);
    V_SQL_EXECUTE VARCHAR2(1000);
BEGIN
    v_allow_processing :=1;

    v_count:= 0;

    IF P_PERIOD_NAME is null or  P_CIA is null THEN
        V_OUT_CODE := 1;
        V_OUT_MESSAGE := 'Es necesario llenar la Compañia y el Periodo.';
        RAISE V_EXCEPTION_PROC;
    END IF;

    -- Se valida si el periodo ya esta poblado.
    SELECT /*+index(a CUST_AP_SLA2_POLIZAS_IDX1)*/ COUNT(*)
    into v_count
    FROM SLA2EBS.cust_ap_sla2_polizas a
    WHERE 1=1
    AND a.periodo  = P_PERIOD_NAME
	AND a.segment1 = P_CIA
    AND ROWNUM<=1;

    IF v_count= 0 THEN
        V_OUT_CODE := 1;
        V_OUT_MESSAGE := 'No hay información de la Compañia '||P_CIA||' Periodo: ' || P_PERIOD_NAME || '.';
        RAISE V_EXCEPTION_PROC;
    END IF;

    v_count :=0;

    BEGIN
        SELECT COUNT(*)
        INTO V_COUNT
        FROM SI2EBS.XXAP_FISCAL_GL_FILES_V
        WHERE 1=1
        AND CIA = P_CIA
        AND PERIODO = P_PERIOD_NAME
        AND ESTATUS ='EJECUCION';

        IF v_count >0 THEN
            V_OUT_CODE := 1;
            V_OUT_MESSAGE := 'la Compañia '||P_CIA||' y Periodo: ' || P_PERIOD_NAME || ' no se puede ejecutar nuevamente hasta que termine el proceso actual.';
            RAISE V_EXCEPTION_PROC;
        END IF;
    END;

    v_count :=0;

    SELECT COUNT(*)
    into v_count
    FROM XXAP_FISCAL_GL_FILES_TBL
    WHERE 1=1
    AND period_name = P_PERIOD_NAME
    and cia= P_CIA;

    IF v_count = 0 THEN
        V_ALLOW_REGENERATION :=1;

        INSERT INTO XXAP_FISCAL_GL_FILES_TBL
            (PERIOD_NAME
            ,CIA
            ,STATUS
            ,CONTROL_ID 
            ,CREATED_BY  
            ,CREATION_DATE 
            ,LAST_UPDATED_BY 
            ,LAST_UPDATE_DATE 
            ,ALLOW_REGENERATION)
        VALUES(P_PERIOD_NAME
            ,P_CIA
            ,'EJECUCION'
            ,NULL
            ,P_USER
            ,SYSDATE
            ,P_USER
            ,SYSDATE
            ,V_ALLOW_REGENERATION);
        
        COMMIT;

        v_allow_processing := 0;
    ELSE
        
        -- Revisa si el estatus esta en error
        
            SELECT COUNT(*)
            INTO V_COUNT
            FROM SI2EBS.XXAP_FISCAL_GL_FILES_V
            WHERE 1=1
            AND CIA = P_CIA
            AND PERIODO = P_PERIOD_NAME
            AND ESTATUS ='ERROR';

        

        IF V_COUNT = 0 THEN            
            
            SELECT NVL(ALLOW_REGENERATION,1)
            INTO V_ALLOW_REGENERATION
            FROM XXAP_FISCAL_GL_FILES_TBL
            WHERE 1=1
            AND period_name = P_PERIOD_NAME
            and cia= P_CIA;

           
        ELSE
            V_ALLOW_REGENERATION := 0;

            
        END IF;
        
        IF V_ALLOW_REGENERATION = 0 THEN
            v_allow_processing := 0;
        END IF;
    END IF;

    IF v_allow_processing != 0 THEN
        V_OUT_CODE := 1;
        V_OUT_MESSAGE := 'No tiene permitido regenerar el periodo ' || P_PERIOD_NAME || '. Para reprocesarlo hay que solicitar su reactivación. (Allow regeneration=1)';
        RAISE V_EXCEPTION_PROC;
    END IF;

    V_FILE_NAME := P_CIA || '_' || P_PERIOD_NAME || '_' || to_char(sysdate,'YYYYMMDDHH24MISS')|| '.xlsx';

    V_SQL_EXECUTE := 'BEGIN SI2EBS.XXGEPP_AP_FISCAL.POPULATE_TABLE('''''||P_PERIOD_NAME||''''','''''||P_CIA||'''''); END;';
    --SI2EBS.XXGEPP_AP_FISCAL.POPULATE_TABLE(P_PERIOD_NAME,P_CIA);

    XX_APEX.XXGEPP_APEX_UTILITIES.SAVE_LONG_FILES(P_USER
                            ,P_APP_ID
                            ,P_APP_PAGE
                            ,'AP'
                            ,'FISCAL_APEX'
                            ,1--P_QUERY_NUMBER NUMBER
                            ,2--P_QUERY_VERSION NUMBER
                            ,V_FILE_NAME---P_FILE_NAME VARCHAR2
                            ,'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' --VARCHAR2
                            ,FALSE --P_CREATE_ZIP BOOLEAN
                            ,P_PERIOD_NAME
                            ,P_CIA
                            ,NULL
                            ,NULL
                            ,NULL
                            ,V_SQL_EXECUTE 
                            ,V_OUT_CODE
                            ,V_OUT_MESSAGE
                            ,V_CONTROL_ID
                            );
            
        /*DBMS_OUTPUT.PUT_LINE('V_OUT_CODE:'||V_OUT_CODE);
        DBMS_OUTPUT.PUT_LINE('V_OUT_MESSAGE:'||V_OUT_MESSAGE);
        DBMS_OUTPUT.PUT_LINE('V_CONTROL_ID:'||V_CONTROL_ID);
        */

        IF V_OUT_CODE = 0 AND V_CONTROL_ID>0 THEN
            UPDATE XXAP_FISCAL_GL_FILES_TBL
            set CONTROL_ID =V_CONTROL_ID
                ,LAST_UPDATE_DATE = sysdate
                ,ALLOW_REGENERATION =1
            where period_name = P_PERIOD_NAME
            and cia= P_CIA;
            commit;
        ELSE
            UPDATE XXAP_FISCAL_GL_FILES_TBL
            set CONTROL_ID =V_CONTROL_ID
                ,LAST_UPDATE_DATE = sysdate
                ,ALLOW_REGENERATION =0
            where period_name = P_PERIOD_NAME
            and cia= P_CIA;
            commit;
        END IF;
        P_OUT_CODE := V_OUT_CODE;
        P_OUT_MESSAGE:=V_OUT_MESSAGE;
EXCEPTION
    WHEN V_EXCEPTION_PROC THEN
            P_OUT_CODE := V_OUT_CODE;
            P_OUT_MESSAGE:=V_OUT_MESSAGE;
    WHEN OTHERS THEN
            V_OUT_CODE := 666;
            V_OUT_MESSAGE:='err No controlado:'|| SQLCODE || '-->' ||  SUBSTR(SQLERRM, 1, 200);

            P_OUT_CODE := V_OUT_CODE;
            P_OUT_MESSAGE:=V_OUT_MESSAGE;
END CREATE_DATA_GL_AP;

    PROCEDURE POPULATE_TABLE(P_PERIOD_NAME VARCHAR2  
                            ,P_CIA VARCHAR2)
    IS
    BEGIN
        --EXECUTE IMMEDIATE 'TRUNCATE TABLE SI2EBS.XXAP_FISCAL_GL_FILES_DATA_TT';
        DELETE SI2EBS.XXAP_FISCAL_GL_FILES_DATA_TT
        WHERE 1=1
        AND PERIODO  = P_PERIOD_NAME    
        AND SEGMENT1_Q = '''' || P_CIA ;
        COMMIT;

        INSERT INTO SI2EBS.XXAP_FISCAL_GL_FILES_DATA_TT
            select /*+index(a CUST_AP_SLA2_POLIZAS_IDX1)*/  
            a.id_ejecucion,
            a.origen,
            a.categoria,
            a.periodo,
            a.lote,
            a.fecha_contable,
            a.poliza,
            a.code_combination_id,
            '''' || a.segment1  AS segment1_q,
            '''' || a.segment2  AS segment2_q,
            '''' || a.segment3  AS segment3_q,
            '''' || a.segment4  AS segment4_q,
            '''' || a.segment5  AS segment5_q,
            '''' || a.segment6  AS segment6q,
            '''' || a.segment7  AS segment7_q,
            a.descripcion,
            a.ae_header_id,
            a.ae_line_num,
            a.debito_mon_transaccion,
            a.credito_mon_transaccion,
            a.debito_mon_nacional,
            a.credito_mon_nacional,
            a.moneda,
            a.tipo_cambio,
            a.numero_transaccion,
            a.clase_cuenta,
            a.fecha_transaccion,
            a.uuid,
            a.numero_cliente,
            a.nombre_cliente,
            a.rfc,
            a.invoice_id,
            a.org_id,
            a.descripcion_h,
            a.header_id,    
            NULL AS descripcion_factura,
            NULL AS creacion_factura,
            NULL AS pagado,
            NULL AS tipo_factura,
            NULL source,
            NULL  estatus,
            NULL oc,
            NULL recepcion
        FROM	SLA2EBS.cust_ap_sla2_polizas a    	
            WHERE 1=1
             --AND ROWNUM<=100
                AND a.periodo  = P_PERIOD_NAME
                AND a.segment1 = P_CIA 
	    --AND a.categoria != 'Facturas Compra'
        ;
        COMMIT;

        DECLARE
            v_limit PLS_INTEGER := 500;
            CURSOR cur_d IS
                    SELECT /*+ DRIVING_SITE(b)*/ B.INVOICE_ID,
                    B.DESCRIPTION AS DESCRIPCION_FACTURA,
                                            B.CREATION_DATE AS CREACION_FACTURA,
                                            B.PAYMENT_STATUS_FLAG AS PAGADO,
                                            B.INVOICE_TYPE_LOOKUP_CODE AS TIPO_FACTURA,
                                            APPS.CUST_AP_FACTURA_ORIGEN_FNC@ORA19_TO_EBSPROD.SUBNETPRODUCCIO.VCNDATABASESTIE.ORACLEVCN.COM(B.SOURCE, B.ATTRIBUTE4) SOURCE,
                                            AP_INVOICES_PKG.GET_APPROVAL_STATUS@ORA19_TO_EBSPROD.SUBNETPRODUCCIO.VCNDATABASESTIE.ORACLEVCN.COM(
                                                        B.INVOICE_ID,
                                                        B.INVOICE_AMOUNT,
                                                        B.PAYMENT_STATUS_FLAG,
                                                        B.INVOICE_TYPE_LOOKUP_CODE
                                                    )  ESTATUS,
                                            APPS.CUST_AP_GET_PO_REC_FNC@ORA19_TO_EBSPROD.SUBNETPRODUCCIO.VCNDATABASESTIE.ORACLEVCN.COM('PO', B.INVOICE_ID) OC,
                                            APPS.CUST_AP_GET_PO_REC_FNC@ORA19_TO_EBSPROD.SUBNETPRODUCCIO.VCNDATABASESTIE.ORACLEVCN.COM('REC', B.INVOICE_ID) RECEPCION                                        
                    FROM 
                        (SELECT INVOICE_ID
                            FROM SI2EBS.XXAP_FISCAL_GL_FILES_DATA_TT A
                            WHERE 1=1
                            AND PERIODO  = P_PERIOD_NAME    
                            AND SEGMENT1_Q = '''' || P_CIA 
                            --AND A.CREACION_FACTURA IS NULL
                            AND A.CATEGORIA = 'Facturas Compra' --*****
                            GROUP BY INVOICE_ID) A
                        ,AP_INVOICES_ALL@ORA19_TO_EBSPROD.SUBNETPRODUCCIO.VCNDATABASESTIE.ORACLEVCN.COM B
                    WHERE 1=1
                    AND B.INVOICE_ID = A.INVOICE_ID
                --AND ROWNUM <=1000
				;

        TYPE cur_d_tb IS TABLE OF SI2EBS.XXAP_FISCAL_GL_FILES_DATA_INVOICES_TT%ROWTYPE INDEX BY PLS_INTEGER;
            cur_d_arr cur_d_tb;


        BEGIN
                DELETE SI2EBS.XXAP_FISCAL_GL_FILES_DATA_INVOICES_TT;
                COMMIT;
                
                
                OPEN  cur_d ;
                LOOP
                    FETCH cur_d BULK COLLECT INTO cur_d_arr LIMIT v_limit;
                    FORALL i IN 1 .. cur_d_arr.COUNT
                    insert into  SI2EBS.XXAP_FISCAL_GL_FILES_DATA_INVOICES_TT values cur_d_arr(i);
                    
                    COMMIT;
                    
                    EXIT WHEN cur_d%NOTFOUND;
                END LOOP;
                CLOSE cur_d;
                COMMIT;     

                -- Se atualiza en la tabla local
                UPDATE SI2EBS.XXAP_FISCAL_GL_FILES_DATA_TT a
                SET (descripcion_factura,
                    creacion_factura,
                    pagado,
                    tipo_factura,
                    source,
                    estatus,
                    oc,
                    recepcion
                    ) = (SELECT /*+ DRIVING_SITE(b)*/ b.descripcion_factura,
                                            b.creacion_factura,
                                            b.pagado,
                                            b.tipo_factura,
                                            B.source,
                                            B.estatus,
                                            B.oc,
                                            B.recepcion                                                                                
                        FROM SI2EBS.XXAP_FISCAL_GL_FILES_DATA_INVOICES_TT b
                        WHERE 1=1
                        AND b.invoice_id = a.invoice_id) 
                WHERE 1=1
                AND PERIODO  = P_PERIOD_NAME    
                AND SEGMENT1_Q = '''' ||P_CIA
                --AND a.creacion_factura IS null
                AND a.categoria = 'Facturas Compra';  
            COMMIT;
        END;

        DELETE XXAP_FISCAL_GL_FILES_DATA_INVOICES_TT;
        COMMIT;
        
    END POPULATE_TABLE;

 END XXGEPP_AP_FISCAL;