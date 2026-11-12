create or replace PACKAGE        "XXCUST_SLA_AR_SOURCE_PKG" 
AS
    FUNCTION XXAR_RETURN_SEGMENT_SLA_AR (p_segment_return NUMBER
                                        ,p_cust_trx_line_gl_dist_id NUMBER
                                        ) RETURN VARCHAR2;

    FUNCTION TIPO_CLIENTE (P_CUST_ACCOUNT_ID NUMBER DEFAULT 0
                          ,P_CUSTOMER_NUMBER NUMBER DEFAULT 0
                          ,P_SITE_USE_ID NUMBER DEFAULT 0
                          ) RETURN VARCHAR2;

    FUNCTION get_estimulo_fiscal (p_org_id              IN NUMBER,
                                 p_inventory_item_id   IN VARCHAR2
                                 ) RETURN VARCHAR2;

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
                                P_SEGMENTO_OPM Varchar2
                                )  Return Varchar;

    FUNCTION GET_SEGMENT_OPM(P_INVENTORY_ITEM_ID NUMBER)       
        RETURN VARCHAR2;

END XXCUST_SLA_AR_SOURCE_PKG;

/
--GRANT EXECUTE ON XXCUST_SLA_AR_SOURCE_PKG TO APPS;