CREATE OR REPLACE PACKAGE BODY "APPS"."CUST_SLA_AR_SOURCE_PKG" 
    AS

    PROCEDURE l (p_in_msg IN VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE (p_in_msg);
        fnd_file.put_line (fnd_file.LOG, p_in_msg);
    END l;

    PROCEDURE MSJOUT (p_in_message IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.output, p_in_message);
    END MSJOUT;


   procedure CUST_SLA_AR_VIEWM
              AS

           V_E_ORGID VARCHAR2(500);
           V_E_SEGMENT1 VARCHAR2(500);
           V_E_VIEW_APP_ID VARCHAR2(500);
           V_E_LOOKUP VARCHAR2(500);
           V_E_TERRITORY VARCHAR2(500);
           V_E_ESTIMULO VARCHAR2(500);
           V_E_LAST_UPD VARCHAR2(500);


           V_T_ORGID VARCHAR2(500);
           V_T_CUST VARCHAR2(500);
           V_T_ATTRI VARCHAR2(500);
           V_T_STAT VARCHAR2(500);
           V_T_LAST VARCHAR2(500);

               BEGIN

                        --VISTA MATERIALIZADA DE ESTIMULO

            --            MATERIALIZED VIEW XXAR_SLA_ESTIMULO_VM
            --            REFRESH FORCE ON DEMAND
            --            START WITH SYSDATE NEXT SYSDATE + 1/1440
            --            AS
            --

                        SELECT TO_NUMBER (
                                           SUBSTR (LOOKUP_CODE, 1, INSTR (LOOKUP_CODE, '-') - 1))
                                           ORG_ID    --DISTINCT DECODE (ENABLED_FLAG, 'Y', 'SI', 'NO')
                                                 ,
                                        TO_NUMBER (
                                           SUBSTR (LOOKUP_CODE,
                                                   INSTR (LOOKUP_CODE, '-') + 1,
                                                   LENGTH (LOOKUP_CODE)))
                                           segment1,
                                        VIEW_APPLICATION_ID,
                                        LOOKUP_TYPE,
                                        territory_code,
                                        DECODE (ENABLED_FLAG, 'Y', 'SI', 'NO') ESTIMULO_FISCAL
                                        ,sysdate last_update_date
                          INTO V_E_ORGID,V_E_SEGMENT1,V_E_VIEW_APP_ID,V_E_LOOKUP,V_E_TERRITORY,V_E_ESTIMULO,V_E_LAST_UPD
                                   FROM FND_LOOKUP_VALUES_VL
                                  WHERE     (   NVL ('', territory_code) = territory_code
                                             OR territory_code IS NULL)
                                        AND lookup_type = 'CUST_ART_ESTIMULO_FISCAL'
                                        AND (LOOKUP_TYPE LIKE 'CUST_ART_ESTIMULO_FISCAL')
                                        AND (VIEW_APPLICATION_ID = 222);




                        --   VISTA MATERIALIZADA DE TIPO DE CLIENTE

            --                            CREATE   MATERIALIZED VIEW XXAR_SLA_TIPO_CLIENTE_VM
            --                        REFRESH FORCE ON DEMAND
            --                        START WITH SYSDATE NEXT SYSDATE + (1/1440)*10
            --                        AS
                                    SELECT /*+INDEX(HCAS HZ_CUST_ACCT_SITES_U2)*/
                                                    UNIQUE hcas.org_id,
                                                           rc.customer_number,
                                                           HCAS.ATTRIBUTE6,
                                                           hcas.status
                                                           ,sysdate last_update_date
                                    INTO V_T_ORGID,V_T_CUST,V_T_ATTRI,V_T_STAT,V_T_LAST
                                               FROM ar.hz_cust_acct_sites_all hcas, apps.ra_customers rc
                                              WHERE     1 = 1
                                                    --AND hcas.org_id = 85
                                                    AND hcas.status = 'A'
                                                    AND HCAS.ATTRIBUTE6 IN ('TERCEROEXP',
                                                                            'ASOCIADA',
                                                                            'ASOCIADOEXP',
                                                                            'FRANQUICIADORA') --MANEJAR EN UNA LISTA DE VALORES
                                                    AND rc.customer_id = hcas.cust_account_id
                                                    AND rc.status = 'A';


                        -- QUERY PARA VER ECONTENIDO DE LA VISTA MATERIALIZADA

            --            SELECT *
            --            FROM XXAR_SLA_TIPO_CLIENTE_VM;



                        -- BLOQUE PARA EJECUTAR DE MANERA MANUAL LA VISTA MATERIALIZADA


            --            BEGIN
            --            DBMS_MVIEW.REFRESH ('XXAR_SLA_TIPO_CLIENTE_VM');
            --            END;


                        -- QUERY CON FUNCIONES CAMBIADAS






                END;


    FUNCTION get_estimulo_fiscal (p_org_id              IN NUMBER,
                                 p_inventory_item_id   IN VARCHAR2)
                  RETURN VARCHAR2
               IS
                  v_estimulo_fis   VARCHAR2 (35);
               BEGIN
                  --  ALTER SESSION SET NLS_LANGUAGE = 'AMERICAN';
                  /*
                  EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''AMERICAN'' ';

                    SELECT DISTINCT DECODE (ENABLED_FLAG, 'Y', 'SI', 'NO')
                      INTO v_estimulo_fis
                      FROM FND_LOOKUP_VALUES_VL
                     WHERE (NVL ('', territory_code) = territory_code
                            OR territory_code IS NULL)
                           AND lookup_type = 'CUST_ART_ESTIMULO_FISCAL'
                           AND (LOOKUP_TYPE LIKE 'CUST_ART_ESTIMULO_FISCAL')
                           AND (VIEW_APPLICATION_ID = 222)
                           AND SUBSTR (LOOKUP_CODE, 1, INSTR (LOOKUP_CODE, '-') - 1) =
                                  p_org_id
                           AND (SECURITY_GROUP_ID = 0)
                           AND SUBSTR (LOOKUP_CODE,
                                       INSTR (LOOKUP_CODE, '-') + 1,
                                       LENGTH (LOOKUP_CODE)) IN
                                  (p_inventory_item_id);
                  */
                       SELECT UNIQUE ESTIMULO_FISCAL
                        INTO v_estimulo_fis
                        FROM XXAR_SLA_ESTIMULO_VM
                       WHERE     1 = 1
                             AND ORG_ID = p_org_id
                             AND SEGMENT1 = p_inventory_item_id;


                  RETURN v_estimulo_fis;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     RETURN 'NO';
               END get_estimulo_fiscal;


       FUNCTION TIPO_CLIENTE (P_NUMERO_CLIENTE NUMBER)
                  RETURN VARCHAR2
               AS
                  V_TIPO_CLIENTE   VARCHAR2 (100);
               BEGIN
                        SELECT UNIQUE ATTRIBUTE6 AS TIPO_CLIENTE
                        INTO V_TIPO_CLIENTE
                        FROM APPS.XXAR_SLA_TIPO_CLIENTE_VM
                       WHERE CUSTOMER_NUMBER = P_NUMERO_CLIENTE;

                  RETURN V_TIPO_CLIENTE;
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     RETURN NULL;
                  WHEN OTHERS
                  THEN
                     RETURN NULL;
               END TIPO_CLIENTE;

          FUNCTION get_org_value (p_org_id IN NUMBER)
                  RETURN VARCHAR2
               IS
                  v_org_code   VARCHAR2 (35);
               BEGIN
                  SELECT A3.ATTRIBUTE15
                    INTO v_org_code
                    FROM hr_all_organization_units A3
                   WHERE A3.ORGANIZATION_ID = TO_NUMBER (p_org_id);

                  RETURN v_org_code;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     RETURN NULL;
               END get_org_value;



        PROCEDURE CUST_SLAR_AR_QUERY

        AS
            V_CUSTOMER_TRX_ID NUMBER;
            V_ATTRIBUTE15 VARCHAR2(100);
            V_CUST_TRX_L VARCHAR2(100);
            V_TRX_NUMBER VARCHAR2(100);
            V_AMOUNT_DUE VARCHAR2(100);
            V_NO_LINE VARCHAR2(100);
            V_INVENTORY_ITEM VARCHAR2(100);
            V_ACCOUNT_CLASS VARCHAR2(100);
            V_MONTO VARCHAR2(100);
            V_CODE_COMBI VARCHAR2(100);
            V_SEGMENT1 VARCHAR2(100);
            V_SEGMENT2 VARCHAR2(100);
            V_SEGMENT3 VARCHAR2(100);
            V_SEGMENT4 VARCHAR2(100);
            V_SEGMENT5 VARCHAR2(100);
            V_SEGMENT6 VARCHAR2(100);
            V_SEGMENT7 VARCHAR2(100);
            V_NAME VARCHAR2(100);
            V_LINE_TYPE VARCHAR2(100);
            V_ACCOUNT_NUMBER VARCHAR2(100);
            V_SEGMENTO VARCHAR2(100);
            V_ORG_CODE VARCHAR2(100);
            V_ESTIMULO VARCHAR2(100);
            V_IEPS_ENERG VARCHAR2(100);
            V_IEPS_CAL VARCHAR2(100);
            V_IEPS_AZUCAR VARCHAR2(100);
            V_IEPS_EDULCORANTE VARCHAR2(100);
            V_IVA_16 VARCHAR2(100);
            V_IVA_0 VARCHAR2(100);
            V_TIPO_CLIENTE VARCHAR2(100);

        BEGIN

        DBMS_OUTPUT.PUT_LINE('');
                        select  trx1.customer_trx_id
                                ,hro.attribute15
                                ,d1.cust_trx_line_gl_dist_id
                                ,trx1.trx_number
                                ,p1.AMOUNT_DUE_ORIGINAL
                                ,nvl(trxl.LINE_NUMBER,0) as no_lin
                                ,trxl.inventory_item_id
                                ,d1.account_class
                                ,(d1.amount) as monto
                                ,d1.code_combination_id
                                ,gl1.segment1
                                ,gl1.segment2
                                ,gl1.segment3
                                ,gl1.segment4
                                ,gl1.segment5
                                ,gl1.segment6
                                ,gl1.segment7
                                ,hro.name
                                ,trxl.line_type
                               ,rac_bill.account_number
                                ,NVL (UPPER (i.ATTRIBUTE13), 'NO')                SEGMENTO,
                  CUST_SLA_AR_SOURCE_PKG.GET_ORG_VALUE (D1.ORG_ID) ORG_CODE,
                  DECODE (
                     CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                        rac_bill.account_number),
                     'TERCEROEXP', 'NO',
                     NVL (
                        CUST_SLA_AR_SOURCE_PKG.GET_ESTIMULO_FISCAL (
                           D1.ORG_ID,
                           I.SEGMENT1),
                        'NO'))
                     ESTIMULO
                  ,DECODE (
                     CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                        rac_bill.account_number),
                     'TERCEROEXP', 'NO',
                     A7.IEPS_ENERG)
                     IEPS_ENERG,
                  DECODE (
                     CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                        rac_bill.account_number),
                     'TERCEROEXP', 'NO',
                     A7.IEPS_CONT_CALOR)
                     IEPS_CONT_CALOR,
                  DECODE (
                     CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                        rac_bill.account_number),
                     'TERCEROEXP', 'NO',
                     DECODE (A7.IEPS_LITRO, 0, 'NO', 'SI'))
                     AZUCA,
                DECODE (
                     CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                        rac_bill.account_number),
                     'TERCEROEXP', 'NO',
                     DECODE (A7.IEPS_LITRO_ED, 0, 'NO', 'SI'))
                     EDULCORANTE,
                  DECODE (trxl.tax_classification_code,  'INC 0%', 'NO',  'IVA 0%', 'NO',  'SI')
                     IVA_16
                  ,DECODE (
                     DECODE (
                        CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                           rac_bill.account_number),
                        'TERCEROEXP', 'NO',
                        NVL (
                           CUST_SLA_AR_SOURCE_PKG.GET_ESTIMULO_FISCAL (
                              D1.ORG_ID,
                              I.SEGMENT1),
                           'NO')),
                     'SI', 'NO',
                     'NO', DECODE (trxl.tax_classification_code,
                                   'INC 0%', 'SI',
                                   'IVA 0%', 'SI',
                                   'NO'))
                     IVA_0
                  ,CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                     rac_bill.account_number)
                     TIPO_CLIENTE
                    INTO
                    V_CUSTOMER_TRX_ID
                    ,V_ATTRIBUTE15
                    ,V_CUST_TRX_L
                    ,V_TRX_NUMBER
                    ,V_AMOUNT_DUE
                    ,V_NO_LINE
                    ,V_INVENTORY_ITEM
                    ,V_ACCOUNT_CLASS
                    ,V_MONTO
                    ,V_CODE_COMBI
                    ,V_SEGMENT1
                    ,V_SEGMENT2
                    ,V_SEGMENT3
                    ,V_SEGMENT4
                    ,V_SEGMENT5
                    ,V_SEGMENT6
                    ,V_SEGMENT7
                    ,V_NAME
                    ,V_LINE_TYPE
                    ,V_ACCOUNT_NUMBER
                    ,V_SEGMENTO
                    ,V_ORG_CODE
                    ,V_ESTIMULO
                    ,V_IEPS_ENERG
                    ,V_IEPS_CAL
                    ,V_IEPS_AZUCAR
                    ,V_IEPS_EDULCORANTE
                    ,V_IVA_16
                    ,V_IVA_0
                    ,V_TIPO_CLIENTE
                        from ra_customer_trx_all trx1
                                ,ar_payment_schedules_all p1
                                ,ra_cust_trx_line_gl_dist_all d1
                                ,gl_code_combinations gl1
                                ,hr_all_organization_units hro
                                ,ra_customer_trx_lines_all trxl
                                ,mtl_system_items_b i
                                ,XXAR_IEPS a7
                                ,hz_cust_accounts_all rac_bill
                                ,hz_parties rac_bill_party
                        where 1=1
                      -- and trx1.trx_number = 'DE235783'
                       --AND D1.cust_trx_line_gl_dist_id =625227527
                        and trx1.org_id = p1.org_id
                        and trx1.customer_trx_id = p1.customer_trx_id
                        and d1.org_id = trx1.org_id
                        and d1.customer_trx_id = trx1.customer_trx_id
                        and gl1.code_combination_id = d1.code_combination_id
                        and hro.organization_id = trx1.org_id
                        --and d1.amount!=0
                        and d1.org_id = trxl.org_id(+)
                        and d1.customer_trx_id = trxl.customer_trx_id(+)
                        and d1.CUSTOMER_TRX_LINE_ID = trxl.CUSTOMER_TRX_LINE_ID(+)
                        AND i.ORGANIZATION_ID(+) = 91
                        and i.inventory_item_id(+) = trxl.inventory_item_id
                        AND A7.ORG_ID(+) = d1.ORG_ID
                            AND A7.SEGMENT1(+) = i.SEGMENT1
                            AND trx1.bill_to_customer_id = rac_bill.cust_account_id
                    AND rac_bill.party_id = rac_bill_party.party_id
--                        group by trx1.customer_trx_id
--                                ,trx1.trx_number
--                                ,p1.AMOUNT_DUE_ORIGINAL
--                                ,d1.account_class
--                                ,d1.code_combination_id
--                                ,gl1.segment1
--                                ,gl1.segment2
--                                ,gl1.segment3
--                                ,gl1.segment4
--                                ,gl1.segment5
--                                ,gl1.segment6
--                                ,gl1.segment7
--                                ,hro.name
                        order by nvl(trxl.LINE_NUMBER,0);

        END;



         FUNCTION CUST_SLA_AR_SOURCE (
                   p_segment_return NUMBER,
                   p_cust_trx_line_gl_dist_id NUMBER
                   )
                   RETURN VARCHAR2
                IS
                   PRAGMA AUTONOMOUS_TRANSACTION;
                   v_return VARCHAR2(4000);
                   v_type_line_dist varchar2(1000);
                   v_code_combination_id number;

                    V_Customer_Trx_Id Number;
                    V_Cia Varchar2(100);
                    v_Cust_Trx_L Varchar2(100);
                    V_Trx_Number Varchar2(100);
                    V_Amount_Due Varchar2(100);
                    V_No_Line Varchar2(100);
                    V_Inventory_Item Varchar2(100);
                    V_Account_Class Varchar2(100);
                    V_Monto Varchar2(100);
                    V_Code_Combi Varchar2(100);
                    V_Segment1 Varchar2(100);
                    V_Segment2 Varchar2(100);
                    V_Segment3 Varchar2(100);
                    V_Segment4 Varchar2(100);
                    V_Segment5 Varchar2(100);
                    V_Segment6 Varchar2(100);
                    V_Segment7 Varchar2(100);
                    V_Name Varchar2(100);
                    V_Line_Type Varchar2(100);
                    V_Account_Number Varchar2(100);
                    V_Segmento Varchar2(100);
                    V_Org_Code Varchar2(100);
                    V_Estimulo Varchar2(100);
                    V_Ieps_Energ Varchar2(100);
                    V_Ieps_Cal Varchar2(100);
                    V_Ieps_Azucar Varchar2(100);
                    V_Ieps_Edulcorante Varchar2(100);
                    V_Iva_16 Varchar2(100);
                    V_Iva_0 Varchar2(100);
                    V_Excento Varchar2(100);
                    V_Tipo_Cliente Varchar2(100);
                    V_Tipo_TransaccionAR Varchar2(100);
                    V_Codigo_TransaccionAR Varchar2(100);



                    V_Tipo_Transaccion Varchar2(100);
                    V_Item Varchar2(1000);
                    V_Bonificacion VARCHAR2(100);
                    V_Linea_Negocio VARCHAR2(100);
                    v_error number;
                BEGIN
                    v_error := 0;
                    insert into eam_aux
                    select 'SLAAR|'||p_cust_trx_line_gl_dist_id, SYSDATE
                    from dual;

                    select account_class, code_combination_id
                    into v_type_line_dist,v_code_combination_id
                     from RA_CUST_TRX_LINE_GL_DIST_ALL
                    where 1=1
                   and cust_trx_line_gl_dist_id =p_cust_trx_line_gl_dist_id;

                   select decode(p_segment_return,1,SEGMENT1,2,SEGMENT2,3,SEGMENT3,4,SEGMENT4,5,SEGMENT5,6,SEGMENT6,SEGMENT7)
                   into v_return
                   from gl_code_combinations
                   where code_combination_id = v_code_combination_id;

                   dbms_output.put_line('v_type_line_dist:'||v_type_line_dist);

--
                   --IF v_type_line_dist != 'REC' THEN -- REC -> L¿neas de cuentas por cobrar         REV -> L¿neas de ingreso ¿ IEPS    TAX-> L¿neas de impuestos
                            -- Obtiene los datos para lir a revisar la tabla de mapeo
                            begin
                                   select  trx1.customer_trx_id
                                                ,hro.attribute15 as cia
                                                ,d1.cust_trx_line_gl_dist_id
                                                ,trx1.trx_number
                                                ,p1.AMOUNT_DUE_ORIGINAL
                                                ,nvl(trxl.LINE_NUMBER,0) as no_lin
                                                ,trxl.inventory_item_id
                                                ,d1.account_class
                                                ,(d1.amount) as monto
                                                ,d1.code_combination_id
                                                ,gl1.segment1
                                                ,gl1.segment2
                                                ,gl1.segment3
                                                ,gl1.segment4
                                                ,gl1.segment5
                                                ,gl1.segment6
                                                ,gl1.segment7
                                                ,hro.name
                                                ,trxl.line_type
                                               ,rac_bill.account_number
                                                ,NVL (UPPER (i.ATTRIBUTE13), NULL )                SEGMENTO,
                                                  CUST_SLA_AR_SOURCE_PKG.GET_ORG_VALUE (D1.ORG_ID) ORG_CODE,
                                                  DECODE (
                                                     CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                                                        rac_bill.account_number),
                                                     'TERCEROEXP', 'NO',
                                                     NVL (
                                                        CUST_SLA_AR_SOURCE_PKG.GET_ESTIMULO_FISCAL (
                                                           D1.ORG_ID,
                                                           I.SEGMENT1),
                                                        'NO'))
                                                     ESTIMULO
                                                  ,DECODE (
                                                     CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                                                        rac_bill.account_number),
                                                     'TERCEROEXP', 'NO',
                                                     A7.IEPS_ENERG)
                                                     IEPS_ENERG,
                                                  DECODE (
                                                     CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                                                        rac_bill.account_number),
                                                     'TERCEROEXP', 'NO',
                                                     A7.IEPS_CONT_CALOR)
                                                     IEPS_CONT_CALOR,
                                                  DECODE (
                                                     CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                                                        rac_bill.account_number),
                                                     'TERCEROEXP', 'NO',
                                                     DECODE (A7.IEPS_LITRO, 0, 'NO', 'SI'))
                                                     AZUCA,
                                                  DECODE (
                                                     CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                                                        rac_bill.account_number),
                                                     'TERCEROEXP', 'NO',
                                                     DECODE (A7.IEPS_LITRO_ED, 0, 'NO', 'SI'))
                                                     EDULCORANTE,
                                                  DECODE (trxl.tax_classification_code,  'INC 0%', 'NO',  'IVA 0%', 'NO',  'SI')
                                                     IVA_16
                                                  ,DECODE (
                                                     DECODE (
                                                        CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                                                           rac_bill.account_number),
                                                        'TERCEROEXP', 'NO',
                                                        NVL (
                                                           CUST_SLA_AR_SOURCE_PKG.GET_ESTIMULO_FISCAL (
                                                              D1.ORG_ID,
                                                              I.SEGMENT1),
                                                           'NO')),
                                                     'SI', 'NO',
                                                     'NO', DECODE (trxl.tax_classification_code,
                                                                   'INC 0%', 'SI',
                                                                   'IVA 0%', 'SI',
                                                                   'NO'))
                                                     IVA_0
                                                  ,DECODE (trxl.tax_classification_code,  'IVA EXENTO', 'SI', 'NO')
                                                  EXCENTO
                                                  ,CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (
                                                     rac_bill.account_number)
                                                     TIPO_CLIENTE
                                                  ,TT.NAME
                                                  ,TT.TYPE
                                                  ,CASE WHEN d1.account_class ='REC' then
                                                                'CXC'
                                                            WHEN TT.TYPE = 'INV' AND d1.account_class ='REV' AND trxl.description NOT LIKE 'IEPS%' AND d1.amount >0 then
                                                                'INGRESOS'
                                                             WHEN TT.TYPE = 'INV' AND d1.account_class ='REV' AND trxl.description NOT LIKE 'IEPS%' AND d1.amount <0 then
                                                                'DESCUENTO ESPECIAL'
                                                          WHEN d1.account_class ='REV' AND trxl.description LIKE 'IEPS_LT.%' then
                                                                'IEPS'
                                                          WHEN d1.account_class ='REV' AND trxl.description LIKE 'IEPS_LT_ED.%' then
                                                                'IEPS EDULCORANTE'
                                                          WHEN d1.account_class ='TAX' then
                                                                'IVA'
                                                          end Tipo_Transaccion
                                                          ,I.segment1 as item
                                                INTO
                                                                V_Customer_Trx_Id
                                                                ,V_Cia
                                                                ,V_Cust_Trx_L
                                                                ,V_Trx_Number
                                                                ,V_Amount_Due
                                                                ,V_No_Line
                                                                ,V_Inventory_Item
                                                                ,V_Account_Class
                                                                ,V_Monto
                                                                ,V_Code_Combi
                                                                ,V_Segment1
                                                                ,V_Segment2
                                                                ,V_Segment3
                                                                ,V_Segment4
                                                                ,V_Segment5
                                                                ,V_Segment6
                                                                ,V_Segment7
                                                                ,V_Name
                                                                ,V_Line_Type
                                                                ,V_Account_Number
                                                                ,V_Segmento -- SEGMENTOSIO
                                                                ,V_Org_Code
                                                                ,V_Estimulo
                                                                ,V_Ieps_Energ
                                                                ,V_Ieps_Cal
                                                                ,V_Ieps_Azucar
                                                                ,V_Ieps_Edulcorante
                                                                ,V_Iva_16
                                                                ,V_Iva_0
                                                                ,V_Excento
                                                                ,V_Tipo_Cliente
                                                                ,V_Tipo_TransaccionAR
                                                                ,V_Codigo_TransaccionAR
                                                                ,V_Tipo_Transaccion
                                                                ,V_Item
                                                        from ra_customer_trx_all trx1
                                                                ,ar_payment_schedules_all p1
                                                                ,ra_cust_trx_line_gl_dist_all d1
                                                                ,gl_code_combinations gl1
                                                                ,hr_all_organization_units hro
                                                                ,ra_customer_trx_lines_all trxl
                                                                ,mtl_system_items_b i
                                                                ,XXAR_IEPS a7
                                                                ,hz_cust_accounts_all rac_bill
                                                                ,hz_parties rac_bill_party
                                                                ,Ra_Cust_Trx_Types_All Tt
                                                        Where 1=1
                                                       --And Trx1.Trx_Number = 'DE235783'
                                                       AND D1.cust_trx_line_gl_dist_id =p_cust_trx_line_gl_dist_id--625227527
                                                        And Trx1.Org_Id = P1.Org_Id(+)
                                                        And Trx1.Customer_Trx_Id = P1.Customer_Trx_Id(+)
                                                        And Trx1.Org_Id = Tt.Org_Id
                                                        And Trx1.Cust_Trx_Type_Id = Tt.Cust_Trx_Type_Id
                                                        And D1.Org_Id = Trx1.Org_Id
                                                        And D1.Customer_Trx_Id = Trx1.Customer_Trx_Id
                                                        And Gl1.Code_Combination_Id = D1.Code_Combination_Id
                                                        And Hro.Organization_Id = Trx1.Org_Id
                                                        And D1.Org_Id = Trxl.Org_Id(+)
                                                        And D1.Customer_Trx_Id = Trxl.Customer_Trx_Id(+)
                                                        And D1.Customer_Trx_Line_Id = Trxl.Customer_Trx_Line_Id(+)
                                                        And I.Organization_Id(+) = 91
                                                        And I.Inventory_Item_Id(+) = Trxl.Inventory_Item_Id
                                                        And A7.Org_Id(+) = D1.Org_Id
                                                        And A7.Segment1(+) = I.Segment1
                                                        And Trx1.Bill_To_Customer_Id = Rac_Bill.Cust_Account_Id
                                                        And Rac_Bill.Party_Id = Rac_Bill_Party.Party_Id;
                            exception
                                when others then
                                    v_error:=1;
                            end;
                    dbms_output.put_line('v_error:'||v_error);
                    If V_Error = 0 Then
                            If V_Codigo_TransaccionAR = 'INV' Then
                                IF  p_segment_return in (4,5,6) AND v_type_line_dist = 'REC' AND V_Tipo_Transaccion = 'CXC' THEN
                                    -- Obtiene el segmento_sio del primer SKU de la factura para derivar el de la cuenta por cobrar
                                    for cur in ( Select Nvl (Upper (I.Attribute13), Null ) Segmento_Sio
                                                    From Ra_Customer_Trx_Lines_All Trxl
                                                            ,Mtl_System_Items_B I
                                                    Where 1=1
                                                    And Trxl.Customer_Trx_Id = V_Customer_Trx_Id
                                                    And Trxl.Line_Number = 1
                                                    And Trxl.Line_Type='LINE'
                                                    And I.Organization_Id(+) = 91
                                                    And I.Inventory_Item_Id(+) = Trxl.Inventory_Item_Id
                                                    And Rownum = 1)
                                    loop
                                        V_Segmento := cur.Segmento_Sio;
                                    end loop;
                                END IF;

                                IF p_segment_return = 7 AND v_type_line_dist = 'REC' AND V_Tipo_Transaccion = 'CXC' AND V_Tipo_Cliente = 'INTERCOMPANIA' THEN
                                    v_return := LPAD(V_Account_Number,3,'0') ;
                                ELSIF p_segment_return = 7 AND v_type_line_dist = 'REV' AND V_Tipo_Transaccion = 'INGRESOS' AND V_Tipo_Cliente = 'INTERCOMPANIA' THEN
                                    v_return := LPAD(V_Account_Number,3,'0') ;
                                ELSIF p_segment_return !=7  AND V_Tipo_Cliente != 'INTERCOMPANIA' THEN
                                    -- Facturas
                                    V_Bonificacion := NULL; --Revisar de donde se tomara este valor
                                    V_Linea_Negocio := NULL; --Revisar de donde se tomara este valor
                                    dbms_output.put_line('Ingresa a derivacion contable');
                                    v_return := Cust_Sla_Ar_Get_Val(V_Tipo_Transaccion
                                                                                ,p_segment_return
                                                                                ,V_Segmento
                                                                                ,V_Cia
                                                                                ,V_Item
                                                                                ,V_Iva_0
                                                                                ,V_Excento--CASE WHEN V_Iva_0='NO' and V_Iva_16='NO' THEN 'SI' ELSE 'NO' END -- EXCENTO
                                                                                ,V_Iva_16
                                                                                ,V_Estimulo
                                                                                ,V_Ieps_Energ
                                                                                ,V_Ieps_Azucar
                                                                                ,V_Ieps_Edulcorante
                                                                                ,V_Ieps_Cal
                                                                                ,V_Tipo_Cliente
                                                                                ,V_Bonificacion
                                                                                ,V_Linea_Negocio
                                                                                ,null --tipo_pedido_om
                                                                                );
                                         dbms_output.put_line('''' ||V_Tipo_Transaccion||''',');
                                         dbms_output.put_line('''' ||p_segment_return||''',');
                                         dbms_output.put_line('''' ||V_Segmento||''',');

                                         dbms_output.put_line('''' ||V_Cia||''',');
                                         dbms_output.put_line('''' ||V_Item||''',');
                                         dbms_output.put_line('''' ||V_Iva_0||''',');
                                         dbms_output.put_line('''' ||CASE WHEN V_Iva_0='NO' and V_Iva_16='NO' THEN 'SI' ELSE 'NO' END||''',');
                                         dbms_output.put_line('''' ||V_Iva_16||''',');
                                         dbms_output.put_line('''' ||V_Estimulo||''',');
                                         dbms_output.put_line('''' ||V_Ieps_Energ||''',');
                                         dbms_output.put_line('''' ||V_Ieps_Azucar||''',');
                                         dbms_output.put_line('''' ||V_Ieps_Edulcorante||''',');
                                         dbms_output.put_line('''' ||V_Ieps_Cal||''',');
                                         dbms_output.put_line('''' ||V_Tipo_Cliente||''',');
                                         dbms_output.put_line('''' ||V_Bonificacion||''',');
                                         dbms_output.put_line('''' ||V_Linea_Negocio||''',');


                                        dbms_output.put_line('v_return:'||v_return);
                                    END IF;
                            End If;
                    END IF;
                 --end if;

                --
                --   IF  p_segment_return = 5 and v_type_line_dist = 'REC' THEN
                --            v_return := '-666';--'1231';--'1407'
                --    end if;
                --   ELSIF  v_type_line_dist = 'TAX' THEN
                --        v_return := '2306';
                --   ELSE
                --        V_RETURN:='-999';
                --    END IF;
                    COMMIT;
                    RETURN v_return;
                EXCEPTION
                    WHEN OTHERS THEN
                        V_RETURN:='-111';
                        ROLLBACK;
                        RETURN v_return;
                END CUST_SLA_AR_SOURCE;


      FUNCTION XXAR_RETURN_SEGMENT_SLA_AR (
               p_segment_return NUMBER,
               p_cust_trx_line_gl_dist_id NUMBER
               --p_code_combination_id NUMBER
               )
               RETURN VARCHAR2
            
      IS
         v_return VARCHAR2(4000);        
      BEGIN
            -- Call function in XXWEBC to return segment of SLA AR
            v_return := XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.XXAR_RETURN_SEGMENT_SLA_AR(p_segment_return, p_cust_trx_line_gl_dist_id);
            RETURN v_return;
        
      END XXAR_RETURN_SEGMENT_SLA_AR;

      FUNCTION Cust_Sla_Ar_Get_Val ( P_Tipo_Transaccion  Varchar2,
                                                        P_Segmento  Number,
                                                        P_Segmento_Sio  Varchar2,
                                                        P_Cia  Varchar2,
                                                        P_Item  Varchar2,
                                                        P_Iva_0  Varchar2,
                                                        P_Excento  Varchar2,
                                                        P_Iva  Varchar2,
                                                        P_Iva_Estimulo  Varchar2,
                                                        P_Ieps_Energetico  Varchar2,
                                                        P_Ieps_Azucarado  Varchar2,
                                                        P_Ieps_Edulcorante  Varchar2,
                                                        P_Ieps_Calorico  Varchar2,
                                                        P_Tipo_Cliente  Varchar2,
                                                        P_Bonificacion  Varchar2,
                                                        P_Linea_Negocio  Varchar2,
                                                        P_tipo_pedido_om Varchar2)  Return Varchar
        is
             cursor c_get_value is
                     SELECT *
                     FROM (
                     With Tbl_Mapeo As
                                (Select *--DISTINCT TIPO_TRANSACCION,SEGMENTO
                                From Xxar_Mapeo_Lines_Cust_sla
                                Where 1=1
                                )
                            Select Segmento_Sio, Item, Iva_0, Excento, Iva, Iva_Estimulo, Ieps_Energetico, Ieps_Azucarado, Ieps_Calorico, Tipo_Cliente, Bonificacion, Linea_Negocio,Valor, tipo_pedido_om
                                From Tbl_Mapeo
                                where 1=1
                                    AND TIPO_TRANSACCION =P_Tipo_Transaccion
                                    AND SEGMENTO = P_Segmento
                                    and case when SEGMENTO_SIO is null then 1
                                        when SEGMENTO_SIO = P_Segmento_Sio then 1
                                        else null
                                        end
                                        is not null
                                    AND CIA = P_Cia
                                    and case when item is null then 1
                                        when item = P_Item then 1
                                        else null
                                        end
                                        is not null
                                    and case when IVA_0 is null then 1
                                        when IVA_0 = P_Iva_0 then 1
                                        else null
                                        end
                                        is not null
                                    and case when EXCENTO is null then 1
                                        when EXCENTO = P_Excento then 1
                                        else null
                                        end
                                        is not null
                                    and case when IVA is null then 1
                                        when IVA = P_Iva then 1
                                        else null
                                        end
                                        is not null
                                    and case when IVA_ESTIMULO is null then 1
                                        when IVA_ESTIMULO = P_Iva_Estimulo then 1
                                        else null
                                        end
                                        is not null
                                    and case when IEPS_ENERGETICO is null then 1
                                        when IEPS_ENERGETICO = P_Ieps_Energetico then 1
                                        else null
                                        end
                                        is not null
                                    and case when IEPS_AZUCARADO is null then 1
                                        when IEPS_AZUCARADO = P_Ieps_Azucarado then 1
                                        else null
                                        end
                                        is not null
                                    and case when IEPS_CALORICO is null then 1
                                        when IEPS_CALORICO = P_Ieps_Calorico then 1
                                        else null
                                        end
                                        is not null
                                    and case when tipo_cliente is null then 1
                                        when tipo_cliente = P_Tipo_Cliente then 1
                                        else null
                                        end
                                        is not null
                                   /* and case when bonificacion is null then 1
                                        when bonificacion = P_Bonificacion then 1
                                        else null
                                        end
                                        is not null
                                    and case when linea_negocio is null then 1
                                        when linea_negocio = P_Linea_Negocio then 1
                                        else null
                                        end
                                        is not null*/
                                    and case when tipo_pedido_om is null then 1
                                        when tipo_pedido_om = P_tipo_pedido_om then 1
                                        else null
                                        end
                                        is not null
                                    --and rownum=1
                                    Order By Segmento_Sio, Item, Iva_0, Excento, Iva, Iva_Estimulo, Ieps_Energetico, Ieps_Azucarado, Ieps_Calorico, Tipo_Cliente, Bonificacion, Linea_Negocio,tipo_pedido_om) T
                              WHERE 1=1
                              and rownum=1;

            v_return varchar2(100);
        BEGIN
            v_return := '-666';

            FOR cur IN c_get_value
            LOOP
                v_return := cur.valor;
            END LOOP;
           return v_return;
        end Cust_Sla_Ar_Get_Val;

        procedure cust_sla_get_cta(P_Tipo_Transaccion  Varchar2,
                                    P_Segmento_Sio  Varchar2,
                                    P_Cia  Varchar2,
                                    P_Item  Varchar2,
                                    P_Iva_0  Varchar2,
                                    P_Excento  Varchar2,
                                    P_Iva  Varchar2,
                                    P_Iva_Estimulo  Varchar2,
                                    P_Ieps_Energetico  Varchar2,
                                    P_Ieps_Azucarado  Varchar2,
                                    P_Ieps_Edulcorante  Varchar2,
                                    P_Ieps_Calorico  Varchar2,
                                    P_Tipo_Cliente  Varchar2,
                                    P_Bonificacion  Varchar2,
                                    P_Linea_Negocio  Varchar2,
                                    P_tipo_pedido_om Varchar2,
                                    P_Account_Number Varchar2,
                                    o_segment1 out Varchar2,
                                    o_segment2 out Varchar2,
                                    o_segment3 out Varchar2,
                                    o_segment4 out Varchar2,
                                    o_segment5 out Varchar2,
                                    o_segment6 out Varchar2,
                                    o_segment7 out Varchar2,
                                    o_code_combination_id out number
                                    ,p_trace VARCHAR2)
    IS
        v_msj_trace varchar2(4000);
        v_trace_log number:=0;
        v_trace_dbms number:=0;
        v_trace_param number:=0;
        v_trace_cta number:=0;
    BEGIN
            IF INSTR(p_trace,'D')>0 THEN
                v_trace_dbms := 1;
            END IF;
            IF INSTR(p_trace,'L')>0 THEN
                v_trace_log := 1;
            END IF;
            IF INSTR(p_trace,'H')>0 THEN
                v_trace_param := 1;
            END IF;
            IF INSTR(p_trace,'C')>0 THEN
                v_trace_cta := 1;
            END IF;

            v_msj_trace := 'Proceso cust_sla_get_cta';
            if v_trace_dbms > 0 then l(v_msj_trace); end if;
            v_msj_trace := '**--------------------------------**';

            IF v_trace_param > 0 THEN
                v_msj_trace := 'P_Tipo_Transaccion:'||P_Tipo_Transaccion;  l(v_msj_trace);
                v_msj_trace := 'P_Segmento_Sio:'||P_Segmento_Sio;  l(v_msj_trace);
                v_msj_trace := 'P_Cia:'||P_Cia;  l(v_msj_trace);
                v_msj_trace := 'P_Item:'||P_Item;  l(v_msj_trace);
                v_msj_trace := 'P_Iva_0:'||P_Iva_0;  l(v_msj_trace);
                v_msj_trace := 'P_Excento:'||P_Excento;  l(v_msj_trace);
                v_msj_trace := 'P_Iva:'||P_Iva;  l(v_msj_trace);
                v_msj_trace := 'P_Iva_Estimulo:'||P_Iva_Estimulo;  l(v_msj_trace);
                v_msj_trace := 'P_Ieps_Energetico:'||P_Ieps_Energetico;  l(v_msj_trace);
                v_msj_trace := 'P_Ieps_Azucarado:'||P_Ieps_Azucarado;  l(v_msj_trace);
                v_msj_trace := 'P_Ieps_Calorico:'||P_Ieps_Calorico;  l(v_msj_trace);
                v_msj_trace := 'P_Ieps_Edulcorante:'||P_Ieps_Edulcorante;  l(v_msj_trace);
                v_msj_trace := 'P_Tipo_Cliente:'||P_Tipo_Cliente;  l(v_msj_trace);
                v_msj_trace := 'P_Bonificacion:'||P_Bonificacion;  l(v_msj_trace);
                v_msj_trace := 'P_Linea_Negocio:'||P_Linea_Negocio;  l(v_msj_trace);
                v_msj_trace := 'P_tipo_pedido_om:'||P_tipo_pedido_om;  l(v_msj_trace);
                v_msj_trace := 'P_Account_Number:'||P_Account_Number;  l(v_msj_trace);
                v_msj_trace := '**--------------------------------**'; l(v_msj_trace);
            END IF;
            v_msj_trace := 'P_Tipo_Transaccion:<<'||P_Tipo_Transaccion|| '>>';
            if v_trace_dbms > 0 then l(v_msj_trace); end if;


            o_segment1 := P_Cia;
            v_msj_trace := 'S1:'||o_segment1;
            if v_trace_dbms > 0 then l(v_msj_trace); end if;

            o_segment2 := APPS.CUST_SLA_AR_SOURCE_PKG.Cust_Sla_Ar_Get_Val(P_Tipo_Transaccion
                                                                        ,2
                                                                        ,P_Segmento_Sio
                                                                        ,P_Cia
                                                                        ,P_Item
                                                                        ,P_Iva_0
                                                                        ,P_Excento
                                                                        ,P_Iva
                                                                        ,P_Iva_Estimulo
                                                                        ,P_Ieps_Energetico
                                                                        ,P_Ieps_Azucarado
                                                                        ,P_Ieps_Edulcorante
                                                                        ,P_Ieps_Calorico
                                                                        ,P_Tipo_Cliente
                                                                        ,P_Bonificacion
                                                                        ,P_Linea_Negocio
                                                                        ,P_tipo_pedido_om
                                                                        );
                v_msj_trace := 'S2:'||o_segment2;
                if v_trace_dbms > 0 then l(v_msj_trace); end if;

                o_segment3 := APPS.CUST_SLA_AR_SOURCE_PKG.Cust_Sla_Ar_Get_Val(P_Tipo_Transaccion
                                                                        ,3
                                                                        ,P_Segmento_Sio
                                                                        ,P_Cia
                                                                        ,P_Item
                                                                        ,P_Iva_0
                                                                        ,P_Excento
                                                                        ,P_Iva
                                                                        ,P_Iva_Estimulo
                                                                        ,P_Ieps_Energetico
                                                                        ,P_Ieps_Azucarado
                                                                        ,P_Ieps_Edulcorante
                                                                        ,P_Ieps_Calorico
                                                                        ,P_Tipo_Cliente
                                                                        ,P_Bonificacion
                                                                        ,P_Linea_Negocio
                                                                        ,P_tipo_pedido_om
                                                                        );
                v_msj_trace := 'S3:'||o_segment3;
                if v_trace_dbms > 0 then l(v_msj_trace); end if;


                o_segment4 := APPS.CUST_SLA_AR_SOURCE_PKG.Cust_Sla_Ar_Get_Val(P_Tipo_Transaccion
                                                                        ,4
                                                                        ,P_Segmento_Sio
                                                                        ,P_Cia
                                                                        ,P_Item
                                                                        ,P_Iva_0
                                                                        ,P_Excento
                                                                        ,P_Iva
                                                                        ,P_Iva_Estimulo
                                                                        ,P_Ieps_Energetico
                                                                        ,P_Ieps_Azucarado
                                                                        ,P_Ieps_Edulcorante
                                                                        ,P_Ieps_Calorico
                                                                        ,P_Tipo_Cliente
                                                                        ,P_Bonificacion
                                                                        ,P_Linea_Negocio
                                                                        ,P_tipo_pedido_om
                                                                        );
                v_msj_trace := 'S4:'||o_segment4;
                if v_trace_dbms > 0 then l(v_msj_trace); end if;

                o_segment5 := APPS.CUST_SLA_AR_SOURCE_PKG.Cust_Sla_Ar_Get_Val(P_Tipo_Transaccion
                                                                        ,5
                                                                        ,P_Segmento_Sio
                                                                        ,P_Cia
                                                                        ,P_Item
                                                                        ,P_Iva_0
                                                                        ,P_Excento
                                                                        ,P_Iva
                                                                        ,P_Iva_Estimulo
                                                                        ,P_Ieps_Energetico
                                                                        ,P_Ieps_Azucarado
                                                                        ,P_Ieps_Edulcorante
                                                                        ,P_Ieps_Calorico
                                                                        ,P_Tipo_Cliente
                                                                        ,P_Bonificacion
                                                                        ,P_Linea_Negocio
                                                                        ,P_tipo_pedido_om
                                                                        );
                v_msj_trace := 'S5:'||o_segment5;
                if v_trace_dbms > 0 then l(v_msj_trace); end if;

                o_segment6 := APPS.CUST_SLA_AR_SOURCE_PKG.Cust_Sla_Ar_Get_Val(P_Tipo_Transaccion
                                                                        ,6
                                                                        ,P_Segmento_Sio
                                                                        ,P_Cia
                                                                        ,P_Item
                                                                        ,P_Iva_0
                                                                        ,P_Excento
                                                                        ,P_Iva
                                                                        ,P_Iva_Estimulo
                                                                        ,P_Ieps_Energetico
                                                                        ,P_Ieps_Azucarado
                                                                        ,P_Ieps_Edulcorante
                                                                        ,P_Ieps_Calorico
                                                                        ,P_Tipo_Cliente
                                                                        ,P_Bonificacion
                                                                        ,P_Linea_Negocio
                                                                        ,P_tipo_pedido_om
                                                                        );
                v_msj_trace := 'S6:'||o_segment6;
                if v_trace_dbms > 0 then l(v_msj_trace); end if;

                if P_Tipo_Cliente = 'INTERCOMPANIA' then
                    o_segment7 := LPAD(P_Account_Number,3,'0');
                ELSE
                    o_segment7 := '000';
                END IF;
                v_msj_trace := 'S7:'||o_segment7;
                if v_trace_dbms > 0 then l(v_msj_trace); end if;

                BEGIN
                    SELECT CODE_COMBINATION_ID
                    INTO o_code_combination_id
                    FROM GL_CODE_COMBINATIONS
                    WHERE 1=1
                    AND SEGMENT1 = o_segment1
                    AND SEGMENT2 = o_segment2
                    AND SEGMENT3 = o_segment3
                    AND SEGMENT4 = o_segment4
                    AND SEGMENT5 = o_segment5
                    AND SEGMENT6 = o_segment6
                    AND SEGMENT7 = o_segment7;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        o_code_combination_id := 666;
                END;

                v_msj_trace := 'o_code_combination_id:'||o_code_combination_id;
                if v_trace_dbms > 0 then dbms_output.put_line(v_msj_trace); end if;


                IF v_trace_cta > 0 and  v_trace_dbms > 0 THEN
                        v_msj_trace := o_segment1 || '-' ||
                               o_segment2 || '-' ||
                               o_segment3 || '-' ||
                               o_segment4 || '-' ||
                               o_segment5 || '-' ||
                               o_segment6 || '-' ||
                               o_segment7;
                        l(v_msj_trace);
                end if;
    END cust_sla_get_cta;

    procedure cust_sla_set_cta(p_rail ra_interface_lines_all%rowtype,p_trace varchar2, o_err_msj OUT varchar2, o_err_num OUT number)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_interface_distribution_rec   ra_interface_distributions_all%ROWTYPE;

        v_segment1 varchar2(100);
        v_segment2 varchar2(100);
        v_segment3 varchar2(100);
        v_segment4 varchar2(100);
        v_segment5 varchar2(100);
        v_segment6 varchar2(100);
        v_segment7 varchar2(100);
        v_code_combination_id number;
    --    v_Tipo_Transaccion varchar2(100);
    --
    --    v_account_number varchar2(100);
    --    v_tipo_cliente varchar2(100);

        v_amount_cxc number;
        v_cont_cxc number;
    BEGIN
        -- Si existe REV la elimina para volver a generar-- Ingreso

        begin
            v_cont_cxc := 0;
            select count(*)
            into v_cont_cxc
            from ra_interface_distributions_all raid
            where 1=1
            and raid.account_class ='REV'
            and p_rail.INTERFACE_LINE_CONTEXT = raid.INTERFACE_LINE_CONTEXT
            and p_rail.INTERFACE_LINE_ATTRIBUTE1 = raid.INTERFACE_LINE_ATTRIBUTE1
            and p_rail.INTERFACE_LINE_ATTRIBUTE2 = raid.INTERFACE_LINE_ATTRIBUTE2
            and p_rail.INTERFACE_LINE_ATTRIBUTE3 = raid.INTERFACE_LINE_ATTRIBUTE3
            and p_rail.INTERFACE_LINE_ATTRIBUTE4 = raid.INTERFACE_LINE_ATTRIBUTE4
            and p_rail.INTERFACE_LINE_ATTRIBUTE5 = raid.INTERFACE_LINE_ATTRIBUTE5
            and p_rail.INTERFACE_LINE_ATTRIBUTE6 = raid.INTERFACE_LINE_ATTRIBUTE6
            and p_rail.INTERFACE_LINE_ATTRIBUTE7 = raid.INTERFACE_LINE_ATTRIBUTE7
            and p_rail.INTERFACE_LINE_ATTRIBUTE8 = raid.INTERFACE_LINE_ATTRIBUTE8
            and p_rail.INTERFACE_LINE_ATTRIBUTE9 = raid.INTERFACE_LINE_ATTRIBUTE9
            and p_rail.INTERFACE_LINE_ATTRIBUTE10 = raid.INTERFACE_LINE_ATTRIBUTE10
            and p_rail.INTERFACE_LINE_ATTRIBUTE11 = raid.INTERFACE_LINE_ATTRIBUTE11
--            and p_rail.INTERFACE_LINE_ATTRIBUTE12 = raid.INTERFACE_LINE_ATTRIBUTE12
--            and p_rail.INTERFACE_LINE_ATTRIBUTE13 = raid.INTERFACE_LINE_ATTRIBUTE13
--            and p_rail.INTERFACE_LINE_ATTRIBUTE14 = raid.INTERFACE_LINE_ATTRIBUTE14
--            and p_rail.INTERFACE_LINE_ATTRIBUTE15 = raid.INTERFACE_LINE_ATTRIBUTE15
            ;
            IF v_cont_cxc > 0 THEN
                DELETE ra_interface_distributions_all raid
                where 1=1
                and raid.account_class ='REV'
                and p_rail.INTERFACE_LINE_CONTEXT = raid.INTERFACE_LINE_CONTEXT
                and p_rail.INTERFACE_LINE_ATTRIBUTE1 = raid.INTERFACE_LINE_ATTRIBUTE1
                and p_rail.INTERFACE_LINE_ATTRIBUTE2 = raid.INTERFACE_LINE_ATTRIBUTE2
                and p_rail.INTERFACE_LINE_ATTRIBUTE3 = raid.INTERFACE_LINE_ATTRIBUTE3
                and p_rail.INTERFACE_LINE_ATTRIBUTE4 = raid.INTERFACE_LINE_ATTRIBUTE4
                and p_rail.INTERFACE_LINE_ATTRIBUTE5 = raid.INTERFACE_LINE_ATTRIBUTE5
                and p_rail.INTERFACE_LINE_ATTRIBUTE6 = raid.INTERFACE_LINE_ATTRIBUTE6
                and p_rail.INTERFACE_LINE_ATTRIBUTE7 = raid.INTERFACE_LINE_ATTRIBUTE7
                and p_rail.INTERFACE_LINE_ATTRIBUTE8 = raid.INTERFACE_LINE_ATTRIBUTE8
                and p_rail.INTERFACE_LINE_ATTRIBUTE9 = raid.INTERFACE_LINE_ATTRIBUTE9
                and p_rail.INTERFACE_LINE_ATTRIBUTE10 = raid.INTERFACE_LINE_ATTRIBUTE10
                and p_rail.INTERFACE_LINE_ATTRIBUTE11 = raid.INTERFACE_LINE_ATTRIBUTE11
    --            and p_rail.INTERFACE_LINE_ATTRIBUTE12 = raid.INTERFACE_LINE_ATTRIBUTE12
    --            and p_rail.INTERFACE_LINE_ATTRIBUTE13 = raid.INTERFACE_LINE_ATTRIBUTE13
    --            and p_rail.INTERFACE_LINE_ATTRIBUTE14 = raid.INTERFACE_LINE_ATTRIBUTE14
    --            and p_rail.INTERFACE_LINE_ATTRIBUTE15 = raid.INTERFACE_LINE_ATTRIBUTE15
                ;
                COMMIT;
            END IF;
         END;

        -- Se valida si existe tipo REC -- Cuentas por cobrar
        begin
            v_cont_cxc := 0;

            select count(*)
            into v_cont_cxc
            from ra_interface_distributions_all raid
            where 1=1
            and raid.account_class ='REC'
            and p_rail.INTERFACE_LINE_CONTEXT = raid.INTERFACE_LINE_CONTEXT
            and p_rail.INTERFACE_LINE_ATTRIBUTE1 = raid.INTERFACE_LINE_ATTRIBUTE1
            and p_rail.INTERFACE_LINE_ATTRIBUTE2 = raid.INTERFACE_LINE_ATTRIBUTE2
            and p_rail.INTERFACE_LINE_ATTRIBUTE3 = raid.INTERFACE_LINE_ATTRIBUTE3
            and p_rail.INTERFACE_LINE_ATTRIBUTE4 = raid.INTERFACE_LINE_ATTRIBUTE4
            and p_rail.INTERFACE_LINE_ATTRIBUTE5 = raid.INTERFACE_LINE_ATTRIBUTE5
            --and p_rail.INTERFACE_LINE_ATTRIBUTE6 = raid.INTERFACE_LINE_ATTRIBUTE6
            and p_rail.INTERFACE_LINE_ATTRIBUTE7 = raid.INTERFACE_LINE_ATTRIBUTE7
            and p_rail.INTERFACE_LINE_ATTRIBUTE8 = raid.INTERFACE_LINE_ATTRIBUTE8
            and p_rail.INTERFACE_LINE_ATTRIBUTE9 = raid.INTERFACE_LINE_ATTRIBUTE9
            and p_rail.INTERFACE_LINE_ATTRIBUTE10 = raid.INTERFACE_LINE_ATTRIBUTE10
            --and p_rail.INTERFACE_LINE_ATTRIBUTE11 = raid.INTERFACE_LINE_ATTRIBUTE11-- Esta se comenta ya que cuando son descuentos cambia
--            and p_rail.INTERFACE_LINE_ATTRIBUTE12 = raid.INTERFACE_LINE_ATTRIBUTE12
--            and p_rail.INTERFACE_LINE_ATTRIBUTE13 = raid.INTERFACE_LINE_ATTRIBUTE13
--            and p_rail.INTERFACE_LINE_ATTRIBUTE14 = raid.INTERFACE_LINE_ATTRIBUTE14
--            and p_rail.INTERFACE_LINE_ATTRIBUTE15 = raid.INTERFACE_LINE_ATTRIBUTE15
            ;

            if v_cont_cxc = 0 then
                --dbms_output.put_line('No existe linea de cuenta por cobrar. v_cont_cxc:'||v_cont_cxc);

                select SUM(AMOUNT)
                into v_amount_cxc
                from ra_interface_lines_all rail
                where 1=1
                and  rail.interface_line_context = p_rail.interface_line_context
                and  rail.sales_order =p_rail.sales_order
                and rail.INTERFACE_LINE_ATTRIBUTE1 = p_rail.INTERFACE_LINE_ATTRIBUTE1
                and rail.INTERFACE_LINE_ATTRIBUTE2 = p_rail.INTERFACE_LINE_ATTRIBUTE2;
            end if;
        end;

        for cur_rail in (select rail.ORG_ID
                                ,rail.TRX_NUMBER
                                ,rail.BATCH_SOURCE_NAME
                                ,rail.LINE_TYPE
                                ,rail.DESCRIPTION
                                ,rail.CUST_TRX_TYPE_ID
                                ,rail.ORIG_SYSTEM_BILL_CUSTOMER_ID
                                ,rail.SALES_ORDER
                                ,rail.TAX_CODE
                                ,i.Inventory_Item_Id
                                ,i.segment1 as no_item
                                ,i.description as descr_item
                                ,rac_bill.account_number
                                ,apps.CUST_GET_CLASS(rail.Inventory_Item_Id,91,'OPM_SEGMENTO') as segmento
                                ,apps.CUST_SLA_AR_SOURCE_PKG.GET_ORG_VALUE (rail.ORG_ID) ORG_CODE
                                ,case when CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (rac_bill.account_number) = 'TERCEROEXP' then
                                            'NO'
                                      ELSE
                                            NVL (CUST_SLA_AR_SOURCE_PKG.GET_ESTIMULO_FISCAL (rail.ORG_ID,I.SEGMENT1),'NO')
                                      END  ESTIMULO
                                ,DECODE (CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (rac_bill.account_number),'TERCEROEXP', 'NO',NVL(A7.IEPS_ENERG,'NO')) IEPS_ENERG
                                ,DECODE (CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (rac_bill.account_number),'TERCEROEXP', 'NO',NVL(A7.IEPS_CONT_CALOR,'NO')) IEPS_CONT_CALOR
                                ,DECODE (CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (rac_bill.account_number),'TERCEROEXP', 'NO',DECODE (A7.IEPS_LITRO, 0, 'NO', 'SI')) AZUCAR
                                ,DECODE (CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (rac_bill.account_number),'TERCEROEXP', 'NO',DECODE (A7.IEPS_LITRO_ED, 0, 'NO', 'SI')) EDULCORANTE
                                ,DECODE (rail.TAX_CODE,  'INC 0%', 'NO',  'IVA 0%', 'NO',  'SI') IVA_16
                                ,DECODE (
                                         DECODE (CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (rac_bill.account_number),'TERCEROEXP', 'NO'
                                                 ,NVL (CUST_SLA_AR_SOURCE_PKG.GET_ESTIMULO_FISCAL (rail.ORG_ID,I.SEGMENT1),'NO'))--termina segundo decode
                                                 ,'SI', 'NO' -- Si el primer decode es SI el resultado es NO
                                                 ,'NO', DECODE (rail.TAX_CODE,
                                                                   'INC 0%', 'SI',
                                                                   'IVA 0%', 'SI',
                                                                   'NO')
                                                                   ) IVA_0
                                ,DECODE (rail.TAX_CODE,  'IVA EXENTO', 'SI', 'NO') EXCENTO
                                ,CUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (rac_bill.account_number) TIPO_CLIENTE
                                ,--cty.name
                                rail.interface_line_attribute2
                                    as tipo_pedido_om
                                ,--case WHEN line_type = 'LINE' THEN
                                    'INGRESOS'
                                 --end
                                 Tipo_Transaccion
                        from ra_interface_lines_all rail
                            ,mtl_system_items_b i
                            ,XXAR_IEPS a7
                            ,hz_cust_accounts_all rac_bill
                            ,ra_cust_trx_types_all cty
                        where 1=1
                        --AND rail.org_id = p_rail.org_id
                        AND rail.SALES_ORDER = p_rail.SALES_ORDER
                        and p_rail.INTERFACE_LINE_CONTEXT = rail.INTERFACE_LINE_CONTEXT
                        and p_rail.INTERFACE_LINE_ATTRIBUTE1 = rail.INTERFACE_LINE_ATTRIBUTE1
                        and p_rail.INTERFACE_LINE_ATTRIBUTE2 = rail.INTERFACE_LINE_ATTRIBUTE2
                        and p_rail.INTERFACE_LINE_ATTRIBUTE3 = rail.INTERFACE_LINE_ATTRIBUTE3
                        and p_rail.INTERFACE_LINE_ATTRIBUTE4 = rail.INTERFACE_LINE_ATTRIBUTE4
                        and p_rail.INTERFACE_LINE_ATTRIBUTE5 = rail.INTERFACE_LINE_ATTRIBUTE5
                        and p_rail.INTERFACE_LINE_ATTRIBUTE6 = rail.INTERFACE_LINE_ATTRIBUTE6
                        and p_rail.INTERFACE_LINE_ATTRIBUTE7 = rail.INTERFACE_LINE_ATTRIBUTE7
                        and p_rail.INTERFACE_LINE_ATTRIBUTE8 = rail.INTERFACE_LINE_ATTRIBUTE8
                        and p_rail.INTERFACE_LINE_ATTRIBUTE9 = rail.INTERFACE_LINE_ATTRIBUTE9
                        and p_rail.INTERFACE_LINE_ATTRIBUTE10 = rail.INTERFACE_LINE_ATTRIBUTE10
                        and p_rail.INTERFACE_LINE_ATTRIBUTE11 = rail.INTERFACE_LINE_ATTRIBUTE11
--                        and p_rail.INTERFACE_LINE_ATTRIBUTE12 = rail.INTERFACE_LINE_ATTRIBUTE12
--                        and p_rail.INTERFACE_LINE_ATTRIBUTE13 = rail.INTERFACE_LINE_ATTRIBUTE13
--                        and p_rail.INTERFACE_LINE_ATTRIBUTE14 = rail.INTERFACE_LINE_ATTRIBUTE14
--                        and p_rail.INTERFACE_LINE_ATTRIBUTE15 = rail.INTERFACE_LINE_ATTRIBUTE15
                        And I.Organization_Id(+) = 91
                        And I.Inventory_Item_Id(+) = rail.Inventory_Item_Id
                        AND A7.ORG_ID(+) = rail.ORG_ID
                        AND A7.SEGMENT1(+) = i.SEGMENT1
                        AND rail.ORIG_SYSTEM_BILL_CUSTOMER_ID = rac_bill.cust_account_id
                        and cty.cust_trx_type_id = rail.cust_trx_type_id
                        )
        loop
                APPS.CUST_SLA_AR_SOURCE_PKG.cust_sla_get_cta(cur_rail.Tipo_Transaccion--V_Tipo_Transaccion
                                                                        ,cur_rail.SEGMENTO--V_Segmento
                                                                        ,cur_rail.ORG_CODE--V_Cia
                                                                        ,cur_rail.NO_ITEM--V_Item
                                                                        ,cur_rail.IVA_0--V_Iva_0
                                                                        ,cur_rail.EXCENTO--V_Excento--CASE WHEN V_Iva_0='NO' and V_Iva_16='NO' THEN 'SI' ELSE 'NO' END -- EXCENTO
                                                                        ,cur_rail.IVA_16--V_Iva_16
                                                                        ,cur_rail.estimulo--V_Estimulo
                                                                        ,cur_rail.IEPS_ENERG--V_Ieps_Energ
                                                                        ,cur_rail.AZUCAR--V_Ieps_Azucar
                                                                        ,cur_rail.EDULCORANTE--V_Ieps_Edulcorante
                                                                        ,cur_rail.IEPS_CONT_CALOR--V_Ieps_Cal
                                                                        ,'INTERCOMPANIA'--TIPO_CLIENTE--V_Tipo_Cliente
                                                                        ,NULL--V_Bonificacion
                                                                        ,NULL--V_Linea_Negocio
                                                                        ,cur_rail.tipo_pedido_om --tipo_pedido_om
                                                                        ,CUR_RAIL.account_number
                                                                        ,v_segment1
                                                                        ,v_segment2
                                                                        ,v_segment3
                                                                        ,v_segment4
                                                                        ,v_segment5
                                                                        ,v_segment6
                                                                        ,v_segment7
                                                                        ,v_code_combination_id
                                                                        ,p_trace--'DC'
                                                                        );
                l_interface_distribution_rec.creation_date := SYSDATE;
                l_interface_distribution_rec.interface_line_context := p_rail.interface_line_context;
                l_interface_distribution_rec.interface_line_attribute1  := p_rail.interface_line_attribute1;
                l_interface_distribution_rec.interface_line_attribute2  := p_rail.interface_line_attribute2;
                l_interface_distribution_rec.interface_line_attribute3  := p_rail.interface_line_attribute3;
                l_interface_distribution_rec.interface_line_attribute4  := p_rail.interface_line_attribute4;
                l_interface_distribution_rec.interface_line_attribute5  := p_rail.interface_line_attribute5;
                l_interface_distribution_rec.interface_line_attribute6  := p_rail.interface_line_attribute6;
                l_interface_distribution_rec.interface_line_attribute7  := p_rail.interface_line_attribute7;
                l_interface_distribution_rec.interface_line_attribute8  := p_rail.interface_line_attribute8;
                l_interface_distribution_rec.interface_line_attribute9  := p_rail.interface_line_attribute9;
                l_interface_distribution_rec.interface_line_attribute10 := p_rail.interface_line_attribute10;
                l_interface_distribution_rec.interface_line_attribute11 := p_rail.interface_line_attribute11;
                l_interface_distribution_rec.interface_line_attribute12 := p_rail.interface_line_attribute12;
                l_interface_distribution_rec.interface_line_attribute13 := p_rail.interface_line_attribute13;
                l_interface_distribution_rec.interface_line_attribute14 := p_rail.interface_line_attribute14;
                l_interface_distribution_rec.interface_line_attribute15 := p_rail.interface_line_attribute15;
                l_interface_distribution_rec.org_id := p_rail.org_id;
                l_interface_distribution_rec.account_class := 'REV'; --REV Ingresos     REC --> cxc
                l_interface_distribution_rec.AMOUNT := p_rail.AMOUNT;
                l_interface_distribution_rec.PERCENT := 100;
                l_interface_distribution_rec.segment1 := v_segment1;
                l_interface_distribution_rec.segment2 := v_segment2;
                l_interface_distribution_rec.segment3 := v_segment3;
                l_interface_distribution_rec.segment4 := v_segment4;
                l_interface_distribution_rec.segment5 := v_segment5;
                l_interface_distribution_rec.segment6 := v_segment6;
                l_interface_distribution_rec.segment7 := v_segment7;
                l_interface_distribution_rec.code_combination_id := v_code_combination_id;

                INSERT /*+ APPEND */
                       INTO AR.ra_interface_distributions_all
                     VALUES l_interface_distribution_rec;

                COMMIT;


                if v_cont_cxc = 0 then

                    APPS.CUST_SLA_AR_SOURCE_PKG.cust_sla_get_cta('CXC'--V_Tipo_Transaccion
                                                                            ,cur_rail.SEGMENTO--V_Segmento
                                                                            ,cur_rail.ORG_CODE--V_Cia
                                                                            ,cur_rail.NO_ITEM--V_Item
                                                                            ,cur_rail.IVA_0--V_Iva_0
                                                                            ,cur_rail.EXCENTO--V_Excento--CASE WHEN V_Iva_0='NO' and V_Iva_16='NO' THEN 'SI' ELSE 'NO' END -- EXCENTO
                                                                            ,cur_rail.IVA_16--V_Iva_16
                                                                            ,cur_rail.estimulo--V_Estimulo
                                                                            ,cur_rail.IEPS_ENERG--V_Ieps_Energ
                                                                            ,cur_rail.AZUCAR--V_Ieps_Azucar
                                                                            ,cur_rail.EDULCORANTE--V_Ieps_Edulcorante
                                                                            ,cur_rail.IEPS_CONT_CALOR--V_Ieps_Cal
                                                                            ,'INTERCOMPANIA'--TIPO_CLIENTE--V_Tipo_Cliente
                                                                            ,NULL--V_Bonificacion
                                                                            ,NULL--V_Linea_Negocio
                                                                            ,cur_rail.tipo_pedido_om --tipo_pedido_om
                                                                            ,CUR_RAIL.account_number
                                                                            ,v_segment1
                                                                            ,v_segment2
                                                                            ,v_segment3
                                                                            ,v_segment4
                                                                            ,v_segment5
                                                                            ,v_segment6
                                                                            ,v_segment7
                                                                            ,v_code_combination_id
                                                                            ,p_trace--'DC'
                                                                            );

                        l_interface_distribution_rec.account_class := 'REC'; --REV Ingresos     REC --> cxc
                        l_interface_distribution_rec.AMOUNT := v_amount_cxc;
                        l_interface_distribution_rec.PERCENT := 100;
                        l_interface_distribution_rec.segment1 := v_segment1;
                        l_interface_distribution_rec.segment2 := v_segment2;
                        l_interface_distribution_rec.segment3 := v_segment3;
                        l_interface_distribution_rec.segment4 := v_segment4;
                        l_interface_distribution_rec.segment5 := v_segment5;
                        l_interface_distribution_rec.segment6 := v_segment6;
                        l_interface_distribution_rec.segment7 := v_segment7;
                        l_interface_distribution_rec.code_combination_id := v_code_combination_id;

                        INSERT /*+ APPEND */
                           INTO ar.ra_interface_distributions_all
                         VALUES l_interface_distribution_rec;

                COMMIT;
                END IF;
        end loop;
        o_err_num := 0;
        o_err_msj :='Successful';
        commit;
    END cust_sla_set_cta;

    procedure cust_get_uso_cfdi_icia(p_rail ra_interface_lines_all%rowtype, o_err_msj OUT varchar2, o_err_num OUT number, o_uso_cfdi out varchar2)
    as
        v_segment5 varchar2(100);
        vExisteUsoCFDI number;
        v_header_attribute14 varchar2(1000);
    begin
        vExisteUsoCFDI := 0;
        -- Revisamos si algun registro ya tiene el UsoDeCFDI
        select count(rail.header_attribute14), max(rail.header_attribute14)
        into vExisteUsoCFDI, v_header_attribute14
        from ra_interface_lines_all rail
        where 1=1
        and rail.org_id = p_rail.org_id
        and rail.INTERFACE_LINE_CONTEXT = p_rail.INTERFACE_LINE_CONTEXT
        and p_rail.INTERFACE_LINE_ATTRIBUTE1 = rail.INTERFACE_LINE_ATTRIBUTE1
        and p_rail.INTERFACE_LINE_ATTRIBUTE2 = rail.INTERFACE_LINE_ATTRIBUTE2
        and rail.header_attribute14 is not null;

        if vExisteUsoCFDI = 0 then

            o_err_num := 0;
            o_err_msj := NULL;
            o_uso_cfdi := null;
            begin
                select segment5
                into v_segment5
                from ra_interface_distributions_all raid
                where 1 = 1
                and raid.account_class ='REV'
                and p_rail.INTERFACE_LINE_CONTEXT = raid.INTERFACE_LINE_CONTEXT
                and p_rail.INTERFACE_LINE_ATTRIBUTE1 = raid.INTERFACE_LINE_ATTRIBUTE1
                and p_rail.INTERFACE_LINE_ATTRIBUTE2 = raid.INTERFACE_LINE_ATTRIBUTE2
                and p_rail.INTERFACE_LINE_ATTRIBUTE3 = raid.INTERFACE_LINE_ATTRIBUTE3
                and p_rail.INTERFACE_LINE_ATTRIBUTE4 = raid.INTERFACE_LINE_ATTRIBUTE4
                and p_rail.INTERFACE_LINE_ATTRIBUTE5 = raid.INTERFACE_LINE_ATTRIBUTE5
                --and p_rail.INTERFACE_LINE_ATTRIBUTE6 = raid.INTERFACE_LINE_ATTRIBUTE6
                and p_rail.INTERFACE_LINE_ATTRIBUTE7 = raid.INTERFACE_LINE_ATTRIBUTE7
                and p_rail.INTERFACE_LINE_ATTRIBUTE8 = raid.INTERFACE_LINE_ATTRIBUTE8
                and p_rail.INTERFACE_LINE_ATTRIBUTE9 = raid.INTERFACE_LINE_ATTRIBUTE9
                and p_rail.INTERFACE_LINE_ATTRIBUTE10 = raid.INTERFACE_LINE_ATTRIBUTE10
                and rownum = 1
                                --and p_rail.INTERFACE_LINE_ATTRIBUTE11 = raid.INTERFACE_LINE_ATTRIBUTE11-- Esta se comenta ya que cuando son descuentos cambia
                    --            and p_rail.INTERFACE_LINE_ATTRIBUTE12 = raid.INTERFACE_LINE_ATTRIBUTE12
                    --            and p_rail.INTERFACE_LINE_ATTRIBUTE13 = raid.INTERFACE_LINE_ATTRIBUTE13
                    --            and p_rail.INTERFACE_LINE_ATTRIBUTE14 = raid.INTERFACE_LINE_ATTRIBUTE14
                    --            and p_rail.INTERFACE_LINE_ATTRIBUTE15 = raid.INTERFACE_LINE_ATTRIBUTE15
                ;
            exception
                when others then
                    o_err_num := 1;
                    o_err_msj := 'SEGMENTO5 CXC NO ENCONTRADO';
            end;
            IF o_err_num = 0 THEN
                -- Busca el segmento5 de la Cxc en el lookup
                begin
                    SELECT  vl.description
                    into o_uso_cfdi
                      FROM fnd_lookup_values_vl vl
                     WHERE     lookup_type = 'XXAR_USOCFDI_NC_INTERCOMPANY'
                        AND vl.enabled_flag = 'Y'
                        and vl.lookup_code = v_segment5
                        AND SYSDATE BETWEEN start_date_active AND NVL (end_date_active, SYSDATE + 1);
                    o_err_msj := 'UsoDeCFDI v_segment5:'||v_segment5 || '  -- ' || o_uso_cfdi;
                exception
                    when others then
                        o_err_num := 2;
                        o_err_msj := 'NO HAY MAPEO CXC SEG5 ' || v_segment5;
                end;
            END IF;
        else
            o_err_num := 0;
            o_err_msj := 'Se recupero el UsoDeCFDI ' || v_header_attribute14;
            o_uso_cfdi := v_header_attribute14;
        end if;
    end cust_get_uso_cfdi_icia;

END CUST_SLA_AR_SOURCE_PKG;