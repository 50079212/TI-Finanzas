CREATE OR REPLACE PACKAGE BODY XXWEBC."XXCUST_SLA_AR_SOURCE_PKG" 
AS
    FUNCTION XXAR_RETURN_SEGMENT_SLA_AR (
                                        p_segment_return NUMBER,
                                        p_cust_trx_line_gl_dist_id NUMBER
                                        )
                                        RETURN VARCHAR2
    IS 
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_return VARCHAR2(4000);
        v_type_line_dist varchar2(1000);
        v_code_combination_id number;
        v_text VARCHAR2(4000);

        V_INTERFACE_HEADER_CONTEXT VARCHAR2(100);
        V_CODIGO_TRANSACCION_AR VARCHAR2(100);
        V_TYPE_TRX_NAME VARCHAR2(100);
        V_NO_LINE VARCHAR2(100);
        V_Customer_Trx_Id Number;
        v_customer_trx_line_id number;
        v_cust_trx_line_gl_dist_id number;
        v_org_id number;
        v_link_to_cust_trx_line_id number;
        v_cia varchar2(100);
        v_cia_name varchar2(100);
        v_trx_number varchar2(100);
        v_monto_original NUMBER;
        v_inventory_item_id NUMBER;
        --v_type_line_dist varchar2(100);
        v_monto NUMBER;
        v_segment1 varchar2(100);
        v_segment2 varchar2(100);
        v_segment3 varchar2(100);
        v_segment4 varchar2(100);
        v_segment5 varchar2(100);
        v_segment6 varchar2(100);   
        v_segment7 varchar2(100);
        v_line_type varchar2(100);
        V_Account_Number NUMBER;
        v_segmento_sio varchar2(100);
        v_tipo_cliente varchar2(100);
        v_estimulo_fiscal varchar2(100);
        v_ieps_energ varchar2(100);
        v_ieps_cal varchar2(100);
        v_ieps_azucar varchar2(100);
        v_ieps_edulcorante varchar2(100);
        v_tax_classification_code varchar2(100);
        v_iva varchar2(100);
        v_iva_tasa varchar2(100);
        v_iva_0 varchar2(100);
        v_excento varchar2(100);
        v_item varchar2(100);
        v_description varchar2(500);
        V_FRONTERA varchar2(10);
        v_tipo_transaccion_dist varchar2(100);
        V_SEGMENTO_OPM VARCHAR2(100);

        v_tipo_pedido_om varchar2(100);
        V_Bonificacion VARCHAR2(100);
        V_Linea_Negocio VARCHAR2(100);

        v_error number;
    BEGIN
        v_error := 0;
        /*insert into XXWEBC.XXAR_AUX_SLA
            (CREATION_DATE
            ,P_SEGMENT_RETURN
            ,P_CUST_TRX_LINE_GL_DIST_ID
            ,P_CODE_COMBINATION_ID)
        VALUES(SYSDATE, p_segment_return, p_cust_trx_line_gl_dist_id, p_code_combination_id);
        commit;*/

        select account_class, code_combination_id,trxh.interface_header_context, trxh.interface_header_attribute2
            into v_type_line_dist,v_code_combination_id,v_interface_header_context, v_tipo_pedido_om
                from apps.RA_CUST_TRX_LINE_GL_DIST_ALL trxd
                ,apps.ra_customer_trx_all trxh
            where 1=1
            and trxd.cust_trx_line_gl_dist_id =p_cust_trx_line_gl_dist_id
            and trxh.customer_trx_id = trxd.customer_trx_id;

        --SEGMENT1
        --select decode(p_segment_return,1,SEGMENT1,2,SEGMENT2,3,SEGMENT3,4,SEGMENT4,5,SEGMENT5,6,SEGMENT6,SEGMENT7)
        select decode(p_segment_return,2,SEGMENT2,4,SEGMENT4,5,SEGMENT5,6,SEGMENT6,SEGMENT7)
            into v_return
        from APPS.GL_CODE_COMBINATIONS
        where code_combination_id = v_code_combination_id;

        COMMIT;  

        IF  v_interface_header_context != 'ORDER ENTRY' THEN
            BEGIN
                v_text := 'v_type_line_dist: '||v_type_line_dist||' v_interface_header_context: '||v_interface_header_context;
                insert into XXWEBC.XXAR_AUX_SLA
                    (CREATION_DATE
                    ,P_SEGMENT_RETURN
                    ,P_CUST_TRX_LINE_GL_DIST_ID
                    ,P_CODE_COMBINATION_ID
                    ,TEXT)
                VALUES(SYSDATE, p_segment_return, p_cust_trx_line_gl_dist_id, v_code_combination_id,V_TEXT);


            END;

            /*IF p_segment_return = 2 THEN
                v_return := '-7';
            ELSE
                v_return := '-777';
            END IF;*/
            commit;
            RETURN v_return;
        ELSE


            BEGIN
                SELECT  TRXH.INTERFACE_HEADER_CONTEXT
                    ,TT.TYPE AS CODIGO_TRANSACCION_AR
                    ,TT.NAME AS TYPE_TRX_NAME
                    ,NVL(TRXL2.LINE_NUMBER,NVL(TRXL.LINE_NUMBER,0)) AS NO_LIN
                    ,TRXH.CUSTOMER_TRX_ID
                    ,TRXL.CUSTOMER_TRX_LINE_ID
                    ,TRXD.CUST_TRX_LINE_GL_DIST_ID
                    ,TRXD.ORG_ID
					,TRXL.LINK_TO_CUST_TRX_LINE_ID
                    ,OU.ATTRIBUTE15 AS CIA 
                    ,OU.NAME AS CIA_NAME
                    ,TRXH.TRX_NUMBER
                    ,PS.AMOUNT_DUE_ORIGINAL AS MONTO_ORIGINAL                                          
                    ,NVL(TRXL2.INVENTORY_ITEM_ID,TRXL.INVENTORY_ITEM_ID) AS INVENTORY_ITEM_ID					
                    ,TRXD.ACCOUNT_CLASS as type_line_dist
                    ,TRXD.AMOUNT AS MONTO
                    ,TRXD.CODE_COMBINATION_ID
                    ,GCC.SEGMENT1
                    ,GCC.SEGMENT2
                    ,GCC.SEGMENT3
                    ,GCC.SEGMENT4
                    ,GCC.SEGMENT5
                    ,GCC.SEGMENT6
                    ,GCC.SEGMENT7
                    ,TRXL.LINE_TYPE
                    ,HZCA.ACCOUNT_NUMBER AS Account_Number                               
                    ,NVL(IT2.ATTRIBUTE13,NVL(IT.ATTRIBUTE13,0)) AS SEGMENTO_SIO
                    ,XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (P_CUST_ACCOUNT_ID=>HZCA.CUST_ACCOUNT_ID,P_SITE_USE_ID=>TRXH.BILL_TO_SITE_USE_ID) TIPO_CLIENTE 
                    ,CASE WHEN XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (P_CUST_ACCOUNT_ID=>HZCA.CUST_ACCOUNT_ID,P_SITE_USE_ID=>TRXH.BILL_TO_SITE_USE_ID) ='TERCEROEXP' THEN 
                            'NO'
                        ELSE
                                XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.GET_ESTIMULO_FISCAL (TRXD.ORG_ID,NVL(IT2.SEGMENT1,IT.SEGMENT1))
                        END ESTIMULO_FISCAL                     
                    ,CASE WHEN XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (P_CUST_ACCOUNT_ID=>HZCA.CUST_ACCOUNT_ID,P_SITE_USE_ID=>TRXH.BILL_TO_SITE_USE_ID) = 'TERCEROEXP' THEN
                            'NO'
                        ELSE
                                NVL(TAX_IEPS2.IEPS_ENERG,NVL(TAX_IEPS.IEPS_ENERG,'NO'))
                        END IEPS_ENERG
                    ,CASE WHEN XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (P_CUST_ACCOUNT_ID=>HZCA.CUST_ACCOUNT_ID,P_SITE_USE_ID=>TRXH.BILL_TO_SITE_USE_ID) = 'TERCEROEXP' THEN
                            'NO'
                        ELSE
                                NVL(TAX_IEPS2.IEPS_CONT_CALOR,NVL(TAX_IEPS.IEPS_CONT_CALOR,'NO'))
                        END IEPS_CAL -- CONTENIDO CALORICO
                    ,CASE WHEN XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (P_CUST_ACCOUNT_ID=>HZCA.CUST_ACCOUNT_ID,P_SITE_USE_ID=>TRXH.BILL_TO_SITE_USE_ID) = 'TERCEROEXP' THEN
                            'NO'
                        ELSE
								NVL(TAX_IEPS2.IEPS,NVL(TAX_IEPS.IEPS,'NO'))
                        END IEPS_AZUCAR     	
                    ,CASE WHEN XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (P_CUST_ACCOUNT_ID=>HZCA.CUST_ACCOUNT_ID,P_SITE_USE_ID=>TRXH.BILL_TO_SITE_USE_ID) = 'TERCEROEXP' THEN
                            'NO'
                        ELSE
                                NVL(TAX_IEPS2.IEPS_ED,NVL(TAX_IEPS.IEPS_ED,'NO'))
                        END IEPS_EDULCORANTE
                    ,NVL(TRXL2.TAX_CLASSIFICATION_CODE,TRXL.TAX_CLASSIFICATION_CODE) AS TAX_CLASSIFICATION_CODE
                    ,CASE WHEN XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (P_CUST_ACCOUNT_ID=>HZCA.CUST_ACCOUNT_ID,P_SITE_USE_ID=>TRXH.BILL_TO_SITE_USE_ID) = 'TERCEROEXP' 
                                OR XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.GET_ESTIMULO_FISCAL (TRXD.ORG_ID,NVL(IT2.SEGMENT1,IT.SEGMENT1)) = 'SI' THEN
                            'NO'
                        WHEN NVL(TRXL2.TAX_CLASSIFICATION_CODE,TRXL.TAX_CLASSIFICATION_CODE) IN ('INC 16%','IVA 16%','INC 8%','IVA 8%') THEN 
                            'SI'
                        ELSE 
                            'NO'   
                        END IVA
                    ,CASE WHEN XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (P_CUST_ACCOUNT_ID=>HZCA.CUST_ACCOUNT_ID,P_SITE_USE_ID=>TRXH.BILL_TO_SITE_USE_ID) = 'TERCEROEXP' 
                                OR XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.GET_ESTIMULO_FISCAL (TRXD.ORG_ID,NVL(IT2.SEGMENT1,IT.SEGMENT1)) = 'SI' THEN
                            '0'
                        WHEN NVL(TRXL2.TAX_CLASSIFICATION_CODE,TRXL.TAX_CLASSIFICATION_CODE) IN ('INC 16%','IVA 16%') THEN 
                            '16'
                        WHEN NVL(TRXL2.TAX_CLASSIFICATION_CODE,TRXL.TAX_CLASSIFICATION_CODE) IN ('INC 8%','IVA 8%') THEN 
                            '8'
                        ELSE 
                            '0'   
                        END AS IVA_TASA
                    ,CASE WHEN XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.TIPO_CLIENTE (P_CUST_ACCOUNT_ID=>HZCA.CUST_ACCOUNT_ID,P_SITE_USE_ID=>TRXH.BILL_TO_SITE_USE_ID) = 'TERCEROEXP' 
                            OR XXWEBC.XXCUST_SLA_AR_SOURCE_PKG.GET_ESTIMULO_FISCAL (TRXD.ORG_ID,NVL(IT2.SEGMENT1,IT.SEGMENT1)) = 'SI'THEN
                            'NO'
                        WHEN NVL(TRXL2.TAX_CLASSIFICATION_CODE,TRXL.TAX_CLASSIFICATION_CODE) IN ('INC 0%','IVA 0%') THEN 
                            'SI'
                        ELSE 
                            'NO'   
                        END IVA_0
                    ,CASE WHEN NVL(TRXL2.TAX_CLASSIFICATION_CODE,TRXL.TAX_CLASSIFICATION_CODE) = 'IVA EXENTO'	THEN
                        'SI'
                    ELSE
                        'NO'
                    END IVA_EXCENTO
                    ,NVL(IT2.SEGMENT1,IT.SEGMENT1) AS ITEM    
                    ,NVL(TRXL2.DESCRIPTION,TRXL.DESCRIPTION) AS DESCRIPTION
                    ,CASE WHEN HZCA.ACCOUNT_NUMBER BETWEEN 8000 AND 8999 THEN 
                            'SI'
                        ELSE
                            'NO'
                        END FRONTERA
                    ,CASE WHEN TRXD.ACCOUNT_CLASS ='REC' THEN
                                'CXC'
                        WHEN TT.TYPE = 'INV' AND TRXD.ACCOUNT_CLASS ='REV' AND TRXL.DESCRIPTION NOT LIKE 'IEPS%' AND TRXD.AMOUNT >0 THEN
                                'INGRESOS'
                        WHEN TT.TYPE = 'CM' AND TRXD.ACCOUNT_CLASS ='REV' AND TRXL.DESCRIPTION NOT LIKE 'IEPS%' AND TRXD.AMOUNT <0 THEN
                                'INGRESOS'
                        WHEN TRXD.ACCOUNT_CLASS ='REV' AND TRXL.DESCRIPTION LIKE 'IEPS_LT.%' THEN
                                'IEPS'   
                        WHEN TRXD.ACCOUNT_CLASS ='REV' AND TRXL.DESCRIPTION LIKE 'IEPS_LT_ED.%' THEN
                                'IEPS EDULCORANTE'                           
                        WHEN TRXD.ACCOUNT_CLASS ='TAX' THEN
                                'IVA'-- Revisar casos de impuesto compuesto?????
                        WHEN TRXD.ORG_ID IN (84) AND TT.TYPE = 'INV' AND TRXD.ACCOUNT_CLASS ='REV' AND TRXD.AMOUNT <0 AND  TRXL.DESCRIPTION NOT LIKE 'IEPS%' AND SUBSTR(TRXL.DESCRIPTION,INSTR(TRXL.DESCRIPTION,'.')-1,2) = 'C.' THEN
                                'DESCUENTO COMERCIAL'
                        WHEN TRXD.ORG_ID IN (84) AND TT.TYPE = 'CM' AND TRXD.ACCOUNT_CLASS ='REV' AND TRXD.AMOUNT >0 AND  TRXL.DESCRIPTION NOT LIKE 'IEPS%' AND SUBSTR(TRXL.DESCRIPTION,INSTR(TRXL.DESCRIPTION,'.')-1,2) = 'C.' THEN
                                'DESCUENTO COMERCIAL' 
                        WHEN TRXD.ORG_ID IN (84) AND TT.TYPE = 'INV' AND TRXD.ACCOUNT_CLASS ='REV' AND TRXD.AMOUNT <0 AND  TRXL.DESCRIPTION NOT LIKE 'IEPS%' AND SUBSTR(TRXL.DESCRIPTION,INSTR(TRXL.DESCRIPTION,'.')-1,2) = 'L.' THEN
                                'DESCUENTO LOGISTICO'
                        WHEN TRXD.ORG_ID IN (84) AND TT.TYPE = 'CM' AND TRXD.ACCOUNT_CLASS ='REV' AND TRXD.AMOUNT >0 AND  TRXL.DESCRIPTION NOT LIKE 'IEPS%' AND SUBSTR(TRXL.DESCRIPTION,INSTR(TRXL.DESCRIPTION,'.')-1,2) = 'L.' THEN
                                'DESCUENTO LOGISTICO' 
                        WHEN TRXD.ORG_ID IN (84) AND TT.TYPE = 'INV' AND TRXD.ACCOUNT_CLASS ='REV' AND TRXD.AMOUNT <0 AND  TRXL.DESCRIPTION NOT LIKE 'IEPS%' AND SUBSTR(TRXL.DESCRIPTION,8,1) = 'P' THEN
                                'DESCUENTO PROMOCIONAL'
                        WHEN TRXD.ORG_ID IN (84) AND TT.TYPE = 'CM' AND TRXD.ACCOUNT_CLASS ='REV' AND TRXD.AMOUNT >0 AND  TRXL.DESCRIPTION NOT LIKE 'IEPS%' AND SUBSTR(TRXL.DESCRIPTION,8,1) = 'P' THEN
                                'DESCUENTO PROMOCIONAL'    
                        WHEN TRXD.ORG_ID IN (84) AND TRXD.ACCOUNT_CLASS ='REV' AND TRXL.DESCRIPTION LIKE 'IRTARIMA.%' THEN
                                'DESCUENTO TARIMA' -- Revisar casos de descuento de tarima?????
                    END tipo_transaccion_dist  
                    ,XXCUST_SLA_AR_SOURCE_PKG.GET_SEGMENT_OPM(it.INVENTORY_ITEM_ID)segmento_opm
                INTO    v_interface_header_context
                    ,V_CODIGO_TRANSACCION_AR
                    ,v_type_trx_name
                    ,v_no_line		
                    ,v_customer_trx_id
                    ,v_customer_trx_line_id
                    ,v_cust_trx_line_gl_dist_id
                    ,v_org_id
                    ,v_link_to_cust_trx_line_id
                    ,v_cia 
                    ,v_cia_name
                    ,v_trx_number
                    ,v_monto_original                                          
                    ,v_inventory_item_id
                    ,v_type_line_dist
                    ,v_monto
                    ,v_code_combination_id
                    ,v_segment1
                    ,v_segment2
                    ,v_segment3
                    ,v_segment4
                    ,v_segment5
                    ,v_segment6
                    ,v_segment7
                    ,v_line_type
                    ,V_Account_Number                               
                    ,v_segmento_sio  
                    ,v_tipo_cliente 
                    ,v_estimulo_fiscal                     
                    ,v_ieps_energ 
                    ,v_ieps_cal 
                    ,v_ieps_azucar 
                    ,v_ieps_edulcorante  
                    ,v_tax_classification_code
                    ,v_iva  
                    ,v_iva_tasa
                    ,v_iva_0
                    ,v_excento
                    ,v_item
                    ,v_description
                    ,V_FRONTERA
                    ,v_tipo_transaccion_dist   
                    ,V_SEGMENTO_OPM
                FROM APPS.RA_CUSTOMER_TRX_ALL TRXH
                    ,APPS.AR_PAYMENT_SCHEDULES_ALL PS
                    ,APPS.RA_CUST_TRX_LINE_GL_DIST_ALL TRXD
                    ,APPS.GL_CODE_COMBINATIONS GCC                                
                    ,APPS.HR_ALL_ORGANIZATION_UNITS OU
                    ,APPS.RA_CUSTOMER_TRX_LINES_ALL TRXL
                    ,APPS.MTL_SYSTEM_ITEMS_B IT
                    ,APPS.XXAR_IEPS TAX_IEPS
                    ,APPS.HZ_CUST_ACCOUNTS_ALL HZCA
                    ,APPS.HZ_PARTIES HZCA_PARTY
                    ,APPS.RA_CUST_TRX_TYPES_ALL TT
                    ,APPS.RA_CUSTOMER_TRX_LINES_ALL TRXL2
                    ,APPS.MTL_SYSTEM_ITEMS_B IT2
                    ,APPS.XXAR_IEPS TAX_IEPS2
                WHERE 1=1
                --AND TRXH.CUSTOMER_TRX_ID = 128742743--71562840  
                --AND TRXH.TRX_NUMBER = 'KO2095817'--'KO2095812'
                AND TRXD.CUST_TRX_LINE_GL_DIST_ID =P_CUST_TRX_LINE_GL_DIST_ID--625227527                                                                                                             ¿¿
                AND TRXH.ORG_ID = PS.ORG_ID(+)
                AND TRXH.CUSTOMER_TRX_ID = PS.CUSTOMER_TRX_ID(+)
                AND TRXH.ORG_ID = TT.ORG_ID
                AND TRXH.CUST_TRX_TYPE_ID = TT.CUST_TRX_TYPE_ID
                AND TRXD.ORG_ID = TRXH.ORG_ID
                AND TRXD.CUSTOMER_TRX_ID = TRXH.CUSTOMER_TRX_ID
                AND GCC.CODE_COMBINATION_ID = TRXD.CODE_COMBINATION_ID
                AND OU.ORGANIZATION_ID = TRXH.ORG_ID                                                         
                AND TRXD.ORG_ID = TRXL.ORG_ID(+)
                AND TRXD.CUSTOMER_TRX_ID = TRXL.CUSTOMER_TRX_ID(+)
                AND TRXD.CUSTOMER_TRX_LINE_ID = TRXL.CUSTOMER_TRX_LINE_ID(+)
                AND IT.ORGANIZATION_ID(+) = 91
                AND IT.INVENTORY_ITEM_ID(+) = TRXL.INVENTORY_ITEM_ID
                AND TAX_IEPS.ORG_ID(+) = TRXD.ORG_ID
                AND TAX_IEPS.SEGMENT1(+) = IT.SEGMENT1
                AND TRXH.BILL_TO_CUSTOMER_ID = HZCA.CUST_ACCOUNT_ID
                AND HZCA.PARTY_ID = HZCA_PARTY.PARTY_ID
                AND TRXL.CUSTOMER_TRX_ID = TRXL2.CUSTOMER_TRX_ID(+)
                AND TRXL.LINK_TO_CUST_TRX_LINE_ID = TRXL2.CUSTOMER_TRX_LINE_ID(+)
                AND IT2.ORGANIZATION_ID(+) = 91
                AND IT2.INVENTORY_ITEM_ID(+) = TRXL2.INVENTORY_ITEM_ID
                AND TAX_IEPS2.ORG_ID(+) = TRXL2.ORG_ID
                AND TAX_IEPS2.SEGMENT1(+) = IT2.SEGMENT1
                --ORDER BY LINE_NUMBER
                ;
            EXCEPTION
                WHEN OTHERS THEN
                    v_error:=1;
            END;

            If V_Error != 0 Then
                -- Regresa error -666
                IF p_segment_return = 2 THEN
                    v_return := '-6';
                ELSE
                    v_return := '-666';
                END IF;
                ROLLBACK;
                insert into XXWEBC.XXAR_AUX_SLA
                    (CREATION_DATE
                    ,P_SEGMENT_RETURN
                    ,P_CUST_TRX_LINE_GL_DIST_ID
                    ,P_CODE_COMBINATION_ID
                    ,TEXT)
                VALUES(SYSDATE, p_segment_return, p_cust_trx_line_gl_dist_id, v_code_combination_id,'ERROR AL OBTENER DATOS');
                commit;
                return v_return;
            ELSE

                /*IF p_segment_return = 7 AND v_type_line_dist IN ('REC','REV') AND V_Tipo_Transaccion_DIST IN ('CXC','INGRESOS') AND V_Tipo_Cliente = 'INTERCOMPANIA' THEN
                    v_return := LPAD(V_Account_Number,3,'0') ;
                    return v_return;
                ELSIF p_segment_return = 7 THEN--OR V_Tipo_Cliente = 'INTERCOMPANIA' THEN                    
                    return v_return;*/
                --ELS
                --IF p_segment_return = 2  AND V_Tipo_Transaccion_DIST IN ('CXC') THEN
                  --  return v_return;
                --ELS
                IF  p_segment_return in (4,5,6) AND v_type_line_dist = 'REC' AND v_tipo_transaccion_dist = 'CXC' THEN
                  -- Obtiene el segmento_sio del primer SKU de la factura para derivar el de la cuenta por cobrar
                  /*-- Obtiene el segmento_sio del primer SKU de la factura para derivar el de la cuenta por cobrar
                    for cur in ( Select Nvl (Upper (I.Attribute13), Null ) Segmento_Sio
                                    From apps.Ra_Customer_Trx_Lines_All Trxl
                                        ,apps.Mtl_System_Items_B I
                                    Where 1=1
                                    And Trxl.Customer_Trx_Id = V_Customer_Trx_Id
                                    And Trxl.Line_Number = 1
                                    And Trxl.Line_Type='LINE'
                                    And I.Organization_Id(+) = 91
                                    And I.Inventory_Item_Id(+) = Trxl.Inventory_Item_Id
                                    And Rownum = 1)*/
                  -- Obtiene el segmento_opm del primer SKU de la factura para derivar el de la cuenta por cobrar
                  V_SEGMENTO_OPM := NULL;
                  for cur in ( SELECT xxwebc.XXCUST_SLA_AR_SOURCE_PKG.GET_SEGMENT_OPM(Trxl.Inventory_Item_Id) SEGMENTO_OPM
                                FROM apps.Ra_Customer_Trx_Lines_All Trxl
                                WHERE 1=1                                
                                And Trxl.Line_Number = 1
                                And Trxl.Line_Type='LINE'
                                And Trxl.Customer_Trx_Id = V_Customer_Trx_Id
                                And Rownum = 1)                    
                    loop
                        V_SEGMENTO_OPM := cur.SEGMENTO_OPM;
                    end loop;
                END IF; 



                    V_Bonificacion := NULL; --Revisar de donde se tomara este valor
                    V_Linea_Negocio := NULL; --Revisar de donde se tomara este valor


                    dbms_output.put_line('Ingresa a derivacion contable');
                    V_TEXT :=   v_tipo_transaccion_dist || '|' ||
                                p_segment_return || '|' ||
                                V_Segmento_sio || '|' ||
                                V_Cia || '|' ||
                                V_Item || '|' ||
                                V_Iva_0 || '|' ||
                                V_Excento || '|' ||
                                V_Iva || '|' ||
                                V_Iva_tasa || '|' ||
                                V_Estimulo_fiscal || '|' ||
                                V_Ieps_Energ || '|' ||
                                V_Ieps_Cal || '|' ||
                                V_Ieps_Azucar || '|' ||
                                V_Ieps_Edulcorante || '|' ||
                                V_Tipo_Cliente || '|' ||
                                V_Bonificacion || '|' ||
                                V_Linea_Negocio || '|' ||
                                v_frontera || '|' || 
                                v_tipo_pedido_om || '|' ||
                                v_account_number || '|' || 
                                v_codigo_transaccion_ar || '|' || 
                                V_SEGMENTO_OPM;

                    insert into XXWEBC.XXAR_AUX_SLA
                        (CREATION_DATE
                        ,P_SEGMENT_RETURN
                        ,P_CUST_TRX_LINE_GL_DIST_ID
                        ,P_CODE_COMBINATION_ID
                        ,TEXT)
                    VALUES(SYSDATE, p_segment_return, p_cust_trx_line_gl_dist_id, v_code_combination_id,V_TEXT);
                    commit;

                    v_return := XXCUST_SLA_AR_SOURCE_PKG.GET_VAL_SEGMENT(v_tipo_transaccion_dist
                                                                        ,p_segment_return
                                                                        ,V_Segmento_sio
                                                                        ,V_Cia
                                                                        ,V_Item
                                                                        ,V_Iva_0
                                                                        ,V_Excento--CASE WHEN V_Iva_0='NO' and V_Iva_16='NO' THEN 'SI' ELSE 'NO' END -- EXCENTO
                                                                        ,V_Iva
                                                                        ,V_Iva_Tasa                                                
                                                                        ,v_estimulo_fiscal
                                                                        ,V_Ieps_Energ
                                                                        ,V_Ieps_Cal
                                                                        ,V_Ieps_Azucar
                                                                        ,V_Ieps_Edulcorante                                                
                                                                        ,V_Tipo_Cliente
                                                                        ,V_Bonificacion
                                                                        ,V_Linea_Negocio
                                                                        ,v_frontera                                                
                                                                        ,v_tipo_pedido_om --tipo_pedido_om
                                                                        ,v_account_number
                                                                        ,v_codigo_transaccion_ar
                                                                        ,V_SEGMENTO_OPM --
                                                                        );                                                        

                        V_TEXT := V_TEXT || '|' || v_return;

                        insert into XXWEBC.XXAR_AUX_SLA
                            (CREATION_DATE
                            ,P_SEGMENT_RETURN
                            ,P_CUST_TRX_LINE_GL_DIST_ID
                            ,P_CODE_COMBINATION_ID
                            ,TEXT)
                        VALUES(SYSDATE, p_segment_return, p_cust_trx_line_gl_dist_id, v_code_combination_id,V_TEXT);
                        commit;
                        dbms_output.put_line('v_return:'||v_return);

                End If;


            commit;
            RETURN v_return;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            V_RETURN:='-667';
            ROLLBACK;
            insert into XXWEBC.XXAR_AUX_SLA
                (CREATION_DATE
                ,P_SEGMENT_RETURN
                ,P_CUST_TRX_LINE_GL_DIST_ID
                ,P_CODE_COMBINATION_ID)
            VALUES(SYSDATE, p_segment_return, p_cust_trx_line_gl_dist_id, v_code_combination_id);
            commit;
            RETURN v_return;
    END XXAR_RETURN_SEGMENT_SLA_AR;

    FUNCTION TIPO_CLIENTE (P_CUST_ACCOUNT_ID NUMBER DEFAULT 0
                          ,P_CUSTOMER_NUMBER NUMBER DEFAULT 0
                          ,P_SITE_USE_ID NUMBER DEFAULT 0
                         )
                  RETURN VARCHAR2
    AS
        V_TIPO_CLIENTE   VARCHAR2 (100);
    BEGIN
        V_TIPO_CLIENTE := P_CUST_ACCOUNT_ID;
        --RETURN V_TIPO_CLIENTE;

        IF P_CUST_ACCOUNT_ID != 0 THEN
            SELECT DISTINCT NVL(hcas.attribute6, 'TERCERO') AS TIPO_CLIENTE
            INTO V_TIPO_CLIENTE
            FROM ar.hz_cust_acct_sites_all hcas, apps.hz_cust_accounts cust_acct, ar.hz_cust_site_uses_all d
            WHERE     1 = 1
                    AND cust_acct.cust_account_id = hcas.cust_account_id
                    AND cust_acct.status = 'A'
                    AND NVL(hcas.attribute6, 'TERCERO') IN ('TERCEROEXP',
                                                            'ASOCIADA',
                                                            'ASOCIADOEXP',
                                                            'FRANQUICIADORA',
                                                            'INTERCOMPANIA',
                                                            'TERCERO')
                    AND hcas.cust_acct_site_id = d.cust_acct_site_id
                    AND hcas.org_id = d.org_id
                    AND d.site_use_id = P_SITE_USE_ID
                    AND hcas.cust_account_id = P_CUST_ACCOUNT_ID;

        ELSIF P_CUSTOMER_NUMBER != 0 THEN
            SELECT DISTINCT NVL(hcas.attribute6, 'TERCERO') AS TIPO_CLIENTE
            INTO V_TIPO_CLIENTE
            FROM ar.hz_cust_acct_sites_all hcas, apps.hz_cust_accounts cust_acct, ar.hz_cust_site_uses_all d
            WHERE     1 = 1
                    AND cust_acct.cust_account_id = hcas.cust_account_id
                    AND cust_acct.status = 'A'
                    AND NVL(hcas.attribute6, 'TERCERO') IN ('TERCEROEXP',
                                                            'ASOCIADA',
                                                            'ASOCIADOEXP',
                                                            'FRANQUICIADORA',
                                                            'INTERCOMPANIA',
                                                            'TERCERO')
                    AND hcas.cust_acct_site_id = d.cust_acct_site_id
                    AND hcas.org_id = d.org_id
                    AND d.site_use_id = P_SITE_USE_ID
                    AND cust_acct.account_number = P_CUSTOMER_NUMBER;
        END IF;

        /*IF V_TIPO_CLIENTE IS NULL THEN
            V_TIPO_CLIENTE := 'TERCERO';
        END IF;*/

        RETURN V_TIPO_CLIENTE;
    EXCEPTION
        WHEN OTHERS THEN        
            V_TIPO_CLIENTE := 'ERROR';
            RETURN V_TIPO_CLIENTE;
    END TIPO_CLIENTE;   

    FUNCTION get_estimulo_fiscal (p_org_id              IN NUMBER,
                                 p_inventory_item_id   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        v_estimulo_fis   VARCHAR2 (35);
    BEGIN
        SELECT UNIQUE NVL(ESTIMULO_FISCAL, 'NO')
        INTO v_estimulo_fis
        FROM apps.XXAR_SLA_ESTIMULO_VM
        WHERE 1=1
            AND ORG_ID = p_org_id
            AND SEGMENT1 = p_inventory_item_id;

        RETURN v_estimulo_fis;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'NO';
    END get_estimulo_fiscal;  

    FUNCTION GET_VAL_SEGMENT (  P_Tipo_Transaccion  Varchar2,
                                P_Segmento  Number,
                                P_Segmento_Sio  Varchar2,
                                P_Cia  Varchar2,
                                P_Item  Varchar2,
                                P_Iva_0  Varchar2,
                                P_Excento  Varchar2,
                                P_Iva  Varchar2,
                                p_Iva_Tasa VARCHAR2,
                                P_Iva_Estimulo  Varchar2,
                                P_Ieps_Energetico  Varchar2,
                                P_Ieps_Calorico  Varchar2,
                                P_Ieps_Azucarado  Varchar2,
                                P_Ieps_Edulcorante  Varchar2,
                                P_Tipo_Cliente  Varchar2,
                                P_Bonificacion  Varchar2,
                                P_Linea_Negocio  Varchar2,
                                P_FRONTERA Varchar2,
                                P_TIPO_PEDIDO_OM Varchar2,
                                P_NO_CADENA Varchar2,
                                p_CODIGO_TRANSACCION_AR Varchar2,
                                P_SEGMENTO_OPM Varchar2)  Return Varchar
    IS
        cursor c_get_value is
        SELECT *
        FROM (
        With Tbl_Mapeo As
                (Select *--DISTINCT TIPO_TRANSACCION,SEGMENTO
                From apps.Xxar_Mapeo_Lines_Cust_sla
                Where 1=1
                )
            Select Segmento_Sio, Item, Iva_0, Excento, Iva, Iva_Estimulo, Ieps_Energetico, Ieps_Azucarado, Ieps_Calorico, Tipo_Cliente, Bonificacion, Linea_Negocio,Valor, tipo_pedido_om,SEGMENTO_OPM
                From Tbl_Mapeo
                where 1=1
                    AND TIPO_TRANSACCION =P_Tipo_Transaccion
                    AND SEGMENTO = P_Segmento
                    and case when cia is null then 1
                        when cia = P_Cia then 1
                        else null
                        end
                        is not null
                    and case when SEGMENTO_SIO is null then 1
                        when SEGMENTO_SIO = P_Segmento_Sio then 1
                        else null
                        end
                        is not null                    
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
                    and case when IEPS_CALORICO is null then 1
                        when IEPS_CALORICO = P_Ieps_Calorico then 1
                        else null
                        end
                        is not null
                    and case when IEPS_AZUCARADO is null then 1
                        when IEPS_AZUCARADO = P_Ieps_Azucarado then 1
                        else null
                        end
                        is not null
                    and case when IEPS_EDULCORANTE is null then 1
                        when IEPS_EDULCORANTE = P_Ieps_Edulcorante then 1
                        else null
                        end
                        is not null
                    and case when tipo_cliente is null then 1
                        when tipo_cliente = P_Tipo_Cliente then 1
                        else null
                        end
                        is not null
                     and case when bonificacion is null then 1
                        when bonificacion = P_Bonificacion then 1
                        else null
                        end
                        is not null/*
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
                    and case when no_cadena is null then 1
                        when no_cadena = P_NO_CADENA then 1
                        else null
                        end
                        is not null
                    and case when frontera is null then 1
                        when frontera = P_FRONTERA then 1
                        else null
                        end
                        is not null
                    and case when SEGMENTO_OPM is null then 1
                        when SEGMENTO_OPM = P_SEGMENTO_OPM then 1
                        else null
                        end
                        is not null    
                    /*and case when      is null then 1
                        when codigo_transaccion_ar = P_CODIGO_TRANSACCION_AR then 1
                        else null
                        end
                        is not null*/
                    /*and case when iva_tasa is null then 1
                        when iva_tasa = P_Iva_Tasa then 1
                        else null
                        end
                        is not null*/
                    --and rownum=1
                    Order By Segmento_Sio, Item, Iva_0, Excento, Iva, Iva_Estimulo, Ieps_Energetico, Ieps_Azucarado, Ieps_Calorico, Tipo_Cliente, Bonificacion, Linea_Negocio,tipo_pedido_om,SEGMENTO_OPM) T
                WHERE 1=1
                and rownum=1;

        v_return varchar2(100);
        BEGIN
        v_return := '-888';

        FOR cur IN c_get_value
        LOOP
            v_return := cur.valor;
        END LOOP;
        return v_return;
    END GET_VAL_SEGMENT;


 FUNCTION GET_SEGMENT_OPM(P_INVENTORY_ITEM_ID NUMBER)       
        RETURN VARCHAR2
    IS
        V_SEGMENT_OPM  VARCHAR2 (40);

    BEGIN


       IF P_INVENTORY_ITEM_ID IS NULL
        THEN         
            RETURN NULL;      
       ELSE  
            SELECT CAT.SEGMENT1    
              INTO V_SEGMENT_OPM
              FROM apps.mtl_item_categories_v cat
                   ,apps.mtl_system_items_b msib  
            WHERE 1=1
              AND msib.organization_id = 91 -- MAR Maestro de artículos
            --AND msib.segment1='98'
              AND cat.organization_id = msib.organization_id
              AND cat.inventory_item_id= msib.inventory_item_id 
              AND cat.category_set_name = 'OPM_SEGMENTO'
              and msib.inventory_item_id = P_INVENTORY_ITEM_ID;

            RETURN V_SEGMENT_OPM;       
      END IF;  

    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            V_SEGMENT_OPM :='SIN_SEGMENTO_OPM';
            RETURN V_SEGMENT_OPM;
        WHEN OTHERS
        THEN
            V_SEGMENT_OPM :='ERR_SEGMENTO_OPM';
            RETURN V_SEGMENT_OPM;
    END GET_SEGMENT_OPM;   


END XXCUST_SLA_AR_SOURCE_PKG;