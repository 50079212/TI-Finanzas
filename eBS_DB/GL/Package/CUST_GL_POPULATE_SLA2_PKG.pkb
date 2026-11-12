CREATE OR REPLACE PACKAGE BODY APPS.CUST_GL_POPULATE_SLA2_PKG IS 

G_PHASE_CODE       VARCHAR2(1);
G_STATUS_CODE      VARCHAR2(1);

PROCEDURE MESSAGE_LOG (P_MESSAGE IN VARCHAR2) IS
BEGIN 
    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,P_MESSAGE);
    DBMS_OUTPUT.PUT_LINE('LOG: '||P_MESSAGE); 
END; 

PROCEDURE MESSAGE_OUTPUT (P_MESSAGE IN VARCHAR2) IS
BEGIN 
    APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,P_MESSAGE);
    DBMS_OUTPUT.PUT_LINE('OUTPUT: '||P_MESSAGE); 
END; 

PROCEDURE MAIN_VALIDACIONES(ERRBUF              OUT VARCHAR2
                                                   ,RETCODE             OUT NUMBER
                                                   ,P_TIPO_EJECUCION    IN VARCHAR2
                                                   ,P_MODULO            IN VARCHAR2
                                                   ,P_EJECUCION         IN NUMBER
                                                   ,P_PERIODO           IN VARCHAR2 --GL_PERIODS.PERIOD_NAME%TYPE
                                                   ,P_CORREO            IN VARCHAR2) IS 

V_EX                VARCHAR2(2); 
V_ID_LAST_EXECUTE   NUMBER;
V_FECHA_EXE         DATE;
V_USER_EXE          VARCHAR2(40);
V_PERIODO_EXE       GL_PERIODS.PERIOD_NAME%TYPE;  
V_MODULO            VARCHAR2(10);

V_EXECUTE_ID        NUMBER := CUST_SEQUENCE_EXECUTE_SLA2.NEXTVAL;
V_ESTATUS           VARCHAR2(200);
V_ERROR             BOOLEAN := FALSE;
V_USER              VARCHAR2(40);
V_CUENTA            NUMBER;

V_REQUEST_ID        NUMBER := FND_GLOBAL.CONC_REQUEST_ID;



BEGIN
    /*====================OBTIENE EL USUARIO QUE EJECUTA EL CONCURRENTE====================*/
    BEGIN
        SELECT NVL(USER_NAME,'SIN USUARIO') 
        INTO V_USER
        FROM FND_USER 
        WHERE USER_ID = FND_PROFILE.VALUE('USER_ID');
    EXCEPTION WHEN NO_DATA_FOUND THEN
        V_USER := 'SIN USUARIO';
    END; 

    /*====================VALIDACIONES PARA CARGAS YA EXISTENTES====================*/
    IF P_TIPO_EJECUCION = 'CARGA' THEN 

    /*====================BUSCA UNA CARGA EXISTENTE PARA EL MODULO SOLICITADO====================*/
        BEGIN 
            SELECT 'EX'
                  ,ID_EJECUCION
                  ,FECHA_EJECUCION
                  ,NOMBRE_USUARIO
                  ,PERIODO 
                  ,MODULO 
            INTO V_EX
                ,V_ID_LAST_EXECUTE
                ,V_FECHA_EXE
                ,V_USER_EXE
                ,V_PERIODO_EXE
                ,V_MODULO
            FROM CUST_SLA2_EJECUCION
            WHERE 1=1
            AND ORIGEN = 'EBS'
            AND PERIODO = P_PERIODO
            AND MODULO = P_MODULO
            AND ESTATUS = 'CARGA';            
        EXCEPTION WHEN NO_DATA_FOUND THEN 
            V_EX := 'NO';
        END;

        /*====================IMPRIME MENSAJES EN EL LOG SI LA CARGA YA EXISTIA====================*/
        IF V_EX = 'EX' THEN 
            MESSAGE_LOG('ERROR EN LA CARGA DEL MODULO:'|| P_MODULO||', LA INFORMACION YA EXISTE');
            MESSAGE_LOG('INFORMACION DE LA CARGA EXISTENTE');
            MESSAGE_LOG('FECHA EJECUCION: '||V_FECHA_EXE);
            MESSAGE_LOG('USUARIO: '||V_USER_EXE);
            MESSAGE_LOG('PERIODO: '||V_PERIODO_EXE);
            MESSAGE_LOG('MODULO:  '||V_MODULO); 
            V_ERROR := TRUE;
        END IF;

        /*====================CARGA VALIDA SI OCURRIO ALGUN ERROR====================*/
        IF V_ERROR = TRUE THEN
            /*====================CARGA LAS VARIABLES DE LA INSERCION EN LA TABLA DE EJECUCIONES*/
            V_ESTATUS := 'ERROR LA CARGA YA EXISTE';
            V_CUENTA := NULL;
        ELSE
            /*====================COMIENZA LA CARGA DE LAS POLIZAS SEGUN EL MODULO EJECUTADO====================*/
            IF P_MODULO = 'AP' THEN 
                MESSAGE_LOG('COMIENZA LA CARGA DE AP');
                POPULATE_AP(P_PERIODO
                           ,V_EXECUTE_ID
                           ,V_CUENTA
                           ,V_ESTATUS
                           ,V_ERROR);
            END IF; 

            IF P_MODULO = 'AR'  THEN 
                MESSAGE_LOG('COMIENZA LA CARGA DE AR');
                POPULATE_AR(P_PERIODO
                           ,V_EXECUTE_ID
                           ,V_CUENTA
                           ,V_ESTATUS
                           ,V_ERROR);
            END IF; 

            IF P_MODulo = 'GL' THEN
                MESSAGE_LOG('COMIENZA LA CARGA DE GL');
                POPULATE_GL(P_PERIODO
                           ,V_EXECUTE_ID
                           ,V_CUENTA
                           ,V_ESTATUS
                           ,V_ERROR);
            END IF;     

            IF P_MODulo = 'BALANZA' THEN
                MESSAGE_LOG('COMIENZA LA CARGA DE BALANZA');
                POPULATE_BLANAZA(P_PERIODO
                           ,V_EXECUTE_ID
                           ,V_CUENTA
                           ,V_ESTATUS
                           ,V_ERROR);
            END IF;     

            V_ID_LAST_EXECUTE := NULL;
        END IF;       
    END IF;

    IF P_TIPO_EJECUCION = 'MODIFICACION' THEN
        /*====================ELIMI LOS REGISTROS YA EXISTENTES PARA EL PERIODO Y MODULO SELECCIONADO====================*/
        IF P_MODULO = 'AP' THEN
            BEGIN
                DELETE CUST_AP_SLA2_POLIZAS
                WHERE PERIODO = P_PERIODO;
           EXCEPTION WHEN OTHERS THEN 
                MESSAGE_LOG ('Error al ELIMINAR el periodo: '||P_PERIODO||', correspondiente al modulo de AP');
                V_ERROR := TRUE;
           END;
        END IF;

        IF P_MODULO = 'AR' THEN
            BEGIN
                DELETE CUST_AR_SLA2_POLIZAS
                WHERE PERIODO = P_PERIODO;
           EXCEPTION WHEN OTHERS THEN 
                MESSAGE_LOG ('Error al ELIMINAR el periodo: '||P_PERIODO||', correspondiente al modulo de AR');
                V_ERROR := TRUE;
           END;
        END IF;

        IF P_MODULO = 'GL' THEN
            BEGIN
                DELETE CUST_GL_SLA2_POLIZAS
                WHERE PERIODO = P_PERIODO;
           EXCEPTION WHEN OTHERS THEN 
                MESSAGE_LOG ('Error al ELIMINAR el periodo: '||P_PERIODO||', correspondiente al modulo de GL');
                V_ERROR := TRUE;
           END;
        END IF;

        IF P_MODULO = 'BALANZA' THEN
            BEGIN
                DELETE CUST_GL_SLA2_BALANCE
                WHERE PERIODO = P_PERIODO;
           EXCEPTION WHEN OTHERS THEN 
                MESSAGE_LOG ('Error al ELIMINAR el periodo: '||P_PERIODO||', correspondiente al modulo de BALANZA');
                V_ERROR := TRUE;
           END;
        END IF;

        /*====================VALIDA SI OCURRIO ALGUN ERROR AL ELIMINAR LA INFORMACION====================*/
        IF V_ERROR = TRUE THEN
            /*====================CARGA LAS VARIABLES PARA LA INSERSION EN LA TABLS DE EJECUCIONES====================*/
            V_ESTATUS := 'ERROR EN MODIFICACION DE PERIODO';
            V_CUENTA := NULL;
        ELSE
            /*====================CARGA LA NUEVA INFORMACION SEGUN EL MODULO SELECCIONADO====================*/
            IF P_MODULO = 'AP' THEN 
                MESSAGE_LOG('COMIENZA LA MODIFICACION DE AP');
                POPULATE_AP(P_PERIODO
                           ,V_EXECUTE_ID
                           ,V_CUENTA
                           ,V_ESTATUS
                           ,V_ERROR);
            END IF; 

            IF P_MODULO = 'AR' THEN 
                MESSAGE_LOG('COMIENZA LA MODIFICACION DE AR');
                POPULATE_AR(P_PERIODO
                           ,V_EXECUTE_ID
                           ,V_CUENTA
                           ,V_ESTATUS
                           ,V_ERROR);
            END IF; 

            IF P_MODULO = 'GL' THEN 
                MESSAGE_LOG('COMIENZA LA MODIFICACION DE GL');
                POPULATE_GL(P_PERIODO
                           ,V_EXECUTE_ID
                           ,V_CUENTA
                           ,V_ESTATUS
                           ,V_ERROR);
            END IF;      

            IF P_MODULO = 'BALANZA' THEN 
                MESSAGE_LOG('COMIENZA LA MODIFICACION DE BALANZA');
                POPULATE_BLANAZA(P_PERIODO
                           ,V_EXECUTE_ID
                           ,V_CUENTA
                           ,V_ESTATUS
                           ,V_ERROR);
            END IF;     

            /*====================SI NO OCURRIO UN ERROR DURANTE LA CARGA CARGA LA VARIABLÑE DE ESTATUS DE LA INSERSION====================*/
            IF V_ERROR = FALSE THEN
                V_ESTATUS := 'MODIFICACION';
            END IF;
        END IF;
        V_ID_LAST_EXECUTE := P_EJECUCION;       
    END IF;                 

   /*====================INSERTA LA INFORMACION DE LE EJECUCION====================*/ 
    BEGIN 
        INSERT INTO CUST_SLA2_EJECUCION
        VALUES (V_EXECUTE_ID
               ,'EBS'
               ,SYSDATE
               ,V_USER
               ,P_PERIODO
               ,P_MODULO
               ,V_ESTATUS
               ,V_CUENTA
               ,V_ID_LAST_EXECUTE);
    EXCEPTION WHEN OTHERS THEN 
        MESSAGE_LOG('ERROR AL INSERTAR EN LA TABLA CUST_SLA2_EJECUCION');
    END;

    COMMIT;
    /*====================SI OCURRIO ALGUN ERROR DURANTE LA EJECUCION TERMINA EL CONCURRENTE CON ESTATUS DISTINTO A NORMAL====================*/
    IF V_ERROR = TRUE THEN 
        BEGIN
            UPDATE FND_CONCURRENT_REQUESTS
            SET PHASE_CODE = 'C' --CAMBIA LA FASE DEL CONCURRENTE A COMPLETED
               ,STATUS_CODE = 'X' -- DEJA EL ESTATUS DEL CONCURRENTE EN TERMINATED 
                            /*'G' --DEJA EL ESTATUS DEL CONCURRNETE EN WARNING */  
                            /*'E' --DEJA EL ESTATUS DEL CONCURRENTE EN ERROR */
            WHERE REQUEST_ID = V_REQUEST_ID;

            MESSAGE_LOG('EJECUCION DEL CONCURRENTE TERMINADA');
        EXCEPTION WHEN OTHERS THEN 
            MESSAGE_LOG('ERROR AL TERMINAR EL CONCURRENTE');
        END;
    END IF;
END;

PROCEDURE POPULATE_AR (P_PERIODO    IN  VARCHAR2
                      ,P_EXECUTE_ID IN  NUMBER
                      ,P_CUENTA     OUT NUMBER
                      ,P_ESTATUS    OUT VARCHAR2
                      ,P_ERROR      OUT BOOLEAN) IS

CURSOR CUR_DATA_UUID IS
                        SELECT  P_EXECUTE_ID,                                
                                GJS.USER_JE_SOURCE_NAME ORIGEN,
                                GJC.USER_JE_CATEGORY_NAME CATEGORIA,
                                GJH.PERIOD_NAME PERIODO,
                                GJB.NAME LOTE,
                                GJH.CREATION_DATE FECHA_CONTABLE,
                                GJH.NAME POLIZA,
                                GCC.CODE_COMBINATION_ID,
                                GCC.SEGMENT1,
                                GCC.SEGMENT2,
                                GCC.SEGMENT3,
                                GCC.SEGMENT4,
                                GCC.SEGMENT5,
                                GCC.SEGMENT6,
                                GCC.SEGMENT7,
                                SUBSTR(GJL.DESCRIPTION, 25) DESCRIPCION,
                                XAH.AE_HEADER_ID,
                                XAL.AE_LINE_NUM,
                                NVL(XAL.ENTERED_DR,0) DEBITO_MON_TRANSACCION,
                                NVL(XAL.ENTERED_CR,0) CREDITO_MON_TRANSACCION,
                                NVL(XAL.ACCOUNTED_DR,0) DEBITO_MON_NACIONAL,
                                NVL(XAL.ACCOUNTED_CR,0) CREDITO_MON_NACIONAL,
                                XAL.CURRENCY_CODE MONEDA,
                                NVL(XAL.CURRENCY_CONVERSION_RATE,1) TIPO_CAMBIO,
                                RCT.TRX_NUMBER NUMERO_TRANSACCION,
                                XAL.ACCOUNTING_CLASS_CODE CLASE_CUENTA,
                                RCT.TRX_DATE FECHA_TRANSACCION,
                                CLOG.UUID,
                                HCA.ACCOUNT_NUMBER NUMERO_CLIENTE,
                                HP.PARTY_NAME NOMBRE_CLIENTE,
                                HP.TAX_REFERENCE RFC,
                                NULL ATTRIBUTE1,
                                NULL ATTRIBUTE2,
                                NULL ATTRIBUTE3,
                                NULL ATTRIBUTE4,
                                NULL ATTRIBUTE5,
                                NULL ATTRIBUTE6,
                                NULL ATTRIBUTE7,
                                NULL ATTRIBUTE8,
                                NULL ATTRIBUTE9,
                                NULL ATTRIBUTE10,
                                NULL ATTRIBUTE11,
                                NULL ATTRIBUTE12,
                                NULL ATTRIBUTE13,
                                NULL ATTRIBUTE14,
                                NULL ATTRIBUTE15,
                                NULL ATTRIBUTE16,
                                NULL ATTRIBUTE17,
                                NULL ATTRIBUTE18,
                                NULL ATTRIBUTE19,
                                NULL ATTRIBUTE20,
                                NULL ATTRIBUTE21,
                                NULL ATTRIBUTE22,
                                NULL ATTRIBUTE23,
                                NULL ATTRIBUTE24,
                                GJH.DESCRIPTION,
                                GJH.JE_HEADER_ID HEADER_ID,
                                RCT.CUSTOMER_TRX_ID,
                                XE.EVENT_TYPE_CODE,
                                null FILE_SAT,
                                RBSA.NAME ORIGEN_2,
                                RCTTA.NAME TIPO_TRANSACCION
                        FROM
                                GL_JE_BATCHES GJB,
                                GL_JE_HEADERS GJH,
                                GL_JE_LINES GJL,
                                GL_JE_SOURCES_TL GJS,
                                GL_JE_CATEGORIES_TL GJC,
                                GL_CODE_COMBINATIONS GCC,
                                GL_IMPORT_REFERENCES IMP,
                                XLA_AE_LINES XAL,
                                XLA_AE_HEADERS XAH,
                                XLA_EVENTS XE,
                                XLA.XLA_TRANSACTION_ENTITIES XTE,
                                CUST_AR_FACTELEC_LOG CLOG,
                                HZ_CUST_ACCOUNTS HCA,
                                HZ_PARTIES HP,
                                RA_CUSTOMER_TRX_ALL RCT,
                                AR.RA_BATCH_SOURCES_ALL RBSA,
                                AR.RA_CUST_TRX_TYPES_ALL RCTTA
                        WHERE 1 = 1
                        AND GJB.JE_BATCH_ID = GJH.JE_BATCH_ID
                        AND GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
                        AND GJH.JE_SOURCE = GJS.JE_SOURCE_NAME
                        AND GJH.JE_CATEGORY = GJC.JE_CATEGORY_NAME
                        AND GJS.LANGUAGE = USERENV('LANG')
                        AND GJC.LANGUAGE = USERENV('LANG')
                        AND GJL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                        AND GJL.JE_HEADER_ID = IMP.JE_HEADER_ID
                        AND GJL.JE_LINE_NUM = IMP.JE_LINE_NUM
                        AND IMP.GL_SL_LINK_ID = XAL.GL_SL_LINK_ID
                        AND IMP.GL_SL_LINK_TABLE = XAL.GL_SL_LINK_TABLE
                        AND XTE.APPLICATION_ID = 222
                        AND XAL.APPLICATION_ID = XAH.APPLICATION_ID
                        AND XAL.AE_HEADER_ID = XAH.AE_HEADER_ID
                        AND XAH.APPLICATION_ID = XE.APPLICATION_ID
                        AND XAH.EVENT_ID = XE.EVENT_ID
                        AND XE.APPLICATION_ID = XTE.APPLICATION_ID
                        AND XE.ENTITY_ID = XTE.ENTITY_ID
                        AND XTE.SOURCE_ID_INT_1 = RCT.CUSTOMER_TRX_ID
                        AND RCT.CUSTOMER_TRX_ID    =  CLOG.CUSTOMER_TRX_ID(+)
                        AND RCT.BILL_TO_CUSTOMER_ID = HCA.CUST_ACCOUNT_ID
                        AND HCA.PARTY_ID = HP.PARTY_ID
                        AND GJL.STATUS||'' = 'P'
                        AND GJH.ACTUAL_FLAG = 'A'
                        --AND GCC.SEGMENT1 = '203'
                        AND GJH.JE_SOURCE = 'Receivables'
                        AND XTE.ENTITY_CODE = 'TRANSACTIONS'
                        AND GJH.JE_CATEGORY IN ('Sales Invoices', 'Credit Memos', 'Debit Memos') --'SALES INVOICES', 'CREDIT MEMOS', 'DEBIT MEMOS'
                        AND GJH.PERIOD_NAME = P_PERIODO
                        AND RBSA.ORG_ID = RCT.ORG_ID
                        AND RBSA.BATCH_SOURCE_ID = RCT.BATCH_SOURCE_ID
                        AND RCTTA.CUST_TRX_TYPE_ID = RCT.CUST_TRX_TYPE_ID
                        AND RCTTA.ORG_ID = RCT.ORG_ID;

TYPE TT_DATA_UUID IS TABLE OF CUR_DATA_UUID%ROWTYPE;
LT_DATA_UUID   TT_DATA_UUID;

CURSOR CUR_DATA_RECIBOS IS SELECT
                                    P_EXECUTE_ID,                                    
                                    GJS.USER_JE_SOURCE_NAME ORIGEN,
                                    GJC.USER_JE_CATEGORY_NAME CATEGORIA,
                                    GJH.PERIOD_NAME PERIODO,
                                    GJB.NAME LOTE,
                                    GJH.CREATION_DATE FECHA_CONTABLE,
                                    GJH.NAME POLIZA,
                                    GCC.CODE_COMBINATION_ID,
                                    GCC.SEGMENT1,
                                    GCC.SEGMENT2,
                                    GCC.SEGMENT3,
                                    GCC.SEGMENT4,
                                    GCC.SEGMENT5,
                                    GCC.SEGMENT6,
                                    GCC.SEGMENT7,
                                    SUBSTR(GJL.DESCRIPTION, 25) DESCRIPCION,
                                    XAH.AE_HEADER_ID, 
                                    XAL.AE_LINE_NUM,
                                    NVL(XAL.ENTERED_DR,0) DEBITO_MON_TRANSACCION,
                                    NVL(XAL.ENTERED_CR,0) CREDITO_MON_TRANSACCION,
                                    NVL(XAL.ACCOUNTED_DR,0) DEBITO_MON_NACIONAL,
                                    NVL(XAL.ACCOUNTED_CR,0) CREDITO_MON_NACIONAL,
                                    XAL.CURRENCY_CODE MONEDA,
                                    NVL(XAL.CURRENCY_CONVERSION_RATE,1) TIPO_CAMBIO,
                                    ACR.RECEIPT_NUMBER NUMERO_TRANSACCION,
                                    XAL.ACCOUNTING_CLASS_CODE CLASE_CUENTA, 
                                    ACR.RECEIPT_DATE FECHA_TRANSACCION,
                                    NULL UUID,
                                    NULL NUMERO_CLIENTE,
                                    NULL NOMBRE_CLIENTE,
                                    NULL RFC,
                                    NULL ATTRIBUTE1,
                                    NULL ATTRIBUTE2,
                                    NULL ATTRIBUTE3,
                                    NULL ATTRIBUTE4,
                                    NULL ATTRIBUTE5,
                                    NULL ATTRIBUTE6,
                                    NULL ATTRIBUTE7,
                                    NULL ATTRIBUTE8,
                                    NULL ATTRIBUTE9,
                                    NULL ATTRIBUTE10,
                                    NULL ATTRIBUTE11,
                                    NULL ATTRIBUTE12,
                                    NULL ATTRIBUTE13,
                                    NULL ATTRIBUTE14,
                                    NULL ATTRIBUTE15,
                                    NULL ATTRIBUTE16,
                                    NULL ATTRIBUTE17, 
                                    NULL ATTRIBUTE18,
                                    NULL ATTRIBUTE19,
                                    NULL ATTRIBUTE20,
                                    NULL ATTRIBUTE21,
                                    NULL ATTRIBUTE22,
                                    NULL ATTRIBUTE23,
                                    NULL ATTRIBUTE24,
                                    GJH.DESCRIPTION,
                                    GJH.JE_HEADER_ID HEADER_ID,
                                    ACR.CASH_RECEIPT_ID,
                                    null EVENT_TYPE_CODE,
                                    null FILE_SAT,
                                    null ORIGEN_2,
                                    null TIPO_TRANSACCION
                            FROM 
                                    GL_JE_BATCHES GJB,
                                    GL_JE_HEADERS GJH,
                                    GL_JE_LINES GJL,
                                    GL_JE_SOURCES_TL GJS,
                                    GL_JE_CATEGORIES_TL GJC,
                                    GL_CODE_COMBINATIONS GCC,
                                    GL_IMPORT_REFERENCES IMP,
                                    XLA_AE_LINES XAL,
                                    XLA_AE_HEADERS XAH,
                                    XLA_EVENTS XE,
                                    XLA.XLA_TRANSACTION_ENTITIES XTE,
                                    AR_CASH_RECEIPTS_ALL ACR
                            WHERE 1 = 1
                            AND GJB.JE_BATCH_ID = GJH.JE_BATCH_ID
                            AND GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
                            AND GJH.JE_SOURCE = GJS.JE_SOURCE_NAME
                            AND GJH.JE_CATEGORY = GJC.JE_CATEGORY_NAME
                            AND GJS.LANGUAGE = USERENV('LANG')
                            AND GJC.LANGUAGE = USERENV('LANG')
                            AND GJL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                            AND GJL.JE_HEADER_ID = IMP.JE_HEADER_ID
                            AND GJL.JE_LINE_NUM = IMP.JE_LINE_NUM
                            AND IMP.GL_SL_LINK_ID = XAL.GL_SL_LINK_ID
                            AND IMP.GL_SL_LINK_TABLE = XAL.GL_SL_LINK_TABLE
                            AND XAL.APPLICATION_ID = XAH.APPLICATION_ID
                            AND XAL.AE_HEADER_ID = XAH.AE_HEADER_ID
                            AND XAH.APPLICATION_ID = XE.APPLICATION_ID
                            AND XAH.EVENT_ID = XE.EVENT_ID
                            AND XE.APPLICATION_ID = XTE.APPLICATION_ID
                            AND XTE.APPLICATION_ID = 222
                            AND XE.ENTITY_ID = XTE.ENTITY_ID
                            AND XTE.SOURCE_ID_INT_1 = ACR.CASH_RECEIPT_ID
                            AND GJL.STATUS||'' = 'P'
                            AND GJH.ACTUAL_FLAG = 'A'
                            --AND GCC.SEGMENT1 = '209'
                            AND GJH.JE_CATEGORY = 'Receipts'
                            AND XTE.ENTITY_CODE = 'RECEIPTS'
                            AND GJH.JE_SOURCE = 'Receivables'
                            AND GJH.PERIOD_NAME = P_PERIODO;

TYPE TT_DATA_RECIBOS IS TABLE OF CUR_DATA_RECIBOS%ROWTYPE;
LT_DATA_RECIBOS TT_DATA_RECIBOS; 

CURSOR CUR_DATA_ADJ IS SELECT
                                P_EXECUTE_ID,                                
                                GJS.USER_JE_SOURCE_NAME ORIGEN,
                                GJC.USER_JE_CATEGORY_NAME CATEGORIA,
                                GJH.PERIOD_NAME PERIODO,
                                GJB.NAME LOTE,
                                GJH.CREATION_DATE FECHA_CONTABLE,
                                GJH.NAME POLIZA,
                                GCC.CODE_COMBINATION_ID,
                                GCC.SEGMENT1,
                                GCC.SEGMENT2,
                                GCC.SEGMENT3,
                                GCC.SEGMENT4,
                                GCC.SEGMENT5,
                                GCC.SEGMENT6,
                                GCC.SEGMENT7,
                                SUBSTR(GJL.DESCRIPTION, 25) DESCRIPCION,
                                XAH.AE_HEADER_ID, 
                                XAL.AE_LINE_NUM,
                                NVL(XAL.ENTERED_DR,0) DEBITO_MON_TRANSACCION,
                                NVL(XAL.ENTERED_CR,0) CREDITO_MON_TRANSACCION,
                                NVL(XAL.ACCOUNTED_DR,0) DEBITO_MON_NACIONAL,
                                NVL(XAL.ACCOUNTED_CR,0) CREDITO_MON_NACIONAL,
                                XAL.CURRENCY_CODE MONEDA,
                                NVL(XAL.CURRENCY_CONVERSION_RATE,1) TIPO_CAMBIO,
                                AAA.ADJUSTMENT_NUMBER NUMERO_TRANSACCION,
                                XAL.ACCOUNTING_CLASS_CODE CLASE_CUENTA, 
                                AAA.APPLY_DATE FECHA_TRANSACCION,
                                NULL UUID,
                                NULL NUMERO_CLIENTE,
                                NULL NOMBRE_CLIENTE,
                                NULL RFC,
                                NULL ATTRIBUTE1,
                                NULL ATTRIBUTE2,
                                NULL ATTRIBUTE3,
                                NULL ATTRIBUTE4,
                                NULL ATTRIBUTE5,
                                NULL ATTRIBUTE6,
                                NULL ATTRIBUTE7,
                                NULL ATTRIBUTE8,
                                NULL ATTRIBUTE9,
                                NULL ATTRIBUTE10,
                                NULL ATTRIBUTE11,
                                NULL ATTRIBUTE12,
                                NULL ATTRIBUTE13,
                                NULL ATTRIBUTE14,
                                NULL ATTRIBUTE15,
                                NULL ATTRIBUTE16,
                                NULL ATTRIBUTE17,
                                NULL ATTRIBUTE18,
                                NULL ATTRIBUTE19,
                                NULL ATTRIBUTE20,
                                NULL ATTRIBUTE21,
                                NULL ATTRIBUTE22,
                                NULL ATTRIBUTE23,
                                NULL ATTRIBUTE24,
                                GJH.DESCRIPTION,
                                GJH.JE_HEADER_ID HEADER_ID,
                                AAA.ADJUSTMENT_ID,
                                null, 
                                null,
                                null,
                                null
                        FROM 
                                GL_JE_BATCHES GJB,
                                GL_JE_HEADERS GJH,
                                GL_JE_LINES GJL,
                                GL_JE_SOURCES_TL GJS,
                                GL_JE_CATEGORIES_TL GJC,
                                GL_CODE_COMBINATIONS GCC,
                                GL_IMPORT_REFERENCES IMP,
                                XLA_AE_LINES XAL,
                                XLA_AE_HEADERS XAH,
                                XLA_EVENTS XE,
                                XLA.XLA_TRANSACTION_ENTITIES XTE,
                                AR_ADJUSTMENTS_ALL AAA
                        WHERE 1=1
                        AND GJB.JE_BATCH_ID = GJH.JE_BATCH_ID
                        AND GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
                        AND GJH.JE_SOURCE = GJS.JE_SOURCE_NAME
                        AND GJH.JE_CATEGORY = GJC.JE_CATEGORY_NAME
                        AND GJS.LANGUAGE = USERENV('LANG')
                        AND GJC.LANGUAGE = USERENV('LANG')
                        AND GJL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                        AND GJL.JE_HEADER_ID = IMP.JE_HEADER_ID
                        AND GJL.JE_LINE_NUM = IMP.JE_LINE_NUM
                        AND IMP.GL_SL_LINK_ID = XAL.GL_SL_LINK_ID
                        AND IMP.GL_SL_LINK_TABLE = XAL.GL_SL_LINK_TABLE
                        AND XAL.APPLICATION_ID = XAH.APPLICATION_ID
                        AND XAL.AE_HEADER_ID = XAH.AE_HEADER_ID
                        AND XAH.APPLICATION_ID = XE.APPLICATION_ID
                        AND XAH.EVENT_ID = XE.EVENT_ID
                        AND XE.APPLICATION_ID = XTE.APPLICATION_ID
                        AND XTE.APPLICATION_ID = 222
                        AND XE.ENTITY_ID = XTE.ENTITY_ID
                        AND XTE.SOURCE_ID_INT_1 = AAA.ADJUSTMENT_ID
                        AND GJL.STATUS||'' = 'P'
                        AND GJH.ACTUAL_FLAG = 'A'
                        --AND GCC.SEGMENT1 = '209'
                        AND GJH.JE_SOURCE = 'Receivables'
                        AND GJH.JE_CATEGORY = 'Adjustment'
                        AND XTE.ENTITY_CODE = 'ADJUSTMENTS'
                        AND GJH.PERIOD_NAME = P_PERIODO;

TYPE TT_DATA_ADJ IS TABLE OF CUR_DATA_ADJ%ROWTYPE;
LT_DATA_ADJ TT_DATA_ADJ; 

CURSOR CUR_DATA_OK IS SELECT *
                      FROM CUST_TT_AR_SLA2_POLIZAS
                      WHERE UUID IS NOT NULL; 

TYPE TT_DATA_OK IS TABLE OF CUR_DATA_OK%ROWTYPE;
LT_DATA_OK TT_DATA_OK; 

P_ARRAY_SIZE    NUMBER  :=100000;
V_VALIDA        BOOLEAN := FALSE;
V_CUENTA        NUMBER  := 0;
V_INSERTA       BOOLEAN := TRUE;
V_ERROR         BOOLEAN := FALSE;
V_ESTATUS       VARCHAR2(100);
BEGIN

    /*====================ELIMINA LA INFORMACION DE LA TABLA TEMPORAL====================*/
    DELETE CUST_TT_AR_SLA2_POLIZAS;

    /*====================CARGA LAS TRANSACCIOANES QUE REQUIEREN UUID A LA TABLA TEMPORAL====================*/

    OPEN CUR_DATA_UUID;
    LOOP
        BEGIN 
            FETCH CUR_DATA_UUID
            BULK COLLECT INTO LT_DATA_UUID LIMIT P_ARRAY_SIZE;

            FORALL I IN 1..LT_DATA_UUID.COUNT
            INSERT INTO CUST_TT_AR_SLA2_POLIZAS VALUES LT_DATA_UUID(I);
        EXCEPTION WHEN OTHERS THEN 
            CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL INSERTAR TRANSACCIONES EN LA TABLA TEMPORAL');
            CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('Error Oracle: '||SQLERRM);
            V_ERROR := TRUE;
        END;

        EXIT WHEN CUR_DATA_UUID%NOTFOUND;
    END LOOP;
    CLOSE CUR_DATA_UUID;

    COMMIT;

    IF V_VALIDA = TRUE THEN 
        /*====================VALIDA QUE TODAS LAS TRANSACCIONES QUE DEPENDAN DE UUID LO TENGAN====================*/
        FOR CUR IN (SELECT UNIQUE 
                            ORIGEN,
                            PERIODO,
                            FECHA_CONTABLE,
                            NUMERO_TRANSACCION,
                            FECHA_TRANSACCION,
                            NUMERO_CLIENTE,
                            NOMBRE_CLIENTE,
                            RFC
                    FROM CUST_TT_AR_SLA2_POLIZAS
                    WHERE UUID IS NULL) 
         LOOP
            CUST_GL_POPULATE_SLA2_PKG.MESSAGE_OUTPUT(CUR.ORIGEN                 ||'|'||
                                                     CUR.PERIODO                ||'|'||
                                                     CUR.FECHA_CONTABLE         ||'|'||
                                                     CUR.NUMERO_TRANSACCION     ||'|'||
                                                     CUR.FECHA_TRANSACCION      ||'|'||
                                                     CUR.NUMERO_CLIENTE         ||'|'||
                                                     CUR.NOMBRE_CLIENTE         ||'|'||
                                                     CUR.RFC);

            V_CUENTA := V_CUENTA + 1;
         END LOOP;

         IF V_CUENTA > 0 THEN 
            V_INSERTA := FALSE;
         ELSE 
            V_INSERTA := TRUE; 
         END IF;
    END IF;

    IF V_INSERTA = TRUE THEN 
        /*====================CARGA LAS TRANSACCIONES QUE NO REQUIEREN UUID A LA TABLA TEMPORAL====================*/
        OPEN CUR_DATA_RECIBOS;
        LOOP
            FETCH CUR_DATA_RECIBOS
            BULK COLLECT INTO LT_DATA_RECIBOS LIMIT P_ARRAY_SIZE;
            BEGIN
                FORALL I IN 1..LT_DATA_RECIBOS.COUNT

                    INSERT INTO CUST_TT_AR_SLA2_POLIZAS VALUES LT_DATA_RECIBOS(I);

            EXCEPTION WHEN OTHERS THEN
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL INSERTAR RECIBOS EN LA TABLA TEMPORAL');
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('Error Oracle: '||SQLERRM);
                V_ERROR := TRUE;
            END;
        EXIT WHEN CUR_DATA_RECIBOS%NOTFOUND;
        END LOOP;
        CLOSE CUR_DATA_RECIBOS;

        OPEN CUR_DATA_ADJ;
        LOOP
            FETCH CUR_DATA_ADJ
            BULK COLLECT INTO LT_DATA_ADJ LIMIT P_ARRAY_SIZE;

            BEGIN
                FORALL I IN 1..LT_DATA_ADJ.COUNT

                    INSERT INTO CUST_TT_AR_SLA2_POLIZAS VALUES LT_DATA_ADJ(I);

            EXCEPTION WHEN OTHERS THEN
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL INSERTAR AJUSTES EN LA TABLA TEMPORAL');
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('Error Oracle: '||SQLERRM);
                V_ERROR := TRUE;
            END; 
        EXIT WHEN CUR_DATA_ADJ%NOTFOUND;
        END LOOP;
        CLOSE CUR_DATA_ADJ;

        COMMIT;

        IF V_ERROR = FALSE THEN 
            /*====================CARGA LAS POLIZAS DE LA TBALA TEMPORAL A SLA2====================*/        
            BEGIN 
                INSERT INTO CUST_AR_SLA2_POLIZAS
                SELECT * FROM CUST_TT_AR_SLA2_POLIZAS;                         
            EXCEPTION WHEN OTHERS THEN 
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL INSERTAR LAS POLIZAS EN SLA2');
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('Error Oracle: '||SQLERRM);
                V_ERROR := TRUE;
            END;

            IF V_ERROR = FALSE THEN 
                BEGIN 
                    SELECT COUNT(*)
                    INTO V_CUENTA
                    FROM CUST_TT_AR_SLA2_POLIZAS 
                    WHERE UUID IS NOT NULL;
                EXCEPTION WHEN NO_DATA_FOUND THEN 
                    V_CUENTA := 0;
                END;

                V_ESTATUS := 'CARGA';
            ELSE 
                V_ESTATUS := 'ERROR AL INSERTAR AR';
                V_CUENTA := NULL;
            END IF;

            COMMIT;

            DELETE CUST_TT_AR_SLA2_POLIZAS;
            COMMIT;            
        END IF;

        /*      NO SE PUEDE CARGAR VIA DBLINK MEDIANTE UN BULK COLLECT 
        OPEN CUR_DATA_OK;
        LOOP
            FETCH CUR_DATA_OK
            BULK COLLECT INTO LT_DATA_OK LIMIT P_ARRAY_SIZE;
            BEGIN
                FORALL I IN 1..LT_DATA_OK.COUNT

                    INSERT INTO CUST_AR_SLA2_POLIZAS VALUES LT_DATA_OK(I);

            EXCEPTION WHEN OTHERS THEN
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL INSERTAR TRANSACCIONES EN SLA2"');
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG( 'Error Oracle: '||SQLERRM);
                V_ERROR := TRUE;
            END;
        EXIT WHEN CUR_DATA_OK%NOTFOUND;
        END LOOP;
        CLOSE CUR_DATA_OK;
        */
    ELSE 
        V_ESTATUS := 'ERROR FALTAN UUID';
        V_CUENTA := NULL; 
    END IF; 

    /*====================CARGA LA VARIABLES QUE REGRESA EL PROCEDIMIENTO====================*/
    P_CUENTA  := V_CUENTA;
    P_ESTATUS := V_ESTATUS; 
    P_ERROR   := V_ERROR;
END;

PROCEDURE POPULATE_AP (P_PERIODO    IN  VARCHAR2
                                          ,P_EXECUTE_ID IN  NUMBER
                                          ,P_CUENTA     OUT NUMBER
                                          ,P_ESTATUS    OUT VARCHAR2
                                          ,P_ERROR      OUT BOOLEAN) IS 

CURSOR CUR_DATA_INVOICE IS 
        SELECT
                    P_EXECUTE_ID ID_EJECUCION,
                    GJS.USER_JE_SOURCE_NAME ORIGEN,
                    GJC.USER_JE_CATEGORY_NAME CATEGORIA,
                    GJH.PERIOD_NAME PERIODO,
                    GJB.NAME LOTE,
                    GJH.CREATION_DATE FECHA_CONTABLE,
                    GJH.NAME POLIZA,
                    GCC.CODE_COMBINATION_ID,
                    GCC.SEGMENT1,
                    GCC.SEGMENT2,
                    GCC.SEGMENT3,
                    GCC.SEGMENT4,
                    GCC.SEGMENT5,
                    GCC.SEGMENT6,
                    GCC.SEGMENT7,
                    SUBSTR(GJL.DESCRIPTION, 25) DESCRIPCION,
                    XAH.AE_HEADER_ID, 
                    XAL.AE_LINE_NUM,
                    NVL(XAL.ENTERED_DR,0) DEBITO_MON_TRANSACCION,
                    NVL(XAL.ENTERED_CR,0) CREDITO_MON_TRANSACCION,
                    NVL(XAL.ACCOUNTED_DR,0) DEBITO_MON_NACIONAL,
                    NVL(XAL.ACCOUNTED_CR,0) CREDITO_MON_NACIONAL,
                    XAL.CURRENCY_CODE MONEDA,
                    NVL(XAL.CURRENCY_CONVERSION_RATE,1) TIPO_CAMBIO,               
                    AIA.INVOICE_NUM NUMERO_TRANSACCION,
                    XAL.ACCOUNTING_CLASS_CODE CLASE_CUENTA,
                    AIA.INVOICE_DATE FECHA_TRANSACCION,
                    AIA.ATTRIBUTE10 UUID,
                    AIA.VENDOR_ID NUMERO_CLIENTE,
                    APS.VENDOR_NAME NOMBRE_CLIENTE,
                    NVL(APS.NUM_1099,'XXXXXXXXXX') RFC,
                     NULL ATTRIBUTE1,
                                NULL ATTRIBUTE2,
                                NULL ATTRIBUTE3,
                                NULL ATTRIBUTE4,
                                NULL ATTRIBUTE5,
                                NULL ATTRIBUTE6,
                                NULL ATTRIBUTE7,
                                NULL ATTRIBUTE8,
                                NULL ATTRIBUTE9,
                                NULL ATTRIBUTE10,
                                NULL ATTRIBUTE11,
                                NULL ATTRIBUTE12,
                                NULL ATTRIBUTE13,
                                NULL ATTRIBUTE14,
                                NULL ATTRIBUTE15,
                                NULL ATTRIBUTE16,
                                NULL ATTRIBUTE17,
                                NULL ATTRIBUTE18,
                                NULL ATTRIBUTE19,
                                NULL ATTRIBUTE20,
                                NULL ATTRIBUTE21,
                                NULL ATTRIBUTE22,
                                NULL ATTRIBUTE23,
                                NULL ATTRIBUTE24,
                                AIA.INVOICE_ID,
                                AIA.ORG_ID,
                                GJH.DESCRIPTION,
                                GJH.JE_HEADER_ID HEADER_ID
              FROM GL_JE_BATCHES GJB,
                   GL_JE_HEADERS GJH,
                   GL_JE_LINES GJL,
                   GL_JE_SOURCES_TL GJS,
                   GL_JE_CATEGORIES_TL GJC,
                   GL_CODE_COMBINATIONS GCC,
                   GL_IMPORT_REFERENCES IMP,
                   XLA_AE_LINES XAL,
                   XLA_AE_HEADERS XAH,
                   XLA_EVENTS XE,
                   XLA.XLA_TRANSACTION_ENTITIES XTE,
                   AP_SUPPLIERS APS,
                   AP_INVOICES_ALL AIA      
             WHERE     1 = 1
                   AND GJB.JE_BATCH_ID = GJH.JE_BATCH_ID
                   AND GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
                   AND GJH.JE_SOURCE = GJS.JE_SOURCE_NAME
                   AND GJH.JE_CATEGORY = GJC.JE_CATEGORY_NAME
                   AND GJS.LANGUAGE = USERENV ('LANG')
                   AND GJC.LANGUAGE = USERENV ('LANG')
                   AND GJL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                   AND GJL.JE_HEADER_ID = IMP.JE_HEADER_ID
                   AND GJL.JE_LINE_NUM = IMP.JE_LINE_NUM
                   AND IMP.GL_SL_LINK_ID = XAL.GL_SL_LINK_ID
                   AND IMP.GL_SL_LINK_TABLE = XAL.GL_SL_LINK_TABLE
                   AND XAL.APPLICATION_ID = XAH.APPLICATION_ID
                   AND XAL.AE_HEADER_ID = XAH.AE_HEADER_ID
                   AND XAH.APPLICATION_ID = XE.APPLICATION_ID
                   AND XAH.EVENT_ID = XE.EVENT_ID
                   AND XE.APPLICATION_ID = XTE.APPLICATION_ID
                   AND XTE.APPLICATION_ID = 200
                   AND XE.ENTITY_ID = XTE.ENTITY_ID
                   AND AIA.VENDOR_ID=APS.VENDOR_ID
                   AND XTE.SOURCE_ID_INT_1 = AIA.INVOICE_ID
                   AND GJL.STATUS = 'P'
                   AND GJH.ACTUAL_FLAG = 'A'
                   AND GJH.JE_SOURCE = 'Payables'
                   AND GJH.JE_CATEGORY = 'Purchase Invoices'
                   AND GJH.PERIOD_NAME = P_PERIODO; 

TYPE TT_DATA_INV IS TABLE OF CUR_DATA_INVOICE%ROWTYPE;
LT_DATA_INV   TT_DATA_INV;

CURSOR CUR_DATA_PAYMENT IS 
        SELECT
                    P_EXECUTE_ID ID_EJECUCION,
                    GJS.USER_JE_SOURCE_NAME ORIGEN,
                    GJC.USER_JE_CATEGORY_NAME CATEGORIA,
                    GJH.PERIOD_NAME PERIODO,
                    GJB.NAME LOTE,
                    GJH.CREATION_DATE FECHA_CONTABLE,
                    GJH.NAME POLIZA,
                    GCC.CODE_COMBINATION_ID,
                    GCC.SEGMENT1,
                    GCC.SEGMENT2,
                    GCC.SEGMENT3,
                    GCC.SEGMENT4,
                    GCC.SEGMENT5,
                    GCC.SEGMENT6,
                    GCC.SEGMENT7,
                    SUBSTR(GJL.DESCRIPTION, 25) DESCRIPCION,
                    XAH.AE_HEADER_ID, 
                    XAL.AE_LINE_NUM,
                    NVL(XAL.ENTERED_DR,0) DEBITO_MON_TRANSACCION,
                    NVL(XAL.ENTERED_CR,0) CREDITO_MON_TRANSACCION,
                    NVL(XAL.ACCOUNTED_DR,0) DEBITO_MON_NACIONAL,
                    NVL(XAL.ACCOUNTED_CR,0) CREDITO_MON_NACIONAL,
                    XAL.CURRENCY_CODE MONEDA,
                    NVL(XAL.CURRENCY_CONVERSION_RATE,1) TIPO_CAMBIO,               
                    AIA.CHECK_NUMBER NUMERO_TRANSACCION,
                    XAL.ACCOUNTING_CLASS_CODE CLASE_CUENTA,
                    AIA.cleared_date FECHA_TRANSACCION,
                    1 UUID,
                    AIA.VENDOR_ID NUMERO_CLIENTE,
                    APS.VENDOR_NAME NOMBRE_CLIENTE,
                    NVL(APS.NUM_1099,'XXXXXXXXXX') RFC,
                     NULL ATTRIBUTE1,
                                NULL ATTRIBUTE2,
                                NULL ATTRIBUTE3,
                                NULL ATTRIBUTE4,
                                NULL ATTRIBUTE5,
                                NULL ATTRIBUTE6,
                                NULL ATTRIBUTE7,
                                NULL ATTRIBUTE8,
                                NULL ATTRIBUTE9,
                                NULL ATTRIBUTE10,
                                NULL ATTRIBUTE11,
                                NULL ATTRIBUTE12,
                                NULL ATTRIBUTE13,
                                NULL ATTRIBUTE14,
                                NULL ATTRIBUTE15,
                                NULL ATTRIBUTE16,
                                NULL ATTRIBUTE17,
                                NULL ATTRIBUTE18,
                                NULL ATTRIBUTE19,
                                NULL ATTRIBUTE20,
                                NULL ATTRIBUTE21,
                                NULL ATTRIBUTE22,
                                NULL ATTRIBUTE23,
                                NULL ATTRIBUTE24,
                                aia.CHECK_id INVOICE_ID,
                                aia.org_id ORG_ID,
                                GJH.DESCRIPTION,
                                GJH.JE_HEADER_ID HEADER_ID
              FROM GL_JE_BATCHES GJB,
                   GL_JE_HEADERS GJH,
                   GL_JE_LINES GJL,
                   GL_JE_SOURCES_TL GJS,
                   GL_JE_CATEGORIES_TL GJC,
                   GL_CODE_COMBINATIONS GCC,
                   GL_IMPORT_REFERENCES IMP,
                   XLA_AE_LINES XAL,
                   XLA_AE_HEADERS XAH,
                   XLA_EVENTS XE,
                   XLA.XLA_TRANSACTION_ENTITIES XTE,
                   AP_SUPPLIERS APS,
                   ap_checks_all aia
                  -- AP_INVOICES_ALL AIA      
             WHERE     1 = 1
                   AND GJB.JE_BATCH_ID = GJH.JE_BATCH_ID
                   AND GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
                   AND GJH.JE_SOURCE = GJS.JE_SOURCE_NAME
                   AND GJH.JE_CATEGORY = GJC.JE_CATEGORY_NAME
                   AND GJS.LANGUAGE = USERENV ('LANG')
                   AND GJC.LANGUAGE = USERENV ('LANG')
                   AND GJL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                   AND GJL.JE_HEADER_ID = IMP.JE_HEADER_ID
                   AND GJL.JE_LINE_NUM = IMP.JE_LINE_NUM
                   AND IMP.GL_SL_LINK_ID = XAL.GL_SL_LINK_ID
                   AND IMP.GL_SL_LINK_TABLE = XAL.GL_SL_LINK_TABLE
                   AND XAL.APPLICATION_ID = XAH.APPLICATION_ID
                   AND XAL.AE_HEADER_ID = XAH.AE_HEADER_ID
                   AND XAH.APPLICATION_ID = XE.APPLICATION_ID
                   AND XAH.EVENT_ID = XE.EVENT_ID
                   AND XE.APPLICATION_ID = XTE.APPLICATION_ID
                   AND XTE.APPLICATION_ID = 200
                   AND XE.ENTITY_ID = XTE.ENTITY_ID
                   AND AIA.VENDOR_ID=APS.VENDOR_ID
                   --AND XTE.SOURCE_ID_INT_1 = AIA.INVOICE_ID
                   AND XTE.SOURCE_ID_INT_1 =aia.check_id
                   AND GJL.STATUS = 'P'
                   AND GJH.ACTUAL_FLAG = 'A'
                   AND GJH.JE_SOURCE = 'Payables'
                   AND GJH.JE_CATEGORY = 'Payments'
                   AND GJH.PERIOD_NAME = P_PERIODO; 

TYPE TT_DATA_PAY IS TABLE OF CUR_DATA_PAYMENT%ROWTYPE;
LT_DATA_PAY   TT_DATA_PAY;

P_ARRAY_SIZE    NUMBER  :=100000;
V_VALIDA        BOOLEAN := FALSE;
V_CUENTA        NUMBER  := 0;
V_INSERTA       BOOLEAN := TRUE;
V_ERROR         BOOLEAN := FALSE;
V_ESTATUS       VARCHAR2(100);

BEGIN

    /*====================ELIMINA LA INFORMACION DE LA TABLA TEMPORAL====================*/
    DELETE CUST_TT_AP_SLA2_POLIZAS;
    delete XXGEPP_TT_AP_INVOICES_UUID;
    DELETE XXGEPP_TT_AP_INV_ISUP_UUID;


    /*====================CARGA LAS TRANSACCIOANES QUE REQUIEREN UUID A LA TABLA TEMPORAL====================*/

    OPEN CUR_DATA_INVOICE;
    LOOP
        BEGIN 
            FETCH CUR_DATA_INVOICE
            BULK COLLECT INTO LT_DATA_INV LIMIT P_ARRAY_SIZE;

            FORALL I IN 1..LT_DATA_INV.COUNT
            INSERT INTO CUST_TT_AP_SLA2_POLIZAS VALUES LT_DATA_INV(I);
        EXCEPTION WHEN OTHERS THEN 
            CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL INSERTAR TRANSACCIONES EN LA TABLA TEMPORAL AP');
            CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('Error Oracle: '||SQLERRM);
            V_ERROR := TRUE;
        END;

        EXIT WHEN CUR_DATA_INVOICE%NOTFOUND;
    END LOOP;
    CLOSE CUR_DATA_INVOICE;

    COMMIT;

    IF V_VALIDA = TRUE THEN 
        /*====================VALIDA QUE TODAS LAS TRANSACCIONES QUE DEPENDAN DE UUID LO TENGAN====================*/
        FOR CUR IN (SELECT UNIQUE 
                            ORIGEN,
                            PERIODO,
                            FECHA_CONTABLE,
                            NUMERO_TRANSACCION,
                            FECHA_TRANSACCION,
                            NUMERO_CLIENTE,
                            NOMBRE_CLIENTE,
                            RFC
                    FROM CUST_TT_AP_SLA2_POLIZAS
                    WHERE UUID IS NULL) 
         LOOP
            CUST_GL_POPULATE_SLA2_PKG.MESSAGE_OUTPUT(CUR.ORIGEN                 ||'|'||
                                                     CUR.PERIODO                ||'|'||
                                                     CUR.FECHA_CONTABLE         ||'|'||
                                                     CUR.NUMERO_TRANSACCION     ||'|'||
                                                     CUR.FECHA_TRANSACCION      ||'|'||
                                                     CUR.NUMERO_CLIENTE         ||'|'||
                                                     CUR.NOMBRE_CLIENTE         ||'|'||
                                                     CUR.RFC);

            V_CUENTA := V_CUENTA + 1;
         END LOOP;

         IF V_CUENTA > 0 THEN 
            V_INSERTA := FALSE;
         ELSE 
            V_INSERTA := TRUE; 
         END IF;
    END IF;

    IF V_INSERTA = TRUE THEN 
        /*====================CARGA LAS TRANSACCIONES QUE NO REQUIEREN UUID A LA TABLA TEMPORAL====================*/
        OPEN CUR_DATA_PAYMENT;
        LOOP
            FETCH CUR_DATA_PAYMENT
            BULK COLLECT INTO LT_DATA_PAY LIMIT P_ARRAY_SIZE;
            BEGIN
                FORALL I IN 1..LT_DATA_PAY.COUNT

                    INSERT INTO CUST_TT_AP_SLA2_POLIZAS VALUES LT_DATA_PAY(I);

            EXCEPTION WHEN OTHERS THEN
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL INSERTAR RECIBOS EN LA TABLA TEMPORAL');
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('Error Oracle: '||SQLERRM);
                V_ERROR := TRUE;
            END;
        EXIT WHEN CUR_DATA_PAYMENT%NOTFOUND;
        END LOOP;
        CLOSE CUR_DATA_PAYMENT;

        COMMIT;

        IF V_ERROR = FALSE THEN 
            /*====================CARGA LAS POLIZAS DE LA TBALA TEMPORAL A SLA2====================*/
            ---Agregar el UUID correcto
            -- Solicitud de pago
            INSERT INTO XXGEPP_TT_AP_INVOICES_UUID
            SELECT DISTINCT ai.org_id, ai.invoice_id,ai.attribute4, ai.invoice_num as no_fact, Ap_Invoices_Pkg.Get_Approval_Status (Ai.Invoice_Id,
                                                                         Ai.Invoice_Amount,
                                                                         Ai.Payment_Status_Flag,
                                                                         Ai.Invoice_Type_Lookup_Code) as estatus,Ap_Invoices_Pkg.Get_Posting_Status (Ai.Invoice_Id) as contabilizado, h.attribute8 as uui
            FROM CUST_TT_AP_SLA2_POLIZAS uuai
                     ,ap_invoices_all Ai
                    ,cust_ap_terceros_h h
            where 1=1
            and ai.org_id = uuai.org_id
            and ai.invoice_id = uuai.invoice_id
            and ai.attribute4 =  h.transfer_no
            --and h.transfer_date >= to_date('01-jun-2015','dd-mon-yyyy')
            and h.attribute12 = 'Y'
            and h.status = 'CERRADO';

            DELETE XXGEPP_TT_AP_INVOICES_UUID
            WHERE 1=1
             AND (estatus != 'APPROVED' or contabilizado ='N');
             commit;

             merge into apps.CUST_TT_AP_SLA2_POLIZAS ip
             using (SELECT *
                      FROM XXGEPP_TT_AP_INVOICES_UUID) it
                on ( it.org_id = ip.org_id and it.invoice_id = ip.invoice_id)
                when matched then
                update set ip.UUID = it.UUID;

             -- Facturas iSupplier
             INSERT INTO XXGEPP_TT_AP_INV_ISUP_UUID
                SELECT DISTINCT f.unidad_operativa, f.ap_invoice_id, Ap_Invoices_Pkg.Get_Approval_Status (Ai.Invoice_Id,
                                                                                         Ai.Invoice_Amount,
                                                                                         Ai.Payment_Status_Flag,
                                                                                         Ai.Invoice_Type_Lookup_Code) as estatus,Ap_Invoices_Pkg.Get_Posting_Status (Ai.Invoice_Id) as contabilizado,fxml.folio_fiscal
                FROM CARGAFACTURASXML fxml
                        ,XXPOS_ACTFACTURA f
                        ,ap_invoices_all ai
                        ,CUST_TT_AP_SLA2_POLIZAS tai
                        ,ap.AP_SUPPLIERS ASUP
                WHERE 1=1
                AND ASUP.VENDOR_ID = AI.VENDOR_ID
                and ai.org_id = tai.org_id
                and ai.invoice_id = tai.invoice_id
                and (FOLIO_FISCAL, ID_CARGA_XML, asup.segment1, ai.org_id) IN (
                                                                                select FOLIO_FISCAL, MAX(ID_CARGA_XML),NUMERO_PROVEEDOR,UNIDAD_OPERATIVA
                                                                                from apps.CARGAFACTURASXML
                                                                                where 1=1
                                                                                --AND folio_fiscal = '4FF1E968-0108-4308-8C07-45920CF0AD6A'
                                                                                GROUP BY FOLIO_FISCAL,NUMERO_PROVEEDOR,UNIDAD_OPERATIVA)
                and f.no_fact_new = fxml.serie_factura || fxml.folio_factura
                and f.ap_invoice_id = ai.invoice_id
                and f.unidad_operativa = fxml.unidad_operativa;

            DELETE XXGEPP_TT_AP_INV_ISUP_UUID
            WHERE 1=1
             AND (estatus != 'APPROVED' or contabilizado ='N');

             commit;

             merge into apps.CUST_TT_AP_SLA2_POLIZAS ip
             using (SELECT *
                      FROM XXGEPP_TT_AP_INV_ISUP_UUID) it
                on ( it.org_id = ip.org_id and it.invoice_id = ip.invoice_id)
                when matched then
                update set ip.UUID = it.UUID;


            BEGIN 
                INSERT INTO CUST_AP_SLA2_POLIZAS
                SELECT * FROM CUST_TT_AP_SLA2_POLIZAS;                         
            EXCEPTION WHEN OTHERS THEN 
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL INSERTAR LAS POLIZAS EN SLA2');
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('Error Oracle: '||SQLERRM);
                V_ERROR := TRUE;
            END;

            IF V_ERROR = FALSE THEN 
                BEGIN 
                    SELECT COUNT(*)
                    INTO V_CUENTA
                    FROM CUST_TT_AP_SLA2_POLIZAS 
                    WHERE UUID IS NOT NULL;
                EXCEPTION WHEN NO_DATA_FOUND THEN 
                    V_CUENTA := 0;
                END;

                V_ESTATUS := 'CARGA';
            ELSE 
                V_ESTATUS := 'ERROR AL INSERTAR AR';
                V_CUENTA := NULL;
            END IF;

            COMMIT;

        END IF;

    ELSE 
        V_ESTATUS := 'ERROR FALTAN UUID';
        V_CUENTA := NULL; 
    END IF; 

    /*====================CARGA LA VARIABLES QUE REGRESA EL PROCEDIMIENTO====================*/
    message_log ('V_CUENTA:'||V_CUENTA);
    message_log ('P_CUENTA:'||P_CUENTA);
    P_CUENTA  := V_CUENTA;
    P_ESTATUS := V_ESTATUS; 
    P_ERROR   := V_ERROR;
END;

PROCEDURE POPULATE_GL (P_PERIODO        IN VARCHAR2
                      ,P_EXECUTE_ID     IN  NUMBER
                      ,P_CUENTA         OUT NUMBER
                      ,P_ESTATUS        OUT VARCHAR2
                      ,P_ERROR          OUT BOOLEAN) IS

CURSOR CUR_DATA_SOURCE IS SELECT JE_SOURCE_NAME ORIGEN
                          FROM GL_JE_SOURCES_TL
                          WHERE JE_SOURCE_NAME NOT IN ('Payables','Receivables')
                          AND LANGUAGE = USERENV('LANG')
                          ORDER BY 1; 

CURSOR CUR_DATA_COMP IS  SELECT B.FLEX_VALUE COMPAÑIA
                          FROM FND_FLEX_VALUE_SETS FVS
                              ,FND_FLEX_VALUES B
                          WHERE 1 = 1
                          AND FVS.FLEX_VALUE_SET_ID = B.FLEX_VALUE_SET_ID
                          AND FVS.FLEX_VALUE_SET_NAME LIKE 'GEPP_GL_CIA'                          
                          ORDER BY 1;
V_LANG      VARCHAR2(10) := USERENV('LANG');
V_ERROR     BOOLEAN := FALSE;
V_CUENTA    NUMBER;
V_ESTATUS   VARCHAR2(100); 
BEGIN 
    FOR CUR_COMP IN CUR_DATA_COMP LOOP
        FOR CUR_SOURCE IN CUR_DATA_SOURCE LOOP
            BEGIN
                INSERT INTO CUST_GL_SLA2_POLIZAS
                SELECT  /*+ INDEX (GJH  GL_JE_HEADERS_N2) 
                           INDEX (GJS GL_JE_SOURCES_TL_U1)
                           INDEX (GCC GL_CODE_COMBINATIONS_N1)*/
                        P_EXECUTE_ID,
                        GJS.USER_JE_SOURCE_NAME ORIGEN,
                        GJC.USER_JE_CATEGORY_NAME CATEGORIA,
                        GJH.PERIOD_NAME PERIODO,
                        GJB.NAME LOTE,
                        GJH.CREATION_DATE FECHA_CONTABLE,
                        GJH.NAME POLIZA,
                        GJH.CURRENCY_CODE MONEDA,
                        GJL.STATUS,
                        GJL.JE_LINE_NUM NUMERO_LINEA,
                        GCC.CODE_COMBINATION_ID,
                        GCC.SEGMENT1,
                        GCC.SEGMENT2,
                        GCC.SEGMENT3,
                        GCC.SEGMENT4,
                        GCC.SEGMENT5,
                        GCC.SEGMENT6,
                        GCC.SEGMENT7,
                        GJL.ENTERED_DR MONEDA_OTROS_DR,
                        GJL.ENTERED_CR MONEDA_OTROS_CR,
                        GJL.ACCOUNTED_DR MONEDA_NACIONAL_DR,
                        GJL.ACCOUNTED_CR MONEDA_NACIONAL_CR,
                        SUBSTR(GJL.DESCRIPTION, 25) DESCRIPCION,
                        GJH.CURRENCY_CONVERSION_RATE TIPO_CAMBIO,
                        NULL ATTRIBUTE1,
                        NULL ATTRIBUTE2,
                        NULL ATTRIBUTE3,
                        NULL ATTRIBUTE4,
                        NULL ATTRIBUTE5,
                        NULL ATTRIBUTE6,
                        NULL ATTRIBUTE7,
                        NULL ATTRIBUTE8,
                        NULL ATTRIBUTE9,
                        NULL ATTRIBUTE10,
                        NULL ATTRIBUTE11,
                        NULL ATTRIBUTE12,
                        NULL ATTRIBUTE13,
                        NULL ATTRIBUTE14,
                        NULL ATTRIBUTE15,
                        NULL ATTRIBUTE16,
                        NULL ATTRIBUTE17,
                        NULL ATTRIBUTE18,
                        NULL ATTRIBUTE19,
                        NULL ATTRIBUTE20,
                        NULL ATTRIBUTE21,
                        NULL ATTRIBUTE22,
                        NULL ATTRIBUTE23,
                        NULL ATTRIBUTE24,
                        GJH.DESCRIPTION,
                        GJH.JE_HEADER_ID
                FROM 
                        GL_JE_BATCHES GJB,
                        GL_JE_HEADERS GJH,
                        GL_JE_LINES GJL,
                        GL_JE_SOURCES_TL GJS,
                        GL_JE_CATEGORIES_TL GJC,
                        GL_CODE_COMBINATIONS GCC--,
                        --GL_IMPORT_REFERENCES IMP
                WHERE 1 = 1
                AND GJB.JE_BATCH_ID = GJH.JE_BATCH_ID
                AND GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
                AND GJH.JE_SOURCE = GJS.JE_SOURCE_NAME
                AND GJH.JE_CATEGORY = GJC.JE_CATEGORY_NAME
                AND GJS.LANGUAGE = TRIM(V_LANG)--USERENV('LANG') --LA FUNCION NO ES SOPORTADA POR DBLINK
                AND GJC.LANGUAGE = TRIM(V_LANG)--USERENV('LANG') --LA FUNCION NO ES SOPORTADA POR DBLINK
                AND GJL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                --AND GJL.JE_HEADER_ID = IMP.JE_HEADER_ID
                --AND GJL.JE_LINE_NUM = IMP.JE_LINE_NUM
                AND GJL.STATUS||'' = 'P'
                AND GJH.ACTUAL_FLAG = 'A'
                AND GJH.CURRENCY_CODE != 'STAT'
                AND GCC.SEGMENT1 = CUR_COMP.COMPAÑIA
                AND GJH.JE_SOURCE = CUR_SOURCE.ORIGEN
                AND GJH.PERIOD_NAME = P_PERIODO;
            EXCEPTION WHEN OTHERS THEN 
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL INSERTAR LAS POLIZAS DE DIARIO EN SLA2');
--                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('COMPAÑIA: '||CUR_COMP.COMPAÑIA|| ' SOURCE: '||CUR_SOURCE.ORIGEN);
                CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR ORACLE: '||SQLERRM);
                V_ERROR := TRUE;
            END; 

            IF V_ERROR = TRUE THEN 
                V_ESTATUS := 'ERROR AL INSERTAR EN SLA2';
            ELSE
                V_ESTATUS := 'CARGA';
            END IF; 

        END LOOP;
    END LOOP;

    IF V_ERROR = FALSE THEN 
        BEGIN 

            SELECT COUNT(*) 
            INTO V_CUENTA
            FROM CUST_GL_SLA2_POLIZAS
            WHERE ID_EJECUCION = P_EXECUTE_ID;

        EXCEPTION WHEN NO_DATA_FOUND THEN 
            V_CUENTA := 0;
        END;

        COMMIT;
    ELSE 
        V_CUENTA := NULL; 
    END IF;

    P_CUENTA    := V_CUENTA;
    P_ESTATUS   := V_ESTATUS;
    P_ERROR     := V_ERROR;
END;

PROCEDURE POPULATE_BLANAZA (P_PERIODO        IN VARCHAR2 --GL_PERIODS.PERIOD_NAME%TYPE);
                                                   ,P_EXECUTE_ID     IN  NUMBER
                                                   ,P_CUENTA         OUT NUMBER
                                                   ,P_ESTATUS        OUT VARCHAR2
                                                   ,P_ERROR          OUT BOOLEAN) IS     


V_ERROR     BOOLEAN := FALSE;
V_CUENTA    NUMBER;
V_ESTATUS   VARCHAR2(100); 
BEGIN 
    BEGIN
        INSERT INTO CUST_GL_SLA2_BALANCE 
                SELECT
                P_EXECUTE_ID 
                ,GL.CODE_COMBINATION_ID
                ,GL.PERIOD_NAME PERIODO
                ,GL.CURRENCY_CODE TIPO_MONEDA
                ,GL.PERIOD_NET_DR SALDO_PERIODO_DR
                ,GL.PERIOD_NET_CR SALDO_PERIODO_CR
                ,GL.BEGIN_BALANCE_DR SALDO_INICIO_DR
                ,GL.BEGIN_BALANCE_CR SALDO_INICIO_CR
                ,GL.PERIOD_NET_DR_BEQ SALDO_PERIODO_DR_MXN
                ,GL.PERIOD_NET_CR_BEQ SALDO_PERIODO_CR_MXN
                ,GL.BEGIN_BALANCE_DR_BEQ SALDO_INICIAL_DR_MXN
                ,GL.BEGIN_BALANCE_CR_BEQ SALDO_INICIAL_CR_MXN
                ,NULL ATTRIBUTE1
                ,NULL ATTRIBUTE2
                ,NULL ATTRIBUTE3
                ,NULL ATTRIBUTE4
                ,NULL ATTRIBUTE5
                ,NULL ATTRIBUTE6
                ,NULL ATTRIBUTE7
                ,NULL ATTRIBUTE8
                ,NULL ATTRIBUTE9
                ,NULL ATTRIBUTE10
                ,NULL ATTRIBUTE11
                ,NULL ATTRIBUTE12
                ,NULL ATTRIBUTE13
                ,NULL ATTRIBUTE14
                ,NULL ATTRIBUTE15
                ,NULL ATTRIBUTE16
                ,NULL ATTRIBUTE17
                ,NULL ATTRIBUTE18
                ,NULL ATTRIBUTE19
                ,NULL ATTRIBUTE20
                ,NULL ATTRIBUTE21
                ,NULL ATTRIBUTE22
                ,NULL ATTRIBUTE23
                ,NULL ATTRIBUTE24
        FROM GL_BALANCES GL
        WHERE 1=1
            AND GL.PERIOD_NAME = P_PERIODO
            AND GL.ACTUAL_FLAG = 'A';
    EXCEPTION WHEN OTHERS THEN 
    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL INSERTAR LA GL_BALANCE EN SLA2');
    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR ORACLE: '||SQLERRM);
    V_ERROR := TRUE;
    END;          

            IF V_ERROR = TRUE THEN 
                V_ESTATUS := 'ERROR AL INSERTAR EN SLA2';
            ELSE
                V_ESTATUS := 'CARGA';
            END IF; 


    IF V_ERROR = FALSE THEN 
        BEGIN 
            SELECT COUNT(*) 
            INTO V_CUENTA
            FROM CUST_GL_SLA2_BALANCE
            WHERE ID_EJECUCION = P_EXECUTE_ID;

        EXCEPTION WHEN NO_DATA_FOUND THEN 
            V_CUENTA := 0;
        END;

        COMMIT;
    ELSE 
        V_CUENTA := NULL; 
    END IF;

    P_CUENTA    := V_CUENTA;
    P_ESTATUS   := V_ESTATUS;
    P_ERROR     := V_ERROR;

EXCEPTION WHEN OTHERS THEN 
    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL INSERTAR LA GL_BALANCE EN SLA2, POPULATE_BLANAZA');
    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR ORACLE: '||SQLERRM);
    V_ERROR := TRUE;
END; 



PROCEDURE POLULATE_CATALOG_ACCOUNTS(ERRBUF             OUT VARCHAR2
                                   ,RETCODE            OUT NUMBER
                                   ,P_VERSION_ID       IN  NUMBER) IS 

V_DESCRIPCION       VARCHAR2(240);
V_USER              VARCHAR2(100); 
V_FECHA_CREACION    DATE;
V_ERROR             BOOLEAN := FALSE;
V_COUNT             NUMBER;
V_BODY              VARCHAR2(2000);
V_USER_EXE          VARCHAR2(100);
V_RESP              VARCHAR2(1000);
V_RECIPIENT         VARCHAR2(4000) := --'aromero@multisolutions.com.mx';
                                     'fernando.barrera@gepp.com
                                     ;claudia.perezmorales@gepp.com
                                     ;mario.mota@gepp.com
                                     ;gabriela.beltran@gepp.com
                                     ;angel.martinez@gepp.com
                                     ;juanjose.torres@gepp.com
                                     ;fausto.gomez@gepp.com;';
V_CC                VARCHAR2(4000) := 'jonathan.millan@gepp.com
                                      ;carloseduardo.davila@gepp.com;';

BEGIN 

    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('====================PARAMETROS====================');
    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('P_VERSION_ID: '||P_VERSION_ID); 
    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('====================PARAMETROS====================');

    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_OUTPUT('SE ELIMINA EL CATALOGO ANTERIOR'); 

    BEGIN
        DELETE FROM CUST_EA_CATALOGO_CUENTAS_SAT; 
    EXCEPTION WHEN OTHERS THEN 
        CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL ELIMINAR LOS REGISTROS DE CUST_EA_CATALOGO_CUENTAS_SAT');
    END;

    BEGIN 
        SELECT CELV.DESCRIPCION
              ,FU.USER_NAME
              ,CELV.CREATION_DATE 
        INTO V_DESCRIPCION
            ,V_USER
            ,V_FECHA_CREACION
        FROM CUST_EA_LOAD_VERSION CELV
            ,FND_USER   FU
        WHERE CELV.VERSION_ID = P_VERSION_ID
        AND  FU.USER_ID = CELV.CREATED_BY;

    EXCEPTION WHEN NO_DATA_FOUND THEN 
        CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL EXTRAER LA INFROMACION DE LA VERSION DEL CATALOGO');
    END;

    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_OUTPUT('COMIENZA LA CARGA DEL CATALOGO'); 
    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_OUTPUT('VERSION: '||P_VERSION_ID);
    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_OUTPUT('DESCRIPCION: '||V_DESCRIPCION);
    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_OUTPUT('USUARIO: '||V_USER);
    CUST_GL_POPULATE_SLA2_PKG.MESSAGE_OUTPUT('FECHA CREACION: '||V_FECHA_CREACION);


    BEGIN 
        INSERT INTO CUST_EA_CATALOGO_CUENTAS_SAT
        SELECT * 
        FROM CUST_EA_CATALOGO_CUENTAS_SAT
        WHERE CCS_VERSION_ID = P_VERSION_ID;
    EXCEPTION WHEN OTHERS THEN 
        CUST_GL_POPULATE_SLA2_PKG.MESSAGE_LOG('ERROR AL INSERTAR EN CUST_EA_CATALOGO_CUENTAS_SAT');
        V_ERROR := TRUE;
    END;

    IF V_ERROR = TRUE THEN 
        CUST_GL_POPULATE_SLA2_PKG.MESSAGE_OUTPUT('OCURRIO UN ERROR AL INSERTAR EL NUEVO CATALOGO');
    ELSE 
        CUST_GL_POPULATE_SLA2_PKG.MESSAGE_OUTPUT('LA CARGA FUE EXITOSA'); 

        SELECT COUNT(*)
        INTO V_COUNT
        FROM CUST_EA_CATALOGO_CUENTAS_SAT
        WHERE CCS_VERSION_ID = P_VERSION_ID;

        CUST_GL_POPULATE_SLA2_PKG.MESSAGE_OUTPUT('SE CARGARON '||V_COUNT||' CUENTAS');

        COMMIT;
    END IF;

     BEGIN
        SELECT NVL(USER_NAME,'SIN USUARIO') 
        INTO V_USER_EXE
        FROM FND_USER 
        WHERE USER_ID = FND_PROFILE.VALUE('USER_ID');
    EXCEPTION WHEN NO_DATA_FOUND THEN
        V_USER_EXE := 'PRUEBA';
    END;

    BEGIN 
        SELECT RESPONSIBILITY_NAME
        INTO V_RESP
        FROM FND_RESPONSIBILITY_TL 
        WHERE RESPONSIBILITY_ID = FND_PROFILE.VALUE('RESP_ID')
        AND LANGUAGE = USERENV('LANG');
    EXCEPTION WHEN NO_DATA_FOUND THEN 
        V_RESP := 'PRUEBA'; 
    END; 

    V_BODY := 'Notificación de Carga del Catálogo para la Contabilidad Electrónica en SLA2<br><br>';
    V_BODY := V_BODY||'====================DATOS DE LA VERSION CARGADA====================<br>';
    V_BODY := V_BODY||'Versión Cargada:         '||P_VERSION_ID||'<br>';
    V_BODY := V_BODY||'Descripción:             '||V_DESCRIPCION||'<br>';
    V_BODY := V_BODY||'Usuario de Creación:     '||V_USER||'<br>';
    V_BODY := V_BODY||'Fecha de Creación:       '||V_FECHA_CREACION||'<br><br>';
    V_BODY := V_BODY||'====================DATOS DE LA EJECUCION====================<br>';
    V_BODY := V_BODY||'Usuario de Ejecución:    '||V_USER_EXE||'<br>';
    V_BODY := V_BODY||'Fecha Ejecución:         '||TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MM:SS')||'<br>';
    V_BODY := V_BODY||'Responsabilidad:         '||V_RESP||'<br>';
    V_BODY := V_BODY||'Cuentas Cargadas:        '||V_COUNT||'<br><br>';


    DECLARE
        PO_ERR_MSG VARCHAR2(1000);
    BEGIN
            CUST_MAIL.SEND_EMAIL(P_DIRECTORY    => 'U05_CARGAS_OPM_EDI_GATORADE_H'
                                ,P_SENDER       => 'oracle@gepp.com'
                                ,P_RECIPIENT    => V_RECIPIENT
                                ,P_CC           => V_CC
                                ,P_BCC          => NULL
                                ,P_SUBJECT      => 'Carga del Catálogo para la Contabilidad Electrónica en SLA2'
                                ,P_BODY         => V_BODY
                                ,P_ERROR        => PO_ERR_MSG);

            CUST_GL_POPULATE_SLA2_PKG.MESSAGE_OUTPUT('MESSAGE ERROR: '||PO_ERR_MSG); 
    END;

END;

END CUST_GL_POPULATE_SLA2_PKG;