CREATE OR REPLACE PACKAGE XXWEBC.XXAR_CIERRE_IEPS 
AS
    PROCEDURE l (p_in_msg IN VARCHAR2);

    PROCEDURE MSJOUT (p_in_message IN VARCHAR2);

    PROCEDURE LogPrc(P_SEC IN NUMBER, P_PERIOD_OR_DATE in VARCHAR2, P_TEXT IN VARCHAR2, P_REQUEST_ID IN NUMBER DEFAULT NULL);

    PROCEDURE EXECUTE_CUBE(p_date IN VARCHAR2
                           ,p_copy_to_history IN VARCHAR2); -- 'S' 'Y' or 'N' 

    PROCEDURE EXECUTE_CUBE_INTERCO(p_date IN VARCHAR2); 

    PROCEDURE EXECUTE_PORTFOLIO_RECEIVABLE(p_date IN VARCHAR2); 

    PROCEDURE EXECUTE_COLLECTED_RECEIPTS(p_period_name IN VARCHAR2);

    PROCEDURE SEND_MAIL(p_period_name IN VARCHAR2,p_date IN VARCHAR2);

    PROCEDURE CARGA_CUENTAS_CONTABLES_A_SLA2(p_period_name IN VARCHAR2);

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
                             ,p_send_mail IN VARCHAR2);
    
END XXAR_CIERRE_IEPS;
/
--GRANT EXECUTE ON XXWEBC.XXAR_CIERRE_IEPS TO APPS;