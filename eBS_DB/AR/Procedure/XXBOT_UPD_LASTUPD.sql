CREATE OR REPLACE PROCEDURE XXBOT.XXBOT_UPD_LASTUPD(errbuf out varchar2
                             ,retcode out number
                             ,p_anio varchar2)
AS
PRAGMA AUTONOMOUS_TRANSACTION;
    V_START_DATE DATE;
    V_END_DATE DATE;
BEGIN
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

        DELETE XXTT_CUSTOMER_TRX_ID_EDO_CTA;
        COMMIT;

        XXBOT.XXBOT_LOG_EDOCTA(6666,1,0,'INI PRE PERIOD_NAME:' || cur_period.PERIOD_NAME,'NO'); 

        INSERT INTO XXTT_CUSTOMER_TRX_ID_EDO_CTA
        SELECT ecr.customer_trx_id--, ecr.NUMBER_B
        FROM CFDI_AP_AR.XXAR_BOTS_EDO_CTA@OCIPROD_TO_ORAPROD19 ecr
        WHERE 1=1
        --and org_id = 180
        --and ecr.customer_trx_id = 133263841
        AND ecr.trx_date >= V_START_DATE--trunc(to_date('01-01-2025','dd-mm-yyyy'))
        AND ecr.trx_date < V_END_DATE--trunc(to_date('01-01-2026','dd-mm-yyyy'))
        ;
        COMMIT;

        XXBOT.XXBOT_LOG_EDOCTA(6666,1,1,'INI PRE PERIOD_NAME:' || cur_period.PERIOD_NAME,'NO'); 

        update /*+ use_nl(x ecl) index(ecl IDX_XXAR_BOTS_TBL_EDO_CTA_N5)*/ XXBOT.XXAR_BOTS_EDO_CTA ecl
        set last_update_date_prc = sysdate-5
        where 1=1
        --and org_id = 180
        and customer_trx_id in (select customer_trx_id from XXTT_CUSTOMER_TRX_ID_EDO_CTA)
        --and trx_date >=to_date('01-08-2026','dd-mm-yyyy')
        and last_update_date_prc >= trunc(sysdate-1);
        commit;        
        
        XXBOT.XXBOT_LOG_EDOCTA(6666,1,2,'FIN PERIOD_NAME:' || cur_period.PERIOD_NAME,'NO'); 
    END LOOP;

    DELETE XXTT_CUSTOMER_TRX_ID_EDO_CTA;
        COMMIT;

END;
/

grant execute on XXBOT_UPD_LASTUPD to apps
