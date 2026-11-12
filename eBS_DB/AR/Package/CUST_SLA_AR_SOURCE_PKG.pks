CREATE OR REPLACE PACKAGE "APPS"."CUST_SLA_AR_SOURCE_PKG" 
as

  procedure CUST_SLA_AR_VIEWM;

     FUNCTION get_estimulo_fiscal (p_org_id              IN NUMBER,
                                                   p_inventory_item_id   IN VARCHAR2)
       RETURN VARCHAR2;

     FUNCTION TIPO_CLIENTE (P_NUMERO_CLIENTE NUMBER)
      RETURN VARCHAR2;

     FUNCTION get_org_value (p_org_id IN NUMBER)
      RETURN VARCHAR2;

    PROCEDURE CUST_SLAR_AR_QUERY ;

     FUNCTION CUST_SLA_AR_SOURCE (
               p_segment_return NUMBER,
               p_cust_trx_line_gl_dist_id NUMBER
               )
               RETURN VARCHAR2;
    
    FUNCTION XXAR_RETURN_SEGMENT_SLA_AR (
               p_segment_return NUMBER,
               p_cust_trx_line_gl_dist_id NUMBER--,
               --p_code_combination_id NUMBER
               )
               RETURN VARCHAR2;

      Function Cust_Sla_Ar_Get_Val ( P_Tipo_Transaccion  Varchar2,
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
                                                        P_tipo_pedido_om Varchar2)  Return Varchar;

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
                                    ,p_trace VARCHAR2);

        procedure cust_sla_set_cta(p_rail ra_interface_lines_all%rowtype,p_trace varchar2, o_err_msj OUT varchar2, o_err_num OUT number);

        procedure cust_get_uso_cfdi_icia(p_rail ra_interface_lines_all%rowtype, o_err_msj OUT varchar2, o_err_num OUT number, o_uso_cfdi out varchar2);


end CUST_SLA_AR_SOURCE_PKG;