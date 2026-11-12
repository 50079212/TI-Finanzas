CREATE OR REPLACE PACKAGE BODY XXBOT.XXAR_BOTS_ACT_EDO_CTA
AS
    PROCEDURE  XXAR_BOTS_ESTADO_D_CTA (errbuf out varchar2,retcode out number,P_ORG_ID IN number)
    IS
        V_COUNT     NUMBER         := 0;
        v_msg       VARCHAR2(4000) := NULL;
		    vProgreso   VARCHAR2(5)    := NULL;
        v_limit PLS_INTEGER := 1000;
        v_mod  number:=10;
        v_iter number;
        v_request_id NUMBER:= NVL(fnd_global.conc_request_id,0);


        cursor cur_principal is
            select   /*+ ordered FULL(m)
            use_nl(curr m)
            use_nl(m ps)
            use_nl(ps l)
            use_nl(ps dh)
            use_nl(ps rct)
            use_nl(ps ctt)
            use_nl(ps units)

            index(logr CUST_AR_FACTELEC_LOG_INDEX1)
            use_nl(ps d)
            index(d HZ_CUST_SITE_USES_U1)
            use_nl(ps hzc)
            index(hzc HZ_CUST_ACCOUNTS_U1)
            use_nl(ps logr)*/  --distinct
                    ps.CUSTOMER_TRX_ID CUSTOMER_TRX_ID,
                   rct.purchase_order,
                   ps.trx_number Number_B,
                   REPLACE(SUBSTR (DECODE (ctt.cust_trx_type_id, NULL, l.meaning, ctt.name),-4,4), '-', ' ') TYPE,
                   ps.trx_date Trx_Date,
                   ps.gl_date Gl_Date,
                   ps.due_date Due_Date,
                   ps.invoice_currency_code Currency_B,
                   DECODE(ps.invoice_currency_code, curr.currency_code, ps.amount_due_original,
                                                                           DECODE(curr.minimum_accountable_unit, NULL, ROUND (ps.amount_due_original * ps.exchange_rate, curr.precision),
                                                                                                                       ROUND (ps.amount_due_original * ps.exchange_rate / curr.minimum_accountable_unit) * curr.minimum_accountable_unit)) Original_Amount,
                   ps.acctd_amount_due_remaining Balance_Due
                   ,logr.uuid,
                   logr.estatus,
                   logr.DESCRIPCION_ESTATUS,
                   logr.ACCESO_DOCTO,
                   logr.url,
                   DECODE(null,null,'1',ctt.NAME) orden,
                   rct.attribute7 remision,
                   rct.attribute8 no_recibo,
                   CASE
                        WHEN INSTR(rct.attribute9,'JAN') > 0 THEN replace(rct.attribute9,'JAN','ENE')
                        WHEN INSTR(rct.attribute9,'APR') > 0 THEN replace(rct.attribute9,'APR','ABR')
                        WHEN INSTR(rct.attribute9,'AUG') > 0 THEN replace(rct.attribute9,'AUG','AGO')
                        WHEN INSTR(rct.attribute9,'DEC') > 0 THEN replace(rct.attribute9,'DEC','DIC')
                        ELSE rct.attribute9
                   END fecha_recibo,
                   rct.attribute12 tipo
                   ,a.orig_system_reference referencia_direccion
                   ,m.customer_id,
                   m.Agent_name ejecutivo,
                   m.COLLECTOR_ID,
                   m.Collector,
                   m.location,
                   m.name,
                   m.number_a,
                   rct.SHIP_TO_SITE_USE_ID
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, -9999, 0, ps.due_date, NULL, sysdate) b0
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1, 30, ps.due_date, NULL, sysdate) b1
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 31, 60, ps.due_date, NULL, sysdate) b2
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 61, 90, ps.due_date, NULL, sysdate) b3
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 91, 120, ps.due_date, NULL, sysdate) b4
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 121, 180, ps.due_date, NULL, sysdate) b5
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 181, 210, ps.due_date, NULL, sysdate) b6
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 211, 240, ps.due_date, NULL, sysdate) b7
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 241, 270, ps.due_date, NULL, sysdate) b8
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 271, 300, ps.due_date, NULL, sysdate) b9
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 301, 330, ps.due_date, NULL, sysdate) b10
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 331, 360, ps.due_date, NULL, sysdate) b11
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 361, 540, ps.due_date, NULL, sysdate) b12
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 541, 720, ps.due_date, NULL, sysdate) b13
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 721, 900, ps.due_date, NULL, sysdate) b14
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 901, 1080, ps.due_date, NULL, sysdate) b15
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1081, 1260, ps.due_date, NULL, sysdate) b16
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1261, 1440, ps.due_date, NULL, sysdate) b17
                  ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1441, 9999, ps.due_date, NULL, sysdate) b18
                  ,2 FLAG
                  ,ps.last_update_date
                  ,RCT.ORG_ID
                  ,units.name COMPANY_NAME
                  ,null SEND_MAIL
                  ,null portal
                  ,null cedis
                  ,null region
                  ,null nud
                  ,LOGR.SISTEMA_DESTINO
                  ,NULL estatus_portal
                  ,NULL client
                  ,NULL ESTATUS_USUARIO
                  ,NULL TRX_PURCHASE_ORDER
                  ,NULL DOCUMENT_NUMBER
                  ,NULL RECEIPT_NUMBER
                  ,NULL EXECUTION_DATE
                  ,NULL PAYMENT_DATE
                  ,NULL VOUCHER_NUMBER
                  ,ps.tax_original
                  ,NULL ID_CARGA
                  ,rct.ATTRIBUTE6 NO_EDITADO
                  ,NULL NUMBER_VAL
                  ,XXBOT.XXAR_BOTS_ACT_EDO_CTA.GET_TAX_BASE(0,ps.CUSTOMER_TRX_ID) IVA_0
                  ,XXBOT.XXAR_BOTS_ACT_EDO_CTA.GET_TAX_BASE(8,ps.CUSTOMER_TRX_ID) IVA_8
                  ,XXBOT.XXAR_BOTS_ACT_EDO_CTA.GET_TAX_BASE(16,ps.CUSTOMER_TRX_ID) IVA_16
                  ,XXBOT.XXAR_BOTS_ACT_EDO_CTA.GET_SUC_GLN ('SUC',hzc.account_number,RCT.ORG_ID,a.orig_system_reference) SUCURSAL
                  ,XXBOT.XXAR_BOTS_ACT_EDO_CTA.GET_SUC_GLN ('GLN',hzc.account_number,RCT.ORG_ID,a.orig_system_reference) gln
                  ,sysdate creation_date_prc
                  ,sysdate last_update_date_prc
                  ,(select B.STATUS_DESC
                      from xx_apex.XXAR_GRPCBZ_DCOMM_TBL@OCIPROD_TO_ORAPROD19 a,
                           xx_apex.XXAR_GRPCBZ_STATUS_TBL@OCIPROD_TO_ORAPROD19 b
                     where 1 = 1
                       and b.source_type       = 'D'
                       and a.status            = b.status
                       AND ps.CUSTOMER_TRX_ID  = A.CUSTOMER_TRX_ID
                       and rownum             <= 1) AS MESSAGE
                  ,(select SCHEDULED_DATE
                      from xx_apex.XXAR_GRPCBZ_DCOMM_TBL@OCIPROD_TO_ORAPROD19 a,
                           xx_apex.XXAR_GRPCBZ_STATUS_TBL@OCIPROD_TO_ORAPROD19 b
                     where 1 = 1
                       and b.source_type       = 'D'
                       and a.status            = b.status
                       AND ps.CUSTOMER_TRX_ID  = A.CUSTOMER_TRX_ID
                       and rownum             <= 1) AS SCHEDULED_DATE
                  ,d.location as direccion_envio
                  ,(select distinct (a.CONTACT_NUMBER)
                      from apps.AR_CONTACTS_V a
                          ,apps.HZ_CONTACT_FIND_V b
                          ,apps.ar_customers d
                          ,apps.hz_parties f
                          ,apps.hz_cust_accounts g
                          ,xxwebc.xxar_bots_tbl_cust_mails_cs h
                     where 1 = 1
                       and d.customer_id       = b.customer_id
                       and a.customer_id       = d.customer_id
                       and a.CONTACT_NUMBER    = b.CONTACT_NUMBER
                       and a.customer_id       = b.customer_id
                       and d.customer_id       = h.customer_id
                       and a.customer_id       = h.customer_id
                       and b.customer_id       = h.customer_id
                       AND g.cust_account_id   = d.customer_id
                       AND g.party_id          = F.party_id
                       and b.CONTACT_NUMBER like 'EC-%'
                       and a.CONTACT_NUMBER like 'EC-%'
                       AND B.STATUS            = 'A'
                       AND a.STATUS            = 'A'
                       AND d.CUSTOMER_number   = hzc.account_number--m.number_a
					   AND ROWNUM             <= 1) g_d_cobranza
                  ,NULL as g_seguridad
from apps.fnd_currencies curr
     ,xxtt_q_main_customer m
     ,XXBOTS_AR_PAYMENT_SCHEDULES ps
    ,apps.ar_lookups l
   ,ar.ar_dispute_history dh
   ,apps.ra_customer_trx_all rct
   ,apps.ra_cust_trx_types_all ctt
   ,apps.hr_all_organization_units units
   ,APPS.hz_cust_accounts hzc
   ,ar.hz_cust_acct_sites_all a
   ,ar.hz_cust_site_uses_all d
   ,ar.cust_ar_factelec_log logr
   --apps.cm_mstr c
where 1=1
and curr.currency_code = 'MXN'
--and ps.org_id = 84
AND ps.customer_id                = m.customer_id
AND ps.ORG_ID                = m.ORG_ID
AND ps.status || ''               = 'OP'
AND abs(ps.amount_due_remaining) >= 1.00
AND ps.gl_date                   <= sysdate
AND ps.gl_date_closed             > sysdate
and ps.class                      =  l.lookup_code(+)
AND l.lookup_type(+)              = 'INV/CM'
AND dh.payment_schedule_id(+) = ps.payment_schedule_id
 AND sysdate                      >= NVL(dh.start_date(+),sysdate)
AND sysdate                       < NVL(dh.end_date(+),sysdate+1)
and rct.customer_trx_id = ps.customer_trx_id
and rct.org_id = ps.org_id
AND ctt.cust_trx_type_id = ps.cust_trx_type_id
and units.organization_id         = ps.ORG_ID
--hzc.cust_account_id AS customer_id
--hzc.orig_system_reference AS cm_addr
and hzc.cust_account_id = nvl(rct.SHIP_TO_CUSTOMER_ID,rct.BILL_TO_CUSTOMER_ID)        --c.customer_id
--and rct.org_id                    = c.org_id
AND a.cust_account_id = hzc.cust_account_id
AND a.org_id = d.org_id
AND a.cust_acct_site_id = d.cust_acct_site_id
and d.site_use_id = nvl(rct.SHIP_TO_SITE_USE_ID, rct.BILL_TO_SITE_USE_ID)
AND logr.NUMERO_DOCTO(+)          = ps.trx_number
AND logr.ORG_ID (+)               = ps.ORG_ID
AND LOGR.customer_trx_id (+)  = ps.customer_trx_id;

            -- WITH q_setup as
            --     (SELECT sob.name   Company_Name,
            --             sob.chart_of_accounts_id   coa_id,
            --             sob.currency_code   Functional_Currency,
            --             cur.precision      Functional_Currency_Precision
            --        FROM apps.gl_sets_of_books sob,
            --             --apps.AR_SYSTEM_PARAMETERS param,
            --             apps.fnd_currencies cur
            --       WHERE 1=1
            --         --AND sob.set_of_books_id = param.set_of_books_id
            --         AND sob.currency_code   = cur.currency_code

            --     )
            --      ,q_main as
            --     (SELECT status.meaning status,
            --             SUBSTRB (party.party_name, 1, 50) Name,
            --             cust_acct.account_number Number_A,
            --             cust_acct.cust_account_id Customer_Id,
            --             NVL (cp_site.collector_id, cp_cust.collector_id) Collector_Id,
            --             col.name Collector,
            --             cust_acct.ATTRIBUTE15 Agent_name,
            --             site_uses.site_use_id cp_site_use_id,
            --             site_uses.location location
            --            ,cust_acct.ATTRIBUTE15
            --             --,cte.type_process  type_process
            --        FROM apps.ar_lookups status,
            --             apps.ar_collectors col,
            --             apps.hz_customer_profiles cp_cust,
            --             apps.hz_customer_profiles cp_site,
            --             apps.hz_cust_accounts cust_acct,
            --             apps.hz_parties party,
            --             apps.hz_cust_site_uses_all site_uses,
            --             apps.hz_cust_acct_sites_all acct_site
            --            ,--apps.xxar_bots_tbl_customers_mails
            --            (select distinct cte.customer_id
            --             from apps.xxar_bots_tbl_customers_mails cte
            --             where 1 = 1
            --             union
            --             select distinct cte.customer_id
            --             from xxwebc.xxar_bots_tbl_cust_mails_cs cte
            --             where 1 = 1) cte
            --       WHERE 1 = 1
            --         --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
            --         and acct_site.cust_account_id = cust_acct.cust_account_id
            --         AND cust_acct.cust_account_id  = cte.Customer_Id
            --         /*and cust_acct.cust_account_id in (select distinct cte.customer_id
            --                                             from apps.xxar_bots_tbl_customers_mails cte
            --                                            where 1=1
            --                                           union
            --                                           select distinct cte.customer_id
            --                                             from xxwebc.xxar_bots_tbl_cust_mails_cs cte
            --                                            where 1=1)   */
            --          AND cust_acct.party_id          = party.party_id
            --          AND site_uses.cust_acct_site_id = acct_site.cust_acct_site_id
            --          AND site_uses.site_use_code     = 'BILL_TO'
            --          AND cp_site.site_use_id(+)   = site_uses.site_use_id
            --          AND cp_cust.cust_account_id  = cust_acct.cust_account_id
            --          AND cp_cust.site_use_id     IS NULL
            --          AND col.collector_id         = NVL (cp_site.collector_id, cp_cust.collector_id)
            --          AND DECODE (cp_site.collector_id, NULL, cp_cust.account_status,
            --                                                  cp_site.account_status) = status.lookup_code
            --          AND status.lookup_type       = 'ACCOUNT_STATUS'
            --          AND EXISTS (SELECT 'x'
            --                        FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
            --                       WHERE (ps.status              = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
            --                         AND ps.customer_id          = cust_acct.cust_account_id
            --                         AND ps.customer_site_use_id = site_uses.site_use_id)

            --      UNION
            --      SELECT status.meaning status,
            --             SUBSTRB (party.party_name, 1, 50) Name,
            --             cust_acct.account_number Number_A,
            --             cust_acct.cust_account_id Customer_Id,
            --             NVL (cp_site.collector_id, cp_cust.collector_id) Collector_Id,
            --             col.name Collector,
            --             cust_acct.ATTRIBUTE15 Agent_name,
            --             site_uses.site_use_id cp_site_use_id,
            --             site_uses.location location
            --             ,cust_acct.ATTRIBUTE15
            --           -- ,cte.type_process type_process
            --        FROM apps.ar_lookups status,
            --             apps.ar_collectors col,
            --             apps.hz_customer_profiles cp_cust,
            --             apps.hz_customer_profiles cp_site,
            --             apps.hz_cust_accounts cust_acct,
            --             apps.hz_parties party,
            --             apps.hz_cust_site_uses_all site_uses,
            --             apps.hz_cust_acct_sites_all acct_site
            --             ,--apps.xxar_bots_tbl_customers_mails
            --             (select distinct cte.customer_id
            --             from apps.xxar_bots_tbl_customers_mails cte
            --             where 1 = 1
            --             union
            --             select distinct cte.customer_id
            --             from xxwebc.xxar_bots_tbl_cust_mails_cs cte
            --             where 1 = 1)    cte
            --       WHERE 1 = 1
            --       --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
            --         and acct_site.cust_account_id = cust_acct.cust_account_id
            --         AND cust_acct.cust_account_id  = cte.Customer_Id
            --         /*and cust_acct.cust_account_id in (select distinct cte.customer_id
            --                                             from apps.xxar_bots_tbl_customers_mails cte
            --                                            where 1 = 1
            --                                           union
            --                                           select distinct cte.customer_id
            --                                             from xxwebc.xxar_bots_tbl_cust_mails_cs cte
            --                                            where 1 = 1)*/
            --         AND cust_acct.party_id           = party.party_id
            --         AND site_uses.cust_acct_site_id  = acct_site.cust_acct_site_id
            --         AND site_uses.site_use_code      = 'BILL_TO'
            --         AND cp_site.site_use_id(+)       = site_uses.site_use_id
            --         AND cp_cust.cust_account_id      = cust_acct.cust_account_id
            --         AND cp_cust.site_use_id         IS NULL
            --         AND col.collector_id             = NVL (cp_site.collector_id, cp_cust.collector_id)
            --         AND cp_site.collector_id        IS NULL
            --         AND cp_cust.account_status       = status.lookup_code(+)
            --         AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
            --         AND EXISTS (SELECT 'x'
            --                       FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
            --                      WHERE (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
            --                        AND ps.customer_id = cust_acct.cust_account_id
            --                        AND ps.customer_site_use_id = site_uses.site_use_id)
            --      UNION
            --      SELECT status.meaning status,
            --             SUBSTRB (party.party_name, 1, 50) Name,
            --             cust_acct.account_number Number_A,
            --             cust_acct.cust_account_id Customer_Id,
            --             NVL (cp_site.collector_id, cp_cust.collector_id) Collector_Id,
            --             col.name Collector,
            --             cust_acct.ATTRIBUTE15 Agent_name,
            --             site_uses.site_use_id cp_site_use_id,
            --             site_uses.location location
            --            ,cust_acct.ATTRIBUTE15
            --             -- ,cte.type_process
            --        FROM apps.ar_lookups status,
            --             apps.ar_collectors col,
            --             apps.hz_customer_profiles cp_cust,
            --             apps.hz_customer_profiles cp_site,
            --             apps.hz_cust_accounts cust_acct,
            --             apps.hz_parties party,
            --             apps.hz_cust_site_uses_all site_uses,
            --             apps.hz_cust_acct_sites_all acct_site
            --            ,--apps.xxar_bots_tbl_customers_mails
            --            (select distinct cte.customer_id
            --             from apps.xxar_bots_tbl_customers_mails cte
            --             where 1 = 1
            --             union
            --             select distinct cte.customer_id
            --             from xxwebc.xxar_bots_tbl_cust_mails_cs cte
            --             where 1 = 1) cte
            --       WHERE 1 = 1
            --       --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
            --         and acct_site.cust_account_id = cust_acct.cust_account_id
            --         AND cust_acct.cust_account_id  = cte.Customer_Id
            --         /*and cust_acct.cust_account_id in (select distinct cte.customer_id
            --                                             from apps.xxar_bots_tbl_customers_mails cte
            --                                            where 1 = 1
            --                                           union
            --                                           select distinct cte.customer_id
            --                                             from xxwebc.xxar_bots_tbl_cust_mails_cs cte
            --                                            where 1 = 1)*/
            --         AND cust_acct.party_id           = party.party_id
            --         AND site_uses.cust_acct_site_id  = acct_site.cust_acct_site_id
            --         AND site_uses.site_use_code      = 'BILL_TO'
            --         AND cp_site.site_use_id(+)       = site_uses.site_use_id
            --         AND cp_cust.cust_account_id      = cust_acct.cust_account_id
            --         AND cp_cust.site_use_id         IS NULL
            --         AND col.collector_id             = NVL (cp_site.collector_id, cp_cust.collector_id)
            --         AND cp_site.collector_id        IS NOT NULL
            --         AND cp_site.account_status       = status.lookup_code(+)
            --         AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
            --         AND EXISTS (SELECT 'x'
            --                       FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
            --                      WHERE (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
            --                        AND ps.customer_id          = cust_acct.cust_account_id
            --                        AND ps.customer_site_use_id = site_uses.site_use_id)
            --      UNION
            --      SELECT status.meaning,
            --             SUBSTRB (party.party_name, 1, 50),
            --             cust_acct.account_number,
            --             cust_acct.cust_account_id,
            --             col.collector_id,
            --             col.name,
            --             cust_acct.ATTRIBUTE15 Agent_name,
            --             DECODE ('Customer', NULL, 0, -88888),
            --             TO_CHAR (NULL)
            --             ,cust_acct.ATTRIBUTE15
            --           -- ,cte.type_process
            --        FROM apps.ar_lookups status,
            --             apps.ar_collectors col,
            --             apps.hz_customer_profiles cp_cust,
            --             apps.hz_cust_accounts cust_acct,
            --             apps.hz_parties party
            --            ,--apps.xxar_bots_tbl_customers_mails
            --             (select distinct cte.customer_id
            --             from apps.xxar_bots_tbl_customers_mails cte
            --             where 1 = 1
            --             union
            --             select distinct cte.customer_id
            --             from xxwebc.xxar_bots_tbl_cust_mails_cs cte
            --             where 1 = 1)cte
            --       WHERE 1 = 1
            --       --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
            --         and cp_cust.cust_account_id = cust_acct.cust_account_id
            --         AND cust_acct.cust_account_id  = cte.Customer_Id
            --         /*and cust_acct.cust_account_id in (select distinct cte.customer_id
            --                                             from apps.xxar_bots_tbl_customers_mails cte
            --                                            where 1 = 1
            --                                           union
            --                                           select distinct cte.customer_id
            --                                             from xxwebc.xxar_bots_tbl_cust_mails_cs cte
            --                                            where 1 = 1)*/
            --         AND cust_acct.party_id     = party.party_id
            --         AND cp_cust.site_use_id   IS NULL
            --         AND cp_cust.collector_id   = col.collector_id
            --         AND cp_cust.account_status = status.lookup_code(+)
            --         AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
            --         AND EXISTS (SELECT 'x'
            --                       FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
            --                      WHERE (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
            --                        AND ps.customer_id = cust_acct.cust_account_id
            --                        AND ps.customer_site_use_id IS NULL)
            --     )
            -- SELECT --distinct
            --         (ps.CUSTOMER_TRX_ID) CUSTOMER_TRX_ID,
            --        rct.purchase_order,
            --        ps.trx_number Number_B,
            --        REPLACE(SUBSTR (DECODE (ctt.cust_trx_type_id, NULL, l.meaning, ctt.name),-4,4), '-', ' ') TYPE,
            --        ps.trx_date Trx_Date,
            --        ps.gl_date Gl_Date,
            --        ps.due_date Due_Date,
            --        ps.invoice_currency_code Currency_B,
            --        DECODE(ps.invoice_currency_code, s.Functional_Currency, ps.amount_due_original,
            --                                                                DECODE(curr.minimum_accountable_unit, NULL, ROUND (ps.amount_due_original * ps.exchange_rate, curr.precision),
            --                                                                                                            ROUND (ps.amount_due_original * ps.exchange_rate / curr.minimum_accountable_unit) * curr.minimum_accountable_unit)) Original_Amount,
            --        ps.acctd_amount_due_remaining Balance_Due,
            --        logr.uuid,
            --        logr.estatus,
            --        logr.DESCRIPCION_ESTATUS,
            --        logr.ACCESO_DOCTO,
            --        logr.url,
            --        DECODE(null,null,'1',ctt.NAME) orden,
            --        rct.attribute7 remision,
            --        rct.attribute8 no_recibo,
            --        CASE
            --             WHEN INSTR(rct.attribute9,'JAN') > 0 THEN replace(rct.attribute9,'JAN','ENE')
            --             WHEN INSTR(rct.attribute9,'APR') > 0 THEN replace(rct.attribute9,'APR','ABR')
            --             WHEN INSTR(rct.attribute9,'AUG') > 0 THEN replace(rct.attribute9,'AUG','AGO')
            --             WHEN INSTR(rct.attribute9,'DEC') > 0 THEN replace(rct.attribute9,'DEC','DIC')
            --             ELSE rct.attribute9
            --        END fecha_recibo,
            --        rct.attribute12 tipo,
            --        c.cm_addr referencia_direccion,
            --        m.customer_id,
            --        m.Agent_name ejecutivo,
            --        m.COLLECTOR_ID,
            --        m.Collector,
            --        m.location,
            --        m.name,
            --        m.number_a,
            --        m.CP_SITE_USE_ID
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, -9999, 0, ps.due_date, NULL, sysdate) b0
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1, 30, ps.due_date, NULL, sysdate) b1
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 31, 60, ps.due_date, NULL, sysdate) b2
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 61, 90, ps.due_date, NULL, sysdate) b3
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 91, 120, ps.due_date, NULL, sysdate) b4
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 121, 180, ps.due_date, NULL, sysdate) b5
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 181, 210, ps.due_date, NULL, sysdate) b6
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 211, 240, ps.due_date, NULL, sysdate) b7
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 241, 270, ps.due_date, NULL, sysdate) b8
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 271, 300, ps.due_date, NULL, sysdate) b9
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 301, 330, ps.due_date, NULL, sysdate) b10
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 331, 360, ps.due_date, NULL, sysdate) b11
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 361, 540, ps.due_date, NULL, sysdate) b12
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 541, 720, ps.due_date, NULL, sysdate) b13
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 721, 900, ps.due_date, NULL, sysdate) b14
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 901, 1080, ps.due_date, NULL, sysdate) b15
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1081, 1260, ps.due_date, NULL, sysdate) b16
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1261, 1440, ps.due_date, NULL, sysdate) b17
            --       ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1441, 9999, ps.due_date, NULL, sysdate) b18
            --       ,2 FLAG
            --       ,ps.last_update_date
            --       ,RCT.ORG_ID
            --       ,units.name COMPANY_NAME
            --       ,null SEND_MAIL
            --       ,null portal
            --       ,null cedis
            --       ,null region
            --       ,null nud
            --       ,LOGR.SISTEMA_DESTINO
            --       ,NULL estatus_portal
            --       ,NULL client
            --       ,NULL ESTATUS_USUARIO
            --       ,NULL TRX_PURCHASE_ORDER
            --       ,NULL DOCUMENT_NUMBER
            --       ,NULL RECEIPT_NUMBER
            --       ,NULL EXECUTION_DATE
            --       ,NULL PAYMENT_DATE
            --       ,NULL VOUCHER_NUMBER
            --       ,ps.tax_original
            --       ,NULL ID_CARGA
            --       ,rct.ATTRIBUTE6 NO_EDITADO
            --       ,NULL NUMBER_VAL
            --       ,GET_TAX_BASE(0,ps.CUSTOMER_TRX_ID) IVA_0
            --       ,GET_TAX_BASE(8,ps.CUSTOMER_TRX_ID) IVA_8
            --       ,GET_TAX_BASE(16,ps.CUSTOMER_TRX_ID) IVA_16
            --       ,GET_SUC_GLN ('SUC',m.number_a,RCT.ORG_ID,c.cm_addr) SUCURSAL
            --       ,GET_SUC_GLN ('GLN',m.number_a,RCT.ORG_ID,c.cm_addr) gln
            --       ,sysdate creation_date_prc
            --       ,sysdate last_update_date_prc
            --       ,(select B.STATUS_DESC
            --           from xx_apex.XXAR_GRPCBZ_DCOMM_TBL@OCIPROD_TO_ORAPROD19 a,
            --                xx_apex.XXAR_GRPCBZ_STATUS_TBL@OCIPROD_TO_ORAPROD19 b
            --          where 1 = 1
            --            and b.source_type       = 'D'
            --            and a.status            = b.status
            --            AND ps.CUSTOMER_TRX_ID  = A.CUSTOMER_TRX_ID
            --            and rownum             <= 1) AS MESSAGE
            --       ,(select SCHEDULED_DATE
            --           from xx_apex.XXAR_GRPCBZ_DCOMM_TBL@OCIPROD_TO_ORAPROD19 a,
            --                xx_apex.XXAR_GRPCBZ_STATUS_TBL@OCIPROD_TO_ORAPROD19 b
            --          where 1 = 1
            --            and b.source_type       = 'D'
            --            and a.status            = b.status
            --            AND ps.CUSTOMER_TRX_ID  = A.CUSTOMER_TRX_ID
            --            and rownum             <= 1) AS SCHEDULED_DATE
            --       ,c.nombre_site as direccion_envio
            --       ,(select distinct (a.CONTACT_NUMBER)
            --           from apps.AR_CONTACTS_V a
            --               ,apps.HZ_CONTACT_FIND_V b
            --               ,apps.ar_customers d
            --               ,apps.hz_parties f
            --               ,apps.hz_cust_accounts g
            --               ,xxwebc.xxar_bots_tbl_cust_mails_cs h
            --          where 1 = 1
            --            and d.customer_id       = b.customer_id
            --            and a.customer_id       = d.customer_id
            --            and a.CONTACT_NUMBER    = b.CONTACT_NUMBER
            --            and a.customer_id       = b.customer_id
            --            and d.customer_id       = h.customer_id
            --            and a.customer_id       = h.customer_id
            --            and b.customer_id       = h.customer_id
            --            AND g.cust_account_id   = d.customer_id
            --            AND g.party_id          = F.party_id
            --            and b.CONTACT_NUMBER like 'EC-%'
            --            and a.CONTACT_NUMBER like 'EC-%'
            --            AND B.STATUS            = 'A'
            --            AND a.STATUS            = 'A'
            --            AND d.CUSTOMER_number   = m.number_a
			-- 		   AND ROWNUM             <= 1) g_d_cobranza
            --       ,NULL as g_seguridad
            --   FROM apps.ar_lookups l,
            --        apps.ra_cust_trx_types ctt,
            --        ar.cust_ar_factelec_log logr,
            --        apps.ra_customer_trx_all rct,
            --        apps.AR_PAYMENT_SCHEDULES_ALL ps,
            --        ar.ar_dispute_history dh,
            --        apps.fnd_currencies curr
            --       ,q_setup s
            --       ,q_main m
            --       ,apps.cm_mstr c
            --       ,apps.hr_all_organization_units units
            --  WHERE 1 = 1
            --    and units.attribute15            is not null
            --    and units.organization_id         = ps.ORG_ID
            --    and ps.class                      =  l.lookup_code(+)
            --    AND l.lookup_type(+)              = 'INV/CM'
            --    AND ps.payment_schedule_id        = dh.payment_schedule_id(+)
            --    AND ps.gl_date                   <= sysdate
            --    AND ps.gl_date_closed             > sysdate
            --    AND sysdate                      >= NVL(dh.start_date(+),sysdate)
            --    AND sysdate                       < NVL(dh.end_date(+),sysdate+1)
            --    AND ps.cust_trx_type_id           = ctt.cust_trx_type_id(+)
            --    AND logr.NUMERO_DOCTO(+)          = ps.trx_number
            --    AND logr.ORG_ID (+)               = ps.ORG_ID
            --    AND rct.customer_trx_id           = ps.customer_trx_id
            --    AND ps.status || ''               = 'OP'
            --    AND abs(ps.amount_due_remaining) >= 1.00
            --    AND ps.customer_id                = m.customer_id
            --    AND curr.currency_code            = s.Functional_Currency
            --    and rct.org_id                    = c.org_id(+)
            --    and rct.SHIP_TO_CUSTOMER_ID       = c.customer_id (+)
            --    and rct.SHIP_TO_SITE_USE_ID       = c.site_use_id (+);

        TYPE cur_principal_tb IS TABLE OF cur_principal%ROWTYPE INDEX BY PLS_INTEGER;
        cur_principal_arr cur_principal_tb;
    begin
        begin
            apps.mo_global.set_policy_context('S', P_ORG_ID);
            DBMS_OUTPUT.PUT_LINE('OK_cias '||P_ORG_ID);
        exception
            when others then
                apps.mo_global.set_policy_context('S', P_ORG_ID);
                DBMS_OUTPUT.PUT_LINE(' no OK_cias '||P_ORG_ID);
        end ;

		vProgreso := '0.1';

        begin
            EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = "LATIN AMERICAN SPANISH";-- "AMERICAN" ';
            DBMS_OUTPUT.PUT_LINE('OK');
        EXCEPTION
		    WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('FALLA '||SQLERRM);
        end;

		vProgreso := '0.2';


        /*delete xxwebc.control_edo_cta where org_id = p_org_id;
        commit;*/ -- It is commented because we are using request_id for more trazability

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>0, p_punto_control=>1, p_text=>'INICIA', p_ins_conteo=>'N', p_request_id=>v_request_id); 


        delete xxbot.xxtt_q_main_customer;
        DELETE xxbot.XXBOTS_AR_PAYMENT_SCHEDULES;
        commit;

		  vProgreso := '0.3';

         XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>1, p_punto_control=>1, p_text=>'ANTES DE Q_MAIN', p_ins_conteo=>'N', p_request_id=>v_request_id); 
        insert into xxbot.xxtt_q_main_customer
        SELECT status.meaning status,
                        SUBSTRB (party.party_name, 1, 50) Name,
                        cust_acct.account_number Number_A,
                        cust_acct.cust_account_id Customer_Id,
                        NVL (cp_site.collector_id, cp_cust.collector_id) Collector_Id,
                        col.name Collector,
                        cust_acct.ATTRIBUTE15 Agent_name,
                        0,--site_uses.site_use_id cp_site_use_id,
                        site_uses.location location
                       ,cust_acct.ATTRIBUTE15
                       ,site_uses.org_id
                        --,cte.type_process  type_process
                   FROM apps.ar_lookups status,
                        apps.ar_collectors col,
                        apps.hz_customer_profiles cp_cust,
                        apps.hz_customer_profiles cp_site,
                        apps.hz_cust_accounts cust_acct,
                        apps.hz_parties party,
                        apps.hz_cust_site_uses_all site_uses,
                        apps.hz_cust_acct_sites_all acct_site
                       ,--apps.xxar_bots_tbl_customers_mails
                        (select distinct cte.customer_id
                        from apps.xxar_bots_tbl_customers_mails cte
                        where 1 = 1
                        union
                        select distinct cte.customer_id
                        from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                        where 1 = 1) cte
                  WHERE 1 = 1
                    --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                    and acct_site.cust_account_id = cust_acct.cust_account_id
                    AND cust_acct.cust_account_id  = cte.Customer_Id
                    /*and cust_acct.cust_account_id in (select distinct cte.customer_id
                                                        from apps.xxar_bots_tbl_customers_mails cte
                                                       where 1=1
                                                      union
                                                      select distinct cte.customer_id
                                                        from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                                       where 1=1)   */
                     AND cust_acct.party_id          = party.party_id
                     AND site_uses.cust_acct_site_id = acct_site.cust_acct_site_id
                     AND site_uses.site_use_code     = 'BILL_TO'
                     AND cp_site.site_use_id(+)   = site_uses.site_use_id
                     AND cp_cust.cust_account_id  = cust_acct.cust_account_id
                     AND cp_cust.site_use_id     IS NULL
                     AND col.collector_id         = NVL (cp_site.collector_id, cp_cust.collector_id)
                     AND DECODE (cp_site.collector_id, NULL, cp_cust.account_status,
                                                             cp_site.account_status) = status.lookup_code
                     AND status.lookup_type       = 'ACCOUNT_STATUS'
                     AND EXISTS (SELECT 'x'
                                   FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
                                  WHERE (ps.status              = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
                                    AND ps.customer_id          = cust_acct.cust_account_id
                                    AND ps.customer_site_use_id = site_uses.site_use_id)

                 UNION
                 SELECT status.meaning status,
                        SUBSTRB (party.party_name, 1, 50) Name,
                        cust_acct.account_number Number_A,
                        cust_acct.cust_account_id Customer_Id,
                        NVL (cp_site.collector_id, cp_cust.collector_id) Collector_Id,
                        col.name Collector,
                        cust_acct.ATTRIBUTE15 Agent_name,
                        0,--site_uses.site_use_id cp_site_use_id,
                        site_uses.location location
                        ,cust_acct.ATTRIBUTE15
                        ,site_uses.org_id
                      -- ,cte.type_process type_process
                   FROM apps.ar_lookups status,
                        apps.ar_collectors col,
                        apps.hz_customer_profiles cp_cust,
                        apps.hz_customer_profiles cp_site,
                        apps.hz_cust_accounts cust_acct,
                        apps.hz_parties party,
                        apps.hz_cust_site_uses_all site_uses,
                        apps.hz_cust_acct_sites_all acct_site
                        ,--apps.xxar_bots_tbl_customers_mails
                        (select distinct cte.customer_id
                        from apps.xxar_bots_tbl_customers_mails cte
                        where 1 = 1
                        union
                        select distinct cte.customer_id
                        from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                        where 1 = 1)    cte
                  WHERE 1 = 1
                  --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                    and acct_site.cust_account_id = cust_acct.cust_account_id
                    AND cust_acct.cust_account_id  = cte.Customer_Id
                    /*and cust_acct.cust_account_id in (select distinct cte.customer_id
                                                        from apps.xxar_bots_tbl_customers_mails cte
                                                       where 1 = 1
                                                      union
                                                      select distinct cte.customer_id
                                                        from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                                       where 1 = 1)*/
                    AND cust_acct.party_id           = party.party_id
                    AND site_uses.cust_acct_site_id  = acct_site.cust_acct_site_id
                    AND site_uses.site_use_code      = 'BILL_TO'
                    AND cp_site.site_use_id(+)       = site_uses.site_use_id
                    AND cp_cust.cust_account_id      = cust_acct.cust_account_id
                    AND cp_cust.site_use_id         IS NULL
                    AND col.collector_id             = NVL (cp_site.collector_id, cp_cust.collector_id)
                    AND cp_site.collector_id        IS NULL
                    AND cp_cust.account_status       = status.lookup_code(+)
                    AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
                    AND EXISTS (SELECT 'x'
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
                        0,--site_uses.site_use_id cp_site_use_id,
                        site_uses.location location
                       ,cust_acct.ATTRIBUTE15
                       ,site_uses.org_id
                        -- ,cte.type_process
                   FROM apps.ar_lookups status,
                        apps.ar_collectors col,
                        apps.hz_customer_profiles cp_cust,
                        apps.hz_customer_profiles cp_site,
                        apps.hz_cust_accounts cust_acct,
                        apps.hz_parties party,
                        apps.hz_cust_site_uses_all site_uses,
                        apps.hz_cust_acct_sites_all acct_site
                       ,--apps.xxar_bots_tbl_customers_mails
                       (select distinct cte.customer_id
                        from apps.xxar_bots_tbl_customers_mails cte
                        where 1 = 1
                        union
                        select distinct cte.customer_id
                        from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                        where 1 = 1) cte
                  WHERE 1 = 1
                  --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                    and acct_site.cust_account_id = cust_acct.cust_account_id
                    AND cust_acct.cust_account_id  = cte.Customer_Id
                    /*and cust_acct.cust_account_id in (select distinct cte.customer_id
                                                        from apps.xxar_bots_tbl_customers_mails cte
                                                       where 1 = 1
                                                      union
                                                      select distinct cte.customer_id
                                                        from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                                       where 1 = 1)*/
                    AND cust_acct.party_id           = party.party_id
                    AND site_uses.cust_acct_site_id  = acct_site.cust_acct_site_id
                    AND site_uses.site_use_code      = 'BILL_TO'
                    AND cp_site.site_use_id(+)       = site_uses.site_use_id
                    AND cp_cust.cust_account_id      = cust_acct.cust_account_id
                    AND cp_cust.site_use_id         IS NULL
                    AND col.collector_id             = NVL (cp_site.collector_id, cp_cust.collector_id)
                    AND cp_site.collector_id        IS NOT NULL
                    AND cp_site.account_status       = status.lookup_code(+)
                    AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
                    AND EXISTS (SELECT 'x'
                                  FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
                                 WHERE (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
                                   AND ps.customer_id          = cust_acct.cust_account_id
                                   AND ps.customer_site_use_id = site_uses.site_use_id)
                 /*UNION
                 SELECT status.meaning,
                        SUBSTRB (party.party_name, 1, 50),
                        cust_acct.account_number,
                        cust_acct.cust_account_id,
                        col.collector_id,
                        col.name,
                        cust_acct.ATTRIBUTE15 Agent_name,
                        0,--DECODE ('Customer', NULL, 0, -88888),
                        TO_CHAR (NULL)
                        ,cust_acct.ATTRIBUTE15
                      -- ,cte.type_process
                   FROM apps.ar_lookups status,
                        apps.ar_collectors col,
                        apps.hz_customer_profiles cp_cust,
                        apps.hz_cust_accounts cust_acct,
                        apps.hz_parties party
                       ,--apps.xxar_bots_tbl_customers_mails
                        (select distinct cte.customer_id
                        from apps.xxar_bots_tbl_customers_mails cte
                        where 1 = 1
                        union
                        select distinct cte.customer_id
                        from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                        where 1 = 1)cte
                  WHERE 1 = 1
                  --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                    and cp_cust.cust_account_id = cust_acct.cust_account_id
                    AND cust_acct.cust_account_id  = cte.Customer_Id
                    /*and cust_acct.cust_account_id in (select distinct cte.customer_id
                                                        from apps.xxar_bots_tbl_customers_mails cte
                                                       where 1 = 1
                                                      union
                                                      select distinct cte.customer_id
                                                        from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                                       where 1 = 1)*/
                    /*AND cust_acct.party_id     = party.party_id
                    AND cp_cust.site_use_id   IS NULL
                    AND cp_cust.collector_id   = col.collector_id
                    AND cp_cust.account_status = status.lookup_code(+)
                    AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
                    AND EXISTS (SELECT 'x'
                                  FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
                                 WHERE (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
                                   AND ps.customer_id = cust_acct.cust_account_id
                                   AND ps.customer_site_use_id IS NULL)*/
                ;
        -- quitamos los que no son de la compañia
        delete xxtt_q_main_customer
        where org_id!= p_org_id;

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>1, p_punto_control=>2, p_text=>'ANTES DE PAYMENT SCHEDULES', p_ins_conteo=>'N', p_request_id=>v_request_id);

        INSERT INTO XXBOTS_AR_PAYMENT_SCHEDULES
        select PS.*
        from apps.AR_PAYMENT_SCHEDULES_ALL ps
            --,xxtt_q_main_customer m
        where 1=1
        and ps.org_id = P_ORG_ID
        --and ps.last_update_date >= trunc(sysdate)-30
        AND ps.gl_date                   <= sysdate
        AND ps.gl_date_closed             > sysdate
        AND ps.status || ''               = 'OP'
        AND abs(ps.amount_due_remaining) >= 1.00;

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>2, p_punto_control=>1, p_text=>'INICIA CARGA DE TABLA TT', p_ins_conteo=>'SI', p_request_id=>v_request_id);

        v_iter := 0;

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>2, p_punto_control=>2, p_text=>'0 INICIA CARGA', p_ins_conteo=>'N', p_request_id=>v_request_id);

        OPEN  cur_principal ;
        LOOP
            FETCH cur_principal BULK COLLECT INTO cur_principal_arr LIMIT v_limit;
            FORALL i IN 1 .. cur_principal_arr.COUNT
            insert into  XXBOT.XXAR_BOTS_EDO_CTA_TT values cur_principal_arr(i);

            v_iter := v_iter+1;

            --if v_iter=1 then
            --    XXBOT_LOG_EDOCTA(p_org_id,2,2,'1 COMMIT ITERACION 1','N');
            --end if;

            --if mod(v_iter,v_mod) =0 then
                XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>2, p_punto_control=>2, p_text=>'2 COMMIT v_iter:'||v_iter, p_ins_conteo=>'N', p_request_id=>v_request_id);
            --end if;

            EXIT WHEN cur_principal%NOTFOUND;
        END LOOP;
        CLOSE cur_principal;
        COMMIT;

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>2, p_punto_control=>2, p_text=>'4 TERMINA CARGA TT', p_ins_conteo=>'SI', p_request_id=>v_request_id);


        declare
            v_count number;
        begin
            select count(*) into v_count
            from XXBOT.XXAR_BOTS_EDO_CTA_TT;

            XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>2, p_punto_control=>3, p_text=>'No. Reg TT:'||v_count, p_ins_conteo=>'N', p_request_id=>v_request_id);
        end;


        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>3, p_punto_control=>1, p_text=>null, p_ins_conteo=>'N', p_request_id=>v_request_id);

        -- ACTUALIZO GRUPO DE SEGURIDAD --
        vProgreso := '1.1';

        BEGIN
            FOR CUR IN (SELECT a.NAME_GRPSEG,b.contact_number  --into V_GS
                          FROM XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a,
                               XXAR_GRPCBZ_GRPSEGN2_TBL@OCIPROD_TO_ORAPROD19 b
                         WHERE 1=1
                           AND a.ID_GSN1      = b.ID_GSN1
                           AND a.ENABLED_FLAG = b.ENABLED_FLAG
                           AND a.ENABLED_FLAG = 'Y'
                           AND SYSDATE BETWEEN a.start_date AND NVL (a.end_date,SYSDATE + 1)
                           AND b.contact_number IN (SELECT DISTINCT G_D_COBRANZA
                                                      FROM xxbot.xxar_bots_edo_cta_tt
                                                     WHERE 1 = 1
                                                       AND G_D_COBRANZA IS NOT NULL)
            )LOOP
                UPDATE XXBOT.XXAR_BOTS_EDO_CTA_TT
                   SET G_D_SEGURIDAD = CUR.NAME_GRPSEG
                 WHERE 1 = 1
                   AND G_D_COBRANZA  = CUR.contact_number;
            END LOOP;
            COMMIT;
        END;

        vProgreso := '1.2';
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>4, p_punto_control=>1, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);
        -- valido las transacciones que NO existenen la nueva ejecució, dado que ya se han pagado.
        -- actualizo recibo --
        update /*+index(a IDX_XXAR_BOTS_TBL_EDO_CTA_N5)*/ xxbot.xxar_bots_edo_cta a
           set (balance_due,last_update_date, last_update_date_prc,a.no_recibo,a.no_editado)
                                                                            = (select b.amount_due_remaining, b.last_update_date, sysdate
                                                                                        ,trx.attribute8 no_recibo
                                                                                        ,trx.attribute6 no_editado
                                                                                    from apps.AR_PAYMENT_SCHEDULES_ALL b
                                                                                        ,ar.ra_customer_trx_all trx
                                                                                where 1=1
                                                                                    and A.CUSTOMER_TRX_ID = b.customer_trx_id
                                                                                    and trx.customer_trx_id = b.customer_trx_id)
         where 1 = 1
           and org_id = P_ORG_ID
           and a.CUSTOMER_TRX_ID NOT IN (select tt.customer_trx_id
                                           from xxbot.xxar_bots_edo_cta_tt tt--,
                                                --xxbot.xxar_bots_edo_cta b
                                          --where 1 = 1
                                            --and b.customer_trx_id = a.customer_trx_id
                                            )
            and a.Balance_Due     <> 0;
        commit;
        vProgreso := '1.3';

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>5, p_punto_control=>1, p_text=>null, p_ins_conteo=>'N', p_request_id=>v_request_id);
        --
        BEGIN
            -- Actualiza si el G_D_COBRANZA esta vacio y ya tiene valor o si este cambio
            FOR CUR IN(select *
                         from xxbot.xxar_bots_edo_cta_tt
                        WHERE 1=1
                          and org_id = P_ORG_ID
                          AND G_D_COBRANZA IS NOT NULL)
            LOOP
                UPDATE /*+index(m IDX_XXAR_BOTS_TBL_EDO_CTA_N5)*/ xxbot.xxar_bots_edo_cta m
                   SET G_D_SEGURIDAD   = CUR.G_D_SEGURIDAD,
                       G_D_COBRANZA    = CUR.G_D_COBRANZA,
                       last_update_date_prc= sysdate -- cedc 20-03-2026
                 WHERE 1 = 1
                   --and a.Balance_Due     <> 0
                   AND CUSTOMER_TRX_ID = CUR.CUSTOMER_TRX_ID
                   AND nvl(G_D_COBRANZA,'vacio')!=cur.G_D_COBRANZA ;
            END LOOP;
            COMMIT;
        END;
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>5, p_punto_control=>2, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);
        --
        vProgreso := '1.4';

        vProgreso := '2.1';
        -- actualizo recibo --
        /*
        update xxbot.xxar_bots_edo_cta a
           set (a.no_recibo,a.last_update_date_prc)= (select b.attribute8, sysdate
                                                        from ar.ra_customer_trx_all b
                                                       where 1 = 1
                                                         and A.CUSTOMER_TRX_ID = b.customer_trx_id)
         where 1 = 1
           and a.Balance_Due <> 0
           and nvl(a.no_recibo,'recibo')   <> (select b.attribute8
                                                from ar.ra_customer_trx_all b
                                                where 1 = 1
                                                    and A.CUSTOMER_TRX_ID = b.customer_trx_id)
           and a.CUSTOMER_TRX_ID NOT IN (select tt.customer_trx_id
                                           from xxbot.xxar_bots_edo_cta_tt tt
                                                --xxbot.xxar_bots_edo_cta b
                                          --where 1 = 1
                                            --and b.customer_trx_id = a.customer_trx_id
                                            );
        commit;
        */
        -- actualizo attribute6 --
        vProgreso := '2.2';
        /*update xxbot.xxar_bots_edo_cta a
           set (a.no_editado,a.last_update_date_prc) = (select b.attribute6, sysdate
                                                          from ar.ra_customer_trx_all b
                                                         where 1 = 1
                                                           and A.CUSTOMER_TRX_ID = b.customer_trx_id)
         where 1=1
           and a.Balance_Due <> 0
           and a.no_editado  <> (select b.attribute6
                                   from ar.ra_customer_trx_all b
                                  where 1=1
                                    and A.CUSTOMER_TRX_ID=b.customer_trx_id);
        commit;*/

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>6, p_punto_control=>1, p_text=>null, p_ins_conteo=>'N', p_request_id=>v_request_id);

        -- ACTUALIZO CLIENTE --
        vProgreso := '3.1';
        UPDATE /*+index(b IDX_XXAR_BOTS_TBL_EDO_CTA_N5)*/ xxbot.xxar_bots_edo_cta B
           SET (B.CLIENT,b.last_update_date_prc) = (SELECT distinct (A.CLIENT) ,sysdate
                                                      FROM apps.xxar_bots_tbl_customers_mails A
                                                     WHERE 1 = 1
                                                       and client is not null
                                                       AND B.NUMBER_A = A.CUSTOMER_NUMBER)
         WHERE 1 = 1
           and b.org_id = P_ORG_ID
           and b.customer_trx_id in (select customer_trx_id from xxbot.xxar_bots_edo_cta_tt a)
           AND nvl(B.CLIENT,'no hay cliente') <>(SELECT distinct (A.CLIENT)
                                                FROM apps.xxar_bots_tbl_customers_mails A
                                                WHERE 1 = 1
                                                  and client     is not null
                                                  AND B.NUMBER_A = A.CUSTOMER_NUMBER)
            --and creation_date_prc >= trunc(sysdate)-30
           /*and b.CUSTOMER_TRX_ID NOT IN (select b.customer_trx_id
                                           from xxbot.xxar_bots_edo_cta_tt a,
                                                xxbot.xxar_bots_edo_cta b
                                          where 1 = 1
                                            and b.customer_trx_id = a.customer_trx_id)*/
                                            ;
        COMMIT;
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>6, p_punto_control=>2, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);
        vProgreso := '3.2';
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>7, p_punto_control=>1, p_text=>null, p_ins_conteo=>'N', p_request_id=>v_request_id);

        -- actualizo las trasnacciones que han sufrido cambios en los bloques. --
        vProgreso := '4.1';
        MERGE INTO /*+index(m IDX_XXAR_BOTS_TBL_EDO_CTA_N5)*/ xxbot.xxar_bots_edo_cta M
        USING (select B0, B1, B2, B3, B4, B5,
                      B6, B7, B8, B9, B10, B11,
                      B12, B13, B14, B15, B16,
                      B17, B18,
                      CUSTOMER_TRX_ID       ,
                      last_update_date_prc  ,
                      collector_id          ,
                      collector
                 from xxbot.xxar_bots_edo_cta_TT
                where 1 = 1) X
           ON (
               M.CUSTOMER_TRX_ID = X.CUSTOMER_TRX_ID
              )
        WHEN MATCHED THEN UPDATE SET
            m.last_update_date_prc = sysdate, --x.last_update_date_prc, --cedc 20-03-2026
            M.B0                   = X.B0,
            M.B1                   = X.B1,
            M.B2                   = X.B2,
            M.B3                   = X.B3,
            M.B4                   = X.B4,
            M.B5                   = X.B5,
            M.B6                   = X.B6,
            M.B7                   = X.B7,
            M.B8                   = X.B8,
            M.B9                   = X.B9,
            M.B10                  = X.B10,
            M.B11                  = X.B11,
            M.B12                  = X.B12,
            M.B13                  = X.B13,
            M.B14                  = X.B14,
            M.B15                  = X.B15,
            M.B16                  = X.B16,
            M.B17                  = X.B17,
            M.B18                  = X.B18,
            M.COLLECTOR_ID         = X.COLLECTOR_ID,
            M.COLLECTOR            = X.COLLECTOR
            WHERE 1=1
              AND M.B0           <> X.B0 OR
                  M.B1           <> X.B1 OR
                  M.B2           <> X.B2 OR
                  M.B3           <> X.B3 OR
                  M.B4           <> X.B4 OR
                  M.B5           <> X.B5 OR
                  M.B6           <> X.B6 OR
                  M.B7           <> X.B7 OR
                  M.B8           <> X.B8 OR
                  M.B9           <> X.B9 OR
                  M.B10          <> X.B10 OR
                  M.B11          <> X.B11 OR
                  M.B12          <> X.B12 OR
                  M.B13          <> X.B13 OR
                  M.B14          <> X.B14 OR
                  M.B15          <> X.B15 OR
                  M.B16          <> X.B16 OR
                  M.B17          <> X.B17  OR
                  M.B18          <> X.B18 OR
                  M.COLLECTOR_ID <> X.COLLECTOR_ID OR
                  M.COLLECTOR    <> X.COLLECTOR ;
        commit;
        vProgreso := '4.2';
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>7, p_punto_control=>2, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>8, p_punto_control=>1, p_text=>null, p_ins_conteo=>'N', p_request_id=>v_request_id);
        vProgreso := '5.1';
        /*MERGE INTO xxbot.xxar_bots_edo_cta M
        USING (select uuid                , estatus             , DESCRIPCION_ESTATUS ,
                      ACCESO_DOCTO        , url,SISTEMA_DESTINO , customer_trx_id     ,
                      numero_docto        , sysdate as last_update_date_prc,   org_id
                 from AR.CUST_AR_FACTELEC_LOG
                where 1 = 1
                  AND ORG_ID = P_ORG_ID) X
        ON (
            M.CUSTOMER_TRX_ID = X.CUSTOMER_TRX_ID and m.number_b=x.numero_docto and M.ORG_ID=X.ORG_ID
           )
        WHEN MATCHED THEN UPDATE SET
            m.last_update_date_prc = sysdate, --x.last_update_date_prc, --cedc 20-03-2026
            M.uuid                 = X.uuid ,
            M.estatus              = X.estatus ,
            M.DESCRIPCION_ESTATUS  = X.DESCRIPCION_ESTATUS ,
            M.ACCESO_DOCTO         = X.ACCESO_DOCTO ,
            M.url                  = X.url ,
            M.SISTEMA_DESTINO      = X.SISTEMA_DESTINO;
        commit;*/-- e comento ya que al hacer match llevaba a millones los registros

        BEGIN
          --FOR CUR IN (SELECT /*+ use_ln(m x)
          --                     INDEX(X CUST_AR_FACTELEC_LOG_INDEX1)*/X.*
          /*      FROM xxbot.xxar_bots_edo_cta M
                  ,AR.CUST_AR_FACTELEC_LOG X
                WHERE 1=1
                AND M.Balance_Due     <> 0
                AND x.creation_date >= trunc(sysdate-5)
                AND x.org_id = P_ORG_ID
                AND M.ORG_ID = x.org_id
                AND M.CUSTOMER_TRX_ID = X.CUSTOMER_TRX_ID
                and m.number_b=x.numero_docto
                and M.ORG_ID=X.ORG_ID
                AND nvl(M.uuid,'vacio') != nvl(X.uuid,'vacio'))*/
          FOR CUR IN (select X.*
                from AR.CUST_AR_FACTELEC_LOG X
                    ,xxbot.xxar_bots_edo_cta M
                where 1=1
                and X.org_id = 84
                and ((X.creation_date is not null and X.creation_date >= sysdate-5)
                      or (X.ACCESO_DOCTO is not null and X.ACCESO_DOCTO >= sysdate-5)
                      or (X.FECHA_CAMBIO_REGISTRO is not null and X.FECHA_CAMBIO_REGISTRO >= sysdate-5)
                      )
                AND M.CUSTOMER_TRX_ID = X.CUSTOMER_TRX_ID
                and M.ORG_ID=X.ORG_ID
                AND nvl(M.uuid,'vacio') != nvl(X.uuid,'vacio')  )
          
          LOOP
            UPDATE /*+index(m IDX_XXAR_BOTS_TBL_EDO_CTA_N5)*/  xxbot.xxar_bots_edo_cta M
            SET m.last_update_date_prc = sysdate, --x.last_update_date_prc, --cedc 20-03-2026
                    M.uuid                 = CUR.uuid ,
                    M.estatus              = CUR.estatus ,
                    M.DESCRIPCION_ESTATUS  = CUR.DESCRIPCION_ESTATUS ,
                    M.ACCESO_DOCTO         = CUR.ACCESO_DOCTO ,
                    M.url                  = CUR.url ,
                    M.SISTEMA_DESTINO      = CUR.SISTEMA_DESTINO
            where m.customer_trx_id = cur.customer_trx_id;
            COMMIT;
          END LOOP;

        END;
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>8, p_punto_control=>2, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);

        vProgreso := '5.2';
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>9, p_punto_control=>1, p_text=>null, p_ins_conteo=>'N', p_request_id=>v_request_id);

        -- actualizo las trasnacciones que han sufrido cambios en montos. --
        vProgreso := '6.1';
        BEGIN
            for CUR  IN (select /*+ use_nl(a b)
                                    index(b IDX_XXAR_BOTS_TBL_EDO_CTA_N5)*/ A.*
                           from xxbot.xxar_bots_edo_cta_tt a,
                                xxbot.xxar_bots_edo_cta b
                          where 1 = 1
                            and b.customer_trx_id=a.customer_trx_id
                            and a.balance_due<>b.balance_due
                            AND B.ORG_ID =p_org_id)
            LOOP
                update xxbot.xxar_bots_edo_cta a
                   set a.LAST_UPDATE_DATE_PRC = sysdate,
                       a.balance_due          = nvl(cur.balance_due,a.balance_due),
                       a.uuid                 = cur.uuid,
                       a.estatus              = cur.estatus,
                       a.descripcion_estatus  = cur.descripcion_estatus,
                       a.url                  = cur.url,
                       a.B0                   = cur.B0,
                       a.B1                   = cur.B1,
                       a.B2                   = cur.B2,
                       a.B3                   = cur.B3,
                       a.B4                   = cur.B4,
                       a.B5                   = cur.B5,
                       a.B6                   = cur.B6,
                       a.B7                   = cur.B7,
                       a.B8                   = cur.B8,
                       a.B9                   = cur.B9,
                       a.B10                  = cur.B10,
                       a.B11                  = cur.B11,
                       a.B12                  = cur.B12,
                       a.B13                  = cur.B13,
                       a.B14                  = cur.B14,
                       a.B15                  = cur.B15,
                       a.B16                  = cur.B16,
                       a.B17                  = cur.B17,
                       a.B18                  = cur.B18,
                       A.G_D_COBRANZA         = cur.G_D_COBRANZA,
                       a.G_D_SEGURIDAD        = cur.G_D_SEGURIDAD,
                       a.last_update_date     = cur.last_update_date
                 where 1 = 1
                   and a.customer_trx_id = cur.customer_trx_id;
                COMMIT;
            END LOOP;
        END;
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>9, p_punto_control=>2, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);
        vProgreso := '6.2';

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>10, p_punto_control=>1, p_text=>'Inserta nuevas lineas', p_ins_conteo=>'N', p_request_id=>v_request_id);
        -- ahora se insertan las nuevas lineas,
        --vProgreso := '7.1';

        for cur in (select /*+ use_nl(b a)
                              index(a IDX_XXAR_BOTS_TBL_EDO_CTA_N5)*/ b.customer_trx_id
                    from xxbot.xxar_bots_edo_cta_tt b
                        ,xxbot.xxar_bots_edo_cta a
                    where 1 = 1
                      and a.customer_trx_id(+) = b.customer_trx_id
                      and a.customer_trx_id is null)
        loop
          insert into xxbot.xxar_bots_edo_cta a
          select *
            from xxbot.xxar_bots_edo_cta_tt b
            where 1 = 1
              and b.customer_trx_id=cur.customer_trx_id;
              commit;
        end loop;

        -- insert into xxbot.xxar_bots_edo_cta a  (select *
        --                                           from xxbot.xxar_bots_edo_cta_tt b
        --                                          where 1 = 1
        --                                            and b.customer_trx_id  not in (select /*+index(a IDX_XXAR_BOTS_TBL_EDO_CTA_N5)*/ a.customer_trx_id
        --                                                                             from xxbot.xxar_bots_edo_cta a
        --                                                                                  xxbot.xxar_bots_edo_cta_tt b
        --                                                                            where 1 = 1
        --                                                                              --and a.customer_trx_id = b.customer_trx_id
        --                                                                              ));
        -- vProgreso := '7.2';
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>11, p_punto_control=>1, p_text=>'termina de insertar', p_ins_conteo=>'N', p_request_id=>v_request_id);

        vProgreso := '8.1';
        BEGIN
              for cur in (select distinct number_a
                            from xxbot.xxar_bots_edo_cta
                          where 1=1
                            and org_id = P_ORG_ID
                            and send_mail is null)
            loop
                V_COUNT := NULL;
                vProgreso := '8.2';
                select count (*)
                  into v_count
                  from apps.xxar_bots_tbl_customers_mails
                 where 1 = 1
                   and customer_number = cur.number_a
                   and type_process    = 'SEND MAIL' ;

                if v_count >= 1 then
                vProgreso := '8.3';
                    update xxbot.xxar_bots_edo_cta a
                       set a.send_mail            = 'NO ENVIADO'
                          ,a.last_update_date_prc = sysdate
                     where 1 = 1
                       AND send_mail  is null
                       and a.number_a = cur.number_a;
                else

                    vProgreso := '8.4';
                    update xxbot.xxar_bots_edo_cta a
                       set a.send_mail = 'N/A'
                          ,a.last_update_date_prc = sysdate
                     where 1 = 1
                       AND send_mail  is null
                       and a.number_a  = cur.number_a;
                END IF;
                COMMIT;
            END LOOP;
        END;
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>11, p_punto_control=>2, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);
        vProgreso := '8.5';

       XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>12, p_punto_control=>1, p_text=>null, p_ins_conteo=>'N', p_request_id=>v_request_id);

        vProgreso := '9.1';
        BEGIN
            for cur in (select distinct number_a
                          from xxbot.xxar_bots_edo_cta
                         where 1 = 1
                          and org_id = P_ORG_ID
                           and portal is null)
            loop
                V_COUNT := NULL;

                vProgreso := '9.2';
                select count (*)
				        into v_count
                  from apps.xxar_bots_tbl_customers_mails
                 where 1 = 1
                   and customer_number = cur.number_a
                   and type_process    = 'PORTAL';

                if v_count >= 1 then
                    vProgreso := '9.3';
                    update xxbot.xxar_bots_edo_cta a
                       set a.PORTAL               = 'NO ENVIADO'
                          ,a.last_update_date_prc = sysdate
                     where 1=1
                       AND PORTAL     is null
                       and a.number_a  = cur.number_a;
                else
                    vProgreso := '9.4';
                    update xxbot.xxar_bots_edo_cta a
                       set a.PORTAL               = 'N/A'
                          ,a.last_update_date_prc = sysdate
                     where 1=1
                       AND PORTAL     is null
                       and a.number_a  = cur.number_a;
                END IF;
                COMMIT;
            END LOOP;
        END;
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>12, p_punto_control=>2, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);
        vProgreso := '9.5';

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>13, p_punto_control=>1, p_text=>null, p_ins_conteo=>'N', p_request_id=>v_request_id);

        vProgreso := '10.1';
        BEGIN
            /*for cur in ( select distinct (customer_number),client
                           from apps.xxar_bots_tbl_customers_mails
                          where 1=1
                            and client is not null)
            loop
                vProgreso := '10.2';
                update xxbot.xxar_bots_edo_cta a
                   set a.client               = cur.client
                      ,a.last_update_date_prc = sysdate
                 where 1=1
                   AND client     is null
                   and a.number_a  = cur.customer_number;
                COMMIT;
            END LOOP;*/
            for cur in (SELECT a.customer_trx_id, cte.client
                        FROM xxbot.xxar_bots_edo_cta a,
                          (select distinct (customer_number),client
                                        from apps.xxar_bots_tbl_customers_mails
                                        where 1=1
                                        and client is not NULL
                                        ) cte
                       WHERE 1=1
                          AND a.org_id = P_ORG_ID
                          AND a.client IS NULL
                          AND BALANCE_DUE!=0
                          and a.number_a  =  cte.customer_number
                      )
              loop
                  vProgreso := '10.2';
                  update xxbot.xxar_bots_edo_cta a
                    set a.client               = cur.client
                        ,a.last_update_date_prc = sysdate
                  where 1=1
                    AND client     is null
                    and a.customer_trx_id  = cur.customer_trx_id;
                  COMMIT;
              END LOOP;
        END;
       XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>13, p_punto_control=>2, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);
        vProgreso := '10.3';

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>14, p_punto_control=>1, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);

        vProgreso := '11.1';
        update xxbot.xxar_bots_edo_cta a
           set (A.CEDIS,A.REGION,A.NUD,A.last_update_date_prc) = (select b.CEDIS,b.REGION,B.TERMINAL, sysdate -- CEDC 20-03-2026
                                                                    from XXBOT.XXAR_BOTS_SENDEROS_CATALOG b
                                                                    where 1=1
                                                                    and A.REFERENCIA_DIRECCION=TO_CHAR (b.REFERENCIA))
         where 1=1
           AND BALANCE_DUE!=0
           and number_a in (select distinct(to_char(b.cadena))
                              from XXBOT.XXAR_BOTS_SENDEROS_CATALOG b
                             where 1 = 1)
           and cedis  is null
           and region is null
           and nud    is null
           and org_id  = p_org_id;
        commit;
        vProgreso := '11.2';

       XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>14, p_punto_control=>2, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);

        -- actualizo ejecutivo --
        update xxar_bots_edo_cta a
           set (a.ejecutivo,a.last_update_date_prc)=(select attribute15, sysdate
                                                       from apps.ar_customers b
                                                      where 1 = 1
                                                        and a.customer_id = b.customer_id)
         where 1 = 1
           and a.Balance_Due <> 0
           AND A.ORG_ID       = p_org_id;
        commit;
        vProgreso := '11.3';
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>14, p_punto_control=>3, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);
        -- actualizo NOTAS --
        BEGIN
            for cur in ( select b.customer_trx_id,C.STATUS_DESC,B.SCHEDULED_DATE
                           from xx_apex.XXAR_GRPCBZ_DCOMM_TBL@OCIPROD_TO_ORAPROD19 B,
                                xx_apex.XXAR_GRPCBZ_STATUS_TBL@OCIPROD_TO_ORAPROD19 C
                          where 1 = 1
                            and b.org_id = p_org_id
                            and C.source_type = 'D'
                            and B.status      = C.status)
            loop
                vProgreso := '11.4';
                update xxar_bots_edo_cta a
                   set a.MESSAGE=cur.STATUS_DESC,
                       a.SCHEDULED_DATE=cur.SCHEDULED_DATE,
                       a.last_update_date_prc= sysdate
                 where 1 = 1
                   and a.customer_trx_id=cur.customer_trx_id
                   and (nvl(a.MESSAGE,'no hay mensaje') != cur.STATUS_DESC
                       or a.SCHEDULED_DATE !=cur.SCHEDULED_DATE);
                COMMIT;
            END LOOP;
        END;
         XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>14, p_punto_control=>4, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);
        vProgreso := '11.5';

         XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>15, p_punto_control=>1, p_text=>null, p_ins_conteo=>'NO', p_request_id=>v_request_id);
        vProgreso := '12.1';

        BEGIN
            for cur in ( select *
                           from xxbot.xxar_bots_edo_cta a
                          where 1 = 1
                            and org_id = P_ORG_ID
                            and A.client           = 'COSTCO'
                            AND ORG_ID            IN (180,84)
                            AND A.BALANCE_DUE     <> 0
                            AND A.CUSTOMER_TRX_ID NOT IN (SELECT CUSTOMER_TRX_ID
                                                            FROM XXBOT.XXAR_BOTS_TRX_COSTCO
                                                           WHERE 1 = 1))
            loop
                vProgreso := '12.2';
                INSERT INTO XXBOT.XXAR_BOTS_TRX_COSTCO
                            (CUSTOMER_TRX_ID      , ORDEN_DE_COMPRA      , STATUS_BOT           ,
                             CREATION_DATE        , CREATED_BY           , LAST_UPDATE_DATE     ,
                             LAST_UPDATE_BY       )
                     VALUES (CUR.CUSTOMER_TRX_ID  , CUR.PURCHASE_ORDER   , NULL                 ,
                             SYSDATE              , -1                   , SYSDATE              ,
                             -1                   );

                COMMIT;
            END LOOP;
        END;
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>15, p_punto_control=>2, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);
        vProgreso := '12.3';

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>16, p_punto_control=>1, p_text=>null, p_ins_conteo=>'NO', p_request_id=>v_request_id);
        vProgreso := '13.1';

--      begin
--      XXAR_BOTS_ESTADO_D_CTA_CS (P_ORG_ID);
--      end;
--      commit;
        BEGIN
            for cur in (SELECT A.ATTRIBUTE15,A.CUSTOMER_TRX_ID
                          FROM XXBOT.xxar_bots_edo_cta B, AR.RA_CUSTOMER_TRX_ALL A
                         WHERE 1 = 1
                          and b.org_id = P_ORG_ID
                           AND A.CUSTOMER_TRX_ID  = B.CUSTOMER_TRX_ID
                           and a.attribute15     is not null
                           AND B.PORTAL           = 'ENV-PAC'
                           AND B.CLIENT          in ('VIPS','DOMINOS')
                           AND B.TRX_DATE        >=(SELECT TO_DATE(PATH_DIR,'DD-MM-YYYY')
                                                      FROM XXBOT.XXAR_BOTS_PATH
													 WHERE USERNAME  = 'ALSEA'
                                                       AND PATH_TYPE = 'PARAMFECHALECTURA')
                                                     --AND B.ESTATUS_USUARIO ='ENCONTRADO'
                       )
            loop
                vProgreso := '13.2';
                UPDATE XXBOT.xxar_bots_edo_cta
                   SET PORTAL               = CUR.ATTRIBUTE15
                      ,last_update_date_prc = sysdate
                 WHERE 1 = 1
                   AND CUSTOMER_TRX_ID      = CUR.CUSTOMER_TRX_ID;
                COMMIT;
            END LOOP;
            COMMIT;
        END;
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>16, p_punto_control=>1, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);

        vProgreso := '13.3';
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>17, p_punto_control=>1, p_text=>null, p_ins_conteo=>'NO', p_request_id=>v_request_id);

        -- Se llama proceso para sincronizar BD eBS vs BD Apex
        vProgreso := '14.1';
        SYNC_UP_EBS_VS_BDAPEX(P_ORG_ID,TRUNC(SYSDATE-1));
        vProgreso := '14.2';

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>18, p_punto_control=>1, p_text=>null, p_ins_conteo=>'NO', p_request_id=>v_request_id);

        --SE ACTUALIZAN LAS VM DEL EDO CTA APEX
        begin
            XX_APEX.XXGEPP_UPDATE_VM@OCIPROD_TO_ORAPROD19 (v_msg);
            apps.MESSAGE_LOG (v_msg);
        end;
        vProgreso := '14.3';
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>18, p_punto_control=>2, p_text=>null, p_ins_conteo=>'SI', p_request_id=>v_request_id);

        -- Actualiza clientes
        INSERT INTO cfdi_ap_ar.xxar_bots_tbl_cust_mails_cs@OCIPROD_TO_ORAPROD19
        select *
        from xxwebc.xxar_bots_tbl_cust_mails_cs cte
        where 1=1
        and not exists(select 'ex'
                       from cfdi_ap_ar.xxar_bots_tbl_cust_mails_cs@OCIPROD_TO_ORAPROD19  bd19
                       where bd19.customer_id = cte.customer_id);
        COMMIT;

        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>18, p_punto_control=>3, p_text=>'TERMINO DE COMPLETAR LA TABLA xxar_bots_tbl_cust_mails_cs', p_ins_conteo=>'NO', p_request_id=>v_request_id);

        vProgreso := '15.1';
        update xx_apex.status_ecta_orgid@OCIPROD_TO_ORAPROD19
           set last_update_date = sysdate,
		       DESCRIPTION      = TO_CHAR(SYSDATE,'DD-MM-YY HH:MI:SS AM')
         where 1 = 1
           and org_id           = P_ORG_ID;
        COMMIT;
        vProgreso := '15.2';
        XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>19, p_punto_control=>1, p_text=>'TERMINO', p_ins_conteo=>'NO', p_request_id=>v_request_id);

        apps.MESSAGE_LOG('PROCESO TERMINO EXITOSAMENTE  '||SYSDATE||CHR(10));
        DBMS_OUTPUT.PUT_LINE('PROCESO TERMINO EXITOSAMENTE  '||SYSDATE||CHR(10));
        COMMIT;
        --return true;
    EXCEPTION
        WHEN OTHERS THEN
            apps.MESSAGE_LOG ('1. ' || vProgreso || 'ERR - EXC EN PROCESO DE ESTADO DE CUENTA '||SQLERRM||CHR(10));
            DBMS_OUTPUT.PUT_LINE('1. ' || vProgreso || 'ERR - EXC EN PROCESO DE ESTADO DE CUENTA '||SQLERRM);
            XXBOT_LOG_EDOCTA(p_org_id=>P_ORG_ID, p_estatus=>-1, p_punto_control=>0, p_text=>'ERR - EXC EN PROCESO DE ESTADO DE CUENTA '||SQLERRM, p_ins_conteo=>'NO', p_request_id=>v_request_id);  
            -- return false;
    END XXAR_BOTS_ESTADO_D_CTA;


    PROCEDURE XXAR_BOTS_ESTADO_D_CTA_BD (P_ORG_ID IN number)
    IS
        V_COUNT   NUMBER         := 0;
        v_msg     VARCHAR2(4000) := NULL;
        vProgreso VARCHAR2(5)    := NULL;
    begin
        begin
            apps.mo_global.set_policy_context('S', P_ORG_ID);
            DBMS_OUTPUT.PUT_LINE('OK_cias '||P_ORG_ID);
        exception
            when others then
                apps.mo_global.set_policy_context('S', P_ORG_ID);
                DBMS_OUTPUT.PUT_LINE(' no OK_cias '||P_ORG_ID);
        end;
        vProgreso := '0.1';
        begin
            EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE =  "AMERICAN" ';
            DBMS_OUTPUT.PUT_LINE('OK');
        EXCEPTION
		    WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('FALLA '||SQLERRM);
        end;
        vProgreso := '0.2';

        delete xxwebc.control_edo_cta;
        commit;

        vProgreso := '0.3';

        insert into xxwebc.control_edo_cta (estatus,fecha) values (0,sysdate);
        commit;

        vProgreso := '0.4';

        INSERT INTO xxbot.xxar_bots_edo_cta_tt
               WITH q_setup as (SELECT sob.name   Company_Name,
                                       sob.chart_of_accounts_id   coa_id,
                                       sob.currency_code   Functional_Currency,
                                       cur.precision      Functional_Currency_Precision
                                  FROM apps.gl_sets_of_books sob,
                                       apps.AR_SYSTEM_PARAMETERS param,
                                       apps.fnd_currencies cur
                                 WHERE sob.set_of_books_id = param.set_of_books_id
                               AND       sob.currency_code = cur.currency_code)
                   ,q_main as (SELECT status.meaning status,
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
                                WHERE 1 = 1
                                --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                                  and acct_site.cust_account_id = cust_acct.cust_account_id
                                --AND cust_acct.cust_account_id  = cte.Customer_Id
                                  and cust_acct.cust_account_id in (select distinct cte.customer_id
                                                                      from apps.xxar_bots_tbl_customers_mails cte
                                                                     where 1 = 1
                                                                    union
                                                                    select distinct cte.customer_id
                                                                      from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                                                     where 1 = 1)
                                  AND cust_acct.party_id = party.party_id
                                  AND site_uses.cust_acct_site_id = acct_site.cust_acct_site_id
                                  AND site_uses.site_use_code = 'BILL_TO'
                                  AND cp_site.site_use_id(+) = site_uses.site_use_id
                                  AND cp_cust.cust_account_id = cust_acct.cust_account_id
                                  AND cp_cust.site_use_id IS NULL
                                  AND col.collector_id = NVL (cp_site.collector_id, cp_cust.collector_id)
                                  AND DECODE (cp_site.collector_id, NULL, cp_cust.account_status, cp_site.account_status) = status.lookup_code
                                  AND status.lookup_type = 'ACCOUNT_STATUS'
                                  AND EXISTS (SELECT 'x'
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
                                WHERE 1 = 1
                                --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                                  and acct_site.cust_account_id = cust_acct.cust_account_id
                                --AND cust_acct.cust_account_id  = cte.Customer_Id
                                  and cust_acct.cust_account_id in (select distinct cte.customer_id
                                                                      from apps.xxar_bots_tbl_customers_mails cte
                                                                     where 1 = 1
                                                                    union
                                                                    select distinct cte.customer_id
                                                                      from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                                                     where 1=1)
                                  AND cust_acct.party_id = party.party_id
                                  AND site_uses.cust_acct_site_id = acct_site.cust_acct_site_id
                                  AND site_uses.site_use_code = 'BILL_TO'
                                  AND cp_site.site_use_id(+) = site_uses.site_use_id
                                  AND cp_cust.cust_account_id = cust_acct.cust_account_id
                                  AND cp_cust.site_use_id IS NULL
                                  AND col.collector_id = NVL (cp_site.collector_id, cp_cust.collector_id)
                                  AND cp_site.collector_id IS NULL
                                  AND cp_cust.account_status = status.lookup_code(+)
                                  AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
                                  AND EXISTS (SELECT 'x'
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
                                WHERE 1 = 1
                                --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                                  and acct_site.cust_account_id = cust_acct.cust_account_id
                                --AND cust_acct.cust_account_id  = cte.Customer_Id
                                  and cust_acct.cust_account_id in (select distinct cte.customer_id
                                                                      from apps.xxar_bots_tbl_customers_mails cte
                                                                     where 1 = 1
                                                                    union
                                                                    select distinct cte.customer_id
                                                                      from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                                                     where 1 = 1)
                                  AND cust_acct.party_id = party.party_id
                                  AND site_uses.cust_acct_site_id = acct_site.cust_acct_site_id
                                  AND site_uses.site_use_code = 'BILL_TO'
                                  AND cp_site.site_use_id(+) = site_uses.site_use_id
                                  AND cp_cust.cust_account_id = cust_acct.cust_account_id
                                  AND cp_cust.site_use_id IS NULL
                                  AND col.collector_id = NVL (cp_site.collector_id, cp_cust.collector_id)
                                  AND cp_site.collector_id IS NOT NULL
                                  AND cp_site.account_status = status.lookup_code(+)
                                  AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
                                  AND EXISTS (SELECT 'x'
                                                FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
                                               WHERE (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
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
                                WHERE 1 = 1
                                --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                                  and cp_cust.cust_account_id = cust_acct.cust_account_id
                                --AND cust_acct.cust_account_id  = cte.Customer_Id
                                  and cust_acct.cust_account_id in (select distinct cte.customer_id
                                                                      from apps.xxar_bots_tbl_customers_mails cte
                                                                     where 1 = 1
                                                                    union
                                                                    select distinct cte.customer_id
                                                                      from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                                                     where 1 = 1)
                                  AND cust_acct.party_id = party.party_id
                                  AND cp_cust.site_use_id IS NULL
                                  AND cp_cust.collector_id = col.collector_id
                                  AND cp_cust.account_status = status.lookup_code(+)
                                  AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
                                  AND EXISTS (SELECT 'x'
                                                FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
                                               WHERE (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
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
                      NULL,
					  ROUND (ps.amount_due_original * ps.exchange_rate,curr.precision),
                      ROUND (ps.amount_due_original * ps.exchange_rate / curr.minimum_accountable_unit) * curr.minimum_accountable_unit)) Original_Amount,
                      ps.acctd_amount_due_remaining Balance_Due,
                      logr.uuid,
                      logr.estatus,
                      logr.DESCRIPCION_ESTATUS,
                      logr.ACCESO_DOCTO,
                      logr.url,
                      DECODE(null,null,'1',ctt.NAME) orden,
					  rct.attribute7 remision,
                      rct.attribute8 no_recibo,
                      CASE
                           WHEN INSTR(rct.attribute9,'JAN') > 0 THEN replace(rct.attribute9,'JAN','ENE')
                           WHEN INSTR(rct.attribute9,'APR') > 0 THEN replace(rct.attribute9,'APR','ABR')
                           WHEN INSTR(rct.attribute9,'AUG') > 0 THEN replace(rct.attribute9,'AUG','AGO')
                           WHEN INSTR(rct.attribute9,'DEC') > 0 THEN replace(rct.attribute9,'DEC','DIC')
                           ELSE rct.attribute9
                      END fecha_recibo,
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
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, -9999, 0, ps.due_date, NULL, sysdate) b0
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1, 30, ps.due_date, NULL, sysdate) b1
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 31, 60, ps.due_date, NULL, sysdate) b2
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 61, 90, ps.due_date, NULL, sysdate) b3
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 91, 120, ps.due_date, NULL, sysdate) b4
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 121, 180, ps.due_date, NULL, sysdate) b5
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 181, 210, ps.due_date, NULL, sysdate) b6
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 211, 240, ps.due_date, NULL, sysdate) b7
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 241, 270, ps.due_date, NULL, sysdate) b8
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 271, 300, ps.due_date, NULL, sysdate) b9
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 301, 330, ps.due_date, NULL, sysdate) b10
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 331, 360, ps.due_date, NULL, sysdate) b11
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 361, 540, ps.due_date, NULL, sysdate) b12
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 541, 720, ps.due_date, NULL, sysdate) b13
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 721, 900, ps.due_date, NULL, sysdate) b14
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 901, 1080, ps.due_date, NULL, sysdate) b15
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1081, 1260, ps.due_date, NULL, sysdate) b16
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1261, 1440, ps.due_date, NULL, sysdate) b17
                     ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1441, 9999, ps.due_date, NULL, sysdate) b18
                     ,2
                     ,ps.last_update_date
                     ,RCT.ORG_ID
                     ,units.name
                     ,null
                     ,null
                     ,null
                     ,null
                     ,null
                     ,LOGR.SISTEMA_DESTINO
                     ,NULL
                     ,NULL
                     ,NULL
                     ,NULL
                     ,NULL
                     ,NULL
                     ,NULL
                     ,NULL
                     ,NULL
                     ,ps.tax_original
                     ,NULL
                     ,rct.ATTRIBUTE6
                     ,NULL
                     ,GET_TAX_BASE(0,ps.CUSTOMER_TRX_ID)
                     ,GET_TAX_BASE(8,ps.CUSTOMER_TRX_ID)
                     ,GET_TAX_BASE(16,ps.CUSTOMER_TRX_ID)
                     ,GET_SUC_GLN ('SUC',m.number_a,RCT.ORG_ID,c.cm_addr)
                     ,GET_SUC_GLN ('GLN',m.number_a,RCT.ORG_ID,c.cm_addr)
                     ,sysdate creation_date_prc
                     ,sysdate last_update_date_prc
                     ,(select B.STATUS_DESC
                         from xx_apex.XXAR_GRPCBZ_DCOMM_TBL@OCIPROD_TO_ORAPROD19 a,
                              xx_apex.XXAR_GRPCBZ_STATUS_TBL@OCIPROD_TO_ORAPROD19 b
                        where 1 = 1
                          and b.source_type='D'
                          and a.status=b.status
                          AND ps.CUSTOMER_TRX_ID=A.CUSTOMER_TRX_ID
                          and rownum<=1) AS MESSAGE
                     ,(select SCHEDULED_DATE
                         from xx_apex.XXAR_GRPCBZ_DCOMM_TBL@OCIPROD_TO_ORAPROD19 a,
                              xx_apex.XXAR_GRPCBZ_STATUS_TBL@OCIPROD_TO_ORAPROD19 b
                        where 1 = 1
                          and b.source_type='D'
                          and a.status=b.status
                          AND ps.CUSTOMER_TRX_ID=A.CUSTOMER_TRX_ID
                          and rownum <= 1) AS SCHEDULED_DATE
                     ,c.nombre_site as direccion_envio
                     ,(select distinct (a.CONTACT_NUMBER)
                         from apps.AR_CONTACTS_V a
                             ,apps.HZ_CONTACT_FIND_V b
                             ,apps.ar_customers d
                             ,apps.hz_parties f
                             ,apps.hz_cust_accounts g
                             ,xxwebc.xxar_bots_tbl_cust_mails_cs h
                        where 1 = 1
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
                          AND d.CUSTOMER_number=m.number_a)
                     ,NULL
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
                WHERE 1 = 1
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

        vProgreso := '0.5';

        insert into xxwebc.control_edo_cta (estatus,fecha) values (1,sysdate);
        commit;

        vProgreso := '1.1';

        -- actualizo GRUPO DE SEGURIDAD --
        BEGIN
            FOR CUR IN (select a.NAME_GRPSEG,b.contact_number  --into V_GS
                          from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a,
                               XXAR_GRPCBZ_GRPSEGN2_TBL@OCIPROD_TO_ORAPROD19 b
                         where 1 = 1
                           and a.ID_GSN1=b.ID_GSN1
                           and a.ENABLED_FLAG=b.ENABLED_FLAG
                           and a.ENABLED_FLAG='Y'
                           AND SYSDATE BETWEEN a.start_date
                           AND NVL (a.end_date,SYSDATE + 1)
                           and b.contact_number IN (select DISTINCT G_D_COBRANZA
                                                      from xxbot.xxar_bots_edo_cta_tt
                                                     WHERE 1 = 1
                                                       AND G_D_COBRANZA IS NOT NULL))
            LOOP
                UPDATE xxbot.xxar_bots_edo_cta_tt
                   SET G_D_SEGURIDAD=CUR.NAME_GRPSEG
                 WHERE 1 = 1
                   AND G_D_COBRANZA=CUR.contact_number;
            END LOOP;
			COMMIT;
        END;

        vProgreso := '1.2';

        -- valido las transacciones que NO existen en la nueva ejecució, dado que ya se han pagado. --
        update xxbot.xxar_bots_edo_cta a
           set (balance_due,last_update_date, last_update_date_prc) = (select b.amount_due_remaining,b.last_update_date, sysdate
                                                                         from apps.AR_PAYMENT_SCHEDULES_ALL b
                                                                        where 1 = 1
                                                                          and A.CUSTOMER_TRX_ID=b.customer_trx_id)
         where 1 = 1
           and a.Balance_Due <> 0
           and a.CUSTOMER_TRX_ID NOT IN (select b.customer_trx_id
                                           from xxbot.xxar_bots_edo_cta_tt a,
                                                xxbot.xxar_bots_edo_cta b
                                          where 1 = 1
                                            and b.customer_trx_id=a.customer_trx_id);

        commit;
        --
        vProgreso := '1.3';

        BEGIN
            FOR CUR IN(select *
                         from xxbot.xxar_bots_edo_cta_tt
                        WHERE 1 = 1
                          AND G_D_COBRANZA IS NOT NULL)
            LOOP
                UPDATE xxbot.xxar_bots_edo_cta
                   SET G_D_SEGURIDAD   = CUR.G_D_SEGURIDAD,
                       G_D_COBRANZA    = CUR.G_D_COBRANZA
                       ,last_update_date_prc=sysdate -- cedc 20-03-2026
                 WHERE 1 = 1
                   AND CUSTOMER_TRX_ID = CUR.CUSTOMER_TRX_ID;
            END LOOP;
            COMMIT;
        END;
        --
        vProgreso := '1.4';
        insert into xxwebc.control_edo_cta (estatus,fecha) values (2,sysdate);
        commit;

        vProgreso := '2.1';
        -- actualizo recibo --
        update xxbot.xxar_bots_edo_cta a
           set (a.no_recibo,a.last_update_date_prc) = (select b.attribute8,sysdate
                                                         from ar.ra_customer_trx_all b
                                                        where 1 = 1
                                                          and A.CUSTOMER_TRX_ID=b.customer_trx_id)
         where 1 = 1
           and a.Balance_Due <> 0
           and a.no_recibo <> (select b.attribute8
                                 from ar.ra_customer_trx_all b
                                where 1=1
                                  and A.CUSTOMER_TRX_ID=b.customer_trx_id)
           and a.CUSTOMER_TRX_ID NOT IN (select b.customer_trx_id
                                           from xxbot.xxar_bots_edo_cta_tt a,
                                                xxbot.xxar_bots_edo_cta b
                                          where 1 = 1
                                            and b.customer_trx_id=a.customer_trx_id);
        commit;
        vProgreso := '2.2';

        -- actualizo attribute6 --
        update xxbot.xxar_bots_edo_cta a
           set (a.no_editado,a.last_update_date_prc)= (select b.attribute6,sysdate
                                                         from ar.ra_customer_trx_all b
                                                        where 1=1
                                                          and A.CUSTOMER_TRX_ID=b.customer_trx_id)
         where 1 = 1
           and a.Balance_Due <> 0
           and a.no_editado  <> (select b.attribute6
                                   from ar.ra_customer_trx_all b
                                  where 1=1
                                     and A.CUSTOMER_TRX_ID=b.customer_trx_id);
        commit;
        vProgreso := '2.3';

        insert into xxwebc.control_edo_cta (estatus,fecha) values (3,sysdate);
        commit;

        -- ACTUALIZO CLIENTE --
        vProgreso := '3.1';
        UPDATE xxbot.xxar_bots_edo_cta B
           SET (B.CLIENT,b.last_update_date_prc) = (SELECT A.CLIENT ,sysdate
                                                      FROM apps.xxar_bots_tbl_customers_mails A
                                                     WHERE 1=1
                                                       AND B.NUMBER_A=A.CUSTOMER_NUMBER)
         WHERE 1=1
           AND B.CLIENT <> (SELECT A.CLIENT
                              FROM apps.xxar_bots_tbl_customers_mails A
                             WHERE 1=1
                               AND B.NUMBER_A=A.CUSTOMER_NUMBER)
           and b.CUSTOMER_TRX_ID NOT IN (select b.customer_trx_id
                                           from xxbot.xxar_bots_edo_cta_tt a,
                                                xxbot.xxar_bots_edo_cta b
                                          where 1=1
                                            and b.customer_trx_id=a.customer_trx_id);
        COMMIT;
        vProgreso := '3.2';

        insert into xxwebc.control_edo_cta (estatus,fecha) values (4,sysdate);
        commit;

        vProgreso := '4.1';
        -- actualizo las trasnacciones que han sufrido cambios en los bloques. --

        MERGE INTO xxbot.xxar_bots_edo_cta M
        USING (select B0,B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,CUSTOMER_TRX_ID,last_update_date_prc
        from xxbot.xxar_bots_edo_cta_TT
        where 1=1)X
        ON (
        M.CUSTOMER_TRX_ID = X.CUSTOMER_TRX_ID
        )
        WHEN MATCHED THEN UPDATE SET
        m.last_update_date_prc=sysdate,--x.last_update_date_prc, -- cedc 20-03-2026
        M.B0=X.B0 ,
        M.B1=X.B1 ,
        M.B2=X.B2 ,
        M.B3=X.B3 ,
        M.B4=X.B4 ,
        M.B5=X.B5 ,
        M.B6=X.B6 ,
        M.B7=X.B7 ,
        M.B8=X.B8 ,
        M.B9=X.B9 ,
        M.B10=X.B10 ,
        M.B11=X.B11 ,
        M.B12=X.B12 ,
        M.B13=X.B13 ,
        M.B14=X.B14 ,
        M.B15=X.B15 ,
        M.B16=X.B16 ,
        M.B17=X.B17 ,
        M.B18=X.B18
        WHERE 1=1
        AND
        M.B0<>X.B0 OR
        M.B1<>X.B1 OR
        M.B2<>X.B2 OR
        M.B3<>X.B3 OR
        M.B4<>X.B4 OR
        M.B5<>X.B5 OR
        M.B6<>X.B6 OR
        M.B7<>X.B7 OR
        M.B8<>X.B8 OR
        M.B9<>X.B9 OR
        M.B10<>X.B10 OR
        M.B11<>X.B11 OR
        M.B12<>X.B12 OR
        M.B13<>X.B13 OR
        M.B14<>X.B14 OR
        M.B15<>X.B15 OR
        M.B16<>X.B16 OR
        M.B17<>X.B17  OR
        M.B18<>X.B18 ;
        commit;
        vProgreso := '4.2';

        insert into xxwebc.control_edo_cta (estatus,fecha) values (5,sysdate);
        commit;
        vProgreso := '5.1';
        MERGE INTO xxbot.xxar_bots_edo_cta M
        USING (select uuid, estatus, DESCRIPCION_ESTATUS, ACCESO_DOCTO, url,SISTEMA_DESTINO, customer_trx_id,numero_docto,sysdate as last_update_date_prc
        from AR.CUST_AR_FACTELEC_LOG
        where 1=1
        AND ORG_ID=P_ORG_ID)X
        ON (
        M.CUSTOMER_TRX_ID = X.CUSTOMER_TRX_ID and m.number_b=x.numero_docto
        )
        WHEN MATCHED THEN UPDATE SET
        m.last_update_date_prc=sysdate,--x.last_update_date_prc, -- cedc 20-03-2026
        M.uuid=X.uuid ,
        M.estatus=X.estatus ,
        M.DESCRIPCION_ESTATUS=X.DESCRIPCION_ESTATUS ,
        M.ACCESO_DOCTO=X.ACCESO_DOCTO ,
        M.url=X.url ,
        M.SISTEMA_DESTINO=X.SISTEMA_DESTINO;
        commit;
        vProgreso := '5.2';

        insert into xxwebc.control_edo_cta (estatus,fecha) values (6,sysdate);
        commit;
        vProgreso := '6.1';

        -- actualizo las trasnacciones que han sufrido cambios en montos.--
        BEGIN
            for CUR  IN (select A.*
                           from xxbot.xxar_bots_edo_cta_tt a,
                                xxbot.xxar_bots_edo_cta b
                          where 1 = 1
                            and b.customer_trx_id=a.customer_trx_id
                            and a.balance_due<>b.balance_due
                            AND B.ORG_ID =p_org_id)
            LOOP
                update xxbot.xxar_bots_edo_cta a
                   set a.LAST_UPDATE_DATE_PRC = sysdate,
                       a.balance_due          = nvl(cur.balance_due,a.balance_due),
                       a.uuid                 = cur.uuid,
                       a.estatus              = cur.estatus,
                       a.descripcion_estatus  = cur.descripcion_estatus,
                       a.url                  = cur.url,
                       a.B0                   = cur.B0,
                       a.B1                   = cur.B1,
                       a.B2                   = cur.B2,
                       a.B3                   = cur.B3,
                       a.B4                   = cur.B4,
                       a.B5                   = cur.B5,
                       a.B6                   = cur.B6,
                       a.B7                   = cur.B7,
                       a.B8                   = cur.B8,
                       a.B9                   = cur.B9,
                       a.B10                  = cur.B10,
                       a.B11                  = cur.B11,
                       a.B12                  = cur.B12,
                       a.B13                  = cur.B13,
                       a.B14                  = cur.B14,
                       a.B15                  = cur.B15,
                       a.B16                  = cur.B16,
                       a.B17                  = cur.B17,
                       a.B18                  = cur.B18,
                       a.G_D_COBRANZA         = cur.G_D_COBRANZA,
                       a.G_D_SEGURIDAD        = cur.G_D_SEGURIDAD,
                       a.last_update_date     = cur.last_update_date
                 where 1 = 1
                   and a.customer_trx_id = cur.customer_trx_id;
                COMMIT;
            END LOOP;
        END;
        vProgreso := '6.2';

        insert into xxwebc.control_edo_cta (estatus,fecha) values (7,sysdate);
        commit;
        vProgreso := '7.1';

        -- ahora se insertan las nuevas lineas, --
        insert into xxbot.xxar_bots_edo_cta a (select *
                                                 from xxbot.xxar_bots_edo_cta_tt b
                                                where 1=1
                                                  and b.customer_trx_id not in (select b.customer_trx_id
                                                                                  from xxbot.xxar_bots_edo_cta a,
                                                                                       xxbot.xxar_bots_edo_cta_tt b
                                                                                 where 1=1
                                                                                   and a.customer_trx_id=b.customer_trx_id));
        vProgreso := '7.2';

        insert into xxwebc.control_edo_cta (estatus,fecha) values (8,sysdate);
        commit;

        vProgreso := '8.1';

		BEGIN
            for cur in (select distinct number_a
                          from xxbot.xxar_bots_edo_cta
                         where 1 = 1
                           and send_mail is null)
            loop
                V_COUNT:=NULL;
                vProgreso := '8.2';
                select count(*)
		    	  into v_count
                  from apps.xxar_bots_tbl_customers_mails
                 where 1 = 1
                   and customer_number = cur.number_a
                   and type_process    = 'SEND MAIL';

                if v_count >= 1 then
                    vProgreso := '8.3';
                    update xxbot.xxar_bots_edo_cta a
                       set a.send_mail            = 'NO ENVIADO'
                          ,a.last_update_date_prc = sysdate
                     where 1 = 1
                       AND send_mail is null
                       and a.number_a = cur.number_a;
                else
                    vProgreso := '8.4';
                    update xxbot.xxar_bots_edo_cta a
                       set a.send_mail = 'N/A'
                          ,a.last_update_date_prc = sysdate
                     where 1=1
                       AND send_mail is null
                       and a.number_a = cur.number_a;
                END IF;
                vProgreso := '8.5';
                COMMIT;
            END LOOP;
        END;
        vProgreso := '8.6';

        insert into xxwebc.control_edo_cta (estatus,fecha) values (9,sysdate);
        commit;
        vProgreso := '9.1';

        BEGIN
            for cur in (select distinct number_a
                          from xxbot.xxar_bots_edo_cta
                         where 1 = 1
                           and portal is null)
            loop
                V_COUNT := NULL;
                vProgreso := '9.2';
		    	select count (*)
		    	  into v_count
                  from apps.xxar_bots_tbl_customers_mails
                 where 1 = 1
                   and customer_number = cur.number_a
                   and type_process    = 'PORTAL';

                if v_count >= 1 then
                    vProgreso := '9.3';
                    update xxbot.xxar_bots_edo_cta a
                       set a.PORTAL = 'NO ENVIADO'
                          ,a.last_update_date_prc = sysdate
                     where 1 = 1
                       AND PORTAL is null
                       and a.number_a = cur.number_a;
                else
                    vProgreso := '9.4';
                    update xxbot.xxar_bots_edo_cta a
                       set a.PORTAL = 'N/A'
                          ,a.last_update_date_prc = sysdate
                     where 1 = 1
                       AND PORTAL is null
                       and a.number_a = cur.number_a;
                END IF;
                COMMIT;
                vProgreso := '9.5';
            END LOOP;
        END;
        vProgreso := '9.6';

        insert into xxwebc.control_edo_cta (estatus,fecha) values (10,sysdate);
        commit;
        vProgreso := '10.1';

        BEGIN
            for cur in (select distinct (customer_number),client
                          from apps.xxar_bots_tbl_customers_mails
                         where 1 = 1
                           and client is not null)
            loop
                vProgreso := '10.2';
                update xxbot.xxar_bots_edo_cta a
                   set a.client = cur.client
                      ,a.last_update_date_prc = sysdate
                 where 1=1
                   AND client is null
                   and a.number_a = cur.customer_number;
                COMMIT;
            END LOOP;
            vProgreso := '10.3';
        END;

        insert into xxwebc.control_edo_cta (estatus,fecha) values (11,sysdate);
        commit;

        vProgreso := '11.1';
        update xxbot.xxar_bots_edo_cta a
           set (A.CEDIS,A.REGION,A.NUD,A.last_update_date_prc)= (select b.CEDIS,b.REGION,B.TERMINAL, sysdate -- cedc 20-03-2026
                                                                    from XXBOT.XXAR_BOTS_SENDEROS_CATALOG b
                                                                where 1=1
                                                                    and A.REFERENCIA_DIRECCION=TO_CHAR (b.REFERENCIA))
          where 1 = 1
            and number_a in (select distinct(to_char(b.cadena))
                               from XXBOT.XXAR_BOTS_SENDEROS_CATALOG b
                              where 1=1 )
            and cedis  is null
            and region is null
            and nud    is null
            and org_id  = p_org_id;
        commit;

        -- actualizo ejecutivo --
        vProgreso := '11.2';
        update xxar_bots_edo_cta a
           set (a.ejecutivo,a.last_update_date_prc)=(select attribute15,sysdate
                                                       from apps.ar_customers b
                                                      where 1 = 1
                                                        and a.customer_id = b.customer_id)
         where 1 = 1
           and a.Balance_Due <>0
           AND A.ORG_ID=p_org_id;
        commit;

        -- actualizo NOTAS --
        vProgreso := '11.3';
        BEGIN
            for cur in (select b.customer_trx_id,C.STATUS_DESC,B.SCHEDULED_DATE
                          from xx_apex.XXAR_GRPCBZ_DCOMM_TBL@OCIPROD_TO_ORAPROD19 B,
                               xx_apex.XXAR_GRPCBZ_STATUS_TBL@OCIPROD_TO_ORAPROD19 C
                         where 1 = 1
                           and C.source_type = 'D'
                           and B.status      = C.status)
            loop
                vProgreso := '11.4';
                update xxar_bots_edo_cta a
                   set a.MESSAGE=cur.STATUS_DESC,
                       a.SCHEDULED_DATE=cur.SCHEDULED_DATE,
                       a.last_update_date_prc= sysdate
                 where 1 = 1
                   and a.customer_trx_id=cur.customer_trx_id;
                COMMIT;
            END LOOP;
            vProgreso := '11.5';
        END;

        insert into xxwebc.control_edo_cta (estatus,fecha) values (12,sysdate);
        commit;

        vProgreso := '12.1';
        BEGIN
            for cur in (select *
                          from xxbot.xxar_bots_edo_cta a
                         where 1 = 1
                           and A.client       = 'COSTCO'
                           AND ORG_ID        IN (180,84)
                           AND A.BALANCE_DUE <> 0
                           AND A.CUSTOMER_TRX_ID NOT IN (SELECT CUSTOMER_TRX_ID
                                                           FROM XXBOT.XXAR_BOTS_TRX_COSTCO
                                                          WHERE 1 = 1))
            loop
                vProgreso := '12.2';
                INSERT INTO XXBOT.XXAR_BOTS_TRX_COSTCO
				            (CUSTOMER_TRX_ID     , ORDEN_DE_COMPRA     , STATUS_BOT          ,
                             CREATION_DATE       , CREATED_BY          , LAST_UPDATE_DATE    ,
                             LAST_UPDATE_BY      )
                     VALUES (CUR.CUSTOMER_TRX_ID , CUR.PURCHASE_ORDER  , null                ,
                             SYSDATE             , -1                  , SYSDATE             ,
                             -1                  );
                COMMIT;
            END LOOP;
            vProgreso := '12.3';
        END;

        insert into xxwebc.control_edo_cta (estatus,fecha) values (13,sysdate);
        commit;
        vProgreso := '13.1';

--      begin
--          XXAR_BOTS_ESTADO_D_CTA_CS (P_ORG_ID);
--      end;
--      commit;

        BEGIN
            for cur in (SELECT A.ATTRIBUTE15,A.CUSTOMER_TRX_ID
                          FROM XXBOT.xxar_bots_edo_cta B, AR.RA_CUSTOMER_TRX_ALL A
                         WHERE 1 = 1
                           AND A.CUSTOMER_TRX_ID=B.CUSTOMER_TRX_ID
                           and a.attribute15 is not null
                           AND B.PORTAL='ENV-PAC'
                           AND B.CLIENT in ('VIPS','DOMINOS')
                           AND B.TRX_DATE >=(SELECT TO_DATE(PATH_DIR,'DD-MM-YYYY')
                                               FROM XXBOT.XXAR_BOTS_PATH
											  WHERE USERNAME = 'ALSEA'
                                                AND PATH_TYPE='PARAMFECHALECTURA')
                                              --AND B.ESTATUS_USUARIO ='ENCONTRADO'
                       )
            loop
                vProgreso := '13.2';
                UPDATE XXBOT.xxar_bots_edo_cta
                   SET PORTAL=CUR.ATTRIBUTE15
                      ,last_update_date_prc = sysdate
                 WHERE 1 = 1
                   AND CUSTOMER_TRX_ID=CUR.CUSTOMER_TRX_ID;
                COMMIT;
            END LOOP;
            COMMIT;
            vProgreso := '13.3';
        END;

        insert into xxwebc.control_edo_cta (estatus,fecha) values (14,sysdate);
        COMMIT;

        -- Se llama proceso para sincronizar BD eBS vs BD Apex
        vProgreso := '14.1';
        SYNC_UP_EBS_VS_BDAPEX(P_ORG_ID,TRUNC(SYSDATE-1));
        vProgreso := '14.2';

        --SE ACTUALIZAN LAS VM DEL EDO CTA APEX
        begin
            XX_APEX.XXGEPP_UPDATE_VM@OCIPROD_TO_ORAPROD19 (v_msg);
            apps.MESSAGE_LOG (v_msg);
        end;
        vProgreso := '14.3';

        insert into xxwebc.control_edo_cta (estatus,fecha) values (15,sysdate);

        vProgreso := '15.1';
        apps.MESSAGE_LOG('PROCESO TERMINO EXITOSAMENTE  '||SYSDATE||CHR(10));
        DBMS_OUTPUT.PUT_LINE('PROCESO TERMINO EXITOSAMENTE  '||SYSDATE||CHR(10));
        vProgreso := '15.2';
        COMMIT;
        -- return true;
    EXCEPTION
        WHEN OTHERS THEN
            apps.MESSAGE_LOG ('2. ' || vProgreso || 'ERR - EXC EN PROCESO DE ESTADO DE CUENTA '||SQLERRM||CHR(10));
            DBMS_OUTPUT.PUT_LINE('2. ' || vProgreso || 'ERR - EXC EN PROCESO DE ESTADO DE CUENTA '||SQLERRM);
            -- return false;
    END XXAR_BOTS_ESTADO_D_CTA_BD;


    PROCEDURE XXAR_BOTS_ESTADO_D_CTA_CS (P_ORG_ID IN number)
    IS
        V_COUNT    NUMBER         := 0;
        v_msg      VARCHAR2(4000) := NULL;
		vProgreso  VARCHAR2(5)    := NULL;
    begin
        begin
            apps.mo_global.set_policy_context('S', P_ORG_ID);
            DBMS_OUTPUT.PUT_LINE('OK_cias_84');
        exception
            when others then
                apps.mo_global.set_policy_context('S', P_ORG_ID);
                DBMS_OUTPUT.PUT_LINE('no ok cias 84');
        end;
        vProgreso := '0.1';
        begin
            EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE =  "AMERICAN" ';
            DBMS_OUTPUT.PUT_LINE('OK');
        EXCEPTION
		    WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('FALLA '||SQLERRM);
        end;
        vProgreso := '0.2';
        delete xxwebc.control_edo_cta_cs;
        delete xxbot.xxar_bots_edo_cta_cs;
        commit;
        vProgreso := '0.3';
        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (0,sysdate);
        commit;

        vProgreso := '0.4';
        INSERT INTO  xxbot.xxar_bots_edo_cta_tt_cs
               WITH q_setup as (SELECT sob.name   Company_Name,
                                       sob.chart_of_accounts_id   coa_id,
                                       sob.currency_code   Functional_Currency,
                                       cur.precision      Functional_Currency_Precision
                                  FROM apps.gl_sets_of_books sob,
                                       apps.AR_SYSTEM_PARAMETERS param,
                                       apps.fnd_currencies cur
                                 WHERE sob.set_of_books_id = param.set_of_books_id
                                   AND sob.currency_code = cur.currency_code)
                   ,q_main as (SELECT status.meaning status,
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
                                     ,xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                WHERE 1=1
                                --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                                  and acct_site.cust_account_id = cust_acct.cust_account_id
                                --AND cust_acct.cust_account_id  = cte.Customer_Id
                                  and cust_acct.cust_account_id in (select distinct cte.customer_id
                                                                      from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                                                     where 1=1)
                                  AND cust_acct.party_id = party.party_id
                                  AND site_uses.cust_acct_site_id = acct_site.cust_acct_site_id
                                  AND site_uses.site_use_code = 'BILL_TO'
                                  AND cp_site.site_use_id(+) = site_uses.site_use_id
                                  AND cp_cust.cust_account_id = cust_acct.cust_account_id
                                  AND cp_cust.site_use_id IS NULL
                                  AND col.collector_id = NVL (cp_site.collector_id, cp_cust.collector_id)
                                  AND DECODE (cp_site.collector_id, NULL, cp_cust.account_status, cp_site.account_status) = status.lookup_code
                                  AND status.lookup_type = 'ACCOUNT_STATUS'
                                  AND EXISTS (SELECT 'x'
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
                                     ,xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                WHERE 1 = 1
                                --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                                  and acct_site.cust_account_id = cust_acct.cust_account_id
                                --AND cust_acct.cust_account_id  = cte.Customer_Id
                                  and cust_acct.cust_account_id in (select distinct cte.customer_id
                                                                      from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                                                     where 1=1)
                                  AND cust_acct.party_id = party.party_id
                                  AND site_uses.cust_acct_site_id = acct_site.cust_acct_site_id
                                  AND site_uses.site_use_code = 'BILL_TO'
                                  AND cp_site.site_use_id(+) = site_uses.site_use_id
                                  AND cp_cust.cust_account_id = cust_acct.cust_account_id
                                  AND cp_cust.site_use_id IS NULL
                                  AND col.collector_id = NVL (cp_site.collector_id, cp_cust.collector_id)
                                  AND cp_site.collector_id IS NULL
                                  AND cp_cust.account_status = status.lookup_code(+)
                                  AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
                                  AND EXISTS (SELECT 'x'
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
                                  -- ,cte.type_process
                                 FROM apps.ar_lookups status,
                                      apps.ar_collectors col,
                                      apps.hz_customer_profiles cp_cust,
                                      apps.hz_customer_profiles cp_site,
                                      apps.hz_cust_accounts cust_acct,
                                      apps.hz_parties party,
                                      apps.hz_cust_site_uses site_uses,
                                      apps.hz_cust_acct_sites acct_site
                                     ,xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                WHERE 1 = 1
                                --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                                  and acct_site.cust_account_id = cust_acct.cust_account_id
                                --AND cust_acct.cust_account_id  = cte.Customer_Id
                                  and cust_acct.cust_account_id in (select distinct cte.customer_id
                                                                      from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                                                     where 1=1)
                                  AND cust_acct.party_id = party.party_id
                                  AND site_uses.cust_acct_site_id = acct_site.cust_acct_site_id
                                  AND site_uses.site_use_code = 'BILL_TO'
                                  AND cp_site.site_use_id(+) = site_uses.site_use_id
                                  AND cp_cust.cust_account_id = cust_acct.cust_account_id
                                  AND cp_cust.site_use_id IS NULL
                                  AND col.collector_id = NVL (cp_site.collector_id, cp_cust.collector_id)
                                  AND cp_site.collector_id IS NOT NULL
                                  AND cp_site.account_status = status.lookup_code(+)
                                  AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
                                  AND EXISTS (SELECT 'x'
                                                FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
                                               WHERE (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
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
                                     ,xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                WHERE 1=1
                                --and cte.type_process in ('SEND MAIL','PORTAL','CSAR','DELAY','PREVALIDACION')
                                  and cp_cust.cust_account_id = cust_acct.cust_account_id
                                --AND cust_acct.cust_account_id  = cte.Customer_Id
                                  and cust_acct.cust_account_id in (select distinct cte.customer_id
                                                                      from xxwebc.xxar_bots_tbl_cust_mails_cs cte
                                                                     where 1=1)
                                  AND cust_acct.party_id = party.party_id
                                  AND cp_cust.site_use_id IS NULL
                                  AND cp_cust.collector_id = col.collector_id
                                  AND cp_cust.account_status = status.lookup_code(+)
                                  AND NVL (status.lookup_type, 'ACCOUNT_STATUS') = 'ACCOUNT_STATUS'
                                  AND EXISTS (SELECT 'x'
                                                FROM apps.AR_PAYMENT_SCHEDULES_ALL ps
                                               WHERE (ps.status = 'OP' and abs(ps.amount_due_remaining) >= 1.00)
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
                           DECODE (ps.invoice_currency_code, s.Functional_Currency, ps.amount_due_original,
                                                                                    DECODE(curr.minimum_accountable_unit, NULL, ROUND(ps.amount_due_original * ps.exchange_rate,curr.precision),
                           ROUND (ps.amount_due_original * ps.exchange_rate / curr.minimum_accountable_unit) * curr.minimum_accountable_unit)) Original_Amount,
                           ps.acctd_amount_due_remaining Balance_Due,
                           logr.uuid,
                           logr.estatus,
                           logr.DESCRIPCION_ESTATUS,
                           logr.ACCESO_DOCTO,
                           logr.url,
                           DECODE(null,null,'1',ctt.NAME) orden,
                           rct.attribute7 remision,
                           rct.attribute8 no_recibo,
                           CASE
                               WHEN INSTR(rct.attribute9,'JAN') > 0 THEN replace(rct.attribute9,'JAN','ENE')
                               WHEN INSTR(rct.attribute9,'APR') > 0 THEN replace(rct.attribute9,'APR','ABR')
                               WHEN INSTR(rct.attribute9,'AUG') > 0 THEN replace(rct.attribute9,'AUG','AGO')
                               WHEN INSTR(rct.attribute9,'DEC') > 0 THEN replace(rct.attribute9,'DEC','DIC')
                               ELSE rct.attribute9
                           END fecha_recibo,
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
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, -9999, 0, ps.due_date, NULL, sysdate) b0
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1, 30, ps.due_date, NULL, sysdate) b1
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 31, 60, ps.due_date, NULL, sysdate) b2
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 61, 90, ps.due_date, NULL, sysdate) b3
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 91, 120, ps.due_date, NULL, sysdate) b4
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 121, 180, ps.due_date, NULL, sysdate) b5
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 181, 210, ps.due_date, NULL, sysdate) b6
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 211, 240, ps.due_date, NULL, sysdate) b7
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 241, 270, ps.due_date, NULL, sysdate) b8
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 271, 300, ps.due_date, NULL, sysdate) b9
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 301, 330, ps.due_date, NULL, sysdate) b10
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 331, 360, ps.due_date, NULL, sysdate) b11
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 361, 540, ps.due_date, NULL, sysdate) b12
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 541, 720, ps.due_date, NULL, sysdate) b13
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 721, 900, ps.due_date, NULL, sysdate) b14
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 901, 1080, ps.due_date, NULL, sysdate) b15
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1081, 1260, ps.due_date, NULL, sysdate) b16
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1261, 1440, ps.due_date, NULL, sysdate) b17
                          ,apps.arpt_sql_func_util.bucket_function('PAST', dh.amount_in_dispute, ps.amount_adjusted_pending, 1441, 9999, ps.due_date, NULL, sysdate) b18
                          ,2
                          ,ps.last_update_date
                          ,RCT.ORG_ID
                          ,units.name
                          ,null
                          ,null
                          ,null
                          ,null
                          ,null
                          ,LOGR.SISTEMA_DESTINO
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,NULL
                          ,ps.tax_original
                          ,NULL
                          ,rct.ATTRIBUTE6
                          ,null
                          ,GET_TAX_BASE(0,ps.CUSTOMER_TRX_ID)
                          ,GET_TAX_BASE(8,ps.CUSTOMER_TRX_ID)
                          ,GET_TAX_BASE(16,ps.CUSTOMER_TRX_ID)
                          ,GET_SUC_GLN ('SUC',m.number_a,RCT.ORG_ID,c.cm_addr)
                          ,GET_SUC_GLN ('GLN',m.number_a,RCT.ORG_ID,c.cm_addr)
                          ,sysdate creation_date_prc
                          ,sysdate last_update_date_prc
                          ,(select B.STATUS_DESC
                              from xx_apex.XXAR_GRPCBZ_DCOMM_TBL@OCIPROD_TO_ORAPROD19 a,
                                   xx_apex.XXAR_GRPCBZ_STATUS_TBL@OCIPROD_TO_ORAPROD19 b
                             where 1=1
                               and b.source_type='D'
                               and a.status=b.status
                               AND ps.CUSTOMER_TRX_ID=A.CUSTOMER_TRX_ID
                               and rownum <= 1) AS MESSAGE
                          ,(select SCHEDULED_DATE
                              from xx_apex.XXAR_GRPCBZ_DCOMM_TBL@OCIPROD_TO_ORAPROD19 a,xx_apex.XXAR_GRPCBZ_STATUS_TBL@OCIPROD_TO_ORAPROD19 b
                             where 1=1
                               and b.source_type='D'
                               and a.status=b.status
                               AND ps.CUSTOMER_TRX_ID=A.CUSTOMER_TRX_ID
                               and rownum <= 1) AS SCHEDULED_DATE
                          ,c.nombre_site as direccion_envio
                          ,(select distinct (a.CONTACT_NUMBER)
                              from apps.AR_CONTACTS_V a
                                  ,apps.HZ_CONTACT_FIND_V b
                                  ,apps.ar_customers d
                                  ,apps.hz_parties f
                                  ,apps.hz_cust_accounts g
                                  ,xxwebc.xxar_bots_tbl_cust_mails_cs h
                             where 1=1
                               and d.customer_id       = b.customer_id
                               and a.customer_id       = d.customer_id
                               and a.CONTACT_NUMBER    = b.CONTACT_NUMBER
                               and a.customer_id       = b.customer_id
                               and d.customer_id       = h.customer_id
                               and a.customer_id       = h.customer_id
                               and b.customer_id       = h.customer_id
                               AND g.cust_account_id   = d.customer_id
                               AND g.party_id          = F.party_id
                               and b.CONTACT_NUMBER like 'EC-%'
                               and a.CONTACT_NUMBER like 'EC-%'
                               AND B.STATUS            = 'A'
                               AND a.STATUS            = 'A'
                               AND d.CUSTOMER_number   = m.number_a)
                          ,NULL
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
                     WHERE 1 = 1
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

        vProgreso := '0.5';
        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (1,sysdate);
        commit;

		-- actualizo GRUPO DE SEGURIDAD --
        vProgreso := '1.1';
        BEGIN
            FOR CUR IN(select a.NAME_GRPSEG,b.contact_number  --into V_GS
                         from XXAR_GRPCBZ_GRPSEGN1_TBL@OCIPROD_TO_ORAPROD19 a,
                              XXAR_GRPCBZ_GRPSEGN2_TBL@OCIPROD_TO_ORAPROD19 b
                        where 1 = 1
                          and a.ID_GSN1=b.ID_GSN1
                          and a.ENABLED_FLAG=b.ENABLED_FLAG
                          and a.ENABLED_FLAG='Y'
                          AND SYSDATE BETWEEN a.start_date
                          AND NVL (a.end_date,SYSDATE + 1)
                          and b.contact_number IN (select DISTINCT G_D_COBRANZA
                                                     from xxbot.xxar_bots_edo_cta_tt_cs
                                                    WHERE 1 = 1
                                                      AND G_D_COBRANZA IS NOT NULL))
            LOOP
                vProgreso := '1.2';
                UPDATE xxbot.xxar_bots_edo_cta_tt_cs
                   SET G_D_SEGURIDAD=CUR.NAME_GRPSEG
                 WHERE 1 = 1
                   AND G_D_COBRANZA=CUR.contact_number;
            END LOOP;
            COMMIT;
        END;

        -- valido las transacciones que NO existenen la nueva ejecució, dado que ya se han pagado.
        vProgreso := '1.3';
        update xxbot.xxar_bots_edo_cta_cs a
           set (balance_due,last_update_date, last_update_date_prc)= (select b.amount_due_remaining,b.last_update_date, sysdate
                                                                        from apps.AR_PAYMENT_SCHEDULES_ALL b
                                                                       where 1=1
                                                                         and A.CUSTOMER_TRX_ID=b.customer_trx_id)
         where 1=1
           and a.Balance_Due <>0
           and a.CUSTOMER_TRX_ID NOT IN (select b.customer_trx_id
                                           from xxbot.xxar_bots_edo_cta_tt_cs a,
                                                xxbot.xxar_bots_edo_cta_cs b
                                          where 1 = 1
                                            and b.customer_trx_id=a.customer_trx_id);

        commit;
        vProgreso := '1.4';

        BEGIN
            FOR CUR IN(select *
                         from xxbot.xxar_bots_edo_cta_tt_CS
                        WHERE 1=1
                          AND G_D_COBRANZA IS NOT NULL)
            LOOP
                UPDATE xxbot.xxar_bots_edo_cta_CS
                   SET G_D_SEGURIDAD=CUR.G_D_SEGURIDAD,
                       G_D_COBRANZA=CUR.G_D_COBRANZA
                        ,last_update_date_prc = sysdate -- cedc 20-03-2026
                 WHERE 1 = 1
                   AND CUSTOMER_TRX_ID=CUR.CUSTOMER_TRX_ID;
            END LOOP;
            COMMIT;
        END;

        vProgreso := '1.5';
        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (2,sysdate);
        commit;

        -- actualizo recibo --
        vProgreso := '2.1';
        update xxbot.xxar_bots_edo_cta_cs a
           set (a.no_recibo,last_update_date_prc)= (select b.attribute8, sysdate
                                                      from ar.ra_customer_trx_all b
                                                     where 1 = 1
                                                       and A.CUSTOMER_TRX_ID = b.customer_trx_id)
         where 1=1
           and a.Balance_Due <> 0
           and a.no_recibo <> (select b.attribute8
                                 from ar.ra_customer_trx_all b
                                where 1=1
                                  and A.CUSTOMER_TRX_ID=b.customer_trx_id)
           and a.CUSTOMER_TRX_ID NOT IN (select b.customer_trx_id
                                           from xxbot.xxar_bots_edo_cta_tt_cs a,
                                                xxbot.xxar_bots_edo_cta_cs b
                                          where 1 = 1
                                            and b.customer_trx_id=a.customer_trx_id);
        commit;

        --actualizo attribute6
        vProgreso := '2.2';
        update xxbot.xxar_bots_edo_cta_cs a
           set (a.no_editado,last_update_date_prc)= (select b.attribute6,sysdate
                                                       from ar.ra_customer_trx_all b
                                                      where 1=1
                                                        and A.CUSTOMER_TRX_ID=b.customer_trx_id)
         where 1=1
           and a.Balance_Due <> 0
           and a.no_editado  <> (select b.attribute6
                                   from ar.ra_customer_trx_all b
                                  where 1 = 1
                                    and A.CUSTOMER_TRX_ID=b.customer_trx_id);
        commit;
        vProgreso := '2.3';

        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (3,sysdate);
        commit;

        -- ACTUALIZO CLIENTE --
        vProgreso := '3.1';
        UPDATE xxbot.xxar_bots_edo_cta_cs B
           SET B.CLIENT= (SELECT A.CLIENT
                            FROM xxwebc.xxar_bots_tbl_cust_mails_cs A
                           WHERE 1=1
                             AND B.NUMBER_A=A.CUSTOMER_NUMBER)
              ,b.last_update_date_prc = sysdate
         WHERE 1=1
           AND B.CLIENT <> (SELECT A.CLIENT
                              FROM xxwebc.xxar_bots_tbl_cust_mails_cs A
                             WHERE 1=1
                               AND B.NUMBER_A=A.CUSTOMER_NUMBER)
           and b.CUSTOMER_TRX_ID NOT IN (select b.customer_trx_id
                                           from xxbot.xxar_bots_edo_cta_tt_cs a,
                                                xxbot.xxar_bots_edo_cta_cs b
                                          where 1 = 1
                                            and b.customer_trx_id=a.customer_trx_id);
        COMMIT;
        vProgreso := '3.2';

        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (4,sysdate);
        commit;

        --actualizo las trasnacciones que han sufrido cambios en los bloques.
        vProgreso := '4.1';
        MERGE INTO xxbot.xxar_bots_edo_cta_cs M
        USING (select B0,B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,CUSTOMER_TRX_ID
        from xxbot.xxar_bots_edo_cta_tt_cs
        where 1=1)X
        ON (
        M.CUSTOMER_TRX_ID = X.CUSTOMER_TRX_ID
        )
        WHEN MATCHED THEN UPDATE SET
        M.B0=X.B0 ,
        M.B1=X.B1 ,
        M.B2=X.B2 ,
        M.B3=X.B3 ,
        M.B4=X.B4 ,
        M.B5=X.B5 ,
        M.B6=X.B6 ,
        M.B7=X.B7 ,
        M.B8=X.B8 ,
        M.B9=X.B9 ,
        M.B10=X.B10 ,
        M.B11=X.B11 ,
        M.B12=X.B12 ,
        M.B13=X.B13 ,
        M.B14=X.B14 ,
        M.B15=X.B15 ,
        M.B16=X.B16 ,
        M.B17=X.B17 ,
        M.B18=X.B18
        ,m.last_update_date_prc = sysdate
        WHERE 1=1
        AND
        M.B0<>X.B0 OR
        M.B1<>X.B1 OR
        M.B2<>X.B2 OR
        M.B3<>X.B3 OR
        M.B4<>X.B4 OR
        M.B5<>X.B5 OR
        M.B6<>X.B6 OR
        M.B7<>X.B7 OR
        M.B8<>X.B8 OR
        M.B9<>X.B9 OR
        M.B10<>X.B10 OR
        M.B11<>X.B11 OR
        M.B12<>X.B12 OR
        M.B13<>X.B13 OR
        M.B14<>X.B14 OR
        M.B15<>X.B15 OR
        M.B16<>X.B16 OR
        M.B17<>X.B17  OR
        M.B18<>X.B18 ;
        commit;
        vProgreso := '4.2';

        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (5,sysdate);
        commit;

        vProgreso := '5.1';
        MERGE INTO xxbot.xxar_bots_edo_cta_cs M
        USING (select uuid, estatus, DESCRIPCION_ESTATUS, ACCESO_DOCTO, url,SISTEMA_DESTINO, customer_trx_id,numero_docto
        from AR.CUST_AR_FACTELEC_LOG
        where 1=1
        AND ORG_ID=P_ORG_ID)X
        ON (
        M.CUSTOMER_TRX_ID = X.CUSTOMER_TRX_ID and m.number_b=x.numero_docto
        )
        WHEN MATCHED THEN UPDATE SET
        M.uuid=X.uuid ,
        M.estatus=X.estatus ,
        M.DESCRIPCION_ESTATUS=X.DESCRIPCION_ESTATUS ,
        M.ACCESO_DOCTO=X.ACCESO_DOCTO ,
        M.url=X.url ,
        M.SISTEMA_DESTINO=X.SISTEMA_DESTINO
        ,m.last_update_date_prc= sysdate;
        commit;

        vProgreso := '5.2';
        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (6,sysdate);
        commit;


        --actualizo las trasnacciones que han sufrido cambios en montos.
        vProgreso := '6.1';
        BEGIN
            for CUR  IN (select A.*
                           from xxbot.xxar_bots_edo_cta_tt_cs a,
                                xxbot.xxar_bots_edo_cta_cs b
                          where 1 = 1
                            and b.customer_trx_id=a.customer_trx_id
                            and a.balance_due<>b.balance_due
                            AND B.ORG_ID IN (180,84))
            LOOP
                update xxbot.xxar_bots_edo_cta_cs a
                   set a.balance_due          = cur.balance_due,
                       a.uuid                 = cur.uuid,
                       a.estatus              = cur.estatus,
                       a.descripcion_estatus  = cur.descripcion_estatus,
                       a.url                  = cur.url,
                       a.B0                   = cur.B0,
                       a.B1                   = cur.B1,
                       a.B2                   = cur.B2,
                       a.B3                   = cur.B3,
                       a.B4                   = cur.B4,
                       a.B5                   = cur.B5,
                       a.B6                   = cur.B6,
                       a.B7                   = cur.B7,
                       a.B8                   = cur.B8,
                       a.B9                   = cur.B9,
                       a.B10                  = cur.B10,
                       a.B11                  = cur.B11,
                       a.B12                  = cur.B12,
                       a.B13                  = cur.B13,
                       a.B14                  = cur.B14,
                       a.B15                  = cur.B15,
                       a.B16                  = cur.B16,
                       a.B17                  = cur.B17,
                       a.B18                  = cur.B18,
                       a.G_D_COBRANZA         = cur.G_D_COBRANZA,
                       a.G_D_SEGURIDAD        = cur.G_D_SEGURIDAD,
                       a.last_update_date     = cur.last_update_date
                      ,a.last_update_date_prc = sysdate
                 where 1 = 1
                   and a.customer_trx_id      = cur.customer_trx_id;
                COMMIT;
            END LOOP;
        END;
        vProgreso := '6.2';

        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (7,sysdate);
        commit;

        --ahora se insertan las nuevas lineas,
        vProgreso := '7.1';
        insert into xxbot.xxar_bots_edo_cta_cs a (select *
                                                    from xxbot.xxar_bots_edo_cta_tt_cs b
                                                   where 1 = 1
                                                     and b.customer_trx_id not in (select b.customer_trx_id
                                                                                     from xxbot.xxar_bots_edo_cta_cs a,
                                                                                          xxbot.xxar_bots_edo_cta_tt_cs b
                                                                                    where 1 = 1
                                                                                      and a.customer_trx_id=b.customer_trx_id));

        vProgreso := '7.2';
        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (8,sysdate);
        commit;

        vProgreso := '8.1';
		BEGIN
            for cur in (select distinct number_a
                          from xxbot.xxar_bots_edo_cta_cs
                         where 1 = 1
                           and send_mail is null)
            loop
                V_COUNT:=NULL;

                vProgreso := '8.2';
                select count (*)
		    	  into v_count
                  from xxwebc.xxar_bots_tbl_cust_mails_cs
                 where 1=1
                   and customer_number =cur.number_a
                   and type_process='SEND MAIL' ;

                if v_count >= 1 then
                    vProgreso := '8.3';
                    update xxbot.xxar_bots_edo_cta_cs a
                       set a.send_mail = 'NO ENVIADO'
                          ,a.last_update_date_prc = sysdate
                     where 1=1
                       AND send_mail is null
                       and a.number_a = cur.number_a;
                else
                    vProgreso := '8.4';
                    update xxbot.xxar_bots_edo_cta_cs a
                       set a.send_mail = 'N/A'
                          ,a.last_update_date_prc = sysdate
                     where 1=1
                       AND send_mail is null
                       and a.number_a = cur.number_a;
                END IF;
                COMMIT;
            END LOOP;
        END;

        vProgreso := '8.5';
        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (9,sysdate);
        commit;

        vProgreso := '9.1';
        BEGIN
            for cur in (select distinct number_a
                          from xxbot.xxar_bots_edo_cta_cs
                         where 1=1
                           and portal is null)
            loop
                V_COUNT:=NULL;

                vProgreso := '9.2';
                select count (*) into v_count
                  from xxwebc.xxar_bots_tbl_cust_mails_cs
                 where 1=1
                   and customer_number =cur.number_a
                   and type_process='PORTAL' ;

                if v_count >= 1 then
                    vProgreso := '9.3';
                    update xxbot.xxar_bots_edo_cta_cs a
                       set a.PORTAL = 'NO ENVIADO'
                          ,a.last_update_date_prc = sysdate
                     where 1 = 1
                       AND PORTAL is null
                       and a.number_a = cur.number_a;
                else
                    vProgreso := '9.4';
                    update xxbot.xxar_bots_edo_cta_cs a
                       set a.PORTAL = 'N/A'
                          ,a.last_update_date_prc = sysdate
                     where 1 = 1
                       AND PORTAL is null
                       and a.number_a = cur.number_a;
                END IF;
                COMMIT;
            END LOOP;
        END;

        vProgreso := '9.5';
        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (10,sysdate);
        commit;

        vProgreso := '10.1';
        BEGIN
            for cur in (select distinct (customer_number),client
                          from xxwebc.xxar_bots_tbl_cust_mails_cs
                         where 1=1
                           and client is not null)
            loop
                vProgreso := '10.2';
                update xxbot.xxar_bots_edo_cta_cs a
                   set a.client = cur.client
                      ,a.last_update_date_prc = sysdate
                 where 1=1
                   AND client is null
                   and a.number_a = cur.customer_number;
                COMMIT;
            END LOOP;
        END;

		vProgreso := '10.3';
        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (11,sysdate);
        commit;

		vProgreso := '11.1';
        update xxbot.xxar_bots_edo_cta_cs a
           set (A.CEDIS,A.REGION,A.NUD,a.last_update_date_prc)= (select b.CEDIS,b.REGION,B.TERMINAL, sysdate
                                                                   from XXBOT.XXAR_BOTS_SENDEROS_CATALOG b
                                                                  where 1=1
                                                                    and A.REFERENCIA_DIRECCION=TO_CHAR (b.REFERENCIA))
         where 1=1
           and cedis is null
           and region is null
           and nud is null;
        commit;

        -- actualizo ejecutivo --
		vProgreso := '11.2';
        update xxar_bots_edo_cta a
           set ejecutivo = (select attribute15
                              from apps.ar_customers b
                             where 1=1
                               and a.customer_id=b.customer_id)
                ,a.last_update_date_prc = sysdate
         where 1 = 1;
        commit;

        -- actualizo NOTAS --
		vProgreso := '11.3';
        update xxar_bots_edo_cta a
           set (a.MESSAGE,a.SCHEDULED_DATE,a.last_update_date_prc)=(select C.STATUS_DESC,B.SCHEDULED_DATE,sysdate
                                                                      from xx_apex.XXAR_GRPCBZ_DCOMM_TBL@OCIPROD_TO_ORAPROD19 B,
                                                                           xx_apex.XXAR_GRPCBZ_STATUS_TBL@OCIPROD_TO_ORAPROD19 C
                                                                     where 1 = 1
                                                                       and C.source_type     = 'D'
                                                                       and B.status          = C.status
                                                                       AND B.CUSTOMER_TRX_ID = A.CUSTOMER_TRX_ID)
         where 1 = 1
           and a.Balance_Due <>0
           AND A.ORG_ID=P_ORG_ID;
        commit;

		vProgreso := '11.4';
        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (12,sysdate);
        commit;

		vProgreso := '12.1';
        BEGIN
            for cur in (select *
                          from xxbot.xxar_bots_edo_cta_cs a
                         where 1 = 1
                           and A.client           = 'COSTCO'
                           AND ORG_ID            IN (180,84)
                           AND A.BALANCE_DUE     <>0
                           AND A.CUSTOMER_TRX_ID NOT IN (SELECT CUSTOMER_TRX_ID
                                                           FROM XXBOT.XXAR_BOTS_TRX_COSTCO
                                                          WHERE 1 = 1))
            loop
                vProgreso := '12.2';
                INSERT INTO XXBOT.XXAR_BOTS_TRX_COSTCO
		    	            (CUSTOMER_TRX_ID     , ORDEN_DE_COMPRA     , STATUS_BOT          ,
                             CREATION_DATE       , CREATED_BY          , LAST_UPDATE_DATE    ,
                             LAST_UPDATE_BY      )
                     VALUES (CUR.CUSTOMER_TRX_ID , CUR.PURCHASE_ORDER  , null                ,
                             SYSDATE             , -1                  , SYSDATE             ,
                             -1                  );
                COMMIT;
            END LOOP;
        END;

        vProgreso := '12.3';
        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (13,sysdate);
        commit;

        vProgreso := '13.1';
        insert into xxbot.xxar_bots_edo_cta (select *
                                               from xxbot.xxar_bots_edo_cta_cs
                                              where 1=1
                                                and customer_trx_id not in (select a.customer_trx_id
                                                                              from xxbot.xxar_bots_edo_cta_cs a,
                                                                                   xxbot.xxar_bots_edo_cta b
                                                                             where 1 = 1
                                                                               and a.customer_trx_id=b.customer_trx_id));
        commit;

        vProgreso := '13.2';
        insert into xxwebc.control_edo_cta_cs (estatus,fecha) values (14,sysdate);
        COMMIT;

        -- Se llama proceso para sincronizar BD eBS vs BD Apex
        vProgreso := '14.1';
        SYNC_UP_EBS_VS_BDAPEX(P_ORG_ID,TRUNC(SYSDATE-1));

        --SE ACTUALIZAN LAS VM DEL EDO CTA APEX
        vProgreso := '14.2';
        begin
            XX_APEX.XXGEPP_UPDATE_VM@OCIPROD_TO_ORAPROD19 (v_msg);
            apps.MESSAGE_LOG (v_msg);
        end;

        vProgreso := '14.3';
        INSERT INTO xxwebc.control_edo_cta_cs (estatus,fecha) values (15,sysdate);
        COMMIT;

        vProgreso := '15.1';
		apps.MESSAGE_LOG('PROCESO TERMINO EXITOSAMENTE  '||SYSDATE||CHR(10));
        DBMS_OUTPUT.PUT_LINE('PROCESO TERMINO EXITOSAMENTE  '||SYSDATE||CHR(10));

        --return true;
    EXCEPTION
        WHEN OTHERS THEN
            apps.MESSAGE_LOG ('3. ' || vProgreso || 'ERR - EXC EN PROCESO DE ESTADO DE CUENTA '||SQLERRM||CHR(10));
            DBMS_OUTPUT.PUT_LINE('3. ' || vProgreso || 'ERR - EXC EN PROCESO DE ESTADO DE CUENTA '||SQLERRM);
            --return false;
    END XXAR_BOTS_ESTADO_D_CTA_CS;


    PROCEDURE GEN_FILE_XLS --( errbuf out varchar2,retcode out number)
    AS
        --v_filename           VARCHAR2 (4000) := p_filename;

        v_SENDER             VARCHAR2 (1000) := 'cfdi_ar_oracle@gepp.com';
        v_subject            VARCHAR2 (1000);
        v_to_recipients      VARCHAR2 (1000);
        v_cc_recipients      VARCHAR2 (1000);
        v_bcc_recipients     VARCHAR2 (1000);
        p_err_msg            NUMBER;
        v_service_name       VARCHAR2 (1000);
        v_zip_name           VARCHAR2 (4000);
        gv_dir               VARCHAR (50) := 'CUST_AR_EDO_CTA';
        v_file_name          VARCHAR2 (3000);
                                 --:= 'XXAR_ELAB_NC_CHEDRAUI.xls';

        v_worksheet          VARCHAR2 (1000) := 'IRSA';
        v_worksheet_a          VARCHAR2 (1000) := 'BEPUSA';
        r                    NUMBER;
        ra                    NUMBER;
        v_EstiloCabColumna   VARCHAR2 (100);
        V_estilo_celda       VARCHAR2 (100);
        v_body               VARCHAR2 (4000);
        V_FN VARCHAR2(4000);
    BEGIN

        V_FN := XXAR_BOTS_NOTAS_CARGO_CHE_FN;
     DBMS_OUTPUT.PUT_LINE('V_FN  '||V_FN);
        v_file_name :=
               'XXAR_EDO_CTA_CTEL'
            || TO_CHAR (SYSDATE, 'DDMMYYYY')
            || '.xls';

        -- Se crea el excel
        apps.gen_xl_xml.create_excel (gv_dir, v_file_name);

        --Stylos
        apps.gen_xl_xml.create_style ('resumen1',
                                 'Calibri',
                                 'Black',
                                 12,
                                 p_backcolor   => 'LightGray');
        apps.gen_xl_xml.create_style ('resumen2',
                                 'Calibri',
                                 'Black',
                                 12);
        apps.gen_xl_xml.create_style ('titulo_pestana2',
                                 'Calibri',
                                 'White',
                                 9,
                                 p_backcolor   => '#f50505');
        apps.gen_xl_xml.create_style ('titulo_pestana',
                                 'Calibri',
                                 'White',
                                 9,
                                 p_backcolor   => '#e7f3fd');--'LightBlue'  ); --'#3366FF');#e7f3fd
        apps.gen_xl_xml.create_style ('texto_celda',
                                 'Calibri',
                                 'Black',
                                 8,
                                 p_backcolor   => '#ffffff');
        apps.gen_xl_xml.create_style ('texto_celda2',
                                 'Calibri',
                                 'Black',
                                 8,
                                 p_backcolor   => '#ffffff');
        apps.gen_xl_xml.create_style ('titulo_error',
                                 'Calibri',
                                 'Red',
                                 9,
                                 p_backcolor   => '#8A8787');
        apps.gen_xl_xml.create_style ('texto_error',
                                 'Calibri',
                                 'Red',
                                 8,
                                 p_backcolor   => '#D5D3D3');
        apps.gen_xl_xml.create_style ('texto_error2',
                                 'Calibri',
                                 'Red',
                                 8,
                                 p_backcolor   => '#FBFCFC');

        apps.gen_xl_xml.create_worksheet (v_worksheet_a);
        -- Tamaño de columna
        apps.gen_xl_xml.set_column_width (1,110, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (2, 110, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (3, 110, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (4, 110, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (5, 110, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (6, 110, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (7, 110, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (8, 110, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (9, 110, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (10, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (11, 100, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (12, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (13, 100, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (14, 90, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (15, 100, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (16, 60, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (17, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (18, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (19, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (20, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (21, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (22, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (23, 70, v_worksheet_a);
        apps.gen_xl_xml.set_row_height (8, 30, v_worksheet_a);

        apps.gen_xl_xml.create_worksheet (v_worksheet);
        -- Tamaño de columna
        apps.gen_xl_xml.set_column_width (1,110, v_worksheet);
        apps.gen_xl_xml.set_column_width (2, 110, v_worksheet);
        apps.gen_xl_xml.set_column_width (3, 110, v_worksheet);
        apps.gen_xl_xml.set_column_width (4, 110, v_worksheet);
        apps.gen_xl_xml.set_column_width (5, 110, v_worksheet);
        apps.gen_xl_xml.set_column_width (6, 110, v_worksheet);
        apps.gen_xl_xml.set_column_width (7, 110, v_worksheet);
        apps.gen_xl_xml.set_column_width (8, 110, v_worksheet);
        apps.gen_xl_xml.set_column_width (9, 110, v_worksheet);
        apps.gen_xl_xml.set_column_width (10, 70, v_worksheet);
        apps.gen_xl_xml.set_column_width (11, 100, v_worksheet);
        apps.gen_xl_xml.set_column_width (12, 70, v_worksheet);
        apps.gen_xl_xml.set_column_width (13, 100, v_worksheet);
        apps.gen_xl_xml.set_column_width (14, 90, v_worksheet);
        apps.gen_xl_xml.set_column_width (15, 100, v_worksheet);
        apps.gen_xl_xml.set_column_width (16, 60, v_worksheet);
        apps.gen_xl_xml.set_column_width (17, 70, v_worksheet);
        apps.gen_xl_xml.set_column_width (18, 70, v_worksheet);
        apps.gen_xl_xml.set_column_width (19, 70, v_worksheet);
        apps.gen_xl_xml.set_column_width (20, 70, v_worksheet);
        apps.gen_xl_xml.set_column_width (21, 70, v_worksheet);
        apps.gen_xl_xml.set_column_width (22, 70, v_worksheet);
        apps.gen_xl_xml.set_column_width (23, 70, v_worksheet);
        apps.gen_xl_xml.set_row_height (8, 30, v_worksheet);

        r := 1;
        ra := 1;
--        APPS.gen_xl_xml.write_cell_CHAR (r,
--                                    1,
--                                    v_worksheet,
--                                    'Nombre Archivo:',
--                                    'titulo_pestana');
--
--        APPS.gen_xl_xml.write_cell_CHAR (r,
--                                    2,
--                                    v_worksheet,
--                                    v_file_name,
--                                    'texto_celda');

        ra := ra + 3;

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    1,
                                    v_worksheet,
                                    'Unidad Operativa',
                                    'titulo_pestana');
        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    2,
                                    v_worksheet,
                                    'Ejecutivo',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    3,
                                    v_worksheet,
                                    'Cadena',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    4,
                                    v_worksheet,
                                    'Cliente',
                                    'titulo_pestana');
        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    5,
                                    v_worksheet,
                                    'Localidad',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    6,
                                    v_worksheet,
                                    'Cobrador',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    7,
                                    v_worksheet,
                                    'Numero de Factura',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    8,
                                    v_worksheet,
                                    'Numero Unico',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    9,
                                    v_worksheet,
                                    'Remision',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                    10,
                                    v_worksheet,
                                    'No. de Recibo',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (ra,
                                   11,
                                    v_worksheet,
                                    'Orden de Compra',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    12,
                                    v_worksheet,
                                    'Fecha Recibo',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    13,
                                    v_worksheet,
                                    'Tipo',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    14,
                                    v_worksheet,
                                    'Fecha Documento',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    15,
                                    v_worksheet,
                                    'Fecha Contable',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    16,
                                    v_worksheet,
                                    'Fecha Vencimiento',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    17,
                                    v_worksheet,
                                    'Divisa',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    18,
                                    v_worksheet,
                                    'UUID',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    19,
                                    v_worksheet,
                                    'Estatus',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    20,
                                    v_worksheet,
                                    'Descripcion Estatus',
                                    'titulo_pestana');

      apps.gen_xl_xml.write_cell_CHAR (ra,
                                    21,
                                    v_worksheet,
                                    'Fecha Estatus',
                                    'titulo_pestana');

      apps.gen_xl_xml.write_cell_CHAR (ra,
                                    22,
                                    v_worksheet,
                                    'Importe Original',
                                    'titulo_pestana');

     apps.gen_xl_xml.write_cell_CHAR (ra,
                                    23,
                                    v_worksheet,
                                    'Saldo Debido',
                                    'titulo_pestana');




        FOR CUR
            IN (
                    select
                     company_name
                    ,ejecutivo
                    ,number_a
                    ,name
                    ,location
                    ,collector
                    ,number_b
                    ,customer_trx_id
                    ,remision
                    ,no_recibo
                    ,purchase_order
                    ,fecha_recibo
                    ,tipo
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
                    from xxar_bots_edo_cta a,
                    xxwebc.xxar_bots_tbl_cust_mails_cs b
                    where 1=1
                    and a.number_a=b.customer_number
                    and a.org_id=180
                    and a.balance_due<>0
                    order by due_date asc

--            AND A.TEXTOPOSICION IN (
--            'MCHID232490',
--            'MAFID273150'
--            )
                            )
        LOOP
            ra := ra + 1;

            IF MOD (ra, 2) = 0
            THEN
                V_estilo_celda := 'texto_celda';
            ELSE
                V_estilo_celda := 'texto_celda2';
            END IF;

            apps.gen_xl_xml.write_cell_CHAR (ra,
                                        1,
                                        v_worksheet,
                                        cur.company_name,
                                        V_estilo_celda);

            apps.gen_xl_xml.write_cell_CHAR (ra,
                                        2,
                                        v_worksheet,
                                        cur.ejecutivo,
                                        V_estilo_celda);

            apps.gen_xl_xml.write_cell_CHAR (ra,
                                        3,
                                        v_worksheet,
                                        CUR.number_a,
                                        V_estilo_celda);

            apps.gen_xl_xml.write_cell_CHAR (ra,
                                        4,
                                        v_worksheet,
                                        CUR.name,
                                        V_estilo_celda);

            apps.gen_xl_xml.write_cell_CHAR (ra,
                                        5,
                                        v_worksheet,
                                        CUR.location,
                                        V_estilo_celda);

            apps.gen_xl_xml.write_cell_CHAR (ra,
                                        6,
                                        v_worksheet,
                                        CUR.collector,
                                        V_estilo_celda);

            apps.gen_xl_xml.write_cell_CHAR (ra,
                                        7,
                                        v_worksheet,
                                        CUR.number_b,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        8,
                                        v_worksheet,
                                        CUR.customer_trx_id,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        9,
                                        v_worksheet,
                                        CUR.remision,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        10,
                                        v_worksheet,
                                        CUR.no_recibo,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        11,
                                        v_worksheet,
                                        CUR.purchase_order,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        12,
                                        v_worksheet,
                                        CUR.fecha_recibo,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        13,
                                        v_worksheet,
                                        CUR.tipo,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        14,
                                        v_worksheet,
                                        CUR.trx_date,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        15,
                                        v_worksheet,
                                        CUR.gl_date,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        16,
                                        v_worksheet,
                                        CUR.due_date,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        17,
                                        v_worksheet,
                                        CUR.currency_b,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        18,
                                        v_worksheet,
                                        CUR.uuid,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        19,
                                        v_worksheet,
                                        cur.estatus,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        20,
                                        v_worksheet,
                                        CUR.descripcion_estatus,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        21,
                                        v_worksheet,
                                        CUR.acceso_docto,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        22,
                                        v_worksheet,
                                        CUR.original_amount,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        23,
                                        v_worksheet,
                                        CUR.balance_due,
                                        V_estilo_celda);


        END LOOP;


        ----------------------------------------------------------------------------------------------------
        -------------------gen pestaña 2
        r := r + 3;

        apps.gen_xl_xml.write_cell_CHAR (r,
                                    1,
                                    v_worksheet_a,
                                    'Unidad Operativa',
                                    'titulo_pestana');
        apps.gen_xl_xml.write_cell_CHAR (r,
                                    2,
                                    v_worksheet_a,
                                    'Ejecutivo',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (r,
                                    3,
                                    v_worksheet_a,
                                    'Cadena',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (r,
                                    4,
                                    v_worksheet_a,
                                    'Cliente',
                                    'titulo_pestana');
        apps.gen_xl_xml.write_cell_CHAR (r,
                                    5,
                                    v_worksheet_a,
                                    'Localidad',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (r,
                                    6,
                                    v_worksheet_a,
                                    'Cobrador',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (r,
                                    7,
                                    v_worksheet_a,
                                    'Numero de Factura',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (r,
                                    8,
                                    v_worksheet_a,
                                    'Numero Unico',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (r,
                                    9,
                                    v_worksheet_a,
                                    'Remision',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (r,
                                    10,
                                    v_worksheet_a,
                                    'No. de Recibo',
                                    'titulo_pestana');

        apps.gen_xl_xml.write_cell_CHAR (r,
                                   11,
                                    v_worksheet_a,
                                    'Orden de Compra',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (r,
                                    12,
                                    v_worksheet_a,
                                    'Fecha Recibo',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (r,
                                    13,
                                    v_worksheet_a,
                                    'Tipo',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (r,
                                    14,
                                    v_worksheet_a,
                                    'Fecha Documento',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (r,
                                    15,
                                    v_worksheet_a,
                                    'Fecha Contable',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (r,
                                    16,
                                    v_worksheet_a,
                                    'Fecha Vencimiento',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (r,
                                    17,
                                    v_worksheet_a,
                                    'Divisa',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (r,
                                    18,
                                    v_worksheet_a,
                                    'UUID',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (r,
                                    19,
                                    v_worksheet_a,
                                    'Estatus',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (r,
                                    20,
                                    v_worksheet_a,
                                    'Descripcion Estatus',
                                    'titulo_pestana');

      apps.gen_xl_xml.write_cell_CHAR (r,
                                    21,
                                    v_worksheet_a,
                                    'Fecha Estatus',
                                    'titulo_pestana');

      apps.gen_xl_xml.write_cell_CHAR (r,
                                    22,
                                    v_worksheet_a,
                                    'Importe Original',
                                    'titulo_pestana');

     apps.gen_xl_xml.write_cell_CHAR (r,
                                    23,
                                    v_worksheet_a,
                                    'Saldo Debido',
                                    'titulo_pestana');




        FOR CUR
            IN (
                    select
                     company_name
                    ,ejecutivo
                    ,number_a
                    ,name
                    ,location
                    ,collector
                    ,number_b
                    ,customer_trx_id
                    ,remision
                    ,no_recibo
                    ,purchase_order
                    ,fecha_recibo
                    ,tipo
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
                    from xxar_bots_edo_cta a,
                    xxwebc.xxar_bots_tbl_cust_mails_cs b
                    where 1=1
                    and a.number_a=b.customer_number
                    and a.org_id=84
                    and a.balance_due<>0
                    order by due_date asc

--            AND A.TEXTOPOSICION IN (
--            'MCHID232490',
--            'MAFID273150'
--            )
                            )
        LOOP
            r := r + 1;

            IF MOD (r, 2) = 0
            THEN
                V_estilo_celda := 'texto_celda';
            ELSE
                V_estilo_celda := 'texto_celda2';
            END IF;

            apps.gen_xl_xml.write_cell_CHAR (r,
                                        1,
                                        v_worksheet_a,
                                        cur.company_name,
                                        V_estilo_celda);

            apps.gen_xl_xml.write_cell_CHAR (r,
                                        2,
                                        v_worksheet_a,
                                        cur.ejecutivo,
                                        V_estilo_celda);

            apps.gen_xl_xml.write_cell_CHAR (r,
                                        3,
                                        v_worksheet_a,
                                        CUR.number_a,
                                        V_estilo_celda);

            apps.gen_xl_xml.write_cell_CHAR (r,
                                        4,
                                        v_worksheet_a,
                                        CUR.name,
                                        V_estilo_celda);

            apps.gen_xl_xml.write_cell_CHAR (r,
                                        5,
                                        v_worksheet_a,
                                        CUR.location,
                                        V_estilo_celda);

            apps.gen_xl_xml.write_cell_CHAR (r,
                                        6,
                                        v_worksheet_a,
                                        CUR.collector,
                                        V_estilo_celda);

            apps.gen_xl_xml.write_cell_CHAR (r,
                                        7,
                                        v_worksheet_a,
                                        CUR.number_b,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        8,
                                        v_worksheet_a,
                                        CUR.customer_trx_id,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        9,
                                        v_worksheet_a,
                                        CUR.remision,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        10,
                                        v_worksheet_a,
                                        CUR.no_recibo,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        11,
                                        v_worksheet_a,
                                        CUR.purchase_order,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        12,
                                        v_worksheet_a,
                                        CUR.fecha_recibo,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        13,
                                        v_worksheet_a,
                                        CUR.tipo,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        14,
                                        v_worksheet_a,
                                        CUR.trx_date,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        15,
                                        v_worksheet_a,
                                        CUR.gl_date,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        16,
                                        v_worksheet_a,
                                        CUR.due_date,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        17,
                                        v_worksheet_a,
                                        CUR.currency_b,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        18,
                                        v_worksheet_a,
                                        CUR.uuid,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        19,
                                        v_worksheet_a,
                                        cur.estatus,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        20,
                                        v_worksheet_a,
                                        CUR.descripcion_estatus,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        21,
                                        v_worksheet_a,
                                        CUR.acceso_docto,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        22,
                                        v_worksheet_a,
                                        CUR.original_amount,
                                        V_estilo_celda);

           apps.gen_xl_xml.write_cell_CHAR (r,
                                        23,
                                        v_worksheet_a,
                                        CUR.balance_due,
                                        V_estilo_celda);


        END LOOP;

        apps.gen_xl_xml.close_file;


--        v_zip_name :=
--            SUBSTR (v_file_name, 1, INSTR (v_file_name, '.') - 1) || '.zip';
--        utl_zipped.zip (gv_dir, v_file_name, v_zip_name);


--        SELECT VALUE
--          INTO v_service_name
--          FROM v$parameter
--         WHERE 1 = 1 AND NAME = 'instance_name';
--
--
--        v_body :=
--               '<B>Generación Automática del formato de elaboración de NC</B>'
--            || '<br>'
--            || '<br>'
--            || 'Nombre de Archivo:<b>'
--            || ' '
--            || v_file_name
--            || '<b/>';
--
--
--        v_subject :=
--               'Elaboración de Notas de Cargo del día '||TO_CHAR(SYSDATE,'DD/MM/YYYY')||' ('
--            || v_service_name
--            || ')';



--        SELECT LISTAGG (MEANING, ';') WITHIN GROUP (ORDER BY MEANING)
--          INTO v_to_recipients
--          FROM FND_LOOKUP_VALUES_VL
--         WHERE     LOOKUP_TYPE = 'CUST_AP_MAIL_FACTORAJE_LKP'
--               AND enabled_flag = 'Y'
--               AND NVL (END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE;
--        apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
--                              P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
--                              P_RECIPIENT     =>'cynthia.montoya@gepp.com;beatriz.morales@gepp.com;luis.hernandezvillegas@gepp.com',
--                                                                    --'alejandro.romo@gepp.com',--v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
--                              P_CC            => 'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
--                              P_BCC           => null,--'CarlosEduardo.Davila@gepp.com',
--                              P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
--                              P_BODY          => v_body,             -- Cuerpo
--                              P_ATTACHMENT1   => v_file_name, --Archivo a enviar
--                              P_ERROR         => p_err_msg);

        --UTL_FILE.fremove (gv_dir, v_file_name);


        COMMIT;
   apps.MESSAGE_LOG ('Proceso finalizado exitoisamente');

    END GEN_FILE_XLS;

    PROCEDURE GEN_FILE_EDO_CTA_MAS ( P_CADENA IN varchar2,P_ORG_ID IN number,P_REQUEST_ID IN NUMBER)
    AS
        --v_filename           VARCHAR2 (4000) := p_filename;

--        v_SENDER             VARCHAR2 (1000) := 'cfdi_ar_oracle@gepp.com';
--        v_subject            VARCHAR2 (1000);
--        v_to_recipients      VARCHAR2 (1000);
--        v_cc_recipients      VARCHAR2 (1000);
--        v_bcc_recipients     VARCHAR2 (1000);
--        p_err_msg            NUMBER;
--        v_service_name       VARCHAR2 (1000);
       --v_zip_name           VARCHAR2 (4000);
        gv_dir               VARCHAR (50) := 'CUST_AR_EDO_CTA';
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
                                else
                                     V_UOP:=209;
                                     v_worksheet_a:= 'BEPUSA';
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
        apps.gen_xl_xml.set_column_width (6, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (7, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (8, 40, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (9, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (10, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (11, 90, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (12, 40, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (13, 170, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (14, 100, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (15, 90, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (16, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (17, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (18, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (19, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (20, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (21, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (22, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (23, 70, v_worksheet_a);
        apps.gen_xl_xml.set_row_height (8, 20, v_worksheet_a);

        select
                     DISTINCT (company_name)
                    ,ejecutivo
                    ,TO_CHAR(number_a)||' '||name
                    ,location
                    ,collector INTO v_COMPANY_NAME,V_EJECUTIVO,V_CLIENTE,V_LOCALIDAD,V_COBRADOR
                    from xxar_bots_edo_cta a,
                    xxwebc.xxar_bots_tbl_cust_mails_cs b
                    where 1=1
                    and a.number_a=b.customer_number
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

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    7,
                                    v_worksheet_a,
                                    'Fecha Recibo',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    8,
                                    v_worksheet_a,
                                    'Tipo',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    9,
                                    v_worksheet_a,
                                    'Fecha Documento',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    10,
                                    v_worksheet_a,
                                    'Fecha Contable',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    11,
                                    v_worksheet_a,
                                    'Fecha Vencimiento',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    12,
                                    v_worksheet_a,
                                    'Divisa',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    13,
                                    v_worksheet_a,
                                    'UUID',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    14,
                                    v_worksheet_a,
                                    'Estatus',
                                    'titulo_pestana');

       apps.gen_xl_xml.write_cell_CHAR (ra,
                                    15,
                                    v_worksheet_a,
                                    'Descripcion Estatus',
                                    'titulo_pestana');

      apps.gen_xl_xml.write_cell_CHAR (ra,
                                    16,
                                    v_worksheet_a,
                                    'Fecha Estatus',
                                    'titulo_pestana');

      apps.gen_xl_xml.write_cell_CHAR (ra,
                                    17,
                                    v_worksheet_a,
                                    'Importe Original',
                                    'titulo_pestana');

     apps.gen_xl_xml.write_cell_CHAR (ra,
                                    18,
                                    v_worksheet_a,
                                    'Saldo Debido',
                                    'titulo_pestana');

     apps.gen_xl_xml.write_cell_CHAR (ra,
                                    19,
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
                    from xxar_bots_edo_cta a,
                    xxwebc.xxar_bots_tbl_cust_mails_cs b
                    where 1=1
                    and a.number_a=b.customer_number
                    and a.number_a=P_CADENA
                    and a.org_id=P_ORG_ID
                    and abs(a.balance_due)>=1.0
                    order by due_date asc

--            AND A.TEXTOPOSICION IN (
--            'MCHID232490',
--            'MAFID273150'
--            )
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
                                        --

--           apps.gen_xl_xml.write_cell_CHAR (ra,
--                                        6,
--                                        v_worksheet_a,
--                                        CUR.purchase_order,
--                                        'texto_celda4');

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        7,
                                        v_worksheet_a,
                                        CUR.fecha_recibo,
                                        'texto_celda4');

           BEGIN

                        apps.gen_xl_xml.write_cell_NUM (ra,
                                        8,
                                        v_worksheet_a,
                                        TO_NUMBER(CUR.type),
                                        'texto_celda4');
                  EXCEPTION
                  WHEN OTHERS
                  THEN
                  apps.gen_xl_xml.write_cell_CHAR (ra,
                                        8,
                                        v_worksheet_a,
                                        CUR.type,
                                        'texto_celda4');
                  END;



           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        9,
                                        v_worksheet_a,
                                        TO_CHAR(CUR.trx_date,'DD-MON-YYYY'),
                                        'texto_celda4');

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        10,
                                        v_worksheet_a,
                                        TO_CHAR(CUR.gl_date,'DD-MON-YYYY'),
                                        'texto_celda4');

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        11,
                                        v_worksheet_a,
                                        TO_CHAR(CUR.due_date,'DD-MON-YYYY'),
                                        'texto_celda4');

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        12,
                                        v_worksheet_a,
                                        CUR.currency_b,
                                        'texto_celda4');

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        13,
                                        v_worksheet_a,
                                        CUR.uuid,
                                        'texto_celda4');

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        14,
                                        v_worksheet_a,
                                        cur.estatus,
                                        'texto_celda4');

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        15,
                                        v_worksheet_a,
                                        CUR.descripcion_estatus,
                                        'texto_celda4');

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        16,
                                        v_worksheet_a,
                                        TO_CHAR (CUR.acceso_docto,'DD-MON-YYYY'),
                                        'texto_celda4');

           apps.gen_xl_xml.write_cell_num (ra,
                                        17,
                                        v_worksheet_a,
                                        CUR.original_amount,
                                        'num_celda');

           apps.gen_xl_xml.write_cell_num (ra,
                                        18,
                                        v_worksheet_a,
                                        CUR.balance_due,
                                        'num_celda');

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        19,
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

        ra := ra + 1;

        select      sum (original_amount)
                    ,sum (balance_due) into v_sum_orig_amount,v_sum_balance_due
                    from xxar_bots_edo_cta a,
                    xxwebc.xxar_bots_tbl_cust_mails_cs b
                    where 1=1
                    and a.number_a=b.customer_number
                    and a.number_a=P_CADENA
                    and a.org_id=P_ORG_ID
                    and abs(a.balance_due)>=1.0;

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
                                        'Total Direción Cliente',
                                        'texto_celda3');

                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        16,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');

        apps.gen_xl_xml.write_cell_num (ra,
                                        17,
                                        v_worksheet_a,
                                        v_sum_orig_amount,
                                        'num_celda');

        apps.gen_xl_xml.write_cell_num (ra,
                                        18,
                                        v_worksheet_a,
                                        v_sum_balance_due,
                                        'num_celda');

                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        19,
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
                                        'Total Estado de Cuenta',
                                        'texto_celda3');

                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        16,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');

        apps.gen_xl_xml.write_cell_num (ra,
                                        17,
                                        v_worksheet_a,
                                        v_sum_orig_amount,
                                        'num_celda');

        apps.gen_xl_xml.write_cell_num (ra,
                                        18,
                                        v_worksheet_a,
                                        v_sum_balance_due,
                                        'num_celda');

                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        19,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');



        apps.gen_xl_xml.close_file;

        INSERT INTO XXBOT.CONTROL_GENMAS_EDOCTA
                                                (
                                                  REQUEST_ID,
                                                  FECHA_EJECUCION,
                                                  CADENA,
                                                  ORG_ID,
                                                  GEN_FILE,
                                                  FILE_NAME,
                                                  CREATION_DATE,
                                                  CREATED_BY,
                                                  LAST_UPDATE_DATE,
                                                  LAST_UPDATE_BY
                                                )
                                                VALUES
                                                (
                                                 P_REQUEST_ID,
                                                 TRUNC(SYSDATE),
                                                 P_CADENA,
                                                 P_ORG_ID,
                                                 'SI',
                                                 v_file_name,
                                                 SYSDATE,
                                                 V_USER_ID,
                                                 SYSDATE,
                                                 V_USER_ID
                                                 );

                                                 COMMIT;

        COMMIT;



        DBMS_OUTPUT.PUT_LINE('Estado de Cuenta Generado con Exito: '||v_file_name);
        apps.MESSAGE_LOG ('Estado de Cuenta Generado con Exito: '||v_file_name);

    END GEN_FILE_EDO_CTA_MAS;

    procedure XXBOT_GENMAS_EDOCTA (P_REQUEST_ID IN NUMBER,p_ORG_ID NUMBER)
    is

      V_REQUEST_ID number;
      V_USER_ID number;
      --v_zip_name varchar2(400);


   BEGIN


        IF P_REQUEST_ID = -1 THEN
        V_REQUEST_ID:= NVL( FND_GLOBAL.CONC_REQUEST_ID,0);
        ELSE
        V_REQUEST_ID := P_REQUEST_ID;
        END IF;
        V_USER_ID := NVL( FND_GLOBAL.USER_ID,0);

        APPS.MESSAGE_LOG('INICIA PROCESO');
        DBMS_OUTPUT.PUT_LINE('INICIA PROCESO');



                    BEGIN

                       for cur in (
                       select  distinct (b.customer_number)
                                    from xxwebc.xxar_bots_tbl_cust_mails_cs b
                                    where 1=1
                                    and b.customer_number   in (
                                                            select DISTINCT(a.number_a)
                                                            from xxbot.xxar_bots_edo_cta a,xxwebc.xxar_bots_tbl_cust_mails_cs b
                                                            where 1=1
                                                             and a.number_a=b.customer_number
                                                             AND A.ORG_ID=P_ORG_ID
                                                             AND abs(A.BALANCE_DUE) >=1.0
                                                             )
                                                              )

                            loop
                            GEN_FILE_EDO_CTA_MAS ( CUR.customer_number,P_ORG_ID,V_REQUEST_ID);
                            COMMIT;
                            END LOOP;
                    END;

                    BEGIN

                       for cur in (
                       select  distinct (b.customer_number)
                                    from xxwebc.xxar_bots_tbl_cust_mails_cs b
                                    where 1=1
                                    and b.customer_number NOT in (
                                                            select DISTINCT(a.number_a)
                                                            from xxbot.xxar_bots_edo_cta a,xxwebc.xxar_bots_tbl_cust_mails_cs b
                                                            where 1=1
                                                             and a.number_a=b.customer_number
                                                             AND A.ORG_ID=P_ORG_ID
                                                             AND abs(A.BALANCE_DUE) >=1.0

                                                              )
                                                              )

                            loop
                                    BEGIN
                                    INSERT INTO XXBOT.CONTROL_GENMAS_EDOCTA
                                                (
                                                  REQUEST_ID,
                                                  FECHA_EJECUCION,
                                                  CADENA,
                                                  ORG_ID,
                                                  GEN_FILE,
                                                  FILE_NAME,
                                                  CREATION_DATE,
                                                  CREATED_BY,
                                                  LAST_UPDATE_DATE,
                                                  LAST_UPDATE_BY
                                                )
                                                VALUES
                                                (
                                                 V_REQUEST_ID,
                                                 TRUNC(SYSDATE),
                                                 CUR.CUSTOMER_NUMBER,
                                                 P_ORG_ID,
                                                 'NO',
                                                 NULL,
                                                 SYSDATE,
                                                 V_USER_ID,
                                                 SYSDATE,
                                                 V_USER_ID
                                                 );

                                                 COMMIT;
                                             END;
                            COMMIT;
                            END LOOP;
                    END;


   EXCEPTION
   WHEN OTHERS THEN
   dbms_output.put_line('Error al ejecutarse el proceso - '||SQLCODE||' -ERROR- '||SQLERRM);
   APPS.MESSAGE_LOG('Error al ejecutarse el proceso - '||SQLCODE||' -ERROR- '||SQLERRM);
   --return false;
   END;

   procedure XXBOT_GENMAS_EDOCTA_CS (errbuf out varchar2,retcode out number)
    is

      P_REQUEST_ID number;
      V_REQUEST_ID number;
      V_USER_ID number;
      v_name varchar2(400);
      --v_zip_name varchar2(400);
      v_SENDER             VARCHAR2 (1000) := 'cfdi_ar_oracle@gepp.com';
       v_subject            VARCHAR2 (1000);
        v_to_recipients      VARCHAR2 (1000);
        v_cc_recipients      VARCHAR2 (1000);
        v_bcc_recipients     VARCHAR2 (1000);
        p_err_msg            NUMBER;
        v_service_name       VARCHAR2 (1000);
       --v_zip_name           VARCHAR2 (4000);
        gv_dir               VARCHAR (50) := 'CUST_AR_EDO_CTA';
        v_file_name          VARCHAR2 (3000);
        v_worksheet_a VARCHAR2 (1000);
        ra                    NUMBER;
        --v_EstiloCabColumna   VARCHAR2 (100);
        V_estilo_celda       VARCHAR2 (100);
        v_body               VARCHAR2 (4000);
        --V_FN              VARCHAR2(4000);

        v_file_name_end    VARCHAR2 (3000);
        v_file_name_2     VARCHAR2 (3000);
        v_file_name_3     VARCHAR2 (3000);
        v_fname utl_file.file_type;
        v_fnamea utl_file.file_type;


   BEGIN

        P_REQUEST_ID:=-1;

        IF P_REQUEST_ID = -1 THEN
        V_REQUEST_ID:= NVL( FND_GLOBAL.CONC_REQUEST_ID,0);
        ELSE
        V_REQUEST_ID := P_REQUEST_ID;
        END IF;
        V_USER_ID := NVL( FND_GLOBAL.USER_ID,0);

        APPS.MESSAGE_LOG('INICIA PROCESO');
        DBMS_OUTPUT.PUT_LINE('INICIA PROCESO');

        ---BORRA ARCHIVOS RESAGADOS
                    BEGIN

                    for cur in ( SELECT COLUMN_VALUE FILENAME
                    FROM TABLE(APPS.LIST_FILES('/u07/cargas/ar/edos_cuenta'))
                    WHERE 1=1
                    and COLUMN_VALUE not in ('zipped'))

                            loop
                            UTL_FILE.fremove (gv_dir, CUR.FILENAME);
                            COMMIT;
                            END LOOP;
                     END;
                     -----


                    BEGIN
                    XXBOT_GENMAS_EDOCTA (V_REQUEST_ID,180);
                    EXCEPTION
                    WHEN OTHERS THEN
                    dbms_output.put_line('Error al ejecutarse el proceso de generación masiva de estado de cuenta IRSA - '||SQLCODE||' -ERROR- '||SQLERRM);
                    APPS.MESSAGE_LOG('Error al ejecutarse el proceso de generación masiva de estado de cuenta IRSA- '||SQLCODE||' -ERROR- '||SQLERRM);
                    END;

                    BEGIN
                    XXBOT_GENMAS_EDOCTA (V_REQUEST_ID,84);
                    EXCEPTION
                    WHEN OTHERS THEN
                    dbms_output.put_line('Error al ejecutarse el proceso de generación masiva de estado de cuenta BEPUSA - '||SQLCODE||' -ERROR- '||SQLERRM);
                    APPS.MESSAGE_LOG('Error al ejecutarse el proceso de generación masiva de estado de cuenta BEPUSA- '||SQLCODE||' -ERROR- '||SQLERRM);
                    END;

--                       v_file_name :=
--                                    'EdCBEPUSAIRA_'
--                                    || TO_CHAR (SYSDATE, 'DDMMYY')
--                                    || '.xls';
--
--                        -- Se crea el csv
--                        v_worksheet_a:='Reporte';
--                        apps.gen_xl_xml.create_excel (gv_dir, v_file_name);
--
--
--                        apps.gen_xl_xml.create_style ('texto_celda4',
--                                 'Calibri',
--                                 'Black',
--                                 11);
--
--                apps.gen_xl_xml.create_worksheet (v_worksheet_a);
--                -- Tamaño de columna
--                apps.gen_xl_xml.set_column_width (1,70, v_worksheet_a);
--                apps.gen_xl_xml.set_column_width (2, 150, v_worksheet_a);
--                apps.gen_xl_xml.set_column_width (3, 70, v_worksheet_a);
--
--                ra := 1;
--                APPS.gen_xl_xml.write_cell_CHAR (ra,
--                                            1,
--                                            v_worksheet_a,
--                                            'Cadena',
--                                            'texto_celda4');
--
--                APPS.gen_xl_xml.write_cell_CHAR (ra,
--                                            2,
--                                            v_worksheet_a,
--                                            'Razon Social',
--                                            'texto_celda4');
--
--                APPS.gen_xl_xml.write_cell_CHAR (ra,
--                                            3,
--                                            v_worksheet_a,
--                                            'Archivos',
--                                            'texto_celda4');
--
--                FOR CUR
--                            IN (
--                                    select a.cadena,b.customer_name,a.file_name
--                                            from XXBOT.CONTROL_GENMAS_EDOCTA a,APPS.ar_customers b
--                                            where 1=1
--                                            and b.customer_number=a.cadena
--                                            and gen_file='SI'
--                                            AND REQUEST_ID=V_request_id
--                                            ORDER BY A.CADENA DESC
--                                            )
--
--
--                LOOP
--
--                ra := ra + 1;
--
--                            apps.gen_xl_xml.write_cell_CHAR (ra,
--                                                        1,
--                                                        v_worksheet_a,
--                                                        to_char(CUR.cadena),
--                                                        'texto_celda4');
--
--                            apps.gen_xl_xml.write_cell_CHAR (ra,
--                                                        2,
--                                                        v_worksheet_a,
--                                                        CUR.customer_name,
--                                                        'texto_celda4');
--
--                            apps.gen_xl_xml.write_cell_CHAR (ra,
--                                                        3,
--                                                        v_worksheet_a,
--                                                        CUR.file_name,
--                                                        'texto_celda4');
--
--                   END LOOP;
--
--                   apps.gen_xl_xml.close_file;
--
--                   COMMIT;
    -----------------------------------------------------------------------------
                   v_file_name_2 :='EdCBEPUSAIRA_'
                                    || TO_CHAR (SYSDATE, 'DDMMYY')
                                    || '.csv';

                   -- Se crea el archivo fin

                   v_fnamea := utl_file.fopen (gv_dir,v_file_name_2, 'w');

                   utl_file.put(v_fnamea,'Cadena');
                    utl_file.put(v_fnamea,',Razon Social');
                    utl_file.put(v_fnamea,',Archivos');
                    utl_file.new_line(v_fnamea);


                   FOR CUR1
                            IN (
                                    select a.cadena,b.customer_name,a.file_name
                                            from XXBOT.CONTROL_GENMAS_EDOCTA a,APPS.ar_customers b
                                            where 1=1
                                            and b.customer_number=a.cadena
                                            and gen_file='SI'
                                            AND REQUEST_ID=V_request_id
                                            ORDER BY A.CADENA DESC
                                            )


                    loop
                    utl_file.put(v_fnamea,cur1.cadena);
                    utl_file.put(v_fnamea,','||cur1.customer_name);
                    utl_file.put(v_fnamea,','||cur1.file_name);
                    utl_file.new_line(v_fnamea);
                    end loop;
                    utl_file.fclose(v_fnamea);





                   v_file_name_end :=
                                    'fin_'
                                    || TO_CHAR (v_request_id)
                                    || '.txt';

                   -- Se crea el archivo fin

                   v_fname := utl_file.fopen (gv_dir,v_file_name_end, 'w');
                   utl_file.fclose(v_fname);

                   ---------
                   select distinct(b.description)into v_name
                        from xxbot.CONTROL_GENMAS_EDOCTA a,APPLSYS.fnd_user b
                        where 1=1
                        and a.created_by=b.user_id
                        and a.request_id=v_request_id;
                  ----

                   SELECT VALUE
                  INTO v_service_name
                  FROM v$parameter
                   WHERE 1 = 1 AND NAME = 'instance_name';


                v_body :=
                       '<B>Notificación de generación de Estados de Cuenta para Cobranza Telefónica</B>'
                    || '<br>'
                    || '<br>'
                    || 'Notas Importantes:<b>'
                    || '<br>'
                    || '<br>'
                    || 'ID de la solicitud: '||v_request_id||'<b>'
                    || '<br>'
                    || '<br>'
                    || 'Proceso ejecutado por: '||v_name||'<b>'
                    || '<br>'
                    || '<br>'
                    || 'Se adjunta archivo .csv con el listado de los Estados de Cuenta generados por el proceso.<b>'
                    || '<br>'
                    || '<br>'
                    || 'Una vez recibido este correo, considerar un tiempo de hasta 1 Hora para poder descargar la información desde la carpeta compartida en OneDrive.<b>'
                    || '<br>'
                    || '<br>'
                    || 'Liga de acceso:<b>'
                    || '<br>'
                    || 'https://gpogepp-my.sharepoint.com/:f:/g/personal/edi_gepp_com/EiOghacCAwZAoedk63kZgnQBcYFMSO0FMMwaw2eK839wTw?e=hZASmY<b>'
                    || '<b/>';


                v_subject :=
                       'Notificación de generación de Estados de Cuenta para Cobranza Telefónica '||TO_CHAR(SYSDATE,'DD/MM/YYYY')||' ('
                    || v_service_name
                    || ')';



--                SELECT LISTAGG (MEANING, ';') WITHIN GROUP (ORDER BY MEANING)
--                  INTO v_to_recipients
--                  FROM FND_LOOKUP_VALUES_VL
--                 WHERE     LOOKUP_TYPE = 'CUST_AP_MAIL_FACTORAJE_LKP'
--                       AND enabled_flag = 'Y'
--                       AND NVL (END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE;
                apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                                      P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                                      P_RECIPIENT     => 'martin.dominguez@gepp.com;eduardo.ruizmares@gepp.com;zammis.gonzalez@gepp.com',--v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                                      P_CC            => null,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                                      P_BCC           => 'alejandro.romo@gepp.com',--'CarlosEduardo.Davila@gepp.com',
                                      P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                                      P_BODY          => v_body,             -- Cuerpo
                                      P_ATTACHMENT1   => v_file_name_2, --Archivo a enviar
                                      P_ERROR         => p_err_msg);

   EXCEPTION
   WHEN OTHERS THEN
   dbms_output.put_line('Error al ejecutarse el proceso_mas - '||SQLCODE||' -ERROR- '||SQLERRM);
   APPS.MESSAGE_LOG('Error al ejecutarse el proceso_mas - '||SQLCODE||' -ERROR- '||SQLERRM);
   --return false;
   END;

procedure XXBOT_GEN_LAY_TELMEX (errbuf out varchar2,retcode out number)
    is

    v_SENDER             VARCHAR2 (1000) := 'cfdi_ar_oracle@gepp.com';
       v_subject            VARCHAR2 (1000);
        v_to_recipients      VARCHAR2 (1000);
        v_cc_recipients      VARCHAR2 (1000);
        v_bcc_recipients     VARCHAR2 (1000);
        p_err_msg            NUMBER;
        v_body VARCHAR2 (1000);
        v_service_name       VARCHAR2 (1000);
      v_dia_execution_1 exception;
    v_dia_execution_2 exception;
      P_REQUEST_ID number;
      V_REQUEST_ID number;
      V_USER_ID number;
      v_name varchar2(400);
        gv_dir               VARCHAR (50) :='CUST_AR_LAY_TELMEX';
        v_file_name          VARCHAR2 (3000);
        v_file_name_end    VARCHAR2 (3000);
        v_file_name_2     VARCHAR2 (3000);
        v_file_name_3     VARCHAR2 (3000);
        v_fname utl_file.file_type;
        v_fnamea utl_file.file_type;
        V_DAY VARCHAR2(20);


   BEGIN

                begin
                        EXECUTE IMMEDIATE
                        'ALTER SESSION SET NLS_LANGUAGE =  "latin american spanish" ';
                        DBMS_OUTPUT.PUT_LINE('OK');
                        EXCEPTION WHEN OTHERS
                        THEN
                        DBMS_OUTPUT.PUT_LINE('FALLA EN SETEO DE LENGUAJE'||SQLERRM);
                        end;


   SELECT TO_CHAR(SYSDATE, 'DAY', 'NLS_DATE_LANGUAGE=SPANISH') INTO V_DAY FROM dual;

       IF
       V_DAY='SÁBADO   '
       THEN
       RAISE v_dia_execution_1;
       END IF;

       IF
       V_DAY='DOMINGO  '
       THEN
       RAISE v_dia_execution_2;
       END IF;

        P_REQUEST_ID:=-1;

        IF P_REQUEST_ID = -1 THEN
        V_REQUEST_ID:= NVL( FND_GLOBAL.CONC_REQUEST_ID,0);
        ELSE
        V_REQUEST_ID := P_REQUEST_ID;
        END IF;
        V_USER_ID := NVL( FND_GLOBAL.USER_ID,0);

        APPS.MESSAGE_LOG('INICIA PROCESO');
        DBMS_OUTPUT.PUT_LINE('INICIA PROCESO');

        ---BORRA ARCHIVOS RESAGADOS
                    BEGIN

                    for cur in ( SELECT COLUMN_VALUE FILENAME
                    FROM TABLE(APPS.LIST_FILES('/u07/cargas/ar/telmex'))
                    WHERE 1=1
                    and COLUMN_VALUE not in ('zipped'))

                            loop
                            UTL_FILE.fremove (gv_dir, CUR.FILENAME);
                            COMMIT;
                            END LOOP;
                     END;
                     -----
--GENERO DATOS DE CONTACTO

            BEGIN
            DELETE XXBOT.CONTACT_INFO_CT_CS
            WHERE 1=1;
            COMMIT;
            END;
 ------------
 BEGIN
FOR CUR IN (select CUSTOMER_NUMBER
                    from xxwebc.xxar_bots_tbl_cust_mails_cs a
                                     where 1=1
                                     )

LOOP
insert into XXBOT.CONTACT_INFO_CT_CS(

select distinct(b.CONT_FULL_NAME)as nombre_contacto
,D.CUSTOMER_ID
,d.customer_number
,d.customer_name as cadena_comercial
,d.TAX_REFERENCE as rfc
,replace (f.ADDRESS1||' '||f.ADDRESS2||' '||f.city||' '||f.state||' '||F.POSTAL_CODE,',',' ') AS DIRECCION
,b.CONTACT_NUMBER as agrupador
,listagg (SUBSTR(b.PHONE,1,10),';') within group (order by b.CONT_FULL_NAME) over (partition by b.CONT_FULL_NAME)||';;;;' phone
,listagg (SUBSTR(b.PHONE,11,19),';') within group (order by b.CONT_FULL_NAME) over (partition by b.CONT_FULL_NAME)||';;;;' ext
,A.email_address||';|' as email_address
,i.PERIODO_ENVIO
,i.FECHA_ENVIO
,null
--,e.MEANING as periodo_envio
--,c.tolerance as Fecha_envio
from apps.AR_CONTACTS_V a
,apps.HZ_CONTACT_FIND_V b
--,AR.HZ_CUSTOMER_PROFILES C
,apps.ar_customers d
--,apps.FND_LOOKUP_VALUES_VL e
,apps.hz_parties f
,apps.hz_cust_accounts g
,xxwebc.xxar_bots_tbl_cust_mails_cs h
,XXBOT.XXAR_SEND_RULES_ECTELMEX_L i
where 1=1
and i.customer_id =b.customer_id
and i.customer_id =a.customer_id
and i.customer_id =d.customer_id
and d.customer_id =b.customer_id
and a.customer_id=d.customer_id
and a.CONTACT_NUMBER=b.CONTACT_NUMBER
and a.customer_id =b.customer_id
and d.customer_id=h.customer_id
and a.customer_id=h.customer_id
and b.customer_id=h.customer_id
and d.customer_number =CUR.CUSTOMER_NUMBER
--AND C.CUST_ACCOUNT_ID=a.customer_id
--and c.ACCOUNT_STATUS(+)=e.LOOKUP_CODE
--and e.LOOKUP_TYPE = 'ACCOUNT_STATUS'
AND g.cust_account_id  =d.customer_id
AND g.party_id = F.party_id
and b.CONTACT_NUMBER like 'EC-%'
AND B.STATUS='A'
and i.ACTIVO='SI'
);
commit;
end loop;
END;
commit;


-----genero layout
    -----------------------------------------------------------------------------
                   v_file_name_2 :='cartera_gepp_'
                                    || TO_CHAR (SYSDATE,'DDMMYYYY')
                                    || '.csv';

                   -- Se crea el archivo fin

                   v_fnamea := utl_file.fopen (gv_dir,v_file_name_2, 'w');

                    utl_file.put(v_fnamea,'Compañía');
                    utl_file.put(v_fnamea,',Nombre Cliente');
                    utl_file.put(v_fnamea,',ID del Cliente');
                    utl_file.put(v_fnamea,',RFC');
                    utl_file.put(v_fnamea,',Direccion Cliente');
                    utl_file.put(v_fnamea,',Responsable Cuenta');
                    utl_file.put(v_fnamea,',Nombre de Contacto');
                    utl_file.put(v_fnamea,',Telefono 1');
                    utl_file.put(v_fnamea,',Telefono 2');
                    utl_file.put(v_fnamea,',Telefono 3');
                    utl_file.put(v_fnamea,',Telefono 4');
                    utl_file.put(v_fnamea,',Extención 1');
                    utl_file.put(v_fnamea,',Extención 2');
                    utl_file.put(v_fnamea,',Extención 3');
                    utl_file.put(v_fnamea,',Extención 4');
                    utl_file.put(v_fnamea,',Correo Princpal');
                    utl_file.put(v_fnamea,',Correos Secundarios');
                    utl_file.put(v_fnamea,',Agrupador de Cobranza Telefónica');
                    utl_file.put(v_fnamea,',Periodo de Envío');
                    utl_file.put(v_fnamea,',Fecha de Envío');
                    utl_file.put(v_fnamea,',Número de Factura');
                    utl_file.put(v_fnamea,',Fecha Factura');
                    utl_file.put(v_fnamea,',Fecha Vencimiento');
                    utl_file.put(v_fnamea,',Importe Original');
                    utl_file.put(v_fnamea,',Importe Pendiente');
                    utl_file.put(v_fnamea,',Número de Recibo');
                    utl_file.put(v_fnamea,',Orden de Compra');
                    utl_file.put(v_fnamea,',Divisa');
                    utl_file.new_line(v_fnamea);


                   FOR CUR1
                            IN (
                                    select B.COMPANY_NAME
                                        ,A.CADENA_COMERCIAL
                                        ,A.CUSTOMER_NUMBER
                                        ,a.rfc
                                        ,A.DIRECCION
                                        ,b.collector
                                        ,A.NOMBRE_CONTACTO
                                        ,SUBSTR(A.PHONE,0,INSTR(A.PHONE,';')-1) as telefono_1
                                        ,SUBSTR(A.PHONE,
                                        INSTR(A.PHONE,';')+1,
                                        INSTR(A.PHONE,';',INSTR(A.PHONE,';')+1)-
                                        INSTR(A.PHONE,';')-1
                                        ) as telefono_2
                                        ,SUBSTR(A.PHONE,
                                        INSTR(A.PHONE,';',INSTR(A.PHONE,';')+1)+1,
                                        INSTR(A.PHONE,';',
                                        INSTR(A.PHONE,';',INSTR(A.PHONE,';')+1)+1)-
                                        INSTR(A.PHONE,';',INSTR(A.PHONE,';')+1)-1
                                        ) as telefono_3
                                        ,SUBSTR(A.PHONE,
                                        INSTR(A.PHONE,';',
                                        INSTR(A.PHONE,';',INSTR(A.PHONE,';')+1)+1)+1,
                                        INSTR(A.PHONE,';',
                                        INSTR(A.PHONE,';',
                                        INSTR(A.PHONE,';',INSTR(A.PHONE,';')+1)+1)+1)-
                                        INSTR(A.PHONE,';',
                                        INSTR(A.PHONE,';',INSTR(A.PHONE,';')+1)+1)-1) as telefono_4
                                        ,SUBSTR(A.EXT,0,INSTR(A.EXT,';')-1) as EXTENCION_1
                                        ,SUBSTR(A.EXT,
                                        INSTR(A.EXT,';')+1,
                                        INSTR(A.EXT,';',INSTR(A.EXT,';')+1)-
                                        INSTR(A.EXT,';')-1
                                        ) as EXTENCION_2
                                        ,SUBSTR(A.EXT,
                                        INSTR(A.EXT,';',INSTR(A.EXT,';')+1)+1,
                                        INSTR(A.EXT,';',
                                        INSTR(A.EXT,';',INSTR(A.EXT,';')+1)+1)-
                                        INSTR(A.EXT,';',INSTR(A.EXT,';')+1)-1
                                        ) as EXTENCION_3
                                        ,SUBSTR(A.EXT,
                                        INSTR(A.EXT,';',
                                        INSTR(A.EXT,';',INSTR(A.EXT,';')+1)+1)+1,
                                        INSTR(A.EXT,';',
                                        INSTR(A.EXT,';',
                                        INSTR(A.EXT,';',INSTR(A.EXT,';')+1)+1)+1)-
                                        INSTR(A.EXT,';',
                                        INSTR(A.EXT,';',INSTR(A.EXT,';')+1)+1)-1) as EXTENCION_4
                                        ,SUBSTR(A.EMAIL_ADDRESS,0,INSTR(A.EMAIL_ADDRESS,';')-1) as CORREO_PRINCIPAL
                                        ,CASE
                                            WHEN REPLACE (SUBSTR(A.EMAIL_ADDRESS,INSTR(A.EMAIL_ADDRESS,';')+1),';|','') ='|' THEN  REPLACE(REPLACE (SUBSTR(A.EMAIL_ADDRESS,INSTR(A.EMAIL_ADDRESS,';')+1),';|',''),'|','')
                                            ELSE
                                            REPLACE (SUBSTR(A.EMAIL_ADDRESS,INSTR(A.EMAIL_ADDRESS,';')+1),';|','')
                                         END
                                             as Correos_Secundarios
                                        ,A.AGRUPADOR
                                        ,A.PERIODO_ENVIO
                                        ,A.FECHA_ENVIO
                                        ,B.NUMBER_B
                                        ,TO_CHAR(B.TRX_DATE,'DD-MON-YYYY') as trx_date
                                        ,TO_CHAR(B.DUE_DATE,'DD-MON-YYYY') as due_date
                                        ,B.ORIGINAL_AMOUNT
                                        ,B.BALANCE_DUE
                                        ,B.NO_RECIBO
                                        ,B.PURCHASE_ORDER
                                        ,B.CURRENCY_B
                                        from XXBOT.CONTACT_INFO_CT_CS A, xxbot.xxar_bots_edo_cta B
                                        WHERE 1=1
                                        AND A.CUSTOMER_ID=B.CUSTOMER_ID
                                        AND B.BALANCE_DUE>=1
                                        AND B.ORG_ID IN (180,84)
                                        AND B.DUE_DATE <=TRUNC (SYSDATE+10)
                                        AND (b.MESSAGE IS NULL or b.message='RESUELTO' or b.message='PROMESA DE PAGO' and to_date(scheduled_date,'dd-mm-yyyy')< to_date (sysdate,'dd-mm-yyyy'))
                                        ORDER BY A.CUSTOMER_ID,B.COMPANY_NAME DESC
                                            )


                    loop
                    utl_file.put(v_fnamea,cur1.COMPANY_NAME);
                    utl_file.put(v_fnamea,','||cur1.CADENA_COMERCIAL);
                    utl_file.put(v_fnamea,','||cur1.CUSTOMER_NUMBER);
                    utl_file.put(v_fnamea,','||cur1.RFC);
                    utl_file.put(v_fnamea,','||cur1.DIRECCION);
                    utl_file.put(v_fnamea,','||cur1.collector);
                    utl_file.put(v_fnamea,','||cur1.NOMBRE_CONTACTO);
                    utl_file.put(v_fnamea,','||cur1.telefono_1);
                    utl_file.put(v_fnamea,','||cur1.telefono_2);
                    utl_file.put(v_fnamea,','||cur1.telefono_3);
                    utl_file.put(v_fnamea,','||cur1.telefono_4);
                    utl_file.put(v_fnamea,','||cur1.EXTENCION_1);
                    utl_file.put(v_fnamea,','||cur1.EXTENCION_2);
                    utl_file.put(v_fnamea,','||cur1.EXTENCION_3);
                    utl_file.put(v_fnamea,','||cur1.EXTENCION_4);
                    utl_file.put(v_fnamea,','||cur1.CORREO_PRINCIPAL);
                    utl_file.put(v_fnamea,','||cur1.Correos_Secundarios);
                    utl_file.put(v_fnamea,','||cur1.AGRUPADOR);
                    utl_file.put(v_fnamea,','||cur1.PERIODO_ENVIO);
                    utl_file.put(v_fnamea,','||cur1.FECHA_ENVIO);
                    utl_file.put(v_fnamea,','||cur1.NUMBER_B);
                    utl_file.put(v_fnamea,','||cur1.TRX_DATE);
                    utl_file.put(v_fnamea,','||cur1.DUE_DATE);
                    utl_file.put(v_fnamea,','||cur1.ORIGINAL_AMOUNT);
                    utl_file.put(v_fnamea,','||cur1.BALANCE_DUE);
                    utl_file.put(v_fnamea,','||cur1.NO_RECIBO);
                    utl_file.put(v_fnamea,','||cur1.PURCHASE_ORDER);
                    utl_file.put(v_fnamea,','||cur1.CURRENCY_B);
                    utl_file.new_line(v_fnamea);
                    end loop;
                    utl_file.fclose(v_fnamea);
                    commit;

                    BEGIN
                    UPDATE XXBOT.CONTACT_INFO_CT_CS
                    SET LAST_UPDATE_DATE=SYSDATE
                    WHERE 1=1;
                    COMMIT;
                    END;





                   v_file_name_end :=
                                    'fin_'
                                    || TO_CHAR (v_request_id)
                                    || '.txt';

                   -- Se crea el archivo fin

                   v_fname := utl_file.fopen (gv_dir,v_file_name_end, 'w');
                   utl_file.fclose(v_fname);
                   commit;



                   SELECT VALUE
                  INTO v_service_name
                  FROM v$parameter
                   WHERE 1 = 1 AND NAME = 'instance_name';


                v_body :=
                       '<B>Notificación de Generación de Layout Telmex</B>'
                    || '<br>'
                    || '<br>'
                    || 'Notas Importantes:<b>'
                    || '<br>'
                    || '<br>'
                    || 'ID de la solicitud: '||v_request_id||'<b>'
                    || '<br>'
                    || '<br>'
                    || 'Proceso de Generación Ejecutado Correctamente.<b>'
                    || '<br>'
                    || '<br>'
                    || 'Una vez recibido este correo, considerar un tiempo de hasta 30 min. para poder descargar la información desde la carpeta compartida en OneDrive.<b>'
                    || '<br>'
                    || '<br>'
                    || 'Liga de acceso:<b>'
                    || '<br>'
                    || 'https://gpogepp-my.sharepoint.com/personal/edi_gepp_com/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Fedi%5Fgepp%5Fcom%2FDocuments%2FTelmex&originalPath=aHR0cHM6Ly9ncG9nZXBwLW15LnNoYXJlcG9pbnQuY29tLzpmOi9nL3BlcnNvbmFsL2VkaV9nZXBwX2NvbS9FdjNvbEZOeU81QktuVkdfR1VfNmIzb0JMMl9qWDQ4ZE41SkRaVHNqV21aZnBnP3J0aW1lPU81VnE2SW9aMlVn'
                    || '<b/>';


                v_subject :=
                       'Notificación de Generación de Layout Telmex '||TO_CHAR(SYSDATE,'DD/MM/YYYY')||' ('
                    || v_service_name
                    || ')';



--                SELECT LISTAGG (MEANING, ';') WITHIN GROUP (ORDER BY MEANING)
--                  INTO v_to_recipients
--                  FROM FND_LOOKUP_VALUES_VL
--                 WHERE     LOOKUP_TYPE = 'CUST_AP_MAIL_FACTORAJE_LKP'
--                       AND enabled_flag = 'Y'
--                       AND NVL (END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE;
                apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                                      P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                                      P_RECIPIENT     => 'zammis.gonzalez@gepp.com',--'martin.dominguez@gepp.com;eduardo.ruizmares@gepp.com;zammis.gonzalez@gepp.com',--v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                                      P_CC            => null,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                                      P_BCC           => 'alejandro.romo@gepp.com',--'CarlosEduardo.Davila@gepp.com',
                                      P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                                      P_BODY          => v_body,             -- Cuerpo
                                      P_ATTACHMENT1   => null,--v_file_name_2, --Archivo a enviar
                                      P_ERROR         => p_err_msg);
                                      commit;



   EXCEPTION
   when v_dia_execution_1 then
   dbms_output.put_line('El proceso no debe ejecutarse los días SABADO '||SQLCODE||' -ERROR- '||SQLERRM);
   APPS.MESSAGE_LOG ('El proceso no debe ejecutarse los días SABADO '||SQLCODE||' -ERROR- '||SQLERRM);
   when v_dia_execution_2 then
   dbms_output.put_line('El proceso no debe ejecutarse los días DOMINGO '||SQLCODE||' -ERROR- '||SQLERRM);
   APPS.MESSAGE_LOG ('El proceso no debe ejecutarse los días DOMINGO '||SQLCODE||' -ERROR- '||SQLERRM);
   WHEN OTHERS THEN
   dbms_output.put_line('Error al ejecutarse el proceso_LAYOUT_TELMEX - '||SQLCODE||' -ERROR- '||SQLERRM);
   APPS.MESSAGE_LOG('Error al ejecutarse el proceso_LAYOUT_TELMEX - '||SQLCODE||' -ERROR- '||SQLERRM);
   commit;
   --return false;
   END;

   FUNCTION GET_SEND_DATE (P_PERIODO_ENVIO IN  VARCHAR2,P_FECHA_ENVIO IN VARCHAR2 )
    RETURN DATE
IS
    V_resultado   DATE := NULL;

BEGIN

                        begin
                        EXECUTE IMMEDIATE
                        'ALTER SESSION SET NLS_LANGUAGE =  "latin american spanish" ';
                        --DBMS_OUTPUT.PUT_LINE('OK');
                        EXCEPTION WHEN OTHERS
                        THEN
                        DBMS_OUTPUT.PUT_LINE('FALLA EN SETEO DE LENGUAJE'||SQLERRM);
                        end;

    IF P_PERIODO_ENVIO = 'Anual'
    THEN

                        SELECT
                        CASE
                        WHEN TO_DATE (TRIM(P_FECHA_ENVIO||'-'||(SELECT EXTRACT(YEAR FROM SYSDATE) AS ONLY_CURRENT_DAY FROM DUAL )))=TRUNC(SYSDATE)THEN SYSDATE
                        ELSE NULL
                        END FECHA INTO V_RESULTADO
                        FROM DUAL;
    RETURN V_RESULTADO;

    ELSIF P_PERIODO_ENVIO ='Trimestral'

    THEN

                    SELECT
                        CASE
                        WHEN TO_DATE (TRIM(P_FECHA_ENVIO||'-'||(SELECT EXTRACT(YEAR FROM SYSDATE) AS ONLY_CURRENT_DAY FROM DUAL )))=TRUNC(SYSDATE )THEN SYSDATE
                        WHEN TO_DATE (TRIM(P_FECHA_ENVIO||'-'||(SELECT EXTRACT(YEAR FROM SYSDATE) AS ONLY_CURRENT_DAY FROM DUAL ))) + interval '3' MONTH =TRUNC(SYSDATE )THEN SYSDATE
                        WHEN TO_DATE (TRIM(P_FECHA_ENVIO||'-'||(SELECT EXTRACT(YEAR FROM SYSDATE) AS ONLY_CURRENT_DAY FROM DUAL ))) + interval '6' MONTH =TRUNC(SYSDATE )THEN SYSDATE
                        WHEN TO_DATE (TRIM(P_FECHA_ENVIO||'-'||(SELECT EXTRACT(YEAR FROM SYSDATE) AS ONLY_CURRENT_DAY FROM DUAL ))) + interval '9' MONTH =TRUNC(SYSDATE )THEN SYSDATE
                        ELSE NULL
                        END FECHA INTO V_RESULTADO
                        FROM DUAL;

        RETURN V_resultado;

        ELSIF P_PERIODO_ENVIO ='Semi anual'
    THEN

                SELECT
                        CASE
                        WHEN TO_DATE (TRIM(P_FECHA_ENVIO||'-'||(SELECT EXTRACT(YEAR FROM SYSDATE) AS ONLY_CURRENT_DAY FROM DUAL )))=TRUNC(SYSDATE )THEN SYSDATE
                        WHEN TO_DATE (TRIM(P_FECHA_ENVIO||'-'||(SELECT EXTRACT(YEAR FROM SYSDATE) AS ONLY_CURRENT_DAY FROM DUAL ))) + interval '6' MONTH =TRUNC(SYSDATE )THEN SYSDATE
                        ELSE NULL
                        END FECHA INTO V_RESULTADO
                        FROM DUAL;
        RETURN V_resultado;

        ELSIF P_PERIODO_ENVIO ='Mensual'
    THEN
                  SELECT
                  CASE
                       WHEN TO_DATE (
                        EXTRACT(day FROM (TO_DATE (TRIM((P_FECHA_ENVIO||'-ENE')||'-'||(SELECT EXTRACT(YEAR FROM SYSDATE) AS ONLY_CURRENT_DAY FROM DUAL )))))
                        ||'-'||(SELECT EXTRACT(MONTH FROM SYSDATE) AS ONLY_CURRENT_DAY FROM DUAL )
                        ||'-'||(SELECT EXTRACT(YEAR FROM SYSDATE) AS ONLY_CURRENT_YEAR FROM DUAL ),'DD-MM-YYYY')
                          =TRUNC(SYSDATE)THEN SYSDATE
                          ELSE NULL
                        END FECHA into v_resultado
                        FROM DUAL;
                        return v_resultado;

            ELSIF P_PERIODO_ENVIO ='Quincenal'
            THEN
                        SELECT
                       CASE
                       WHEN TO_DATE
                         ((P_FECHA_ENVIO)||'-'||(select to_char(SYSDATE,'MM') from DUAL)||'-'||(select to_char(sysdate,'YYYY') from dual),'DD-MM-YY')
                          =TRUNC(SYSDATE)THEN SYSDATE
                        WHEN
                        TO_DATE
                        ((P_FECHA_ENVIO+15)||'-'||(select to_char(SYSDATE,'MM') from DUAL)||'-'||(select to_char(sysdate,'YYYY') from dual),'DD-MM-YY')=TRUNC(SYSDATE)THEN SYSDATE
                          ELSE NULL
                        END FECHA into v_resultado
                        FROM DUAL;
                        return v_resultado;

            ELSIF P_PERIODO_ENVIO ='Semanal'
            THEN
                   select
                   case
                   when to_char(SYSDATE,'D')= P_FECHA_ENVIO THEN SYSDATE
                   ELSE
                   NULL
                   END FECHA INTO V_RESULTADO
                   FROM dual;
            return v_resultado;
             ELSE
             RETURN NULL;
             commit;
    END IF;
EXCEPTION
    WHEN OTHERS
    THEN
        RETURN NULL;
        commit;
END;

PROCEDURE GEN_FILE_EDO_CTA_TEL ( P_CADENA IN varchar2,P_ORG_ID IN number,P_REQUEST_ID IN NUMBER)
    AS
        --v_filename           VARCHAR2 (4000) := p_filename;

--        v_SENDER             VARCHAR2 (1000) := 'cfdi_ar_oracle@gepp.com';
--        v_subject            VARCHAR2 (1000);
--        v_to_recipients      VARCHAR2 (1000);
--        v_cc_recipients      VARCHAR2 (1000);
--        v_bcc_recipients     VARCHAR2 (1000);
--        p_err_msg            NUMBER;
--        v_service_name       VARCHAR2 (1000);
       --v_zip_name           VARCHAR2 (4000);
        gv_dir               VARCHAR (50) := 'CUST_AR_BOTS_LAYOUT';
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
                                else
                                     V_UOP:=209;
                                     v_worksheet_a:= 'BEPUSA';
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
        apps.gen_xl_xml.set_column_width (6, 70, v_worksheet_a);
        --nuevos campos
        apps.gen_xl_xml.set_column_width (7, 90, v_worksheet_a);
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
        apps.gen_xl_xml.set_column_width (18, 70, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (19, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (20, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (21, 80, v_worksheet_a);
        apps.gen_xl_xml.set_column_width (22, 70, v_worksheet_a);
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
                    from xxar_bots_edo_cta a,
                    xxwebc.xxar_bots_tbl_cust_mails_cs b
                    where 1=1
                    and a.number_a=b.customer_number
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

                                    --nuevos campos

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
                                    'Fecha Estatus',
                                    'titulo_pestana');

      apps.gen_xl_xml.write_cell_CHAR (ra,
                                    19,
                                    v_worksheet_a,
                                    'Importe Original',
                                    'titulo_pestana');

     apps.gen_xl_xml.write_cell_CHAR (ra,
                                    20,
                                    v_worksheet_a,
                                    'Saldo Debido',
                                    'titulo_pestana');

     apps.gen_xl_xml.write_cell_CHAR (ra,
                                    21,
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
                    ,referencia_direccion
                    ,direccion_envio
                    from xxar_bots_edo_cta a,
                    xxwebc.xxar_bots_tbl_cust_mails_cs b
                    where 1=1
                    and a.number_a=b.customer_number
                    and a.number_a=P_CADENA
                    and a.org_id=P_ORG_ID
                    and abs(a.balance_due)>=1.0
                    order by due_date asc

--            AND A.TEXTOPOSICION IN (
--            'MCHID232490',
--            'MAFID273150'
--            )
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
                  --nuevos campos
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
                  END;


           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        8,
                                        v_worksheet_a,
                                        CUR.direccion_envio,
                                        'texto_celda4');
                                        -----
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
                                        TO_CHAR (CUR.acceso_docto,'DD-MON-YYYY'),
                                        'texto_celda4');

           apps.gen_xl_xml.write_cell_num (ra,
                                        19,
                                        v_worksheet_a,
                                        CUR.original_amount,
                                        'num_celda');

           apps.gen_xl_xml.write_cell_num (ra,
                                        20,
                                        v_worksheet_a,
                                        CUR.balance_due,
                                        'num_celda');

           apps.gen_xl_xml.write_cell_CHAR (ra,
                                        21,
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

        ra := ra + 1;

        select      sum (original_amount)
                    ,sum (balance_due) into v_sum_orig_amount,v_sum_balance_due
                    from xxar_bots_edo_cta a,
                    xxwebc.xxar_bots_tbl_cust_mails_cs b
                    where 1=1
                    and a.number_a=b.customer_number
                    and a.number_a=P_CADENA
                    and a.org_id=P_ORG_ID
                    and abs(a.balance_due)>=1.0;

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

        apps.gen_xl_xml.write_cell_num (ra,
                                        19,
                                        v_worksheet_a,
                                        v_sum_orig_amount,
                                        'num_celda');

        apps.gen_xl_xml.write_cell_num (ra,
                                        20,
                                        v_worksheet_a,
                                        v_sum_balance_due,
                                        'num_celda');

                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        21,
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

        apps.gen_xl_xml.write_cell_num (ra,
                                        19,
                                        v_worksheet_a,
                                        v_sum_orig_amount,
                                        'num_celda');

        apps.gen_xl_xml.write_cell_num (ra,
                                        20,
                                        v_worksheet_a,
                                        v_sum_balance_due,
                                        'num_celda');

                                        apps.gen_xl_xml.write_cell_CHAR (ra,
                                        21,
                                        v_worksheet_a,
                                        NULL,
                                        'texto_celda4');
                                        commit;



        apps.gen_xl_xml.close_file;
      -------INSERT
        BEGIN
        IF P_ORG_ID=180
        THEN
        INSERT INTO xxbot.CONTROL_ENV_EDC_TELMEX
                                    (
                                    REQUEST_ID,
                                    CUSTOMER_ID,
                                    CUSTOMER_NUMBER,
                                    PERIODO_ENVIO,
                                    FECHA_ENVIO,
                                    ENV_CORREO,
                                    FILE_IRSA,
                                    FILE_BEP,
                                    CREATION_DATE,
                                    CREATED_BY,
                                    LAST_UPDATE_DATE,
                                    LAST_UPDATE_BY,
                                    MOTIVO
                                    ) VALUES
                                    (
                                    P_REQUEST_ID,
                                    NULL,
                                    P_CADENA,
                                    NULL,
                                    NULL,
                                    'SI',
                                    v_file_name,
                                    NULL,
                                    SYSDATE,
                                    V_USER_ID,
                                    SYSDATE,
                                    V_USER_ID,
                                    NULL);
                                    COMMIT;
        ELSE
                  SELECT COUNT (*) INTO V_COUNT_FILE
                  FROM xxbot.CONTROL_ENV_EDC_TELMEX
                  WHERE 1=1
                  AND REQUEST_ID =P_REQUEST_ID
                  AND CUSTOMER_NUMBER=P_CADENA;

                  IF V_COUNT_FILE >0

                  THEN
                            UPDATE xxbot.CONTROL_ENV_EDC_TELMEX
                                  SET FILE_BEP=v_file_name
                                  WHERE 1=1
                                  AND REQUEST_ID =P_REQUEST_ID
                                  AND CUSTOMER_NUMBER=P_CADENA;
                                  COMMIT;

                  ELSE

                    INSERT INTO xxbot.CONTROL_ENV_EDC_TELMEX
                                    (
                                    REQUEST_ID,
                                    CUSTOMER_ID,
                                    CUSTOMER_NUMBER,
                                    PERIODO_ENVIO,
                                    FECHA_ENVIO,
                                    ENV_CORREO,
                                    FILE_IRSA,
                                    FILE_BEP,
                                    CREATION_DATE,
                                    CREATED_BY,
                                    LAST_UPDATE_DATE,
                                    LAST_UPDATE_BY,
                                    MOTIVO
                                    ) VALUES
                                    (
                                    P_REQUEST_ID,
                                    NULL,
                                    P_CADENA,
                                    NULL,
                                    NULL,
                                    'SI',
                                    NULL,
                                    v_file_name,
                                    SYSDATE,
                                    V_USER_ID,
                                    SYSDATE,
                                    V_USER_ID,
                                    NULL);
                                    COMMIT;
                                    END IF;
         END IF;
         END;

        COMMIT;



        DBMS_OUTPUT.PUT_LINE('Estado de Cuenta Generado con Exito: '||v_file_name);
        apps.MESSAGE_LOG ('Estado de Cuenta Generado con Exito: '||v_file_name);

    END ;

    procedure XXBOT_GENMAS_EDOCTA_TELMEX (errbuf out varchar2,retcode out number)
    is

      P_REQUEST_ID number;
      V_REQUEST_ID number;
      V_USER_ID number;
      v_name varchar2(400);
      --v_zip_name varchar2(400);
      v_SENDER             VARCHAR2 (1000);
       v_subject            VARCHAR2 (1000);
        v_to_recipients      VARCHAR2 (1000);
        v_cc_recipients      VARCHAR2 (1000);
        v_bcc_recipients     VARCHAR2 (1000);
        p_err_msg            NUMBER;
        v_service_name       VARCHAR2 (1000);
       --v_zip_name           VARCHAR2 (4000);
        gv_dir               VARCHAR (50) := 'CUST_AR_BOTS_LAYOUT';
        v_file_name          VARCHAR2 (3000);
        v_worksheet_a VARCHAR2 (1000);
        ra                    NUMBER;
        --v_EstiloCabColumna   VARCHAR2 (100);
        V_estilo_celda       VARCHAR2 (100);
        v_body               VARCHAR2 (4000);
        --V_FN              VARCHAR2(4000);
        V_C_ENV_CORREO number;
         v_file_name_2 varchar2(100);
        v_fnamea utl_file.file_type;
        v_LOG VARCHAR2 (400);
        v_MAILBODY VARCHAR2 (400);
        v_PHONE  VARCHAR2 (400);
        v_SENDMAIL  VARCHAR2 (400);
       v_MAILEC  VARCHAR2 (400);
       v_GS  VARCHAR2 (400);
       v_WAY NUMBER;
       v_exception exception;



   BEGIN

        P_REQUEST_ID:=-1;

        IF P_REQUEST_ID = -1 THEN
        V_REQUEST_ID:= NVL( FND_GLOBAL.CONC_REQUEST_ID,0);
        ELSE
        V_REQUEST_ID := P_REQUEST_ID;
        END IF;
        V_USER_ID := NVL( FND_GLOBAL.USER_ID,0);

        APPS.MESSAGE_LOG('INICIA PROCESO');
        DBMS_OUTPUT.PUT_LINE('INICIA PROCESO');

                        BEGIN
                        EXECUTE IMMEDIATE
                        'ALTER SESSION SET NLS_LANGUAGE =  "latin american spanish" ';
                        DBMS_OUTPUT.PUT_LINE('OK');
                        EXCEPTION WHEN OTHERS
                        THEN
                        DBMS_OUTPUT.PUT_LINE('FALLA EN SETEO DE LENGUAJE'||SQLERRM);
                        END;

        ---BORRA ARCHIVOS RESAGADOS
--                    BEGIN
--
--                    for cur in ( SELECT COLUMN_VALUE FILENAME
--                    FROM TABLE(APPS.LIST_FILES('/u07/cargas/ar/edos_cuenta'))
--                    WHERE 1=1
--                    and COLUMN_VALUE not in ('zipped'))
--
--                            loop
--                            UTL_FILE.fremove (gv_dir, CUR.FILENAME);
--                            COMMIT;
--                            END LOOP;
--                     END;
                     -----
 ----------------------BUSCA CADENAS A GENERAR ESTADO DE CUENTA



                    BEGIN
                            FOR CUR IN (select CUSTOMER_NUMBER
                                                from xxwebc.xxar_bots_tbl_cust_mails_cs a
                                                                 where 1=1
                                                                 )

                            LOOP
                            insert into XXBOT.TABLERO_EDC_TELMEX
                            (
                            select
                            distinct(D.CUSTOMER_ID) AS CUSTOMER_ID
                            ,d.customer_number
                            ,A.email_address||';|' as email_address
                            ,i.PERIODO_ENVIO
                            ,i.FECHA_ENVIO
                            --,e.MEANING as periodo_envio
                            --,c.tolerance as Fecha_envio
                            ,XXBOT.XXAR_BOTS_ACT_EDO_CTA.GET_SEND_DATE(i.PERIODO_ENVIO,i.FECHA_ENVIO) AS FECHA_CALC
                            ,V_REQUEST_ID AS REQUEST_ID
                            from apps.AR_CONTACTS_V a
                            ,apps.HZ_CONTACT_FIND_V b
                            --,AR.HZ_CUSTOMER_PROFILES C
                            ,apps.ar_customers d
                            --,apps.FND_LOOKUP_VALUES_VL e
                            ,apps.hz_parties f
                            ,apps.hz_cust_accounts g
                            ,xxwebc.xxar_bots_tbl_cust_mails_cs h
                            ,XXBOT.XXAR_SEND_RULES_ECTELMEX_L i
                            where 1=1
                            and i.customer_id =b.customer_id
                            and i.customer_id =a.customer_id
                            and i.customer_id =d.customer_id
                            and d.customer_id =b.customer_id
                            and a.customer_id=d.customer_id
                            and a.CONTACT_NUMBER=b.CONTACT_NUMBER
                            and a.customer_id =b.customer_id
                            and d.customer_id=h.customer_id
                            and a.customer_id=h.customer_id
                            and b.customer_id=h.customer_id
                            and d.customer_number =CUR.CUSTOMER_NUMBER
                            --AND C.CUST_ACCOUNT_ID=a.customer_id
                            --and c.ACCOUNT_STATUS(+)=e.LOOKUP_CODE
                            --and e.LOOKUP_TYPE = 'ACCOUNT_STATUS'
                            AND g.cust_account_id  =d.customer_id
                            AND g.party_id = F.party_id
                            and b.CONTACT_NUMBER like 'EC-%'
                            AND B.STATUS='A'
                            and i.ACTIVO='SI'

                            );
                            commit;
                            end loop;
                            END;
                            commit;



-- GENERO ESTADOS DE CUENTA A ENVIAR PARA IRSA
                            BEGIN

                            for cur in (
                            select  distinct (b.customer_number)
                                    from XXBOT.TABLERO_EDC_TELMEX b
                                    where 1=1
                                    and trunc(FECHA_CALC)=trunc(sysdate)
                                    and fecha_calc is not null
                                    and request_id=v_request_id
                                    and b.customer_id   in (
                                                            select DISTINCT(a.customer_id)
                                                            from xxbot.xxar_bots_edo_cta a,XXBOT.TABLERO_EDC_TELMEX b
                                                            where 1=1
                                                             and a.customer_id=b.customer_id
                                                             AND A.ORG_ID=180
                                                             and b.REQUEST_ID=v_request_id
                                                             AND abs(A.BALANCE_DUE) >=1.0
                                                             and trunc(B.FECHA_CALC)=trunc(sysdate)
                                                             and B.fecha_calc is not null
                                                             )
                                                              )

                            loop
                            GEN_FILE_EDO_CTA_TEL ( CUR.customer_number,180,V_REQUEST_ID);
                            COMMIT;
                            END LOOP;
                            END;
                            commit;

--GENERO ESTADOS DE CUENTA PARA ENVIAR BEPUSA

                            BEGIN

                            for cur in (
                            select  distinct (b.customer_number)
                                    from XXBOT.TABLERO_EDC_TELMEX b
                                    where 1=1
                                    and trunc(FECHA_CALC)=trunc(sysdate)
                                    and fecha_calc is not null
                                    and request_id=v_request_id
                                    and b.customer_id   in (
                                                            select DISTINCT(a.customer_id)
                                                            from xxbot.xxar_bots_edo_cta a,XXBOT.TABLERO_EDC_TELMEX b
                                                            where 1=1
                                                             and a.customer_id=b.customer_id
                                                             AND A.ORG_ID=84
                                                             AND abs(A.BALANCE_DUE) >=1.0
                                                             and trunc(B.FECHA_CALC)=trunc(sysdate)
                                                             and B.fecha_calc is not null
                                                             and B.request_id=v_request_id
                                                             )
                                                              )

                            loop
                            GEN_FILE_EDO_CTA_TEL ( CUR.customer_number,84,V_REQUEST_ID);
                            COMMIT;
                            END LOOP;
                            END;
                            commit;

--ACTUALIZO CONTROL DE NO ENVIADOS POR FECHA

                              BEGIN

                                for cur in (
                                select  B.*
                                        from XXBOT.TABLERO_EDC_TELMEX b
                                        where 1=1
                                        and fecha_calc is Null
                                        and request_id=v_request_id)

                            loop
                            INSERT INTO xxbot.CONTROL_ENV_EDC_TELMEX
                                    (
                                    REQUEST_ID,
                                    CUSTOMER_ID,
                                    CUSTOMER_NUMBER,
                                    PERIODO_ENVIO,
                                    FECHA_ENVIO,
                                    ENV_CORREO,
                                    FILE_IRSA,
                                    FILE_BEP,
                                    CREATION_DATE,
                                    CREATED_BY,
                                    LAST_UPDATE_DATE,
                                    LAST_UPDATE_BY,
                                    MOTIVO
                                    ) VALUES
                                    (
                                    CUR.REQUEST_ID,
                                    CUR.CUSTOMER_ID,
                                    CUR.CUSTOMER_NUMBER,
                                    CUR.PERIODO_ENVIO,
                                    CUR.FECHA_ENVIO,
                                    'NO',
                                    NULL,
                                    NULL,
                                    SYSDATE,
                                    V_USER_ID,
                                    SYSDATE,
                                    V_USER_ID,
                                    'NO ENV. EN FUNCIÓN A LA FECHA_ENV');
                            COMMIT;
                            END LOOP;
                            END;
                            commit;


--ACTUALIZO CONTROL DE NO ENVIADOS POR QUE NO GENERÓ EDO CUENTA
                                BEGIN

                                for cur in (
                                select  B.*
                                    from XXBOT.TABLERO_EDC_TELMEX b
                                    where 1=1
                                    and trunc(FECHA_CALC)=trunc(sysdate)
                                    and fecha_calc is not null
                                    and request_id=v_request_id
                                    and b.customer_id   NOT in (
                                                            select DISTINCT(a.customer_id)
                                                            from xxbot.xxar_bots_edo_cta a,XXBOT.TABLERO_EDC_TELMEX b
                                                            where 1=1
                                                             and a.customer_id=b.customer_id
                                                             AND A.ORG_ID in (180,84)
                                                             and abs(a.balance_due)>=1.0
                                                             and trunc(B.FECHA_CALC)=trunc(sysdate)
                                                             and B.fecha_calc is not null
                                                             and B.request_id=v_request_id
                                                             )
                                                              )

                            loop
                            INSERT INTO xxbot.CONTROL_ENV_EDC_TELMEX
                                    (
                                    REQUEST_ID,
                                    CUSTOMER_ID,
                                    CUSTOMER_NUMBER,
                                    PERIODO_ENVIO,
                                    FECHA_ENVIO,
                                    ENV_CORREO,
                                    FILE_IRSA,
                                    FILE_BEP,
                                    CREATION_DATE,
                                    CREATED_BY,
                                    LAST_UPDATE_DATE,
                                    LAST_UPDATE_BY,
                                    MOTIVO
                                    ) VALUES
                                    (
                                    CUR.REQUEST_ID,
                                    CUR.CUSTOMER_ID,
                                    CUR.CUSTOMER_NUMBER,
                                    CUR.PERIODO_ENVIO,
                                    CUR.FECHA_ENVIO,
                                    'NO',
                                    NULL,
                                    NULL,
                                    SYSDATE,
                                    V_USER_ID,
                                    SYSDATE,
                                    V_USER_ID,
                                    'NO ENV. NO GENERÓ EDO_CTA');
                            COMMIT;
                            END LOOP;
                            END;
                            commit;

--HAGO EL UPDATE DE LOS ENVIADOS
                              BEGIN

                                for cur in (
                                select  a.*
                                    from XXBOT.TABLERO_EDC_TELMEX a,xxbot.CONTROL_ENV_EDC_TELMEX b
                                    where 1=1
                                    and a.request_id=b.request_id
                                    and a.request_id=v_request_id
                                    and a.customer_number=b.customer_number
                                    and b.ENV_CORREO='SI'
                                                             )


                            loop

                            UPDATE xxbot.CONTROL_ENV_EDC_TELMEX A
                            SET A.CUSTOMER_ID=cur.CUSTOMER_ID,
                                A.PERIODO_ENVIO=cur.PERIODO_ENVIO,
                                A.FECHA_ENVIO=cur.FECHA_ENVIO
                                WHERE 1=1
                                AND A.CUSTOMER_NUMBER=CUR.CUSTOMER_NUMBER
                                and a.request_id=cur.REQUEST_ID
                                AND A.ENV_CORREO='SI';
                            COMMIT;
                            END LOOP;
                            END;
                            commit;

-- ENVÍO CORREOS DOS ADJUNTOS
                            BEGIN

                                for cur in (
                                            select  a.CUSTOMER_NUMBER
                                            ,b.FILE_BEP
                                            ,B.FILE_IRSA
                                            ,SUBSTR(A.EMAIL_ADDRESS,0,INSTR(a.EMAIL_ADDRESS,';')-1) as CORREO_PRINCIPAL
                                            ,CASE
                                            WHEN REPLACE (SUBSTR(a.EMAIL_ADDRESS,INSTR(A.EMAIL_ADDRESS,';')+1),';|','') ='|' THEN  REPLACE(REPLACE (SUBSTR(A.EMAIL_ADDRESS,INSTR(A.EMAIL_ADDRESS,';')+1),';|',''),'|','')
                                            ELSE
                                            REPLACE (SUBSTR(a.EMAIL_ADDRESS,INSTR(A.EMAIL_ADDRESS,';')+1),';|','')
                                            END
                                            as Correos_Secundarios
                                    from XXBOT.TABLERO_EDC_TELMEX a,xxbot.CONTROL_ENV_EDC_TELMEX b
                                    where 1=1
                                    and a.request_id=b.request_id
                                    and a.request_id=v_request_id
                                    and a.customer_number=b.customer_number
                                    and b.ENV_CORREO='SI'
                                    AND b.FILE_IRSA IS NOT NULL
                                    AND b.FILE_BEP IS NOT NULL
                                                             )

                            loop

                            v_to_recipients:=cur.CORREO_PRINCIPAL;
                            v_cc_recipients:=cur.Correos_Secundarios;

--                            SELECT VALUE
--                  INTO v_service_name
--                  FROM v$parameter
--                   WHERE 1 = 1 AND NAME = 'instance_name';
v_way:=0;

XXBOT.XXAR_PAY_NOTIF_SYSTEM.XXBOT_GET_DATA_PROFILE (cur.CUSTOMER_NUMBER,v_LOG,v_MAILBODY, v_PHONE,v_SENDMAIL,v_SENDER,v_GS,v_WAY);

if v_way=1
then
raise v_exception;
end if;

                BEGIN
                v_body :=
                       '</b>Buen día estimado cliente.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Por este medio le hacemos llegar su estado de cuenta al corte del día de ayer. Favor de hacer caso omiso si ya realizó el pago de los documentos vencidos.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Recuerde que por cada pago realizado es importante enviar un soporte del mismo, así como la relación de las facturas pagadas a la siguiente cuenta de correo '||v_MAILBODY||'.</b>'
                    || '<br>'
                    || '</b>Mismas que servirán para generar su complemento de pago.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Aprovechamos para recordarle que al momento de hacer sus transferencias debe utilizar la referencia de pago que se incluye en cada factura.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Finalmente, ponemos a su disposición el siguiente portal https://www.facturagepp.com.mx para que pueda descargar sus facturas y la siguiente linea telefónica</b>'
                    || '<br>'
                    || '</b>en caso de necesitar alguna ayuda: ' ||v_phone||'</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Atentamente,</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Departamento de Cobranza GEPP</b>'
                    || '<br>'
                    || '<br>'
                    || '<u><FONT COLOR="red">NOTA:</FONT><FONT COLOR="blue"> Esta cuenta de correo no es monitoreada, favor de no responder</FONT></u>'
                    || '<b>';


                v_subject :=
                       'Envío Estado de cuenta GEPP -  '
                    || CUR.CUSTOMER_NUMBER;



--                SELECT LISTAGG (MEANING, ';') WITHIN GROUP (ORDER BY MEANING)
--                  INTO v_to_recipients
--                  FROM FND_LOOKUP_VALUES_VL
--                 WHERE     LOOKUP_TYPE = 'CUST_AP_MAIL_FACTORAJE_LKP'
--                       AND enabled_flag = 'Y'
--                       AND NVL (END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE;
                apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                                      P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                                      P_RECIPIENT     =>v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                                      P_CC            =>v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                                      P_BCC           =>v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                                      P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                                      P_BODY          => v_body,             -- Cuerpo
                                      P_ATTACHMENT1   => cur.file_irsa,
                                      P_ATTACHMENT2   => cur.file_bep, --Archivo a enviar
                                      P_ERROR         => p_err_msg);

                                      DBMS_LOCK.SLEEP('5');
                                      APPS.MESSAGE_LOG('Prepara Correo_IB');
                                      APPS.MESSAGE_LOG('Correo Enviado -  '|| CUR.CUSTOMER_NUMBER);
                       EXCEPTION
                       when v_exception then  APPS.MESSAGE_LOG('Falta de configuración de datos de envío -  '|| CUR.CUSTOMER_NUMBER);
                       WHEN OTHERS
                       THEN
                            APPS.MESSAGE_LOG('Error al enviar correo de la cadena -  '|| CUR.CUSTOMER_NUMBER);
                       end;
                            COMMIT;
                            END LOOP;
                            END;
                            commit;

-- ENVÍO CORREOS un adjunto (irsa)
                            BEGIN

                                for cur in (
                                            select  a.CUSTOMER_NUMBER
                                            ,B.FILE_IRSA
                                            ,SUBSTR(A.EMAIL_ADDRESS,0,INSTR(a.EMAIL_ADDRESS,';')-1) as CORREO_PRINCIPAL
                                            ,CASE
                                            WHEN REPLACE (SUBSTR(a.EMAIL_ADDRESS,INSTR(A.EMAIL_ADDRESS,';')+1),';|','') ='|' THEN  REPLACE(REPLACE (SUBSTR(A.EMAIL_ADDRESS,INSTR(A.EMAIL_ADDRESS,';')+1),';|',''),'|','')
                                            ELSE
                                            REPLACE (SUBSTR(a.EMAIL_ADDRESS,INSTR(A.EMAIL_ADDRESS,';')+1),';|','')
                                            END
                                            as Correos_Secundarios
                                    from XXBOT.TABLERO_EDC_TELMEX a,xxbot.CONTROL_ENV_EDC_TELMEX b
                                    where 1=1
                                    and a.request_id=b.request_id
                                    and a.request_id=v_request_id
                                    and a.customer_number=b.customer_number
                                    and b.ENV_CORREO='SI'
                                    AND b.FILE_IRSA IS NOT NULL
                                    AND b.FILE_BEP IS NULL
                                                             )


                            loop

                             v_to_recipients:=cur.CORREO_PRINCIPAL;
                            v_cc_recipients:=cur.Correos_Secundarios;

                            --                            SELECT VALUE
--                  INTO v_service_name
--                  FROM v$parameter
--                   WHERE 1 = 1 AND NAME = 'instance_name';
v_way:=0;

XXBOT.XXAR_PAY_NOTIF_SYSTEM.XXBOT_GET_DATA_PROFILE (cur.CUSTOMER_NUMBER,v_LOG,v_MAILBODY, v_PHONE,v_SENDMAIL,v_SENDER,v_GS,v_WAY);

if v_way=1
then
raise v_exception;
end if;

                BEGIN
                v_body :=
                       '</b>Buen día estimado cliente.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Por este medio le hacemos llegar su estado de cuenta al corte del día de ayer. Favor de hacer caso omiso si ya realizó el pago de los documentos vencidos.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Recuerde que por cada pago realizado es importante enviar un soporte del mismo, así como la relación de las facturas pagadas a la siguiente cuenta de correo '||v_MAILBODY||'.</b>'
                    || '<br>'
                    || '</b>Mismas que servirán para generar su complemento de pago.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Aprovechamos para recordarle que al momento de hacer sus transferencias debe utilizar la referencia de pago que se incluye en cada factura.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Finalmente, ponemos a su disposición el siguiente portal https://www.facturagepp.com.mx para que pueda descargar sus facturas y la siguiente linea telefónica</b>'
                    || '<br>'
                    || '</b>en caso de necesitar alguna ayuda: ' ||v_phone||'</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Atentamente,</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Departamento de Cobranza GEPP</b>'
                    || '<br>'
                    || '<br>'
                    || '<u><FONT COLOR="red">NOTA:</FONT><FONT COLOR="blue"> Esta cuenta de correo no es monitoreada, favor de no responder</FONT></u>'
                    || '<b>';


                v_subject :=
                       'Envío Estado de cuenta GEPP -  '
                    || CUR.CUSTOMER_NUMBER;



--                SELECT LISTAGG (MEANING, ';') WITHIN GROUP (ORDER BY MEANING)
--                  INTO v_to_recipients
--                  FROM FND_LOOKUP_VALUES_VL
--                 WHERE     LOOKUP_TYPE = 'CUST_AP_MAIL_FACTORAJE_LKP'
--                       AND enabled_flag = 'Y'
--                       AND NVL (END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE;
                apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                                      P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                                      P_RECIPIENT     =>v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                                      P_CC            =>v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                                      P_BCC           =>v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                                      P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                                      P_BODY          => v_body,             -- Cuerpo
                                      P_ATTACHMENT1   => cur.file_irsa,
                                      P_ATTACHMENT2   => null, --Archivo a enviar
                                      P_ERROR         => p_err_msg);

                                      DBMS_LOCK.SLEEP('3');
                                      APPS.MESSAGE_LOG('Prepara Correo_I');
                                      APPS.MESSAGE_LOG('Correo Enviado -  '|| CUR.CUSTOMER_NUMBER);
                       EXCEPTION
                       when v_exception then  APPS.MESSAGE_LOG('Falta de configuración de datos de envío -  '|| CUR.CUSTOMER_NUMBER);
                       WHEN OTHERS
                       THEN
                            APPS.MESSAGE_LOG('Error al enviar correo de la cadena -  '|| CUR.CUSTOMER_NUMBER);
                       end;
                            COMMIT;
                            END LOOP;
                            END;
                            commit;

-- ENVÍO CORREOS un adjunto (bepusa)
                            BEGIN

                                for cur in (
                                            select  a.CUSTOMER_NUMBER
                                            ,B.FILE_bep
                                            ,SUBSTR(A.EMAIL_ADDRESS,0,INSTR(a.EMAIL_ADDRESS,';')-1) as CORREO_PRINCIPAL
                                            ,CASE
                                            WHEN REPLACE (SUBSTR(a.EMAIL_ADDRESS,INSTR(A.EMAIL_ADDRESS,';')+1),';|','') ='|' THEN  REPLACE(REPLACE (SUBSTR(A.EMAIL_ADDRESS,INSTR(A.EMAIL_ADDRESS,';')+1),';|',''),'|','')
                                            ELSE
                                            REPLACE (SUBSTR(a.EMAIL_ADDRESS,INSTR(A.EMAIL_ADDRESS,';')+1),';|','')
                                            END
                                            as Correos_Secundarios
                                    from XXBOT.TABLERO_EDC_TELMEX a,xxbot.CONTROL_ENV_EDC_TELMEX b
                                    where 1=1
                                    and a.request_id=b.request_id
                                    and a.request_id=v_request_id
                                    and a.customer_number=b.customer_number
                                    and b.ENV_CORREO='SI'
                                    AND b.FILE_IRSA IS NULL
                                    AND b.FILE_BEP IS not NULL
                                                             )


                            loop
                             v_to_recipients:=cur.CORREO_PRINCIPAL;
                            v_cc_recipients:=cur.Correos_Secundarios;

                                                        --                            SELECT VALUE
--                  INTO v_service_name
--                  FROM v$parameter
--                   WHERE 1 = 1 AND NAME = 'instance_name';
v_way:=0;

XXBOT.XXAR_PAY_NOTIF_SYSTEM.XXBOT_GET_DATA_PROFILE (cur.CUSTOMER_NUMBER,v_LOG,v_MAILBODY, v_PHONE,v_SENDMAIL,v_SENDER,v_GS,v_WAY);

if v_way=1
then
raise v_exception;
end if;

                BEGIN
                v_body :=
                       '</b>Buen día estimado cliente.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Por este medio le hacemos llegar su estado de cuenta al corte del día de ayer. Favor de hacer caso omiso si ya realizó el pago de los documentos vencidos.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Recuerde que por cada pago realizado es importante enviar un soporte del mismo, así como la relación de las facturas pagadas a la siguiente cuenta de correo '||v_MAILBODY||'.</b>'
                    || '<br>'
                    || '</b>Mismas que servirán para generar su complemento de pago.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Aprovechamos para recordarle que al momento de hacer sus transferencias debe utilizar la referencia de pago que se incluye en cada factura.</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Finalmente, ponemos a su disposición el siguiente portal https://www.facturagepp.com.mx para que pueda descargar sus facturas y la siguiente linea telefónica</b>'
                    || '<br>'
                    || '</b>en caso de necesitar alguna ayuda: ' ||v_phone||'</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Atentamente,</b>'
                    || '<br>'
                    || '<br>'
                    || '</b>Departamento de Cobranza GEPP</b>'
                    || '<br>'
                    || '<br>'
                    || '<u><FONT COLOR="red">NOTA:</FONT><FONT COLOR="blue"> Esta cuenta de correo no es monitoreada, favor de no responder</FONT></u>'
                    || '<b>';


                v_subject :=
                       'Envío Estado de cuenta GEPP -  '
                    || CUR.CUSTOMER_NUMBER;



--                SELECT LISTAGG (MEANING, ';') WITHIN GROUP (ORDER BY MEANING)
--                  INTO v_to_recipients
--                  FROM FND_LOOKUP_VALUES_VL
--                 WHERE     LOOKUP_TYPE = 'CUST_AP_MAIL_FACTORAJE_LKP'
--                       AND enabled_flag = 'Y'
--                       AND NVL (END_DATE_ACTIVE, SYSDATE + 1) >= SYSDATE;
                apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                                      P_SENDER        => v_SENDER, -- Cuenta desde donde se envia el correo
                                      P_RECIPIENT     =>v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                                      P_CC            =>v_cc_recipients,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                                      P_BCC           =>v_bcc_recipients,--'CarlosEduardo.Davila@gepp.com',
                                      P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                                      P_BODY          => v_body,             -- Cuerpo
                                      P_ATTACHMENT1   => cur.file_bep,
                                      P_ATTACHMENT2   => null, --Archivo a enviar
                                      P_ERROR         => p_err_msg);

                                     DBMS_LOCK.SLEEP('3');
                                      APPS.MESSAGE_LOG('Prepara Correo_B');
                                      APPS.MESSAGE_LOG('Correo Enviado -  '|| CUR.CUSTOMER_NUMBER);
                       EXCEPTION
                       when v_exception then  APPS.MESSAGE_LOG('Falta de configuración de datos de envío -  '|| CUR.CUSTOMER_NUMBER);
                       WHEN OTHERS
                       THEN
                            APPS.MESSAGE_LOG('Error al enviar correo de la cadena -  '|| CUR.CUSTOMER_NUMBER);
                       end;
                            COMMIT;
                            END LOOP;
                            END;
                            commit;

-- elimino archivos IRSA

                                BEGIN

                            for cur in (
                            select a.FILE_IRSA
                            from xxbot.CONTROL_ENV_EDC_TELMEX a
                            where 1=1
                            and a.request_id=v_request_id
                            and a.ENV_CORREO='SI'
                            AND a.FILE_IRSA IS NOT NULL
                                                              )

                            loop
                            UTL_FILE.fremove (gv_dir, CUR.FILE_IRSA);
                            COMMIT;
                            END LOOP;
                            END;
                            commit;

-- elimino archivos BEPUSA

                                BEGIN

                            for cur in (
                            select a.FILE_BEP
                            from xxbot.CONTROL_ENV_EDC_TELMEX a
                            where 1=1
                            and a.request_id=v_request_id
                            and a.ENV_CORREO='SI'
                            AND a.FILE_BEP IS NOT NULL
                                                              )

                            loop
                            UTL_FILE.fremove (gv_dir, CUR.FILE_BEP);
                            COMMIT;
                            END LOOP;
                            END;
                            commit;

                            begin
                V_C_ENV_CORREO:=0;
                                        select  COUNT (*) INTO V_C_ENV_CORREO
                                        from xxbot.CONTROL_ENV_EDC_TELMEX
                                        where 1=1
                                        AND env_correo='SI'
                                        and  request_id=V_REQUEST_ID;

                 IF V_C_ENV_CORREO >0
                 THEN

                   v_file_name_2 :='Control_envCTel_'
                                    || TO_CHAR (SYSDATE,'DDMMYYYY')
                                    || '.csv';



                   v_fnamea := utl_file.fopen (gv_dir,v_file_name_2, 'w');

                    utl_file.put(v_fnamea,'CADENA');
                    utl_file.put(v_fnamea,',PERIODO ENVIO');
                    utl_file.put(v_fnamea,',FECHA ENVIO');
                    utl_file.put(v_fnamea,',ENVIO CORREO');
                    utl_file.put(v_fnamea,',ARCHIVO IRSA');
                    utl_file.put(v_fnamea,',ARCHIVO BEPUSA');
                    utl_file.put(v_fnamea,',MOTIVO DE NO ENV.');
                    utl_file.new_line(v_fnamea);


                   FOR CUR1
                            IN (
                                    select *
                                        from xxbot.CONTROL_ENV_EDC_TELMEX
                                        where 1=1
                                        and  request_id=V_REQUEST_ID
                                                                                    )


                    loop
                    utl_file.put(v_fnamea,cur1.CUSTOMER_NUMBER);
                    utl_file.put(v_fnamea,','||cur1.PERIODO_ENVIO);
                    utl_file.put(v_fnamea,','||cur1.FECHA_ENVIO);
                    utl_file.put(v_fnamea,','||cur1.ENV_CORREO);
                    utl_file.put(v_fnamea,','||cur1.FILE_IRSA);
                    utl_file.put(v_fnamea,','||cur1.FILE_BEP);
                    utl_file.put(v_fnamea,','||cur1.MOTIVO);
                    utl_file.new_line(v_fnamea);
                    end loop;
                    utl_file.fclose(v_fnamea);

                    v_body :=
                       '</B>Notificación de Envío Masivo de Estados de Cuenta CT Proyecto Telmex</B>'
                    || '<br>'
                    || '<br>'
                    || '</B>Adjunto a este correo encontrará el archivo control con el resumen de los archivos generados y el envío de los estados de cuenta al cliente</B>'
                    || '<br>'
                    || '<br>'
                    || '</B>ID de la solicitud: '||v_request_id||'</B>'
                    || '<br>'
                    || '<br>'
                    || '</B>Proceso de Generación Ejecutado Correctamente.</B>';


                v_subject :=
                       'Notificación Envío Masivo Correos CT '||TO_CHAR(SYSDATE,'DD/MM/YYYY');
                apps.cust_mail.send_email (P_DIRECTORY     => gv_dir,         -- Directorio
                                      P_SENDER        => 'cfdi_ar_oracle@gepp.com', -- Cuenta desde donde se envia el correo
                                      P_RECIPIENT     => 'eduardo.ruizmares@gepp.com',--'martin.dominguez@gepp.com;eduardo.ruizmares@gepp.com;zammis.gonzalez@gepp.com',--v_to_recipients,--;ernesto.eugenio@pepsico.com', -- Cuentas que reciben el correo
                                      P_CC            => null,--'Victor.Santana@gepp.com;alejandro.romo@gepp.com',    -- Con Copia para
                                      P_BCC           => 'alejandro.romo@gepp.com',--'CarlosEduardo.Davila@gepp.com',
                                      P_SUBJECT       => v_subject, --'Envio de archivo de proceso EDI-Oracle', --Asunto
                                      P_BODY          => v_body,             -- Cuerpo
                                      P_ATTACHMENT1   => v_file_name_2,--v_file_name_2, --Archivo a enviar
                                      P_ERROR         => p_err_msg);
                                      commit;


                                                    begin
                                                    UTL_FILE.fremove (gv_dir,v_file_name_2);
                                                    exception
                                                    when others
                                                    then
                                                    dbms_output.put_line('error al enviar archivo de control');
                                                    APPS.MESSAGE_LOG('error al enviar archivo de control');
                                                    end;
                                                    commit;
                    ELSE
                    dbms_output.put_line('NO SE ENVÍA CORREO DE VALIDACIÓN');
                    APPS.MESSAGE_LOG('NO SE ENVÍA CORREO DE VALIDACIÓN');
                    END IF;
                    commit;



END;



   EXCEPTION
   WHEN OTHERS THEN
   dbms_output.put_line('Error al ejecutarse el proceso_masivo de envío de correos Telmex - '||SQLCODE||' -ERROR- '||SQLERRM);
   APPS.MESSAGE_LOG('Error al ejecutarse el proceso_masivo de envío de correos Telmex - '||SQLCODE||' -ERROR- '||SQLERRM);
   commit;
   END;

   FUNCTION get_data_on (      p_data        IN VARCHAR2,
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
    END get_data_on;

--    procedure xxbot_update_rulesedc(errbuf out varchar2,retcode out number, P_REQUEST_ID IN NUMBER,p_file_name varchar2)
--    is
--
--        v_file         UTL_FILE.file_type;
--        vgDirectory varchar2(1000):= 'CUST_AR_BOTS_LAYOUT';
--        v_line    VARCHAR2 (4000);
--        v_line_number number;
--        v_file_name varchar2(1000);
--      V_REQUEST_ID number;
--      V_USER_ID number;
--      v_c_procedure number;
--      v_prefijo VARCHAR2(1000):='LAY_RE_EDC_CT_';
--      v_applied VARCHAR2(100);
--      V_CUSTOMER_NUMBER VARCHAR2(100);
--      V_PERIODO_ENVIO VARCHAR2(20);
--      V_FECHA_ENVIO VARCHAR2(20);
--      V_ACTIVO VARCHAR2(20);
--
--
--
--   BEGIN
--
--
--        IF P_REQUEST_ID = -1 THEN
--        V_REQUEST_ID:= NVL( FND_GLOBAL.CONC_REQUEST_ID,0);
--        ELSE
--        V_REQUEST_ID := P_REQUEST_ID;
--        END IF;
--        V_USER_ID := NVL( FND_GLOBAL.USER_ID,0);
--
--        APPS.MESSAGE_LOG('INICIA PROCESO CICLO DE REV. Y FECHA DE ENV.');
--
--
--            --apps.fnd_global.set_nls_context('Latin American Spanish');
--
--        v_file := SYS.UTL_FILE.fopen(vgDirectory,p_file_name,'R');
--        APPS.MESSAGE_LOG('OPEN FILE');
--
--        v_file_name := P_FILE_NAME;
--
--       IF substr(v_file_name,1,14) = v_prefijo THEN
--
--
--          v_applied := NULL;
--
--                        FOR cur IN (SELECT NVL(APPLIED,'N') APPLIED, REQUEST_ID
--                                        FROM XXBOT.XXAR_SEND_RULES_ECTELMEX_H
--                                        WHERE 1=1
--                                        AND FILE_NAME = v_file_name)
--                        LOOP
--                            v_applied := cur.APPLIED;
--                            IF cur.applied = 'N' THEN
--                                -- Si el archivo no ha sido procesado lo borra de la tabla
--                                DELETE XXBOT.XXAR_SEND_RULES_ECTELMEX_H
--                                WHERE 1=1
--                                AND REQUEST_ID =cur.request_id;
--                                DELETE XXBOT.XXAR_SEND_RULES_ECTELMEX_L
--                                WHERE 1=1
--                                AND REQUEST_ID =cur.request_id;
--                                COMMIT;
--                            END IF;
--
--                        END LOOP;
--
--            IF v_applied IS NULL OR v_applied ='N' THEN
--            dbms_output.put_line('procesa archivo');
--             APPS.MESSAGE_LOG('procesa archivo');
--            v_line_number:=0;
--
--
--            begin
--            delete XXBOT.XXAR_SEND_RULES_ECTELMEX_L
--            where 1=1;
--            commit;
--            end;
--
--                        LOOP
--                            BEGIN
--                                SYS.UTL_FILE.get_line (v_file, v_line);
--                                v_line_number := v_line_number + 1;
--
--                                 if v_line_number>1 then
--
--
--                                      V_CUSTOMER_NUMBER:=get_data_on(V_LINE,1,',');
--                                      V_PERIODO_ENVIO := get_data_on(V_LINE,2,',');
--                                      V_FECHA_ENVIO:= get_data_on(V_LINE,3,',');
--                                      V_ACTIVO:= get_data_on(V_LINE,4,',');
--
--
--                                           INSERT INTO XXBOT.XXAR_SEND_RULES_ECTELMEX_L (
--                                              REQUEST_ID,
--                                              CUSTOMER_ID,
--                                              CUSTOMER_NUMBER,
--                                              PERIODO_ENVIO,
--                                              FECHA_ENVIO,
--                                              ACTIVO,
--                                              CREATION_DATE,
--                                              CREATED_BY,
--                                              LAST_UPDATE_DATE,
--                                              LAST_UPDATE_BY
--                                              )
--                                            VALUES(
--                                              V_REQUEST_ID,
--                                              null,
--                                              V_CUSTOMER_NUMBER,
--                                              V_PERIODO_ENVIO,
--                                              V_FECHA_ENVIO,
--                                              V_ACTIVO,
--                                              sysdate,
--                                              V_USER_ID,
--                                              sysdate,
--                                              V_USER_ID
--                                                 );
--
--
--                                 end if;
--
--                            EXCEPTION
--                            WHEN NO_DATA_FOUND THEN
--                                EXIT;
--                            END;
--                        END LOOP;
--
--                                BEGIN
--
--                                for cur in (
--                                select  B.CUSTOMER_ID,B.CUSTOMER_NUMBER
--                                        from XXBOT.XXAR_SEND_RULES_ECTELMEX_L A,apps.ar_customers b
--                                        where 1=1
--                                        and A.CUSTOMER_NUMBER=b.CUSTOMER_NUMBER
--                                        and A.request_id=v_request_id)
--
--                                        loop
--                                        UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_L A
--                                        SET A.CUSTOMER_ID=cur.CUSTOMER_ID
--                                        WHERE 1=1
--                                        AND A.CUSTOMER_NUMBER=cur.CUSTOMER_NUMBER ;
--                                        COMMIT;
--                                        END LOOP;
--                                END;
--                                commit;
--
--
--
--                        SYS.UTL_FILE.fclose(V_FILE);
--                        BEGIN
--                            SYS.UTL_FILE.FREMOVE (vgDirectory,p_file_name);
--
--                        EXCEPTION
--                            WHEN OTHERS THEN
--                                NULL;
--                        END;
--
--                        select count (*) into v_c_procedure
--                        from XXBOT.XXAR_SEND_RULES_ECTELMEX_L
--                        where 1=1;
--
--
--            ELSE
--            APPS.MESSAGE_LOG(' - ERROR -> EL SIGUIENTE ARCHIVO YA HA SIDO PROCESADO ANTERIORMENTE:'||v_file_name);
--            dbms_output.put_line(' - ERROR -> EL SIGUIENTE ARCHIVO YA HA SIDO PROCESADO ANTERIORMENTE:'||v_file_name);
--            --return false;
--            end if;
--
--            insert into XXBOT.XXAR_SEND_RULES_ECTELMEX_H
--            (
--              REQUEST_ID,
--              FILE_NAME,
--              APPLIED,
--              CREATION_DATE,
--              CREATED_BY,
--              LAST_UPDATE_DATE,
--              LAST_UPDATE_BY
--              )
--              values
--              (
--              v_request_id,
--              V_file_name,
--              'Y',
--              SYSDATE,
--              V_USER_ID,
--              SYSDATE,
--              V_USER_ID
--              );
--            COMMIT;
--
--
--
--
--       APPS.MESSAGE_LOG('Proceso concluyó correctamente');
--       APPS.MESSAGE_LOG('Registros procesados:  '||v_c_procedure);
--       dbms_output.put_line('Proceso concluyó correctamente');
--       else
--       APPS.MESSAGE_LOG('Prefijo '||v_prefijo||' - ERROR -> Nombre del archivo:'||v_file_name);
--       dbms_output.put_line('Prefijo '||v_prefijo||' - ERROR -> Nombre del archivo:'||v_file_name);
--       --return false;
--       end if;
--            COMMIT;
--   EXCEPTION
--   WHEN OTHERS THEN
--   dbms_output.put_line('Error al leer el archivo - '||SQLCODE||' -ERROR- '||SQLERRM);
--   APPS.MESSAGE_LOG('Error al leer el archivo - '||SQLCODE||' -ERROR- '||SQLERRM);
--   --return false;
--   END;
procedure xxbot_update_rulesedc(
errbuf out varchar2
,retcode out number
,pFileName varchar2)
    is
        v_file         UTL_FILE.file_type;
        vgDirectory varchar2(1000):= 'CUST_AR_BOTS_LAYOUT';
        v_file_name varchar2(1000);
      V_REQUEST_ID number;
      V_USER_ID number;
      V_COUNT_NEW number;
       V_COUNT_UPDATE number;
        V_COUNT_BUG number;
      v_prefijo VARCHAR2(1000):='LAY_RE_EDC_CT_';
        v_count_file number:=0;
        v_exception_file exception;


   BEGIN
        apps.MESSAGE_LOG('Parametros');
        apps.MESSAGE_LOG('Archivo:'||pFileName);
        --apps.MESSAGE_LOG('Tipo de Proceso:'||p_process);

        -- Obtiene request_id y user_id
        select nvl(fnd_global.conc_request_id,to_char(sysdate,'YYYYMMDDHH24MISS')),nvl(fnd_global.user_id,-1)
        into v_request_id ,V_USER_ID
        from dual;

        if v_request_id=-1
        then v_request_id:=to_char(sysdate,'YYYYMMDDHH24MISS');
        end if;

        apps.MESSAGE_LOG('INICIA PROCESO CARGA DE REGLAS DE ENVÍO EC-CT');

        begin
        select count (*) into v_count_file
        from XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
        where 1=1
        and file_name=pFileName;
        if v_count_file>0
        then
        apps.MESSAGE_LOG('Nombre de archivo utilizado anteriormente - '||pFileName);

                                      BEGIN
                                        UTL_FILE.fremove (vgDirectory, pFileName);
                                        APPS.MESSAGE_LOG('- Archivo de Usuario con nombre ya procesado: Borrado-'||pFileName);
                                        EXCEPTION
                                        WHEN OTHERS
                                        then
                                        APPS.MESSAGE_LOG('- Error al Intentar Borrar el Archivo .xlsx');
                                        END;
                                        COMMIT;
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
                            insert into XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                            select v_request_id
                                 ,pFileName
                                 ,ROW_NR
                                 ,TO_CHAR(upper(MAX(DECODE (col_nr,1, TRIM(NUMBER_val))))) customer_number
                                 ,MAX(DECODE (col_nr,2, TRIM(string_val))) periodo_envio
                                 ,TO_CHAR(upper(MAX(DECODE (col_nr,3, TRIM(NUMBER_val))))) fecha_envio
                                 ,UPPER (MAX(DECODE (col_nr,4, TRIM(string_val)))) activo
                                 ,0
                                 ,NULL
                                 ,sysdate as creation_date
                                 ,v_user_id created_BY
                                 ,sysdate as last_update_date
                                 ,v_user_id LAST_UPDATE_BY
                                 ,null
                            FROM TABLE(apps.as_read_xlsx.read( apps.as_read_xlsx.file2blob(vgDirectory,pFileName)))
                            WHERE 1=1
                            and row_nr>1
                            group by row_nr
                            order by row_nr;
                            commit;
--                        exception
--                            when others then
--                                RETCODE := 2; --error
--                                ERRBUF := 'Error al insertar en la tabla de validación';
                        end;

        ----------------------VALIDO QUE LA CADENA EXISTA ---------------------------------------

        BEGIN

                                for cur in (
                                select  B.CUSTOMER_ID,B.CUSTOMER_NUMBER
                                        from XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD A,apps.ar_customers b
                                        where 1=1
                                        and A.CUSTOMER_NUMBER=b.CUSTOMER_NUMBER
                                        and A.request_id=v_request_id)

                                        loop
                                        UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD A
                                        SET A.CUSTOMER_ID=cur.CUSTOMER_ID
                                        WHERE 1=1
                                        AND A.CUSTOMER_NUMBER=cur.CUSTOMER_NUMBER ;
                                        COMMIT;
                                        END LOOP;
                                END;
                                commit;

        -----------------------------------------------------------------------------------------

                ----------------------ACTUALIZO REGISTROS QUE NO SE ENCONTRÓ EL CUSTOMER_ID ---------------------------------------

        BEGIN

                                for cur in (
                                select  CUSTOMER_NUMBER,line_number
                                        from XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD A
                                        where 1=1
                                        AND CUSTOMER_ID IS NULL
                                        and A.request_id=v_request_id)

                                        loop
                                        UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD A
                                        SET A.STATUS=1,COMENTARIO='LA CADENA NO EXISTE EN AR'
                                        WHERE 1=1
                                        AND A.CUSTOMER_NUMBER=cur.CUSTOMER_NUMBER
                                        AND A.LINE_NUMBER=cur.LINE_NUMBER ;
                                        COMMIT;
                                        END LOOP;
                                END;
                                commit;

        -----------------------------------------------------------------------------------------

        ---------INICIO CON LA VALIDACIÓN DE LOS REGISTROS CARGADOS (NO NULOS)-----------------------

        BEGIN

        for cur in ( SELECT LINE_NUMBER,request_id
                                FROM XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                WHERE 1=1
                                AND STATUS=0
                                AND REQUEST_ID=v_request_id
                                and customer_number is null
                                or PERIODO_ENVIO is null
                                or FECHA_ENVIO is null
                                or activo is null
                                )

                            loop

                             UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                    SET STATUS= 1, comentario='NO ES POSIBLE PROCESAR UN REGISTRO NULO'
                                    WHERE 1=1
                                    AND STATUS=0
                                    and request_id=cur.request_id
                                    AND line_number =cur.line_number;
                            COMMIT;
                            END LOOP;
        END;
        ---------INICIO CON LA VALIDACION DE LOS REGISTROS DEL CAMPO ACTIVO---------------------------------------------------------

        BEGIN

        for cur in ( SELECT LINE_NUMBER,request_id,ACTIVO
                                FROM XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                WHERE 1=1
                                AND STATUS=0
                                AND activo NOT IN ('SI','NO')
                                )

                            loop

                             UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                    SET STATUS= 1, comentario='DATO EN EL CAMPO "ACTIVO" NO VALIDO: '||cur.activo
                                    WHERE 1=1
                                    AND STATUS=0
                                    and request_id=cur.request_id
                                    AND line_number =cur.line_number;
                            COMMIT;
                            END LOOP;
        END;

                ---------INICIO CON LA VALIDACION DE LOS REGISTROS DEL CAMPO PERIODO ENVIO---------------------------------------------------------

        BEGIN

        for cur in ( SELECT LINE_NUMBER,request_id,PERIODO_ENVIO
                                FROM XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                WHERE 1=1
                                AND STATUS=0
                                AND PERIODO_ENVIO NOT IN ('Anual','Trimestral','Semi anual','Mensual','Quincenal','Semanal')
                                )

                            loop

                             UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                    SET STATUS= 1, comentario='DATO EN EL CAMPO "PERIODO_ENVIO" NO VALIDO: '||cur.PERIODO_ENVIO
                                    WHERE 1=1
                                    AND STATUS=0
                                    and request_id=cur.request_id
                                    AND line_number =cur.line_number;
                            COMMIT;
                            END LOOP;
        END;

        ---------INICIO CON LA VALIDACION DE LA REGLA PERIODO QUINCENAL---------------------------------------------------------

        BEGIN

        for cur in ( SELECT LINE_NUMBER,request_id,PERIODO_ENVIO,FECHA_ENVIO
                                FROM XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                WHERE 1=1
                                AND STATUS=0
                                AND PERIODO_ENVIO='Quincenal'
                                AND FECHA_ENVIO NOT IN (1,2,3,4,5,6,7,8,9,10,11,12,13)
                                )

                            loop

                             UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                    SET STATUS= 1, comentario='CAMPO "FECHA_ENVIO" CORRESPONDIENTE AL PERIODO "Quincenal", NO VALIDO: '||cur.FECHA_ENVIO
                                    WHERE 1=1
                                    AND STATUS=0
                                    and request_id=cur.request_id
                                    AND line_number =cur.line_number;
                            COMMIT;
                            END LOOP;
        END;

        ---------INICIO CON LA VALIDACION DE LA REGLA PERIODO SEMANAL---------------------------------------------------------

        BEGIN

        for cur in ( SELECT LINE_NUMBER,request_id,PERIODO_ENVIO,FECHA_ENVIO
                                FROM XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                WHERE 1=1
                                AND STATUS=0
                                AND PERIODO_ENVIO='Semanal'
                                AND FECHA_ENVIO NOT IN (1,2,3,4,5,6,7)
                                )

                            loop

                             UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                    SET STATUS= 1, comentario='CAMPO "FECHA_ENVIO" CORRESPONDIENTE AL PERIODO "Semanal", NO VALIDO: '||cur.FECHA_ENVIO
                                    WHERE 1=1
                                    AND STATUS=0
                                    and request_id=cur.request_id
                                    AND line_number =cur.line_number;
                            COMMIT;
                            END LOOP;
        END;

        ---------INICIO CON LA VALIDACION DE LA REGLA PERIODO mensual---------------------------------------------------------

        BEGIN

        for cur in ( SELECT LINE_NUMBER,request_id,PERIODO_ENVIO,FECHA_ENVIO
                                FROM XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                WHERE 1=1
                                AND STATUS=0
                                AND PERIODO_ENVIO='Mensual'
                                AND FECHA_ENVIO NOT IN (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28)
                                )

                            loop

                             UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                    SET STATUS= 1, comentario='CAMPO "FECHA_ENVIO" CORRESPONDIENTE AL PERIODO "Mensual", NO VALIDO: '||cur.FECHA_ENVIO
                                    WHERE 1=1
                                    AND STATUS=0
                                    and request_id=cur.request_id
                                    AND line_number =cur.line_number;
                            COMMIT;
                            END LOOP;
        END;

        ---------INICIO CON LA VALIDACION DE LA REGLA PERIODO Anual---------------------------------------------------------
		-----
        BEGIN

        for cur in ( SELECT LINE_NUMBER,request_id,PERIODO_ENVIO,FECHA_ENVIO
                                FROM XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                WHERE 1=1
                                AND STATUS=0
                                AND PERIODO_ENVIO='Anual'
                                AND FECHA_ENVIO NOT IN (1,2,3,4,5,6,7,8,9,10,11,12)
                                )

                            loop

                             UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                    SET STATUS= 1, comentario='CAMPO "FECHA_ENVIO" CORRESPONDIENTE AL PERIODO "Anual", NO VALIDO: '||cur.FECHA_ENVIO
                                    WHERE 1=1
                                    AND STATUS=0
                                    and request_id=cur.request_id
                                    AND line_number =cur.line_number;
                            COMMIT;
                            END LOOP;
        END;

        ---------INICIO CON LA VALIDACION DE LA REGLA dato fecha envio---------------------------------------------------------

        BEGIN

        for cur in ( SELECT LINE_NUMBER,request_id,PERIODO_ENVIO,FECHA_ENVIO
                                FROM XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                WHERE 1=1
                                AND STATUS=0
                                AND FECHA_ENVIO NOT IN (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31)
                                )

                            loop

                             UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                    SET STATUS= 1, comentario='CAMPO "FECHA_ENVIO", NO VALIDO: '||cur.FECHA_ENVIO
                                    WHERE 1=1
                                    AND STATUS=0
                                    and request_id=cur.request_id
                                    AND line_number =cur.line_number;
                            COMMIT;
                            END LOOP;
        END;

        ---------INICIO CON LA VALIDACIÓN DE LOS REGISTROS CARGADOS (EXISTA EN TABLA FINAL CON LA MISMA DATA)-----------------------

        BEGIN

        for cur in ( SELECT a.LINE_NUMBER,a.request_id
                                FROM XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD A,XXBOT.XXAR_SEND_RULES_ECTELMEX_L B
                                WHERE 1=1
                                AND A.STATUS=0
                                AND A.REQUEST_ID=v_request_id
                                and A.customer_number=B.customer_number
                                AND A.PERIODO_ENVIO=B.PERIODO_ENVIO
                                AND A.FECHA_ENVIO=B.FECHA_ENVIO
                                AND A.activo=B.activo
                                )

                            loop

                             UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                    SET STATUS= 1, comentario='REGISTRO NO PROCESADO - YA EXISTE EN TABLA FINAL'
                                    WHERE 1=1
                                    AND STATUS=0
                                    and request_id=cur.request_id
                                    AND line_number =cur.line_number;
                            COMMIT;
                            END LOOP;
        END;

        ---------INICIO CON LA VALIDACIÓN DE LOS REGISTROS CARGADOS (EXISTA EN TABLA FINAL PERO SE DEBE ACTUALIZAR)-----------------------

        BEGIN

        for cur in ( SELECT A.LINE_NUMBER,A.request_id,A.CUSTOMER_NUMBER,A.PERIODO_ENVIO,A.FECHA_ENVIO,A.ACTIVO
                                FROM XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD A,XXBOT.XXAR_SEND_RULES_ECTELMEX_L B
                                WHERE 1=1
                                AND A.STATUS=0
                                AND A.REQUEST_id=v_request_id
                                and A.customer_number=B.customer_number
                                )

                            loop

                             UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                    SET STATUS= 2, comentario='REGISTRO ACTUALIZADO CORRECTAMENTE'
                                    WHERE 1=1
                                    AND STATUS=0
                                    and request_id=cur.request_id
                                    AND line_number =cur.line_number;
                            COMMIT;

                            UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_L
                            SET PERIODO_ENVIO=cur.periodo_envio,FECHA_ENVIO=cur.FECHA_ENVIO,ACTIVO=cur.ACTIVO, last_update_date=sysdate,last_update_by=V_USER_ID
                            where 1=1
                            and customer_number=cur.customer_number;
                            commit;
                            END LOOP;
        END;


        ---------INICIO CON LA VALIDACIÓN DE LOS REGISTROS CARGADOS (nuevos registros a cargar)-----------------------

        BEGIN

        for cur in ( SELECT A.LINE_NUMBER,A.request_id,A.CUSTOMER_NUMBER,A.PERIODO_ENVIO,A.FECHA_ENVIO,A.ACTIVO,a.customer_id
                                FROM XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD A
                                WHERE 1=1
                                AND A.STATUS=0
                                AND A.REQUEST_ID=v_request_id
                                and A.customer_number not in (
                                select customer_number
                                from XXBOT.XXAR_SEND_RULES_ECTELMEX_L
                                where 1=1)
                                )

                            loop

                             UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                    SET STATUS= 3, comentario='REGISTRO NUEVO CARGADO CORRECTAMENTE'
                                    WHERE 1=1
                                    AND STATUS=0
                                    and request_id=cur.request_id
                                    AND line_number =cur.line_number;
                            COMMIT;

                            INSERT INTO  XXBOT.XXAR_SEND_RULES_ECTELMEX_L (
                            REQUEST_ID,
                            CUSTOMER_ID,
                            CUSTOMER_NUMBER,
                            PERIODO_ENVIO,
                            FECHA_ENVIO,
                            ACTIVO,
                            CREATION_DATE,
                            CREATED_BY,
                            LAST_UPDATE_DATE,
                            LAST_UPDATE_BY) VALUES (
                            cur.request_id,
                            cur.customer_id,
                            cur.customer_number,
                            cur.PERIODO_ENVIO,
                            cur.FECHA_ENVIO,
                            cur.ACTIVO,
                            sysdate,
                            v_user_id,
                            sysdate,
                            v_user_id);

                            commit;
                            END LOOP;
        END;





                                        BEGIN
                                        UTL_FILE.fremove (vgDirectory, pFileName);
                                        APPS.MESSAGE_LOG('- Archivo de reporte Borrado-'||pFileName);
                                        EXCEPTION
                                        WHEN OTHERS
                                        then
                                        APPS.MESSAGE_LOG('- Error al Intentar Borrar el Archivo .xls');
                                        END;
                                        COMMIT;

                                       UPDATE XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                       SET STATUS=1,COMENTARIO='NO SE PUDO PROCESAR EL REGISTRO - VALIDAR -'
                                       WHERE 1=1
                                       AND REQUEST_ID=V_REQUEST_ID
                                       AND STATUS=0;
                                       COMMIT;


                                select  count (*) into v_count_new
                                        from XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                        where 1=1
                                        and status=3
                                        and request_id=v_request_id;

                                select  count (*) into v_count_update
                                        from XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                        where 1=1
                                        and status=2
                                        and request_id=v_request_id;

                                select  count (*) into v_count_BUG
                                        from XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                        where 1=1
                                        and status=1
                                        and request_id=v_request_id;

                                        apps.MESSAGE_LOG ('--------------------RESUMEN DEL PROCESO--------------------');
                                        apps.MESSAGE_LOG (' ');
                                        apps.MESSAGE_LOG ('REGISTROS NUEVOS: '||v_count_new);
                                        apps.MESSAGE_LOG ('REGISTROS ACTUALIZADOS: '||v_count_UPDATE);
                                        apps.MESSAGE_LOG ('REGISTROS CON ERROR: '||v_count_BUG);
                                        apps.MESSAGE_LOG (' ');
                                        apps.MESSAGE_LOG (' ');
                                        apps.MESSAGE_LOG ('--------------------DETALLE DE REGISTROS CON ERROR---------');
                                        apps.MESSAGE_LOG (' ');
                                        apps.MESSAGE_LOG (' ');

                                        BEGIN
                                        FOR CUR IN (select  *
                                        from XXBOT.XXAR_SEND_RULES_ECTELMEX_LOAD
                                        where 1=1
                                        and status=1
                                        and request_id=v_request_id)
                                        LOOP
                                        apps.MESSAGE_LOG ('LINEA: '||CUR.LINE_NUMBER||', CUSTOMER NUMBER: '||CUR.CUSTOMER_NUMBER||', PERIODO ENVIO: '||CUR.PERIODO_ENVIO||', FECHA ENVIO: '||CUR.FECHA_ENVIO||', ACTIVO: '||CUR.ACTIVO||', COMENTARIO: '||CUR.COMENTARIO );
                                         END LOOP;
                                         END;


    EXCEPTION
    when v_exception_file then
    apps.MESSAGE_LOG('Nombre de archivo utilizado anteriormente - '||pFileName|| '-- Procesar la solicitud con un nombre de archivo diferente');
    WHEN OTHERS
    THEN
    apps.MESSAGE_LOG ('ERROR- Ocurrió un error al ejecutar el proceso - '||SQLERRM||CHR(10));
    end;

   FUNCTION GET_TAX_BASE (P_TAX IN  NUMBER,P_CUSTOMER IN NUMBER )
    RETURN NUMBER
IS
    V_resultado   NUMBER := 0;

BEGIN


    IF P_TAX =0
    THEN
            select sum (LINE_RECOVERABLE+TAX_RECOVERABLE) INTO V_RESULTADO
                    from AR.RA_CUSTOMER_TRX_ALL a , ar.RA_CUSTOMER_TRX_LINES_ALL b
                    where 1=1
                    and a.customer_trx_id=b.customer_trx_id
                    and a.customer_trx_id=P_CUSTOMER
                    and line_type='LINE'
                    and TAX_CLASSIFICATION_CODE like '%'||TO_CHAR(P_TAX)||'%';

                    RETURN NVL(V_RESULTADO,0);

    ELSIF P_TAX =8

    THEN

                    select sum (LINE_RECOVERABLE+TAX_RECOVERABLE) INTO V_RESULTADO
                    from AR.RA_CUSTOMER_TRX_ALL a , ar.RA_CUSTOMER_TRX_LINES_ALL b
                    where 1=1
                    and a.customer_trx_id=b.customer_trx_id
                    and a.customer_trx_id=P_CUSTOMER
                    and line_type='LINE'
                    and TAX_CLASSIFICATION_CODE like '%'||TO_CHAR(P_TAX)||'%';

                    RETURN NVL(V_RESULTADO,0);

        ELSIF P_TAX =16

    THEN

                    select sum (LINE_RECOVERABLE+TAX_RECOVERABLE) INTO V_RESULTADO
                    from AR.RA_CUSTOMER_TRX_ALL a , ar.RA_CUSTOMER_TRX_LINES_ALL b
                    where 1=1
                    and a.customer_trx_id=b.customer_trx_id
                    and a.customer_trx_id=P_CUSTOMER
                    and line_type='LINE'
                    and TAX_CLASSIFICATION_CODE like '%'||TO_CHAR(P_TAX)||'%';
                    RETURN NVL(V_RESULTADO,0);
             ELSE
             RETURN V_RESULTADO;
             commit;
    END IF;
EXCEPTION
    WHEN OTHERS
    THEN
        RETURN V_RESULTADO;
        commit;
END;

FUNCTION GET_SUC_GLN (P_DATA IN  VARCHAR2,P_CUSTOMER_NUMBER IN VARCHAR2,P_ORG_ID IN NUMBER,P_REFERENCE IN VARCHAR2)
    RETURN VARCHAR2
IS
    V_resultado   VARCHAR2 (100):= NULL;

BEGIN


    IF P_DATA ='SUC'
    THEN
                            select c.ATTRIBUTE9 INTO V_RESULTADO
                                    from apps.hz_parties party,apps.HZ_PARTY_SITES pz,
                                     apps.hz_cust_accounts cust_acct,apps.HZ_CUST_ACCT_SITES_all c,apps.ar_customers d
                                    where 1=1
                                    and d.customer_number =P_CUSTOMER_NUMBER
                                    and c.org_id=P_ORG_ID
                                    AND cust_acct.cust_account_id  =d.customer_id
                                    AND cust_acct.cust_account_id  =c.cust_account_id
                                    AND cust_acct.party_id = party.party_id
                                    AND pz.party_id = party.party_id
                                    and pz.ORIG_SYSTEM_REFERENCE=c.ORIG_SYSTEM_REFERENCE
                                    and pz.ORIG_SYSTEM_REFERENCE=P_REFERENCE;

                    RETURN V_RESULTADO;

    ELSIF P_DATA ='GLN'

    THEN

                    select c.ATTRIBUTE11 INTO V_RESULTADO
                                    from apps.hz_parties party,apps.HZ_PARTY_SITES pz,
                                     apps.hz_cust_accounts cust_acct,apps.HZ_CUST_ACCT_SITES_all c,apps.ar_customers d
                                    where 1=1
                                    and d.customer_number =P_CUSTOMER_NUMBER
                                    and c.org_id=P_ORG_ID
                                    AND cust_acct.cust_account_id  =d.customer_id
                                    AND cust_acct.cust_account_id  =c.cust_account_id
                                    AND cust_acct.party_id = party.party_id
                                    AND pz.party_id = party.party_id
                                    and pz.ORIG_SYSTEM_REFERENCE=c.ORIG_SYSTEM_REFERENCE
                                    and pz.ORIG_SYSTEM_REFERENCE=P_REFERENCE;

                    RETURN V_RESULTADO;


             ELSE
             RETURN V_RESULTADO;
             commit;
    END IF;
EXCEPTION
    WHEN OTHERS
    THEN
        RETURN V_RESULTADO;
        commit;
END GET_SUC_GLN;

    PROCEDURE SYNC_UP_EBS_VS_BDAPEX(P_ORG_ID  in VARCHAR2, P_LAST_UPDATE_DATE_PRC DATE DEFAULT TRUNC(SYSDATE-1))
    IS BEGIN
        merge into CFDI_AP_AR.XXAR_BOTS_EDO_CTA@OCIPROD_TO_ORAPROD19 ecr
using (SELECT *
        FROM XXBOT.XXAR_BOTS_EDO_CTA ecl
        WHERE 1=1
        AND ecl.org_id = P_ORG_ID
        AND ecl.last_update_date_prc >=trunc(P_LAST_UPDATE_DATE_PRC-1)) ecl
ON (ecr.org_id = ecl.org_id
    and ecr.customer_trx_id = ecl.customer_trx_id
    and ecr.location=ecl.location)
WHEN MATCHED THEN
    UPDATE SET
     ecr.purchase_order = ecl.purchase_order
        ,ecr.last_update_date_prc = ecl.last_update_date_prc
        ,ecr.no_recibo = ecl.no_recibo
        ,ecr.no_editado = ecl.no_editado
        ,ecr.CLIENT = ecl.CLIENT
        ,ecr.B0=ecl.B0 ,
        ecr.B1=ecl.B1 ,
        ecr.B2=ecl.B2 ,
        ecr.B3=ecl.B3 ,
        ecr.B4=ecl.B4 ,
        ecr.B5=ecl.B5 ,
        ecr.B6=ecl.B6 ,
        ecr.B7=ecl.B7 ,
        ecr.B8=ecl.B8 ,
        ecr.B9=ecl.B9 ,
        ecr.B10=ecl.B10 ,
        ecr.B11=ecl.B11 ,
        ecr.B12=ecl.B12 ,
        ecr.B13=ecl.B13 ,
        ecr.B14=ecl.B14 ,
        ecr.B15=ecl.B15 ,
        ecr.B16=ecl.B16 ,
        ecr.B17=ecl.B17 ,
        ecr.B18=ecl.B18,
        ecr.uuid=ecl.uuid ,
        ecr.estatus=ecl.estatus ,
        ecr.DESCRIPCION_ESTATUS=ecl.DESCRIPCION_ESTATUS ,
        ecr.ACCESO_DOCTO=ecl.ACCESO_DOCTO ,
        ecr.url=ecl.url ,
        ecr.SISTEMA_DESTINO=ecl.SISTEMA_DESTINO,
        ecr.balance_due = ecl.balance_due,
        ecr.send_mail = ecl.send_mail,
        ecr.PORTAL = ecl.PORTAL,
        ecr.CEDIS =ecl.CEDIS
        ,ecr.REGION = ecl.REGION
        ,ecr.NUD = ecl.NUD
        ,ecr.LAST_UPDATE_DATE=ecl.LAST_UPDATE_DATE
        ,ecr.ejecutivo = ecl.ejecutivo
        ,ecr.COLLECTOR_ID=ecl.COLLECTOR_ID
        ,ecr.COLLECTOR=ecl.COLLECTOR
        ,ecr.ESTATUS_PORTAL=ecl.ESTATUS_PORTAL
        ,ecr.DOCUMENT_NUMBER=ecl.DOCUMENT_NUMBER
        ,ecr.ESTATUS_USUARIO=ecl.ESTATUS_USUARIO
        ,ecr.TRX_PURCHASE_ORDER=ecl.TRX_PURCHASE_ORDER
        ,ecr.RECEIPT_NUMBER=ecl.RECEIPT_NUMBER
        ,ecr.EXECUTION_DATE=ecl.EXECUTION_DATE
        ,ecr.PAYMENT_DATE=ecl.PAYMENT_DATE
        ,ecr.VOUCHER_NUMBER=ecl.VOUCHER_NUMBER
        ,ecr.TAX_ORIGINAL=ecl.TAX_ORIGINAL
        ,ecr.ID_CARGA=ecl.ID_CARGA
        ,ecr.NUMBER_VAL=ecl.NUMBER_VAL
        ,ecr.MESSAGE=ecl.MESSAGE
        ,ecr.SCHEDULED_DATE=ecl.SCHEDULED_DATE
        ,ecr.direccion_envio=ecl.direccion_envio
        ,ecr.G_D_COBRANZA=ecl.G_D_COBRANZA
        ,ecr.G_D_SEGURIDAD=ecl.G_D_SEGURIDAD
        ,ecr.gln=ecl.gln
        ,ecr.sucursal=ecl.sucursal

    WHEN NOT MATCHED THEN
        INSERT (ecr.CUSTOMER_TRX_ID,
                ecr.PURCHASE_ORDER,
                ecr.NUMBER_B,
                ecr.TYPE,
                ecr.TRX_DATE,
                ecr.GL_DATE,
                ecr.DUE_DATE,
                ecr.CURRENCY_B,
                ecr.ORIGINAL_AMOUNT,
                ecr.BALANCE_DUE,
                ecr.UUID,
                ecr.ESTATUS,
                ecr.DESCRIPCION_ESTATUS,
                ecr.ACCESO_DOCTO,
                ecr.URL,
                ecr.ORDEN,
                ecr.REMISION,
                ecr.NO_RECIBO,
                ecr.FECHA_RECIBO,
                ecr.TIPO,
                ecr.REFERENCIA_DIRECCION,
                ecr.CUSTOMER_ID,
                ecr.EJECUTIVO,
                ecr.COLLECTOR_ID,
                ecr.COLLECTOR,
                ecr.LOCATION,
                ecr.NAME,
                ecr.NUMBER_A,
                ecr.CP_SITE_USE_ID,
                ecr.B0,
                ecr.B1,
                ecr.B2,
                ecr.B3,
                ecr.B4,
                ecr.B5,
                ecr.B6,
                ecr.B7,
                ecr.B8,
                ecr.B9,
                ecr.B10,
                ecr.B11,
                ecr.B12,
                ecr.B13,
                ecr.B14,
                ecr.B15,
                ecr.B16,
                ecr.B17,
                ecr.B18,
                ecr.FLAG,
                ecr.LAST_UPDATE_DATE,
                ecr.ORG_ID,
                ecr.COMPANY_NAME,
                ecr.SEND_MAIL,
                ecr.PORTAL,
                ecr.CEDIS,
                ecr.REGION,
                ecr.NUD,
                ecr.SISTEMA_DESTINO,
                ecr.ESTATUS_PORTAL,
                ecr.CLIENT,
                ecr.ESTATUS_USUARIO,
                ecr.TRX_PURCHASE_ORDER,
                ecr.DOCUMENT_NUMBER,
                ecr.RECEIPT_NUMBER,
                ecr.EXECUTION_DATE,
                ecr.PAYMENT_DATE,
                ecr.VOUCHER_NUMBER,
                ecr.TAX_ORIGINAL,
                ecr.ID_CARGA,
                ecr.NO_EDITADO,
                ecr.NUMBER_VAL,
                ecr.IVA_0,
                ecr.IVA_8,
                ecr.IVA_16,
                ecr.SUCURSAL,
                ecr.GLN,
                ecr.CREATION_DATE_PRC,
                ecr.LAST_UPDATE_DATE_PRC,
                ecr.MESSAGE,
                ecr.SCHEDULED_DATE,
                ecr.direccion_envio,
                ecr.G_D_COBRANZA,
                ecr.G_D_SEGURIDAD)
        values (ecl.CUSTOMER_TRX_ID,
                ecl.PURCHASE_ORDER,
                ecl.NUMBER_B,
                ecl.TYPE,
                ecl.TRX_DATE,
                ecl.GL_DATE,
                ecl.DUE_DATE,
                ecl.CURRENCY_B,
                ecl.ORIGINAL_AMOUNT,
                ecl.BALANCE_DUE,
                ecl.UUID,
                ecl.ESTATUS,
                ecl.DESCRIPCION_ESTATUS,
                ecl.ACCESO_DOCTO,
                ecl.URL,
                ecl.ORDEN,
                ecl.REMISION,
                ecl.NO_RECIBO,
                ecl.FECHA_RECIBO,
                ecl.TIPO,
                ecl.REFERENCIA_DIRECCION,
                ecl.CUSTOMER_ID,
                ecl.EJECUTIVO,
                ecl.COLLECTOR_ID,
                ecl.COLLECTOR,
                ecl.LOCATION,
                ecl.NAME,
                ecl.NUMBER_A,
                ecl.CP_SITE_USE_ID,
                ecl.B0,
                ecl.B1,
                ecl.B2,
                ecl.B3,
                ecl.B4,
                ecl.B5,
                ecl.B6,
                ecl.B7,
                ecl.B8,
                ecl.B9,
                ecl.B10,
                ecl.B11,
                ecl.B12,
                ecl.B13,
                ecl.B14,
                ecl.B15,
                ecl.B16,
                ecl.B17,
                ecl.B18,
                ecl.FLAG,
                ecl.LAST_UPDATE_DATE,
                ecl.ORG_ID,
                ecl.COMPANY_NAME,
                ecl.SEND_MAIL,
                ecl.PORTAL,
                ecl.CEDIS,
                ecl.REGION,
                ecl.NUD,
                ecl.SISTEMA_DESTINO,
                ecl.ESTATUS_PORTAL,
                ecl.CLIENT,
                ecl.ESTATUS_USUARIO,
                ecl.TRX_PURCHASE_ORDER,
                ecl.DOCUMENT_NUMBER,
                ecl.RECEIPT_NUMBER,
                ecl.EXECUTION_DATE,
                ecl.PAYMENT_DATE,
                ecl.VOUCHER_NUMBER,
                ecl.TAX_ORIGINAL,
                ecl.ID_CARGA,
                ecl.NO_EDITADO,
                ecl.NUMBER_VAL,
                ecl.IVA_0,
                ecl.IVA_8,
                ecl.IVA_16,
                ecl.SUCURSAL,
                ecl.GLN,
                ecl.CREATION_DATE_PRC,
                ecl.LAST_UPDATE_DATE_PRC,
                ecl.MESSAGE,
                ecl.SCHEDULED_DATE,
                ecl.direccion_envio,
                ecl.G_D_COBRANZA,
                ecl.G_D_SEGURIDAD);
        COMMIT;
    END SYNC_UP_EBS_VS_BDAPEX;

    PROCEDURE XXBOT_LOG_EDOCTA(
                                p_org_id NUMBER,P_ESTATUS NUMBER, P_PUNTO_CONTROL NUMBER, P_TEXT VARCHAR2
                                ,P_INS_CONTEO VARCHAR2
                                ,P_REQUEST_ID NUMBER)
          is
            v_return number;
            v_request_id NUMBER;
          BEGIN

              IF P_REQUEST_ID IS NOT NULL THEN
                  v_request_id := P_REQUEST_ID;
              ELSE
                  v_request_id := NVL(fnd_global.conc_request_id,0);
              END IF;
      
          insert into XXBOT.XXBOT_LOG_CONTROL_EDO_CTA (estatus,fecha,punto_control, text,ORG_ID,REQUEST_ID) 
          values (P_ESTATUS,sysdate,P_PUNTO_CONTROL,'0' ||P_TEXT,p_org_id,v_request_id); 

          IF P_INS_CONTEO IN ('Y','S','YES','SI') THEN
              v_return := 0;
          
              SELECT count(*)
                into v_return
              from XXBOT.XXAR_BOTS_EDO_CTA ecl
              WHERE 1=1		
              AND ecl.org_id = p_org_id       
              AND ecl.last_update_date_prc >=trunc(sysdate-2);
          
              insert into XXBOT.XXBOT_LOG_CONTROL_EDO_CTA (estatus,fecha,punto_control, text,ORG_ID,REQUEST_ID) 
              values (P_ESTATUS,sysdate,P_PUNTO_CONTROL,'666 Conteo:'||v_return,p_org_id,v_request_id); 
                        
          END IF;                                                                           
            
          commit;
  end xxbot_log_edocta;
 END XXAR_BOTS_ACT_EDO_CTA;