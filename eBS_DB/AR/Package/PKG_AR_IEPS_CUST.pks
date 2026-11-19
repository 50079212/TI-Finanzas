CREATE OR REPLACE EDITIONABLE PACKAGE apps.PKG_AR_IEPS_CUST
AS
    -- $Id: PKG_AR_IEPS_CUST.pks 1758 2016-03-16 02:11:03Z igarcia $
	-- $HeadURL: http://mxapediprdl.gepp.pvt:18080/svn/r12/ap/ap_tracking/pkg/XXAP_TRACKING_AP_PKG.pks $
	-- $Author: cdavila $
    -- $Revision: 1758 $
    -- $Date: 2025-07-25 16:47:41 -0600 (vie., 25 jul. 2025) $
    -- Proceso para crear nueva linea de IEPS en Facturas AR

    TYPE datos_tax IS VARRAY (10) OF VARCHAR2 (35);

    ---- TABLE OF VARCHAR2(15);

    t_cve_tax    datos_tax
                     := datos_tax ('',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '');
    t_por_tax    datos_tax
                     := datos_tax ('',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '');
    t_tipo_tax   datos_tax
                     := datos_tax ('',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '',
                                   '');

    FUNCTION f_org_considera_ieps (p_org_id IN NUMBER, p_trx_date IN DATE)
        RETURN VARCHAR2;                                     --- regresa S o N

    --imprime msjs de OUPTPUT
    PROCEDURE MSJOUT (p_in_message IN VARCHAR2);

    -----
    PROCEDURE f_imp_x_moneda (p_moneda    IN     VARCHAR2,
                              p_tipo      IN     VARCHAR2,
                              p_rate      IN     NUMBER,
                              p_date      IN     DATE,
                              p_importe   IN     NUMBER,
                              o_monto        OUT NUMBER,
                              o_status       OUT NUMBER);

    --- eeugenio Nov2025
   PROCEDURE pa_ar_obten_info_ieps_cust (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_ieps_litro               OUT NUMBER,
        o_chk_ieps_litro_ed        OUT NUMBER,
        o_ieps_litro_ed            OUT NUMBER
        );

    PROCEDURE pa_ar_obten_info_ieps_cust_old (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        -- o_litros out number,
        o_ieps_litro               OUT NUMBER);

    PROCEDURE pa_ar_obt_info_ieps_cust_dic19 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        -- o_litros out number,
        o_ieps_litro               OUT NUMBER);

    PROCEDURE pa_ar_obt_info_ieps_cust_dic20 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        -- o_litros out number,
        o_ieps_litro               OUT NUMBER);

    PROCEDURE pa_ar_obt_info_ieps_cust_jul21 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        -- o_litros out number,
        o_ieps_litro               OUT NUMBER);

    PROCEDURE pa_ar_obt_info_ieps_cust_dic21 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        -- o_litros out number,
        o_ieps_litro               OUT NUMBER);

    PROCEDURE pa_ar_obt_info_ieps_cust_dic22 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        -- o_litros out number,
        o_ieps_litro               OUT NUMBER);

    PROCEDURE pa_ar_obt_info_ieps_cust_dic23 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        -- o_litros out number,
        o_ieps_litro               OUT NUMBER);

    PROCEDURE pa_ar_obt_info_ieps_cust_dic24 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        -- o_litros out number,
        o_ieps_litro               OUT NUMBER);

    PROCEDURE pa_ar_obt_info_ieps_cust_dic25 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        -- o_litros out number,
        o_ieps_litro               OUT NUMBER);

    FUNCTION validate_descuento (p_description IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE pa_ar_gen_nva_lin_ieps_cust (
        errbuf                        OUT NOCOPY VARCHAR2,
        retcode                       OUT NOCOPY NUMBER,
        p_batch_source_id          IN            VARCHAR2,
        p_so_i                     IN            VARCHAR2,
        p_so_f                     IN            VARCHAR2,
        p_trans_type_id            IN            VARCHAR2,
        p_bill_to_customer_num_i   IN            VARCHAR2,
        p_bill_to_customer_num_f   IN            VARCHAR2,
        p_trx_number_i             IN            VARCHAR2,
        p_trx_number_f             IN            VARCHAR2);

    PROCEDURE pa_ar_mod_dcon_cust (errbuf       OUT NOCOPY VARCHAR2,
                                   retcode      OUT NOCOPY NUMBER);

    PROCEDURE pa_ar_act_link_lin_ieps (p_req_id IN NUMBER);

    FUNCTION pa_ar_cambia_distcont (p_req_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION pa_obten_impuestos (p_cod_imp IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION cambiar_dist_cont (p_in_org_id            IN NUMBER,
                                p_in_customer_trx_id   IN NUMBER)
        RETURN BOOLEAN;

    PROCEDURE CUSTOM_TRIGG_IEPS (P_TRX_ID                     NUMBER,
                                 P_CUST_TRX_LINE_GL_DIST_ID   NUMBER,
                                 P_CC_ID                      NUMBER);

    FUNCTION pa_ar_inserta_log_ieps (P_ORG_ID        IN NUMBER,
                                     P_TRX_NUMBER    IN VARCHAR2,
                                     P_SALES_ORDER   IN VARCHAR2,
                                     P_PRODUCTO      IN VARCHAR2,
                                     P_FECHA         IN DATE,
                                     P_CAT_IEPS      IN VARCHAR2)
        RETURN NUMBER;
END PKG_AR_IEPS_CUST;