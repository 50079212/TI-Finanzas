CREATE OR REPLACE PACKAGE XXWEBC.XXAP_TRACKING_AP_PKG
AS
	--
	-- $Id: XXAP_TRACKING_AP_PKG.pks 4744 2025-07-25 22:47:41Z cdavila $
	-- $HeadURL: http://mxapediprdl.gepp.pvt:18080/svn/r12/ap/ap_tracking/pkg/XXAP_TRACKING_AP_PKG.pks $
	-- $Author: cdavila $
    -- $Revision: 4744 $
    -- $Date: 2025-07-25 16:47:41 -0600 (vie., 25 jul. 2025) $
    --
	
    vg_IsApp BOOLEAN := FALSE;
    vg_LevelLog NUMBER := 5;
    vg_msg VARCHAR2(3000);
    vg_Resp_Id NUMBER;

    PROCEDURE XXLOG(p_Level in NUMBER default 0
                    ,p_EXECUTION_ID in NUMBER default 0
                    ,p_INVOICE_ID in NUMBER default NULL
                    ,p_TEXT in VARCHAR2 default NULL
                    ,p_VALUE1STR in VARCHAR2 default NULL
                    ,p_VALUE2STR in VARCHAR2 default NULL
                    ,p_VALUE3STR in VARCHAR2 default NULL
                    ,p_VALUE1NUM in NUMBER default NULL
                    ,p_VALUE2NUM in NUMBER default NULL
                    ,p_VALUE3NUM in NUMBER default NULL
                    ,p_PROCESS_NAME in VARCHAR2 default NULL);

    procedure MAIN(errbuf out varchar2, retcode out number,pin_ejecuta_dias in number, pin_fecha_barrido in varchar2);


    PROCEDURE INSERT_DATA_INVOICES_AP_OC(pin_user_id IN NUMBER, pin_id_executon IN NUMBER, pin_fecha_barrido  IN  DATE);

    PROCEDURE APPLY_HOLD_FA_XML(pin_user_id IN NUMBER, pin_id_executon IN NUMBER);

    PROCEDURE CHANGED_ERS_TO_XML(pin_user_id IN NUMBER,pin_id_executon IN NUMBER, pin_fecha_barrido  IN  DATE);

    --PROCEDURE ACCOUNTED_INVOICES(pin_id_execution in number ,pin_user_id in number);

    FUNCTION GET_COUNT_HOLD(p_invoice_id in number, p_hold_name in varchar2, p_tipo in varchar2) return number;

    PROCEDURE UPDATE_STATUS_INVOICES(pin_id_execution in number ,pin_user_id in number);

    PROCEDURE APPLY_HOLD_INV(pin_id_execution in number ,pin_user_id in number,P_INVOICE_ID in NUMBER, p_tipo_hold in NUMBER, p_result out number,p_hold_reason in varchar2 default NULL);--XXGEP_APLHOLD--

    PROCEDURE UNAPPLY_HOLD_INV(pin_id_execution in number ,pin_user_id in number,P_INVOICE_ID in NUMBER, p_tipo_hold in NUMBER, p_result out number);--XXGEP_RELHOLD--

    PROCEDURE CUST_UPDATE_INVOICE_AP(pin_id_execution in number ,pin_user_id in number,P_INVOICE_ID in NUMBER, p_invoice_num_new in VARCHAR2, p_invoice_date_new date, p_result out varchar2, p_result_msg out varchar2);--XXGEP_UPD_INV_NUM

    PROCEDURE SEND_REQUEST_POXPOIV(errbuf out varchar2, retcode out number,pin_ejecuta_dias in number,pin_fecha_barrido in varchar2);

    PROCEDURE XXPRUEBA_CONCURRENTE;

    FUNCTION GET_RESP_ID (p_execution_id number,P_INVOICE_ID NUMBER) RETURN NUMBER;

    PROCEDURE XX_CREATE_ACCOUNTING(errbuf out varchar2, retcode out number);

    PROCEDURE XX_VALIDATE_INVOICES(errbuf out varchar2, retcode out number);

    PROCEDURE XX_TRANSFER_TO_ACCOUNTING(errbuf out varchar2, retcode out number);

    PROCEDURE GET_OPEN_PERIOD(p_application_id in number, p_period_name OUT VARCHAR2, p_start_date OUT DATE, p_end_date OUT DATE, p_num_periods_open OUT number);

    FUNCTION GET_END_DATE_PERIOD(p_application_id in number, p_period_name in VARCHAR2) return date;

    PROCEDURE TRACKING_MONITOR_BUILDER(p_period_name VARCHAR2);

    PROCEDURE UPDATE_ROW_TRACKING(pin_invoice_id number, pin_user_id in number, pin_process_name VARCHAR2);

    FUNCTION IS_FOREIGN_SUPPLIER(pin_vendor_id NUMBER,pin_vendor_site_id NUMBER) RETURN VARCHAR2;

    FUNCTION CUST_AP_VALIDA_ES_CIERRE_FNC RETURN VARCHAR2;

    FUNCTION STATUS_TO_EXCECUTE_THE_PROCESS(pin_process_name varchar2) RETURN VARCHAR2;

    PROCEDURE APPLY_HOLD_NC(pin_user_id IN NUMBER, pin_id_executon IN NUMBER);

END XXAP_TRACKING_AP_PKG;