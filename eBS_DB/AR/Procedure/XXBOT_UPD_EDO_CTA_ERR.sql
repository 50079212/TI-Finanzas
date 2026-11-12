CREATE OR REPLACE PROCEDURE XXBOT.XXBOT_UPD_EDO_CTA_ERR(errbuf out varchar2
                             ,retcode out number
                             ,p_anio varchar2)
is
    PRAGMA AUTONOMOUS_TRANSACTION;
    V_START_DATE DATE;
    V_END_DATE DATE;

begin



    FOR cur_period IN (
                        select PERIOD_NAME, START_DATE, END_DATE+1 END_DATE2, PERIOD_NUM
                        from apps.gl_periods
                        WHERE 1=1
                        AND START_DATE <= SYSDATE
                        AND period_set_name = 'GEPP'
                        AND PERIOD_YEAR = p_anio
                        AND PERIOD_NAME NOT LIKE 'AJU%'
                        ORDER BY PERIOD_NUM DESC)
    loop
        V_START_DATE := cur_period.START_DATE;
        V_END_DATE := cur_period.END_DATE2;

        delete XXTT_CUSTOMER_TRX_ID_EDO_CTA;
        commit;

        INSERT INTO XXTT_CUSTOMER_TRX_ID_EDO_CTA
        SELECT ecr.customer_trx_id--, ecr.NUMBER_B
        FROM CFDI_AP_AR.XXAR_BOTS_EDO_CTA@OCIPROD_TO_ORAPROD19 ecr
        WHERE 1=1
        --and ecr.customer_trx_id = 133263841
        AND ecr.trx_date >= V_START_DATE--trunc(to_date('01-01-2026','dd-mm-yyyy'))
        AND ecr.trx_date < V_END_DATE --trunc(to_date('01-02-2026','dd-mm-yyyy'));
        and not exists (select 'ex' 
                        from xxcustomer_trx_id_edocta a
                        where 1=1
                        and a.customer_trx_id = ecr.customer_trx_id)
        ;
        COMMIT;

        delete  xx_datos_edo_cta;
        commit;

        insert into xx_datos_edo_cta
            SELECT /*+ use_nl(ecr ecl)
                    index(ecl IDX_XXAR_BOTS_TBL_EDO_CTA_N5)
                    use_nl(ecl x)
                    INDEX(X CUST_AR_FACTELEC_LOG_INDEX1)*/
                    ECL.ORG_ID,ecl.customer_trx_id, ECL.NUMBER_B
                    ,x.uuid 
                ,x.estatus
                ,x.DESCRIPCION_ESTATUS
                ,x.ACCESO_DOCTO
                ,x.url
                ,x.SISTEMA_DESTINO
            FROM XXTT_CUSTOMER_TRX_ID_EDO_CTA ecr--CFDI_AP_AR.XXAR_BOTS_EDO_CTA@OCIPROD_TO_ORAPROD19                             
                ,XXBOT.XXAR_BOTS_EDO_CTA ecl
                ,AR.CUST_AR_FACTELEC_LOG X
            WHERE 1=1
            --and ecr.customer_trx_id = 133263841
            --AND ecr.trx_date >= V_START_DATE--trunc(to_date('01-07-2026','dd-mm-yyyy'))
            --AND ecr.trx_date < V_END_DATE--trunc(to_date('01-08-2026','dd-mm-yyyy'))
            AND ecl.customer_trx_id = ecr.customer_trx_id
            AND x.org_id(+) = ECL.ORG_ID
            AND X.CUSTOMER_TRX_ID(+) = ecl.CUSTOMER_TRX_ID
            and x.numero_docto(+) = ecl.NUMBER_B            
                            ;

    commit;   

        -- FOR CUR IN (SELECT /*+ use_nl(ecr ecl)
        --                         index(ecl IDX_XXAR_BOTS_TBL_EDO_CTA_N5)
        --                         use_nl(ecl x)
		-- 	                    INDEX(X CUST_AR_FACTELEC_LOG_INDEX1)*/
        --                         ECL.ORG_ID,ecl.customer_trx_id, ECL.NUMBER_B
        --                         ,x.uuid 
        --                     ,x.estatus
        --                     ,x.DESCRIPCION_ESTATUS
        --                     ,x.ACCESO_DOCTO
        --                     ,x.url
        --                     ,x.SISTEMA_DESTINO
        --                 FROM XXTT_CUSTOMER_TRX_ID_EDO_CTA ecr--CFDI_AP_AR.XXAR_BOTS_EDO_CTA@OCIPROD_TO_ORAPROD19                             
        --                     ,XXBOT.XXAR_BOTS_EDO_CTA ecl
        --                     ,AR.CUST_AR_FACTELEC_LOG X
        --                 WHERE 1=1
        --                 --and ecr.customer_trx_id = 133263841
        --                 --AND ecr.trx_date >= V_START_DATE--trunc(to_date('01-07-2026','dd-mm-yyyy'))
        --                 --AND ecr.trx_date < V_END_DATE--trunc(to_date('01-08-2026','dd-mm-yyyy'))
        --                 AND ecl.customer_trx_id = ecr.customer_trx_id
        --                 AND x.org_id(+) = ECL.ORG_ID
        --                 AND X.CUSTOMER_TRX_ID(+) = ecl.CUSTOMER_TRX_ID
        --                 and x.numero_docto(+) = ecl.NUMBER_B
        --                 and not exists (select 'ex' 
        --                                 from xxcustomer_trx_id_edocta a
        --                                 where 1=1
        --                                 and a.customer_trx_id = ecr.customer_trx_id)
        --             )
          FOR CUR IN (SELECT x.ORG_ID,x.customer_trx_id, x.NUMBER_B
                                ,x.uuid 
                            ,x.estatus
                            ,x.DESCRIPCION_ESTATUS
                            ,x.ACCESO_DOCTO
                            ,x.url
                            ,x.SISTEMA_DESTINO
                        FROM xx_datos_edo_cta x
                        where 1=1
                        and not exists (select 'ex' 
                                        from xxcustomer_trx_id_edocta a
                                        where 1=1
                                        and a.customer_trx_id = x.customer_trx_id)
                        --and rownum<= 100000
                        )
          LOOP
            UPDATE /*+index(m IDX_XXAR_BOTS_TBL_EDO_CTA_N5)*/ xxbot.xxar_bots_edo_cta M
            SET --m.last_update_date_prc = sysdate, --x.last_update_date_prc, --cedc 20-03-2026
                    M.uuid                 = CUR.uuid , 
                    M.estatus              = CUR.estatus ,
                    M.DESCRIPCION_ESTATUS  = CUR.DESCRIPCION_ESTATUS ,
                    M.ACCESO_DOCTO         = CUR.ACCESO_DOCTO ,
                    M.url                  = CUR.url ,
                    M.SISTEMA_DESTINO      = CUR.SISTEMA_DESTINO
            where m.customer_trx_id = CUR.customer_trx_id ;

            UPDATE CFDI_AP_AR.XXAR_BOTS_EDO_CTA@OCIPROD_TO_ORAPROD19 M
             SET --m.last_update_date_prc = sysdate, --x.last_update_date_prc, --cedc 20-03-2026
                    M.uuid                 = CUR.uuid , 
                    M.estatus              = CUR.estatus ,
                    M.DESCRIPCION_ESTATUS  = CUR.DESCRIPCION_ESTATUS ,
                    M.ACCESO_DOCTO         = CUR.ACCESO_DOCTO ,
                    M.url                  = CUR.url ,
                    M.SISTEMA_DESTINO      = CUR.SISTEMA_DESTINO
            where m.customer_trx_id = CUR.customer_trx_id ;

            insert into xxcustomer_trx_id_edocta
            select CUR.customer_trx_id, sysdate
            from dual;

            COMMIT;
          END LOOP;
    END LOOP;
END XXBOT_UPD_EDO_CTA_ERR;
/


grant execute on XXBOT_UPD_EDO_CTA_ERR to apps
