CREATE OR REPLACE PACKAGE XXBOT.XXAR_BOTS_ACT_EDO_CTA
as

procedure  XXAR_BOTS_ESTADO_D_CTA (errbuf out varchar2,retcode out number,P_ORG_ID IN number);

procedure  XXAR_BOTS_ESTADO_D_CTA_CS (P_ORG_ID IN number) ;

PROCEDURE GEN_FILE_XLS ;--( errbuf out varchar2,retcode out number);

PROCEDURE GEN_FILE_EDO_CTA_MAS ( P_CADENA IN varchar2,P_ORG_ID IN number,P_REQUEST_ID IN NUMBER);

procedure XXBOT_GENMAS_EDOCTA (P_REQUEST_ID IN NUMBER,p_ORG_ID NUMBER);

procedure XXBOT_GENMAS_EDOCTA_CS (errbuf out varchar2,retcode out number);

----PROCESO TELMEX 

procedure XXBOT_GEN_LAY_TELMEX (errbuf out varchar2,retcode out number);

FUNCTION GET_SEND_DATE (P_PERIODO_ENVIO IN  VARCHAR2,P_FECHA_ENVIO IN VARCHAR2) RETURN DATE;

PROCEDURE GEN_FILE_EDO_CTA_TEL ( P_CADENA IN varchar2,P_ORG_ID IN number,P_REQUEST_ID IN NUMBER);

procedure XXBOT_GENMAS_EDOCTA_TELMEX (errbuf out varchar2,retcode out number);

FUNCTION get_data_on(      p_data        IN VARCHAR2,
                                p_index       IN NUMBER,
                                p_character   IN VARCHAR2) RETURN VARCHAR2;

procedure xxbot_update_rulesedc(errbuf out varchar2,retcode out number,pfileName varchar2);

FUNCTION GET_TAX_BASE (P_TAX IN  NUMBER,P_CUSTOMER IN NUMBER ) RETURN NUMBER;

FUNCTION GET_SUC_GLN (P_DATA IN  VARCHAR2,P_CUSTOMER_NUMBER IN VARCHAR2,P_ORG_ID IN NUMBER,P_REFERENCE IN VARCHAR2) RETURN VARCHAR2;

PROCEDURE SYNC_UP_EBS_VS_BDAPEX(P_ORG_ID in VARCHAR2,P_LAST_UPDATE_DATE_PRC DATE DEFAULT TRUNC(SYSDATE-1));

procedure XXBOT_LOG_EDOCTA(
			p_org_id NUMBER,P_ESTATUS NUMBER, P_PUNTO_CONTROL NUMBER, P_TEXT VARCHAR2
			,P_INS_CONTEO VARCHAR2
            ,P_REQUEST_ID NUMBER);

end XXAR_BOTS_ACT_EDO_CTA;
