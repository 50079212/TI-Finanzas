CREATE OR REPLACE PACKAGE BODY XXWEBC.XXAP_TRACKING_AP_PKG
AS
	--
	-- $Id: XXAP_TRACKING_AP_PKG.pkb 4745 2025-07-28 18:14:11Z cdavila $
	-- $HeadURL: http://mxapediprdl.gepp.pvt:18080/svn/r12/ap/ap_tracking/pkg/XXAP_TRACKING_AP_PKG.pkb $
    -- $Date: 2025-07-28 12:14:11 -0600 (lun., 28 jul. 2025) $
    --
    
    /* TABLA DE LOG DEL PROCESAMIENTO*/
    PROCEDURE  XXLOG(p_Level in NUMBER default 0
                    ,p_EXECUTION_ID in NUMBER default 0
                    ,p_INVOICE_ID in NUMBER default NULL
                    ,p_TEXT in VARCHAR2 default NULL
                    ,p_VALUE1STR in VARCHAR2 default NULL
                    ,p_VALUE2STR in VARCHAR2 default NULL
                    ,p_VALUE3STR in VARCHAR2 default NULL
                    ,p_VALUE1NUM in NUMBER default NULL
                    ,p_VALUE2NUM in NUMBER default NULL
                    ,p_VALUE3NUM in NUMBER default NULL
                    ,p_PROCESS_NAME in VARCHAR2 default NULL)
    AS
       -- pragma autonomous_transaction;
        -- p_Level  
        -- 0 Todo
        -- 1 error 
        -- 2 warning
        -- 3 message
        -- 4 debug
        v_id number;
    BEGIN
        IF p_Level <= vg_LevelLog  THEN
               SELECT XXAP_LOG_TRACK_INV_SEQ.NEXTVAL 
               INTO v_id
               FROM dual;

                insert into XXAP_LOG_TRACK_INV_TBL
                    (ID
                     ,EXECUTION_ID
                    ,INVOICE_ID
                    ,CREATION_DATE
                    ,TEXT
                    ,VALUE1STR
                    ,VALUE2STR
                    ,VALUE3STR
                    ,VALUE1NUM
                    ,VALUE2NUM
                    ,VALUE3NUM
                    ,PROCESS_NAME)
                values(v_id
                    ,p_EXECUTION_ID
                    ,p_INVOICE_ID
                    ,sysdate
                    ,p_TEXT
                    ,p_VALUE1STR
                    ,p_VALUE2STR
                    ,p_VALUE3STR
                    ,p_VALUE1NUM
                    ,p_VALUE2NUM
                    ,p_VALUE3NUM
                    ,p_PROCESS_NAME);                
        END IF;
        commit;
    END XXLOG;

    /* CONTROL DE MENSAJES IMPRESO EN LA SECCION DEL LOG */
    PROCEDURE MESSAGE_LOG (P_MESSAGE IN VARCHAR2, p_IsApp boolean DEFAULT TRUE)
    AS
    BEGIN
        if p_IsApp then
            APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, P_MESSAGE);
            --APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, P_MESSAGE);
            --DBMS_OUTPUT.PUT_LINE (P_MESSAGE);
        else
            DBMS_OUTPUT.PUT_LINE (P_MESSAGE);
        end if;
    END MESSAGE_LOG;

    /* CONTROL DE MENSAJES IMPRESOS EN EL OUPUT */
    PROCEDURE MESSAGE_OUTPUT (P_MESSAGE IN VARCHAR2, p_IsApp boolean DEFAULT TRUE)
    AS
    BEGIN
        if p_IsApp then
            APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, P_MESSAGE);
        end if;
        MESSAGE_LOG ('OUTPUT: ' || P_MESSAGE,p_IsApp);
    END MESSAGE_OUTPUT;

    procedure main(errbuf out varchar2, retcode out number,pin_ejecuta_dias in number, pin_fecha_barrido in varchar2)
    as 
        v_fecha_barrido date;
        v_user_id       number;
        v_id_execution number;

      es_fin_mes EXCEPTION;
      v_status_excecute_process varchar2(1000);
      v_status_code varchar2(2);
      v_msj_exception varchar2(1000);

      l_request_id number;
    BEGIN
      EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
      v_id_execution := to_char(sysdate,'YYYYMMDDHH24MISS');
      l_request_id := fnd_global.conc_request_id;

      v_status_excecute_process := STATUS_TO_EXCECUTE_THE_PROCESS('PROCESO1') || ' Requist_Id:'||l_request_id;
      v_status_code := substr(v_status_excecute_process,1,2);

      XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => 'v_status_code: ' || v_status_code || ' es cierre '|| CUST_AP_VALIDA_ES_CIERRE_FNC());

      IF v_status_code = 'NE' THEN
         v_msj_exception := v_status_excecute_process;
         raise es_fin_mes;
      ELSIF CUST_AP_VALIDA_ES_CIERRE_FNC() IN ('Y1') AND v_status_code = 'CA' THEN
         v_msj_exception := 'Y1 - '|| v_status_excecute_process;
         raise es_fin_mes;
      ELSIF CUST_AP_VALIDA_ES_CIERRE_FNC() IN ('Y2') THEN
         v_msj_exception := 'Y2 - '|| v_status_excecute_process;
         raise es_fin_mes;
      END IF;

           execute immediate 'ALTER SESSION SET NLS_LANGUAGE =  "LATIN AMERICAN SPANISH" ';



           XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => 'INICIA PROCESO');


            --dbms_output.put_line(v_id_execution || 'INICIA PROCESO');

           -- Obtiene el ID del usuario
           v_user_id := apps.FND_GLOBAL.USER_ID();
           vg_Resp_Id := 50671; -- Se inia en AP_BEPUSA_SISTEMAS
           -- Si regresa -1 es por no se lanzo desde la aplicación o no esta seteado el usuario
           IF  v_user_id = -1 THEN
                v_user_id := 1250; --Asigna el usuario 1250 que es Oracle en esta instancia de eBS
                --apps.fnd_global.apps_initialize 
                APPS.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize
                                       (puser_id        => v_user_id,
                                        presp_id        => vg_Resp_Id, --50671,--v_resp_id,    AP
                                        presp_appl_id   => 200 --v_resp_appl_id   AP_BEPUSA_SISTEMAS
                                       );

           END IF;   
           XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => 'User_Id :' || v_user_id);

           -- Determina los días hacia atras para barrer con base a la fecha de creación de las facturas
           if pin_ejecuta_dias = 0 then
                v_fecha_barrido := trunc(to_date(pin_fecha_barrido, 'dd-mm-yyyy')); -- Probar el formato cuando se asigne a un concurrente
           else
                v_fecha_barrido := trunc(sysdate)- abs(pin_ejecuta_dias);
           end if;

            XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => 'Fecha de barrrido :' || to_char(v_fecha_barrido,'DD-MM-YYYY'));


           -- Se valida si las facturas ya estan validadas (95) o contabilizadas (100)
           -- ya que estas no entran en juego nuevamente
           vg_msg := 'Begin call UPDATE_STATUS_INVOICES';
           XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => vg_msg);


           UPDATE_STATUS_INVOICES(v_id_execution,v_user_id);

           vg_msg := 'End call UPDATE_STATUS_INVOICES';

           XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => vg_msg);

           vg_msg := 'Begin call INSERT_DATA_INVOICES_AP_OC';
           XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => vg_msg);


           INSERT_DATA_INVOICES_AP_OC(v_user_id, v_id_execution, v_fecha_barrido);

           vg_msg := 'End call INSERT_DATA_INVOICES_AP_OC';
           XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => vg_msg);


           -- Llama al proceso para ver que regsitros son de Activo Fijo y si tienen retención 
           -- Si son de activo fijo el campo step_ctrl sera 20
           -- Si NO son de activo fijo sera el valor 30
           vg_msg := 'Begin call APPLY_HOLD_FA_XML';
           XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg);

           APPLY_HOLD_FA_XML(v_user_id,v_id_execution);

           vg_msg := 'End call APPLY_HOLD_FA_XML';
           XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg);

           --vg_msg := 'Begin call APPLY_HOLD_NC';
           --XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg);

           --APPLY_HOLD_NC(v_user_id,v_id_execution);

           --vg_msg := 'End call APPLY_HOLD_NC';
           --XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg);


           -- Se valida si las facturas ya pasaron por el proceso de cambio de número de factura
           -- ERS o USE por el número que trae el XML
           vg_msg := 'Begin call CHANGED_ERS_TO_XML';
           XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg);

           CHANGED_ERS_TO_XML(v_user_id,v_id_execution,v_fecha_barrido);

           vg_msg := 'End call CHANGED_ERS_TO_XML';
           XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg);

    EXCEPTION
      WHEN es_fin_mes THEN
         vg_msg := 'MAIN ES CIERRE DE MES ' || v_msj_exception;
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution, p_TEXT => vg_msg);
      WHEN OTHERS THEN
         vg_msg := 'MAIN ERROR OTHERS ' || SQLCODE;
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution, p_TEXT => vg_msg);

    end main;



    PROCEDURE INSERT_DATA_INVOICES_AP_OC(pin_user_id IN NUMBER, pin_id_executon IN NUMBER, pin_fecha_barrido  IN  DATE)
    IS

        --pin_ejecuta_dias number:=0; --0 por fecha, valor de la variable mayor a 0 los días a ejecutar atras
        --pin_fecha_barrido varchar2:='01-01-2024';

        v_fecha_barrido date;
        v_user_id       number;
        v_id_execution number;

            cursor c_organizations is
                select u.organization_id as org_id, u.name, u.attribute15 cia
                  from apps.FND_LOOKUP_VALUES_VL fv
                      ,hr.hr_all_organization_units u    
                 where 1=1
                   --AND u.organization_id !=86
                   AND fv.ENABLED_FLAG = 'Y'
                   AND NVL (fv.END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE
                   AND fv.LOOKUP_TYPE = 'CUST_AP_EMPRESAS_LKP'
                   and u.name = fv.meaning
                 order by u.organization_id;


           cursor c_datos (p_fecha_barrido date,p_org_id number) is
              SELECT distinct ai.org_id,
                     ai.invoice_id,
                     ai.creation_date creation_date_inv,
                     ai.invoice_num,
                     ai.source,
                     ai.invoice_type_lookup_code,
                     ai.payment_status_flag,
                     ai.invoice_date,
                     ai.invoice_currency_code,
                     ai.gl_date,
                     ai.invoice_amount,
                     ai.total_tax_amount,
                     case when ai.source = 'USE' THEN
                              (SELECT mp.organization_id --DISTINCT (mp.organization_id)
                                 FROM APPS.po_line_locations_all      pll1,
                                       apps.mtl_parameters             mp
                                 WHERE     pll1.po_header_id = poh.po_header_id     --36391993                                       
                                    AND mp.organization_id = pll1.ship_to_organization_id
                                    group by mp.organization_id)
                           WHEN ai.source = 'ERS' then
                              (select  rsh.ship_to_org_id
                                 from apps.ap_invoice_distributions_all  w
                                    ,apps.rcv_transactions              y
                                    ,apps.rcv_shipment_headers          rsh
                                 where 1=1
                                 and w.invoice_id = ai.invoice_id
                                 AND y.transaction_id = w.rcv_transaction_id
                                 AND rsh.shipment_header_id = y.shipment_header_id
                                 group by rsh.ship_to_org_id
                                 )
                           end
                           ship_to_org_id,
                     case when ai.source = 'USE' THEN
                              '1'
                           WHEN ai.source = 'ERS' then
                              (select rsh.receipt_num
                                 from apps.ap_invoice_distributions_all  w
                                    ,apps.rcv_transactions              y
                                    ,apps.rcv_shipment_headers          rsh
                                 where 1=1
                                 and w.invoice_id = ai.invoice_id
                                 AND y.transaction_id = w.rcv_transaction_id
                                 AND rsh.shipment_header_id = y.shipment_header_id
                                 group by rsh.receipt_num)
                           end
                           receipt_num,
                           case when ai.source = 'USE' THEN
                              0
                           WHEN ai.source = 'ERS' then
                              (select rsh.shipment_header_id
                                 from apps.ap_invoice_distributions_all  w
                                    ,apps.rcv_transactions              y
                                    ,apps.rcv_shipment_headers          rsh
                                 where 1=1
                                 and w.invoice_id = ai.invoice_id
                                 AND y.transaction_id = w.rcv_transaction_id
                                 AND rsh.shipment_header_id = y.shipment_header_id
                                 AND rownum<=1
                                 group by rsh.shipment_header_id)
                           end
                           shipment_header_id,
                     pv.segment1                            num_proveedor,
                     pv.vendor_name                         nombre_proveedor,
                     pv.num_1099                            rfc_proveedor,
                     ai.vendor_id,
                     XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'ALL', 'ALL')             num_holds,
                     XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'ALL', 'ACT')           num_holds_act,
                     NVL((SELECT MAX (psu.vendor_id)
                            FROM apps.pos_supplier_users_v psu
                           WHERE psu.vendor_id = ai.vendor_id), 0)  ProvReg_iSuppl,
                     (select segment1
                        from (
                              select imb.segment1
                                from ap.ap_invoice_distributions_all  aida
                                    ,po.po_distributions_all          pda
                                    ,po.po_lines_all                  pla
                                    ,inv.mtl_categories_b             imb
                               where 1=1
                                 and aida.org_id                = ai.org_id
                                 and aida.invoice_id            = ai.invoice_id
                                 AND aida.line_type_lookup_code in ('ACCRUAL', 'ITEM')
                                 AND pda.po_distribution_id     = aida.po_distribution_id 
                                 AND pla.po_header_id           = pda.po_header_id 
                                 AND imb.category_id            = pla.category_id
                               group by imb.segment1
                             )
                        where rownum = 1) categoria,
                     (select segment5
                        from (
                              select case when gcc.segment5 IN (1713,1714,1715,1716) then 1  else  0 end segment5 
                                from ap.ap_invoice_distributions_all  aida
                                    ,po.po_distributions_all          pda
                                    ,po.po_lines_all                  pla
                                    ,inv.mtl_categories_b             imb
                                    ,gl.gl_code_combinations          gcc
                               where 1=1
                                 and aida.org_id                = ai.org_id
                                 and aida.invoice_id            = ai.invoice_id
                                 AND aida.line_type_lookup_code in ('ACCRUAL', 'ITEM')
                                 AND pda.po_distribution_id     = aida.po_distribution_id 
                                 AND pla.po_header_id           = pda.po_header_id 
                                 AND imb.category_id            = pla.category_id
                                 AND gcc.code_combination_id    = aida.dist_code_combination_id
                               group by gcc.segment5
                             )
                       where rownum = 1) fa_exclude,
                     XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'Falta Validacion AF', 'ALL') fa_hold,
                     XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'Falta Validacion AF', 'STATUS') fa_hold_status,
                     XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'Falta XML', 'ALL')  xml_hold, -- Falta XML iSupplier
                     XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'Falta XML', 'STATUS') xml_hold_status,
                     poh.po_header_id,
                     poh.segment1 oc,
                     apps.ap_invoices_pkg.get_approval_status (ai.invoice_id,
                                                          ai.invoice_amount,
                                                          ai.payment_status_flag,
                                                          ai.invoice_type_lookup_code) approval_status,
                     ap_invoices_pkg.get_posting_status(ai.invoice_id) posting_status

                     ,XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'Proveedor Extranjero', 'ALL')  foreign_hold
                     ,XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'Proveedor Extranjero', 'STATUS') foreign_hold_status
                     ,XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'SE ENCUENTRA EN PROCESO DE LIBERACION', 'ALL')  funds_hold
                     ,XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'SE ENCUENTRA EN PROCESO DE LIBERACION', 'STATUS') funds_hold_status
                     ,XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'Dif en Impuestos CUST','ALL')--'Diferencia en Impuesto', 'ALL')  
                      difference_tax_hold
                     ,XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'Dif en Impuestos CUST','STATUS')--'Diferencia en Impuesto', 'STATUS') 
                      difference_tax_hold_status
                     ,XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'Factura Partida', 'ALL')  splited_invoice_hold
                     ,XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'Factura Partida', 'STATUS') splited_invoice_hold_status
                     ,XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'Other Holds', 'ALL')  other_holds
                     ,XXAP_TRACKING_AP_PKG.GET_COUNT_HOLD(ai.invoice_id, 'Other Holds', 'STATUS') other_holds_status
                     ,ass.vendor_site_id
                     ,ass.vendor_site_code
                     ,case when ass.vendor_site_code in ('RET ACT EMP RESICO'
                                                         ,'RET ARRENDAMIENTOS RESICO'
                                                         ,'RET HONORARIOS RESICO'
                                                         ,'RET RESICO PF IS') THEN
                              'Y'
                           else
                              'N'
                           END supplier_resico
                     ,XXAP_TRACKING_AP_PKG.IS_FOREIGN_SUPPLIER(ai.vendor_id, ai.vendor_site_id) foreign_supplier
                     -- select ai.*
                from ap_invoices_all ai,
                     po_vendors pv,
                     ap_invoice_lines_all ail,
                     apps.po_headers_all poh
                     ,apps.ap_supplier_sites_all ass
               where 1 = 1
                 AND ai.invoice_id not in (36703346,36676743,36703144) -- falta meter control para facturas que tengan mas de una recepción
                 and apps.ap_invoices_pkg.get_approval_status (ai.invoice_id,
                                                               ai.invoice_amount,
                                                               ai.payment_status_flag,
                                                               ai.invoice_type_lookup_code) IN ('NEEDS REAPPROVAL', 'NEVER APPROVED')
                 and ap_invoices_pkg.get_posting_status(ai.invoice_id) = 'N'
                 and not exists (select 1 from xxwebc.XXAP_TRACKING_INVOICES_TBL tbl where tbl.invoice_id = ai.invoice_id)

                 and ai.payment_status_flag  = 'N'
                 and ai.org_id               = p_org_id--84--fnd_global.org_id
                 --and ai.creation_date       >= to_date('01-06-2024','dd-mm-yyyy')
                 and ai.creation_date       >= p_fecha_barrido--to_date('01-01-2024','dd-mm-yyyy')
                 and ai.source              in ('ERS','USE','RTS')-- Validar nombre
                 and ail.org_id              = ai.org_id
                 and ail.invoice_id          = ai.invoice_id
                 and poh.org_id              = ail.org_id
                 and poh.po_header_id        = ail.po_header_id
                 and ail.po_header_id is not null
                 and ai.cancelled_date      is null
                 and ai.vendor_id            = pv.vendor_id
                 and ass.vendor_id = ai.vendor_id
                 and ass.vendor_site_id = ai.vendor_site_id;
        --         and rownum < 10;

        begin
        --
           EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
           v_fecha_barrido :=pin_fecha_barrido;
           v_user_id       :=pin_user_id;
           v_id_execution := pin_id_executon;

           vg_msg := 'Begin INSERT_DATA_INVOICES_AP_OC';
           XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg);





           for cur_org in c_organizations 
           loop
                vg_msg := 'Begin Org_id: '|| cur_org.org_id || ' Nombre:' || cur_org.name;
                XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg, p_value1num => cur_org.org_id ,p_value1str => cur_org.name, p_value2str => to_char(v_fecha_barrido,'dd-mm-yyyy'));

               for i in c_datos(v_fecha_barrido, cur_org.org_id) 
               loop
                    vg_msg := 'INVOICE';
                    XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => i.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_org.org_id ,p_value1str => cur_org.name);


                     insert into xxwebc.XXAP_TRACKING_INVOICES_TBL
                                 ( invoice_id                 , org_id                     ,creation_date_inv           , invoice_num                , invoice_num_ers            
                                  ,vendor_id                  , source                     , invoice_type_lookup_code   , payment_status_flag        
                                  ,invoice_date               , provreg_isuppl             , categoria                 
                                  ,FA_EXCLUDE                 , po_header_id               , orden_compra               
                                  ,num_proveedor              , nombre_proveedor           , rfc_proveedor              , approval_status            
                                  ,posting_status             , creation_date              , created_by                 , last_update_date           
                                  ,last_updated_by            , step_ctrl  
                                  ,execution_id               , period_name                , cia_name                   , cia
                                  ,NUM_HOLDS                  , NUM_HOLDS_ACT              ,XML_HOLD                    ,FA_HOLD
                                  ,XML_HOLD_STATUS            , FA_HOLD_STATUS             ,SHIP_TO_ORG_ID              ,RECEIPT_NUM
                                  ,SHIPMENT_HEADER_ID         ,GL_DATE                    ,INVOICE_CURRENCY_CODE
                                  ,FOREIGN_HOLD               ,FOREIGN_HOLD_STATUS        ,FUNDS_HOLD                  ,FUNDS_HOLD_STATUS
                                  ,OTHER_HOLDS                ,OTHER_HOLDS_STATUS
                                  ,VENDOR_SITE_ID             ,VENDOR_SITE_CODE           ,FOREIGN_SUPPLIER
                                  ,DIFFERENCE_TAX_HOLD        ,DIFFERENCE_TAX_HOLD_STATUS ,SPLITED_INVOICE_HOLD         ,SPLITED_INVOICE_HOLD_STATUS
                                  ,INVOICE_AMOUNT             ,SUPPLIER_RESICO            ,TOTAL_TAX_AMOUNT
                                 )
                          values ( i.invoice_id               , i.org_id                   ,i.creation_date_inv         , i.invoice_num              , i.invoice_num
                                  ,i.vendor_id                , i.source                   , i.invoice_type_lookup_code , i.payment_status_flag      
                                  ,i.invoice_date             , i.provreg_isuppl           , i.categoria                
                                  ,i.fa_exclude               , i.po_header_id             , i.oc                       
                                  ,i.num_proveedor            , i.nombre_proveedor         , i.rfc_proveedor            , i.approval_status          
                                  ,i.posting_status           , sysdate                    , v_user_id                  , sysdate                    
                                  ,v_user_id                  , 1
                                  ,v_id_execution             , to_char(i.invoice_date, 'MON-YY'), cur_org.name         , cur_org.cia
                                  ,i.num_holds                , i.num_holds_act             , i.xml_hold                , i.fa_hold        
                                  ,i.xml_hold_status          , i.fa_hold_status            , i.ship_to_org_id          , i.receipt_num
                                  ,i.shipment_header_id       , i.gl_date                   , i.invoice_currency_code
                                  ,i.foreign_hold             , i.foreign_hold_status       , i.funds_hold              , i.funds_hold_status
                                  ,i.other_holds              , i.other_holds_status
                                  ,i.vendor_site_id           , i.vendor_site_code          , i.foreign_supplier
                                  ,i.difference_tax_hold      , i.difference_tax_hold_status, i.splited_invoice_hold    , i.splited_invoice_hold_status
                                  ,i.invoice_amount           , i.supplier_resico           , i.total_tax_amount
                                 );


               end loop;
               commit; -- Hace commit por compañia

               vg_msg := 'End Org_id: '|| cur_org.org_id || ' Nombre:' || cur_org.name;
               XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg, p_value1num => cur_org.org_id ,p_value1str => cur_org.name);
           end loop;
           vg_msg := 'End INSERT_DATA_INVOICES_AP_OC';
           XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg);

    END INSERT_DATA_INVOICES_AP_OC;

    PROCEDURE APPLY_HOLD_FA_XML(pin_user_id IN NUMBER, pin_id_executon IN NUMBER)
    is
      v_id_execution NUMBER;
      v_resp number;
      v_org_id number;
      v_user_id number;
      v_process_name varchar2(100);
      v_result_num number;
    begin
        v_process_name := 'APPLY_HOLD_FA_XML';
        v_user_id := pin_user_id;
        v_org_id := 0;
        v_id_execution := pin_id_executon;
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';

        -- Validar si tiene retencion de XML o Proveedor extranjero
        -- Se actualiza nuevamente por los registros pasados que no haya podido procesar en ejecuciones anteriores
        /*UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
        SET  XML_HOLD = GET_COUNT_HOLD(ai.invoice_id, 'Falta XML', 'ALL')
            ,XML_HOLD_STATUS = GET_COUNT_HOLD(ai.invoice_id, 'Falta XML', 'STATUS')
            ,NUM_HOLDS =  GET_COUNT_HOLD(ai.invoice_id, 'ALL', 'ALL')
            ,NUM_HOLDS_ACT =  GET_COUNT_HOLD(ai.invoice_id, 'ALL', 'ACT')
        WHERE 1 = 1
        AND STEP_CTRL = 1
        AND XML_HOLD = 0;*/

         FOR cur IN (SELECT INVOICE_ID
                     FROM XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
                     WHERE 1=1
                     AND source in ('ERS','USE')
                     AND STEP_CTRL = 1
                     AND XML_HOLD = 0
                     AND FOREIGN_HOLD = 0
                     )
         LOOP
            UPDATE_ROW_TRACKING(cur.invoice_id, v_user_id,v_process_name||'_1');
         END LOOP;


        -- xml_hold_act = 0 
        -- foreign_supplier = 'N'
        -- insertar retencion de XML
        FOR c_xml IN (SELECT ORG_ID, INVOICE_ID,INVOICE_NUM                           
                        FROM XXWEBC.XXAP_TRACKING_INVOICES_TBL
                       WHERE 1               = 1
                         --AND INVOICE_ID = 33426565
                         AND STEP_CTRL       = 1
                         AND XML_HOLD = 0
                         AND foreign_supplier = 'N'
                         AND SOURCE IN ('ERS','USE') -- Al momento son los que se detectan con retención
                         AND approval_status IN ('NEEDS REAPPROVAL', 'NEVER APPROVED')
                     ORDER BY ORG_ID)
        LOOP

            if v_org_id != c_xml.org_id then
               v_org_id := c_xml.org_id;
               vg_Resp_Id := GET_RESP_ID(v_id_execution,c_xml.INVOICE_ID);
               -- Setea 
               APPS.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize(puser_id        => v_user_id,
                                                                  presp_id        => vg_Resp_Id, --50671,--v_resp_id,    AP
                                                                  presp_appl_id   => 200 --v_resp_appl_id   AP_BEPUSA_SISTEMAS
                                                                  );
            end if;
            vg_msg := 'Insert Hold Falta XML (Debug Before) Org_Id:'|| c_xml.org_id || ' Invoice_Id:' || c_xml.invoice_id || ' Invoice_num:'|| c_xml.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_xml.invoice_id ,p_TEXT => vg_msg, p_value1num => c_xml.org_id);

            APPLY_HOLD_INV(v_id_execution, pin_user_id, c_xml.invoice_id, 1, v_resp);
            vg_msg := 'Insert Hold Falta XML (Debug After) Org_Id:'|| c_xml.org_id || ' Invoice_Id:' || c_xml.invoice_id || ' Invoice_num:'|| c_xml.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_xml.invoice_id ,p_TEXT => vg_msg, p_value1num => c_xml.org_id);

            -- Actualiza los campos del xml_hold
            UPDATE_ROW_TRACKING(c_xml.invoice_id, v_user_id,v_process_name||'_2');
            /*UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
            SET  XML_HOLD = GET_COUNT_HOLD(ai.invoice_id, 'Falta XML', 'ALL')
                ,XML_HOLD_STATUS = GET_COUNT_HOLD(ai.invoice_id, 'Falta XML', 'STATUS')
               ,NUM_HOLDS = GET_COUNT_HOLD(ai.invoice_id, 'ALL', 'ALL')
               ,NUM_HOLDS_ACT = GET_COUNT_HOLD(ai.invoice_id, 'ALL', 'ACT')
               ,last_updated_by = pin_user_id
            WHERE 1 = 1
            AND STEP_CTRL = 1
            and invoice_id = c_xml.invoice_id;

            COMMIT;*/
            vg_msg := 'Insert Hold XML (Debug Updated count) Org_Id:'|| c_xml.org_id || ' Invoice_Id:' || c_xml.invoice_id || ' Invoice_num:'|| c_xml.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_xml.invoice_id ,p_TEXT => vg_msg, p_value1num => c_xml.org_id);
        END LOOP;

        -- foreign_hold = 0 
        -- foreign_supplier = 'Y'
        -- insertar retencion de Proveedor Extranjero
        FOR c_provext IN (SELECT ORG_ID, INVOICE_ID,INVOICE_NUM                           
                        FROM XXWEBC.XXAP_TRACKING_INVOICES_TBL
                       WHERE 1               = 1
                         --AND INVOICE_ID = 33426565
                         AND STEP_CTRL       = 1
                         AND FOREIGN_HOLD = 0
                         AND foreign_supplier = 'Y'
                         AND SOURCE IN ('ERS','USE') -- Al momento son los que se detectan con retención
                         AND approval_status IN ('NEEDS REAPPROVAL', 'NEVER APPROVED')
                     ORDER BY ORG_ID)
        LOOP

            if v_org_id != c_provext.org_id then
               v_org_id := c_provext.org_id;
               vg_Resp_Id := GET_RESP_ID(v_id_execution,c_provext.INVOICE_ID);
               -- Setea 
               APPS.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize(puser_id        => v_user_id,
                                                                  presp_id        => vg_Resp_Id, --50671,--v_resp_id,    AP
                                                                  presp_appl_id   => 200 --v_resp_appl_id   AP_BEPUSA_SISTEMAS
                                                                  );
            end if;
            vg_msg := 'Insert Hold Proveedor Extranjero (Debug Before) Org_Id:'|| c_provext.org_id || ' Invoice_Id:' || c_provext.invoice_id || ' Invoice_num:'|| c_provext.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_provext.invoice_id ,p_TEXT => vg_msg, p_value1num => c_provext.org_id);

            APPLY_HOLD_INV(v_id_execution, pin_user_id, c_provext.invoice_id, 6, v_resp);
            vg_msg := 'Insert Hold Proveedor Extranjero (Debug After) Org_Id:'|| c_provext.org_id || ' Invoice_Id:' || c_provext.invoice_id || ' Invoice_num:'|| c_provext.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_provext.invoice_id ,p_TEXT => vg_msg, p_value1num => c_provext.org_id);

            -- Actualiza los campos del proveedor extranjero
            UPDATE_ROW_TRACKING(c_provext.invoice_id, v_user_id,v_process_name||'_3');

            vg_msg := 'Insert Hold Proveedor (Debug Updated count) Org_Id:'|| c_provext.org_id || ' Invoice_Id:' || c_provext.invoice_id || ' Invoice_num:'|| c_provext.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_provext.invoice_id ,p_TEXT => vg_msg, p_value1num => c_provext.org_id);

            -- If exist hold Falta XML in teh row is necesary remove it.
            -- 2 Is exits hols and it´s active
            IF GET_COUNT_HOLD(c_provext.invoice_id, 'Falta XML', 'STATUS') =2 THEN
               -- Remove hold
               -- Remove hold Falta XML
                  vg_msg := 'Proveedor Extranjero CHANGED_ERS_TO_XML (Debug Before) -- Remueve Falta XML Org_Id:'|| c_provext.org_id || ' Invoice_Id:' || c_provext.invoice_id || ' Invoice_num:'|| c_provext.invoice_num;
                  XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_provext.invoice_id ,p_TEXT => vg_msg, p_value1num => c_provext.org_id
                        );

                  UNAPPLY_HOLD_INV(v_id_execution, pin_user_id, c_provext.invoice_id, 1, v_result_num);

                  vg_msg := 'Proveedor Extranjero CHANGED_ERS_TO_XML (Debug After) -- Remueve Falta XML Org_Id:'|| c_provext.org_id || ' Invoice_Id:' || c_provext.invoice_id || ' Invoice_num:'|| c_provext.invoice_num;
                  XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_provext.invoice_id ,p_TEXT => vg_msg, p_value1num => c_provext.org_id
                        );
                  UPDATE_ROW_TRACKING(c_provext.invoice_id, v_user_id,v_process_name||'_3');
            END IF;
        END LOOP;

        -- Coloca la retención de FA si es necesario.
        -- Se valida si necesita la retención de activo fijo y se la coloca
           -- NA no aplica
           -- NO es por que ya tenia la retención por otro medio
           -- SI es por que este proceso la colocara
        UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL
           SET APPLIED_HOLD_FA       = 'NA'             
              ,last_updated_by = pin_user_id
              ,LAST_UPDATE_DATE = sysdate
         WHERE 1                     = 1
           AND STEP_CTRL             = 1
           AND CATEGORIA            != 'ACTIVO FIJO'
           AND SOURCE IN ('ERS','USE') ;

           COMMIT;       

        UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL
           SET APPLIED_HOLD_FA      = 'NA'           
              ,last_updated_by = pin_user_id
              ,LAST_UPDATE_DATE = sysdate
         WHERE 1                    = 1
           AND STEP_CTRL            = 1
           AND CATEGORIA            = 'ACTIVO FIJO'
           AND FA_EXCLUDE          != 0  -- 0 SE INCLUYE DIFERENTE DE 0 SE EXCLUYE           
           AND SOURCE IN ('ERS','USE') 
           ;
           COMMIT;

           -- Se coloca SI ya que este proceso intentara poner la retención
        UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL
           SET APPLIED_HOLD_FA       = 'SI'
              ,last_updated_by = pin_user_id
              ,LAST_UPDATE_DATE = sysdate
         WHERE 1                     = 1
           AND STEP_CTRL             = 1
           AND CATEGORIA             = 'ACTIVO FIJO'
           AND (APPLIED_HOLD_FA  NOT IN ('NO','NA') OR APPLIED_HOLD_FA IS NULL)           
           AND SOURCE IN ('ERS','USE') 
           ;
           commit;

        -- Se actualiza nuevamente por los registros pasados que no haya podido procesar en ejecuciones anteriores
        /*UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
        SET  FA_HOLD = GET_COUNT_HOLD(ai.invoice_id, 'Falta Validacion AF', 'ALL')
            ,FA_HOLD_STATUS = GET_COUNT_HOLD(ai.invoice_id, 'Falta Validacion AF', 'STATUS')
            ,NUM_HOLDS =  GET_COUNT_HOLD(ai.invoice_id, 'ALL', 'ALL')
            ,NUM_HOLDS_ACT =  GET_COUNT_HOLD(ai.invoice_id, 'ALL', 'ACT')
            ,last_updated_by = pin_user_id
            ,LAST_UPDATE_DATE = sysdate
        WHERE 1 = 1
        AND STEP_CTRL = 1
        AND APPLIED_HOLD_FA = 'SI'
        AND FA_HOLD = 0 
        AND SOURCE IN ('ERS','USE') ;*/

         FOR cur IN (SELECT INVOICE_ID
                     FROM XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
                     WHERE 1=1
                     AND STEP_CTRL = 1
                     AND APPLIED_HOLD_FA = 'SI'
                     AND FA_HOLD = 0 
                     AND SOURCE IN ('ERS','USE') 
                     )
         LOOP
            UPDATE_ROW_TRACKING(cur.invoice_id, v_user_id,v_process_name||'_4');
         END LOOP;

        FOR c_fa IN (SELECT ORG_ID, INVOICE_ID,INVOICE_NUM
                        FROM XXWEBC.XXAP_TRACKING_INVOICES_TBL
                       WHERE 1               = 1
                         AND STEP_CTRL       = 1
                         AND FA_HOLD = 0
                         AND APPLIED_HOLD_FA = 'SI'
                         AND approval_status IN ('NEEDS REAPPROVAL', 'NEVER APPROVED')
                         AND SOURCE IN ('ERS','USE') 
                     ORDER BY ORG_ID)
        LOOP
            if v_org_id != c_fa.org_id then
               v_org_id := c_fa.org_id;
               vg_Resp_Id := GET_RESP_ID(v_id_execution,c_fa.INVOICE_ID);
               -- Setea 
               APPS.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize(puser_id        => v_user_id,
                                                               presp_id        => vg_Resp_Id, --50671,--v_resp_id,    AP
                                                               presp_appl_id   => 200 --v_resp_appl_id   AP_BEPUSA_SISTEMAS
                                                               );
            end if;

            vg_msg := 'Insert Hold Activo Fijo (Debug Before) Org_Id:'|| c_fa.org_id || ' Invoice_Id:' || c_fa.invoice_id || ' Invoice_num:'|| c_fa.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_fa.invoice_id ,p_TEXT => vg_msg, p_value1num => c_fa.org_id);
            APPLY_HOLD_INV(v_id_execution, pin_user_id, c_fa.invoice_id, 4, v_resp);

            vg_msg := 'Insert Hold Activo Fijo (Debug After) Org_Id:'|| c_fa.org_id || ' Invoice_Id:' || c_fa.invoice_id || ' Invoice_num:'|| c_fa.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_fa.invoice_id ,p_TEXT => vg_msg, p_value1num => c_fa.org_id);

            -- Actualiza los campos del fa_hold
            /*UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
            SET  FA_HOLD = GET_COUNT_HOLD(ai.invoice_id, 'Falta Validacion AF', 'ALL')
                ,FA_HOLD_STATUS = GET_COUNT_HOLD(ai.invoice_id, 'Falta Validacion AF', 'STATUS')
               ,NUM_HOLDS = GET_COUNT_HOLD(ai.invoice_id, 'ALL', 'ALL')
               ,NUM_HOLDS_ACT = GET_COUNT_HOLD(ai.invoice_id, 'ALL', 'ACT')
               ,last_updated_by = pin_user_id
               ,LAST_UPDATE_DATE = sysdate
            WHERE 1 = 1
            AND STEP_CTRL = 1
            and invoice_id = c_fa.invoice_id;

            COMMIT;*/
            UPDATE_ROW_TRACKING(c_fa.invoice_id, v_user_id,v_process_name||'_5');
        END LOOP;

        -- Para cambiar de estatus de 1 a 5 el valor del campo step_ctrl será necesario:
        -- XML_HOLD > 0
        -- FA_FOLD > 0 y APPLIED_HOLD_FA sea SI
        UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
        SET STEP_CTRL = 5
            ,last_updated_by = pin_user_id
            ,LAST_UPDATE_DATE = sysdate
        WHERE 1=1
        AND STEP_CTRL = 1
        AND SOURCE IN ('ERS','USE') 
        AND (XML_HOLD > 0 OR FOREIGN_HOLD > 0)
        AND approval_status IN ('NEEDS REAPPROVAL', 'NEVER APPROVED')
        AND CASE WHEN APPLIED_HOLD_FA = 'SI' AND FA_HOLD > 0 THEN 'OK'
                 ELSE 'OK'
                 END  = 'OK';
        COMMIT;

    end APPLY_HOLD_FA_XML;


    PROCEDURE CHANGED_ERS_TO_XML(pin_user_id IN NUMBER,pin_id_executon IN NUMBER, pin_fecha_barrido  IN  DATE)
    IS
      v_fecha_barrido date;
      v_id_execution number;
      --v_resultado  VARCHAR2 (10);
      v_result_num number;
      v_result_str varchar2(20);
      v_result_msg_str varchar2(1000);
      v_resp number;
      v_invoice_num_new varchar2(100);
      v_org_id number;
      v_user_id number;
      v_splited_invoice boolean;

      es_fin_mes EXCEPTION;
      v_status_excecute_process varchar2(1000);
      v_status_code varchar2(2);
      v_msj_exception varchar2(1000);
      l_request_id number;

      v_UUID_Validar VARCHAR2(100);
      v_existe_UUID NUMBER;
    BEGIN
      EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
      v_user_id := pin_user_id;
      v_org_id := 0;
      v_id_execution := pin_id_executon;
      v_fecha_barrido := trunc(pin_fecha_barrido);

      l_request_id := fnd_global.conc_request_id;

      v_status_excecute_process := STATUS_TO_EXCECUTE_THE_PROCESS('PROCESO2') || ' Requist_Id:'||l_request_id;
      v_status_code := substr(v_status_excecute_process,1,2);

      IF v_status_code = 'NE' THEN
         v_msj_exception := v_status_excecute_process;
         raise es_fin_mes;
      ELSIF CUST_AP_VALIDA_ES_CIERRE_FNC() IN ('Y1') AND v_status_code = 'CA' THEN
         v_msj_exception := 'Y1 - '|| v_status_excecute_process;
         raise es_fin_mes;
      ELSIF CUST_AP_VALIDA_ES_CIERRE_FNC() IN ('Y2') THEN
         v_msj_exception := 'Y2 - '|| v_status_excecute_process;
         raise es_fin_mes;
      END IF;



      vg_msg := 'CHANGED_ERS_TO_XML Begin ' ;
      XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution  ,p_TEXT => vg_msg);

      -- Con base a la fecah de barrido vemos si llegaron nuevos XML para actualizar
      FOR cur_xml_load in /*(SELECT mp.organization_id ship_to_org_id
                           ,y.numero_recepcion receipt_num
                           ,y.orden_compra
                           ,nvl((y.serie_factura || y.folio_factura), y.folio_fiscal) seriefolio,                           
                           y.bodega,
                           y.atributo2 tolerancia,
                           upper(y.folio_fiscal) uuid
                           ,ti.org_id
                           ,ti.invoice_id
                           ,ti.invoice_num
                           ,y.total
                           ,y.subtotal
                           ,MAX(y.id_carga_xml) id_carga_xml
                           ,MAX(y.fecha_recepcion_xml) fecha_recepcion_xml
                           ,ti.vendor_id
                           ,ti.vendor_site_id
                           ,ti.vendor_site_code
                           ,ti.invoice_amount
                           ,ti.supplier_resico
                           ,ti.total_tax_amount
                        FROM apps.cargafacturasxml y
                           , mtl_parameters mp
                           ,XXAP_TRACKING_INVOICES_TBL ti
                           ,ap_invoices_all ai
                        WHERE 1=1
                        --and ai.invoice_id =31493488
                        AND Y.FECHA_RECEPCION_XML >= v_fecha_barrido--SYSDATE-30
                        AND mp.organization_code = SUBSTR (y.bodega, 1, 3)
                        and mp.organization_id = ti.SHIP_TO_ORG_ID
                        AND y.numero_recepcion = ti.receipt_num
                        AND y.orden_compra = ti.orden_compra
                        and ti.UPDATED_DATA_FROM_XML is null
                        and ai.invoice_id = ti.invoice_id
                        AND apps.ap_invoices_pkg.get_approval_status (ai.invoice_id,
                                                                                 ai.invoice_amount,
                                                                                 ai.payment_status_flag,
                                                                                 ai.invoice_type_lookup_code) IN ('NEEDS REAPPROVAL', 'NEVER APPROVED')
                        GROUP BY mp.organization_id 
                           ,y.numero_recepcion 
                           ,y.orden_compra
                           ,nvl((y.serie_factura || y.folio_factura), y.folio_fiscal) ,                           
                           y.bodega,
                           y.atributo2 ,
                           y.folio_fiscal 
                           ,ti.org_id
                           ,ti.invoice_id
                           ,ti.invoice_num
                           ,y.total
                           ,y.subtotal
                           ,ti.vendor_id
                           ,ti.vendor_site_id
                           ,ti.vendor_site_code
                           ,ti.invoice_amount
                           ,ti.supplier_resico
                           ,ti.total_tax_amount
                        order by ti.org_id,id_carga_xml)*/
      					(SELECT mp.organization_id ship_to_org_id
                           ,y.numero_recepcion receipt_num
                           ,y.orden_compra
                           ,nvl((y.serie_factura || y.folio_factura), y.folio_fiscal) seriefolio,                           
                           y.bodega,
                           y.atributo2 tolerancia,
                           upper(y.folio_fiscal) uuid
                           ,ti.org_id
                           ,ti.invoice_id
                           ,ti.invoice_num
                           ,y.total
                           ,y.subtotal
                           ,y.id_carga_xml id_carga_xml
                           ,y.fecha_recepcion_xml fecha_recepcion_xml
                           ,ti.vendor_id
                           ,ti.vendor_site_id
                           ,ti.vendor_site_code
                           ,ti.invoice_amount
                           ,ti.supplier_resico
                           ,ti.total_tax_amount
                        FROM apps.cargafacturasxml y
                           , mtl_parameters mp
                           ,XXAP_TRACKING_INVOICES_TBL ti
                           ,ap_invoices_all ai
                           ,(SELECT MAX(y.id_carga_xml) id_carga_xml
		                           ,MAX(y.fecha_recepcion_xml) fecha_recepcion_xml   
		                           ,y.orden_compra
		                           ,y.numero_recepcion
		                           ,y.unidad_operativa
		                        FROM apps.cargafacturasxml y   
		                        	,XXAP_TRACKING_INVOICES_TBL ti
		                        WHERE 1=1
		                        AND ti.source in ('ERS','USE')
		                        AND Y.FECHA_RECEPCION_XML >= v_fecha_barrido--SYSDATE-30 
		                        AND y.numero_recepcion = ti.receipt_num
		                        AND y.orden_compra = ti.orden_compra
		                        and ti.UPDATED_DATA_FROM_XML is null
		                        GROUP BY y.orden_compra
		                           ,y.numero_recepcion
		                           ,y.unidad_operativa) y_agr
                        WHERE 1=1
                        --and ai.invoice_id =36057554
                        --AND Y.FECHA_RECEPCION_XML >= v_fecha_barrido--SYSDATE-30
                        AND mp.organization_code = SUBSTR (y.bodega, 1, 3)
                        and mp.organization_id = ti.SHIP_TO_ORG_ID
                        AND y.numero_recepcion = ti.receipt_num
                        AND y.orden_compra = ti.orden_compra
                        AND Y.ID_CARGA_XML  =y_agr.ID_CARGA_XML
                        --and ti.UPDATED_DATA_FROM_XML is null
                        and ai.invoice_id = ti.invoice_id
                        AND apps.ap_invoices_pkg.get_approval_status (ai.invoice_id,
                                                                                 ai.invoice_amount,
                                                                                 ai.payment_status_flag,
                                                                                 ai.invoice_type_lookup_code) IN ('NEEDS REAPPROVAL', 'NEVER APPROVED')
                        -- Se procesan solo las transacciones y UUID que no esten ligados a otra factura que este en estatus
                        -- Nunca validado, necesita revalidación o validado
                        AND NOT EXISTS (SELECT 'ex'
                        				FROM APPS.XXPOS_ACTFACTURA P	
                        					,ap_invoices_all ai2
              							WHERE 1=1
              							AND P.ATRIBUTO3 = y.folio_fiscal
              							AND P.AP_INVOICE_ID =ai2.INVOICE_ID
              							AND apps.ap_invoices_pkg.get_approval_status (ai2.invoice_id,
                                                                                 ai2.invoice_amount,
                                                                                 ai2.payment_status_flag,
                                                                                 ai2.invoice_type_lookup_code) IN ('NEEDS REAPPROVAL', 'NEVER APPROVED','APPROVED')
                                                                                 )
                         
                          AND Y.ID_CARGA_XML >= (SELECT nvl(max(p.ATRIBUTO4),Y.ID_CARGA_XML) AS id_carga_xml
				                				FROM APPS.XXPOS_ACTFACTURA P	
				                					,ap_invoices_all ai2
				      							WHERE 1=1
				      							AND P.ATRIBUTO3 = y.folio_fiscal
				      							AND P.AP_INVOICE_ID =ai2.INVOICE_ID
				      							AND apps.ap_invoices_pkg.get_approval_status (ai2.invoice_id,
                                                                                 ai2.invoice_amount,
                                                                                 ai2.payment_status_flag,
                                                                                 ai2.invoice_type_lookup_code) NOT IN ('NEEDS REAPPROVAL', 'NEVER APPROVED','APPROVED'))  
--                        GROUP BY mp.organization_id 
--                           ,y.numero_recepcion 
--                           ,y.orden_compra
--                           ,nvl((y.serie_factura || y.folio_factura), y.folio_fiscal) ,                           
--                           y.bodega,
--                           y.atributo2 ,
--                           y.folio_fiscal 
--                           ,ti.org_id
--                           ,ti.invoice_id
--                           ,ti.invoice_num
--                           ,y.total
--                           ,y.subtotal
--                           ,ti.vendor_id
--                           ,ti.vendor_site_id
--                           ,ti.vendor_site_code
--                           ,ti.invoice_amount
--                           ,ti.supplier_resico
--                           ,ti.total_tax_amount
                        order by ti.org_id,id_carga_xml desc)
      loop 
	     -- Como hay proveedores que ocupan el mismo UUID para diferentes OC y Recepción se debe validar nuevamente el UUID que no este ya ligado a otra factura
	     -- dentro del mismo proceso en ejecución
	     v_UUID_Validar := cur_xml_load.uuid;	      
      	 v_existe_UUID :=0;

	     SELECT count(*)
	     INTO v_existe_UUID
		 FROM APPS.XXPOS_ACTFACTURA P	
		 	,ap_invoices_all ai2
		 WHERE 1=1
		 AND P.ATRIBUTO3 = v_UUID_Validar
		 AND P.AP_INVOICE_ID =ai2.INVOICE_ID
		 AND apps.ap_invoices_pkg.get_approval_status (ai2.invoice_id,
                                                 ai2.invoice_amount,
                                                 ai2.payment_status_flag,
                                                 ai2.invoice_type_lookup_code) IN ('NEEDS REAPPROVAL', 'NEVER APPROVED','APPROVED');
		
	     -- Se valida si existe algun registro cancelado
	     -- el Id Carga sea posterior a la carga del uuid cancelada
	     IF v_existe_UUID = 0 THEN
	     	SELECT count(*)
		     INTO v_existe_UUID
			 FROM APPS.XXPOS_ACTFACTURA P	
			 	,ap_invoices_all ai2
			 WHERE 1=1
			 AND P.ATRIBUTO3 = v_UUID_Validar
			 AND P.AP_INVOICE_ID =ai2.INVOICE_ID
			 AND p.ATRIBUTO4 >= cur_xml_load.id_carga_xml; -- En este atributo se guarda el Id_Carga_XML
			 
			 vg_msg := 'v_existe_UUID (Debug Before) Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.seriefolio || ' UUID:'|| cur_xml_load.UUID;
	            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id, p_value2num => v_existe_UUID );
	     END IF;
	     
	     IF v_existe_UUID = 0 THEN -- No esta aun asignado 

	         if v_org_id != cur_xml_load.org_id then
	               v_org_id := cur_xml_load.org_id;
	               vg_Resp_Id := GET_RESP_ID(v_id_execution,cur_xml_load.INVOICE_ID);
	               -- Setea 
	               APPS.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize(puser_id        => v_user_id,
	                                                                  presp_id        => vg_Resp_Id, --50671,--v_resp_id,    AP
	                                                                  presp_appl_id   => 200 --v_resp_appl_id   AP_BEPUSA_SISTEMAS
	                                                                  );
	         end if;
	         v_invoice_num_new := cur_xml_load.seriefolio;
	         v_splited_invoice := false;

	         -- Validate that v_invoice_num_new not exists for company, supplier and site 
	         declare
	            v_exist number;
	         begin
	            v_exist := 0;

	            select count(invoice_id)
	            into v_exist
	            from apps.ap_invoices_all
	            where 1=1
	            and org_id = v_org_id
	            and vendor_id = cur_xml_load.vendor_id
	            and vendor_site_id = cur_xml_load.vendor_site_id
	            and invoice_num = v_invoice_num_new
	            and invoice_id != cur_xml_load.invoice_id;

	            -- if v_exist is greater than 0
	            if v_exist > 0 then
	               v_exist := 0;
	               -- Validate UUID
	               v_invoice_num_new := cur_xml_load.UUID;

	               select count(invoice_id)
	               into v_exist
	               from apps.ap_invoices_all
	               where 1=1
	               and org_id = v_org_id
	               and vendor_id = cur_xml_load.vendor_id
	               and vendor_site_id = cur_xml_load.vendor_site_id
	               and invoice_num = v_invoice_num_new;
	               -- 

	               if v_exist > 0 then
	                  v_splited_invoice := true;
	               end if;
	            end if;
	         end;

	         if v_splited_invoice then
	            -- Put Hold Factura Partida
	            vg_msg := 'Insert Hold Factura Partida (Debug Before) Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.seriefolio || ' UUID:'|| cur_xml_load.UUID;
	            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id);
	            APPLY_HOLD_INV(v_id_execution, pin_user_id, cur_xml_load.invoice_id, 2, v_resp);

	            vg_msg := 'Insert Hold Factura Partida (Debug After) Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.seriefolio || ' UUID:'|| cur_xml_load.UUID;
	            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id);

	            v_result_str := 'Y';
	         else

	               -- Se realizará la actualización si y solo si la factura disponible esta en estatus ('NEEDS REAPPROVAL', 'NEVER APPROVED') a nivel AP
	               -- Que no haya sido ya actualizada por este proceso anteriormente es decir que la columna UPDATED_DATA_FROM_XML este nula
	               -- Update the invoice number and invoice date
	               vg_msg := 'CHANGED_ERS_TO_XML (Debug Before) -- 1CUST_UPDATE_INVOICE_AP XML Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.invoice_num;
	               XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id
	                     , p_value2num => cur_xml_load.ship_to_org_id
	                     , p_value3num => cur_xml_load.id_carga_xml
	                     , p_value1str => cur_xml_load.uuid
	                     , p_value2str => to_char(cur_xml_load.fecha_recepcion_xml,'DD-MM-YYYY')
	                     , p_value3str => cur_xml_load.invoice_num
	                     );

	               CUST_UPDATE_INVOICE_AP(v_id_execution ,pin_user_id, cur_xml_load.invoice_id, v_invoice_num_new, cur_xml_load.fecha_recepcion_xml, v_result_str,v_result_msg_str);

	               vg_msg := 'CHANGED_ERS_TO_XML (Debug After) -- CUST_UPDATE_INVOICE_AP Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.invoice_num || ' Result->'|| v_result_str;
	               XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id
	                     , p_value2num => cur_xml_load.ship_to_org_id
	                     , p_value3num => cur_xml_load.id_carga_xml
	                     , p_value1str => cur_xml_load.uuid
	                     , p_value2str => to_char(cur_xml_load.fecha_recepcion_xml,'DD-MM-YYYY')
	                     , p_value3str => v_result_str
	                     );
	         	END IF; 


	               IF v_result_str = 'Y' THEN
	                  -- Remove hold Falta XML
	                  vg_msg := 'CHANGED_ERS_TO_XML (Debug Before) -- Remueve Falta XML Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.invoice_num;
	                  XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id
	                        , p_value2num => cur_xml_load.ship_to_org_id
	                        , p_value3num => cur_xml_load.id_carga_xml
	                        , p_value1str => cur_xml_load.orden_compra
	                        , p_value2str => cur_xml_load.receipt_num
	                        , p_value3str => cur_xml_load.bodega
	                        );

	                  --apps.XXGEP_RELHOLD (cur_xml_load.invoice_id, v_result_num);
	                  UNAPPLY_HOLD_INV(v_id_execution, pin_user_id, cur_xml_load.invoice_id, 1, v_result_num);

	                  vg_msg := 'CHANGED_ERS_TO_XML (Debug After) -- Remueve Falta XML Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.invoice_num || ' Result->'|| v_result_num;
	                  XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id
	                        , p_value2num => cur_xml_load.ship_to_org_id
	                        , p_value3num => cur_xml_load.id_carga_xml
	                        , p_value1str => cur_xml_load.orden_compra
	                        , p_value2str => cur_xml_load.receipt_num
	                        , p_value3str => v_result_num
	                        );
	                  IF v_result_num = 0 THEN -- If value is 0, hold is disable

	                     -- If tolerancia is Y, we insert a hold 'Tolerancia XML'
	                     /*if cur_xml_load.tolerancia = 'Y' and GET_COUNT_HOLD(cur_xml_load.invoice_id, 'Tolerancia XML', 'ACT')=0 then
	                        vg_msg := 'Insert Hold Tolerancia XML (Debug Before) Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.invoice_num;
	                        XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id);

	                        APPLY_HOLD_INV(v_id_execution, pin_user_id, cur_xml_load.invoice_id, 3, v_resp);

	                        vg_msg := 'Insert Hold Tolerancia XML (Debug After) Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.invoice_num;                     
	                        XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id, p_value2num =>v_resp);

	                        -- Actualiza los campos del hold
	                        UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
	                        SET NUM_HOLDS = GET_COUNT_HOLD(ai.invoice_id, 'ALL', 'ALL')
	                           ,NUM_HOLDS_ACT = GET_COUNT_HOLD(ai.invoice_id, 'ALL', 'ACT')
	                           ,last_updated_by = pin_user_id
	                           ,LAST_UPDATE_DATE = sysdate
	                        WHERE 1 = 1
	                        and invoice_id = cur_xml_load.invoice_id;
	                        commit;
	                     end if;*/

	                  	 DECLARE
	                  	 	v_existe NUMBER;
	                     BEGIN
		                    SELECT count(*)
		                     INTO v_existe
		                    FROM APPS.XXPOS_ACTFACTURA
		                    WHERE 1=1
		                    AND ap_invoice_id = cur_xml_load.invoice_id;

	                  	 	--IF v_existe = 0 THEN	                     
		                        INSERT INTO APPS.XXPOS_ACTFACTURA (
		                                                      ap_invoice_id,
		                                                      no_fact_ant,
		                                                      no_fact_new,
		                                                      usuario,
		                                                      unidad_operativa,
		                                                      estatus_lote,
		                                                      atributo3,
		                                                      atributo4)
		                                          VALUES (cur_xml_load.invoice_id,
		                                                   cur_xml_load.invoice_num,
		                                                   v_invoice_num_new,
		                                                   pin_user_id,
		                                                   cur_xml_load.org_id,
		                                                   '0',
		                                                   cur_xml_load.uuid,
		                                                   cur_xml_load.id_carga_xml);
		                                                   NULL;
		                        commit;

	                  	 	--END IF;
	                        -- If the hold was removed Falta XML
	                        -- , if invoice updated 
	                        -- and too inserted in XXPOS_ACTFACTURA 
	                        -- we continue to update the field UPDATED_DATA_FROM_XML to Y value
	                        update XXAP_TRACKING_INVOICES_TBL tb
	                           set tb.UPDATED_DATA_FROM_XML = 'Y'
	                              ,tb.UUID    = cur_xml_load.uuid --FOLIO_FISCAL
	                              ,tb.ID_CARGA_XML    = cur_xml_load.id_carga_xml --ID_CARGA_XML
	                              ,TB.INVOICE_NUM = v_invoice_num_new
	                              ,tb.last_updated_by = pin_user_id
	                              ,tb.LAST_UPDATE_DATE = sysdate
	                              ,tb.period_name = to_char(cur_xml_load.fecha_recepcion_xml,'MON-YY')
	                              ,tb.INVOICE_DATE = cur_xml_load.fecha_recepcion_xml
	                              ,tb.gl_date = cur_xml_load.fecha_recepcion_xml
	                              ,TB.SUBTOTAL_XML = cur_xml_load.subtotal
	                              ,TB.TOTAL_XML = cur_xml_load.total
	                              ,TB.loaded_date_xml =cur_xml_load.fecha_recepcion_xml
	                           WHERE 1=1
	                           AND INVOICE_ID = cur_xml_load.invoice_id;

	                        COMMIT;

	                        vg_msg := 'CHANGED_ERS_TO_XML (Debug) -- Updated UPDATED_DATA_FROM_XML Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.invoice_num;
	                        XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id
	                              , p_value2num => cur_xml_load.ship_to_org_id
	                              , p_value3num => cur_xml_load.id_carga_xml
	                              , p_value1str => cur_xml_load.orden_compra
	                              , p_value2str => cur_xml_load.receipt_num
	                              );
	                           -- Validate RESICO 
	                           IF cur_xml_load.supplier_resico = 'Y' THEN
	                              -- Aplicate algorit RESICO
	                              DECLARE
	                                 v_factor NUMBER:=0.0125;
	                                 v_subtotal_xml NUMBER;
	                                 v_total_xml NUMBER;
	                                 v_invoice_amount NUMBER;
	                                 v_factor_X_subtotal_xml NUMBER;
	                                 v_amount_minus_total_xml NUMBER;
	                              BEGIN
	                                 v_invoice_amount := cur_xml_load.invoice_amount;
	                                 v_subtotal_xml := cur_xml_load.subtotal;
	                                 v_total_xml := cur_xml_load.total;

	                                 v_factor_X_subtotal_xml := v_subtotal_xml * v_factor;
	                                 v_amount_minus_total_xml := v_invoice_amount - v_total_xml;

	                                 -- v_amount_minus_total_xml
	                                 IF ABS(v_amount_minus_total_xml - v_factor_X_subtotal_xml) > 0.1 THEN
	                                    -- Put Hold Diferencia en impuesto
	                                    vg_msg := 'Insert Hold Diferencia Impuesto (Debug Before) Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.seriefolio || ' UUID:'|| cur_xml_load.UUID;
	                                    XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id);
	                                    APPLY_HOLD_INV(v_id_execution, pin_user_id, cur_xml_load.invoice_id, 7, v_resp);

	                                    vg_msg := 'Insert Hold Diferencia Impuesto (Debug After) Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.seriefolio || ' UUID:'|| cur_xml_load.UUID;
	                                    XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id);

	                                 END IF;
	                              END;
	                           else
	                              --total_tax_amount
	                              -- Check if there is a diffrence between xml and row in ap
	                              DECLARE
	                                 v_toleracia NUMBER:=0.99;
	                                 v_subtotal_xml NUMBER;
	                                 v_total_xml NUMBER;
	                                 v_total_tax_amount NUMBER;
	                                 v_valor1 NUMBER;
	                                 v_diferencia NUMBER;
	                              BEGIN
	                                 v_total_tax_amount := cur_xml_load.total_tax_amount;
	                                 v_subtotal_xml := cur_xml_load.subtotal;
	                                 v_total_xml := cur_xml_load.total;

	                                 v_valor1 := v_total_xml - v_subtotal_xml;
	                                 v_diferencia := v_total_tax_amount - v_valor1;

	                                 -- v_amount_minus_total_xml
	                                 IF ABS(v_diferencia) > v_toleracia THEN
	                                    -- Put Hold Diferencia en impuesto
	                                    vg_msg := 'Insert Hold Diferencia Impuesto NO RESICO (Debug Before) Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.seriefolio || ' UUID:'|| cur_xml_load.UUID;
	                                    XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id);
	                                    APPLY_HOLD_INV(v_id_execution, pin_user_id, cur_xml_load.invoice_id, 7, v_resp);

	                                    vg_msg := 'Insert Hold Diferencia Impuesto NO RESICO (Debug After) Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.seriefolio || ' UUID:'|| cur_xml_load.UUID;
	                                    XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id);

	                                 END IF;
	                              END;
	                           END IF;

	                     EXCEPTION
	                        WHEN DUP_VAL_ON_INDEX THEN
	                           vg_msg := 'CHANGED_ERS_TO_XML (Debug After) -- Insert XXPOS_ACTFACTURA - DUP_VAL_ON_INDEX Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.invoice_num ;
	                           XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id
	                                 , p_value2num => cur_xml_load.ship_to_org_id
	                                 , p_value3num => cur_xml_load.id_carga_xml
	                                 , p_value1str => cur_xml_load.orden_compra
	                                 , p_value2str => cur_xml_load.receipt_num
	                                 , p_value3str => 'DUP_VAL_ON_INDEX Duplicada'-- || ' SQLERRM:' || substr(SQLERRM,1,50)
	                                 );                                            
	                        WHEN OTHERS THEN
	                           vg_msg := 'CHANGED_ERS_TO_XML (Debug After) -- Insert XXPOS_ACTFACTURA - OTHERS Org_Id:'|| cur_xml_load.org_id || ' Invoice_Id:' || cur_xml_load.invoice_id || ' Invoice_num:'|| cur_xml_load.invoice_num ;
	                           XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur_xml_load.invoice_id ,p_TEXT => vg_msg, p_value1num => cur_xml_load.org_id
	                                 , p_value2num => cur_xml_load.ship_to_org_id
	                                 , p_value3num => cur_xml_load.id_carga_xml
	                                 , p_value1str => cur_xml_load.orden_compra
	                                 , p_value2str => cur_xml_load.receipt_num
	                                 , p_value3str => 'OTHERS' || ' SQLERRM:' || substr(SQLERRM,1,15)
	                                 );
	                     end;
	                  END IF;
	               END IF;
			END IF;
      end loop;
    EXCEPTION
      WHEN es_fin_mes THEN
         vg_msg := 'CHANGED_ERS_TO_XML ES CIERRE DE MES ' || v_msj_exception;
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution, p_TEXT => vg_msg, p_VALUE1NUM => l_request_id);
      WHEN OTHERS THEN
         vg_msg := 'CHANGED_ERS_TO_XML ERROR OTHERS ' || SQLCODE;
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution, p_TEXT => vg_msg, p_VALUE1NUM => l_request_id);

    END CHANGED_ERS_TO_XML;

    /*PROCEDURE  ACCOUNTED_INVOICES(pin_id_execution in number ,pin_user_id in number)
    AS
    BEGIN*/
        -- Se validan si las facturas ya estan validadas y contabilizadas
        -- Se revisan desde las que estan en estatus  STEP_CTRL en 1, 5 u otro diferente de 100
        --UPDATE /*+index(tb XXAP_TRACKING_INVOICES_TBL_N1)*/ XXWEBC.XXAP_TRACKING_INVOICES_TBL TB
        /*SET (tb.approval_status
            ,tb.posting_status            
            , tb.LAST_UPDATE_DATE) = (select apps.ap_invoices_pkg.get_approval_status (ai.invoice_id,
                                                                              ai.invoice_amount,
                                                                              ai.payment_status_flag,
                                                                              ai.invoice_type_lookup_code) approval_status,
                                            ap_invoices_pkg.get_posting_status(ai.invoice_id) posting_status
                                            ,sysdate
                                       from apps.ap_invoices_all ai
                                       where 1=1
                                       and ai.invoice_id = tb.invoice_id)
            ,XML_HOLD = GET_COUNT_HOLD(tb.invoice_id, 'Falta XML', 'ALL')
            ,XML_HOLD_STATUS = GET_COUNT_HOLD(tb.invoice_id, 'Falta XML', 'STATUS')
            ,fa_hold  = GET_COUNT_HOLD(tb.invoice_id, 'Falta Validacion AF', 'ALL') 
            ,fa_hold_status = GET_COUNT_HOLD(tb.invoice_id, 'Falta Validacion AF', 'STATUS') 

            ,NUM_HOLDS =  GET_COUNT_HOLD(tb.invoice_id, 'ALL', 'ALL')
            ,NUM_HOLDS_ACT =  GET_COUNT_HOLD(tb.invoice_id, 'ALL', 'ACT')
            ,foreign_hold = GET_COUNT_HOLD(tb.invoice_id, 'Proveedor Extranjero', 'ALL')  
            ,foreign_hold_status = GET_COUNT_HOLD(tb.invoice_id, 'Proveedor Extranjero', 'STATUS') 
            ,funds_hold = GET_COUNT_HOLD(tb.invoice_id, 'SE ENCUENTRA EN PROCESO DE LIBERACION', 'ALL')  
            ,funds_hold_status = GET_COUNT_HOLD(tb.invoice_id, 'SE ENCUENTRA EN PROCESO DE LIBERACION', 'STATUS') 
            ,difference_tax_hold = GET_COUNT_HOLD(tb.invoice_id, 'Diferencia en Impuesto', 'ALL')  
            ,difference_tax_hold_status = GET_COUNT_HOLD(tb.invoice_id, 'Diferencia en Impuesto', 'STATUS') 
            ,splited_invoice_hold = GET_COUNT_HOLD(tb.invoice_id, 'Factura Partida', 'ALL')  
            ,splited_invoice_hold_status = GET_COUNT_HOLD(tb.invoice_id, 'Factura Partida', 'STATUS') 
            ,other_holds = GET_COUNT_HOLD(tb.invoice_id, 'Other Holds', 'ALL')  
            ,other_holds_status = GET_COUNT_HOLD(tb.invoice_id, 'Other Holds', 'STATUS') 
        WHERE 1=1
        AND tb.STEP_CTRL != 100
        and tb.execution_id != pin_id_execution;

        commit;
*/
        --UPDATE /*+index(tb XXAP_TRACKING_INVOICES_TBL_N1)*/ XXWEBC.XXAP_TRACKING_INVOICES_TBL TB
        /*SET tb.step_ctrl = case when tb.posting_status = 'Y' OR TB.approval_status = 'CANCELLED' THEN 100
                                else 99
                                end
            ,tb.last_update_date = sysdate
            ,tb.INVOICE_NUM = (select invoice_num from apps.ap_invoices_all i where i.invoice_id = tb.invoice_id)
            ,(tb.uuid,tb.ID_CARGA_XML) = (select XF.ATRIBUTO3 uuid, XF.ATRIBUTO4 ID_CARGA_XML from APPS.XXPOS_ACTFACTURA XF where 1=1 and xf.ap_invoice_id = tb.invoice_id )
            ,tb.last_updated_by = pin_user_id
        WHERE 1=1
        AND tb.STEP_CTRL !=100
        and tb.execution_id != pin_id_execution
        and tb.approval_status NOT IN ('NEEDS REAPPROVAL', 'NEVER APPROVED');

        commit;

    END  ACCOUNTED_INVOICES;*/

    FUNCTION GET_COUNT_HOLD(p_invoice_id in number, p_hold_name in varchar2, p_tipo in varchar2) 
        return number
    AS
        v_return number;
        v_tipo varchar2(100);
    BEGIN
        v_return := 0;
        v_tipo := upper(p_tipo);
        IF v_tipo != 'STATUS' THEN
            if p_hold_name != 'Other Holds' THEN
                  SELECT count(*)
                  into v_return
                  FROM ap_holds_all aha
                  WHERE aha.invoice_id       = p_invoice_id
                  AND REPLACE(aha.hold_lookup_code,'XXCUST Diferencia en Impu','Dif en Impuestos CUST') = CASE WHEN p_hold_name = 'ALL' THEN
                                                         REPLACE(aha.hold_lookup_code,'XXCUST Diferencia en Impu','Dif en Impuestos CUST')--aha.hold_lookup_code
                                                   ELSE 
                                                         p_hold_name
                                                   END 
                  and nvl(aha.release_lookup_code,'VACIO') = CASE WHEN NVL(p_tipo,'ALL') = 'ALL' THEN
                                                                     nvl(aha.release_lookup_code,'VACIO')
                                                                  ELSE 
                                                                        'VACIO'
                                                                  END ;
            ELSE
                  SELECT count(*)
                  into v_return
                  FROM ap_holds_all aha
                  WHERE aha.invoice_id       = p_invoice_id
                  AND aha.hold_lookup_code NOT IN ('Falta XML','Falta Validacion AF','Proveedor Extranjero','SE ENCUENTRA EN PROCESO DE LIBERACION','Factura Partida','Diferencia en Impuesto','Revision Manual','XXCUST Diferencia en Impu','Dif en Impuestos CUST')
                  and nvl(aha.release_lookup_code,'VACIO') = CASE WHEN NVL(p_tipo,'ALL') = 'ALL' THEN
                                                                     nvl(aha.release_lookup_code,'VACIO')
                                                                  ELSE 
                                                                        'VACIO'
                                                                  END ;
            END IF;
        ELSIF  v_tipo = 'STATUS' THEN
            if p_hold_name != 'Other Holds' THEN
                  SELECT case when count(aha.hold_lookup_code) <= 0 then
                                    0 -- No hay retención
                              when sum(case when aha.release_lookup_code is null  then 1 else 0 end) = 0 then
                                    1 -- Si hay retención pero NO activa
                              else
                                    2 -- Si hay retención SI activa
                              end AS STATUS
                  into v_return
                  FROM ap_holds_all aha
                  WHERE aha.invoice_id       = p_invoice_id
                  AND REPLACE(aha.hold_lookup_code,'XXCUST Diferencia en Impu','Dif en Impuestos CUST') = p_hold_name;
            ELSE
                  SELECT case when count(aha.hold_lookup_code) <= 0 then
                                    0 -- No hay retención
                              when sum(case when aha.release_lookup_code is null  then 1 else 0 end) = 0 then
                                    1 -- Si hay retención pero NO activa
                              else
                                    2 -- Si hay retención SI activa
                              end AS STATUS
                  into v_return
                  FROM ap_holds_all aha
                  WHERE aha.invoice_id       = p_invoice_id
                  AND aha.hold_lookup_code NOT IN ('Falta XML','Falta Validacion AF','Proveedor Extranjero','SE ENCUENTRA EN PROCESO DE LIBERACION','Factura Partida','Diferencia en Impuesto','Revision Manual','XXCUST Diferencia en Impu','Dif en Impuestos CUST');
            END IF;
        END IF;

        return v_return;
    END GET_COUNT_HOLD;


    PROCEDURE UPDATE_STATUS_INVOICES(pin_id_execution in number ,pin_user_id in number)
    IS
    BEGIN
         EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
         -- Se validan si las facturas ya estan validadas y contabilizadas
        -- Se revisan desde las que estan en estatus  STEP_CTRL en 1, 5 u otro diferente de 100

        --UPDATE /*+index(tb XXAP_TRACKING_INVOICES_TBL_N1)*/ XXWEBC.XXAP_TRACKING_INVOICES_TBL TB
        /*SET (tb.approval_status
            ,tb.posting_status            
            , tb.LAST_UPDATE_DATE) = (select apps.ap_invoices_pkg.get_approval_status (ai.invoice_id,
                                                                              ai.invoice_amount,
                                                                              ai.payment_status_flag,
                                                                              ai.invoice_type_lookup_code) approval_status,
                                            ap_invoices_pkg.get_posting_status(ai.invoice_id) posting_status
                                            ,sysdate
                                       from apps.ap_invoices_all ai
                                       where 1=1
                                       and ai.invoice_id = tb.invoice_id)
        WHERE 1=1
        AND tb.STEP_CTRL != 100
        and tb.execution_id != pin_id_execution;

        commit;*/
        FOR cur IN (SELECT /*+index(tb XXAP_TRACKING_INVOICES_TBL_N1)*/ invoice_id
                     FROM  XXWEBC.XXAP_TRACKING_INVOICES_TBL TB
                     WHERE 1=1
                     and source in ('ERS','USE')
                     AND tb.STEP_CTRL != 100
                     and tb.execution_id != pin_id_execution)
         LOOP
               UPDATE_ROW_TRACKING(cur.invoice_id, pin_user_id, 'UPDATE_STATUS_INVOICES');
         END LOOP;

        -- Actualiza estatus de origen ERS,RTS y USE
        UPDATE /*+index(tb XXAP_TRACKING_INVOICES_TBL_N1)*/ XXWEBC.XXAP_TRACKING_INVOICES_TBL TB
        SET tb.step_ctrl = case when tb.posting_status = 'Y' OR TB.approval_status = 'CANCELLED' THEN 100
                                else 99
                                end
            ,tb.last_update_date = sysdate
            ,tb.INVOICE_NUM = (select invoice_num from apps.ap_invoices_all i where i.invoice_id = tb.invoice_id)
            ,(tb.uuid,tb.ID_CARGA_XML) = (select XF.ATRIBUTO3 uuid, XF.ATRIBUTO4 ID_CARGA_XML from APPS.XXPOS_ACTFACTURA XF where 1=1 and xf.ap_invoice_id = tb.invoice_id )
            ,tb.last_updated_by = pin_user_id
        WHERE 1=1
        AND tb.STEP_CTRL !=100
        and tb.execution_id != pin_id_execution
        and source in ('ERS','USE')--,'RTS')
        and tb.approval_status NOT IN ('NEEDS REAPPROVAL', 'NEVER APPROVED');

        commit;

    END UPDATE_STATUS_INVOICES;

    PROCEDURE APPLY_HOLD_INV(pin_id_execution in number ,pin_user_id in number,P_INVOICE_ID in NUMBER, p_tipo_hold in NUMBER, p_result out number,p_hold_reason in varchar2 default NULL)--XXGEP_APLHOLD--
    AS
      x_invoice_id         NUMBER;
      x_hold_lookup_code   VARCHAR2 (200);
      x_hold_type          VARCHAR2 (200);
      x_hold_reason        VARCHAR2 (200);
      x_held_by            NUMBER;
      x_calling_sequence   VARCHAR2 (200);
      --v_check_flag         VARCHAR2 (1);
      v_id_execution number;
    BEGIN      
      v_id_execution := pin_id_execution;



      p_result := 0;
      x_invoice_id := p_invoice_id;
      x_held_by := pin_user_id;
      x_calling_sequence := NULL;


      IF p_tipo_hold = 1 THEN       
         x_hold_lookup_code := 'Falta XML';
         x_hold_type := 'INVOICE HOLD REASON';
         x_hold_reason := 'La factura no tiene un XML Valido iSupplier';       
      ELSIF p_tipo_hold = 2 THEN
         x_hold_lookup_code := 'Factura Partida';
         x_hold_type := 'INVOICE HOLD REASON';
         x_hold_reason := 'La factura esta partida';       
      ELSIF p_tipo_hold = 3 THEN
         x_hold_lookup_code := 'Tolerancia XML';
         x_hold_type := 'INVOICE HOLD REASON';
         x_hold_reason := 'Limite de tolerancia en XML';       
      ELSIF p_tipo_hold = 4 THEN
         x_hold_lookup_code := 'Falta Validacion AF';
         x_hold_type := 'INVOICE HOLD REASON';
         x_hold_reason := 'Requiere de documentacion de AF';       
      ELSIF p_tipo_hold = 5 THEN
         x_hold_lookup_code := 'Años Anteriores';
         x_hold_type := 'INVOICE HOLD REASON';
         x_hold_reason := 'Años Anteriores';  
      ELSIF p_tipo_hold = 6 THEN
         x_hold_lookup_code := 'Proveedor Extranjero';
         x_hold_type := 'INVOICE HOLD REASON';
         x_hold_reason := 'Proveedor Extranjero';  
      ELSIF p_tipo_hold = 7 THEN
         x_hold_lookup_code := 'Dif en Impuestos CUST';--031225 'XXCUST Diferencia en Impu';
         x_hold_type := 'INVOICE HOLD REASON';
         x_hold_reason := 'Variación Impuesto';
      ELSIF p_tipo_hold = 8 THEN
         x_hold_lookup_code := 'Revision Manual';
         x_hold_type := 'INVOICE HOLD REASON';
         IF p_hold_reason IS NULL THEN
            x_hold_reason := 'Variación Impuesto RESICO';
         ELSE
            x_hold_reason := p_hold_reason;
         END IF;
      END IF;


      -- Call API to apply hold
      --apps.AP_HOLDS_PKG.INSERT_SINGLE_HOLD 
      apps.XXGEPP_APPS_UTILITIES_PKG.XX_INSERT_SINGLE_HOLD(
                     p_invoice_id         => x_invoice_id,
                     p_hold_lookup_code   => x_hold_lookup_code,
                     p_hold_type          => x_hold_type,
                     p_hold_reason        => x_hold_reason,
                     p_held_by            => x_held_by,
                     p_calling_sequence   => x_calling_sequence);


      p_result := GET_COUNT_HOLD(x_invoice_id, x_hold_lookup_code, 'ACT');


      vg_msg := 'APPLY_HOLD_INV (applied hold) --  Invoice_Id:' || x_invoice_id || ' Hold:'|| x_hold_lookup_code || ' Num. Holds Activas:' || p_result
                  || ' UserId:'|| x_held_by || ' x_hold_lookup_code:' || x_hold_lookup_code;

      XXLOG(p_Level => 5 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => x_invoice_id ,p_TEXT => vg_msg
               , p_value1num => x_held_by
               , p_value2num => p_result
               , p_value1str => x_hold_lookup_code
               );

      /*apps.AP_HOLDS_PKG.release_single_hold (
      x_invoice_id            => x_invoice_id,
      x_hold_lookup_code      => x_hold_lookup_code,
      X_RELEASE_lookup_code   => 'APPROVED',
   --                x_hold_type             => x_hold_type,
    --               x_hold_reason           => x_hold_reason,
      x_held_by               => x_held_by,
      x_calling_sequence      => x_calling_sequence);*/

    END APPLY_HOLD_INV;

    PROCEDURE UNAPPLY_HOLD_INV(pin_id_execution in number ,pin_user_id in number,P_INVOICE_ID in NUMBER, p_tipo_hold in NUMBER, p_result out number)--XXGEP_RELHOLD--
    AS
      x_invoice_id         NUMBER;
      x_hold_lookup_code   VARCHAR2 (200);
      x_hold_type          VARCHAR2 (200);
      x_hold_reason        VARCHAR2 (200);
      x_held_by            NUMBER;
      x_calling_sequence   VARCHAR2 (200);
      --v_check_flag         VARCHAR2 (1);
      v_id_execution number;
    BEGIN    
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
      v_id_execution := pin_id_execution;

      p_result := 0;
      x_invoice_id := p_invoice_id;
      x_held_by := 666;--pin_user_id;
      x_calling_sequence := NULL;

      IF p_tipo_hold = 1 THEN       
         x_hold_lookup_code := 'Falta XML';
         x_hold_type := 'INVOICE HOLD REASON';
         x_hold_reason := 'La factura no tiene un XML Valido iSupplier';       
      ELSIF p_tipo_hold = 2 THEN
         x_hold_lookup_code := 'Factura Partida';
         x_hold_type := 'INVOICE HOLD REASON';
         x_hold_reason := 'La factura esta partida';       
      ELSIF p_tipo_hold = 3 THEN
         x_hold_lookup_code := 'Tolerancia XML';
         x_hold_type := 'INVOICE HOLD REASON';
         x_hold_reason := 'Limite de tolerancia en XML';       
      ELSIF p_tipo_hold = 4 THEN
         x_hold_lookup_code := 'Falta Validacion AF';
         x_hold_type := 'INVOICE HOLD REASON';
         x_hold_reason := 'Requiere de documentacion de AF';       
      ELSIF p_tipo_hold = 5 THEN
         x_hold_lookup_code := 'Años Anteriores';
         x_hold_type := 'INVOICE HOLD REASON';
         x_hold_reason := 'Años Anteriores';       
      END IF;

      p_result := GET_COUNT_HOLD(x_invoice_id, x_hold_lookup_code, 'ACT');

      if p_result = 1 then
               SELECT held_by
               into x_held_by
               FROM ap_holds_all aha
               where aha.invoice_id = x_invoice_id
               and aha.hold_lookup_code = x_hold_lookup_code
               and aha.release_lookup_code is null;

            -- Call API to unapply hold
            --apps.AP_HOLDS_PKG.release_single_hold (

            apps.XXGEPP_APPS_UTILITIES_PKG.XX_RELEASE_SINGLE_HOLD(
                        p_invoice_id            => x_invoice_id,
                        p_hold_lookup_code      => x_hold_lookup_code,      
                        p_held_by               => x_held_by,
                        p_calling_sequence      => x_calling_sequence);


            p_result := GET_COUNT_HOLD(x_invoice_id, x_hold_lookup_code, 'ACT');
            vg_msg := 'UNAPPLY_HOLD_INV (removed hold) --  Invoice_Id:' || x_invoice_id || ' Hold:'|| x_hold_lookup_code || ' Num. Holds Activas:' || p_result;
            XXLOG(p_Level => 5 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => x_invoice_id ,p_TEXT => vg_msg
                     , p_value1num => x_held_by
                     , p_value2num => p_result
                     , p_value1str => x_hold_lookup_code
                     );
      else
         vg_msg := 'UNAPPLY_HOLD_INV No aplico (removed hold) --  Invoice_Id:' || x_invoice_id || ' Hold:'|| x_hold_lookup_code || ' Num. Holds Activas:' || p_result;
         XXLOG(p_Level => 5 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => x_invoice_id ,p_TEXT => vg_msg
               , p_value1num => x_held_by
               , p_value2num => p_result
               , p_value1str => x_hold_lookup_code
               );
      end if;



    END UNAPPLY_HOLD_INV;

    PROCEDURE CUST_UPDATE_INVOICE_AP(pin_id_execution in number ,pin_user_id in number,P_INVOICE_ID in NUMBER, p_invoice_num_new in VARCHAR2, p_invoice_date_new date, p_result out varchar2, p_result_msg out varchar2)
    AS
         v_id_execution number;
         v_result varchar2(10);
         v_result_msg varchar2(1000);
         v_exist number;
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
      -- valida si ya existe en esta tabla es por que paso por el proceso anterior y ya no hay que cambiarlo
      select count(*)
      into v_exist
      from APPS.XXPOS_ACTFACTURA
      where 1=1
      and ap_invoice_id = P_INVOICE_ID;

      IF v_exist > 0 THEN
         p_result := 'Y1';

      ELSE


         v_id_execution := pin_id_execution;
         apps.XXGEPP_APPS_UTILITIES_PKG.xx_update_row (pin_user_id,P_INVOICE_ID, p_invoice_num_new, p_invoice_date_new, v_result, v_result_msg);
         p_result := v_result;
         p_result_msg := v_result_msg;
         vg_msg := 'CUST_UPDATE_INVOICE_AP after  (changing invoice_num, invoice_date, terms_date, gl_date) --  Invoice_Id:' || P_INVOICE_ID || ' Invoice Num New:'|| p_invoice_num_new || ' Invoice Date New:' || to_char(p_invoice_date_new,'dd-mm-yyyy') || ' ---- ' 
                              || p_result || '  '
                              || p_result_msg;
      end if;       
      XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => P_INVOICE_ID ,p_TEXT => vg_msg
         , p_value1str => p_invoice_num_new
         , p_value2str => to_char(p_invoice_date_new,'dd-mm-yyyy')
         , P_VALUE3STR => p_result
         );
      if p_result = 'Y1' THEN
         p_result := 'Y';
      END IF;

    END CUST_UPDATE_INVOICE_AP;

    PROCEDURE SEND_REQUEST_POXPOIV(errbuf out varchar2, retcode out number,pin_ejecuta_dias in number,pin_fecha_barrido in varchar2)
    IS
            cursor c_organizations_resp  is
                select u.organization_id as org_id, u.name name_cia, u.attribute15 cia, r.responsibility_id, r.responsibility_name
                  from apps.FND_LOOKUP_VALUES_VL fv
                      ,hr.hr_all_organization_units u  
                      ,apps.fnd_responsibility_tl r  
                 where 1=1
                   AND fv.ENABLED_FLAG = 'Y'
                   AND NVL (fv.END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE
                   AND fv.LOOKUP_TYPE = 'CUST_AP_EMPRESAS_LKP'
                   and u.name = fv.meaning
                   and r.language = 'ESA'
                   and r.responsibility_name = 'AP_' || u.name || '_SISTEMAS'                  
                 order by u.organization_id;

            cursor c_organizations is
                select u.organization_id as org_id, u.name, u.attribute15 cia
                  from apps.FND_LOOKUP_VALUES_VL fv
                      ,hr.hr_all_organization_units u    
                 where 1=1
                   AND fv.ENABLED_FLAG = 'Y'
                   AND NVL (fv.END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE
                   AND fv.LOOKUP_TYPE = 'CUST_AP_EMPRESAS_LKP'
                   and u.name = fv.meaning
                 order by u.organization_id;

         cursor c_receipts( pFecha_Barrido date, pExecution_Id number) is
         select /*+ INDEX (rts RCV_TRANSACTIONS_N16) */ 
               pExecution_Id as execution_id,rts.transaction_id,rsh.receipt_num,phs.vendor_id,phs.org_id, sysdate as creation_date
               ,rsh.SHIPMENT_HEADER_ID , phs.po_header_id, 'ERS'
           from apps.rcv_transactions  rts
               ,apps.po_headers_all     phs
               ,apps.rcv_shipment_headers    rsh
         where 1=1
            --and rsh.receipt_num ='1315305'
            --AND RSH.SHIPMENT_HEADER_ID =  24330319
            --and rts.transaction_id = 131304124
            --and phs.org_id = pOrg_Id--84
            and rts.last_update_date >= pFecha_Barrido--sysdate-31 to_date('01-04-2025','dd-mm-yyyy')
            AND rts.po_header_id = phs.po_header_id
            AND nvl(rts.invoice_status_code,'NA')  IN ('PENDING','REJECTED')
            AND rts.shipment_header_id = rsh.shipment_header_id
            AND rsh.receipt_source_code = 'VENDOR'
            AND rts.source_document_code = 'PO'
            AND phs.pcard_id is null
            AND (rts.transaction_type = 'RECEIVE'
                  OR ( 1=1
                      AND rts.transaction_type = 'CORRECT'
                      AND rts.timecard_id is not null
                      AND exists(select 1 
                                       from apps.rcv_transactions prt
                                    where prt.transaction_type = 'RECEIVE'
                                       and prt.SOURCE_DOCUMENT_CODE = 'PO'
                                       and prt.transaction_id = rts.parent_transaction_id
                                       and prt.invoice_status_code ='INVOICED'
                                       and prt.last_update_date <= rts.creation_date)
                     )
               );
      type tt_c_receipts is table of c_receipts%rowtype;
        l_c_receipts tt_c_receipts;
        c_limit number := 100;

      cursor c_uses( pFecha_Barrido date, pExecution_Id number) is
      select pExecution_Id as execution_id, NULL transaction_id,NULL receipt_num,poh.vendor_id,poh.org_id, sysdate as creation_date
                     ,NULL SHIPMENT_HEADER_ID , poh.po_header_id, 'USE'
      FROM
         apps.PO_VENDORS pv,
         apps.PO_VENDOR_SITES_all pvs,
         apps.PO_VENDOR_SITES_all pvs2,
         apps.PO_HEADERS_all poh,
         apps.PO_LINES_all pol,
         apps.PO_LINE_LOCATIONS_all poll,
         apps.PO_DISTRIBUTIONS_all pod
      WHERE 
            pv.vendor_id = poh.vendor_id
      --AND   poh.po_header_id=      38061656
      AND   poh.vendor_site_id = pvs.vendor_site_id
      AND   NVL(pvs.default_pay_site_id, pvs.vendor_site_id) =
            pvs2.vendor_site_id
      AND   poh.po_header_id = pol.po_header_id
      AND   pol.po_line_id = poll.po_line_id
      AND   poll.line_location_id = pod.line_location_id
      AND   poh.pay_on_code IN ('RECEIPT_AND_USE', 'USE')
      AND   DECODE (poh.consigned_consumption_flag,     -- utilize PO_HEADERS_F1 idx
                  'Y', 
                  DECODE(poh.closed_code,
                           'FINALLY CLOSED',
                           NULL,
                           'Y'),
                  NULL) = 'Y'
      AND   poh.type_lookup_code = 'STANDARD'
      AND   poh.creation_date >=  pFecha_Barrido --trunc(sysdate)-5--p_cutoff_date
      AND   pvs.pay_on_code IN ('RECEIPT_AND_USE', 'USE')
      AND   pod.quantity_ordered > NVL(pod.quantity_billed,0) 
      AND   poll.closed_code <> 'FINALLY CLOSED'
      AND   NOT EXISTS ( SELECT 'use invoice is interfaced'
                           FROM  apps.ap_invoices_interface aii,
                                 apps.ap_invoice_lines_interface aili
                        WHERE  aii.invoice_id = aili.invoice_id
                           AND  nvl(aii.status,'PENDING') <> 'PROCESSED'
                           AND  aili.po_distribution_id = pod.po_distribution_id )
      UNION ALL
      -- blanket release
      select pExecution_Id as execution_id, NULL transaction_id,NULL receipt_num,poh.vendor_id,poh.org_id, sysdate as creation_date
                     ,NULL SHIPMENT_HEADER_ID , poh.po_header_id, 'USE'
      FROM
         apps.PO_VENDORS pv,
         apps.PO_VENDOR_SITES_all pvs,
         apps.PO_VENDOR_SITES_all pvs2,
         apps.PO_HEADERS_all poh,
         apps.PO_RELEASES_all por,
         apps.PO_LINES_all pol,
         apps.PO_LINE_LOCATIONS_all poll,
         apps.PO_DISTRIBUTIONS_all pod
      WHERE 
            pv.vendor_id = poh.vendor_id
      --AND   poh.po_header_id=      38061656
      AND   poh.vendor_site_id = pvs.vendor_site_id
      AND   NVL(pvs.default_pay_site_id, pvs.vendor_site_id) =
            pvs2.vendor_site_id
      AND   poh.po_header_id = por.po_header_id
      AND   poh.po_header_id = pol.po_header_id
      AND   pol.po_line_id = poll.po_line_id
      AND   por.po_release_id = poll.po_release_id
      AND   poll.line_location_id = pod.line_location_id
      AND   por.pay_on_code IN ('RECEIPT_AND_USE', 'USE')
      AND   DECODE (por.consigned_consumption_flag,  -- utilize PO_RELEASES_F1 idx
                  'Y', 
                  DECODE(por.closed_code,
                           'FINALLY CLOSED',
                           NULL,
                           'Y'),
                  NULL) = 'Y'
      AND   por.release_type = 'BLANKET'
      AND   por.creation_date >= pFecha_Barrido--trunc(sysdate)-5--<= p_cutoff_date
      AND   pvs.pay_on_code IN ('RECEIPT_AND_USE', 'USE')
      AND   pod.quantity_ordered > NVL(pod.quantity_billed,0) 
      AND   poll.closed_code <> 'FINALLY CLOSED'
      AND   NOT EXISTS ( SELECT 'use invoice is interfaced'
                           FROM  apps.ap_invoices_interface aii,
                                 apps.ap_invoice_lines_interface aili
                        WHERE  aii.invoice_id = aili.invoice_id
                           AND  nvl(aii.status,'PENDING') <> 'PROCESSED'
                           AND  aili.po_distribution_id = pod.po_distribution_id );

      type tt_c_uses is table of c_uses%rowtype;
      l_c_uses tt_c_uses;

      --pin_ejecuta_dias NUMBER:=0;
      --pin_fecha_barrido varchar2(20):='01-04-2025';
      v_id_execution NUMBER;
      v_fecha_barrido DATE;
      v_user_id NUMBER;
      v_count_trx NUMBER;
      v_responsibility_id NUMBER;
      v_request_id NUMBER;

      v_process VARCHAR2(20):='SEND_REQUEST_POXPOIV';

      es_fin_mes EXCEPTION;
      v_status_excecute_process varchar2(1000);
      v_status_code varchar2(2);
      v_msj_exception varchar2(1000);
      l_request_id number;
      v_time_execute_all date;
      v_tag_execute_all varchar2(10);

      v_exists_other_exec number;
      hay_procesos_ejecutandose exception;
    BEGIN
      EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
      v_responsibility_id := 0;
         execute immediate 'ALTER SESSION SET NLS_LANGUAGE =  "LATIN AMERICAN SPANISH" ';

         v_id_execution := to_char(sysdate,'YYYYMMDDHH24MISS');

      l_request_id := NVL(fnd_global.conc_request_id,-666);

      v_status_excecute_process := STATUS_TO_EXCECUTE_THE_PROCESS('PROCESO6') || ' Requist_Id:'||l_request_id;

      v_status_code := substr(v_status_excecute_process,1,2);

      IF v_status_code = 'NE' THEN
         v_msj_exception := v_status_excecute_process;
         raise es_fin_mes;
      ELSIF CUST_AP_VALIDA_ES_CIERRE_FNC() IN ('Y1') AND v_status_code = 'CA' THEN
         v_msj_exception := 'Y1 - '|| v_status_excecute_process;
         raise es_fin_mes;
      ELSIF CUST_AP_VALIDA_ES_CIERRE_FNC() IN ('Y2') THEN
         v_msj_exception := 'Y2 - '|| v_status_excecute_process;
         raise es_fin_mes;
      END IF;


      select count(1)
      into v_exists_other_exec
            from apps.fnd_concurrent_requests 
            where 1=1
            and concurrent_program_id =36838
            --and request_id = 339836607
            and PHASE_CODE IN ('R','P');

      if v_exists_other_exec > 0 then
         retcode := 1;
         v_msj_exception := 'SEND_REQUEST_POXPOIV HAY PROCESOS EN EJECUCION';
         raise hay_procesos_ejecutandose;
      end if;


         XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => 'INICIA PROCESO SEND_REQUEST_POXPOIV'
                ,p_PROCESS_NAME => v_process);

         MESSAGE_LOG('INICIA PROCESO SEND_REQUEST_POXPOIV v_id_execution:'||v_id_execution);
         -- Obtiene el ID del usuario
         --v_user_id := 3994;--  apps.FND_GLOBAL.USER_ID();  
         v_user_id := apps.FND_GLOBAL.USER_ID();  
         -- Si regresa -1 es por no se lanzo desde la aplicación o no esta seteado el usuario
           IF  v_user_id = -1 THEN
                v_user_id := 1250; --Asigna el usuario 1250 que es Oracle en esta instancia de eBS

           END IF;   


         XXLOG(p_Level => 3
               ,p_EXECUTION_ID => v_id_execution
               ,p_TEXT => 'User_Id :' || v_user_id
               ,p_PROCESS_NAME => v_process
               );

         -- If time is less of parameter hour and more the 00:00 execute all
         begin
            select  trim(tag) as tag
            into v_tag_execute_all
               from apps.FND_LOOKUP_VALUES_VL fv  
               where 1=1
                  --AND fv.ENABLED_FLAG = 'Y'
                  AND NVL (fv.END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE
                  AND fv.LOOKUP_TYPE = 'XXAP_PROCESO_VALIDACION_MASIVA'
                  AND fv.lookup_code = 'EJECUTAR_COMPLETO';               
         exception 
            when others then
               v_tag_execute_all :='04:00';
         end ;
         v_time_execute_all := to_date(to_char(sysdate,'dd-mm-yyyy') || ' ' || v_tag_execute_all,'dd-mm-yyyy hh24:mi');

         if sysdate < v_time_execute_all then
            for cur in c_organizations_resp
            loop
                     BEGIN
                           IF v_responsibility_id != cur.responsibility_id then
                              v_responsibility_id := cur.responsibility_id;
                              XXLOG(p_Level => 3
                                 ,p_EXECUTION_ID => v_id_execution
                                 ,p_TEXT => 'ALL TRX Hace el seteo para el OrgId:' ||cur.org_id || ' Cia:' || cur.name_cia
                                 ,p_PROCESS_NAME => v_process
                                 ,p_VALUE1STR => cur.name_cia 
                                 ,p_VALUE2STR => 'AP_'||cur.name_cia||'_SISTEMAS' 
                                 ,p_VALUE3STR => v_tag_execute_all 
                                 ,p_VALUE1num => cur.org_id
                                 ,p_VALUE2num => v_responsibility_id);

                              apps.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize (pUser_id        => v_user_id,
                                                                                 pResp_id        => v_responsibility_id,  --v_resp_id,    AP
                                                                                 pResp_appl_id   => 200  -- AP_BEPUSA_SISTEMAS
                                                                                          );
                           END IF;
                           v_request_id :=0;

                           v_request_id :=apps.XXGEPP_APPS_UTILITIES_PKG.xx_submit_request (pOrg_id => cur.ORG_ID
                                                                                             ,papplication   => 'PO' --Purchasing
                                                                                             ,pprogram       => 'POXPOIV' --Pay On Receipt AutoInvoice
                                                                                             ,pdescription   => 'Pay On Receipt AutoInvoice Program - BotGepp'                                                                                                                         
                                                                                             ,pargument1     => NULL --ALL
                                                                                             ,pargument2     => '1'
                                                                                             ,pargument3     =>  NULL--cur.shipment_header_id
                                                                                             ,pargument4     => 0
                                                                                             ,pargument5     => 'N'
                                                                                             );

                           COMMIT;    

                           IF v_request_id > 0 THEN
                              XXLOG(p_Level => 3
                                    ,p_EXECUTION_ID => v_id_execution
                                    ,p_TEXT => 'Request_id:'|| v_request_id || ' ORG_ID:'|| cur.ORG_ID
                                    ,p_PROCESS_NAME => v_process
                                    ,p_VALUE1STR => cur.ORG_ID                                                                      
                                    ,p_VALUE2num => v_request_id);


                              COMMIT;

                              	DECLARE
							           v_end_concurrent_program BOOLEAN;
							           v_seonds_of_waiting number:=10;
							           V_Phase                    VARCHAR2 (50);
							           V_Status                   VARCHAR2 (50);
							           V_Dev_Phase                VARCHAR2 (50);
							           V_Dev_Status               VARCHAR2 (50);
							           V_Message                  VARCHAR2 (50);
							     BEGIN 
							           	LOOP							
							              v_end_concurrent_program := apps.XXGEPP_APPS_UTILITIES_PKG.wait_for_request (v_request_id,       --NUMERO DE REQUEST
							                                                                                         v_seonds_of_waiting, --CANTIDAD DE SEGUNDOS QUE ESPERA PARA CHECAR DE NUEVO EL CONCURRENTE
							                                                                                         0,                        -- VALOR FIJO
							                                                                                         v_phase,
							                                                                                         v_status,
							                                                                                         v_dev_phase,
							                                                                                         v_dev_status,
							                                                                                         v_message);

							              IF v_end_concurrent_program THEN
							                 IF UPPER (v_status) <> 'ERROR' THEN	
							                 	XXLOG(p_Level => 3
					                                    ,p_EXECUTION_ID => v_id_execution
					                                    ,p_TEXT => '1 ALL Termino OK en el Request_id:'|| v_request_id || ' ORG_ID:'|| cur.ORG_ID
					                                    ,p_PROCESS_NAME => v_process
					                                    ,p_VALUE1STR => cur.ORG_ID                                                                      
					                                    ,p_VALUE2num => v_request_id);
							                       COMMIT;
							                 ELSE		
							                 	XXLOG(p_Level => 3
					                                    ,p_EXECUTION_ID => v_id_execution
					                                    ,p_TEXT => '1 ALL Error en el Request_id:'|| v_request_id || ' ORG_ID:'|| cur.ORG_ID
					                                    ,p_PROCESS_NAME => v_process
					                                    ,p_VALUE1STR => cur.ORG_ID                                                                      
					                                    ,p_VALUE2num => v_request_id);
							                       COMMIT;
							                 END IF;
							              END IF;
							              EXIT WHEN v_end_concurrent_program;--UPPER (v_phase) = 'COMPLETED' OR UPPER (v_dev_phase) = 'COMPLETED' OR UPPER (v_status) IN ('CANCELLED', 'ERROR', 'TERMINATED') OR UPPER (v_dev_status) IN ('CANCELLED', 'ERROR', 'TERMINATED');
							              END LOOP;							
							           COMMIT;
							     END;

                           ELSE
                              XXLOG(p_Level => 3
                                    ,p_EXECUTION_ID => v_id_execution
                                    ,p_TEXT => 'Error no pudo ejecutar el Request_id:'|| v_request_id || ' ORG_ID:'|| cur.ORG_ID
                                    ,p_PROCESS_NAME => v_process
                                    ,p_VALUE1STR => cur.ORG_ID                                                                      
                                    ,p_VALUE2num => v_request_id);
                           END IF;
                        EXCEPTION
                           WHEN OTHERS THEN
                              XXLOG(p_Level => 3
                                       ,p_EXECUTION_ID => v_id_execution
                                       ,p_TEXT => 'OTHERS Error no pudo ejecutar el Request_id:'|| v_request_id || ' ORG_ID:'|| cur.ORG_ID || ' SQLERRM:' || substr(SQLERRM,1,50)
                                       ,p_PROCESS_NAME => v_process
                                       ,p_VALUE1STR => cur.ORG_ID                                     
                                       ,p_VALUE2num => v_request_id);
                        END;
            end loop;
         else

            -- Determina los días hacia atras para barrer con base a la fecha de creación de las facturas
            if pin_ejecuta_dias = 0 then
                  v_fecha_barrido := trunc(to_date(pin_fecha_barrido, 'dd-mm-yyyy')); -- Probar el formato cuando se asigne a un concurrente
            else
                  v_fecha_barrido := trunc(sysdate)- abs(pin_ejecuta_dias);
            end if;

            open c_receipts(v_fecha_barrido,v_id_execution);
            loop
               fetch c_receipts 
               BULK COLLECT INTO l_c_receipts
                  LIMIT c_limit;
               EXIT WHEN l_c_receipts.COUNT = 0;

               FOR I IN 1 .. l_c_receipts.COUNT loop
                  INSERT INTO XXAP_TRACKING_POXPOIV_L_TBL
                  values l_c_receipts(I);
                  end loop;
               commit;
            end loop;

            -- Agrupa el execution_id para ver si hay que procesar
            insert into XXAP_TRACKING_POXPOIV_H_TBL(
                        EXECUTION_ID
                        ,RECEIPT_NUM
                        ,VENDOR_ID
                        ,ORG_ID
                        ,STEP_CTRL
                        ,CREATION_DATE
                        ,CREATED_BY
                        ,LAST_UPDATE_DATE
                        ,LAST_UPDATED_BY
                        ,SHIPMENT_HEADER_ID
                        ,PO_HEADER_ID
                        ,SOURCE
                        )
            select EXECUTION_ID
               ,RECEIPT_NUM
               ,VENDOR_ID
               ,ORG_ID
               ,1 --STEP_CTRL
               ,sysdate 
               ,v_user_id
               ,sysdate 
               ,v_user_id
               ,SHIPMENT_HEADER_ID
               ,PO_HEADER_ID
               ,SOURCE
            from XXAP_TRACKING_POXPOIV_L_TBL
            where 1=1
            and execution_id = v_id_execution
            and source = 'ERS'
            group by EXECUTION_ID
               ,RECEIPT_NUM
               ,VENDOR_ID
               ,ORG_ID
               ,SHIPMENT_HEADER_ID
               ,PO_HEADER_ID
               ,SOURCE;

            commit;

            open c_uses(v_fecha_barrido,v_id_execution);
            loop
               fetch c_uses 
               BULK COLLECT INTO l_c_uses
                  LIMIT c_limit;
               EXIT WHEN l_c_uses.COUNT = 0;

               FOR I IN 1 .. l_c_uses.COUNT loop
                  INSERT INTO XXAP_TRACKING_POXPOIV_L_TBL
                  values l_c_uses(I);
                  end loop;
               commit;
            end loop;

            insert into XXAP_TRACKING_POXPOIV_H_TBL(
                        EXECUTION_ID
                        ,RECEIPT_NUM
                        ,VENDOR_ID
                        ,ORG_ID
                        ,STEP_CTRL
                        ,CREATION_DATE
                        ,CREATED_BY
                        ,LAST_UPDATE_DATE
                        ,LAST_UPDATED_BY
                        ,SHIPMENT_HEADER_ID
                        ,PO_HEADER_ID
                        ,SOURCE
                        )
            select EXECUTION_ID
               ,RECEIPT_NUM
               ,VENDOR_ID
               ,ORG_ID
               ,1 --STEP_CTRL
               ,sysdate 
               ,v_user_id
               ,sysdate 
               ,v_user_id
               ,SHIPMENT_HEADER_ID
               ,PO_HEADER_ID
               ,SOURCE
            from XXAP_TRACKING_POXPOIV_L_TBL
            where 1=1
            and execution_id = v_id_execution
            and source = 'USE'
            group by EXECUTION_ID
               ,RECEIPT_NUM
               ,VENDOR_ID
               ,ORG_ID
               ,SHIPMENT_HEADER_ID
               ,PO_HEADER_ID
               ,SOURCE;

            commit;

            SELECT COUNT(*)
            INTO v_count_trx
            FROM XXAP_TRACKING_POXPOIV_H_TBL
            WHERE 1=1
            AND EXECUTION_ID = v_id_execution;

            IF v_count_trx=0 THEN
               XXLOG(p_Level => 3
                     ,p_EXECUTION_ID => v_id_execution
                     ,p_TEXT => 'There were NOT receipts to process'
                     ,p_PROCESS_NAME => v_process);
            ELSIF v_count_trx>0 THEN
               XXLOG(p_Level => 3
                  ,p_EXECUTION_ID => v_id_execution
                  ,p_TEXT => 'There were receipts to process'
                  ,p_PROCESS_NAME => v_process);


               -- Sent the concurrent for compañy, receipt and shipment_header_id            
               FOR CUR IN (SELECT ORG_ID--, RECEIPT_NUM
                                 --,SHIPMENT_HEADER_ID
                                 ,NVL((select r.responsibility_id
                                    from apps.fnd_responsibility_tl r
                                       ,hr.hr_all_organization_units u
                                    where 1=1
                                    and u.organization_id = TT.ORG_ID
                                    and r.language = 'ESA'
                                    and r.responsibility_name = 'AP_' || u.name || '_SISTEMAS'),-666) responsibility_id
                                 ,(select name from hr.hr_all_organization_units u where u.organization_id = TT.ORG_ID) name_cia
                           FROM XXAP_TRACKING_POXPOIV_H_TBL TT
                           WHERE 1=1
                           AND SOURCE = 'ERS'
                           AND EXECUTION_ID = v_id_execution
                           --AND ROWNUM = 1
                           GROUP BY ORG_ID
                           --ORDER BY ORG_ID--, SHIPMENT_HEADER_ID
                           )
               LOOP
                     IF cur.responsibility_id = -666 THEN
                        XXLOG(p_Level => 3
                              ,p_EXECUTION_ID => v_id_execution
                              ,p_TEXT => 'ERS No se pudo localizar la responsabilidad AP_%SISTEMAS para el OrgId:' ||cur.org_id || ' Cia:' || cur.name_cia
                              ,p_PROCESS_NAME => v_process
                              ,p_VALUE1STR => cur.name_cia 
                              --,p_VALUE2STR => NULL--cur.receipt_num
                              ,p_VALUE1num => cur.org_id);
                     ELSE
                        BEGIN
                           IF v_responsibility_id != cur.responsibility_id then
                              v_responsibility_id := cur.responsibility_id;
                              XXLOG(p_Level => 3
                                 ,p_EXECUTION_ID => v_id_execution
                                 ,p_TEXT => 'ERS Hace el seteo para el OrgId:' ||cur.org_id || ' Cia:' || cur.name_cia
                                 ,p_PROCESS_NAME => v_process
                                 ,p_VALUE1STR => cur.name_cia 
                                 ,p_VALUE2STR => 'AP_'||cur.name_cia||'_SISTEMAS' 
                                 ,p_VALUE1num => cur.org_id
                                 ,p_VALUE2num => v_responsibility_id);

                              apps.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize (pUser_id        => v_user_id,
                                                                                 pResp_id        => v_responsibility_id,  --v_resp_id,    AP
                                                                                 pResp_appl_id   => 200  -- AP_BEPUSA_SISTEMAS
                                                                                          );
                           END IF;
                           v_request_id :=0;

                           v_request_id :=apps.XXGEPP_APPS_UTILITIES_PKG.xx_submit_request (pOrg_id => cur.ORG_ID
                                                                                             ,papplication   => 'PO' --Purchasing
                                                                                             ,pprogram       => 'POXPOIV' --Pay On Receipt AutoInvoice
                                                                                             ,pdescription   => 'Pay On Receipt AutoInvoice Program - BotGepp'                                                                                                                         
                                                                                             ,pargument1     => 'ERS'
                                                                                             ,pargument2     => '1'
                                                                                             ,pargument3     =>  NULL--cur.shipment_header_id
                                                                                             ,pargument4     => 0
                                                                                             ,pargument5     => 'N'
                                                                                             );

                           COMMIT;    

                           IF v_request_id > 0 THEN
                              XXLOG(p_Level => 3
                                    ,p_EXECUTION_ID => v_id_execution
                                    ,p_TEXT => 'ERS Request_id:'|| v_request_id --|| ' SHIPMENT_HEADER_ID:'|| cur.shipment_header_id
                                    ,p_PROCESS_NAME => v_process
                                    --,p_VALUE1STR => NULL--cur.receipt_num                                     
                                    --,p_VALUE1num => cur.shipment_header_id
                                    ,p_VALUE2num => v_request_id);

                              UPDATE XXAP_TRACKING_POXPOIV_H_TBL
                              SET REQUEST_ID = v_request_id
                                 ,LAST_UPDATE_DATE = sysdate
                                 ,LAST_UPDATED_BY = v_user_id
                              WHERE 1=1
                              AND ORG_ID =cur.org_id
                              AND EXECUTION_ID = v_id_execution
                              --AND SHIPMENT_HEADER_ID = cur.shipment_header_id
                              AND SOURCE='ERS';
                              COMMIT;

                              DECLARE
							           v_end_concurrent_program BOOLEAN;
							           v_seonds_of_waiting number:=10;
							           V_Phase                    VARCHAR2 (50);
							           V_Status                   VARCHAR2 (50);
							           V_Dev_Phase                VARCHAR2 (50);
							           V_Dev_Status               VARCHAR2 (50);
							           V_Message                  VARCHAR2 (50);
							     BEGIN 
							           	LOOP							
							              v_end_concurrent_program := apps.XXGEPP_APPS_UTILITIES_PKG.wait_for_request (v_request_id,       --NUMERO DE REQUEST
							                                                                                         v_seonds_of_waiting, --CANTIDAD DE SEGUNDOS QUE ESPERA PARA CHECAR DE NUEVO EL CONCURRENTE
							                                                                                         0,                        -- VALOR FIJO
							                                                                                         v_phase,
							                                                                                         v_status,
							                                                                                         v_dev_phase,
							                                                                                         v_dev_status,
							                                                                                         v_message);

							              IF v_end_concurrent_program THEN
							                 IF UPPER (v_status) <> 'ERROR' THEN	
							                 	XXLOG(p_Level => 3
					                                    ,p_EXECUTION_ID => v_id_execution
					                                    ,p_TEXT => '2 ERS Termino OK en el Request_id:'|| v_request_id || ' ORG_ID:'|| cur.ORG_ID
					                                    ,p_PROCESS_NAME => v_process
					                                    ,p_VALUE1STR => cur.ORG_ID                                                                      
					                                    ,p_VALUE2num => v_request_id);
							                       COMMIT;
							                 ELSE		
							                 	XXLOG(p_Level => 3
					                                    ,p_EXECUTION_ID => v_id_execution
					                                    ,p_TEXT => '2 ERS Error en el Request_id:'|| v_request_id || ' ORG_ID:'|| cur.ORG_ID
					                                    ,p_PROCESS_NAME => v_process
					                                    ,p_VALUE1STR => cur.ORG_ID                                                                      
					                                    ,p_VALUE2num => v_request_id);
							                       COMMIT;
							                 END IF;
							              END IF;
							              EXIT WHEN v_end_concurrent_program;--UPPER (v_phase) = 'COMPLETED' OR UPPER (v_dev_phase) = 'COMPLETED' OR UPPER (v_status) IN ('CANCELLED', 'ERROR', 'TERMINATED') OR UPPER (v_dev_status) IN ('CANCELLED', 'ERROR', 'TERMINATED');
							              END LOOP;							
							           COMMIT;
							     END;

                           ELSE
                              XXLOG(p_Level => 3
                                    ,p_EXECUTION_ID => v_id_execution
                                    ,p_TEXT => 'ERS Error no pudo ejecutar el Request_id:'|| v_request_id 
                                    ,p_PROCESS_NAME => v_process
                                    ,p_VALUE1STR => cur.ORG_ID
                                    ,p_VALUE2num => v_request_id);
                           END IF;
                        EXCEPTION
                           WHEN OTHERS THEN
                              XXLOG(p_Level => 3
                                       ,p_EXECUTION_ID => v_id_execution
                                       ,p_TEXT => 'ERS OTHERS Error no pudo ejecutar el Request_id:'|| v_request_id || ' SQLERRM:' || substr(SQLERRM,1,50)
                                       ,p_PROCESS_NAME => v_process                                        
                                       ,p_VALUE1STR => cur.ORG_ID                                        
                                       ,p_VALUE2num => v_request_id);
                        END;
                     END IF;
               END LOOP;

               -- Los USE los ejecuta por compañia
               FOR CUR IN (SELECT ORG_ID
                                 ,NVL((select r.responsibility_id
                                    from apps.fnd_responsibility_tl r
                                       ,hr.hr_all_organization_units u
                                    where 1=1
                                    and u.organization_id = TT.ORG_ID
                                    and r.language = 'ESA'
                                    and r.responsibility_name = 'AP_' || u.name || '_SISTEMAS'),-666) responsibility_id
                                 ,(select name from hr.hr_all_organization_units u where u.organization_id = TT.ORG_ID) name_cia
                           FROM XXAP_TRACKING_POXPOIV_H_TBL TT
                           WHERE 1=1
                           AND SOURCE = 'USE'
                           AND EXECUTION_ID = v_id_execution
                           GROUP BY ORG_ID
                           ORDER BY ORG_ID)
               LOOP
                     IF cur.responsibility_id = -666 THEN
                        XXLOG(p_Level => 3
                              ,p_EXECUTION_ID => v_id_execution
                              ,p_TEXT => 'USE No se pudo localizar la responsabilidad AP_%SISTEMAS para el OrgId:' ||cur.org_id || ' Cia:' || cur.name_cia
                              ,p_PROCESS_NAME => v_process
                              ,p_VALUE1STR => cur.name_cia 
                              ,p_VALUE1num => cur.org_id);
                     ELSE
                        BEGIN
                           IF v_responsibility_id != cur.responsibility_id then
                              v_responsibility_id := cur.responsibility_id;
                              XXLOG(p_Level => 3
                                 ,p_EXECUTION_ID => v_id_execution
                                 ,p_TEXT => 'Hace el seteo para el OrgId:' ||cur.org_id || ' Cia:' || cur.name_cia
                                 ,p_PROCESS_NAME => v_process
                                 ,p_VALUE1STR => cur.name_cia 
                                 ,p_VALUE2STR => 'AP_'||cur.name_cia||'_SISTEMAS' 
                                 ,p_VALUE1num => cur.org_id
                                 ,p_VALUE2num => v_responsibility_id);

                              apps.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize (pUser_id        => v_user_id,
                                                                                 pResp_id        => v_responsibility_id,  --v_resp_id,    AP
                                                                                 pResp_appl_id   => 200  -- AP_BEPUSA_SISTEMAS
                                                                                          );
                           END IF;
                           v_request_id :=0;

                           v_request_id :=apps.XXGEPP_APPS_UTILITIES_PKG.xx_submit_request (pOrg_id => cur.ORG_ID
                                                                                             ,papplication   => 'PO' --Purchasing
                                                                                             ,pprogram       => 'POXPOIV' --Pay On Receipt AutoInvoice
                                                                                             ,pdescription   => 'Pay On Receipt AutoInvoice Program - BotGepp'                                                                                                                         
                                                                                             ,pargument1     => 'USE'
                                                                                             ,pargument2     => '1'
                                                                                             ,pargument3     =>  NULL--cur.shipment_header_id
                                                                                             ,pargument4     => 0
                                                                                             ,pargument5     => 'N'
                                                                                             );

                           COMMIT;    

                           IF v_request_id > 0 THEN
                              XXLOG(p_Level => 3
                                    ,p_EXECUTION_ID => v_id_execution
                                    ,p_TEXT => 'Request_id:'|| v_request_id || ' ORG_ID:'|| cur.ORG_ID
                                    ,p_PROCESS_NAME => v_process
                                    ,p_VALUE1STR => cur.ORG_ID                                                                      
                                    ,p_VALUE2num => v_request_id);

                              UPDATE XXAP_TRACKING_POXPOIV_H_TBL
                              SET REQUEST_ID = v_request_id
                                 ,LAST_UPDATE_DATE = sysdate
                                 ,LAST_UPDATED_BY = v_user_id
                              WHERE 1=1
                              AND EXECUTION_ID = v_id_execution
                              AND ORG_ID = cur.ORG_ID
                              AND SOURCE ='USE';
                              COMMIT;

                              DECLARE
							           v_end_concurrent_program BOOLEAN;
							           v_seonds_of_waiting number:=10;
							           V_Phase                    VARCHAR2 (50);
							           V_Status                   VARCHAR2 (50);
							           V_Dev_Phase                VARCHAR2 (50);
							           V_Dev_Status               VARCHAR2 (50);
							           V_Message                  VARCHAR2 (50);
							     BEGIN 
							           	LOOP							
							              v_end_concurrent_program := apps.XXGEPP_APPS_UTILITIES_PKG.wait_for_request (v_request_id,       --NUMERO DE REQUEST
							                                                                                         v_seonds_of_waiting, --CANTIDAD DE SEGUNDOS QUE ESPERA PARA CHECAR DE NUEVO EL CONCURRENTE
							                                                                                         0,                        -- VALOR FIJO
							                                                                                         v_phase,
							                                                                                         v_status,
							                                                                                         v_dev_phase,
							                                                                                         v_dev_status,
							                                                                                         v_message);

							              IF v_end_concurrent_program THEN
							                 IF UPPER (v_status) <> 'ERROR' THEN	
							                 	XXLOG(p_Level => 3
					                                    ,p_EXECUTION_ID => v_id_execution
					                                    ,p_TEXT => '3 USE Termino OK en el Request_id:'|| v_request_id || ' ORG_ID:'|| cur.ORG_ID
					                                    ,p_PROCESS_NAME => v_process
					                                    ,p_VALUE1STR => cur.ORG_ID                                                                      
					                                    ,p_VALUE2num => v_request_id);
							                       COMMIT;
							                 ELSE		
							                 	XXLOG(p_Level => 3
					                                    ,p_EXECUTION_ID => v_id_execution
					                                    ,p_TEXT => '3 USE Error en el Request_id:'|| v_request_id || ' ORG_ID:'|| cur.ORG_ID
					                                    ,p_PROCESS_NAME => v_process
					                                    ,p_VALUE1STR => cur.ORG_ID                                                                      
					                                    ,p_VALUE2num => v_request_id);
							                       COMMIT;
							                 END IF;
							              END IF;
							              EXIT WHEN v_end_concurrent_program;--UPPER (v_phase) = 'COMPLETED' OR UPPER (v_dev_phase) = 'COMPLETED' OR UPPER (v_status) IN ('CANCELLED', 'ERROR', 'TERMINATED') OR UPPER (v_dev_status) IN ('CANCELLED', 'ERROR', 'TERMINATED');
							              END LOOP;							
							           COMMIT;
							     END;

                           ELSE
                              XXLOG(p_Level => 3
                                    ,p_EXECUTION_ID => v_id_execution
                                    ,p_TEXT => 'Error no pudo ejecutar el Request_id:'|| v_request_id || ' ORG_ID:'|| cur.ORG_ID
                                    ,p_PROCESS_NAME => v_process
                                    ,p_VALUE1STR => cur.ORG_ID                                                                      
                                    ,p_VALUE2num => v_request_id);
                           END IF;
                        EXCEPTION
                           WHEN OTHERS THEN
                              XXLOG(p_Level => 3
                                       ,p_EXECUTION_ID => v_id_execution
                                       ,p_TEXT => 'OTHERS Error no pudo ejecutar el Request_id:'|| v_request_id || ' ORG_ID:'|| cur.ORG_ID || ' SQLERRM:' || substr(SQLERRM,1,50)
                                       ,p_PROCESS_NAME => v_process
                                       ,p_VALUE1STR => cur.ORG_ID                                     
                                       ,p_VALUE2num => v_request_id);
                        END;
                     END IF;
               END LOOP;

            END IF;
         END IF;

    EXCEPTION
      when hay_procesos_ejecutandose then 
         vg_msg := v_msj_exception;
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution, p_TEXT => vg_msg,  p_VALUE1NUM => l_request_id);
      WHEN es_fin_mes THEN
         vg_msg := 'SEND_REQUEST_POXPOIV ES CIERRE DE MES '  || v_msj_exception;
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution, p_TEXT => vg_msg,  p_VALUE1NUM => l_request_id);
      WHEN OTHERS THEN
         vg_msg := 'SEND_REQUEST_POXPOIV ERROR OTHERS [' || SQLCODE  || '] ' || SUBSTR(SQLERRM,1,100);
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution, p_TEXT => vg_msg, p_VALUE1NUM => l_request_id);

    END SEND_REQUEST_POXPOIV;

    PROCEDURE XXPRUEBA_CONCURRENTE
    IS
      v_request_id NUMBER;
    BEGIN
         execute immediate 'ALTER SESSION SET NLS_LANGUAGE =  "LATIN AMERICAN SPANISH" ';

         APPS.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize(pUser_Id =>3994
                                                         ,pResp_Id =>50671
                                                         ,pResp_Appl_Id =>200);

         v_request_id := APPS.XXGEPP_APPS_UTILITIES_PKG.xx_submit_request(pOrg_id => 84
                                                                           ,papplication => 'PO'
                                                                           ,pprogram =>   'POXPOIV'
                                                                           ,pdescription =>'Pay On Receipt AutoInvoice Program - BotGepp'
                                                                           ,pargument1     => NULL
                                                                           ,pargument2     => '1'
                                                                           ,pargument3     => NULL--cur.shipment_header_id
                                                                           ,pargument4     => 0
                                                                           ,pargument5     => 'N'
                                                                           );

    END XXPRUEBA_CONCURRENTE;

    FUNCTION GET_RESP_ID (p_execution_id number,P_INVOICE_ID NUMBER) RETURN NUMBER
    AS
      v_return number;
      v_id_execution number;
    BEGIN
         v_id_execution := p_execution_id;

         select r.responsibility_id
         into v_return
         from apps.fnd_responsibility_tl r
            ,hr.hr_all_organization_units u
            ,ap_invoices_all ai
         where 1=1
         and ai.invoice_id = P_INVOICE_ID
         and u.organization_id = ai.org_id
         and r.language = 'ESA'
         and r.responsibility_name = 'AP_' || u.name || '_SISTEMAS';

      return v_return;
   exception
      when others then
         v_return:= -666;
         XXLOG(p_Level => 1
               ,p_EXECUTION_ID => v_id_execution
               ,p_TEXT => 'OTHERS Error al obtener resp_id invoice_id:' || P_INVOICE_ID || ' SQLERRM:' || substr(SQLERRM,1,50)
               ,p_PROCESS_NAME => 'GET_RESP_ID'                         
               ,p_VALUE1num => P_INVOICE_ID);
         return v_return;         
   end GET_RESP_ID;

   PROCEDURE XX_CREATE_ACCOUNTING(errbuf out varchar2, retcode out number)
   IS
      cursor c_organizations (pFechaBarrido date) is
                select u.organization_id as org_id, u.name, u.attribute15 cia, r.responsibility_id, r.responsibility_name
                  from apps.FND_LOOKUP_VALUES_VL fv
                      ,hr.hr_all_organization_units u  
                      ,apps.fnd_responsibility_tl r  
                 where 1=1
                   AND fv.ENABLED_FLAG = 'Y'
                   AND NVL (fv.END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE
                   AND fv.LOOKUP_TYPE = 'CUST_AP_EMPRESAS_LKP'
                   and u.name = fv.meaning
                   and r.language = 'ESA'
                   and r.responsibility_name = 'AP_' || u.name || '_SISTEMAS'
                   /*and u.organization_id in (select xte.security_id_int_1
                                             from apps.XLA_AE_HEADERS                XAH
                                                ,XLA.XLA_TRANSACTION_ENTITIES  XTE
                                             where 1=1
                                             and xah.application_id = 200
                                             and xte.entity_id = xah.entity_id
                                             and xah.gl_transfer_status_code is null
                                             and xah.creation_date >= pFechaBarrido--to_date('01-04-2025','dd-mm-yyyy')
                                             group by xte.security_id_int_1)*/
                 order by u.organization_id;

      --v_fecha_barrido date;
      v_user_id       number;
      v_id_execution number;
      v_process_name VARCHAR2(20):='XX_CREATE_ACCOUNTING';

      v_fecha_barrido date;
      v_responsibility_id number;
      v_request_id number;

      v_fecha_contabilidad_str varchar2(30);
      v_fecha_contabilidad_date date;
      v_nombre_lote varchar2(1000);
      v_num_periods_open number;
      v_period_name varchar(10);
      v_start_date date;
      v_end_date date;

      es_fin_mes EXCEPTION;
      v_status_excecute_process varchar2(1000);
      v_status_code varchar2(2);
      v_msj_exception varchar2(1000);
      l_request_id number;
    BEGIN
      v_id_execution := to_char(sysdate,'YYYYMMDDHH24MISS');
      l_request_id := fnd_global.conc_request_id;

      v_status_excecute_process := STATUS_TO_EXCECUTE_THE_PROCESS('PROCESO4') || ' Requist_Id:'||l_request_id;
      v_status_code := substr(v_status_excecute_process,1,2);

      IF v_status_code = 'NE' THEN
         v_msj_exception := v_status_excecute_process;
         raise es_fin_mes;
      ELSIF CUST_AP_VALIDA_ES_CIERRE_FNC() IN ('Y1') AND v_status_code = 'CA' THEN
         v_msj_exception := 'Y1 - '|| v_status_excecute_process;
         raise es_fin_mes;
      ELSIF CUST_AP_VALIDA_ES_CIERRE_FNC() IN ('Y2') THEN
         v_msj_exception := 'Y2 - '|| v_status_excecute_process;
         raise es_fin_mes;
      END IF;

         v_request_id := -666;
         v_responsibility_id := 0;
         v_num_periods_open := 0;

         execute immediate 'ALTER SESSION SET NLS_LANGUAGE =  "LATIN AMERICAN SPANISH" ';



         XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => 'INICIA PROCESO XX_CREATE_ACCOUNTING'
                ,p_PROCESS_NAME =>v_process_name);


         -- Obtiene el ID del usuario
         v_user_id := apps.FND_GLOBAL.USER_ID();
         --vg_Resp_Id := 50671; -- Se inia en AP_BEPUSA_SISTEMAS
         -- Si regresa -1 es por no se lanzo desde la aplicación o no esta seteado el usuario
         IF  v_user_id = -1 THEN
              v_user_id := 1250; --Asigna el usuario 1250 que es Oracle en esta instancia de eBS                
         END IF; 

         GET_OPEN_PERIOD(200,v_period_name, v_start_date,v_end_date,v_num_periods_open );        

        IF SYSDATE < v_end_date THEN
            v_fecha_contabilidad_date := TRUNC(SYSDATE);
        ELSE
            v_fecha_contabilidad_date := v_end_date;
        END IF;


         v_fecha_contabilidad_str := to_char(v_fecha_contabilidad_date,'yyyy/mm/dd') || ' 00:00:00';--'2025/04/30 00:00:00';

         vg_msg := 'Parameters v_num_periods_open:' || v_num_periods_open || ' v_fecha_barrido:' || to_char(v_fecha_barrido,'yyyy/mm/dd hh24:mi:ss') || ' v_fecha_contabilidad:' || v_fecha_contabilidad_str;
         XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg, p_value1num => v_num_periods_open ,p_value1str => to_char(v_fecha_barrido,'yyyy/mm/dd hh24:mi:ss'),p_value2str => v_fecha_contabilidad_str,p_PROCESS_NAME =>v_process_name);

         for cur_org in c_organizations(v_fecha_barrido)
         loop
            v_request_id := 0;
               IF v_responsibility_id != cur_org.responsibility_id THEN
                  v_responsibility_id := cur_org.responsibility_id;

                  APPS.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize(pUser_Id =>v_user_id
                                                         ,pResp_Id =>v_responsibility_id
                                                         ,pResp_Appl_Id =>200);
                  v_nombre_lote := 'Prueba CEDC ' || cur_org.responsibility_name;
               END IF;

                vg_msg := 'Begin Org_id: '|| cur_org.org_id || ' Nombre:' || cur_org.name;
                XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg, p_value1num => cur_org.org_id ,p_value1str => cur_org.name,p_PROCESS_NAME =>v_process_name);

                  v_request_id := APPS.XXGEPP_APPS_UTILITIES_PKG.xx_submit_request(pOrg_id => cur_org.ORG_ID
                                                                           ,papplication => 'XLA'
                                                                           ,pprogram =>   'XLAACCPB' -- concurrent_program_id = 48121
                                                                           ,pdescription =>'XXCS Create Accounting ' || cur_org.responsibility_name
                                                                           ,pargument1=> '200'
                                                                            ,pargument2=> '200'
                                                                            ,pargument3=> 'Y'
                                                                            ,pargument4=> '2021'
                                                                            ,pargument5=> NULL
                                                                            ,pargument6=> v_fecha_contabilidad_str
                                                                            ,pargument7=> 'Y'
                                                                            ,pargument8=> 'Y'
                                                                            ,pargument9=> 'F'
                                                                            ,pargument10=> 'Y'
                                                                            ,pargument11=> 'N'
                                                                            ,pargument12=> 'N'
                                                                            ,pargument13=> 'Y'
                                                                            ,pargument14=> 'Y'
                                                                            ,pargument15=> 'N'
                                                                            ,pargument16=> v_nombre_lote
                                                                            ,pargument17=> NULL
                                                                            ,pargument18=> 'N'
                                                                            ,pargument19=> NULL
                                                                            ,pargument20=> NULL
                                                                            ,pargument21=> 'Payables'
                                                                            ,pargument22=> 'Payables'
                                                                            ,pargument23=> 'Oracle GEPP'
                                                                            ,pargument24=> NULL
                                                                            ,pargument25=> 'Yes'
                                                                            ,pargument26=> 'Final'
                                                                            ,pargument27=> 'No'
                                                                            ,pargument28=> 'No Report'
                                                                            ,pargument29=> 'Yes'
                                                                            ,pargument30=> 'No'
                                                                            ,pargument31=> 'No'
                                                                            ,pargument32=> NULL
                                                                            ,pargument33=> NULL
                                                                            ,pargument34=> NULL
                                                                            ,pargument35=> NULL
                                                                            ,pargument36=> NULL
                                                                            ,pargument37=> NULL
                                                                            ,pargument38=> NULL
                                                                            ,pargument39=> NULL
                                                                            ,pargument40=> 'N'
                                                                            ,pargument41=> 'No'
                                                                            ,pargument42=> 'N'
                                                                            ,pargument43=> v_user_id
                                                                            ,pargument44=> 'N'
                                                                           );
               commit;

               vg_msg := 'End Org_id: '|| cur_org.org_id || ' Nombre:' || cur_org.name || ' v_request_id:'|| v_request_id;
               XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg, p_value1num => cur_org.org_id ,p_value1str => cur_org.name,p_PROCESS_NAME =>v_process_name);

         end loop;
         if v_request_id = -666 then
            vg_msg := 'NO hay nada que procesar v_num_periods_open:' || v_num_periods_open || ' v_fecha_barrido:' || to_char(v_fecha_barrido,'yyyy/mm/dd hh24:mi:ss') || ' v_fecha_contabilidad:' || v_fecha_contabilidad_str;
            XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg, p_value1num => v_num_periods_open ,p_value1str => to_char(v_fecha_barrido,'yyyy/mm/dd hh24:mi:ss'),p_value2str => v_fecha_contabilidad_str,p_PROCESS_NAME =>v_process_name);
         end if;
         XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => 'TERMINA PROCESO XX_CREATE_ACCOUNTING'
                ,p_PROCESS_NAME =>v_process_name);
   EXCEPTION
      WHEN es_fin_mes THEN
         vg_msg := 'XX_CREATE_ACCOUNTING ES CIERRE DE MES ' || v_msj_exception;
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution, p_TEXT => vg_msg, p_VALUE1NUM => l_request_id);
      WHEN OTHERS THEN
         vg_msg := 'XX_CREATE_ACCOUNTING ERROR OTHERS ' || SQLCODE;
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution, p_TEXT => vg_msg, p_VALUE1NUM => l_request_id);

   END XX_CREATE_ACCOUNTING;

   PROCEDURE XX_VALIDATE_INVOICES(errbuf out varchar2, retcode out number)
   IS
      v_Module_Batch number:=400; -- Lotes de 400
      v_execution_id_val number;
      v_user_id       number;
      v_num_lote number;
      v_batch_name varchar2(200);
      v_responsibility_id number;
      v_all_invoice_id_clob CLOB;
      v_error_code number;
      v_error_MSJ varchar2(3000);
      v_request_id number;
      v_numrows_updated number;
      v_process_name VARCHAR2(20):='XX_VALIDATE_INVOICES';
      es_fin_mes EXCEPTION;
      v_status_excecute_process varchar2(1000);
      v_status_code varchar2(2);
      v_msj_exception varchar2(1000);
      l_request_id number;
    BEGIN
       v_execution_id_val := to_char(sysdate,'YYYYMMDDHH24MISS');
      l_request_id := fnd_global.conc_request_id;

      v_status_excecute_process := STATUS_TO_EXCECUTE_THE_PROCESS('PROCESO3') || ' Requist_Id:'||l_request_id;
      v_status_code := substr(v_status_excecute_process,1,2);

      IF v_status_code = 'NE' THEN
         v_msj_exception := v_status_excecute_process;
         raise es_fin_mes;
      ELSIF CUST_AP_VALIDA_ES_CIERRE_FNC() IN ('Y1') AND v_status_code = 'CA' THEN
         v_msj_exception := 'Y1 - '|| v_status_excecute_process;
         raise es_fin_mes;
      ELSIF CUST_AP_VALIDA_ES_CIERRE_FNC() IN ('Y2') THEN
         v_msj_exception := 'Y2 - '|| v_status_excecute_process;
         raise es_fin_mes;
      END IF;

      v_responsibility_id := 0;
      v_num_lote := 0;
      execute immediate 'ALTER SESSION SET NLS_LANGUAGE =  "LATIN AMERICAN SPANISH" ';



      --dbms_output.put_line('v_execution_id_val:'||v_execution_id_val);
      MESSAGE_LOG('v_execution_id_val:'||v_execution_id_val);

      XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_execution_id_val
                ,p_TEXT => 'INICIA PROCESO '||v_process_name|| ' v_execution_id_val:' || v_execution_id_val
                ,p_PROCESS_NAME => v_process_name
                ,p_VALUE1NUM => v_execution_id_val);

      v_user_id := apps.FND_GLOBAL.USER_ID();    
      -- Si regresa -1 es por no se lanzo desde la aplicación o no esta seteado el usuario
      IF  v_user_id = -1 THEN
         v_user_id := 1250; --Asigna el usuario 1250 que es Oracle en esta instancia de eBS
      END IF;

      --dbms_output.put_line('v_user_id:'||v_user_id);
      vg_msg := 'v_user_id:'||v_user_id;
           XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_execution_id_val
                ,p_TEXT => vg_msg
                ,p_PROCESS_NAME => v_process_name);


      vg_msg := 'Begin call UPDATE_STATUS_INVOICES';
           XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_execution_id_val
                ,p_TEXT => vg_msg
                ,p_PROCESS_NAME => v_process_name);


      UPDATE_STATUS_INVOICES(v_execution_id_val,v_user_id);

      vg_msg := 'End call UPDATE_STATUS_INVOICES';

      XXLOG(p_Level => 3
            ,p_EXECUTION_ID => v_execution_id_val
            ,p_TEXT => vg_msg
            ,p_PROCESS_NAME => v_process_name);

      -- Se marcan las facturas que procesará
      UPDATE XXAP_TRACKING_INVOICES_TBL tb1 
         set EXECUTION_ID_VAL = v_execution_id_val
               ,STATUS_VAL = 'En Proceso'
               ,LAST_UPDATED_BY = v_user_id
               ,LAST_UPDATE_DATE = SYSDATE
      WHERE 1=1
      and TB1.INVOICE_ID IN (select ai.INVOICE_ID
                              from XXAP_TRACKING_INVOICES_TBL tb
                                 ,ap.ap_invoices_all ai
                                 ,ap.ap_suppliers pv
                              where 1=1
                              AND tb.source in ('ERS','USE')
                              and tb.step_ctrl = 5
                              AND (tb.num_holds_act = 0 or (tb.num_holds_act = 1 and tb.funds_hold_status=2)) -- No tenga algun otro hold activo o solo tenga control de fondos
                              and (tb.xml_hold_status = 1 or tb.foreign_hold_status = 1)                  -- Si tiene Hold Falta XML pero inactiva
                              and tb.fa_hold_status in (0,1) -- 0 NA Hold Valida FA -- 1 Tiene hold de FA pero inactiva
                              AND ai.invoice_id =  tb.invoice_id
                              AND Ap_Invoices_Pkg.Get_Approval_Status (Ai.Invoice_Id,
                                                                     Ai.Invoice_Amount,
                                                                     Ai.Payment_Status_Flag,
                                                                     Ai.Invoice_Type_Lookup_Code) in ('NEEDS REAPPROVAL', 'NEVER APPROVED')
                              AND pv.vendor_id = ai.vendor_id
                              --AND NVL(STATUS_VAL,'Nuevo') in ('Necesita Reproceso 1','Necesita Reproceso 2','Nuevo','Necesita Reproceso 3')
                              AND NVL(STATUS_VAL,'En Proceso') = 'En Proceso'
                              );

      v_numrows_updated := SQL%rowcount; 

      COMMIT;



      MESSAGE_LOG('v_numrows_updated:'||v_numrows_updated);

      if v_numrows_updated > 0 then

        MESSAGE_LOG('***** Generating batch names *****');
         -- read cursor for company and currency code
         for cur_cia_div in (select tb.org_id,
                                       tb.invoice_currency_code                                
                                 from XXAP_TRACKING_INVOICES_TBL tb
                                 where 1=1
                                 AND source in ('ERS','USE')
                                 and tb.EXECUTION_ID_VAL = v_execution_id_val                    
                                 --and tb.status_val = 'En Proceso'
                                 group by tb.org_id,tb.invoice_currency_code
                                 order by 1,2)
         loop 
               -- Create batch_name for company and currency each v_Module_Batch invoices
               for cur_i in (select tb.invoice_id
                                 ,rownum as nun_row
                                 from XXAP_TRACKING_INVOICES_TBL tb
                                 where 1=1
                                 AND source in ('ERS','USE')
                                 and tb.EXECUTION_ID_VAL = v_execution_id_val
                                 and tb.org_id = cur_cia_div.org_id
                                 and tb.invoice_currency_code = cur_cia_div.invoice_currency_code
                                 order by 1)
               loop 
                  if mod(cur_i.nun_row, v_Module_Batch) = 1 then
                     v_num_lote := v_num_lote + 1;
                     v_batch_name := 'XXCSVAL_'
                              || cur_cia_div.org_id
                              || '_'
                              || cur_cia_div.invoice_currency_code
                              || '_'
                              || v_execution_id_val
                              || '_'
                              || v_num_lote;
                  end if;

                  MESSAGE_LOG('ORG_ID: ' || cur_cia_div.org_id || '   v_num_lote: ' || v_num_lote || '   v_batch_name: ' || v_batch_name);

                  UPDATE XXAP_TRACKING_INVOICES_TBL tb1 
                     set BATCH_NAME_VAL = v_batch_name
                  WHERE 1=1
                  AND source in ('ERS','USE')
                  AND tb1.execution_id_val = v_execution_id_val
                  AND tb1.invoice_id = cur_i.invoice_id;

                  COMMIT;
               end loop;
         end loop;
         -- Create New Batch in Oracle AP
         MESSAGE_LOG('***** Generating batches in Oracle AP *****');
         for cur_nb in (select tb.org_id
                              ,tb.batch_name_val
                              ,XXWEBC.XXAP_TRACKING_AP_PKG.GET_RESP_ID (v_execution_id_val,tb.INVOICE_ID) responsibility_id
                     from XXAP_TRACKING_INVOICES_TBL tb
                     where 1=1
                     		AND source in ('ERS','USE')
                           and tb.EXECUTION_ID_VAL = v_execution_id_val
                           group by tb.org_id
                              ,tb.batch_name_val
                              ,XXWEBC.XXAP_TRACKING_AP_PKG.GET_RESP_ID (v_execution_id_val,tb.INVOICE_ID))
         loop 
               IF v_responsibility_id != cur_nb.responsibility_id THEN
                  v_responsibility_id := cur_nb.responsibility_id;
                  APPS.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize(pUser_Id =>v_user_id
                                                                     ,pResp_Id =>v_responsibility_id
                                                                     ,pResp_Appl_Id =>200);
               END IF;
               --v_all_invoice_id_clob := f_transpose (cur_nb.batch_name_val);

               APPS.XXGEPP_APPS_UTILITIES_PKG.CREATE_NEW_BATCH_PRC(P_EXECUTION_ID_VAL   => v_execution_id_val,
                                                                  P_BATCH_NAME    => cur_nb.batch_name_val,
                                                                  PUSER_ID => v_user_id,
                                                                  P_COD_ERR => v_error_code,
                                                                  P_MSJ_ERR => v_error_MSJ);
               dbms_output.put_line('v_error_code:'||v_error_code);
               dbms_output.put_line('v_error_MSJ:'||v_error_MSJ);
               IF v_error_code !=  0 THEN
                           --message_log ('Error en generación de lote.');
                  update XXAP_TRACKING_INVOICES_TBL tb
                     set STATUS_VAL = 'Necesita Reproceso 1'
                           ,LAST_UPDATED_BY = v_user_id
                           ,LAST_UPDATE_DATE = SYSDATE
                     where 1=1
                     AND source in ('ERS','USE')
                     and tb.EXECUTION_ID_VAL = v_execution_id_val
                     and tb.org_id = cur_nb.org_id
                     and tb.batch_name_val = cur_nb.batch_name_val;
                  commit;
               ELSE
                  COMMIT;            
               END IF;
         end loop;

         -- Send concurrents
         for cur_batch in (select tb.org_id
                              ,tb.batch_name_val
                              ,tb.batch_id_val
                              ,XXWEBC.XXAP_TRACKING_AP_PKG.GET_RESP_ID (v_execution_id_val,tb.INVOICE_ID) responsibility_id
                     from XXAP_TRACKING_INVOICES_TBL tb
                     where 1=1
                     	AND source in ('ERS','USE')
                           and tb.EXECUTION_ID_VAL = v_execution_id_val
                           and STATUS_VAL = 'En Proceso'
                           group by tb.org_id
                              ,tb.batch_name_val
                              ,tb.batch_id_val
                              ,XXWEBC.XXAP_TRACKING_AP_PKG.GET_RESP_ID (v_execution_id_val,tb.INVOICE_ID))
         loop 
               IF v_responsibility_id != cur_batch.responsibility_id THEN
                  v_responsibility_id := cur_batch.responsibility_id;
                  APPS.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize(pUser_Id =>v_user_id
                                                                     ,pResp_Id =>v_responsibility_id
                                                                     ,pResp_Appl_Id =>200);
               END IF;
               v_request_id :=0;
               -- Send concurrent
               v_request_id := APPS.XXGEPP_APPS_UTILITIES_PKG.xx_submit_request(pOrg_id => cur_batch.ORG_ID
                                                                              ,papplication => 'SQLAP'
                                                                              ,pprogram =>   'CUST_APPRVL' -- concurrent_program_id = 48121
                                                                              ,pdescription =>'XXCS - Proceso Interno Valida (NO EJECUTARLO) ['||v_execution_id_val||']' || cur_batch.batch_name_val
                                                                              ,pargument1=> cur_batch.org_id
                                                                              ,pargument2=> 'All'
                                                                              ,pargument3=> cur_batch.batch_id_val);
               dbms_output.put_line('v_request_id:'||v_request_id);
               commit;

               update XXAP_TRACKING_INVOICES_TBL tb
               set request_id_val = v_request_id
                  ,LAST_UPDATED_BY = v_user_id
                  ,LAST_UPDATE_DATE = SYSDATE
               where 1=1
               and tb.EXECUTION_ID_VAL = v_execution_id_val
               and tb.org_id = cur_batch.org_id
               and tb.batch_id_val = cur_batch.batch_id_val;
               commit;        
         end loop;

         -- If some request_id is 0, we chance status
         update XXAP_TRACKING_INVOICES_TBL tb
         set STATUS_VAL = 'Necesita Reproceso 2'
               ,LAST_UPDATED_BY = v_user_id
               ,LAST_UPDATE_DATE = SYSDATE
         where 1=1
         AND source in ('ERS','USE')
         and tb.EXECUTION_ID_VAL = v_execution_id_val
         and tb.request_id_val = 0
         and STATUS_VAL = 'En Proceso';
         commit;

         -- We validate how the concurrent finish
         DECLARE
               v_end_concurrent_program BOOLEAN;
               v_seonds_of_waiting number:=10;
               V_Phase                    VARCHAR2 (50);
               V_Status                   VARCHAR2 (50);
               V_Dev_Phase                VARCHAR2 (50);
               V_Dev_Status               VARCHAR2 (50);
               V_Message                  VARCHAR2 (50);
         BEGIN 
               FOR cr IN (SELECT request_id_val
                           FROM XXAP_TRACKING_INVOICES_TBL tb
                           WHERE 1=1
                           AND source in ('ERS','USE')
                           and tb.EXECUTION_ID_VAL = v_execution_id_val
                           and tb.request_id_val != 0
                           and tb.status_val = 'En Proceso'
                           GROUP BY request_id_val
                           ORDER BY request_id_val)
               loop
                  v_end_concurrent_program := false;
                  LOOP

                  v_end_concurrent_program := apps.XXGEPP_APPS_UTILITIES_PKG.wait_for_request (cr.request_id_val,       --NUMERO DE REQUEST
                                                                                             v_seonds_of_waiting, --CANTIDAD DE SEGUNDOS QUE ESPERA PARA CHECAR DE NUEVO EL CONCURRENTE
                                                                                             0,                        -- VALOR FIJO
                                                                                             v_phase,
                                                                                             v_status,
                                                                                             v_dev_phase,
                                                                                             v_dev_status,
                                                                                             v_message);

                  IF v_end_concurrent_program THEN
                     IF UPPER (v_status) <> 'ERROR' THEN
                           update XXAP_TRACKING_INVOICES_TBL tb
                           set STATUS_VAL = 'Procesado'
                              ,LAST_UPDATED_BY = v_user_id
                              ,LAST_UPDATE_DATE = SYSDATE
                           where 1=1
                           AND source in ('ERS','USE')
                           and tb.EXECUTION_ID_VAL = v_execution_id_val
                           and tb.request_id_val = cr.request_id_val
                           and STATUS_VAL = 'En Proceso';
                           commit;
                     ELSE
                           update XXAP_TRACKING_INVOICES_TBL tb
                           set STATUS_VAL = 'Error Procesado'
                              ,LAST_UPDATED_BY = v_user_id
                              ,LAST_UPDATE_DATE = SYSDATE
                           where 1=1
                           AND source in ('ERS','USE')
                           and tb.EXECUTION_ID_VAL = v_execution_id_val
                           and tb.request_id_val = cr.request_id_val
                           and STATUS_VAL = 'En Proceso';
                           commit;
                     END IF;
                  END IF;
                  EXIT WHEN v_end_concurrent_program;--UPPER (v_phase) = 'COMPLETED' OR UPPER (v_dev_phase) = 'COMPLETED' OR UPPER (v_status) IN ('CANCELLED', 'ERROR', 'TERMINATED') OR UPPER (v_dev_status) IN ('CANCELLED', 'ERROR', 'TERMINATED');
                  END LOOP;
                  COMMIT;
               END LOOP;

               -- Update status_invoice
               update XXAP_TRACKING_INVOICES_TBL tb
               SET (tb.approval_status
                  ,tb.posting_status            
                  , tb.LAST_UPDATE_DATE
                  ,tb.LAST_UPDATED_BY
                  ,tb.STATUS_VAL) = (select apps.ap_invoices_pkg.get_approval_status (ai.invoice_id,
                                                                                 ai.invoice_amount,
                                                                                 ai.payment_status_flag,
                                                                                 ai.invoice_type_lookup_code) approval_status,
                                                   ap_invoices_pkg.get_posting_status(ai.invoice_id) posting_status
                                                   ,sysdate
                                                   ,v_user_id
                                                   ,case when (apps.ap_invoices_pkg.get_approval_status (ai.invoice_id,
                                                                                 ai.invoice_amount,
                                                                                 ai.payment_status_flag,
                                                                                 ai.invoice_type_lookup_code))  IN ('NEEDS REAPPROVAL', 'NEVER APPROVED') THEN 
                                                               'Necesita Reproceso 3'
                                                         ELSE 
                                                               apps.ap_invoices_pkg.get_approval_status (ai.invoice_id,
                                                                                 ai.invoice_amount,
                                                                                 ai.payment_status_flag,
                                                                                 ai.invoice_type_lookup_code)
                                                         END
                                          from apps.ap_invoices_all ai
                                          where 1=1
                                          and ai.invoice_id = tb.invoice_id)

               where 1=1
               AND source in ('ERS','USE')
               and tb.EXECUTION_ID_VAL = v_execution_id_val
               and tb.STATUS_VAL in ('Error Procesado','Procesado');

               commit;
         end;

      end if;
   EXCEPTION
      WHEN es_fin_mes THEN
         vg_msg := 'XX_VALIDATE_INVOICES ES CIERRE DE MES ' || v_msj_exception;
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_execution_id_val, p_TEXT => vg_msg, p_VALUE1NUM => l_request_id);
      WHEN OTHERS THEN
         vg_msg := 'XX_VALIDATE_INVOICES ERROR OTHERS ' || SQLCODE;
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_execution_id_val, p_TEXT => vg_msg, p_VALUE1NUM => l_request_id);
   END XX_VALIDATE_INVOICES;

   PROCEDURE XX_TRANSFER_TO_ACCOUNTING(errbuf out varchar2, retcode out number)
   IS
   cursor c_organizations (pFechaBarrido date) is
                select u.organization_id as org_id, u.name, u.attribute15 cia, r.responsibility_id, r.responsibility_name
                  from apps.FND_LOOKUP_VALUES_VL fv
                      ,hr.hr_all_organization_units u  
                      ,apps.fnd_responsibility_tl r  
                 where 1=1
                   AND fv.ENABLED_FLAG = 'Y'
                   AND NVL (fv.END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE
                   AND fv.LOOKUP_TYPE = 'CUST_AP_EMPRESAS_LKP'
                   and u.name = fv.meaning
                   and r.language = 'ESA'
                   and r.responsibility_name = 'AP_' || u.name || '_SISTEMAS'
                   and u.organization_id in (select xte.security_id_int_1
                                             from apps.XLA_AE_HEADERS                XAH
                                                ,XLA.XLA_TRANSACTION_ENTITIES  XTE
                                             where 1=1
                                             and xah.application_id = 200
                                             and xte.entity_id = xah.entity_id
                                             and xah.gl_transfer_status_code is null
                                             and xah.creation_date >= pFechaBarrido--to_date('01-04-2025','dd-mm-yyyy')
                                             group by xte.security_id_int_1)
                 order by u.organization_id;

      --v_fecha_barrido date;
      v_user_id       number;
      v_id_execution number;
      v_process_name VARCHAR2(20):='XX_TRANSF_ACCOUNTING';

      v_fecha_barrido date;
      v_responsibility_id number;
      v_request_id number;

      v_fecha_contabilidad_str varchar2(30);
      v_fecha_contabilidad_date date;
      v_nombre_lote varchar2(1000);
      v_num_periods_open number;
      v_period_name varchar(10);
      v_start_date date;
      v_end_date date;
      es_fin_mes EXCEPTION;
      v_status_excecute_process varchar2(1000);
      v_status_code varchar2(2);
      v_msj_exception varchar2(1000);
      l_request_id number;
    BEGIN
      v_id_execution := to_char(sysdate,'YYYYMMDDHH24MISS');
      l_request_id := fnd_global.conc_request_id;

      v_status_excecute_process := STATUS_TO_EXCECUTE_THE_PROCESS('PROCESO5') || ' Requist_Id:'||l_request_id;
      v_status_code := substr(v_status_excecute_process,1,2);

      IF v_status_code = 'NE' THEN
         v_msj_exception := v_status_excecute_process;
         raise es_fin_mes;
      ELSIF CUST_AP_VALIDA_ES_CIERRE_FNC() IN ('Y1') AND v_status_code = 'CA' THEN
         v_msj_exception := 'Y1 - '|| v_status_excecute_process;
         raise es_fin_mes;
      ELSIF CUST_AP_VALIDA_ES_CIERRE_FNC() IN ('Y2') THEN
         v_msj_exception := 'Y2 - '|| v_status_excecute_process;
         raise es_fin_mes;
      END IF;

         v_request_id := -666;
         v_responsibility_id := 0;         

         execute immediate 'ALTER SESSION SET NLS_LANGUAGE =  "LATIN AMERICAN SPANISH" ';



         XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => 'INICIA PROCESO XX_TRANSFER_TO_ACCOUNTING'
                ,p_PROCESS_NAME =>v_process_name);


         -- Obtiene el ID del usuario
         v_user_id := apps.FND_GLOBAL.USER_ID();
         --vg_Resp_Id := 50671; -- Se inia en AP_BEPUSA_SISTEMAS
         -- Si regresa -1 es por no se lanzo desde la aplicación o no esta seteado el usuario
         IF  v_user_id = -1 THEN
              v_user_id := 1250; --Asigna el usuario 1250 que es Oracle en esta instancia de eBS                
         END IF; 

        GET_OPEN_PERIOD(200,v_period_name, v_start_date,v_end_date,v_num_periods_open );        

        IF SYSDATE < v_end_date THEN
            v_fecha_contabilidad_date := TRUNC(SYSDATE);
        ELSE
            v_fecha_contabilidad_date := v_end_date;
        END IF;

         v_fecha_contabilidad_str := to_char(v_fecha_contabilidad_date,'yyyy/mm/dd') || ' 00:00:00';--'2025/04/30 00:00:00';

         vg_msg := 'Parameters v_num_periods_open:' || v_num_periods_open || ' v_fecha_barrido:' || to_char(v_fecha_barrido,'yyyy/mm/dd hh24:mi:ss') || ' v_fecha_contabilidad:' || v_fecha_contabilidad_str;
         XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg, p_value1num => v_num_periods_open ,p_value1str => to_char(v_fecha_barrido,'yyyy/mm/dd hh24:mi:ss'),p_value2str => v_fecha_contabilidad_str,p_PROCESS_NAME =>v_process_name);

         for cur_org in c_organizations(v_fecha_barrido)
         loop
            v_request_id := 0;
               IF v_responsibility_id != cur_org.responsibility_id THEN
                  v_responsibility_id := cur_org.responsibility_id;

                  APPS.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize(pUser_Id =>v_user_id
                                                         ,pResp_Id =>v_responsibility_id
                                                         ,pResp_Appl_Id =>200);
                  v_nombre_lote := 'Prueba CEDC ' || cur_org.responsibility_name;
               END IF;

                vg_msg := 'Begin Org_id: '|| cur_org.org_id || ' Nombre:' || cur_org.name;
                XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg, p_value1num => cur_org.org_id ,p_value1str => cur_org.name,p_PROCESS_NAME =>v_process_name);

                  v_request_id := APPS.XXGEPP_APPS_UTILITIES_PKG.xx_submit_request(pOrg_id => cur_org.ORG_ID
                                                                           ,papplication => 'XLA'
                                                                           ,pprogram =>   'XLAGLTRN' -- concurrent_program_id = 48121
                                                                           ,pdescription =>'XXCS Transfer Journal Entries to GL ' || cur_org.responsibility_name
                                                                           ,pargument1  => '200'
                                                                           ,pargument2  => '200'
                                                                           ,pargument3  => 'Y'
                                                                           ,pargument4  => '2021'
                                                                           ,pargument5  => NULL
                                                                           ,pargument6  => v_fecha_contabilidad_str
                                                                           ,pargument7  => 'N'
                                                                           ,pargument8  => NULL
                                                                           ,pargument9  => NULL
                                                                           ,pargument10  => 'Y'
                                                                           ,pargument11  => NULL
                                                                           ,pargument12  => NULL
                                                                           ,pargument13  => 'Y'
                                                                           ,pargument14  => 'Y'
                                                                           ,pargument15  => 'N'
                                                                           ,pargument16  => v_nombre_lote
                                                                           ,pargument17  => NULL
                                                                           ,pargument18  => NULL
                                                                           ,pargument19  => NULL
                                                                           ,pargument20  => 'Payables'
                                                                           ,pargument21  => 'Payables'
                                                                           ,pargument22  => 'Oracle GEPP'
                                                                           ,pargument23  => NULL
                                                                           ,pargument24  => 'No'
                                                                           ,pargument25  => NULL
                                                                           ,pargument26  => NULL
                                                                           ,pargument27  => NULL
                                                                           ,pargument28  => 'Yes'
                                                                           ,pargument29  => 'No'
                                                                           ,pargument30  => NULL
                                                                           ,pargument31  => NULL
                                                                           ,pargument32  => NULL
                                                                           ,pargument33  => NULL
                                                                           ,pargument34  => NULL
                                                                           ,pargument35  => NULL
                                                                           ,pargument36  => NULL
                                                                           ,pargument37  => NULL
                                                                           ,pargument38  => 'N'
                                                                           ,pargument39  => 'N'

                                                                           );
               commit;

               vg_msg := 'End Org_id: '|| cur_org.org_id || ' Nombre:' || cur_org.name || ' v_request_id:'|| v_request_id;
               XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg, p_value1num => cur_org.org_id ,p_value1str => cur_org.name,p_PROCESS_NAME =>v_process_name);

         end loop;
         if v_request_id = -666 then
            vg_msg := 'NO hay nada que procesar v_num_periods_open:' || v_num_periods_open || ' v_fecha_barrido:' || to_char(v_fecha_barrido,'yyyy/mm/dd hh24:mi:ss') || ' v_fecha_contabilidad:' || v_fecha_contabilidad_str;
            XXLOG(p_Level => 3 ,p_EXECUTION_ID => v_id_execution ,p_TEXT => vg_msg, p_value1num => v_num_periods_open ,p_value1str => to_char(v_fecha_barrido,'yyyy/mm/dd hh24:mi:ss'),p_value2str => v_fecha_contabilidad_str,p_PROCESS_NAME =>v_process_name);
         end if;
         XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => 'TERMINA PROCESO XX_TRANSFER_TO_ACCOUNTING'
                ,p_PROCESS_NAME =>v_process_name);
   EXCEPTION
      WHEN es_fin_mes THEN
         vg_msg := 'XX_TRANSFER_TO_ACCOUNTING ES CIERRE DE MES ' || v_msj_exception;
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution, p_TEXT => vg_msg, p_VALUE1NUM => l_request_id);
      WHEN OTHERS THEN
         vg_msg := 'XX_TRANSFER_TO_ACCOUNTING ERROR OTHERS ' || SQLCODE;
         XXLOG(p_Level => 1 ,p_EXECUTION_ID => v_id_execution, p_TEXT => vg_msg, p_VALUE1NUM => l_request_id);
   END XX_TRANSFER_TO_ACCOUNTING;

    PROCEDURE GET_OPEN_PERIOD(p_application_id in number, p_period_name OUT VARCHAR2, p_start_date OUT DATE, p_end_date OUT DATE, p_num_periods_open OUT number)
    IS
        v_start_date DATE;
        v_end_date DATE;
        v_num_periods_open NUMBER;
        v_period_name varchar2(10);
    BEGIN
        SELECT count(period_name) ,max(start_date)  
         into v_num_periods_open,v_start_date
         FROM APPS.GL_PERIOD_STATUSES
         WHERE 1=1
           AND application_id = p_application_id --200 -- This is the number of application for account payables
           AND CLOSING_STATUS = 'O';

        if v_num_periods_open > 1 then
            -- If num of periods open is greater than 1, we are gount to return one month
            v_start_date := TO_DATE(to_char((v_start_date-2),'YYYY-MM') || '-01','YYYY-MM-DD');
        end if;

        -- Get data of period
        select end_date, PERIOD_NAME
         into v_end_date,v_period_name
         FROM APPS.GL_PERIOD_STATUSES
         WHERE 1=1
            AND application_id = p_application_id--200
            AND CLOSING_STATUS = 'O'
            and start_date = v_start_date;

        -- return value in out parameters
        p_period_name := v_period_name;
        p_start_date := v_start_date;
        p_end_date := v_end_date;
        p_num_periods_open := v_num_periods_open;

    END GET_OPEN_PERIOD;

    FUNCTION GET_END_DATE_PERIOD(p_application_id in number, p_period_name in VARCHAR2) return date
    is
      v_return date;
    begin
        select end_date
         into v_return
         FROM APPS.GL_PERIOD_STATUSES
         WHERE 1=1
            AND application_id = p_application_id
            and PERIOD_NAME = p_period_name;

      return v_return;
    end GET_END_DATE_PERIOD;

    PROCEDURE TRACKING_MONITOR_BUILDER(p_period_name VARCHAR2)
    IS   
        executing_now_raise EXCEPTION;
        period_closed_raise EXCEPTION;
        period_future_raise EXCEPTION;

        v_id_execution number;
        v_user_id NUMBER;
        v_process_name varchar2(35):='TRACKING_MONITOR_BUILDER';
        v_mensaje varchar2(1000);

        v_executing number;
        v_period_name VARCHAR2(10);
        v_start_date DATE;
        v_end_date DATE;
        v_closing_status VARCHAR2(1);
        v_org_id number;

        v_id number;
        v_num_ers_use_processed NUMBER;
        v_num_lines_pending_interface NUMBER;
        v_num_inv_ap number;
        v_num_invoices_ap_new NUMBER;
        v_num_invoices_ap_old NUMBER;
        v_num_hold_faltaxml number;
        v_num_hold_prov_extranjero number;
        v_num_hold_valida_fa number;
        v_num_hold_funds_control number;
        v_num_hold_factura_partida number;
        v_num_hold_dif_impuesto number;
        v_num_hold_others number;
        v_num_inv_validated number;
        v_num_inv_validated_wip number;
        V_num_inv_accounted NUMBER;
        V_num_inv_accounted_WIP NUMBER;
        V_num_inv_trasnfered_gl_wip number;

        v_is_open_period boolean;
        v_period_name_op VARCHAR2(10);
         v_start_date_op date;
         v_end_date_op date;
         v_num_periods_open_op number;


        cursor c_organizations  is
            select u.organization_id as org_id, u.name, u.attribute15 cia
            from apps.FND_LOOKUP_VALUES_VL fv
                  ,hr.hr_all_organization_units u  
            where 1=1
               AND fv.ENABLED_FLAG = 'Y'
               AND NVL (fv.END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE
               AND fv.LOOKUP_TYPE = 'CUST_AP_EMPRESAS_LKP'
               and u.name = fv.meaning
               and exists (select 'ex'
                           from XXAP_TRACKING_INVOICES_TBL
                           where org_id = u.organization_id);
    BEGIN
         EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
         v_is_open_period := FALSE;
         GET_OPEN_PERIOD(200, v_period_name_op, v_start_date_op, v_end_date_op, v_num_periods_open_op);

         IF v_period_name = p_period_name THEN
            v_is_open_period:= TRUE;
         END IF;


         v_id_execution := to_char(sysdate,'YYYYMMDDHH24MISS');
         -- Obtiene el ID del usuario
         v_user_id := apps.FND_GLOBAL.USER_ID();
         --vg_Resp_Id := 50671; -- Se inia en AP_BEPUSA_SISTEMAS
         -- Si regresa -1 es por no se lanzo desde la aplicación o no esta seteado el usuario
         IF  v_user_id = -1 THEN
              v_user_id := 1250; --Asigna el usuario 1250 que es Oracle en esta instancia de eBS                
         END IF;

         XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => 'INICIA PROCESO '|| v_process_name
                ,p_PROCESS_NAME =>v_process_name);

         v_period_name := p_period_name;

         select count(*)
         into v_executing
         from XXAPEX_DASHBOARD_AP_TRACKING@OCIPROD_TO_ORAPROD19
         where 1=1
         and status= 0;

         if v_executing > 0 then
            v_mensaje := 'Hay un proceso en ejecución por lo que no se puede continuar';
            raise executing_now_raise;
         end if;

         select end_date, START_DATE, CLOSING_STATUS
         into v_end_date,v_start_date, v_closing_status
         FROM APPS.GL_PERIOD_STATUSES
         WHERE 1=1
            AND application_id = 200
            and PERIOD_NAME = v_period_name;

         IF v_closing_status != 'O' THEN
            v_mensaje := 'El periodo ejecutado no esta abierto por lo que no se puede continuar';
            raise period_closed_raise;
         END IF;


         IF v_end_date_op < v_start_date THEN
            v_mensaje := 'El periodo ' || v_period_name || ' es futuro. El periodo de cierre actual es:' || v_period_name_op;
            RAISE period_future_raise;
         END IF;


         -- We inserted control row
         --v_id := 0;
         -- Get max id
         select nvl(max(id),0)+1 as id
         into v_id
         from XXAPEX_DASHBOARD_AP_TRACKING@OCIPROD_TO_ORAPROD19
         where 1=1;

         insert into XXAPEX_DASHBOARD_AP_TRACKING@OCIPROD_TO_ORAPROD19
         (id,execution_id,org_id,status,period_name)
         values(v_id,v_id_execution,-666,0,v_period_name);
         commit;

         for cur_org in c_organizations
         loop
                     v_id := v_id +1;

                     v_org_id := cur_org.org_id;

                     -- Get Total of invoices loaded whit source ERS and USE
                     SELECT COUNT(INVOICE_ID)
                        INTO v_num_ers_use_processed
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     and org_id = v_org_id
                     AND CREATION_DATE_INV BETWEEN v_start_date AND v_end_date
                     AND SOURCE IN ('ERS','USE');

                     -- Interface AP -- Get Total of distinct InvoiceNum in Intarface Table
                     select count(distinct invoice_num)
                     into v_num_lines_pending_interface
                     from xxwebc.xxap_ap_int_rej_v
                     where 1=1
                     and org_id = v_org_id
                     and invoice_date BETWEEN v_start_date AND v_end_date;

                     -- Get Total of invoices with step_ctrl 1,5,99
                     SELECT sum(case when invoice_date <= v_end_date 
                                    then 1 else 0 end),
                           sum(case when CREATION_DATE_INV >=v_start_date 
                                          and invoice_date >= v_start_date 
                                          and invoice_date <= v_end_date 
                                    then 1 else 0 end),
                           sum(case when CREATION_DATE_INV < v_start_date then 1 else 0 end)
                        INTO v_num_inv_ap
                           ,v_num_invoices_ap_new
                           ,v_num_invoices_ap_old
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     and org_id = v_org_id
                     --and period_name = v_period_name
                     AND step_ctrl in (1,5,99)
                     AND INVOICE_DATE <= v_end_date --BETWEEN TO_DATE('01-05-2025','DD-MM-YYYY') AND TO_DATE('30-05-2025','DD-MM-YYYY')
                     AND SOURCE IN ('ERS','USE');

                     SELECT COUNT(DISTINCT INVOICE_ID)
                           into v_num_hold_faltaxml
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     and org_id = v_org_id
                     AND step_ctrl in (1,5,99)
                     and XML_HOLD_STATUS = 2 --  OR FOREIGN_HOLD_STATUS = 2)
                     AND INVOICE_DATE <= v_end_date
                     AND SOURCE IN ('ERS','USE');

                     SELECT COUNT(DISTINCT INVOICE_ID)
                           into v_num_hold_prov_extranjero
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     and org_id = v_org_id
                     AND step_ctrl in (1,5,99)
                     and FOREIGN_HOLD_STATUS = 2
                     AND INVOICE_DATE <= v_end_date
                     AND SOURCE IN ('ERS','USE');

                     SELECT COUNT(INVOICE_ID)
                           into v_num_hold_valida_fa
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     and org_id = v_org_id
                     AND step_ctrl in (1,5,99)
                     and XML_HOLD_STATUS != 2 
                     and FOREIGN_HOLD_STATUS != 2
                     and FA_HOLD_STATUS = 2  
                     AND INVOICE_DATE <= v_end_date                      
                     AND SOURCE IN ('ERS','USE');

                     -- otros holds
                     SELECT COUNT(INVOICE_ID)
                     into v_num_hold_others
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     and org_id = v_org_id
                     AND step_ctrl in (1,5,99)
                     and XML_HOLD_STATUS != 2 
                     and FOREIGN_HOLD_STATUS != 2
                     and FA_HOLD_STATUS != 2
                     and SPLITED_INVOICE_HOLD_STATUS != 2
                     and DIFFERENCE_TAX_HOLD_STATUS != 2
                     and other_holds_STATUS =2  
                     AND INVOICE_DATE <= v_end_date
                     AND SOURCE IN ('ERS','USE');

                     -- Control de fondos
                     SELECT COUNT(INVOICE_ID)
                     into v_num_hold_funds_control
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     and org_id = v_org_id
                     AND step_ctrl in (1,5,99)    
                     and XML_HOLD_STATUS != 2 
                     and FOREIGN_HOLD_STATUS != 2
                     and FA_HOLD_STATUS != 2
                     and OTHER_HOLDS_STATUS != 2 
                     and FUNDS_HOLD_STATUS =2  
                     AND INVOICE_DATE <= v_end_date
                     AND SOURCE IN ('ERS','USE');

                     -- Factura partida
                     SELECT COUNT(INVOICE_ID)
                     into v_num_hold_factura_partida
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     and org_id = v_org_id
                     AND step_ctrl in (1,5,99)    
                     and XML_HOLD_STATUS != 2 
                     and FOREIGN_HOLD_STATUS != 2
                     and FA_HOLD_STATUS != 2
                     --and OTHER_HOLDS_STATUS != 2 
                     and SPLITED_INVOICE_HOLD_STATUS =2  
                     AND INVOICE_DATE <= v_end_date
                     AND SOURCE IN ('ERS','USE');

                     -- Diferencia impuestos
                     SELECT COUNT(INVOICE_ID)
                     into v_num_hold_dif_impuesto
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     and org_id = v_org_id
                     AND step_ctrl in (1,5,99)    
                     and XML_HOLD_STATUS != 2 
                     and FOREIGN_HOLD_STATUS != 2
                     and FA_HOLD_STATUS != 2
                     --and OTHER_HOLDS_STATUS != 2 
                     and DIFFERENCE_TAX_HOLD_STATUS =2  
                     AND INVOICE_DATE <= v_end_date
                     AND SOURCE IN ('ERS','USE');

                     SELECT COUNT(DISTINCT INVOICE_ID)
                        into v_num_inv_validated
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     and org_id = v_org_id
                     and period_name = v_period_name        
                     --and NUM_HOLDS_ACT = 0
                     and approval_status IN ('APPROVED')
                     AND INVOICE_DATE <= v_end_date
                     AND SOURCE IN ('ERS','USE');

                     SELECT COUNT(DISTINCT INVOICE_ID)
                        into v_num_inv_validated_wip
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1        
                     and org_id = v_org_id
                     --and period_name = v_period_name
                     and NUM_HOLDS_ACT = 0
                     and approval_status IN ('NEEDS REAPPROVAL', 'NEVER APPROVED')
                     AND INVOICE_DATE <= v_end_date
                     AND SOURCE IN ('ERS','USE');

                     SELECT COUNT(DISTINCT INVOICE_ID)
                        into V_num_inv_accounted
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     and org_id = v_org_id
                     and period_name = v_period_name    
                     and approval_status IN ('APPROVED')            
                     and POSTING_STATUS = 'Y'
                     AND INVOICE_DATE <= v_end_date
                     AND SOURCE IN ('ERS','USE');

                     SELECT COUNT(DISTINCT INVOICE_ID)
                        into V_num_inv_accounted_wip
                     FROM XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     and org_id = v_org_id
                     and period_name = v_period_name                
                     and approval_status IN ('APPROVED')
                     and POSTING_STATUS = 'N'
                     AND INVOICE_DATE <= v_end_date
                     AND SOURCE IN ('ERS','USE');

                     --IF v_is_open_period THEN
                        select count(distinct xte.SOURCE_ID_INT_1)
                        INTO v_num_inv_trasnfered_gl_wip
                        from apps.XLA_AE_HEADERS                XAH
                              ,XLA.XLA_TRANSACTION_ENTITIES  XTE
                        where 1=1        
                        and xah.application_id = 200
                        --and xah.creation_date >= v_start_date--to_date('01-04-2025','dd-mm-yyyy')
                        and xah.period_name = v_period_name
                        and xah.GL_TRANSFER_DATE is null
                        AND xte.security_id_int_1 = v_org_id        
                        and xte.entity_id = xah.entity_id                     
                        and xte.application_id = xah.application_id;
                     --ELSE
                       -- v_num_inv_trasnfered_gl_wip := 0;
                     --END IF;

                     INSERT INTO XXAPEX_DASHBOARD_AP_TRACKING@OCIPROD_TO_ORAPROD19
                        (id
                        ,execution_id
                        ,org_id
                        ,period_name
                        ,status
                        ,num_ers_use_processed
                        ,num_lines_pending_interface
                        ,num_inv_ap
                        ,num_invoices_ap_new
                        ,num_invoices_ap_old
                        ,num_hold_faltaxml
                        ,num_hold_prov_extranjero
                        ,num_hold_valida_fa
                        ,num_hold_funds_control
                        ,num_hold_factura_partida
                        ,num_hold_dif_impuesto
                        ,num_hold_others
                        ,num_inv_validated
                        ,num_inv_validated_wip
                        ,num_inv_accounted
                        ,num_inv_accounted_wip
                        ,num_inv_trasnfered_gl_wip
                        ,created_by
                        ,creation_date 
                        ,last_update_by
                        ,last_updated_date)
                     VALUES(
                         v_id
                        ,v_id_execution
                        ,v_org_id
                        ,v_period_name
                        ,0
                        ,v_num_ers_use_processed
                        ,v_num_lines_pending_interface
                        ,v_num_inv_ap
                        ,v_num_invoices_ap_new
                        ,v_num_invoices_ap_old
                        ,v_num_hold_faltaxml
                        ,v_num_hold_prov_extranjero
                        ,v_num_hold_valida_fa
                        ,v_num_hold_funds_control
                        ,v_num_hold_factura_partida
                        ,v_num_hold_dif_impuesto
                        ,v_num_hold_others
                        ,v_num_inv_validated
                        ,v_num_inv_validated_wip
                        ,v_num_inv_accounted
                        ,v_num_inv_accounted_wip
                        ,v_num_inv_trasnfered_gl_wip
                        ,v_user_id
                        ,sysdate
                        ,v_user_id
                        ,sysdate
                     );
               COMMIT;
         end loop;

         -- Update status 1 to 2
         update XXAPEX_DASHBOARD_AP_TRACKING@OCIPROD_TO_ORAPROD19
         set status = 2
            ,last_update_by = v_user_id
            ,last_updated_date = sysdate
         where 1=1
         and status = 1
         and period_name = v_period_name;

         commit;

         -- Update ststus 0 to status 1
         update XXAPEX_DASHBOARD_AP_TRACKING@OCIPROD_TO_ORAPROD19
         set status = 1
            ,last_update_by = v_user_id
            ,last_updated_date = sysdate
         where 1=1
         and status = 0
         and period_name = v_period_name;

         commit;

         XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => 'TERMINA PROCESO '|| v_process_name
                ,p_PROCESS_NAME =>v_process_name);
    EXCEPTION
      WHEN period_future_raise THEN
         XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => v_mensaje
                ,p_PROCESS_NAME =>v_process_name);
      WHEN executing_now_raise THEN
         XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => v_mensaje
                ,p_PROCESS_NAME =>v_process_name);
      WHEN period_closed_raise THEN
         XXLOG(p_Level => 3
                ,p_EXECUTION_ID => v_id_execution
                ,p_TEXT => v_mensaje
                ,p_PROCESS_NAME =>v_process_name);
    END TRACKING_MONITOR_BUILDER;

    PROCEDURE UPDATE_ROW_TRACKING(pin_invoice_id number, pin_user_id in number,pin_process_name VARCHAR2)
    IS
      v_return number;
    BEGIN
         EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
         v_return := 0;

         UPDATE /*+index(tb XXAP_TRACKING_INVOICES_TBL_N1)*/ XXWEBC.XXAP_TRACKING_INVOICES_TBL TB
        SET (tb.approval_status
            ,tb.posting_status
            ,tb.invoice_num) = (select apps.ap_invoices_pkg.get_approval_status (ai.invoice_id,
                                                                                    ai.invoice_amount,
                                                                                    ai.payment_status_flag,
                                                                                    ai.invoice_type_lookup_code) approval_status,
                                            ap_invoices_pkg.get_posting_status(ai.invoice_id) posting_status
                                            ,invoice_num
                                       from apps.ap_invoices_all ai
                                       where 1=1
                                       and ai.invoice_id = tb.invoice_id)
            ,tb.last_update_date = sysdate
            ,tb.last_updated_by = pin_user_id
            ,NUM_HOLDS =  GET_COUNT_HOLD(tb.invoice_id, 'ALL', 'ALL')
            ,NUM_HOLDS_ACT =  GET_COUNT_HOLD(tb.invoice_id, 'ALL', 'ACT')            
            ,XML_HOLD = GET_COUNT_HOLD(tb.invoice_id, 'Falta XML', 'ALL')
            ,XML_HOLD_STATUS = GET_COUNT_HOLD(tb.invoice_id, 'Falta XML', 'STATUS')
            ,fa_hold  = GET_COUNT_HOLD(tb.invoice_id, 'Falta Validacion AF', 'ALL') 
            ,fa_hold_status = GET_COUNT_HOLD(tb.invoice_id, 'Falta Validacion AF', 'STATUS') 
            ,foreign_hold = GET_COUNT_HOLD(tb.invoice_id, 'Proveedor Extranjero', 'ALL')  
            ,foreign_hold_status = GET_COUNT_HOLD(tb.invoice_id, 'Proveedor Extranjero', 'STATUS') 
            ,funds_hold = GET_COUNT_HOLD(tb.invoice_id, 'SE ENCUENTRA EN PROCESO DE LIBERACION', 'ALL')  
            ,funds_hold_status = GET_COUNT_HOLD(tb.invoice_id, 'SE ENCUENTRA EN PROCESO DE LIBERACION', 'STATUS') 
            ,difference_tax_hold = GET_COUNT_HOLD(tb.invoice_id, 'Dif en Impuestos CUST', 'ALL')--'Diferencia en Impuesto', 'ALL')  
            ,difference_tax_hold_status = GET_COUNT_HOLD(tb.invoice_id, 'Dif en Impuestos CUST', 'ALL')--'Diferencia en Impuesto', 'STATUS') 
            ,splited_invoice_hold = GET_COUNT_HOLD(tb.invoice_id, 'Factura Partida', 'ALL')  
            ,splited_invoice_hold_status = GET_COUNT_HOLD(tb.invoice_id, 'Factura Partida', 'STATUS') 
            ,other_holds = GET_COUNT_HOLD(tb.invoice_id, 'Other Holds', 'ALL')  
            ,other_holds_status = GET_COUNT_HOLD(tb.invoice_id, 'Other Holds', 'STATUS') 
            ,hold_manual_review_ers_nc = GET_COUNT_HOLD(tb.invoice_id, 'Resvision Manual', 'ALL')  
	         ,hold_man_rev_status_ers_nc = GET_COUNT_HOLD(tb.invoice_id, 'Resvision Manual', 'STATUS') 
        WHERE 1=1
        AND tb.invoice_id = pin_invoice_id;

         COMMIT;

    EXCEPTION 
      WHEN OTHERS THEN
         vg_msg := 'Error al actualizar Invoice_ID:'||pin_invoice_id || ' Proceso:'||pin_process_name;
         XXLOG(p_Level => 4 ,p_invoice_id => pin_invoice_id ,p_TEXT => vg_msg,p_PROCESS_NAME =>pin_process_name);

    END UPDATE_ROW_TRACKING;

    FUNCTION IS_FOREIGN_SUPPLIER(pin_vendor_id NUMBER,pin_vendor_site_id NUMBER) RETURN VARCHAR2
    IS
      v_return varchar2(2);
    BEGIN
         v_return :='';

               select case when gcc.segment5 = '2108' and gcc.segment6 = '0087' then 'Y'
                                    ELSE 'N'
                                    end
               into v_return
                from apps.ap_supplier_sites_all ass
                     ,apps.gl_code_combinations gcc

               where 1 = 1                 
                 and ass.vendor_id = pin_vendor_id
                 and ass.vendor_site_id = pin_vendor_site_id
                 and gcc.code_combination_id = ass.accts_pay_code_combination_id;

         return v_return;
    EXCEPTION 
      WHEN OTHERS THEN
         v_return :='NE';
         return v_return;
    END IS_FOREIGN_SUPPLIER;

    FUNCTION CUST_AP_VALIDA_ES_CIERRE_FNC--(pin_period_name VARCHAR2)
      RETURN VARCHAR2
    IS
      v_retrurn VARCHAR2(30);

      v_period_name varchar2(10);
      v_start_date date;
      v_end_date date;
      v_num_periods_open NUMBER;
      v_count_provision NUMBER;
    BEGIN
         EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
         /*XXLOG(p_Level => 3
                ,p_EXECUTION_ID => -666
                ,p_TEXT => 'entro');*/

         GET_OPEN_PERIOD(200, v_period_name, v_start_date, v_end_date, v_num_periods_open);

         


         SELECT COUNT(1)
            INTO v_count_provision
         FROM
            xxwebc.xxgepp_ap_provision_ejec_tbl
         WHERE
                1 = 1
            AND tipo = 'COMPLEMENTO'
            AND periodo = TO_CHAR(ADD_MONTHS(v_start_date,-1),'MON-YY')
            --v_period_name
         					;
         

         IF TRUNC(SYSDATE) <= v_end_date AND v_count_provision > 0 THEN -- Not is date of period closed
            RETURN 'N'; 
         ELSIF TRUNC(SYSDATE) > v_end_date THEN -- More of one periods open
            RETURN 'Y1';
         ELSIF TRUNC(SYSDATE) <= v_end_date AND v_count_provision = 0 THEN -- Only one period open but provisión process not exeute yet
            RETURN 'Y2';
         ELSE
            RETURN 'ERR';
         END IF;
    END CUST_AP_VALIDA_ES_CIERRE_FNC;

    FUNCTION STATUS_TO_EXCECUTE_THE_PROCESS(pin_process_name varchar2) RETURN VARCHAR2
    IS
      v_tag varchar2(100);
      v_enabled_flag varchar2(3);
      v_meaning varchar2(100);
      v_return varchar2(1000);
    BEGIN
         select  enabled_flag, UPPER(tag), meaning
         into v_enabled_flag, v_tag, v_meaning
            from apps.FND_LOOKUP_VALUES_VL fv  
            where 1=1
               --AND fv.ENABLED_FLAG = 'Y'
               AND NVL (fv.END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE
               AND fv.LOOKUP_TYPE = 'XXAP_PROCESO_VALIDACION_MASIVA'
               AND fv.lookup_code = pin_process_name;
		 
         -- Tag E -> Enabled 
    	 -- NE No Encontrado
         IF nvl(v_tag,'VACIO') !='E' THEN
            RETURN 'NE|' || v_meaning || ' Se desactivo la ejecución Tag diferente de E en lookup XXAP_PROCESO_VALIDACION_MASIVA';
         END IF;
		
         -- CA Candado Activo
         IF v_enabled_flag ='Y' THEN
            RETURN 'CA|' || v_meaning || ' Candado de cierre de mes activo para el proceso';
         END IF;
		 
         -- CI Candado Inactivo
         IF v_enabled_flag !='Y' THEN
            RETURN 'CI|' || v_meaning || ' Candado de cierre de mes inactivo se puede ejecutar en cierre';
         END IF;
    EXCEPTION
      WHEN OTHERS THEN
         RETURN 'NE| Ocurrio un error al revisar proceso no se ejecutará';
    END STATUS_TO_EXCECUTE_THE_PROCESS;

    PROCEDURE APPLY_HOLD_NC(pin_user_id IN NUMBER, pin_id_executon IN NUMBER)
    IS
      v_id_execution NUMBER;
      v_resp number;
      v_org_id number;
      v_user_id number;
      v_process_name varchar2(100);
      v_result_num number;
      v_msg_hold varchar2(1000);
    begin
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''latin american spanish''';
        v_process_name := 'APPLY_HOLD_NC';
        v_user_id := pin_user_id;
        v_org_id := 0;
        v_id_execution := pin_id_executon;

        -- Validar si tiene retencion de XML o Proveedor extranjero
        -- Se actualiza nuevamente por los registros pasados que no haya podido procesar en ejecuciones anteriores        

         FOR cur IN (SELECT INVOICE_ID
                     FROM XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
                     WHERE 1=1
                     AND STEP_CTRL = 1
                     AND XML_HOLD = 0
                     AND FOREIGN_HOLD = 0
                     )
         LOOP
            UPDATE_ROW_TRACKING(cur.invoice_id, v_user_id,v_process_name||'_1');
         END LOOP;


        -- xml_hold_act = 0 
        -- foreign_supplier = 'N'
        -- insertar retencion de XML
        FOR c_xml IN (SELECT ORG_ID, INVOICE_ID,INVOICE_NUM                           
                        FROM XXWEBC.XXAP_TRACKING_INVOICES_TBL
                       WHERE 1               = 1
                         --AND INVOICE_ID = 33426565
                         AND STEP_CTRL       = 1
                         AND XML_HOLD = 0
                         AND foreign_supplier = 'N'
                         AND SOURCE IN ('RTS') -- Al momento son los que se detectan con retención
                         AND approval_status IN ('NEEDS REAPPROVAL', 'NEVER APPROVED')
                     ORDER BY ORG_ID)
        LOOP

            if v_org_id != c_xml.org_id then
               v_org_id := c_xml.org_id;
               vg_Resp_Id := GET_RESP_ID(v_id_execution,c_xml.INVOICE_ID);
               -- Setea 
               APPS.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize(puser_id        => v_user_id,
                                                                  presp_id        => vg_Resp_Id, --50671,--v_resp_id,    AP
                                                                  presp_appl_id   => 200 --v_resp_appl_id   AP_BEPUSA_SISTEMAS
                                                                  );
            end if;
            vg_msg := 'Insert Hold Falta XML (Debug Before) Org_Id:'|| c_xml.org_id || ' Invoice_Id:' || c_xml.invoice_id || ' Invoice_num:'|| c_xml.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_xml.invoice_id ,p_TEXT => vg_msg, p_value1num => c_xml.org_id);

            APPLY_HOLD_INV(v_id_execution, pin_user_id, c_xml.invoice_id, 1, v_resp);
            vg_msg := 'Insert Hold Falta XML (Debug After) Org_Id:'|| c_xml.org_id || ' Invoice_Id:' || c_xml.invoice_id || ' Invoice_num:'|| c_xml.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_xml.invoice_id ,p_TEXT => vg_msg, p_value1num => c_xml.org_id);

            -- Actualiza los campos del xml_hold
            UPDATE_ROW_TRACKING(c_xml.invoice_id, v_user_id,v_process_name||'_2');

            vg_msg := 'Insert Hold XML (Debug Updated count) Org_Id:'|| c_xml.org_id || ' Invoice_Id:' || c_xml.invoice_id || ' Invoice_num:'|| c_xml.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_xml.invoice_id ,p_TEXT => vg_msg, p_value1num => c_xml.org_id);
        END LOOP;

        -- foreign_hold = 0 
        -- foreign_supplier = 'Y'
        -- insertar retencion de Proveedor Extranjero
        FOR c_provext IN (SELECT ORG_ID, INVOICE_ID,INVOICE_NUM                           
                        FROM XXWEBC.XXAP_TRACKING_INVOICES_TBL
                       WHERE 1               = 1
                         --AND INVOICE_ID = 33426565
                         AND STEP_CTRL       = 1
                         AND FOREIGN_HOLD = 0
                         AND foreign_supplier = 'Y'
                         AND SOURCE IN ('RTS') -- Al momento son los que se detectan con retención
                         AND approval_status IN ('NEEDS REAPPROVAL', 'NEVER APPROVED')
                     ORDER BY ORG_ID)
        LOOP

            if v_org_id != c_provext.org_id then
               v_org_id := c_provext.org_id;
               vg_Resp_Id := GET_RESP_ID(v_id_execution,c_provext.INVOICE_ID);
               -- Setea 
               APPS.XXGEPP_APPS_UTILITIES_PKG.XX_apps_initialize(puser_id        => v_user_id,
                                                                  presp_id        => vg_Resp_Id, --50671,--v_resp_id,    AP
                                                                  presp_appl_id   => 200 --v_resp_appl_id   AP_BEPUSA_SISTEMAS
                                                                  );
            end if;
            vg_msg := 'Insert Hold Proveedor Extranjero (Debug Before) Org_Id:'|| c_provext.org_id || ' Invoice_Id:' || c_provext.invoice_id || ' Invoice_num:'|| c_provext.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_provext.invoice_id ,p_TEXT => vg_msg, p_value1num => c_provext.org_id);

            APPLY_HOLD_INV(v_id_execution, pin_user_id, c_provext.invoice_id, 6, v_resp);
            vg_msg := 'Insert Hold Proveedor Extranjero (Debug After) Org_Id:'|| c_provext.org_id || ' Invoice_Id:' || c_provext.invoice_id || ' Invoice_num:'|| c_provext.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_provext.invoice_id ,p_TEXT => vg_msg, p_value1num => c_provext.org_id);

            -- Actualiza los campos del proveedor extranjero
            UPDATE_ROW_TRACKING(c_provext.invoice_id, v_user_id,v_process_name||'_3');

            vg_msg := 'Insert Hold Proveedor (Debug Updated count) Org_Id:'|| c_provext.org_id || ' Invoice_Id:' || c_provext.invoice_id || ' Invoice_num:'|| c_provext.invoice_num;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_provext.invoice_id ,p_TEXT => vg_msg, p_value1num => c_provext.org_id);

            -- If exist hold Falta XML in teh row is necesary remove it.
            -- 2 Is exits hols and it´s active
            IF GET_COUNT_HOLD(c_provext.invoice_id, 'Falta XML', 'STATUS') =2 THEN
               -- Remove hold
               -- Remove hold Falta XML
                  vg_msg := 'Proveedor Extranjero CHANGED_ERS_TO_XML (Debug Before) -- Remueve Falta XML Org_Id:'|| c_provext.org_id || ' Invoice_Id:' || c_provext.invoice_id || ' Invoice_num:'|| c_provext.invoice_num;
                  XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_provext.invoice_id ,p_TEXT => vg_msg, p_value1num => c_provext.org_id
                        );

                  UNAPPLY_HOLD_INV(v_id_execution, pin_user_id, c_provext.invoice_id, 1, v_result_num);

                  vg_msg := 'Proveedor Extranjero CHANGED_ERS_TO_XML (Debug After) -- Remueve Falta XML Org_Id:'|| c_provext.org_id || ' Invoice_Id:' || c_provext.invoice_id || ' Invoice_num:'|| c_provext.invoice_num;
                  XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => c_provext.invoice_id ,p_TEXT => vg_msg, p_value1num => c_provext.org_id
                        );
                  UPDATE_ROW_TRACKING(c_provext.invoice_id, v_user_id,v_process_name||'_3');

            END IF;
        END LOOP;

        -- We must complete information of ERS
        FOR cur IN (SELECT *
                     FROM XXWEBC.XXAP_TRACKING_INVOICES_TBL
                     WHERE 1=1
                     AND source ='RTS'
                     AND STEP_CTRL       = 1
                     AND INVOICE_ID_ERS_NC is null)
       LOOP
          UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL
            SET (INVOICE_ID_ERS_NC
               ,INVOICE_NUM_ERS_NC
               ,payment_status_flag_ERS_NC
               ,APPROVAL_STATUS_ERS_NC
               ,posting_status_ERS_NC               
               ,last_updated_by
               ,LAST_UPDATE_DATE
               ,HOLD_MANUAL_REVIEW_ERS_NC
               ,HOLD_MAN_REV_STATUS_ERS_NC) =
               (select ers.invoice_id
                        ,ers.invoice_num
                        ,ers.payment_status_flag
                        ,apps.ap_invoices_pkg.get_approval_status (ers.invoice_id,
                                                                           ers.invoice_amount,
                                                                           ers.payment_status_flag,
                                                                           ers.invoice_type_lookup_code) approval_status
                        ,ap_invoices_pkg.get_posting_status(ers.invoice_id) posting_status
                        ,pin_user_id
                        ,SYSDATE
                        ,0
                        ,0
                  FROM ap_invoices_all nc
                        ,ap_invoice_lines_all nc_lines
                        ,po.rcv_transactions rt
                        ,ap_invoice_lines_all ers_lines
                        ,ap_invoices_all ers
                  where 1=1
                  AND nc.invoice_id = cur.invoice_id
                  and nc.source = 'RTS'
                  AND nc.invoice_type_lookup_code = 'DEBIT'
                  and nc_lines.invoice_id = nc.invoice_id
                  and rt.transaction_id = nc_lines.rcv_transaction_id
                  and ers_lines.rcv_transaction_id = rt.transaction_id
                  and ers.invoice_id = ers_lines.invoice_id
                  and ers.source = 'ERS'
                  AND ers.invoice_type_lookup_code = 'STANDARD')
          WHERE 1=1
            AND invoice_id = cur.invoice_id
            AND source = 'RTS';

          COMMIT;
       END LOOP;

       -- Credits Memo whit source invoice in status CANCELLED, we will put the hold Revision Manual
       FOR cur in (select *
                     from XXWEBC.XXAP_TRACKING_INVOICES_TBL
                     where 1=1
                     and source = 'RTS'
                     AND STEP_CTRL       = 1
                     and approval_status_ers_nc  IN ('CANCELLED')
                     and HOLD_MANUAL_REVIEW_ERS_NC = 0
                  )
       LOOP            
            v_msg_hold:='Factura Origen Cancelada';

            vg_msg := 'Insert Hold Revision Manual (Debug Before) Org_Id:'|| cur.org_id || ' Invoice_Id:' || cur.invoice_id;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur.invoice_id ,p_TEXT => vg_msg, p_value1num => cur.org_id);
            APPLY_HOLD_INV(v_id_execution, pin_user_id, cur.invoice_id, 8, v_resp,v_msg_hold);

            vg_msg := 'Insert Hold Revision Manual (Debug After) Org_Id:'|| cur.org_id || ' Invoice_Id:' || cur.invoice_id;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur.invoice_id ,p_TEXT => vg_msg, p_value1num => cur.org_id);

            UPDATE_ROW_TRACKING(cur.invoice_id, v_user_id,v_process_name||'_3');

            UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
            SET STEP_CTRL = 99
                  ,last_updated_by = pin_user_id
                  ,LAST_UPDATE_DATE = sysdate
                  ,STATUS_MESSAGE_ERS_NC =v_msg_hold
            WHERE 1=1
            AND STEP_CTRL = 1
            AND SOURCE IN ('RTS') 
            AND invoice_id = cur.invoice_id;

            COMMIT;
       END LOOP;

       -- Credits Memo whit source invoice in status APPROVED and it was payment, we will put the hold Revision Manual
       FOR cur in (select *
                     from XXWEBC.XXAP_TRACKING_INVOICES_TBL
                     where 1=1
                     and source = 'RTS'
                     AND STEP_CTRL       = 1
                     and approval_status_ers_nc ='APPROVED'
                     and PAYMENT_STATUS_FLAG_ERS_NC != 'N'
                  )
       LOOP            
            v_msg_hold:='Factura Origen ya fue pagada';

            vg_msg := 'Insert Hold Revision Manual (Debug Before) Org_Id:'|| cur.org_id || ' Invoice_Id:' || cur.invoice_id;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur.invoice_id ,p_TEXT => vg_msg, p_value1num => cur.org_id);
            APPLY_HOLD_INV(v_id_execution, pin_user_id, cur.invoice_id, 8, v_resp,v_msg_hold);

            vg_msg := 'Insert Hold Revision Manual (Debug After) Org_Id:'|| cur.org_id || ' Invoice_Id:' || cur.invoice_id;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur.invoice_id ,p_TEXT => vg_msg, p_value1num => cur.org_id);

            UPDATE_ROW_TRACKING(cur.invoice_id, v_user_id,v_process_name||'_3');

            UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
            SET STEP_CTRL = 100
                  ,last_updated_by = pin_user_id
                  ,LAST_UPDATE_DATE = sysdate
                  ,STATUS_MESSAGE_ERS_NC =v_msg_hold
            WHERE 1=1
            AND STEP_CTRL = 1
            AND SOURCE IN ('RTS') 
            AND invoice_id = cur.invoice_id;

            COMMIT;
       END LOOP;

      -- Credits Memo with ERS whit others Credits Memo
      UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL TC
         SET NUM_NC_ERS_NC = (select count(distinct nc.invoice_id)
                              FROM ap_invoices_all nc
                                    ,ap_invoice_lines_all nc_lines
                                    ,po.rcv_transactions rt
                                    ,ap_invoice_lines_all ers_lines
                                    ,ap_invoices_all ers
                              where 1=1
                              AND ers.invoice_id = TC.INVOICE_ID_ERS_NC
                              and nc.source = 'RTS'
                              AND nc.invoice_type_lookup_code = 'DEBIT'
                              and nc_lines.invoice_id = nc.invoice_id
                              and rt.transaction_id = nc_lines.rcv_transaction_id
                              and ers_lines.rcv_transaction_id = rt.transaction_id
                              and ers.invoice_id = ers_lines.invoice_id
                              and ers.source = 'ERS'
                              AND ers.invoice_type_lookup_code = 'STANDARD')
      where 1=1
         and source = 'RTS'
         AND STEP_CTRL       = 1
         AND NUM_NC_ERS_NC IS NULL;

      COMMIT;

      FOR cur in (select *
                     from XXWEBC.XXAP_TRACKING_INVOICES_TBL
                     where 1=1
                     and source = 'RTS'
                     AND STEP_CTRL       = 1
                     AND NUM_NC_ERS_NC > 0
                  )
       LOOP            
            v_msg_hold:='Factura Origen con mas de una Nota de Credito relacionada';

            vg_msg := 'Insert Hold Revision Manual (Debug Before) Org_Id:'|| cur.org_id || ' Invoice_Id:' || cur.invoice_id;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur.invoice_id ,p_TEXT => vg_msg, p_value1num => cur.org_id);
            APPLY_HOLD_INV(v_id_execution, pin_user_id, cur.invoice_id, 8, v_resp,v_msg_hold);

            vg_msg := 'Insert Hold Revision Manual (Debug After) Org_Id:'|| cur.org_id || ' Invoice_Id:' || cur.invoice_id;
            XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur.invoice_id ,p_TEXT => vg_msg, p_value1num => cur.org_id);

            UPDATE_ROW_TRACKING(cur.invoice_id, v_user_id,v_process_name||'_3');

            UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
            SET STEP_CTRL = 100
                  ,last_updated_by = pin_user_id
                  ,LAST_UPDATE_DATE = sysdate
                  ,STATUS_MESSAGE_ERS_NC =v_msg_hold
            WHERE 1=1
            AND STEP_CTRL = 1
            AND SOURCE IN ('RTS') 
            AND invoice_id = cur.invoice_id;

            COMMIT;
       END LOOP;

      -- Credits Memo whit source invoice in status APPROVED and it is not payment yet, we will put the hold Retención por devolución to ERS
       FOR cur in (select *
                     from XXWEBC.XXAP_TRACKING_INVOICES_TBL
                     where 1=1
                     and source = 'RTS'
                     AND STEP_CTRL       = 1
                     and approval_status_ers_nc ='APPROVED'
                     and PAYMENT_STATUS_FLAG_ERS_NC = 'N'
                  )
       LOOP   
         -- If not has a Hold 
            DECLARE
               v_Hold_Flag VARCHAR2(10);
            BEGIN
               SELECT HOLD_FLAG
               INTO v_Hold_Flag
               FROM apps.AP_PAYMENT_SCHEDULES_ALL
               WHERE 1=1
               AND  invoice_id =CUR.INVOICE_ID_ERS_NC;

               IF v_Hold_Flag ='N' THEN

                  UPDATE apps.AP_PAYMENT_SCHEDULES_ALL
                     SET HOLD_FLAG='Y'
                        ,IBY_HOLD_REASON ='RETENCION POR DEVOLUCION'
                        ,ATTRIBUTE3 ='RETENCION POR DEVOLUCION'
                  where 1=1
                  and invoice_id =CUR.INVOICE_ID_ERS_NC;
                  COMMIT;
               END IF;
            EXCEPTION 
               WHEN OTHERS THEN
                  vg_msg := 'Error in Hold RETENCION POR DEVOLUCION (Debug) Org_Id:'|| cur.org_id || ' Invoice_Id:' || cur.invoice_id;
                  XXLOG(p_Level => 4 ,p_EXECUTION_ID => v_id_execution ,p_invoice_id => cur.invoice_id ,p_TEXT => vg_msg, p_value1num => cur.org_id);
            END;
       END LOOP;


        -- Para cambiar de estatus de 1 a 5 el valor del campo step_ctrl será necesario:
        -- XML_HOLD > 0
        -- FA_FOLD > 0 y APPLIED_HOLD_FA sea SI
        UPDATE XXWEBC.XXAP_TRACKING_INVOICES_TBL ai
        SET STEP_CTRL = 5
            ,last_updated_by = pin_user_id
            ,LAST_UPDATE_DATE = sysdate
        WHERE 1=1
        AND STEP_CTRL = 1
        AND SOURCE IN ('RTS') 
        AND (XML_HOLD > 0 OR FOREIGN_HOLD > 0)
        AND approval_status IN ('NEEDS REAPPROVAL', 'NEVER APPROVED');

        COMMIT;
    END APPLY_HOLD_NC;

END XXAP_TRACKING_AP_PKG;