CREATE OR REPLACE EDITIONABLE PACKAGE BODY APPS.PKG_AR_IEPS_CUST
AS
    -- $Id: PKG_AR_IEPS_CUST.pks 1758 2016-03-16 02:11:03Z igarcia $
    -- $HeadURL: http://mxapediprdl.gepp.pvt:18080/svn/r12/ap/ap_tracking/pkg/XXAP_TRACKING_AP_PKG.pks $
    -- $Author: cdavila $
    -- $Revision: 1758 $
    -- $Date: 2025-07-25 16:47:41 -0600 (vie., 25 jul. 2025) $
    -- Proceso para crear nueva linea de IEPS en Facturas AR

    PROCEDURE l (p_in_msg IN VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE (p_in_msg);
        fnd_file.put_line (fnd_file.LOG, p_in_msg);
    END l;

    PROCEDURE MSJOUT (p_in_message IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.output, p_in_message);
    END MSJOUT;

    FUNCTION f_org_considera_ieps (p_org_id IN NUMBER, p_trx_date IN DATE)
        RETURN VARCHAR2
    IS
        v_resp   VARCHAR2 (2) := 'N';
    BEGIN
        IF TRUNC (p_trx_date) <= TRUNC (TO_DATE ('31-12-2018', 'DD-MM-YYYY'))
        THEN
            SELECT DISTINCT 'S'
              INTO v_resp
              FROM xxar_ieps_2018
             WHERE org_id = p_org_id AND ieps_litro > 0;
        ELSE
            SELECT DISTINCT 'S'
              INTO v_resp
              FROM xxar_ieps
             WHERE     org_id = p_org_id
                   AND (ieps_litro > 0 OR ieps_litro_ed > 0);
        END IF;

        --
        RETURN v_resp;                                       --- regresa S o N
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'S';
    END f_org_considera_ieps;

    -------
    -- IGC 24 nov 2020
    ---***************

    FUNCTION pa_ar_inserta_log_ieps (P_ORG_ID        IN NUMBER,
                                     P_TRX_NUMBER    IN VARCHAR2,
                                     P_SALES_ORDER   IN VARCHAR2,
                                     P_PRODUCTO      IN VARCHAR2,
                                     P_FECHA         IN DATE,
                                     P_CAT_IEPS      IN VARCHAR2)
        RETURN NUMBER
    IS
    BEGIN
        INSERT INTO APPS.XXAR_LOG_IEPS (ORG_ID,
                                        TRX_NUMBER,
                                        SALES_ORDER,
                                        PRODUCTO,
                                        FECHA,
                                        CAT_IEPS)
             VALUES (P_ORG_ID,
                     P_TRX_NUMBER,
                     P_SALES_ORDER,
                     P_PRODUCTO,
                     P_FECHA,
                     P_CAT_IEPS);

        --commit;
        --
        RETURN 1;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END pa_ar_inserta_log_ieps;

    ---***************
    PROCEDURE f_imp_x_moneda (p_moneda    IN     VARCHAR2,
                              p_tipo      IN     VARCHAR2,
                              p_rate      IN     NUMBER,
                              p_date      IN     DATE,
                              p_importe   IN     NUMBER,
                              o_monto        OUT NUMBER,
                              o_status       OUT NUMBER)
    IS
        v_rate   NUMBER;
    BEGIN
        o_status := 0;

        IF p_moneda IN ('MXN', 'MXP')
        THEN
            l ('     mon:MXN o MXP');
            o_monto := p_importe;
            o_status := 0;
        ELSE
            IF p_tipo = 'Corporate'
            THEN
                BEGIN
                    SELECT conversion_rate
                      INTO v_rate
                      FROM gl_daily_rates
                     WHERE     conversion_type = p_tipo
                           AND from_currency = 'MXN'
                           AND to_currency = p_moneda
                           AND TRUNC (conversion_date) = TRUNC (p_date);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l (
                               'NO existio el tipo de cambio Corporate para el dia:'
                            || TO_CHAR (p_date));
                        v_rate := NULL;
                        o_status := 1;
                END;

                l (
                       '     mon:'
                    || p_tipo
                    || '*'
                    || TO_CHAR (v_rate)
                    || '*fecha:'
                    || TO_CHAR (p_date)
                    || '*Imp:'
                    || TO_CHAR (p_importe));
                o_monto := ROUND (v_rate * p_importe, 2);
            ELSE
                IF p_rate IS NULL
                THEN
                    l (
                        'El monto de conversion es nulo para linea con tipo de cambio User');
                    o_status := 1;
                END IF;

                l (
                       '     mon:'
                    || p_tipo
                    || '*'
                    || TO_CHAR (p_rate)
                    || '*Imp:'
                    || TO_CHAR (p_importe));
                o_monto := ROUND (p_importe * p_rate, 2);
            END IF;
        END IF;
    END;

    -------
    -------- eeugenio Nov2025
    PROCEDURE pa_ar_obten_info_ieps_cust (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_ieps_litro               OUT NUMBER,
        o_chk_ieps_litro_ed        OUT NUMBER,
        o_ieps_litro_ed            OUT NUMBER)
    IS
        v_ieps_litro        NUMBER;
        v_ieps_energ        VARCHAR2 (20);
        v_ieps_cont_calor   VARCHAR2 (20);
        v_ieps              VARCHAR2 (2);
        v_ieps_litro_ed     NUMBER;
        v_ieps_ed           VARCHAR2 (2);
    BEGIN
        SELECT ieps_litro,
               ieps_energ,
               ieps_cont_calor,
               ieps,
               ieps_litro_ed,
               ieps_ed
          INTO v_ieps_litro,
               v_ieps_energ,
               v_ieps_cont_calor,
               v_ieps,
               v_ieps_litro_ed,
               v_ieps_ed
          FROM XXAR_IEPS
         WHERE org_id = p_org_id AND segment1 = p_cve_item;

        ---
        IF v_ieps_energ = 'SI'
        THEN
            o_chk_ieps_energ := 1;
        ELSE
            o_chk_ieps_energ := 0;
        END IF;

        ---
        IF v_ieps_cont_calor = 'SI'
        THEN
            o_chk_ieps_cont_calor := 1;
        ELSE
            o_chk_ieps_cont_calor := 0;
        END IF;

        ---
        IF v_ieps_litro <> 0
        THEN
            o_chk_ieps_litro := 1;
            o_ieps_litro := v_ieps_litro;
        ELSE
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
        END IF;

        IF v_ieps_litro_ed <> 0
        THEN
            o_chk_ieps_litro_ed := 1;
            o_ieps_litro_ed := v_ieps_litro_ed;
        ELSE
            o_chk_ieps_litro_ed := 0;
            o_ieps_litro_ed := 0;
        END IF;
    ----
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            o_chk_ieps_cont_calor := 0;
            o_chk_ieps_energ := 0;
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
            o_chk_ieps_litro_ed := 0;
            o_ieps_litro_ed := 0;
    END;

    PROCEDURE pa_ar_obten_info_ieps_cust_old (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_ieps_litro               OUT NUMBER)
    IS
        v_ieps_litro        NUMBER;
        v_ieps_energ        VARCHAR2 (20);
        v_ieps_cont_calor   VARCHAR2 (20);
    BEGIN
        SELECT ieps_litro, ieps_energ, ieps_cont_calor
          INTO v_ieps_litro, v_ieps_energ, v_ieps_cont_calor
          FROM xxar_ieps_2018 --XXWEBC.Xxar_Ieps_Ene2018_Bkp --apps.xxar_ieps_old_sep18 --xxar_ieps_bkp1
         WHERE org_id = p_org_id AND segment1 = p_cve_item;

        ---
        IF v_ieps_energ = 'SI'
        THEN
            o_chk_ieps_energ := 1;
        ELSE
            o_chk_ieps_energ := 0;
        END IF;

        ---
        IF v_ieps_cont_calor = 'SI'
        THEN
            o_chk_ieps_cont_calor := 1;
        ELSE
            o_chk_ieps_cont_calor := 0;
        END IF;

        ---
        IF v_ieps_litro <> 0
        THEN
            o_chk_ieps_litro := 1;
            o_ieps_litro := v_ieps_litro;
        ELSE
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
        END IF;
    ----
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            o_chk_ieps_cont_calor := 0;
            o_chk_ieps_energ := 0;
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
    END;

    -- IGC 31 dic 2019
    PROCEDURE pa_ar_obt_info_ieps_cust_dic19 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_ieps_litro               OUT NUMBER)
    IS
        v_ieps_litro        NUMBER;
        v_ieps_energ        VARCHAR2 (20);
        v_ieps_cont_calor   VARCHAR2 (20);
    BEGIN
        SELECT ieps_litro, ieps_energ, ieps_cont_calor
          INTO v_ieps_litro, v_ieps_energ, v_ieps_cont_calor
          FROM Apps.XXAR_IEPS_DIC19
         WHERE org_id = p_org_id AND segment1 = p_cve_item;

        ---
        IF v_ieps_energ = 'SI'
        THEN
            o_chk_ieps_energ := 1;
        ELSE
            o_chk_ieps_energ := 0;
        END IF;

        ---
        IF v_ieps_cont_calor = 'SI'
        THEN
            o_chk_ieps_cont_calor := 1;
        ELSE
            o_chk_ieps_cont_calor := 0;
        END IF;

        ---
        IF v_ieps_litro <> 0
        THEN
            o_chk_ieps_litro := 1;
            o_ieps_litro := v_ieps_litro;
        ELSE
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
        END IF;
    ----
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            o_chk_ieps_cont_calor := 0;
            o_chk_ieps_energ := 0;
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
    END;

    --

    -- IGC 24 nov 2020
    PROCEDURE pa_ar_obt_info_ieps_cust_dic20 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_ieps_litro               OUT NUMBER)
    IS
        v_ieps_litro        NUMBER;
        v_ieps_energ        VARCHAR2 (20);
        v_ieps_cont_calor   VARCHAR2 (20);
    BEGIN
        SELECT ieps_litro, ieps_energ, ieps_cont_calor
          INTO v_ieps_litro, v_ieps_energ, v_ieps_cont_calor
          FROM Apps.XXAR_IEPS_DIC20
         WHERE org_id = p_org_id AND segment1 = p_cve_item;

        ---
        IF v_ieps_energ = 'SI'
        THEN
            o_chk_ieps_energ := 1;
        ELSE
            o_chk_ieps_energ := 0;
        END IF;

        ---
        IF v_ieps_cont_calor = 'SI'
        THEN
            o_chk_ieps_cont_calor := 1;
        ELSE
            o_chk_ieps_cont_calor := 0;
        END IF;

        ---
        IF v_ieps_litro <> 0
        THEN
            o_chk_ieps_litro := 1;
            o_ieps_litro := v_ieps_litro;
        ELSE
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
        END IF;
    ----
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            o_chk_ieps_cont_calor := 0;
            o_chk_ieps_energ := 0;
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
    END;

    -----

    -- IGC 16 ago 2021
    PROCEDURE pa_ar_obt_info_ieps_cust_jul21 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_ieps_litro               OUT NUMBER)
    IS
        v_ieps_litro        NUMBER;
        v_ieps_energ        VARCHAR2 (20);
        v_ieps_cont_calor   VARCHAR2 (20);
    BEGIN
        SELECT ieps_litro, ieps_energ, ieps_cont_calor
          INTO v_ieps_litro, v_ieps_energ, v_ieps_cont_calor
          FROM apps.xxar_iepsPROD31JUL
         WHERE org_id = p_org_id AND segment1 = p_cve_item;

        ---
        IF v_ieps_energ = 'SI'
        THEN
            o_chk_ieps_energ := 1;
        ELSE
            o_chk_ieps_energ := 0;
        END IF;

        ---
        IF v_ieps_cont_calor = 'SI'
        THEN
            o_chk_ieps_cont_calor := 1;
        ELSE
            o_chk_ieps_cont_calor := 0;
        END IF;

        ---
        IF v_ieps_litro <> 0
        THEN
            o_chk_ieps_litro := 1;
            o_ieps_litro := v_ieps_litro;
        ELSE
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
        END IF;
    ----
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            o_chk_ieps_cont_calor := 0;
            o_chk_ieps_energ := 0;
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
    END;

    ----- IGC 16 ago 2021

    -----

    -- IGC 31 dic 2021

    PROCEDURE pa_ar_obt_info_ieps_cust_dic21 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_ieps_litro               OUT NUMBER)
    IS
        v_ieps_litro        NUMBER;
        v_ieps_energ        VARCHAR2 (20);
        v_ieps_cont_calor   VARCHAR2 (20);
    BEGIN
        SELECT ieps_litro, ieps_energ, ieps_cont_calor
          INTO v_ieps_litro, v_ieps_energ, v_ieps_cont_calor
          FROM Apps.XXAR_IEPS_DIC21
         WHERE org_id = p_org_id AND segment1 = p_cve_item;

        ---
        IF v_ieps_energ = 'SI'
        THEN
            o_chk_ieps_energ := 1;
        ELSE
            o_chk_ieps_energ := 0;
        END IF;

        ---
        IF v_ieps_cont_calor = 'SI'
        THEN
            o_chk_ieps_cont_calor := 1;
        ELSE
            o_chk_ieps_cont_calor := 0;
        END IF;

        ---
        IF v_ieps_litro <> 0
        THEN
            o_chk_ieps_litro := 1;
            o_ieps_litro := v_ieps_litro;
        ELSE
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
        END IF;
    ----
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            o_chk_ieps_cont_calor := 0;
            o_chk_ieps_energ := 0;
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
    END;

    ----- IGC 31 dic 2021

    --*** 21 dic 2022

    -- IGC 31 dic 2022
    PROCEDURE pa_ar_obt_info_ieps_cust_dic22 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_ieps_litro               OUT NUMBER)
    IS
        v_ieps_litro        NUMBER;
        v_ieps_energ        VARCHAR2 (20);
        v_ieps_cont_calor   VARCHAR2 (20);
    BEGIN
        SELECT ieps_litro, ieps_energ, ieps_cont_calor
          INTO v_ieps_litro, v_ieps_energ, v_ieps_cont_calor
          FROM Apps.XXAR_IEPS_DIC22
         WHERE org_id = p_org_id AND segment1 = p_cve_item;

        ---
        IF v_ieps_energ = 'SI'
        THEN
            o_chk_ieps_energ := 1;
        ELSE
            o_chk_ieps_energ := 0;
        END IF;

        ---
        IF v_ieps_cont_calor = 'SI'
        THEN
            o_chk_ieps_cont_calor := 1;
        ELSE
            o_chk_ieps_cont_calor := 0;
        END IF;

        ---
        IF v_ieps_litro <> 0
        THEN
            o_chk_ieps_litro := 1;
            o_ieps_litro := v_ieps_litro;
        ELSE
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
        END IF;
    ----
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            o_chk_ieps_cont_calor := 0;
            o_chk_ieps_energ := 0;
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
    END;

    -----

    --*** 21 dic 2022

    --*** 21 dic 2023

    -- IGC 31 dic 2023
    PROCEDURE pa_ar_obt_info_ieps_cust_dic23 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_ieps_litro               OUT NUMBER)
    IS
        v_ieps_litro        NUMBER;
        v_ieps_energ        VARCHAR2 (20);
        v_ieps_cont_calor   VARCHAR2 (20);
    BEGIN
        SELECT ieps_litro, ieps_energ, ieps_cont_calor
          INTO v_ieps_litro, v_ieps_energ, v_ieps_cont_calor
          FROM Apps.XXAR_IEPS_DIC23
         WHERE org_id = p_org_id AND segment1 = p_cve_item;

        ---
        IF v_ieps_energ = 'SI'
        THEN
            o_chk_ieps_energ := 1;
        ELSE
            o_chk_ieps_energ := 0;
        END IF;

        ---
        IF v_ieps_cont_calor = 'SI'
        THEN
            o_chk_ieps_cont_calor := 1;
        ELSE
            o_chk_ieps_cont_calor := 0;
        END IF;

        ---
        IF v_ieps_litro <> 0
        THEN
            o_chk_ieps_litro := 1;
            o_ieps_litro := v_ieps_litro;
        ELSE
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
        END IF;
    ----
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            o_chk_ieps_cont_calor := 0;
            o_chk_ieps_energ := 0;
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
    END;

    -----

    --*** 21 dic 2023

    -- IGC 26 dic 2024
    PROCEDURE pa_ar_obt_info_ieps_cust_dic24 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_ieps_litro               OUT NUMBER)
    IS
        v_ieps_litro        NUMBER;
        v_ieps_energ        VARCHAR2 (20);
        v_ieps_cont_calor   VARCHAR2 (20);
    BEGIN
        SELECT ieps_litro, ieps_energ, ieps_cont_calor
          INTO v_ieps_litro, v_ieps_energ, v_ieps_cont_calor
          FROM Apps.XXAR_IEPS_DIC24
         WHERE org_id = p_org_id AND segment1 = p_cve_item;

        ---
        IF v_ieps_energ = 'SI'
        THEN
            o_chk_ieps_energ := 1;
        ELSE
            o_chk_ieps_energ := 0;
        END IF;

        ---
        IF v_ieps_cont_calor = 'SI'
        THEN
            o_chk_ieps_cont_calor := 1;
        ELSE
            o_chk_ieps_cont_calor := 0;
        END IF;

        ---
        IF v_ieps_litro <> 0
        THEN
            o_chk_ieps_litro := 1;
            o_ieps_litro := v_ieps_litro;
        ELSE
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
        END IF;
    ----
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            o_chk_ieps_cont_calor := 0;
            o_chk_ieps_energ := 0;
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
    END;

    -----

    --*** 26 dic 2024
    -- Nov2025
    PROCEDURE pa_ar_obt_info_ieps_cust_dic25 (
        p_org_id                IN     NUMBER,
        p_cve_item              IN     VARCHAR2,
        o_chk_ieps_cont_calor      OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_energ           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_chk_ieps_litro           OUT NUMBER,           --- (0/1) 0= no, 1=si
        o_ieps_litro               OUT NUMBER)
    IS
        v_ieps_litro        NUMBER;
        v_ieps_energ        VARCHAR2 (20);
        v_ieps_cont_calor   VARCHAR2 (20);
    BEGIN
        SELECT ieps_litro, ieps_energ, ieps_cont_calor
          INTO v_ieps_litro, v_ieps_energ, v_ieps_cont_calor
          FROM Apps.XXAR_IEPS_DIC25
         WHERE org_id = p_org_id AND segment1 = p_cve_item;

        ---
        IF v_ieps_energ = 'SI'
        THEN
            o_chk_ieps_energ := 1;
        ELSE
            o_chk_ieps_energ := 0;
        END IF;

        ---
        IF v_ieps_cont_calor = 'SI'
        THEN
            o_chk_ieps_cont_calor := 1;
        ELSE
            o_chk_ieps_cont_calor := 0;
        END IF;

        ---
        IF v_ieps_litro <> 0
        THEN
            o_chk_ieps_litro := 1;
            o_ieps_litro := v_ieps_litro;
        ELSE
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
        END IF;
    ----
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            o_chk_ieps_cont_calor := 0;
            o_chk_ieps_energ := 0;
            o_chk_ieps_litro := 0;
            o_ieps_litro := 0;
    END;

    ---

    FUNCTION validate_descuento (p_description IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_desc   NUMBER := 0;
    BEGIN
        BEGIN
            SELECT COUNT (lookup_code)
              INTO l_desc
              FROM fnd_lookup_values flka
             WHERE     1 = 1
                   AND lookup_code =
                       NVL (
                           SUBSTR (
                               SUBSTR (p_description, 8),
                               0,
                               INSTR (SUBSTR (p_description, 8), '.') - 1),
                           1)
                   AND LANGUAGE = USERENV ('LANG')
                   AND lookup_type = 'LK_DESCARTA_DESC_CUST';
        EXCEPTION
            WHEN OTHERS
            THEN
                l_desc := 0;
        END;

        --Valida si el tipo de descuento esta entre la cadena seguido de 3 mumeros, ejemplo DG3100P234.455
        IF l_desc = 0
        THEN
            SELECT COUNT (aux.description)
              INTO l_desc
              FROM (SELECT p_description description FROM DUAL) aux
             WHERE REGEXP_LIKE (aux.description, '[A-Pa-p][0-9]{3}+\.');
        END IF;

        IF l_desc = 0
        THEN
            RETURN 'N';
        ELSE
            RETURN 'Y';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            --         print_message (g_type_log_summary,
            --                        'Error en la funcion validate_descuento :' || SQLERRM
            --                       );
            RETURN 'N';
    END validate_descuento;

    ----------
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
        p_trx_number_f             IN            VARCHAR2)
    IS
        CURSOR c_lineas (p_batch_source_name IN VARCHAR2)
        IS
                SELECT *
                  FROM ra_interface_lines_all
                 WHERE     line_type = '#IEPS#'
                       AND org_id = fnd_profile.VALUE ('ORG_ID')
                       AND batch_source_name =
                           NVL (p_batch_source_name, batch_source_name)
                       AND NVL (sales_order, -1) BETWEEN TO_CHAR (
                                                             NVL (
                                                                 p_so_i,
                                                                 NVL (
                                                                     sales_order,
                                                                     -1)))
                                                     AND TO_CHAR (
                                                             NVL (
                                                                 p_so_f,
                                                                 NVL (
                                                                     sales_order,
                                                                     -1)))
                       AND NVL (trx_number, '***') BETWEEN NVL (
                                                               p_trx_number_i,
                                                               NVL (trx_number,
                                                                    '***'))
                                                       AND NVL (
                                                               p_trx_number_f,
                                                               NVL (trx_number,
                                                                    '***'))
                       AND NVL (cust_trx_type_id, -1) =
                           NVL (p_trans_type_id, NVL (cust_trx_type_id, -1))
                       AND NVL (orig_system_bill_customer_ref, '***') BETWEEN NVL (
                                                                                  p_bill_to_customer_num_i,
                                                                                  NVL (
                                                                                      orig_system_bill_customer_ref,
                                                                                      '***'))
                                                                          AND NVL (
                                                                                  p_bill_to_customer_num_f,
                                                                                  NVL (
                                                                                      orig_system_bill_customer_ref,
                                                                                      '***'))
            FOR UPDATE OF line_type NOWAIT;

        error_fatal                  EXCEPTION;
        reg_lin                      ra_interface_lines_all%ROWTYPE;
        vo_chk_ieps_cont_calor       NUMBER;             --- (0/1) 0= no, 1=si
        vo_chk_ieps_energ            NUMBER;             --- (0/1) 0= no, 1=si
        vo_chk_ieps_litro            NUMBER;             --- (0/1) 0= no, 1=si
        vo_ieps_litro                NUMBER;             --- (0/1) 0= no, 1=si
        vo_chk_ieps_litro_ed         NUMBER;    --- (0/1) 0= no, 1=si  NOV2025
        vo_ieps_litro_ed             NUMBER;    --- (0/1) 0= no, 1=si  NOV2025
        v_excluir_ieps_ncdas         NUMBER;    --- (0/1) 0= no, 1=si  NOV2025
        v_item                       VARCHAR2 (50);
        v_tot_reg_ins                NUMBER := 0;
        v_tot_reg_act                NUMBER := 0;
        p_batch_source_name          VARCHAR2 (50);
        v_type                       VARCHAR2 (10);
        v_monto                      NUMBER;
        v_monto_iepslt_sio           NUMBER := 0;                --PAAD NOV 25
        v_monto_iepsed_sio           NUMBER := 0;                --PAAD NOV 25
        v_description_sio            VARCHAR2 (255);             --PAAD NOV 25
        v_salesorderl_sio            VARCHAR2 (50);              --PAAD NOV 25
        v_interfacelatt11_sio        VARCHAR2 (50);              --PAAD NOV 25

        v_monto_precio               NUMBER;
        v_cantidad                   NUMBER;
        v_status                     NUMBER := 0;
        v_error                      NUMBER := 0;
        v_tasa                       NUMBER := 0;
        v_quantity                   NUMBER := 0;
        v_unit_selling               NUMBER := 0;
        v_unit_standard              NUMBER := 0;
        v_unit_standard_price        NUMBER := 0;
        v_unit_selling_price         NUMBER := 0;
        v_ind_refactura              VARCHAR2 (5);
        v_compuesto                  NUMBER;
        v_monto_upd                  NUMBER;
        v_monto_tmp                  NUMBER;
        i                            NUMBER;
        o                            NUMBER;
        v_descuentos                 NUMBER;
        v_ind_imp_base               NUMBER;
        v_monto_taxes                NUMBER;
        l_trx_number                 VARCHAR2 (10);
        l_reference_line_id          NUMBER;
        l_purchase_order             VARCHAR2 (40);
        l_category_code              VARCHAR2 (40);
        l_cust_trx_id                NUMBER;
        l_cust_trx_type_id           NUMBER;
        l_interco                    VARCHAR2 (1);
        l_ship_to_site_id            ra_interface_lines_all.orig_system_ship_address_id%TYPE;
        l_ship_to_customer_id        ra_interface_lines_all.orig_system_ship_customer_id%TYPE;
        v_error_config               NUMBER := 0;
        vtax_code                    VARCHAR2 (50);

        -- VARIABLES PARA LOS SEGMENTOS DE LA CUENTA DE IEPS
        -- JIBARRA 20-FEB-2017
        V_CC_SEGMENT1                VARCHAR2 (100);
        V_CC_SEGMENT2                VARCHAR2 (100);
        V_CC_SEGMENT3                VARCHAR2 (100);
        V_CC_SEGMENT4                VARCHAR2 (100);
        V_CC_SEGMENT5                VARCHAR2 (100);
        V_CC_SEGMENT6                VARCHAR2 (100);
        V_CC_SEGMENT7                VARCHAR2 (100);
        V_CODE_COMBINATION_ID        NUMBER;

        -- VARIABLES PARA CONTROLAR LA CREACION CORRECTA DE LAS NOTAS DE CREDITO DE ORDER ENTRY - PEDIDOS TERCEROS
        -- GARANTIZAR LA CREACION DE LA NOTA DE CREDITO AUNQUE ESATA NO SE REALCIONE CON EL PEDIDO DE TERCEROS
        -- JIBARRA 17-ABR-2017     SALE A PROD [27-NOV-2017]
        V_VALIDA_REFERENCE_LINE_ID   VARCHAR2 (100) := NULL;
        V_NUMERO_PEDIDO              VARCHAR2 (100) := NULL;
        L_REFERENCE_LINE_ID_IEPS     NUMBER;

        v_err_logieps                NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS=''.,''';

        BEGIN
            SELECT NAME
              INTO p_batch_source_name
              FROM ra_batch_sources_all
             WHERE     batch_source_id = p_batch_source_id
                   AND org_id = fnd_profile.VALUE ('ORG_ID');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l ('==>   source: NO hay source ' || p_batch_source_id);
                --Comentario
                p_batch_source_name := NULL;
            WHEN TOO_MANY_ROWS
            THEN
                l (
                       '==>   source: Muchos sources encontrados,id= '
                    || p_batch_source_id);                        --Comentario
                p_batch_source_name := NULL;
                RAISE error_fatal;
        END;

        /* BEGIN
            SELECT DISTINCT trx_number
              INTO l_trx_number
              FROM ra_interface_lines_all
             WHERE org_id = FND_PROFILE.VALUE('ORG_ID');
             l ('==>  old_trx_number : '|| l_trx_number  );
         EXCEPTION
            WHEN OTHERS THEN
               l ('==>  sqlerrm : '|| sqlerrm  );
         END;
        */
        l ('==>   org:' || TO_CHAR (fnd_profile.VALUE ('ORG_ID')));
        l ('==>   source:' || p_batch_source_name);
        l ('==> sales_order:' || p_so_i || '*' || p_so_f);
        l ('==> trx_num:' || p_trx_number_i || '*' || p_trx_number_f);
        l ('==> trans_type_id:' || TO_CHAR (p_trans_type_id));
        l (
               '==> #cus:'
            || p_bill_to_customer_num_i
            || '*'
            || p_bill_to_customer_num_f);

        FOR r_l IN c_lineas (p_batch_source_name)
        LOOP
            v_descuentos := NULL;
            vo_chk_ieps_cont_calor := NULL;
            vo_chk_ieps_energ := NULL;
            vo_chk_ieps_litro := NULL;
            vo_chk_ieps_litro_ed := 0;                        --NULL;  NOV2025
            vo_ieps_litro_ed := 0;                       --NULL;       NOV2025
            v_excluir_ieps_ncdas := 0;                              -- NOV2025
            vo_ieps_litro := NULL;
            v_item := NULL;
            v_tot_reg_ins := 0;
            v_tot_reg_act := 0;
            v_type := NULL;
            v_monto := NULL;
            v_monto_precio := NULL;
            v_cantidad := NULL;
            v_status := 0;
            v_error := 0;
            v_tasa := 0;
            v_quantity := 0;
            v_unit_selling := 0;
            v_unit_standard := 0;
            v_unit_standard_price := 0;
            v_unit_selling_price := 0;
            v_ind_refactura := NULL;
            v_compuesto := NULL;
            v_monto_upd := NULL;
            v_monto_tmp := NULL;
            i := NULL;
            o := NULL;
            v_ind_imp_base := NULL;
            v_monto_taxes := NULL;
            l_trx_number := NULL;
            l_reference_line_id := NULL;
            L_REFERENCE_LINE_ID_IEPS := NULL;
            l_purchase_order := NULL;
            l_category_code := NULL;
            v_error_config := 0;


            -- REINICIANDO VARIABLES DE LOS SEGMENTOS DE CUENTA IEPS
            -- JIBARRA 20-FEB-2017

            V_CC_SEGMENT1 := NULL;
            V_CC_SEGMENT2 := NULL;
            V_CC_SEGMENT3 := NULL;
            V_CC_SEGMENT4 := NULL;
            V_CC_SEGMENT5 := NULL;
            V_CC_SEGMENT6 := NULL;
            V_CC_SEGMENT7 := NULL;
            V_CODE_COMBINATION_ID := NULL;

            BEGIN
                SELECT TYPE
                  INTO v_type
                  FROM ra_cust_trx_types_all
                 WHERE     cust_trx_type_id =
                           NVL (r_l.cust_trx_type_id, cust_trx_type_id)
                       AND NAME = NVL (r_l.cust_trx_type_name, NAME)
                       AND org_id = r_l.org_id;

                l ('cust_trx_type:' || v_type);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l (
                           '  NO existe tipo linea:(id)*'
                        || TO_CHAR (r_l.cust_trx_type_id)
                        || ' (name)*'
                        || r_l.cust_trx_type_name);
                WHEN TOO_MANY_ROWS
                THEN
                    l (
                           '  MUCHOS tipos linea:(id)*'
                        || TO_CHAR (r_l.cust_trx_type_id)
                        || ' (name)*'
                        || r_l.cust_trx_type_name);
            END;

            --valida si la linea pertenece a un tipo de descuento                                                         --EFRA
            SELECT COUNT (lookup_code)
              INTO v_descuentos
              FROM fnd_lookup_values flka
             WHERE     1 = 1
                   AND lookup_code =
                       NVL (
                           SUBSTR (
                               SUBSTR (r_l.description, 8),
                               0,
                               INSTR (SUBSTR (r_l.description, 8), '.') - 1),
                           1)
                   AND LANGUAGE = USERENV ('LANG')
                   AND lookup_type = 'LK_DESCARTA_DESC_CUST';

            --Valida si el tipo de descuento esta entre la cadena seguido de 3 mumeros, ejemplo DG3100P234.455          --EFRA
            IF v_descuentos = 0
            THEN
                SELECT COUNT (aux.description)
                  INTO v_descuentos
                  FROM (SELECT r_l.description description FROM DUAL) aux
                 WHERE REGEXP_LIKE (aux.description, '[A-Pa-p][0-9]{3}+\.');
            END IF;

            l (' entra a linea');

            --MSJOUT('### L1 ::');

            IF     r_l.amount < 0
               AND v_type <> 'CM'
               AND r_l.interface_line_context != 'INTERCOMPANY'
               /* descuentos para docs. que NO sean CM */
               AND v_descuentos = 1
            THEN
                l ('   LINEA de descuento. tipo <> CM');

                --MSJOUT('### L1.1 ::');

                UPDATE ra_interface_lines_all
                   SET line_type = 'LINE'
                 WHERE CURRENT OF c_lineas;

                v_tot_reg_act := v_tot_reg_act + 1;
            ELSIF     r_l.amount > 0
                  AND v_type = 'CM'
                  AND r_l.interface_line_context != 'INTERCOMPANY'
                  /* descuentos para docs. que sean CreditMemo */
                  AND v_descuentos = 1
            THEN
                l ('   LINEA de descuento. tipo CreditMemo');

                --MSJOUT('### L1.2 ::');

                UPDATE ra_interface_lines_all
                   SET line_type = 'LINE'
                 WHERE CURRENT OF c_lineas;

                v_tot_reg_act := v_tot_reg_act + 1;
            ELSE
                --MSJOUT('### L1.3 ELSE ::');
                ---------------------------
                reg_lin := r_l;

                ---  ---------------------
                IF r_l.inventory_item_id IS NOT NULL
                THEN
                    BEGIN
                        v_item := NULL;

                        SELECT segment1
                          INTO v_item
                          FROM mtl_system_items           it,
                               hr_all_organization_units  ou
                         WHERE     it.inventory_item_id =
                                   r_l.inventory_item_id
                               AND it.organization_id = ou.organization_id
                               AND ou.NAME = 'MAESTRO DE ARTICULOS';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            l (
                                   ' *** NO existio:'
                                || TO_CHAR (r_l.warehouse_id)
                                || '*'
                                || TO_CHAR (r_l.inventory_item_id));
                        WHEN TOO_MANY_ROWS
                        THEN
                            l (
                                   ' *** Muchos:'
                                || TO_CHAR (r_l.warehouse_id)
                                || '*'
                                || TO_CHAR (r_l.inventory_item_id));
                    END;
                ELSE
                    v_item := r_l.mtl_system_items_seg1;
                END IF;

                l (
                       r_l.interface_line_attribute1
                    || '*'
                    || r_l.interface_line_attribute2
                    || '*'
                    || r_l.org_id
                    || '*it_id:'
                    || r_l.inventory_item_id
                    || '*seg1:'
                    || v_item);
                v_ind_refactura :=
                    SUBSTR (r_l.batch_source_name,
                            (LENGTH (r_l.batch_source_name) - 2),
                            3);
                l ('==> ultimas pos. source:' || v_ind_refactura);
                --            if r_l.interface_line_context !=  'FACTURAS MANUALES VITALITE' and r_l.interface_line_context!='INTERCOMPANY'  then
                --                l (' *******pa_ar_obten_info_ieps_cust diferente * FACTURAS MANUALES VITALITE');
                l (
                    ' ******* Refacturar productos LIPTON sin IEPS - Reorganizaci¿n fiscal');

                --jibarra ajuste IEPS
                /*IF -- v_ind_refactura = '-RE' AND
                        r_l.trx_date <= TO_DATE ('30-09-2018', 'DD-MM-YYYY')
                THEN
                                   l (' *******pa_ar_obten_info_ieps_cust igual * FACTURAS MANUALES VITALITE');
              */

                --EFRA ajuste IEPS
                IF TRUNC (r_l.trx_date) <=
                   TRUNC (TO_DATE ('31-12-2018', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.trx_date,
                            'pa_ar_obt_info_ieps_cust_old');
                    l ('pa_ar_obten_info_ieps_cust_old');
                    pkg_ar_ieps_cust.pa_ar_obten_info_ieps_cust_old (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                --IGC ajuste IEPS dic19
                ELSIF     TRUNC (r_l.trx_date) >=
                          TRUNC (TO_DATE ('01-01-2019', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.trx_date) <=
                          TRUNC (TO_DATE ('31-12-2019', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.trx_date,
                            'pa_ar_obt_info_ieps_cust_dic19');
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('trx_date ' || r_l.trx_date);
                    l ('pa_ar_obt_info_ieps_cust_dic19');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic19 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                ELSIF     TRUNC (r_l.SHIP_DATE_ACTUAL) >=
                          TRUNC (TO_DATE ('01-01-2019', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.SHIP_DATE_ACTUAL) <=
                          TRUNC (TO_DATE ('31-12-2019', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.trx_date,
                            'pa_ar_obt_info_ieps_cust_dic19');
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('SHIP_DATE_ACTUAL ' || r_l.SHIP_DATE_ACTUAL);
                    l ('pa_ar_obt_info_ieps_cust_dic19');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic19 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                -- IGC 24 nov 2020
                -- IGC ajuste IEPS dic20
                ELSIF     TRUNC (r_l.trx_date) >=
                          TRUNC (TO_DATE ('01-01-2020', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.trx_date) <=
                          TRUNC (TO_DATE ('31-12-2020', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.trx_date,
                            'pa_ar_obt_info_ieps_cust_dic20');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('trx_date ' || r_l.trx_date);
                    l ('pa_ar_obt_info_ieps_cust_dic20');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic20 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                ELSIF     TRUNC (r_l.SHIP_DATE_ACTUAL) >=
                          TRUNC (TO_DATE ('01-01-2020', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.SHIP_DATE_ACTUAL) <=
                          TRUNC (TO_DATE ('31-12-2020', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.ship_date_actual,
                            'pa_ar_obt_info_ieps_cust_dic20');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('SHIP_DATE_ACTUAL ' || r_l.SHIP_DATE_ACTUAL);
                    l ('pa_ar_obt_info_ieps_cust_dic20');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic20 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                -- IGC 16 ago 2021
                -- IGC ajuste IEPS jul21
                ELSIF     TRUNC (r_l.trx_date) >=
                          TRUNC (TO_DATE ('01-01-2021', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.trx_date) <=
                          TRUNC (TO_DATE ('31-07-2021', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.trx_date,
                            'pa_ar_obt_info_ieps_cust_jul21');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('trx_date ' || r_l.trx_date);
                    l ('pa_ar_obt_info_ieps_cust_jul21');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_jul21 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                ELSIF     TRUNC (r_l.SHIP_DATE_ACTUAL) >=
                          TRUNC (TO_DATE ('01-01-2021', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.SHIP_DATE_ACTUAL) <=
                          TRUNC (TO_DATE ('31-07-2021', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.ship_date_actual,
                            'pa_ar_obt_info_ieps_cust_jul21');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('SHIP_DATE_ACTUAL ' || r_l.SHIP_DATE_ACTUAL);
                    l ('pa_ar_obt_info_ieps_cust_jul21');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_jul21 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                -- IGC 16 ago 2021
                -- IGC 31 dic 2021
                -- IGC ajuste IEPS agosto a diciembre 21
                ELSIF     TRUNC (r_l.trx_date) >=
                          TRUNC (TO_DATE ('01-08-2021', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.trx_date) <=
                          TRUNC (TO_DATE ('31-12-2021', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.trx_date,
                            'pa_ar_obt_info_ieps_cust_dic21');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('trx_date ' || r_l.trx_date);
                    l ('pa_ar_obt_info_ieps_cust_dic21');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic21 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                ELSIF     TRUNC (r_l.SHIP_DATE_ACTUAL) >=
                          TRUNC (TO_DATE ('01-08-2021', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.SHIP_DATE_ACTUAL) <=
                          TRUNC (TO_DATE ('31-12-2021', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.ship_date_actual,
                            'pa_ar_obt_info_ieps_cust_dic21');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('SHIP_DATE_ACTUAL ' || r_l.SHIP_DATE_ACTUAL);
                    l ('pa_ar_obt_info_ieps_cust_dic21');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic21 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                -- IGC 31 dic 2021

                --** IGC 21 dic 2022

                ELSIF     TRUNC (r_l.trx_date) >=
                          TRUNC (TO_DATE ('01-01-2022', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.trx_date) <=
                          TRUNC (TO_DATE ('31-12-2022', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.trx_date,
                            'pa_ar_obt_info_ieps_cust_dic22');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('trx_date ' || r_l.trx_date);
                    l ('pa_ar_obt_info_ieps_cust_dic22');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic22 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                ELSIF     TRUNC (r_l.SHIP_DATE_ACTUAL) >=
                          TRUNC (TO_DATE ('01-01-2022', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.SHIP_DATE_ACTUAL) <=
                          TRUNC (TO_DATE ('31-12-2022', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.ship_date_actual,
                            'pa_ar_obt_info_ieps_cust_dic22');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('SHIP_DATE_ACTUAL ' || r_l.SHIP_DATE_ACTUAL);
                    l ('pa_ar_obt_info_ieps_cust_dic22');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic22 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                --** IGC 21 dic 2022

                --** IGC 13 dic 2023

                ELSIF     TRUNC (r_l.trx_date) >=
                          TRUNC (TO_DATE ('01-01-2023', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.trx_date) <=
                          TRUNC (TO_DATE ('31-12-2023', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.trx_date,
                            'pa_ar_obt_info_ieps_cust_dic23');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('trx_date ' || r_l.trx_date);
                    l ('pa_ar_obt_info_ieps_cust_dic23');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic23 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                ELSIF     TRUNC (r_l.SHIP_DATE_ACTUAL) >=
                          TRUNC (TO_DATE ('01-01-2023', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.SHIP_DATE_ACTUAL) <=
                          TRUNC (TO_DATE ('31-12-2023', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.ship_date_actual,
                            'pa_ar_obt_info_ieps_cust_dic23');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('SHIP_DATE_ACTUAL ' || r_l.SHIP_DATE_ACTUAL);
                    l ('pa_ar_obt_info_ieps_cust_dic23');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic23 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                --** IGC 13 dic 2023

                --** IGC 26 dic 2024

                ELSIF     TRUNC (r_l.trx_date) >=
                          TRUNC (TO_DATE ('01-01-2024', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.trx_date) <=
                          TRUNC (TO_DATE ('31-12-2024', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.trx_date,
                            'pa_ar_obt_info_ieps_cust_dic24');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('trx_date ' || r_l.trx_date);
                    l ('pa_ar_obt_info_ieps_cust_dic24');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic24 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                ELSIF     TRUNC (r_l.SHIP_DATE_ACTUAL) >=
                          TRUNC (TO_DATE ('01-01-2024', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.SHIP_DATE_ACTUAL) <=
                          TRUNC (TO_DATE ('31-12-2024', 'DD-MM-YYYY'))
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.ship_date_actual,
                            'pa_ar_obt_info_ieps_cust_dic24');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('SHIP_DATE_ACTUAL ' || r_l.SHIP_DATE_ACTUAL);
                    l ('pa_ar_obt_info_ieps_cust_dic24');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic24 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                --** IGC 26 dic 2024
                --- nov2025
                ELSIF     TRUNC (r_l.trx_date) >=
                          TRUNC (TO_DATE ('01-01-2025', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.trx_date) <=
                          TRUNC (TO_DATE ('31-12-2025', 'DD-MM-YYYY'))
                --TRUNC (TO_DATE ('30-09-2025', 'DD-MM-YYYY')) --- Quitar al subir a prod cedc
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.trx_date,
                            'pa_ar_obt_info_ieps_cust_dic25');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('trx_date ' || r_l.trx_date);
                    l ('pa_ar_obt_info_ieps_cust_dic25');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic25 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                ELSIF     TRUNC (r_l.SHIP_DATE_ACTUAL) >=
                          TRUNC (TO_DATE ('01-01-2025', 'DD-MM-YYYY'))
                      AND TRUNC (r_l.SHIP_DATE_ACTUAL) <=
                          TRUNC (TO_DATE ('31-12-2025', 'DD-MM-YYYY'))
                --TRUNC (TO_DATE ('30-09-2025', 'DD-MM-YYYY')) -- Quitar al subir a prod cedc
                THEN
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            r_l.ship_date_actual,
                            'pa_ar_obt_info_ieps_cust_dic25');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('trx_numbre ' || r_l.trx_number);
                    l ('sales_order ' || r_l.sales_order);
                    l ('v_item ' || v_item);
                    l ('SHIP_DATE_ACTUAL ' || r_l.SHIP_DATE_ACTUAL);
                    l ('pa_ar_obt_info_ieps_cust_dic25');
                    pkg_ar_ieps_cust.pa_ar_obt_info_ieps_cust_dic25 (
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro);
                --** nov2025 end de limites 2025
                ELSE
                    v_err_logieps :=
                        pa_ar_inserta_log_ieps (
                            r_l.org_id,
                            NVL (r_l.trx_number,
                                 r_l.interface_line_attribute3),
                            r_l.sales_order,
                            v_item,
                            NVL (r_l.trx_date, r_l.ship_date_actual),
                            'pa_ar_obt_info_ieps_cust');
                    l ('v_err_logieps ' || v_err_logieps);
                    l ('pa_ar_obten_info_ieps_cust');
                    PKG_AR_IEPS_CUST.pa_ar_obten_info_ieps_cust (  --- NOV2025
                        p_org_id                => r_l.org_id,
                        p_cve_item              => v_item,
                        o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                        o_chk_ieps_energ        => vo_chk_ieps_energ,
                        o_chk_ieps_litro        => vo_chk_ieps_litro,
                        o_ieps_litro            => vo_ieps_litro,
                        o_chk_ieps_litro_ed     => vo_chk_ieps_litro_ed,
                        o_ieps_litro_ed         => vo_ieps_litro_ed);
                END IF;


                --            pkg_ar_ieps_cust.pa_ar_obten_info_ieps_cust (
                --                  p_org_id                => r_l.org_id,
                --                  p_cve_item              => v_item,
                --                  o_chk_ieps_cont_calor   => vo_chk_ieps_cont_calor,
                --                  o_chk_ieps_energ        => vo_chk_ieps_energ,
                --                  o_chk_ieps_litro        => vo_chk_ieps_litro,
                --                  o_ieps_litro            => vo_ieps_litro);
                --end if;

                -- NOV2025
                l (
                       ' ******* ITEM:'
                    || v_item
                    || ' - ieps_litro:'
                    || TO_CHAR (vo_ieps_litro)
                    || ', ieps_litro_ed:'
                    || TO_CHAR (vo_ieps_litro_ed)
                    || '  ,description:'
                    || reg_lin.description);

                --MSJOUT('### L1 ieps_litro:: ' || TO_CHAR (vo_ieps_litro));

                -- NOV2025
                -- Se valida si el tipo de trasnaccion se debe excluir del IEPS
                BEGIN
                    l ('r_l.cus_trx_type_name -  ' || r_l.cust_trx_type_name);

                    SELECT COUNT (RCTT.CUST_TRX_TYPE_ID)
                      INTO v_excluir_ieps_ncdas
                      FROM RA_CUST_TRX_TYPES_ALL RCTT
                     WHERE     1 = 1
                           AND EXISTS
                                   (SELECT 'ex'               --FV.LOOKUP_CODE
                                      FROM APPS.FND_LOOKUP_VALUES fv
                                     WHERE     1 = 1
                                           AND ENABLED_FLAG = 'Y'
                                           AND NVL (END_DATE_ACTIVE,
                                                    SYSDATE + 1) >=
                                               SYSDATE
                                           AND LOOKUP_TYPE =
                                               'XXAR_EXCLUIR_IEPS_NCDAS'
                                           AND FV.LOOKUP_CODE = RCTT.NAME
                                           AND FV.LANGUAGE = 'ESA')
                           AND RCTT.NAME = r_l.cust_trx_type_name;

                    --AND RCTT.CUST_TRX_TYPE_ID = r_l.cust_trx_type_id

                    l ('v_excluir_ieps_ncdas -  ' || v_excluir_ieps_ncdas);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l (
                               'Error en obtener TT excluidas por NC DAS -  '
                            || SQLERRM);
                END;

                IF v_excluir_ieps_ncdas > 0
                THEN
                    vo_ieps_litro := 0;
                    vo_ieps_litro_ed := 0;
                    l (
                           ' ******* ITEM:'
                        || v_item
                        || ' cust_trx_type_name:'
                        || r_l.cust_trx_type_name
                        || ' - ieps_litro:'
                        || TO_CHAR (vo_ieps_litro)
                        || ', ieps_litro_ed:'
                        || TO_CHAR (vo_ieps_litro_ed)
                        || '  ,description:'
                        || reg_lin.description);
                    l (
                        ' ******* REGRESO A 0 los factores de IEPS ya que es una NC DAS');
                END IF;



                IF vo_ieps_litro = 0 AND vo_ieps_litro_ed = 0       -- NOV2025
                THEN
                    l ('  IEPS = 0');
                    l ('*-A-*' || r_l.orig_system_bill_customer_id);
                    l (
                        xxgepp_ar_cm_pkg.get_category_code (
                            r_l.orig_system_bill_customer_id));

                    IF xxgepp_ar_cm_pkg.get_category_code (
                           r_l.orig_system_bill_customer_id) =
                       'INTERCOMPA¿IAS'                              --NOV 25
                    THEN
                        l_interco := NULL;
                        l ('*-B-*');
                        xxgepp_ar_cm_pkg.get_ship_information (
                            r_l.sales_order,
                            r_l.org_id,
                            r_l.interface_line_attribute6,
                            l_ship_to_site_id,
                            l_ship_to_customer_id);
                        l (
                               '*-B1 -*'
                            || l_ship_to_site_id
                            || ' -  '
                            || l_ship_to_customer_id);
                        l_purchase_order :=
                            xxgepp_ar_cm_pkg.get_cust_po_number (
                                r_l.sales_order,
                                r_l.org_id,
                                r_l.interface_line_attribute6,
                                l_category_code,
                                r_l.orig_system_bill_customer_id);
                        l ('*-C-*');
                        l (l_category_code);

                        --MSJOUT ('### L2 l_category_code:: ' || l_category_code);

                        IF l_category_code = 'RETURN'
                        THEN
                            l ('*-D-*');

                            --MSJOUT('### L3:: ' || r_l.sales_order_line || ' -.- ' || r_l.inventory_item_id || ' - ' || r_l.DESCRIPTION);
                            --MSJOUT('### L3.1:: l_purchase_order:' ||l_purchase_order);
                            --MSJOUT('### L3.1:: org_id:' ||r_l.org_id);
                            --MSJOUT('### L3.1:: inventory_item_id:' ||r_l.inventory_item_id);
                            --MSJOUT('### L3.1:: purchase_order:' ||r_l.purchase_order);
                            --MSJOUT('### L3.1:: sales_order_line:' ||r_l.sales_order_line);
                            --MSJOUT('### L3.1:: BATCH_SOURCE_NAME:' ||r_l.BATCH_SOURCE_NAME);
                            --MSJOUT('### L3.1:: IN-PR-PEDIDOS-INTERNOS-NC');
                            --MSJOUT('### L3.1:: interface_line_context:'||reg_lin.interface_line_context);

                            IF     reg_lin.interface_line_context =
                                   'ORDER ENTRY'
                               AND REG_LIN.BATCH_SOURCE_NAME =
                                   'IN-PR-PEDIDOS-INTERNOS-NCR'
                            THEN                                        --CEDC
                                l_reference_line_id := r_l.REFERENCE_LINE_ID;

                                -- No. pedido original

                                SELECT TO_CHAR (oh.order_number) --, order_category_code
                                  INTO l_purchase_order    --, p_category_code
                                  FROM oe_order_headers_all oh
                                 WHERE     1 = 1
                                       AND header_id =
                                           (SELECT ohl.reference_header_id
                                              FROM oe_order_headers_all  oha,
                                                   oe_order_lines_all    ohl
                                             WHERE     oha.cust_po_number =
                                                       r_l.purchase_order
                                                   AND ohl.org_id =
                                                       r_l.org_id
                                                   AND ohl.line_id =
                                                       r_l.interface_line_attribute6
                                                   AND oha.org_id =
                                                       ohl.org_id
                                                   AND ohl.header_id =
                                                       oha.header_id);
                            ---MSJOUT('### L3.1 l_reference_line_id:: ' || l_reference_line_id);
                            --MSJOUT('### L3.1 new l_purchase_order:: ' || l_purchase_order);

                            ELSE
                                l_reference_line_id :=
                                    xxgepp_ar_cm_pkg.get_trx_line_id (
                                        l_purchase_order, --pedido de venta IGC 20-JUL-2016
                                        r_l.org_id,
                                        r_l.inventory_item_id,
                                        'ITEM',
                                        r_l.purchase_order, -- orden_compra IGC 20-JUL-2016
                                        r_l.sales_order_line -- l¿nea del pedido IGC 20-JUL-2016
                                                            );
                            --MSJOUT('### L3.1 l_reference_line_id:: ' || l_reference_line_id);


                            END IF;

                            l ('*-E-*');
                            l_cust_trx_id :=
                                xxgepp_ar_cm_pkg.get_cust_trx_id (
                                    l_purchase_order,
                                    r_l.org_id,
                                    l_reference_line_id);

                            --MSJOUT ('### L4 l_cust_trx_id:: ' || l_cust_trx_id);

                            l_cust_trx_type_id :=
                                xxgepp_ar_cm_pkg.get_trx_type_id (
                                    l_cust_trx_id);

                            --MSJOUT ('### L5 l_cust_trx_type_id:: '|| l_cust_trx_type_id);


                            l_interco := 'Y';
                            l (
                                   l_interco
                                || '-'
                                || l_cust_trx_id
                                || '-'
                                || l_cust_trx_type_id);
                        END IF;                                  --- termina D

                        l ('*-F-*');

                        --MSJOUT ('### L5:: ' || l_reference_line_id || ' - ' || r_l.REFERENCE_LINE_ID);

                        UPDATE ra_interface_lines_all
                           SET line_type = 'LINE',
                               reference_line_id = l_reference_line_id,
                               cust_trx_type_id =
                                   DECODE (l_interco,
                                           'Y', l_cust_trx_type_id,
                                           cust_trx_type_id),
                               orig_system_ship_customer_id =
                                   DECODE (
                                       NVL (r_l.orig_system_ship_customer_id,
                                            0),
                                       0, l_ship_to_customer_id,
                                       orig_system_ship_customer_id),
                               orig_system_ship_address_id =
                                   DECODE (
                                       NVL (r_l.orig_system_ship_address_id,
                                            0),
                                       0, l_ship_to_site_id,
                                       orig_system_ship_address_id)
                         WHERE CURRENT OF c_lineas;

                        v_tot_reg_act := v_tot_reg_act + 1;
                    END IF;

                    l ('*-G-*');

                    UPDATE ra_interface_lines_all
                       SET line_type = 'LINE'
                     WHERE CURRENT OF c_lineas;

                    --MSJOUT('###-----------------------------------------');

                    v_tot_reg_act := v_tot_reg_act + 1;
                ELSIF     r_l.interface_line_context = 'FACTURAS AUTOMATICAS'
                      AND v_ind_refactura <> '-RE'
                THEN               -------------------- 'FACTURAS AUTOMATICAS'
                    v_monto_iepslt_sio := 0;                     --PAAD NOV 25
                    v_monto_iepsed_sio := 0;                     --PAAD NOV 25
                    v_description_sio := NULL;                   --PAAD NOV 25
                    v_salesorderl_sio := NULL;                   --PAAD NOV 25
                    v_interfacelatt11_sio := NULL;               --PAAD NOV 25
                    ----Termina inicializar variables
                    v_monto_iepslt_sio := reg_lin.attribute11;   --PAAD NOV 25
                    v_monto_iepsed_sio := reg_lin.attribute7;    --PAAD NOV 25
                    v_description_sio := reg_lin.description;    --PAAD NOV 25
                    v_salesorderl_sio := reg_lin.sales_order_line; --PAAD NOV 25
                    v_interfacelatt11_sio :=
                        reg_lin.interface_line_attribute11;      --PAAD NOV 25

                    IF v_monto_iepslt_sio <> 0                   --PAAD NOV 25
                    THEN
                        l ('   fact. automaticas');
                        reg_lin.amount := reg_lin.attribute11;
                        reg_lin.unit_selling_price := reg_lin.attribute11;
                        reg_lin.unit_standard_price := reg_lin.attribute11;
                        reg_lin.interface_line_id := NULL;
                        reg_lin.line_type := 'LINE';
                        reg_lin.description :=
                            'IEPS_LT.' || v_description_sio;
                        reg_lin.sales_order_line :=
                               v_salesorderl_sio
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.NEXTVAL);
                        reg_lin.quantity := 1;
                        reg_lin.quantity_ordered := 1;
                        reg_lin.interface_line_attribute11 :=
                               v_interfacelatt11_sio
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.CURRVAL);
                        ----
                        reg_lin.attribute1 := NULL;
                        reg_lin.attribute2 := NULL;
                        reg_lin.attribute3 := NULL;
                        reg_lin.attribute4 := NULL;
                        reg_lin.attribute5 := NULL;
                        reg_lin.attribute6 := NULL;
                        reg_lin.attribute7 := NULL;
                        reg_lin.attribute8 := NULL;
                        reg_lin.attribute9 := NULL;
                        reg_lin.attribute10 := NULL;
                        reg_lin.attribute11 := NULL;
                        reg_lin.attribute12 := NULL;
                        reg_lin.attribute13 := NULL;
                        reg_lin.attribute14 := NULL;
                        reg_lin.attribute15 := NULL;

                        ---
                        IF v_error = 0
                        THEN
                            UPDATE ra_interface_lines_all
                               --- solo actualiza la linea origen
                               SET line_type = 'LINE'
                             WHERE CURRENT OF c_lineas;

                            v_tot_reg_act := v_tot_reg_act + 1;

                            IF reg_lin.amount <> 0
                            THEN
                                --INSERT INTO ra_interface_lines_all
                                --     VALUES reg_lin;

                                BEGIN
                                    INSERT INTO RA_INTERFACE_LINES_ALL
                                         VALUES REG_LIN;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        V_ERROR := 1;

                                        MSJOUT (
                                               '## ERROR:: [FACTURAS AUTOMATICAS] AL INSERTAR IEPS EN RA_INTERFACE_LINES_ALL_'
                                            || SQLERRM);
                                END;

                                -- SE INSERTA EN LA TABLA DE DISTRIBUCIONES LOS SEGMENTOS DE
                                -- LA CUENTA DE IEPS
                                -- JIBARRA 20-FEB-2017

                                IF (V_ERROR = 0)
                                THEN
                                    IF (r_l.batch_source_name LIKE
                                            '%ECP-SIO%')
                                    THEN
                                        BEGIN
                                            MSJOUT (
                                                   '## SE GENERA DISTRIBUCION PARA LINEA DE IEPS DE UNA FACTURA ['
                                                || r_l.interface_line_context
                                                || '] ORIGEN::'
                                                || r_l.batch_source_name);

                                            SELECT CC.SEGMENT1,
                                                   CC.SEGMENT2,
                                                   CC.SEGMENT3,
                                                   CC.SEGMENT4,
                                                   CC.SEGMENT5,
                                                   CC.SEGMENT6,
                                                   CC.SEGMENT7
                                              INTO V_CC_SEGMENT1,
                                                   V_CC_SEGMENT2,
                                                   V_CC_SEGMENT3,
                                                   V_CC_SEGMENT4,
                                                   V_CC_SEGMENT5,
                                                   V_CC_SEGMENT6,
                                                   V_CC_SEGMENT7
                                              FROM ZX_STATUS_B           ZS,
                                                   ZX_TAXES_B            ZT,
                                                   ZX_RATES_B            ZR,
                                                   ZX_ACCOUNTS           ZA,
                                                   GL_CODE_COMBINATIONS  CC,
                                                   HR_ALL_ORGANIZATION_UNITS
                                                   OU
                                             WHERE     1 = 1
                                                   AND ZS.EFFECTIVE_TO
                                                           IS NULL
                                                   AND ZS.TAX_REGIME_CODE =
                                                       ZT.TAX_REGIME_CODE
                                                   AND ZS.TAX = ZT.TAX
                                                   AND ZS.CONTENT_OWNER_ID =
                                                       ZT.CONTENT_OWNER_ID
                                                   AND ZS.TAX_STATUS_CODE =
                                                       ZR.TAX_STATUS_CODE
                                                   AND ZS.TAX_REGIME_CODE =
                                                       ZR.TAX_REGIME_CODE
                                                   AND ZS.TAX = ZR.TAX
                                                   AND ZS.CONTENT_OWNER_ID =
                                                       ZR.CONTENT_OWNER_ID
                                                   AND ZR.ACTIVE_FLAG = 'Y'
                                                   AND ZR.TAX_RATE_ID =
                                                       ZA.TAX_ACCOUNT_ENTITY_ID
                                                   AND ZA.TAX_ACCOUNT_CCID =
                                                       CC.CODE_COMBINATION_ID
                                                   AND ZA.INTERNAL_ORGANIZATION_ID =
                                                       OU.ORGANIZATION_ID
                                                   AND TAX_RATE_CODE =
                                                       'IEPS LT'
                                                   AND ZA.INTERNAL_ORGANIZATION_ID =
                                                       REG_LIN.ORG_ID;

                                            INSERT INTO RA_INTERFACE_DISTRIBUTIONS_ALL (
                                                            INTERFACE_LINE_CONTEXT,
                                                            INTERFACE_LINE_ATTRIBUTE1,
                                                            INTERFACE_LINE_ATTRIBUTE2,
                                                            INTERFACE_LINE_ATTRIBUTE3,
                                                            INTERFACE_LINE_ATTRIBUTE4,
                                                            INTERFACE_LINE_ATTRIBUTE5,
                                                            INTERFACE_LINE_ATTRIBUTE6,
                                                            INTERFACE_LINE_ATTRIBUTE7,
                                                            INTERFACE_LINE_ATTRIBUTE8,
                                                            INTERFACE_LINE_ATTRIBUTE9,
                                                            INTERFACE_LINE_ATTRIBUTE10,
                                                            INTERFACE_LINE_ATTRIBUTE11,
                                                            INTERFACE_LINE_ATTRIBUTE12,
                                                            INTERFACE_LINE_ATTRIBUTE13,
                                                            INTERFACE_LINE_ATTRIBUTE14,
                                                            INTERFACE_LINE_ATTRIBUTE15,
                                                            ACCOUNT_CLASS,
                                                            AMOUNT,
                                                            SEGMENT1,
                                                            SEGMENT2,
                                                            SEGMENT3,
                                                            SEGMENT4,
                                                            SEGMENT5,
                                                            SEGMENT6,
                                                            SEGMENT7,
                                                            ORG_ID,
                                                            CREATION_DATE)
                                                     VALUES (
                                                                REG_LIN.INTERFACE_LINE_CONTEXT,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE1,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE2,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE3,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE4,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE5,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE6,
                                                                TO_CHAR (
                                                                    SYSDATE,
                                                                    'dd-mm-yyyy'),
                                                                TO_CHAR (
                                                                    SYSDATE,
                                                                    'dd-mm-yyyy'),
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE9,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE10,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE11,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE12,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE13,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE14,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE15,
                                                                'REV',
                                                                REG_LIN.AMOUNT,
                                                                V_CC_SEGMENT1,
                                                                V_CC_SEGMENT2,
                                                                V_CC_SEGMENT3,
                                                                V_CC_SEGMENT4,
                                                                V_CC_SEGMENT5,
                                                                V_CC_SEGMENT6,
                                                                V_CC_SEGMENT7,
                                                                REG_LIN.ORG_ID,
                                                                REG_LIN.CREATION_DATE);
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                V_ERROR := 1;
                                                MSJOUT (
                                                       '## ERROR:: [FACTURAS AUTOMATICAS] AL INSERTAR DISTRIBUCION DE IEPS EN RA_INTERFACE_DISTRIBUTIONS_ALL'
                                                    || SQLERRM);
                                        END;
                                    END IF;
                                END IF;

                                v_tot_reg_ins := v_tot_reg_ins + 1;
                                l ('   Inserta Fact,Aut.');
                            ELSE
                                l ('     Att11= 0 ');
                            END IF;
                        END IF;
                    END IF;                                      --PAAD NOV 25

                    ------PAAD NOV 25
                    IF v_monto_iepsed_sio <> 0
                    THEN
                        l ('   fact. automaticas');
                        reg_lin.amount := v_monto_iepsed_sio;
                        reg_lin.unit_selling_price := v_monto_iepsed_sio;
                        reg_lin.unit_standard_price := v_monto_iepsed_sio;
                        reg_lin.interface_line_id := NULL;
                        reg_lin.line_type := 'LINE';
                        reg_lin.description :=
                            'IEPS_LT_ED.' || v_description_sio;
                        reg_lin.sales_order_line :=
                               v_salesorderl_sio
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.NEXTVAL);
                        reg_lin.quantity := 1;
                        reg_lin.quantity_ordered := 1;
                        reg_lin.interface_line_attribute11 :=
                               v_interfacelatt11_sio
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.CURRVAL);
                        ----
                        reg_lin.attribute1 := NULL;
                        reg_lin.attribute2 := NULL;
                        reg_lin.attribute3 := NULL;
                        reg_lin.attribute4 := NULL;
                        reg_lin.attribute5 := NULL;
                        reg_lin.attribute6 := NULL;
                        reg_lin.attribute7 := NULL;
                        reg_lin.attribute8 := NULL;
                        reg_lin.attribute9 := NULL;
                        reg_lin.attribute10 := NULL;
                        reg_lin.attribute11 := NULL;
                        reg_lin.attribute12 := NULL;
                        reg_lin.attribute13 := NULL;
                        reg_lin.attribute14 := NULL;
                        reg_lin.attribute15 := NULL;

                        ---
                        IF v_error = 0
                        THEN
                            UPDATE ra_interface_lines_all
                               --- solo actualiza la linea origen
                               SET line_type = 'LINE'
                             WHERE CURRENT OF c_lineas;

                            v_tot_reg_act := v_tot_reg_act + 1;

                            IF reg_lin.amount <> 0
                            THEN
                                --INSERT INTO ra_interface_lines_all
                                --     VALUES reg_lin;

                                BEGIN
                                    INSERT INTO RA_INTERFACE_LINES_ALL
                                         VALUES REG_LIN;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        V_ERROR := 1;

                                        MSJOUT (
                                               '## ERROR:: [FACTURAS AUTOMATICAS] AL INSERTAR IEPS EDULCORANTE EN RA_INTERFACE_LINES_ALL_'
                                            || SQLERRM);
                                END;

                                -- SE INSERTA EN LA TABLA DE DISTRIBUCIONES LOS SEGMENTOS DE
                                -- LA CUENTA DE IEPS EDULCORANTE
                                -- PAALTAMIRANOD 24-NOV-2025

                                IF (V_ERROR = 0)
                                THEN
                                    IF (r_l.batch_source_name LIKE
                                            '%ECP-SIO%')
                                    THEN
                                        BEGIN
                                            MSJOUT (
                                                   '## SE GENERA DISTRIBUCION PARA LINEA DE IEPS EDULCORANTE DE UNA FACTURA ['
                                                || r_l.interface_line_context
                                                || '] ORIGEN::'
                                                || r_l.batch_source_name);

                                            SELECT CC.SEGMENT1,
                                                   CC.SEGMENT2,
                                                   CC.SEGMENT3,
                                                   CC.SEGMENT4,
                                                   CC.SEGMENT5,
                                                   CC.SEGMENT6,
                                                   CC.SEGMENT7
                                              INTO V_CC_SEGMENT1,
                                                   V_CC_SEGMENT2,
                                                   V_CC_SEGMENT3,
                                                   V_CC_SEGMENT4,
                                                   V_CC_SEGMENT5,
                                                   V_CC_SEGMENT6,
                                                   V_CC_SEGMENT7
                                              FROM ZX_STATUS_B           ZS,
                                                   ZX_TAXES_B            ZT,
                                                   ZX_RATES_B            ZR,
                                                   ZX_ACCOUNTS           ZA,
                                                   GL_CODE_COMBINATIONS  CC,
                                                   HR_ALL_ORGANIZATION_UNITS
                                                   OU
                                             WHERE     1 = 1
                                                   AND ZS.EFFECTIVE_TO
                                                           IS NULL
                                                   AND ZS.TAX_REGIME_CODE =
                                                       ZT.TAX_REGIME_CODE
                                                   AND ZS.TAX = ZT.TAX
                                                   AND ZS.CONTENT_OWNER_ID =
                                                       ZT.CONTENT_OWNER_ID
                                                   AND ZS.TAX_STATUS_CODE =
                                                       ZR.TAX_STATUS_CODE
                                                   AND ZS.TAX_REGIME_CODE =
                                                       ZR.TAX_REGIME_CODE
                                                   AND ZS.TAX = ZR.TAX
                                                   AND ZS.CONTENT_OWNER_ID =
                                                       ZR.CONTENT_OWNER_ID
                                                   AND ZR.ACTIVE_FLAG = 'Y'
                                                   AND ZR.TAX_RATE_ID =
                                                       ZA.TAX_ACCOUNT_ENTITY_ID
                                                   AND ZA.TAX_ACCOUNT_CCID =
                                                       CC.CODE_COMBINATION_ID
                                                   AND ZA.INTERNAL_ORGANIZATION_ID =
                                                       OU.ORGANIZATION_ID
                                                   AND TAX_RATE_CODE =
                                                       'IEPS LT ED'
                                                   AND ZA.INTERNAL_ORGANIZATION_ID =
                                                       REG_LIN.ORG_ID;

                                            INSERT INTO RA_INTERFACE_DISTRIBUTIONS_ALL (
                                                            INTERFACE_LINE_CONTEXT,
                                                            INTERFACE_LINE_ATTRIBUTE1,
                                                            INTERFACE_LINE_ATTRIBUTE2,
                                                            INTERFACE_LINE_ATTRIBUTE3,
                                                            INTERFACE_LINE_ATTRIBUTE4,
                                                            INTERFACE_LINE_ATTRIBUTE5,
                                                            INTERFACE_LINE_ATTRIBUTE6,
                                                            INTERFACE_LINE_ATTRIBUTE7,
                                                            INTERFACE_LINE_ATTRIBUTE8,
                                                            INTERFACE_LINE_ATTRIBUTE9,
                                                            INTERFACE_LINE_ATTRIBUTE10,
                                                            INTERFACE_LINE_ATTRIBUTE11,
                                                            INTERFACE_LINE_ATTRIBUTE12,
                                                            INTERFACE_LINE_ATTRIBUTE13,
                                                            INTERFACE_LINE_ATTRIBUTE14,
                                                            INTERFACE_LINE_ATTRIBUTE15,
                                                            ACCOUNT_CLASS,
                                                            AMOUNT,
                                                            SEGMENT1,
                                                            SEGMENT2,
                                                            SEGMENT3,
                                                            SEGMENT4,
                                                            SEGMENT5,
                                                            SEGMENT6,
                                                            SEGMENT7,
                                                            ORG_ID,
                                                            CREATION_DATE)
                                                     VALUES (
                                                                REG_LIN.INTERFACE_LINE_CONTEXT,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE1,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE2,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE3,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE4,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE5,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE6,
                                                                TO_CHAR (
                                                                    SYSDATE,
                                                                    'dd-mm-yyyy'),
                                                                TO_CHAR (
                                                                    SYSDATE,
                                                                    'dd-mm-yyyy'),
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE9,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE10,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE11,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE12,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE13,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE14,
                                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE15,
                                                                'REV',
                                                                REG_LIN.AMOUNT,
                                                                V_CC_SEGMENT1,
                                                                V_CC_SEGMENT2,
                                                                V_CC_SEGMENT3,
                                                                V_CC_SEGMENT4,
                                                                V_CC_SEGMENT5,
                                                                V_CC_SEGMENT6,
                                                                V_CC_SEGMENT7,
                                                                REG_LIN.ORG_ID,
                                                                REG_LIN.CREATION_DATE);
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                V_ERROR := 1;
                                                MSJOUT (
                                                       '## ERROR:: [FACTURAS AUTOMATICAS] AL INSERTAR DISTRIBUCION DE IEPS EDULCORANTE EN RA_INTERFACE_DISTRIBUTIONS_ALL'
                                                    || SQLERRM);
                                        END;
                                    END IF;
                                END IF;

                                v_tot_reg_ins := v_tot_reg_ins + 1;
                                l ('   Inserta Fact,Aut.');
                            ELSE
                                l ('     Att7= 0 ');
                            END IF;
                        END IF;
                    END IF;                                  ------PAAD NOV 25
                ELSIF     r_l.interface_line_context = 'INTERCOMPANY'
                      AND v_ind_refactura <> '-RE'
                THEN                  --------------------      'INTERCOMPANY'
                    l ('=>  line_id:' || TO_CHAR (r_l.interface_line_id));
                    f_imp_x_moneda (
                        p_moneda    => reg_lin.currency_code,
                        p_tipo      => reg_lin.conversion_type,
                        p_rate      => reg_lin.conversion_rate,
                        p_date      =>
                            NVL (reg_lin.ship_date_actual,
                                 reg_lin.sales_order_date),
                        p_importe   => reg_lin.quantity * vo_ieps_litro,
                        o_monto     => v_monto,
                        o_status    => v_status);

                    IF v_status = 1
                    THEN
                        v_error := 1;
                    END IF;

                    IF v_type = 'CM'
                    THEN
                        v_monto := v_monto;
                        v_monto_precio := v_monto * -1;
                        v_cantidad := -1;
                    END IF;

                    reg_lin.amount := ROUND (v_monto, 2);
                    reg_lin.unit_selling_price := v_monto_precio;
                    reg_lin.unit_standard_price := v_monto_precio;
                    reg_lin.quantity := v_cantidad;
                    reg_lin.quantity_ordered := v_cantidad;
                    reg_lin.interface_line_id := NULL;
                    reg_lin.line_type := 'LINE';
                    reg_lin.description := 'IEPS_LT.' || reg_lin.description;
                    reg_lin.sales_order_line :=
                        reg_lin.interface_line_attribute2;
                    l (
                           'Description: '
                        || 'IEPS_LT.'
                        || reg_lin.description
                        || '   Linea: '
                        || reg_lin.sales_order_line);
                    reg_lin.interface_line_attribute7 :=
                           reg_lin.interface_line_attribute7
                        || '.'
                        || TO_CHAR (cust_ar_ieps_s.NEXTVAL);
                    reg_lin.interface_line_attribute1 :=
                        reg_lin.interface_line_attribute1 || '.1';

                    ----
                    --                reg_lin.interface_line_attribute1 := IEPS;
                    --                reg_lin.interface_line_attribute2 := null;
                    --                reg_lin.interface_line_attribute3 := null;
                    --                reg_lin.interface_line_attribute4 := null;
                    --                reg_lin.interface_line_attribute5 := null;
                    --                reg_lin.interface_line_attribute6 := null;
                    --                reg_lin.interface_line_attribute7 := null;
                    --                reg_lin.interface_line_attribute8 := null;
                    --                reg_lin.interface_line_attribute9 := null;
                    --                reg_lin.interface_line_attribute10 := null;
                    --                reg_lin.interface_line_attribute11 := null;
                    --                reg_lin.interface_line_attribute12 := null;
                    --                reg_lin.interface_line_attribute13 := null;
                    --                reg_lin.interface_line_attribute14 := null;
                    --                reg_lin.interface_line_attribute15 := null;
                    ---
                    l ('*-B-*');
                    xxgepp_ar_cm_pkg.get_ship_information (
                        r_l.sales_order,
                        r_l.org_id,
                        r_l.interface_line_attribute6,
                        l_ship_to_site_id,
                        l_ship_to_customer_id);
                    l (
                           '*-B1 -*'
                        || l_ship_to_site_id
                        || ' -  '
                        || l_ship_to_customer_id);
                    ------

                    reg_lin.orig_system_ship_customer_id :=
                        l_ship_to_customer_id;
                    reg_lin.orig_system_ship_address_id := l_ship_to_site_id;

                    IF     v_type != 'CM'
                       AND TRUNC (
                                 r_l.unit_selling_price
                               - (v_monto / r_l.quantity),
                               2) <
                           0
                       AND TRUNC (
                                 TRUNC (
                                       r_l.unit_standard_price
                                     - (v_monto / r_l.quantity),
                                     2)
                               * r_l.quantity,
                               2) <
                           0
                    THEN
                        v_error_config := 1;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Configuraci¿n erronea sobre el precio unitario de OM para el art¿culo '
                            || r_l.description);
                    END IF;

                    IF v_error = 0 AND v_error_config = 0
                    THEN
                        UPDATE ra_interface_lines_all
                           SET line_type = 'LINE',
                               interface_line_attribute1 =
                                   interface_line_attribute1,
                               --AMOUNT                        = v_monto_upd ,  ---decode(v_tasa,0, amount-v_monto_upd, trunc(v_quantity*v_unit_selling ,2)  ),   ---decode ( v_type, 'CM', amount, TRUNC(TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)*v_quantity,2)), /* solicitud de funcional */
                               --UNIT_SELLING_PRICE      = v_unit_selling ,   -- decode(v_tasa,0, v_unit_selling /*UNIT_SELLING_PRICE*/,    v_unit_selling  ), --agregado por PAAD (14012014)
                               --UNIT_STANDARD_PRICE  = v_unit_standard  --decode(v_tasa,0,v_unit_standard /*UNIT_STANDARD_PRICE*/, v_unit_standard ) --agregado por PAAD (14012014)
                               amount =
                                   DECODE (
                                       v_type,
                                       'CM', TRUNC (
                                                   TRUNC (
                                                         unit_standard_price
                                                       - (v_monto / quantity),
                                                       2)
                                                 * quantity,
                                                 2),
                                       TRUNC (
                                             TRUNC (
                                                   unit_standard_price
                                                 - (v_monto / quantity),
                                                 2)
                                           * quantity,
                                           2)),   /* solicitud de funcional */
                               unit_selling_price =
                                   DECODE (
                                       v_type,
                                       'CM', TRUNC (
                                                   unit_selling_price
                                                 - (v_monto / quantity),
                                                 2),
                                       TRUNC (
                                             unit_selling_price
                                           - (v_monto / quantity),
                                           2)), --agregado por PAAD (14012014)
                               unit_standard_price =
                                   DECODE (
                                       v_type,
                                       'CM', TRUNC (
                                                   unit_standard_price
                                                 - (v_monto / quantity),
                                                 2),
                                       TRUNC (
                                             unit_standard_price
                                           - (v_monto / quantity),
                                           2)), --agregado por PAAD (14012014)
                               orig_system_ship_customer_id =
                                   DECODE (
                                       NVL (r_l.orig_system_ship_customer_id,
                                            0),
                                       0, l_ship_to_customer_id,
                                       orig_system_ship_customer_id),
                               orig_system_ship_address_id =
                                   DECODE (
                                       NVL (r_l.orig_system_ship_address_id,
                                            0),
                                       0, l_ship_to_site_id,
                                       orig_system_ship_address_id)
                         WHERE CURRENT OF c_lineas;

                        v_tot_reg_act := v_tot_reg_act + 1;

                        BEGIN
                            INSERT INTO ra_interface_lines_all
                                 VALUES reg_lin;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                V_ERROR := 1;

                                MSJOUT (
                                       '## ERROR:: [INTERCOMPANY] AL INSERTAR IEPS EN RA_INTERFACE_LINES_ALL_'
                                    || SQLERRM);
                        END;

                        /* SE COLOCA LA SECCION PARA QUE SE COLOCADA LA DISTRIBUCION DE LAS
                        * LINEAS DE IEPS EN LA TABLA DE DISTRIBUCIONES DE LA INTERFACE
                        * IGARCIA 23-JUL-2019
                        */
                        IF V_ERROR = 0
                        THEN
                            BEGIN
                                MSJOUT (
                                       '## SE GENERA DISTRIBUCION PARA LINEA DE IEPS DE UNA FACTURA ['
                                    || r_l.interface_line_context
                                    || '] ORIGEN:: '
                                    || r_l.batch_source_name);

                                l (
                                    '   Inserta Distribuci¿n contable Intercompany');

                                SELECT CC.SEGMENT1,
                                       CC.SEGMENT2,
                                       CC.SEGMENT3,
                                       CC.SEGMENT4,
                                       CC.SEGMENT5,
                                       CC.SEGMENT6,
                                       CC.SEGMENT7,
                                       CC.CODE_COMBINATION_ID
                                  INTO V_CC_SEGMENT1,
                                       V_CC_SEGMENT2,
                                       V_CC_SEGMENT3,
                                       V_CC_SEGMENT4,
                                       V_CC_SEGMENT5,
                                       V_CC_SEGMENT6,
                                       V_CC_SEGMENT7,
                                       V_CODE_COMBINATION_ID
                                  FROM ZX_STATUS_B                ZS,
                                       ZX_TAXES_B                 ZT,
                                       ZX_RATES_B                 ZR,
                                       ZX_ACCOUNTS                ZA,
                                       GL_CODE_COMBINATIONS       CC,
                                       HR_ALL_ORGANIZATION_UNITS  OU
                                 WHERE     1 = 1
                                       AND ZS.EFFECTIVE_TO IS NULL
                                       AND ZS.TAX_REGIME_CODE =
                                           ZT.TAX_REGIME_CODE
                                       AND ZS.TAX = ZT.TAX
                                       AND ZS.CONTENT_OWNER_ID =
                                           ZT.CONTENT_OWNER_ID
                                       AND ZS.TAX_STATUS_CODE =
                                           ZR.TAX_STATUS_CODE
                                       AND ZS.TAX_REGIME_CODE =
                                           ZR.TAX_REGIME_CODE
                                       AND ZS.TAX = ZR.TAX
                                       AND ZS.CONTENT_OWNER_ID =
                                           ZR.CONTENT_OWNER_ID
                                       AND ZR.ACTIVE_FLAG = 'Y'
                                       AND ZR.TAX_RATE_ID =
                                           ZA.TAX_ACCOUNT_ENTITY_ID
                                       AND ZA.TAX_ACCOUNT_CCID =
                                           CC.CODE_COMBINATION_ID
                                       AND ZA.INTERNAL_ORGANIZATION_ID =
                                           OU.ORGANIZATION_ID
                                       AND TAX_RATE_CODE = 'IEPS LT'
                                       AND ZA.INTERNAL_ORGANIZATION_ID =
                                           REG_LIN.ORG_ID;

                                INSERT INTO RA_INTERFACE_DISTRIBUTIONS_ALL (
                                                INTERFACE_LINE_CONTEXT,
                                                INTERFACE_LINE_ATTRIBUTE1,
                                                INTERFACE_LINE_ATTRIBUTE2,
                                                INTERFACE_LINE_ATTRIBUTE3,
                                                INTERFACE_LINE_ATTRIBUTE4,
                                                INTERFACE_LINE_ATTRIBUTE5,
                                                INTERFACE_LINE_ATTRIBUTE6,
                                                INTERFACE_LINE_ATTRIBUTE7,
                                                INTERFACE_LINE_ATTRIBUTE8,
                                                INTERFACE_LINE_ATTRIBUTE9,
                                                INTERFACE_LINE_ATTRIBUTE10,
                                                INTERFACE_LINE_ATTRIBUTE11,
                                                INTERFACE_LINE_ATTRIBUTE12,
                                                INTERFACE_LINE_ATTRIBUTE13,
                                                INTERFACE_LINE_ATTRIBUTE14,
                                                INTERFACE_LINE_ATTRIBUTE15,
                                                ACCOUNT_CLASS,
                                                AMOUNT,
                                                PERCENT,
                                                CODE_COMBINATION_ID,
                                                SEGMENT1,
                                                SEGMENT2,
                                                SEGMENT3,
                                                SEGMENT4,
                                                SEGMENT5,
                                                SEGMENT6,
                                                SEGMENT7,
                                                ORG_ID,
                                                CREATION_DATE,
                                                SEGMENT25)
                                         VALUES (
                                                    REG_LIN.INTERFACE_LINE_CONTEXT,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE1,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE2,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE3,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE4,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE5,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE6,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE7,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE8,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE9,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE10,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE11,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE12,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE13,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE14,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE15,
                                                    'REV',
                                                    REG_LIN.AMOUNT,
                                                    '100',
                                                    V_CODE_COMBINATION_ID,
                                                    V_CC_SEGMENT1,
                                                    V_CC_SEGMENT2,
                                                    V_CC_SEGMENT3,
                                                    V_CC_SEGMENT4,
                                                    V_CC_SEGMENT5,
                                                    V_CC_SEGMENT6,
                                                    V_CC_SEGMENT7,
                                                    REG_LIN.ORG_ID,
                                                    REG_LIN.CREATION_DATE,
                                                    REG_LIN.TRX_NUMBER);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    V_ERROR := 1;

                                    MSJOUT (
                                           '## ERROR:: [INTERCOMPANY] AL INSERTAR DISTRIBUCION DE IEPS EN RA_INTERFACE_DISTRIBUTIONS_ALL'
                                        || SQLERRM);
                            END;
                        END IF;

                        v_tot_reg_ins := v_tot_reg_ins + 1;
                        l ('   Inserta  Intercompany');
                    END IF;
                ELSIF     r_l.interface_line_context = 'FACTURA NAGRUP'
                      AND v_ind_refactura <> '-RE'
                THEN
                    v_monto_iepslt_sio := 0;                     --PAAD NOV 25
                    v_monto_iepsed_sio := 0;                     --PAAD NOV 25
                    v_description_sio := NULL;                   --PAAD NOV 25
                    v_salesorderl_sio := NULL;                   --PAAD NOV 25
                    v_interfacelatt11_sio := NULL;               --PAAD NOV 25
                    ----Termina inicializar variables
                    v_monto_iepslt_sio := reg_lin.attribute11;   --PAAD NOV 25
                    v_monto_iepsed_sio := reg_lin.attribute7;    --PAAD NOV 25
                    v_description_sio := reg_lin.description;    --PAAD NOV 25

                    IF v_monto_iepslt_sio > 0
                    THEN
                        ------------------------------------------           'FACTURA NAGRUP'
                        reg_lin.amount := r_l.attribute11;
                        reg_lin.unit_selling_price := r_l.attribute11;
                        reg_lin.quantity := NULL;                --v_cantidad;
                        reg_lin.quantity_ordered := NULL;        --v_cantidad;
                        reg_lin.interface_line_id := NULL;
                        reg_lin.line_type := 'LINE';
                        reg_lin.description :=
                            'IEPS_LT.' || reg_lin.description;
                        reg_lin.sales_order_line :=
                               reg_lin.sales_order_line
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.NEXTVAL);
                        reg_lin.interface_line_attribute11 :=
                               reg_lin.interface_line_attribute11
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.CURRVAL);
                        reg_lin.attribute1 := NULL;
                        reg_lin.attribute2 := NULL;
                        reg_lin.attribute3 := NULL;
                        reg_lin.attribute4 := NULL;
                        reg_lin.attribute5 := NULL;
                        reg_lin.attribute6 := NULL;
                        reg_lin.attribute7 := NULL;
                        reg_lin.attribute8 := NULL;
                        reg_lin.attribute9 := NULL;
                        reg_lin.attribute10 := NULL;
                        reg_lin.attribute11 := NULL;
                        reg_lin.attribute12 := NULL;
                        reg_lin.attribute13 := NULL;
                        reg_lin.attribute14 := NULL;
                        reg_lin.attribute15 := NULL;

                        ---
                        IF v_error = 0
                        THEN
                            UPDATE ra_interface_lines_all
                               --- solo actualiza la linea origen
                               SET line_type = 'LINE'
                             WHERE CURRENT OF c_lineas;

                            v_tot_reg_act := v_tot_reg_act + 1;

                            IF reg_lin.amount <> 0
                            THEN
                                INSERT INTO ra_interface_lines_all
                                     VALUES reg_lin;

                                v_tot_reg_ins := v_tot_reg_ins + 1;
                                l ('    Inserta NA group');
                            ELSE
                                l ('     Att11= 0 ');
                            END IF;
                        END IF;
                    END IF;

                    IF v_monto_iepsed_sio > 0
                    THEN                   -- CEDC  ENE-26 -- IEPS EDULCORANTE
                        ------------------------------------------           'FACTURA NAGRUP'
                        reg_lin.amount := r_l.attribute7;
                        reg_lin.unit_selling_price := r_l.attribute7;
                        reg_lin.quantity := NULL;                --v_cantidad;
                        reg_lin.quantity_ordered := NULL;        --v_cantidad;
                        reg_lin.interface_line_id := NULL;
                        reg_lin.line_type := 'LINE';
                        reg_lin.description :=
                            'IEPS_LT_ED.' || reg_lin.description;
                        reg_lin.sales_order_line :=
                               reg_lin.sales_order_line
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.NEXTVAL);
                        reg_lin.interface_line_attribute7 :=
                               reg_lin.interface_line_attribute7
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.CURRVAL);
                        reg_lin.attribute1 := NULL;
                        reg_lin.attribute2 := NULL;
                        reg_lin.attribute3 := NULL;
                        reg_lin.attribute4 := NULL;
                        reg_lin.attribute5 := NULL;
                        reg_lin.attribute6 := NULL;
                        reg_lin.attribute7 := NULL;
                        reg_lin.attribute8 := NULL;
                        reg_lin.attribute9 := NULL;
                        reg_lin.attribute10 := NULL;
                        reg_lin.attribute11 := NULL;
                        reg_lin.attribute12 := NULL;
                        reg_lin.attribute13 := NULL;
                        reg_lin.attribute14 := NULL;
                        reg_lin.attribute15 := NULL;

                        ---
                        IF v_error = 0
                        THEN
                            UPDATE ra_interface_lines_all
                               --- solo actualiza la linea origen
                               SET line_type = 'LINE'
                             WHERE CURRENT OF c_lineas;

                            v_tot_reg_act := v_tot_reg_act + 1;

                            IF reg_lin.amount <> 0
                            THEN
                                INSERT INTO ra_interface_lines_all
                                     VALUES reg_lin;

                                v_tot_reg_ins := v_tot_reg_ins + 1;
                                l ('    Inserta NA group ED');
                            ELSE
                                l ('     Att7= 0 ');
                            END IF;
                        END IF;
                    END IF;
                ELSIF r_l.interface_line_context =
                      'FACTURAS MANUALES VITALITE'
                THEN
                    ----======================######################**********************
                    IF vo_ieps_litro <> 0                   --vo_ieps_litro_ed
                    THEN
                        ---------------------------===============================$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
                        v_tasa := 0;
                        vtax_code := 0;
                        --
                        v_compuesto := NULL;
                        v_quantity := NULL;
                        v_unit_standard_price := NULL;
                        v_unit_selling_price := NULL;
                        v_monto_tmp := NULL;
                        --v_monto_precio := 0;
                        --v_cantidad := 0;
                        v_monto := 0;

                        --

                        BEGIN
                            SELECT ft.description
                              INTO vtax_code
                              FROM apps.fnd_flex_values_tl   ft,
                                   apps.fnd_flex_values      fb,
                                   apps.fnd_flex_value_sets  fc
                             WHERE     1 = 1
                                   AND fb.flex_value_id = ft.flex_value_id
                                   AND ft.language = 'ESA'
                                   AND fb.enabled_flag = 'Y'
                                   AND fb.flex_value_set_id =
                                       fc.flex_value_set_id
                                   AND fc.flex_value_set_name =
                                       'XXCUST_REPLACE_IMP'
                                   AND fb.flex_value = r_l.tax_code;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                vtax_code := r_l.tax_code;
                        END;

                        --MSJOUT('### V1.2 ELSE:: ASIGNA CANTIDAD Y PRESIO UNITARIO');
                        v_compuesto := pa_obten_impuestos (r_l.tax_code);
                        v_quantity := REPLACE (reg_lin.quantity, ',', '.');
                        v_unit_standard_price :=
                            REPLACE (r_l.unit_standard_price, ',', '.');
                        v_unit_selling_price :=
                            REPLACE (r_l.unit_selling_price, ',', '.');

                        IF v_compuesto = 0
                        THEN              --- el codigo de im puesto es simple
                            --l (
                            --        '    tax simple:'
                            --     || t_por_tax (1)
                            --     || '   desplegado.tipo_tax:'
                            --     || t_tipo_tax (1));
                            v_tasa := t_por_tax (1) / 100;

                            ---
                            SELECT DECODE (
                                       SUBSTR (t_tipo_tax (1), 5, 3),
                                       'INC', (  (v_quantity * vo_ieps_litro)
                                               + (  v_quantity
                                                  * vo_ieps_litro
                                                  * v_tasa)),
                                       v_quantity * vo_ieps_litro)
                              INTO v_monto_tmp
                              FROM DUAL;
                        -----
                        --l (
                        --       ' decode( substr(t_tipo_tax(1),5,3)   ,INC,  ((v_quantity*vo_ieps_litro)+(v_quantity * vo_ieps_litro * v_tasa))    , v_quantity*vo_ieps_litro  ) =>'
                        --    || 'decode( '
                        --    || SUBSTR (t_tipo_tax (1), 5, 3)
                        --    || '   ,INC,  (('
                        --    || TO_CHAR ((v_quantity * vo_ieps_litro) + (v_quantity * vo_ieps_litro * v_tasa))
                        --    || '    , '
                        --    || TO_CHAR (v_quantity * vo_ieps_litro)
                        --    || '  )  ');
                        --l (' importe_tmp:' || TO_CHAR (v_monto_tmp));
                        END IF;

                        --MSJOUT('### V2 v_tasa:' || TO_CHAR (v_tasa) || ' *v_monto_tmp: ' || TO_CHAR (v_monto_tmp) || ' *v_monto_taxes: ' || TO_CHAR (v_monto_taxes));
                        --l (
                        --       ' v_tasa:'
                        --    || TO_CHAR (v_tasa)
                        --    || '*v_monto_tmp:'
                        --    || TO_CHAR (v_monto_tmp)
                        --    || '*v_monto_taxes:'
                        --    || TO_CHAR (v_monto_taxes));
                        f_imp_x_moneda (
                            p_moneda    => reg_lin.currency_code,
                            p_tipo      => reg_lin.conversion_type,
                            p_rate      => reg_lin.conversion_rate,
                            p_date      =>
                                NVL (reg_lin.ship_date_actual,
                                     reg_lin.sales_order_date),
                            p_importe   => v_monto_tmp,
                            o_monto     => v_monto,
                            o_status    => v_status);
                        l (' v_monto:' || TO_CHAR (v_monto));

                        ---------------------------===============================$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
                        --l ('  line_id:' || TO_CHAR (r_l.interface_line_id));
                        --MSJOUT ('  line_id:' || TO_CHAR (r_l.interface_line_id));
                        --MSJOUT ('  currency_code:' || reg_lin.currency_code);
                        --MSJOUT ('  conversion_type:' || reg_lin.conversion_type);
                        --MSJOUT ('  conversion_rate:' || reg_lin.conversion_rate);
                        --MSJOUT ('  ship_date_actual:' || reg_lin.ship_date_actual||', sales_order_date:'||reg_lin.sales_order_date);
                        --MSJOUT ('  quantity:' || reg_lin.quantity||', vo_ieps_litro:'||vo_ieps_litro);

                        ---->>>f_imp_x_moneda (
                        ---->>>    p_moneda    => reg_lin.currency_code,
                        ---->>>     p_tipo      => reg_lin.conversion_type,
                        ---->>>     p_rate      => reg_lin.conversion_rate,
                        ---->>>     p_date      => NVL (reg_lin.ship_date_actual, reg_lin.sales_order_date),
                        ---->>>     p_importe   => reg_lin.quantity * vo_ieps_litro,
                        ---->>>     o_monto     => v_monto,
                        ---->>>     o_status    => v_status);

                        IF v_status = 1
                        THEN
                            v_error := 1;
                        END IF;

                        --Si no termino en error considerar el tipo de impuesto
                        IF v_type = 'CM'
                        THEN
                            v_monto := v_monto;
                            v_monto_precio := v_monto * -1;
                            v_cantidad := -1;
                        END IF;

                        MSJOUT ('  v_cantidad:' || v_cantidad);
                        MSJOUT ('  v_monto_precio:' || v_monto_precio);

                        reg_lin.amount := ROUND (v_monto, 2);
                        reg_lin.unit_selling_price := v_monto_precio;
                        reg_lin.unit_standard_price := v_monto_precio;
                        reg_lin.quantity := v_cantidad;
                        reg_lin.quantity_ordered := v_cantidad;
                        reg_lin.interface_line_id := NULL;
                        reg_lin.line_type := 'LINE';
                        reg_lin.description :=
                            'IEPS_LT.' || reg_lin.description;
                        reg_lin.sales_order_line :=
                               reg_lin.sales_order_line
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.NEXTVAL);
                        reg_lin.interface_line_attribute7 :=
                               reg_lin.interface_line_attribute7
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.CURRVAL);
                        reg_lin.interface_line_attribute5 :=
                            reg_lin.interface_line_attribute5 || '.1';

                        IF v_error = 0
                        THEN
                            MSJOUT ('ED_v_type: ' || v_type);
                            MSJOUT ('ED_v_monto: ' || v_monto);

                            UPDATE ra_interface_lines_all
                               SET line_type = 'LINE',
                                   interface_line_attribute1 =
                                       interface_line_attribute1,
                                   --AMOUNT                        = v_monto_upd ,  ---decode(v_tasa,0, amount-v_monto_upd, trunc(v_quantity*v_unit_selling ,2)  ),   ---decode ( v_type, 'CM', amount, TRUNC(TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)*v_quantity,2)), /* solicitud de funcional */
                                   --UNIT_SELLING_PRICE      = v_unit_selling ,   -- decode(v_tasa,0, v_unit_selling /*UNIT_SELLING_PRICE*/,    v_unit_selling  ), --agregado por PAAD (14012014)
                                   --UNIT_STANDARD_PRICE  = v_unit_standard  --decode(v_tasa,0,v_unit_standard /*UNIT_STANDARD_PRICE*/, v_unit_standard ) --agregado por PAAD (14012014)
                                   amount =
                                       DECODE (
                                           v_type,
                                           'CM',                     --amount,
                                                 TRUNC (
                                                       TRUNC (
                                                             unit_selling_price
                                                           - (  v_monto
                                                              / quantity),
                                                           2)
                                                     * quantity,
                                                     2),
                                           TRUNC (
                                                 TRUNC (
                                                       unit_selling_price
                                                     - (v_monto / quantity),
                                                     2)
                                               * quantity,
                                               2)), /* solicitud de funcional */
                                   unit_selling_price =
                                       DECODE (
                                           v_type,
                                           'CM',         --unit_selling_price,
                                                 TRUNC (
                                                       unit_selling_price
                                                     - (v_monto / quantity),
                                                     2),
                                           TRUNC (
                                                 unit_selling_price
                                               - (v_monto / quantity),
                                               2)) --agregado por PAAD (14012014)
                             -- UNIT_STANDARD_PRICE  = decode ( v_type, 'CM',UNIT_STANDARD_PRICE,TRUNC(UNIT_STANDARD_PRICE - ( v_monto/QUANTITY ),2)) --agregado por PAAD (14012014)
                             WHERE CURRENT OF c_lineas;

                            v_tot_reg_act := v_tot_reg_act + 1;

                            BEGIN
                                INSERT INTO ra_interface_lines_all
                                     VALUES reg_lin;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    V_ERROR := 1;

                                    MSJOUT (
                                           '## ERROR:: [FACTURAS MANUALES VITALITE] AL INSERTAR IEPS EN RA_INTERFACE_LINES_ALL_'
                                        || SQLERRM);
                            END;

                            /* SE COLOCA LA SECCION PARA QUE SE COLOCADA LA DISTRIBUCION DE LAS
                            * LINEAS DE IEPS EN LA TABLA DE DISTRIBUCIONES DE LA INTERFACE
                            * IGARCIA 13-MAR-2019
                            */
                            IF V_ERROR = 0
                            THEN
                                BEGIN
                                    --MSJOUT (
                                    --       '## SE GENERA DISTRIBUCION PARA LINEA DE IEPS DE UNA FACTURA ['
                                    --    || r_l.interface_line_context
                                    --    || '] ORIGEN:: '
                                    --    || r_l.batch_source_name);

                                    SELECT CC.SEGMENT1,
                                           CC.SEGMENT2,
                                           CC.SEGMENT3,
                                           CC.SEGMENT4,
                                           CC.SEGMENT5,
                                           CC.SEGMENT6,
                                           CC.SEGMENT7,
                                           CC.CODE_COMBINATION_ID
                                      INTO V_CC_SEGMENT1,
                                           V_CC_SEGMENT2,
                                           V_CC_SEGMENT3,
                                           V_CC_SEGMENT4,
                                           V_CC_SEGMENT5,
                                           V_CC_SEGMENT6,
                                           V_CC_SEGMENT7,
                                           V_CODE_COMBINATION_ID
                                      FROM ZX_STATUS_B                ZS,
                                           ZX_TAXES_B                 ZT,
                                           ZX_RATES_B                 ZR,
                                           ZX_ACCOUNTS                ZA,
                                           GL_CODE_COMBINATIONS       CC,
                                           HR_ALL_ORGANIZATION_UNITS  OU
                                     WHERE     1 = 1
                                           AND ZS.EFFECTIVE_TO IS NULL
                                           AND ZS.TAX_REGIME_CODE =
                                               ZT.TAX_REGIME_CODE
                                           AND ZS.TAX = ZT.TAX
                                           AND ZS.CONTENT_OWNER_ID =
                                               ZT.CONTENT_OWNER_ID
                                           AND ZS.TAX_STATUS_CODE =
                                               ZR.TAX_STATUS_CODE
                                           AND ZS.TAX_REGIME_CODE =
                                               ZR.TAX_REGIME_CODE
                                           AND ZS.TAX = ZR.TAX
                                           AND ZS.CONTENT_OWNER_ID =
                                               ZR.CONTENT_OWNER_ID
                                           AND ZR.ACTIVE_FLAG = 'Y'
                                           AND ZR.TAX_RATE_ID =
                                               ZA.TAX_ACCOUNT_ENTITY_ID
                                           AND ZA.TAX_ACCOUNT_CCID =
                                               CC.CODE_COMBINATION_ID
                                           AND ZA.INTERNAL_ORGANIZATION_ID =
                                               OU.ORGANIZATION_ID
                                           AND TAX_RATE_CODE = 'IEPS LT'
                                           AND ZA.INTERNAL_ORGANIZATION_ID =
                                               REG_LIN.ORG_ID;

                                    INSERT INTO RA_INTERFACE_DISTRIBUTIONS_ALL (
                                                    INTERFACE_LINE_CONTEXT,
                                                    INTERFACE_LINE_ATTRIBUTE1,
                                                    INTERFACE_LINE_ATTRIBUTE2,
                                                    INTERFACE_LINE_ATTRIBUTE3,
                                                    INTERFACE_LINE_ATTRIBUTE4,
                                                    INTERFACE_LINE_ATTRIBUTE5,
                                                    INTERFACE_LINE_ATTRIBUTE6,
                                                    INTERFACE_LINE_ATTRIBUTE7,
                                                    INTERFACE_LINE_ATTRIBUTE8,
                                                    INTERFACE_LINE_ATTRIBUTE9,
                                                    INTERFACE_LINE_ATTRIBUTE10,
                                                    INTERFACE_LINE_ATTRIBUTE11,
                                                    INTERFACE_LINE_ATTRIBUTE12,
                                                    INTERFACE_LINE_ATTRIBUTE13,
                                                    INTERFACE_LINE_ATTRIBUTE14,
                                                    INTERFACE_LINE_ATTRIBUTE15,
                                                    ACCOUNT_CLASS,
                                                    AMOUNT,
                                                    PERCENT,
                                                    CODE_COMBINATION_ID,
                                                    SEGMENT1,
                                                    SEGMENT2,
                                                    SEGMENT3,
                                                    SEGMENT4,
                                                    SEGMENT5,
                                                    SEGMENT6,
                                                    SEGMENT7,
                                                    ORG_ID,
                                                    CREATION_DATE,
                                                    SEGMENT25)
                                             VALUES (
                                                        REG_LIN.INTERFACE_LINE_CONTEXT,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE1,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE2,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE3,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE4,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE5,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE6,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE7,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE8,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE9,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE10,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE11,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE12,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE13,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE14,
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE15,
                                                        'REV',
                                                        REG_LIN.AMOUNT,
                                                        '100',
                                                        V_CODE_COMBINATION_ID,
                                                        V_CC_SEGMENT1,
                                                        V_CC_SEGMENT2,
                                                        V_CC_SEGMENT3,
                                                        V_CC_SEGMENT4,
                                                        V_CC_SEGMENT5,
                                                        V_CC_SEGMENT6,
                                                        V_CC_SEGMENT7,
                                                        REG_LIN.ORG_ID,
                                                        REG_LIN.CREATION_DATE,
                                                        REG_LIN.TRX_NUMBER);
                                --MSJOUT (
                                --       '## SE GENERA DISTRIBUCION PARA LINEA DE IEPS DE UNA FACTURA ['
                                --    || r_l.interface_line_context
                                --    || '] ORIGEN:: '
                                --    || r_l.batch_source_name
                                --    || ' ID CUENTA: '
                                --    ||V_CODE_COMBINATION_ID||' CUENTA: '||
                                --      V_CC_SEGMENT1||'-'||
                                --      V_CC_SEGMENT2||'-'||
                                --      V_CC_SEGMENT3||'-'||
                                --      V_CC_SEGMENT4||'-'||
                                --      V_CC_SEGMENT5||'-'||
                                --      V_CC_SEGMENT6||'-'||
                                --      V_CC_SEGMENT7
                                --    );
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        V_ERROR := 1;

                                        MSJOUT (
                                               '## ERROR:: [FACTURAS MANUALES VITALITE] AL INSERTAR DISTRIBUCION DE IEPS EN RA_INTERFACE_DISTRIBUTIONS_ALL'
                                            || SQLERRM);
                                END;
                            END IF;

                            v_tot_reg_ins := v_tot_reg_ins + 1;
                            l ('   Inserta  Facturas Automaticas Corp');
                        END IF;
                    END IF;

                    ----======================######################**********************
                    --MSJOUT ('   INSERTAR IEPS ED EN RA_INTERFACE_LINES_ALL');
                    reg_lin := r_l; --Se agrega linea para intentar conservar el dato de cantidad

                    IF vo_ieps_litro_ed <> 0 AND vo_chk_ieps_litro_ed = 1
                    THEN
                        ---------------------------===============================$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
                        v_tasa := 0;
                        vtax_code := 0;
                        --
                        v_compuesto := NULL;
                        v_quantity := NULL;
                        v_unit_standard_price := NULL;
                        v_unit_selling_price := NULL;
                        v_monto_tmp := NULL;
                        --v_monto_precio := 0;
                        --v_cantidad := 0;
                        v_monto := 0;

                        --

                        -- Validaci¿n para modificar la tasa de impuestos en las Refacturaciones

                        BEGIN
                            SELECT ft.description
                              INTO vtax_code
                              FROM apps.fnd_flex_values_tl   ft,
                                   apps.fnd_flex_values      fb,
                                   apps.fnd_flex_value_sets  fc
                             WHERE     1 = 1
                                   AND fb.flex_value_id = ft.flex_value_id
                                   AND ft.language = 'ESA'
                                   AND fb.enabled_flag = 'Y'
                                   AND fb.flex_value_set_id =
                                       fc.flex_value_set_id
                                   AND fc.flex_value_set_name =
                                       'XXCUST_REPLACE_IMP'
                                   AND fb.flex_value = r_l.tax_code;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                vtax_code := r_l.tax_code;
                        END;

                        --MSJOUT('### V1.2 ELSE:: ASIGNA CANTIDAD Y PRESIO UNITARIO');
                        v_compuesto := pa_obten_impuestos (r_l.tax_code);
                        v_quantity := REPLACE (reg_lin.quantity, ',', '.');
                        v_unit_standard_price :=
                            REPLACE (r_l.unit_standard_price, ',', '.');
                        v_unit_selling_price :=
                            REPLACE (r_l.unit_selling_price, ',', '.');

                        IF v_compuesto = 0
                        THEN              --- el codigo de im puesto es simple
                            --l (
                            --       '    tax simple:'
                            --    || t_por_tax (1)
                            --    || '   desplegado.tipo_tax:'
                            --    || t_tipo_tax (1));
                            v_tasa := t_por_tax (1) / 100;

                            ---
                            SELECT DECODE (
                                       SUBSTR (t_tipo_tax (1), 5, 3),
                                       'INC', (  (  v_quantity
                                                  * vo_ieps_litro_ed)
                                               + (  v_quantity
                                                  * vo_ieps_litro_ed
                                                  * v_tasa)),
                                       v_quantity * vo_ieps_litro_ed)
                              INTO v_monto_tmp
                              FROM DUAL;

                            -----
                            --l (
                            --       ' decode( substr(t_tipo_tax(1),5,3)   ,INC,  ((v_quantity*vo_ieps_litro)+(v_quantity * vo_ieps_litro * v_tasa))    , v_quantity*vo_ieps_litro  ) =>'
                            --    || 'decode( '
                            --    || SUBSTR (t_tipo_tax (1), 5, 3)
                            --    || '   ,INC,  (('
                            --    || TO_CHAR ((v_quantity * vo_ieps_litro_ed) + (v_quantity * vo_ieps_litro_ed * v_tasa))
                            --    || '    , '
                            --    || TO_CHAR (v_quantity * vo_ieps_litro_ed)
                            --    || '  )  ');
                            l (' importe_tmp:' || TO_CHAR (v_monto_tmp));
                        END IF;

                        --MSJOUT('### V2 v_tasa:' || TO_CHAR (v_tasa) || ' *v_monto_tmp: ' || TO_CHAR (v_monto_tmp) || ' *v_monto_taxes: ' || TO_CHAR (v_monto_taxes));
                        --l (
                        --       ' v_tasa:'
                        --    || TO_CHAR (v_tasa)
                        --    || '*v_monto_tmp:'
                        --    || TO_CHAR (v_monto_tmp)
                        --    || '*v_monto_taxes:'
                        --    || TO_CHAR (v_monto_taxes));
                        f_imp_x_moneda (
                            p_moneda    => reg_lin.currency_code,
                            p_tipo      => reg_lin.conversion_type,
                            p_rate      => reg_lin.conversion_rate,
                            p_date      =>
                                NVL (reg_lin.ship_date_actual,
                                     reg_lin.sales_order_date),
                            p_importe   => v_monto_tmp,
                            o_monto     => v_monto,
                            o_status    => v_status);
                        l (' v_monto:' || TO_CHAR (v_monto));

                        ---------------------------===============================$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
                        --l ('  line_id:' || TO_CHAR (r_l.interface_line_id));

                        --MSJOUT ('  ED line_id:' || TO_CHAR (r_l.interface_line_id));
                        --MSJOUT ('  ED currency_code:' || reg_lin.currency_code);
                        --MSJOUT ('  ED conversion_type:' || reg_lin.conversion_type);
                        --MSJOUT ('  ED conversion_rate:' || reg_lin.conversion_rate);
                        --MSJOUT ('  ED ship_date_actual:' || reg_lin.ship_date_actual||', sales_order_date:'||reg_lin.sales_order_date);
                        --MSJOUT ('  ED quantity:' || reg_lin.quantity||', vo_ieps_litro_ed:'||vo_ieps_litro_ed);

                        ---->>>f_imp_x_moneda (
                        ---->>>    p_moneda    => reg_lin.currency_code,
                        ---->>>    p_tipo      => reg_lin.conversion_type,
                        ---->>>    p_rate      => reg_lin.conversion_rate,
                        ---->>>    p_date      => NVL (reg_lin.ship_date_actual, reg_lin.sales_order_date),
                        ---->>>    p_importe   => reg_lin.quantity * vo_ieps_litro_ed,
                        ---->>>    o_monto     => v_monto,
                        ---->>>    o_status    => v_status);

                        --MSJOUT ('f_imp_x_moneda v_monto: '||v_monto||', v_status'||v_status);
                        IF v_status = 1
                        THEN
                            v_error := 1;
                        END IF;

                        IF v_type = 'CM'
                        THEN
                            v_monto := v_monto;
                            v_monto_precio := v_monto * -1;
                            v_cantidad := -1;
                        END IF;

                        --MSJOUT ('  ED v_cantidad:'||v_cantidad);
                        --MSJOUT ('  ED v_monto_precio:'||v_monto_precio);

                        reg_lin.amount := ROUND (v_monto, 2);
                        reg_lin.unit_selling_price := v_monto_precio;
                        reg_lin.unit_standard_price := v_monto_precio;
                        reg_lin.quantity := v_cantidad;
                        reg_lin.quantity_ordered := v_cantidad;
                        reg_lin.interface_line_id := NULL;
                        reg_lin.line_type := 'LINE';
                        reg_lin.description :=
                            'IEPS_LT_ED.' || reg_lin.description;
                        reg_lin.sales_order_line :=
                               reg_lin.sales_order_line
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.NEXTVAL);
                        reg_lin.interface_line_attribute7 :=
                               reg_lin.interface_line_attribute7
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.CURRVAL);
                        reg_lin.interface_line_attribute5 :=
                            reg_lin.interface_line_attribute5 || '.2';

                        IF v_error = 0
                        THEN
                            --                        MSJOUT ('Prueba IEPS');
                            --                        MSJOUT ('reg_lin.description:' || reg_lin.description);
                            --                        MSJOUT ('unit_selling_price:' || reg_lin.unit_selling_price);
                            --                               MSJOUT ('v_monto:' || v_monto);
                            --                               MSJOUT ('quantity:' || reg_lin.quantity);
                            --                        MSJOUT ('Prueba IEPS FIN' );
                            UPDATE ra_interface_lines_all
                               SET line_type = 'LINE',
                                   interface_line_attribute1 =
                                       interface_line_attribute1,
                                   --AMOUNT                        = v_monto_upd ,  ---decode(v_tasa,0, amount-v_monto_upd, trunc(v_quantity*v_unit_selling ,2)  ),   ---decode ( v_type, 'CM', amount, TRUNC(TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)*v_quantity,2)), /* solicitud de funcional */
                                   --UNIT_SELLING_PRICE      = v_unit_selling ,   -- decode(v_tasa,0, v_unit_selling /*UNIT_SELLING_PRICE*/,    v_unit_selling  ), --agregado por PAAD (14012014)
                                   --UNIT_STANDARD_PRICE  = v_unit_standard  --decode(v_tasa,0,v_unit_standard /*UNIT_STANDARD_PRICE*/, v_unit_standard ) --agregado por PAAD (14012014)
                                   amount =
                                       DECODE (
                                           v_type,
                                           'CM',                     --amount,
                                                 TRUNC (
                                                       TRUNC (
                                                             unit_selling_price
                                                           - (  v_monto
                                                              / quantity),
                                                           2)
                                                     * quantity,
                                                     2),
                                           TRUNC (
                                                 TRUNC (
                                                       unit_selling_price
                                                     - (v_monto / quantity),
                                                     2)
                                               * quantity,
                                               2)), /* solicitud de funcional */
                                   unit_selling_price =
                                       DECODE (
                                           v_type,
                                           'CM',         --unit_selling_price,
                                                 TRUNC (
                                                       unit_selling_price
                                                     - (v_monto / quantity),
                                                     2),
                                           TRUNC (
                                                 unit_selling_price
                                               - (v_monto / quantity),
                                               2)) --agregado por PAAD (14012014)
                             -- UNIT_STANDARD_PRICE  = decode ( v_type, 'CM',UNIT_STANDARD_PRICE,TRUNC(UNIT_STANDARD_PRICE - ( v_monto/QUANTITY ),2)) --agregado por PAAD (14012014)
                             WHERE CURRENT OF c_lineas;

                            v_tot_reg_act := v_tot_reg_act + 1;

                            BEGIN
                                INSERT INTO ra_interface_lines_all
                                     VALUES reg_lin;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    V_ERROR := 1;

                                    MSJOUT (
                                           '## ERROR:: [FACTURAS MANUALES VITALITE] AL INSERTAR IEPS ED EN RA_INTERFACE_LINES_ALL_'
                                        || SQLERRM);
                            END;
                        END IF;


                        /* SE COLOCA LA SECCION PARA QUE SE COLOCADA LA DISTRIBUCION DE LAS
                      * LINEAS DE IEPS EN LA TABLA DE DISTRIBUCIONES DE LA INTERFACE
                      * IGARCIA 13-MAR-2019
                      */
                        IF V_ERROR = 0
                        THEN
                            BEGIN
                                MSJOUT (
                                       '## SE GENERA DISTRIBUCION PARA LINEA DE IEPS ED DE UNA FACTURA ['
                                    || r_l.interface_line_context
                                    || '] ORIGEN:: '
                                    || r_l.batch_source_name);

                                SELECT CC.SEGMENT1,
                                       CC.SEGMENT2,
                                       CC.SEGMENT3,
                                       CC.SEGMENT4,
                                       CC.SEGMENT5,
                                       CC.SEGMENT6,
                                       CC.SEGMENT7,
                                       CC.CODE_COMBINATION_ID
                                  INTO V_CC_SEGMENT1,
                                       V_CC_SEGMENT2,
                                       V_CC_SEGMENT3,
                                       V_CC_SEGMENT4,
                                       V_CC_SEGMENT5,
                                       V_CC_SEGMENT6,
                                       V_CC_SEGMENT7,
                                       V_CODE_COMBINATION_ID
                                  FROM ZX_STATUS_B                ZS,
                                       ZX_TAXES_B                 ZT,
                                       ZX_RATES_B                 ZR,
                                       ZX_ACCOUNTS                ZA,
                                       GL_CODE_COMBINATIONS       CC,
                                       HR_ALL_ORGANIZATION_UNITS  OU
                                 WHERE     1 = 1
                                       AND ZS.EFFECTIVE_TO IS NULL
                                       AND ZS.TAX_REGIME_CODE =
                                           ZT.TAX_REGIME_CODE
                                       AND ZS.TAX = ZT.TAX
                                       AND ZS.CONTENT_OWNER_ID =
                                           ZT.CONTENT_OWNER_ID
                                       AND ZS.TAX_STATUS_CODE =
                                           ZR.TAX_STATUS_CODE
                                       AND ZS.TAX_REGIME_CODE =
                                           ZR.TAX_REGIME_CODE
                                       AND ZS.TAX = ZR.TAX
                                       AND ZS.CONTENT_OWNER_ID =
                                           ZR.CONTENT_OWNER_ID
                                       AND ZR.ACTIVE_FLAG = 'Y'
                                       AND ZR.TAX_RATE_ID =
                                           ZA.TAX_ACCOUNT_ENTITY_ID
                                       AND ZA.TAX_ACCOUNT_CCID =
                                           CC.CODE_COMBINATION_ID
                                       AND ZA.INTERNAL_ORGANIZATION_ID =
                                           OU.ORGANIZATION_ID
                                       AND TAX_RATE_CODE = 'IEPS LT ED'
                                       AND ZA.INTERNAL_ORGANIZATION_ID =
                                           REG_LIN.ORG_ID;

                                INSERT INTO RA_INTERFACE_DISTRIBUTIONS_ALL (
                                                INTERFACE_LINE_CONTEXT,
                                                INTERFACE_LINE_ATTRIBUTE1,
                                                INTERFACE_LINE_ATTRIBUTE2,
                                                INTERFACE_LINE_ATTRIBUTE3,
                                                INTERFACE_LINE_ATTRIBUTE4,
                                                INTERFACE_LINE_ATTRIBUTE5,
                                                INTERFACE_LINE_ATTRIBUTE6,
                                                INTERFACE_LINE_ATTRIBUTE7,
                                                INTERFACE_LINE_ATTRIBUTE8,
                                                INTERFACE_LINE_ATTRIBUTE9,
                                                INTERFACE_LINE_ATTRIBUTE10,
                                                INTERFACE_LINE_ATTRIBUTE11,
                                                INTERFACE_LINE_ATTRIBUTE12,
                                                INTERFACE_LINE_ATTRIBUTE13,
                                                INTERFACE_LINE_ATTRIBUTE14,
                                                INTERFACE_LINE_ATTRIBUTE15,
                                                ACCOUNT_CLASS,
                                                AMOUNT,
                                                PERCENT,
                                                CODE_COMBINATION_ID,
                                                SEGMENT1,
                                                SEGMENT2,
                                                SEGMENT3,
                                                SEGMENT4,
                                                SEGMENT5,
                                                SEGMENT6,
                                                SEGMENT7,
                                                ORG_ID,
                                                CREATION_DATE,
                                                SEGMENT25)
                                         VALUES (
                                                    REG_LIN.INTERFACE_LINE_CONTEXT,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE1,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE2,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE3,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE4,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE5,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE6,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE7,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE8,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE9,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE10,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE11,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE12,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE13,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE14,
                                                    REG_LIN.INTERFACE_LINE_ATTRIBUTE15,
                                                    'REV',
                                                    REG_LIN.AMOUNT,
                                                    '100',
                                                    V_CODE_COMBINATION_ID,
                                                    V_CC_SEGMENT1,
                                                    V_CC_SEGMENT2,
                                                    V_CC_SEGMENT3,
                                                    V_CC_SEGMENT4,
                                                    V_CC_SEGMENT5,
                                                    V_CC_SEGMENT6,
                                                    V_CC_SEGMENT7,
                                                    REG_LIN.ORG_ID,
                                                    REG_LIN.CREATION_DATE,
                                                    REG_LIN.TRX_NUMBER);
                            --MSJOUT (
                            --   '## SE GENERA DISTRIBUCION PARA LINEA DE IEPS ED DE UNA FACTURA ['
                            --|| r_l.interface_line_context
                            --|| '] ORIGEN:: '
                            --|| r_l.batch_source_name
                            --|| ' ID CUENTA: '
                            --||V_CODE_COMBINATION_ID||' CUENTA: '||
                            --  V_CC_SEGMENT1||'-'||
                            --  V_CC_SEGMENT2||'-'||
                            --  V_CC_SEGMENT3||'-'||
                            --  V_CC_SEGMENT4||'-'||
                            --  V_CC_SEGMENT5||'-'||
                            --  V_CC_SEGMENT6||'-'||
                            --  V_CC_SEGMENT7
                            --);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    V_ERROR := 1;

                                    MSJOUT (
                                           '## ERROR:: [FACTURAS MANUALES VITALITE] AL INSERTAR DISTRIBUCION DE IEPS ED EN RA_INTERFACE_DISTRIBUTIONS_ALL'
                                        || SQLERRM);
                            END;
                        END IF;

                        v_tot_reg_ins := v_tot_reg_ins + 1;
                        l ('   Inserta  Facturas Automaticas Corp');
                    END IF;
                -----------***************-----------==========================
                ELSIF    r_l.interface_line_context = 'ORDER ENTRY'
                      OR v_ind_refactura = '-RE'
                THEN
                    IF vo_ieps_litro > 0
                    THEN                                            -- NOV2025
                        --MSJOUT('### V1:: INGRESA A ORDER ENTRY');
                        ---------------------------------------     'ORDER ENTRY' con "-RE" o sin "-RE"
                        v_tasa := 0;
                        vtax_code := 0;

                        ---- inicio cambio impuesto INC agregado por PAAD (14012014)
                        /*      BEGIN
                                SELECT (PERCENTAGE_RATE/100)         INTO v_tasa
                                FROM ZX_RATES_B zr
                                WHERE 1 = 1
                                AND zr.TAX_RATE_CODE = reg_lin.TAX_CODE
                                AND zr.INCLUSIVE_TAX_FLAG = 'Y'
                                AND zr.EFFECTIVE_TO is null
                                AND zr.TAX != 'IEPS';
                            EXCEPTION
                                WHEN NO_DATA_FOUND             THEN
                                v_tasa := 0;
                                WHEN  TOO_MANY_ROWS             THEN
                                v_tasa := 0;
                                WHEN  OTHERS                           THEN
                                v_tasa := 0;
                            END;*/

                        -- Validaci¿n para modificar la tasa de impuestos en las Refacturaciones

                        BEGIN
                            SELECT ft.description
                              INTO vtax_code
                              FROM apps.fnd_flex_values_tl   ft,
                                   apps.fnd_flex_values      fb,
                                   apps.fnd_flex_value_sets  fc
                             WHERE     1 = 1
                                   AND fb.flex_value_id = ft.flex_value_id
                                   AND ft.language = 'ESA'
                                   AND fb.enabled_flag = 'Y'
                                   AND fb.flex_value_set_id =
                                       fc.flex_value_set_id
                                   AND fc.flex_value_set_name =
                                       'XXCUST_REPLACE_IMP'
                                   AND fb.flex_value = r_l.tax_code;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                vtax_code := r_l.tax_code;
                        END;

                        IF r_l.interface_line_context IN
                               ('FACTURAS AUTOMATICAS', 'FACTURA NAGRUP')
                        THEN
                            --MSJOUT (
                            --      '## CONTROL:: '
                            --  || v_ind_refactura
                            --  || r_l.interface_line_context);
                            v_compuesto := pa_obten_impuestos (vtax_code);
                            v_quantity := reg_lin.attribute2;
                            -- Nov2025
                            l (
                                   'IEPS Azu '
                                || v_item
                                || '-- before -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard_price:'
                                || v_unit_standard_price);
                            l (
                                   'IEPS Azu '
                                || v_item
                                || '-- before -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard_price:'
                                || v_unit_standard_price);

                            IF v_unit_standard_price = 0
                            THEN
                                v_unit_standard_price := reg_lin.attribute3;
                                v_unit_selling_price := reg_lin.attribute3;
                            END IF;

                            l (
                                   'IEPS Azu '
                                || v_item
                                || '-- after -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard_price:'
                                || v_unit_standard_price);
                            l (
                                   'IEPS Azu '
                                || v_item
                                || '-- after -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard_price:'
                                || v_unit_standard_price);
                        ELSE
                            --MSJOUT('### V1.2 ELSE:: ASIGNA CANTIDAD Y PRESIO UNITARIO');
                            v_compuesto := pa_obten_impuestos (r_l.tax_code);
                            v_quantity :=
                                REPLACE (reg_lin.quantity, ',', '.');
                            -- Nov2025
                            l (
                                   'IEPS Azu '
                                || v_item
                                || '-- before -- v_unit_standard_price:'
                                || v_unit_standard_price);
                            l (
                                   'IEPS Azu '
                                || v_item
                                || '-- before -- v_unit_standard_price:'
                                || v_unit_standard_price);

                            IF v_unit_standard_price = 0
                            THEN
                                v_unit_standard_price :=
                                    REPLACE (r_l.unit_standard_price,
                                             ',',
                                             '.');
                                v_unit_selling_price :=
                                    REPLACE (r_l.unit_selling_price,
                                             ',',
                                             '.');
                            END IF;

                            l (
                                   'IEPS Azu '
                                || v_item
                                || '-- after -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard_price:'
                                || v_unit_standard_price);
                            l (
                                   'IEPS Azu '
                                || v_item
                                || '-- after -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard_price:'
                                || v_unit_standard_price);
                        END IF;

                        IF v_compuesto = 0
                        THEN              --- el codigo de im puesto es simple
                            l (
                                   '    tax simple:'
                                || t_por_tax (1)
                                || '   desplegado.tipo_tax:'
                                || t_tipo_tax (1));
                            v_tasa := t_por_tax (1) / 100;

                            ---
                            SELECT DECODE (
                                       SUBSTR (t_tipo_tax (1), 5, 3),
                                       'INC', (  (v_quantity * vo_ieps_litro)
                                               + (  v_quantity
                                                  * vo_ieps_litro
                                                  * v_tasa)),
                                       v_quantity * vo_ieps_litro)
                              INTO v_monto_tmp
                              FROM DUAL;

                            -----
                            l (
                                   ' decode( substr(t_tipo_tax(1),5,3)   ,INC,  ((v_quantity*vo_ieps_litro)+(v_quantity * vo_ieps_litro * v_tasa))    , v_quantity*vo_ieps_litro  ) =>'
                                || 'decode( '
                                || SUBSTR (t_tipo_tax (1), 5, 3)
                                || '   ,INC,  (('
                                || TO_CHAR (
                                         (v_quantity * vo_ieps_litro)
                                       + (v_quantity * vo_ieps_litro * v_tasa))
                                || '    , '
                                || TO_CHAR (v_quantity * vo_ieps_litro)
                                || '  )  ');
                            l (' importe_tmp:' || TO_CHAR (v_monto_tmp));
                        ELSE
                            l ('    tax compuesto');
                            i := 1;
                            o := t_cve_tax.LAST;
                            v_ind_imp_base := 0;
                            v_monto_taxes := 0;

                            WHILE i <= o
                            LOOP
                                l (
                                       '  t_cve_tax.('
                                    || i
                                    || ') = '
                                    || t_cve_tax (i)
                                    || '*'
                                    || t_por_tax (i)
                                    || '*'
                                    || t_tipo_tax (i));

                                IF SUBSTR (NVL (t_tipo_tax (i), '***'), 1, 3) =
                                   'BSE'
                                THEN
                                    l (
                                           ' ==>Tax base:'
                                        || t_por_tax (i)
                                        || '*'
                                        || t_tipo_tax (i)
                                        || '['
                                        || SUBSTR (
                                               NVL (t_tipo_tax (i), '***'),
                                               1,
                                               3)
                                        || ']');
                                    v_ind_imp_base := i;
                                --i := 999;
                                END IF;

                                IF t_por_tax (i) IS NOT NULL
                                THEN
                                    IF SUBSTR (t_tipo_tax (1), 5, 3) = 'INC'
                                    THEN
                                        v_monto_taxes :=
                                              v_monto_taxes
                                            +   vo_ieps_litro
                                              * ((t_por_tax (i) / 100));
                                        l (
                                               '  sumando:'
                                            || TO_CHAR (
                                                     vo_ieps_litro
                                                   * ((t_por_tax (i) / 100))));
                                    ELSE
                                        v_monto_taxes :=
                                              v_monto_taxes
                                            + (  vo_ieps_litro
                                               * ((t_por_tax (i) / 100) * -1));
                                        l (
                                               '  sumando(-):'
                                            || TO_CHAR (
                                                     vo_ieps_litro
                                                   * (  (t_por_tax (i) / 100)
                                                      * -1)));
                                    END IF;
                                END IF;

                                i := t_cve_tax.NEXT (i);
                            END LOOP;

                            v_monto_tmp := vo_ieps_litro + v_monto_taxes;
                            v_tasa := 99;
                        END IF;

                        --MSJOUT('### V2 v_tasa:' || TO_CHAR (v_tasa) || ' *v_monto_tmp: ' || TO_CHAR (v_monto_tmp) || ' *v_monto_taxes: ' || TO_CHAR (v_monto_taxes));

                        l (
                               ' v_tasa:'
                            || TO_CHAR (v_tasa)
                            || '*v_monto_tmp:'
                            || TO_CHAR (v_monto_tmp)
                            || '*v_monto_taxes:'
                            || TO_CHAR (v_monto_taxes));
                        f_imp_x_moneda (
                            p_moneda    => reg_lin.currency_code,
                            p_tipo      => reg_lin.conversion_type,
                            p_rate      => reg_lin.conversion_rate,
                            p_date      =>
                                NVL (reg_lin.ship_date_actual,
                                     reg_lin.sales_order_date),
                            p_importe   => v_monto_tmp,
                            o_monto     => v_monto,
                            o_status    => v_status);
                        l (' v_monto:' || TO_CHAR (v_monto));

                        --MSJOUT('### V3 v_monto:' || TO_CHAR (v_monto) || ' *v_type:: ' || v_type);

                        -- fin cambio impuesto INC agregado por PAAD (14012014)
                        IF v_status = 1
                        THEN
                            v_error := 1;
                        END IF;

                        IF v_type = 'CM'
                        THEN
                            v_monto := v_monto;
                            v_monto_precio := v_monto * -1;
                            v_cantidad := -1;
                        END IF;

                        reg_lin.amount := TRUNC (v_monto, 2);
                        reg_lin.unit_selling_price :=
                            TRUNC (v_monto_precio, 2);
                        reg_lin.unit_standard_price := v_monto_precio;
                        reg_lin.quantity := v_cantidad;
                        reg_lin.quantity_ordered := v_cantidad;
                        reg_lin.interface_line_id := NULL;
                        reg_lin.line_type := 'LINE';
                        reg_lin.description :=
                            'IEPS_LT.' || reg_lin.description;
                        reg_lin.sales_order_line :=
                               reg_lin.sales_order_line
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.NEXTVAL);
                        reg_lin.interface_line_attribute7 :=
                               reg_lin.interface_line_attribute7
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.CURRVAL);
                        ---
                        --MSJOUT('### V5:: ' || reg_lin.sales_order_line || ' -.- ' || reg_lin.INVENTORY_ITEM_ID || ' - IEPS_LT.' || reg_lin.DESCRIPTION);

                        l (
                               '   v_monto/v_quantity =>'
                            || TO_CHAR (v_monto)
                            || '/'
                            || TO_CHAR (v_quantity));

                        IF v_tasa = 0
                        THEN
                            l (
                                   'tasa=0, selling:'
                                || TO_CHAR (v_unit_selling_price));
                            v_unit_selling :=
                                TRUNC (
                                      v_unit_selling_price
                                    - (v_monto / v_quantity),
                                    2);
                            --r_l.UNIT_SELLING_PRICE;
                            v_unit_standard :=
                                TRUNC (
                                      v_unit_standard_price
                                    - (v_monto / v_quantity),
                                    2);            -- r_l.UNIT_STANDARD_PRICE;
                            v_monto_upd :=
                                TRUNC (v_quantity * v_unit_standard, 2);
                        ELSE
                            l (
                                   'tasa <> 0, selling:'
                                || TO_CHAR (v_unit_selling_price));
                            v_unit_selling :=
                                TRUNC (
                                      v_unit_selling_price
                                    - (v_monto / v_quantity),
                                    2);
                            v_unit_standard :=
                                TRUNC (
                                      v_unit_standard_price
                                    - (v_monto / v_quantity),
                                    2);
                            v_monto_upd :=
                                TRUNC (v_quantity * v_unit_selling, 2);
                        END IF;

                        IF v_error = 0
                        THEN
                            IF    r_l.interface_line_context =
                                  'FACTURAS AUTOMATICAS'
                               OR r_l.currency_code <> 'MXN'
                               OR (    r_l.interface_line_context =
                                       'ORDER ENTRY'
                                   AND v_ind_refactura = '-RE')
                            THEN
                                UPDATE ra_interface_lines_all
                                   --- solo actualiza la linea origen
                                   SET line_type = 'LINE'
                                 WHERE CURRENT OF c_lineas;

                                v_tot_reg_act := v_tot_reg_act + 1;
                                l (
                                       '     Es FACTURA AUTOMATICA, no se actualiza el registro base o moneda es <> a MXP o es -RE ....v_ind_refactura:'
                                    || v_ind_refactura);
                            ELSE
                                l (
                                       '     actualizando linea y monto orig.orig:'
                                    || TO_CHAR (r_l.amount)
                                    || ' cambio:'
                                    || TO_CHAR (v_monto_upd));
                                l (
                                       '*-A-*'
                                    || r_l.orig_system_bill_customer_id);
                                l_interco := NULL;

                                IF    xxgepp_ar_cm_pkg.get_category_code (
                                          r_l.orig_system_bill_customer_id) =
                                      'INTERCOMPA¿IAS'
                                   OR (    r_l.interface_line_context =
                                           'ORDER ENTRY'
                                       AND v_type = 'CM')
                                -- Add SPA 02/05/2014
                                -- Para solucionar el problema de la reference_line_id
                                THEN
                                    l ('*-B-*');
                                    xxgepp_ar_cm_pkg.get_ship_information (
                                        r_l.sales_order,
                                        r_l.org_id,
                                        r_l.interface_line_attribute6,
                                        l_ship_to_site_id,
                                        l_ship_to_customer_id);
                                    l (
                                           '*-B1 -*'
                                        || l_ship_to_site_id
                                        || ' -  '
                                        || l_ship_to_customer_id);

                                    reg_lin.orig_system_ship_customer_id :=
                                        l_ship_to_customer_id;
                                    reg_lin.orig_system_ship_address_id :=
                                        l_ship_to_site_id;

                                    l_purchase_order :=
                                        xxgepp_ar_cm_pkg.get_cust_po_number (
                                            r_l.sales_order,
                                            r_l.org_id,
                                            r_l.interface_line_attribute6,
                                            l_category_code,
                                            r_l.orig_system_bill_customer_id);
                                    l (
                                           '*-C-*'
                                        || l_purchase_order
                                        || ' - '
                                        || l_category_code);

                                    IF    l_category_code = 'RETURN'
                                       OR (    r_l.interface_line_context =
                                               'ORDER ENTRY'
                                           AND v_type = 'CM'
                                           AND l_category_code = 'ORDER')
                                    THEN
                                        --MSJOUT('### V6 l_category_code:: ' || l_category_code || ' r_l.interface_line_context:: ' || r_l.interface_line_context || ' v_type:: ' || v_type || ' l_category_code:: ' || l_category_code);
                                        l ('*-D-*');

                                        -- AQUI SE COLOCA LA PRIMERA VALIDACION DEL NUMERO DE PEDIDO PARA SU ACTUALIZAICON Y CONTROL
                                        -- JIBARRA 17-ABR-2017   SALE A PROD [27-NOV-2017]
                                        IF (V_NUMERO_PEDIDO IS NULL)
                                        THEN
                                            V_NUMERO_PEDIDO :=
                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE1;
                                        --MSJOUT('### V6.1:: IDENTIFICAMOS EL NUMERO DE PEDIDO:: ' || REG_LIN.INTERFACE_LINE_ATTRIBUTE1);
                                        ELSE
                                            IF (V_NUMERO_PEDIDO !=
                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE1)
                                            THEN
                                                IF (V_VALIDA_REFERENCE_LINE_ID =
                                                    'Y')
                                                THEN
                                                    --MSJOUT('### V6.2.1:: SE ACTUALIZAN LOS REFERENCE_LINE_ID DE TODO EL PEDIDO A NULL ');
                                                    --MSJOUT('### V6.2.1:: V_NUMERO_PEDIDO != REG_LIN.INTERFACE_LINE_ATTRIBUTE1 [' || V_NUMERO_PEDIDO || '!=' || REG_LIN.INTERFACE_LINE_ATTRIBUTE1 || ']');

                                                    UPDATE RA_INTERFACE_LINES_ALL
                                                       SET REFERENCE_LINE_ID =
                                                               NULL
                                                     WHERE     1 = 1
                                                           AND ORG_ID =
                                                               FND_PROFILE.VALUE (
                                                                   'ORG_ID')
                                                           AND BATCH_SOURCE_NAME =
                                                               NVL (
                                                                   P_BATCH_SOURCE_NAME,
                                                                   BATCH_SOURCE_NAME)
                                                           AND INTERFACE_LINE_ATTRIBUTE1 =
                                                               V_NUMERO_PEDIDO
                                                           AND INTERFACE_LINE_CONTEXT =
                                                               'ORDER ENTRY';

                                                    V_VALIDA_REFERENCE_LINE_ID :=
                                                        NULL;
                                                    V_NUMERO_PEDIDO :=
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE1;
                                                ELSE
                                                    --MSJOUT('### V6.2.2:: SE ACTUALIZAN EL NUEVO NUMERO DE PEDIDO:: ' || REG_LIN.INTERFACE_LINE_ATTRIBUTE1);
                                                    V_NUMERO_PEDIDO :=
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE1;
                                                END IF;
                                            END IF;
                                        END IF;

                                        --MSJOUT('### V7 l_reference_line_id:: ' || l_purchase_order || ' - ' || r_l.org_id || ' - ' || r_l.inventory_item_id
                                        --           || ' - ITEM - ' || r_l.purchase_order || ' - ' || r_l.sales_order_line);

                                        l_reference_line_id :=
                                            xxgepp_ar_cm_pkg.get_trx_line_id (
                                                l_purchase_order, --pedido de venta IGC 20-JUL-2016
                                                r_l.org_id,
                                                r_l.inventory_item_id,
                                                'ITEM',
                                                r_l.purchase_order, -- orden_compra IGC 20-JUL-2016
                                                r_l.sales_order_line -- l¿nea del pedido IGC 20-JUL-2016
                                                                    );

                                        L_REFERENCE_LINE_ID_IEPS :=
                                            xxgepp_ar_cm_pkg.get_trx_line_id (
                                                l_purchase_order, --pedido de venta IGC 20-JUL-2016
                                                r_l.org_id,
                                                r_l.inventory_item_id,
                                                'IEPS',
                                                r_l.purchase_order, -- orden_compra IGC 20-JUL-2016
                                                reg_lin.sales_order_line -- l¿nea del pedido IGC 20-JUL-2016
                                                                        );


                                        reg_lin.REFERENCE_LINE_ID :=
                                            L_REFERENCE_LINE_ID_IEPS;

                                        --MSJOUT('### V7.1 l_reference_line_id:: ' || l_reference_line_id || ' - ' || L_REFERENCE_LINE_ID_IEPS);
                                        l ('*-E-*' || l_reference_line_id);
                                        l_cust_trx_id :=
                                            xxgepp_ar_cm_pkg.get_cust_trx_id (
                                                l_purchase_order,
                                                r_l.org_id,
                                                l_reference_line_id);

                                        --MSJOUT('### V8 l_cust_trx_id:: ' || l_cust_trx_id);

                                        l_cust_trx_type_id :=
                                            xxgepp_ar_cm_pkg.get_trx_type_id (
                                                l_cust_trx_id);

                                        --MSJOUT('### V9 l_cust_trx_type_id:: ' || l_cust_trx_type_id);

                                        l_interco := 'Y';
                                        l (
                                               l_interco
                                            || '-'
                                            || l_cust_trx_id
                                            || '-'
                                            || l_cust_trx_type_id);
                                    END IF;

                                    l ('*-F-*');
                                END IF;

                                l ('*-G-*');
                                l (
                                       '     actualizando linea y monto orig. orig:'
                                    || TO_CHAR (r_l.amount)
                                    || ' cambio:'
                                    || TO_CHAR (v_monto_upd));

                                --MSJOUT('### V10 actualizando linea y monto orig. orig: '  || TO_CHAR (r_l.amount) || ' cambio:' || TO_CHAR (v_monto_upd));

                                /* SE COLOCA UN IF PARA VALIDAR LOS CASOS DE REFACTURA DONDE SE PUEDA PRESENTAR DOCUMENTOS CON IEPS E IMPUESTO
                                * DIFERENTE DE 0. SI NO SE CUMPLE SE APLICA EL MISMO UPDATE QUE HASTA EL MOMENTO SE ESTABA REALIZANDO
                                * JIBARRA 14-MAR-2017
                                */

                                IF (    V_MONTO_TMP IS NOT NULL
                                    AND R_L.INTERFACE_LINE_CONTEXT =
                                        'FACTURA NAGRUP'
                                    AND V_IND_REFACTURA = '-RE')
                                THEN
                                    UPDATE ra_interface_lines_all
                                       --- solo actualiza la linea origen
                                       SET line_type = 'LINE',
                                           reference_line_id =
                                               l_reference_line_id,
                                           cust_trx_type_id =
                                               DECODE (
                                                   l_interco,
                                                   'Y', DECODE (
                                                            v_type,
                                                            'CM', NVL (
                                                                      l_cust_trx_type_id,
                                                                      cust_trx_type_id),
                                                            l_cust_trx_type_id),
                                                   cust_trx_type_id),
                                           orig_system_ship_customer_id =
                                               DECODE (
                                                   NVL (
                                                       r_l.orig_system_ship_customer_id,
                                                       0),
                                                   0, l_ship_to_customer_id,
                                                   orig_system_ship_customer_id),
                                           orig_system_ship_address_id =
                                               DECODE (
                                                   NVL (
                                                       r_l.orig_system_ship_address_id,
                                                       0),
                                                   0, l_ship_to_site_id,
                                                   orig_system_ship_address_id)
                                     --AMOUNT = decode ( v_type, 'CM', amount, TRUNC(TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)*v_quantity,2)), /* solicitud de funcional */
                                     --UNIT_SELLING_PRICE  = decode ( v_type, 'CM', unit_selling_price, TRUNC(unit_selling_price - ( v_monto/v_quantity ),2)), --agregado por PAAD (14012014)
                                     --UNIT_STANDARD_PRICE  = decode ( v_type, 'CM',UNIT_STANDARD_PRICE,TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)) --agregado por PAAD (14012014)
                                     --**amount = v_monto_upd,
                                     --decode(v_tasa,0, amount-v_monto, trunc(v_quantity*v_unit_selling ,2)  ),   ---decode ( v_type, 'CM', amount, TRUNC(TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)*v_quantity,2)), /* solicitud de funcional */
                                     --**unit_selling_price = v_unit_selling,
                                     --decode(v_tasa,0, v_unit_selling /*UNIT_SELLING_PRICE*/,    v_unit_selling  ), --agregado por PAAD (14012014)
                                     --**unit_standard_price = v_unit_standard
                                     --decode(v_tasa,0,v_unit_standard /*UNIT_STANDARD_PRICE*/, v_unit_standard ) --agregado por PAAD (14012014)
                                     WHERE CURRENT OF c_lineas;
                                ELSE
                                    --MSJOUT('### V11 ELSE  R_L.INTERFACE_LINE_CONTEXT:: ' || R_L.INTERFACE_LINE_CONTEXT  || ' V_TYPE:: ' || V_TYPE
                                    --            || ' L_CATEGORY_CODE:: ' || L_CATEGORY_CODE || ' L_REFERENCE_LINE_ID:: ' || L_REFERENCE_LINE_ID);
                                    -- AL ENTRAR AQUI VALIDA NUEVAMENTE LOS PARAMETROS PARA ENTONCES CONTROLAR SI DEJO UN REFERENCE_LINE_ID NULO
                                    -- JIBARRA 17-ABR-2017   SALE A PROD [27-NOV-2017]
                                    IF (    R_L.INTERFACE_LINE_CONTEXT =
                                            'ORDER ENTRY'
                                        AND V_TYPE = 'CM'
                                        AND L_CATEGORY_CODE = 'ORDER'
                                        AND (   L_REFERENCE_LINE_ID IS NULL
                                             OR L_REFERENCE_LINE_ID_IEPS
                                                    IS NULL))
                                    THEN
                                        V_VALIDA_REFERENCE_LINE_ID := 'Y';
                                    END IF;

                                    --MSJOUT('### V11.1 ELSE - UPDATE ::' || l_reference_line_id || ' - ' || REG_LIN.reference_line_id);

                                    UPDATE ra_interface_lines_all
                                       --- solo actualiza la linea origen
                                       SET line_type = 'LINE',
                                           reference_line_id =
                                               l_reference_line_id,
                                           cust_trx_type_id =
                                               DECODE (
                                                   l_interco,
                                                   'Y', DECODE (
                                                            v_type,
                                                            'CM', NVL (
                                                                      l_cust_trx_type_id,
                                                                      cust_trx_type_id),
                                                            l_cust_trx_type_id),
                                                   cust_trx_type_id),
                                           orig_system_ship_customer_id =
                                               DECODE (
                                                   NVL (
                                                       r_l.orig_system_ship_customer_id,
                                                       0),
                                                   0, l_ship_to_customer_id,
                                                   orig_system_ship_customer_id),
                                           orig_system_ship_address_id =
                                               DECODE (
                                                   NVL (
                                                       r_l.orig_system_ship_address_id,
                                                       0),
                                                   0, l_ship_to_site_id,
                                                   orig_system_ship_address_id),
                                           --AMOUNT = decode ( v_type, 'CM', amount, TRUNC(TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)*v_quantity,2)), /* solicitud de funcional */
                                           --UNIT_SELLING_PRICE  = decode ( v_type, 'CM', unit_selling_price, TRUNC(unit_selling_price - ( v_monto/v_quantity ),2)), --agregado por PAAD (14012014)
                                           --UNIT_STANDARD_PRICE  = decode ( v_type, 'CM',UNIT_STANDARD_PRICE,TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)) --agregado por PAAD (14012014)
                                           amount = v_monto_upd,
                                           --decode(v_tasa,0, amount-v_monto, trunc(v_quantity*v_unit_selling ,2)  ),   ---decode ( v_type, 'CM', amount, TRUNC(TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)*v_quantity,2)), /* solicitud de funcional */
                                           unit_selling_price =
                                               v_unit_selling,
                                           --decode(v_tasa,0, v_unit_selling /*UNIT_SELLING_PRICE*/,    v_unit_selling  ), --agregado por PAAD (14012014)
                                           unit_standard_price =
                                               v_unit_standard
                                     --decode(v_tasa,0,v_unit_standard /*UNIT_STANDARD_PRICE*/, v_unit_standard ) --agregado por PAAD (14012014)
                                     WHERE CURRENT OF c_lineas;
                                END IF;

                                v_tot_reg_act := v_tot_reg_act + 1;
                            END IF;

                            IF r_l.currency_code = 'MXN'
                            THEN
                                l ('  Es pesos  genera IEPS ');
                                xxgepp_ar_cm_pkg.link_trx_line_id (reg_lin);

                                BEGIN
                                    INSERT INTO RA_INTERFACE_LINES_ALL
                                         VALUES REG_LIN;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        V_ERROR := 1;

                                        MSJOUT (
                                               '## ERROR:: [ORDER ENTRY] AL INSERTAR IEPS EN RA_INTERFACE_LINES_ALL_'
                                            || SQLERRM);
                                END;

                                /* SE PALCIA UN UPDATE AL ATTRIBUTE11 DE DONDE SE TOMA EL VALOR PARA EL MONTO
                                * DEL IEPS EN LAS REFACTURAS Y QUE EN LA FACTURA ELECTRONICA SE REFLEJE CORRECTAMENTE EL MONTO
                                * JIBARRA 30-AGO-2017
                                */

                                IF (reg_lin.BATCH_SOURCE_NAME LIKE '%SIO-RE')
                                THEN
                                    MSJOUT (
                                           '***  SE ACTUALIZA EL MONTO EN ATTRIBUTE11:: '
                                        || REG_LIN.AMOUNT
                                        || ' PARA '
                                        || REG_LIN.TRX_NUMBER
                                        || '-'
                                        || REG_LIN.description);
                                    L (
                                           '***  SE ACTUALIZA EL MONTO EN ATTRIBUTE11:: '
                                        || REG_LIN.AMOUNT
                                        || ' PARA '
                                        || REG_LIN.TRX_NUMBER
                                        || '-'
                                        || REG_LIN.description);

                                    UPDATE ra_interface_lines_all
                                       SET ATTRIBUTE11 = REG_LIN.AMOUNT
                                     WHERE CURRENT OF c_lineas;
                                END IF;

                                /* SE COLOCA LA SECCION PARA QUE SE COLOCADA LA DISTRIBUCION DE LAS
                                * LINEAS DE IEPS EN LA TABLA DE DISTRIBUCIONES DE LA INTERFACE
                                * JIBARRA 06-MAR-2017
                                */
                                IF (    V_ERROR = 0
                                    AND r_l.interface_line_context !=
                                        'FACTURA NAGRUP')
                                THEN
                                    BEGIN
                                        MSJOUT (
                                               '## SE GENERA DISTRIBUCION PARA LINEA DE IEPS DE UNA FACTURA ['
                                            || r_l.interface_line_context
                                            || '] ORIGEN:: '
                                            || r_l.batch_source_name);

                                        SELECT CC.SEGMENT1,
                                               CC.SEGMENT2,
                                               CC.SEGMENT3,
                                               CC.SEGMENT4,
                                               CC.SEGMENT5,
                                               CC.SEGMENT6,
                                               CC.SEGMENT7,
                                               CC.CODE_COMBINATION_ID
                                          INTO V_CC_SEGMENT1,
                                               V_CC_SEGMENT2,
                                               V_CC_SEGMENT3,
                                               V_CC_SEGMENT4,
                                               V_CC_SEGMENT5,
                                               V_CC_SEGMENT6,
                                               V_CC_SEGMENT7,
                                               V_CODE_COMBINATION_ID
                                          FROM ZX_STATUS_B                ZS,
                                               ZX_TAXES_B                 ZT,
                                               ZX_RATES_B                 ZR,
                                               ZX_ACCOUNTS                ZA,
                                               GL_CODE_COMBINATIONS       CC,
                                               HR_ALL_ORGANIZATION_UNITS  OU
                                         WHERE     1 = 1
                                               AND ZS.EFFECTIVE_TO IS NULL
                                               AND ZS.TAX_REGIME_CODE =
                                                   ZT.TAX_REGIME_CODE
                                               AND ZS.TAX = ZT.TAX
                                               AND ZS.CONTENT_OWNER_ID =
                                                   ZT.CONTENT_OWNER_ID
                                               AND ZS.TAX_STATUS_CODE =
                                                   ZR.TAX_STATUS_CODE
                                               AND ZS.TAX_REGIME_CODE =
                                                   ZR.TAX_REGIME_CODE
                                               AND ZS.TAX = ZR.TAX
                                               AND ZS.CONTENT_OWNER_ID =
                                                   ZR.CONTENT_OWNER_ID
                                               AND ZR.ACTIVE_FLAG = 'Y'
                                               AND ZR.TAX_RATE_ID =
                                                   ZA.TAX_ACCOUNT_ENTITY_ID
                                               AND ZA.TAX_ACCOUNT_CCID =
                                                   CC.CODE_COMBINATION_ID
                                               AND ZA.INTERNAL_ORGANIZATION_ID =
                                                   OU.ORGANIZATION_ID
                                               AND TAX_RATE_CODE = 'IEPS LT'
                                               AND ZA.INTERNAL_ORGANIZATION_ID =
                                                   REG_LIN.ORG_ID;

                                        INSERT INTO RA_INTERFACE_DISTRIBUTIONS_ALL (
                                                        INTERFACE_LINE_CONTEXT,
                                                        INTERFACE_LINE_ATTRIBUTE1,
                                                        INTERFACE_LINE_ATTRIBUTE2,
                                                        INTERFACE_LINE_ATTRIBUTE3,
                                                        INTERFACE_LINE_ATTRIBUTE4,
                                                        INTERFACE_LINE_ATTRIBUTE5,
                                                        INTERFACE_LINE_ATTRIBUTE6,
                                                        INTERFACE_LINE_ATTRIBUTE7,
                                                        INTERFACE_LINE_ATTRIBUTE8,
                                                        INTERFACE_LINE_ATTRIBUTE9,
                                                        INTERFACE_LINE_ATTRIBUTE10,
                                                        INTERFACE_LINE_ATTRIBUTE11,
                                                        INTERFACE_LINE_ATTRIBUTE12,
                                                        INTERFACE_LINE_ATTRIBUTE13,
                                                        INTERFACE_LINE_ATTRIBUTE14,
                                                        INTERFACE_LINE_ATTRIBUTE15,
                                                        ACCOUNT_CLASS,
                                                        AMOUNT,
                                                        PERCENT,
                                                        CODE_COMBINATION_ID,
                                                        SEGMENT1,
                                                        SEGMENT2,
                                                        SEGMENT3,
                                                        SEGMENT4,
                                                        SEGMENT5,
                                                        SEGMENT6,
                                                        SEGMENT7,
                                                        ORG_ID,
                                                        CREATION_DATE,
                                                        SEGMENT25)
                                                 VALUES (
                                                            REG_LIN.INTERFACE_LINE_CONTEXT,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE1,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE2,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE3,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE4,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE5,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE6,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE7,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE8,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE9,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE10,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE11,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE12,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE13,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE14,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE15,
                                                            'REV',
                                                            REG_LIN.AMOUNT,
                                                            '100',
                                                            V_CODE_COMBINATION_ID,
                                                            V_CC_SEGMENT1,
                                                            V_CC_SEGMENT2,
                                                            V_CC_SEGMENT3,
                                                            V_CC_SEGMENT4,
                                                            V_CC_SEGMENT5,
                                                            V_CC_SEGMENT6,
                                                            V_CC_SEGMENT7,
                                                            REG_LIN.ORG_ID,
                                                            REG_LIN.CREATION_DATE,
                                                            REG_LIN.TRX_NUMBER);
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            V_ERROR := 1;

                                            MSJOUT (
                                                   '## ERROR:: [ORDER ENTRY] AL INSERTAR DISTRIBUCION DE IEPS EN RA_INTERFACE_DISTRIBUTIONS_ALL'
                                                || SQLERRM);
                                    END;
                                END IF;

                                l ('    Inserta order entry');
                                v_tot_reg_ins := v_tot_reg_ins + 1;
                            END IF;
                        END IF;
                    END IF;                    -- NOV2025 IF vo_ieps_litro !=0

                    --- NOV2025 IF vo_ieps_litro_ed <> 0 AND vo_chk_ieps_litro_ed = 1
                    --  Ingresa al codigo si el SKU tiene Edulcorante
                    IF vo_ieps_litro_ed <> 0 AND vo_chk_ieps_litro_ed = 1
                    THEN
                        reg_lin := r_l; --Se agrega linea para intentar conservar el dato de cantidad

                        --MSJOUT('### V1:: INGRESA A ORDER ENTRY');
                        ---------------------------------------     'ORDER ENTRY' con "-RE" o sin "-RE"
                        v_tasa := 0;
                        vtax_code := 0;

                        ---- inicio cambio impuesto INC agregado por PAAD (14012014)
                        /*      BEGIN
                                SELECT (PERCENTAGE_RATE/100)         INTO v_tasa
                                FROM ZX_RATES_B zr
                                WHERE 1 = 1
                                AND zr.TAX_RATE_CODE = reg_lin.TAX_CODE
                                AND zr.INCLUSIVE_TAX_FLAG = 'Y'
                                AND zr.EFFECTIVE_TO is null
                                AND zr.TAX != 'IEPS';
                            EXCEPTION
                                WHEN NO_DATA_FOUND             THEN
                                v_tasa := 0;
                                WHEN  TOO_MANY_ROWS             THEN
                                v_tasa := 0;
                                WHEN  OTHERS                           THEN
                                v_tasa := 0;
                            END;*/

                        -- Validaci¿n para modificar la tasa de impuestos en las Refacturaciones

                        BEGIN
                            SELECT ft.description
                              INTO vtax_code
                              FROM apps.fnd_flex_values_tl   ft,
                                   apps.fnd_flex_values      fb,
                                   apps.fnd_flex_value_sets  fc
                             WHERE     1 = 1
                                   AND fb.flex_value_id = ft.flex_value_id
                                   AND ft.language = 'ESA'
                                   AND fb.enabled_flag = 'Y'
                                   AND fb.flex_value_set_id =
                                       fc.flex_value_set_id
                                   AND fc.flex_value_set_name =
                                       'XXCUST_REPLACE_IMP'
                                   AND fb.flex_value = r_l.tax_code;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                vtax_code := r_l.tax_code;
                        END;

                        IF r_l.interface_line_context IN
                               ('FACTURAS AUTOMATICAS', 'FACTURA NAGRUP')
                        THEN
                            --MSJOUT (
                            --      '## CONTROL:: '
                            --  || v_ind_refactura
                            --  || r_l.interface_line_context);
                            v_compuesto := pa_obten_impuestos (vtax_code);
                            v_quantity := reg_lin.attribute2;

                            -- Nov2025
                            --l ('IEPS Edul '|| v_item||'-- before -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_selling_price:'||v_unit_selling_price);
                            --l ('IEPS Edul '|| v_item||'-- before -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard_price:'||v_unit_standard_price);
                            --l ('IEPS Edul '|| v_item||'-- before -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_selling:'||v_unit_selling);
                            --l ('IEPS Edul '|| v_item||'-- before -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard:'||v_unit_standard);
                            IF v_unit_standard = 0
                            THEN
                                v_unit_standard_price := reg_lin.attribute3;
                                v_unit_selling_price := reg_lin.attribute3;
                            ELSE
                                v_unit_standard_price := v_unit_standard;
                                v_unit_selling_price := v_unit_standard;
                            END IF;
                        --l ('IEPS Edul '|| v_item||'-- after -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_selling_price:'||v_unit_selling_price);
                        --l ('IEPS Edul '|| v_item||'-- after -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard_price:'||v_unit_standard_price);
                        --l ('IEPS Edul '|| v_item||'-- after -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_selling:'||v_unit_selling);
                        --l ('IEPS Edul '|| v_item||'-- after -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard:'||v_unit_standard);
                        ELSE
                            --MSJOUT('### V1.2 ELSE:: ASIGNA CANTIDAD Y PRESIO UNITARIO');
                            v_compuesto := pa_obten_impuestos (r_l.tax_code);
                            v_quantity :=
                                REPLACE (reg_lin.quantity, ',', '.');

                            -- Nov2025
                            --l ('IEPS Edul '|| v_item||'-- before -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_selling_price:'||v_unit_selling_price);
                            --l ('IEPS Edul '|| v_item||'-- before -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard_price:'||v_unit_standard_price);
                            --l ('IEPS Edul '|| v_item||'-- before -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_selling:'||v_unit_selling);
                            --l ('IEPS Edul '|| v_item||'-- before -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard:'||v_unit_standard);
                            IF v_unit_standard = 0
                            THEN
                                v_unit_standard_price :=
                                    REPLACE (r_l.unit_standard_price,
                                             ',',
                                             '.');
                                v_unit_selling_price :=
                                    REPLACE (r_l.unit_selling_price,
                                             ',',
                                             '.');
                            ELSE
                                v_unit_standard_price := v_unit_standard;
                                v_unit_selling_price := v_unit_selling;
                            END IF;
                        --l ('IEPS Edul '|| v_item||'-- after -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_selling_price:'||v_unit_selling_price);
                        --l ('IEPS Edul '|| v_item||'-- after -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard_price:'||v_unit_standard_price);
                        --l ('IEPS Edul '|| v_item||'-- after -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_selling:'||v_unit_selling);
                        --l ('IEPS Edul '|| v_item||'-- after -- FACTURAS AUTOMATICAS, FACTURA NAGRUP -- v_unit_standard:'||v_unit_standard);
                        END IF;

                        IF v_compuesto = 0
                        THEN              --- el codigo de im puesto es simple
                            l (
                                   '    tax simple:'
                                || t_por_tax (1)
                                || '   desplegado.tipo_tax:'
                                || t_tipo_tax (1));
                            v_tasa := t_por_tax (1) / 100;

                            ---
                            --Nov2025
                            SELECT DECODE (
                                       SUBSTR (t_tipo_tax (1), 5, 3),
                                       'INC', (  (  v_quantity
                                                  * vo_ieps_litro_ed)
                                               + (  v_quantity
                                                  * vo_ieps_litro_ed
                                                  * v_tasa)),
                                       v_quantity * vo_ieps_litro_ed)
                              INTO v_monto_tmp
                              FROM DUAL;

                            -----
                            --Nov2025
                            l (
                                   ' decode( substr(t_tipo_tax(1),5,3)   ,INC,  ((v_quantity*vo_ieps_litro_ed)+(v_quantity * vo_ieps_litro_ed * v_tasa))    , v_quantity*vo_ieps_litro_ed  ) =>'
                                || 'decode( '
                                || SUBSTR (t_tipo_tax (1), 5, 3)
                                || '   ,INC,  (('
                                || TO_CHAR (
                                         (v_quantity * vo_ieps_litro_ed)
                                       + (  v_quantity
                                          * vo_ieps_litro_ed
                                          * v_tasa))
                                || '    , '
                                || TO_CHAR (v_quantity * vo_ieps_litro_ed)
                                || '  )  ');
                            l (' importe_tmp:' || TO_CHAR (v_monto_tmp));
                        ELSE
                            l ('    tax compuesto');
                            i := 1;
                            o := t_cve_tax.LAST;
                            v_ind_imp_base := 0;
                            v_monto_taxes := 0;

                            WHILE i <= o
                            LOOP
                                l (
                                       '  t_cve_tax.('
                                    || i
                                    || ') = '
                                    || t_cve_tax (i)
                                    || '*'
                                    || t_por_tax (i)
                                    || '*'
                                    || t_tipo_tax (i));

                                IF SUBSTR (NVL (t_tipo_tax (i), '***'), 1, 3) =
                                   'BSE'
                                THEN
                                    l (
                                           ' ==>Tax base:'
                                        || t_por_tax (i)
                                        || '*'
                                        || t_tipo_tax (i)
                                        || '['
                                        || SUBSTR (
                                               NVL (t_tipo_tax (i), '***'),
                                               1,
                                               3)
                                        || ']');
                                    v_ind_imp_base := i;
                                --i := 999;
                                END IF;

                                IF t_por_tax (i) IS NOT NULL
                                THEN
                                    IF SUBSTR (t_tipo_tax (1), 5, 3) = 'INC'
                                    THEN
                                        -- Nov2025
                                        v_monto_taxes :=
                                              v_monto_taxes
                                            +   vo_ieps_litro_ed
                                              * ((t_por_tax (i) / 100));
                                        l (
                                               '  sumando:'
                                            || TO_CHAR (
                                                     vo_ieps_litro_ed
                                                   * ((t_por_tax (i) / 100))));
                                    ELSE
                                        -- Nov2025
                                        v_monto_taxes :=
                                              v_monto_taxes
                                            + (  vo_ieps_litro_ed
                                               * ((t_por_tax (i) / 100) * -1));
                                        l (
                                               '  sumando(-):'
                                            || TO_CHAR (
                                                     vo_ieps_litro_ed
                                                   * (  (t_por_tax (i) / 100)
                                                      * -1)));
                                    END IF;
                                END IF;

                                i := t_cve_tax.NEXT (i);
                            END LOOP;

                            --Nov2025
                            v_monto_tmp := vo_ieps_litro_ed + v_monto_taxes;
                            v_tasa := 99;
                        END IF;

                        --MSJOUT('### V2 v_tasa:' || TO_CHAR (v_tasa) || ' *v_monto_tmp: ' || TO_CHAR (v_monto_tmp) || ' *v_monto_taxes: ' || TO_CHAR (v_monto_taxes));

                        l (
                               ' v_tasa:'
                            || TO_CHAR (v_tasa)
                            || '*v_monto_tmp:'
                            || TO_CHAR (v_monto_tmp)
                            || '*v_monto_taxes:'
                            || TO_CHAR (v_monto_taxes));
                        f_imp_x_moneda (
                            p_moneda    => reg_lin.currency_code,
                            p_tipo      => reg_lin.conversion_type,
                            p_rate      => reg_lin.conversion_rate,
                            p_date      =>
                                NVL (reg_lin.ship_date_actual,
                                     reg_lin.sales_order_date),
                            p_importe   => v_monto_tmp,
                            o_monto     => v_monto,
                            o_status    => v_status);
                        l (' v_monto:' || TO_CHAR (v_monto));

                        --MSJOUT('### V3 v_monto:' || TO_CHAR (v_monto) || ' *v_type:: ' || v_type);

                        -- fin cambio impuesto INC agregado por PAAD (14012014)
                        IF v_status = 1
                        THEN
                            v_error := 1;
                        END IF;

                        IF v_type = 'CM'
                        THEN
                            v_monto := v_monto;
                            v_monto_precio := v_monto * -1;
                            v_cantidad := -1;
                        END IF;

                        reg_lin.amount := TRUNC (v_monto, 2);
                        reg_lin.unit_selling_price :=
                            TRUNC (v_monto_precio, 2);
                        reg_lin.unit_standard_price := v_monto_precio;
                        reg_lin.quantity := v_cantidad;
                        reg_lin.quantity_ordered := v_cantidad;
                        reg_lin.interface_line_id := NULL;
                        reg_lin.line_type := 'LINE';
                        --Nov2025
                        reg_lin.description :=
                            'IEPS_LT_ED.' || reg_lin.description;
                        reg_lin.sales_order_line :=
                               reg_lin.sales_order_line
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.NEXTVAL);
                        reg_lin.interface_line_attribute7 :=
                               reg_lin.interface_line_attribute7
                            || '.'
                            || TO_CHAR (cust_ar_ieps_s.CURRVAL);
                        ---
                        --MSJOUT('### V5:: ' || reg_lin.sales_order_line || ' -.- ' || reg_lin.INVENTORY_ITEM_ID || ' - IEPS_LT.' || reg_lin.DESCRIPTION);

                        l (
                               '   v_monto/v_quantity =>'
                            || TO_CHAR (v_monto)
                            || '/'
                            || TO_CHAR (v_quantity));

                        IF v_tasa = 0
                        THEN
                            l (
                                   'tasa=0, selling:'
                                || TO_CHAR (v_unit_selling_price));
                            v_unit_selling :=
                                TRUNC (
                                      v_unit_selling_price
                                    - (v_monto / v_quantity),
                                    2);
                            --r_l.UNIT_SELLING_PRICE;
                            v_unit_standard :=
                                TRUNC (
                                      v_unit_standard_price
                                    - (v_monto / v_quantity),
                                    2);            -- r_l.UNIT_STANDARD_PRICE;
                            v_monto_upd :=
                                TRUNC (v_quantity * v_unit_standard, 2);
                        ELSE
                            l (
                                   'tasa <> 0, selling:'
                                || TO_CHAR (v_unit_selling_price));
                            v_unit_selling :=
                                TRUNC (
                                      v_unit_selling_price
                                    - (v_monto / v_quantity),
                                    2);
                            v_unit_standard :=
                                TRUNC (
                                      v_unit_standard_price
                                    - (v_monto / v_quantity),
                                    2);
                            v_monto_upd :=
                                TRUNC (v_quantity * v_unit_selling, 2);
                        END IF;

                        --l('v_quantity:'||v_quantity);
                        --l('v_unit_selling:'||v_unit_selling);
                        --l('v_unit_standard:'||v_unit_selling);
                        --l('v_monto_upd:'||v_unit_selling);

                        IF v_error = 0
                        THEN
                            IF    r_l.interface_line_context =
                                  'FACTURAS AUTOMATICAS'
                               OR r_l.currency_code <> 'MXN'
                               OR (    r_l.interface_line_context =
                                       'ORDER ENTRY'
                                   AND v_ind_refactura = '-RE')
                            THEN
                                UPDATE ra_interface_lines_all
                                   --- solo actualiza la linea origen
                                   SET line_type = 'LINE'
                                 WHERE CURRENT OF c_lineas;

                                v_tot_reg_act := v_tot_reg_act + 1;
                                l (
                                       '     Es FACTURA AUTOMATICA, no se actualiza el registro base o moneda es <> a MXP o es -RE ....v_ind_refactura:'
                                    || v_ind_refactura);
                            ELSE
                                l (
                                       '     actualizando linea y monto orig.orig:'
                                    || TO_CHAR (r_l.amount)
                                    || ' cambio:'
                                    || TO_CHAR (v_monto_upd));
                                l (
                                       '*-A-*'
                                    || r_l.orig_system_bill_customer_id);
                                l_interco := NULL;

                                IF    xxgepp_ar_cm_pkg.get_category_code (
                                          r_l.orig_system_bill_customer_id) =
                                      'INTERCOMPA¿IAS'
                                   OR (    r_l.interface_line_context =
                                           'ORDER ENTRY'
                                       AND v_type = 'CM')
                                -- Add SPA 02/05/2014
                                -- Para solucionar el problema de la reference_line_id
                                THEN
                                    l ('*-B-*');
                                    xxgepp_ar_cm_pkg.get_ship_information (
                                        r_l.sales_order,
                                        r_l.org_id,
                                        r_l.interface_line_attribute6,
                                        l_ship_to_site_id,
                                        l_ship_to_customer_id);
                                    l (
                                           '*-B1 -*'
                                        || l_ship_to_site_id
                                        || ' -  '
                                        || l_ship_to_customer_id);

                                    reg_lin.orig_system_ship_customer_id :=
                                        l_ship_to_customer_id;
                                    reg_lin.orig_system_ship_address_id :=
                                        l_ship_to_site_id;

                                    l_purchase_order :=
                                        xxgepp_ar_cm_pkg.get_cust_po_number (
                                            r_l.sales_order,
                                            r_l.org_id,
                                            r_l.interface_line_attribute6,
                                            l_category_code,
                                            r_l.orig_system_bill_customer_id);
                                    l (
                                           '*-C-*'
                                        || l_purchase_order
                                        || ' - '
                                        || l_category_code);

                                    IF    l_category_code = 'RETURN'
                                       OR (    r_l.interface_line_context =
                                               'ORDER ENTRY'
                                           AND v_type = 'CM'
                                           AND l_category_code = 'ORDER')
                                    THEN
                                        --MSJOUT('### V6 l_category_code:: ' || l_category_code || ' r_l.interface_line_context:: ' || r_l.interface_line_context || ' v_type:: ' || v_type || ' l_category_code:: ' || l_category_code);
                                        l ('*-D-*');

                                        -- AQUI SE COLOCA LA PRIMERA VALIDACION DEL NUMERO DE PEDIDO PARA SU ACTUALIZAICON Y CONTROL
                                        -- JIBARRA 17-ABR-2017   SALE A PROD [27-NOV-2017]
                                        IF (V_NUMERO_PEDIDO IS NULL)
                                        THEN
                                            V_NUMERO_PEDIDO :=
                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE1;
                                        --MSJOUT('### V6.1:: IDENTIFICAMOS EL NUMERO DE PEDIDO:: ' || REG_LIN.INTERFACE_LINE_ATTRIBUTE1);
                                        ELSE
                                            IF (V_NUMERO_PEDIDO !=
                                                REG_LIN.INTERFACE_LINE_ATTRIBUTE1)
                                            THEN
                                                IF (V_VALIDA_REFERENCE_LINE_ID =
                                                    'Y')
                                                THEN
                                                    --MSJOUT('### V6.2.1:: SE ACTUALIZAN LOS REFERENCE_LINE_ID DE TODO EL PEDIDO A NULL ');
                                                    --MSJOUT('### V6.2.1:: V_NUMERO_PEDIDO != REG_LIN.INTERFACE_LINE_ATTRIBUTE1 [' || V_NUMERO_PEDIDO || '!=' || REG_LIN.INTERFACE_LINE_ATTRIBUTE1 || ']');

                                                    UPDATE RA_INTERFACE_LINES_ALL
                                                       SET REFERENCE_LINE_ID =
                                                               NULL
                                                     WHERE     1 = 1
                                                           AND ORG_ID =
                                                               FND_PROFILE.VALUE (
                                                                   'ORG_ID')
                                                           AND BATCH_SOURCE_NAME =
                                                               NVL (
                                                                   P_BATCH_SOURCE_NAME,
                                                                   BATCH_SOURCE_NAME)
                                                           AND INTERFACE_LINE_ATTRIBUTE1 =
                                                               V_NUMERO_PEDIDO
                                                           AND INTERFACE_LINE_CONTEXT =
                                                               'ORDER ENTRY';

                                                    V_VALIDA_REFERENCE_LINE_ID :=
                                                        NULL;
                                                    V_NUMERO_PEDIDO :=
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE1;
                                                ELSE
                                                    --MSJOUT('### V6.2.2:: SE ACTUALIZAN EL NUEVO NUMERO DE PEDIDO:: ' || REG_LIN.INTERFACE_LINE_ATTRIBUTE1);
                                                    V_NUMERO_PEDIDO :=
                                                        REG_LIN.INTERFACE_LINE_ATTRIBUTE1;
                                                END IF;
                                            END IF;
                                        END IF;

                                        --MSJOUT('### V7 l_reference_line_id:: ' || l_purchase_order || ' - ' || r_l.org_id || ' - ' || r_l.inventory_item_id
                                        --           || ' - ITEM - ' || r_l.purchase_order || ' - ' || r_l.sales_order_line);

                                        l_reference_line_id :=
                                            xxgepp_ar_cm_pkg.get_trx_line_id (
                                                l_purchase_order, --pedido de venta IGC 20-JUL-2016
                                                r_l.org_id,
                                                r_l.inventory_item_id,
                                                'ITEM',
                                                r_l.purchase_order, -- orden_compra IGC 20-JUL-2016
                                                r_l.sales_order_line -- l¿nea del pedido IGC 20-JUL-2016
                                                                    );

                                        --NOV2025
                                        L_REFERENCE_LINE_ID_IEPS :=
                                            xxgepp_ar_cm_pkg.get_trx_line_id (
                                                l_purchase_order, --pedido de venta IGC 20-JUL-2016
                                                r_l.org_id,
                                                r_l.inventory_item_id,
                                                'IEPS_ED',
                                                r_l.purchase_order, -- orden_compra IGC 20-JUL-2016
                                                reg_lin.sales_order_line -- l¿nea del pedido IGC 20-JUL-2016
                                                                        );


                                        reg_lin.REFERENCE_LINE_ID :=
                                            L_REFERENCE_LINE_ID_IEPS;

                                        --MSJOUT('### V7.1 l_reference_line_id:: ' || l_reference_line_id || ' - ' || L_REFERENCE_LINE_ID_IEPS);
                                        l (
                                               '*-E-l_reference_line_id*'
                                            || l_reference_line_id);
                                        l (
                                               '*-E-L_REFERENCE_LINE_ID_IEPS*'
                                            || L_REFERENCE_LINE_ID_IEPS);
                                        l_cust_trx_id :=
                                            xxgepp_ar_cm_pkg.get_cust_trx_id (
                                                l_purchase_order,
                                                r_l.org_id,
                                                l_reference_line_id);

                                        --MSJOUT('### V8 l_cust_trx_id:: ' || l_cust_trx_id);

                                        l_cust_trx_type_id :=
                                            xxgepp_ar_cm_pkg.get_trx_type_id (
                                                l_cust_trx_id);

                                        --MSJOUT('### V9 l_cust_trx_type_id:: ' || l_cust_trx_type_id);

                                        l_interco := 'Y';
                                        l (
                                               l_interco
                                            || '-'
                                            || l_cust_trx_id
                                            || '-'
                                            || l_cust_trx_type_id);
                                    END IF;

                                    l ('*-F-*');
                                END IF;

                                l ('*-G-*');
                                l (
                                       '     actualizando linea y monto orig. orig:'
                                    || TO_CHAR (r_l.amount)
                                    || ' cambio:'
                                    || TO_CHAR (v_monto_upd));

                                --MSJOUT('### V10 actualizando linea y monto orig. orig: '  || TO_CHAR (r_l.amount) || ' cambio:' || TO_CHAR (v_monto_upd));

                                /* SE COLOCA UN IF PARA VALIDAR LOS CASOS DE REFACTURA DONDE SE PUEDA PRESENTAR DOCUMENTOS CON IEPS E IMPUESTO
                                * DIFERENTE DE 0. SI NO SE CUMPLE SE APLICA EL MISMO UPDATE QUE HASTA EL MOMENTO SE ESTABA REALIZANDO
                                * JIBARRA 14-MAR-2017
                                */

                                IF (    V_MONTO_TMP IS NOT NULL
                                    AND R_L.INTERFACE_LINE_CONTEXT =
                                        'FACTURA NAGRUP'
                                    AND V_IND_REFACTURA = '-RE')
                                THEN
                                    UPDATE ra_interface_lines_all
                                       --- solo actualiza la linea origen
                                       SET line_type = 'LINE',
                                           reference_line_id =
                                               l_reference_line_id,
                                           cust_trx_type_id =
                                               DECODE (
                                                   l_interco,
                                                   'Y', DECODE (
                                                            v_type,
                                                            'CM', NVL (
                                                                      l_cust_trx_type_id,
                                                                      cust_trx_type_id),
                                                            l_cust_trx_type_id),
                                                   cust_trx_type_id),
                                           orig_system_ship_customer_id =
                                               DECODE (
                                                   NVL (
                                                       r_l.orig_system_ship_customer_id,
                                                       0),
                                                   0, l_ship_to_customer_id,
                                                   orig_system_ship_customer_id),
                                           orig_system_ship_address_id =
                                               DECODE (
                                                   NVL (
                                                       r_l.orig_system_ship_address_id,
                                                       0),
                                                   0, l_ship_to_site_id,
                                                   orig_system_ship_address_id)
                                     --AMOUNT = decode ( v_type, 'CM', amount, TRUNC(TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)*v_quantity,2)), /* solicitud de funcional */
                                     --UNIT_SELLING_PRICE  = decode ( v_type, 'CM', unit_selling_price, TRUNC(unit_selling_price - ( v_monto/v_quantity ),2)), --agregado por PAAD (14012014)
                                     --UNIT_STANDARD_PRICE  = decode ( v_type, 'CM',UNIT_STANDARD_PRICE,TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)) --agregado por PAAD (14012014)
                                     --**amount = v_monto_upd,
                                     --decode(v_tasa,0, amount-v_monto, trunc(v_quantity*v_unit_selling ,2)  ),   ---decode ( v_type, 'CM', amount, TRUNC(TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)*v_quantity,2)), /* solicitud de funcional */
                                     --**unit_selling_price = v_unit_selling,
                                     --decode(v_tasa,0, v_unit_selling /*UNIT_SELLING_PRICE*/,    v_unit_selling  ), --agregado por PAAD (14012014)
                                     --**unit_standard_price = v_unit_standard
                                     --decode(v_tasa,0,v_unit_standard /*UNIT_STANDARD_PRICE*/, v_unit_standard ) --agregado por PAAD (14012014)
                                     WHERE CURRENT OF c_lineas;
                                ELSE
                                    --MSJOUT('### V11 ELSE  R_L.INTERFACE_LINE_CONTEXT:: ' || R_L.INTERFACE_LINE_CONTEXT  || ' V_TYPE:: ' || V_TYPE
                                    --            || ' L_CATEGORY_CODE:: ' || L_CATEGORY_CODE || ' L_REFERENCE_LINE_ID:: ' || L_REFERENCE_LINE_ID);
                                    -- AL ENTRAR AQUI VALIDA NUEVAMENTE LOS PARAMETROS PARA ENTONCES CONTROLAR SI DEJO UN REFERENCE_LINE_ID NULO
                                    -- JIBARRA 17-ABR-2017   SALE A PROD [27-NOV-2017]
                                    IF (    R_L.INTERFACE_LINE_CONTEXT =
                                            'ORDER ENTRY'
                                        AND V_TYPE = 'CM'
                                        AND L_CATEGORY_CODE = 'ORDER'
                                        AND (   L_REFERENCE_LINE_ID IS NULL
                                             OR L_REFERENCE_LINE_ID_IEPS
                                                    IS NULL))
                                    THEN
                                        V_VALIDA_REFERENCE_LINE_ID := 'Y';
                                    END IF;

                                    --MSJOUT('### V11.1 ELSE - UPDATE ::' || l_reference_line_id || ' - ' || REG_LIN.reference_line_id);

                                    UPDATE ra_interface_lines_all
                                       --- solo actualiza la linea origen
                                       SET line_type = 'LINE',
                                           reference_line_id =
                                               l_reference_line_id,
                                           cust_trx_type_id =
                                               DECODE (
                                                   l_interco,
                                                   'Y', DECODE (
                                                            v_type,
                                                            'CM', NVL (
                                                                      l_cust_trx_type_id,
                                                                      cust_trx_type_id),
                                                            l_cust_trx_type_id),
                                                   cust_trx_type_id),
                                           orig_system_ship_customer_id =
                                               DECODE (
                                                   NVL (
                                                       r_l.orig_system_ship_customer_id,
                                                       0),
                                                   0, l_ship_to_customer_id,
                                                   orig_system_ship_customer_id),
                                           orig_system_ship_address_id =
                                               DECODE (
                                                   NVL (
                                                       r_l.orig_system_ship_address_id,
                                                       0),
                                                   0, l_ship_to_site_id,
                                                   orig_system_ship_address_id),
                                           --AMOUNT = decode ( v_type, 'CM', amount, TRUNC(TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)*v_quantity,2)), /* solicitud de funcional */
                                           --UNIT_SELLING_PRICE  = decode ( v_type, 'CM', unit_selling_price, TRUNC(unit_selling_price - ( v_monto/v_quantity ),2)), --agregado por PAAD (14012014)
                                           --UNIT_STANDARD_PRICE  = decode ( v_type, 'CM',UNIT_STANDARD_PRICE,TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)) --agregado por PAAD (14012014)
                                           amount = v_monto_upd,
                                           --decode(v_tasa,0, amount-v_monto, trunc(v_quantity*v_unit_selling ,2)  ),   ---decode ( v_type, 'CM', amount, TRUNC(TRUNC(UNIT_STANDARD_PRICE - ( v_monto/v_quantity ),2)*v_quantity,2)), /* solicitud de funcional */
                                           unit_selling_price =
                                               v_unit_selling,
                                           --decode(v_tasa,0, v_unit_selling /*UNIT_SELLING_PRICE*/,    v_unit_selling  ), --agregado por PAAD (14012014)
                                           unit_standard_price =
                                               v_unit_standard
                                     --decode(v_tasa,0,v_unit_standard /*UNIT_STANDARD_PRICE*/, v_unit_standard ) --agregado por PAAD (14012014)
                                     WHERE CURRENT OF c_lineas;
                                END IF;

                                v_tot_reg_act := v_tot_reg_act + 1;
                            END IF;

                            IF r_l.currency_code = 'MXN'
                            THEN
                                --NOV2025
                                l ('  Es pesos  genera IEPS ED');
                                xxgepp_ar_cm_pkg.link_trx_line_id (reg_lin);

                                BEGIN
                                    INSERT INTO RA_INTERFACE_LINES_ALL
                                         VALUES REG_LIN;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        V_ERROR := 1;

                                        MSJOUT (
                                               '## ERROR:: [ORDER ENTRY] AL INSERTAR IEPS EN RA_INTERFACE_LINES_ALL_'
                                            || SQLERRM);
                                END;

                                /* SE PALCIA UN UPDATE AL ATTRIBUTE11 DE DONDE SE TOMA EL VALOR PARA EL MONTO
                                * DEL IEPS EN LAS REFACTURAS Y QUE EN LA FACTURA ELECTRONICA SE REFLEJE CORRECTAMENTE EL MONTO
                                * JIBARRA 30-AGO-2017
                                */

                                IF (reg_lin.BATCH_SOURCE_NAME LIKE '%SIO-RE')
                                THEN
                                    MSJOUT (
                                           '***  SE ACTUALIZA EL MONTO EN ATTRIBUTE11:: '
                                        || REG_LIN.AMOUNT
                                        || ' PARA '
                                        || REG_LIN.TRX_NUMBER
                                        || '-'
                                        || REG_LIN.description);
                                    L (
                                           '***  SE ACTUALIZA EL MONTO EN ATTRIBUTE11:: '
                                        || REG_LIN.AMOUNT
                                        || ' PARA '
                                        || REG_LIN.TRX_NUMBER
                                        || '-'
                                        || REG_LIN.description);

                                    UPDATE ra_interface_lines_all
                                       SET ATTRIBUTE11 = REG_LIN.AMOUNT
                                     WHERE CURRENT OF c_lineas;
                                END IF;

                                /* SE COLOCA LA SECCION PARA QUE SE COLOCADA LA DISTRIBUCION DE LAS
                                * LINEAS DE IEPS EN LA TABLA DE DISTRIBUCIONES DE LA INTERFACE
                                * JIBARRA 06-MAR-2017
                                */
                                IF (    V_ERROR = 0
                                    AND r_l.interface_line_context !=
                                        'FACTURA NAGRUP')
                                THEN
                                    BEGIN
                                        MSJOUT (
                                               '## SE GENERA DISTRIBUCION PARA LINEA DE IEPS DE UNA FACTURA ['
                                            || r_l.interface_line_context
                                            || '] ORIGEN:: '
                                            || r_l.batch_source_name);

                                        --NOV2025
                                        SELECT CC.SEGMENT1,
                                               CC.SEGMENT2,
                                               CC.SEGMENT3,
                                               CC.SEGMENT4,
                                               CC.SEGMENT5,
                                               CC.SEGMENT6,
                                               CC.SEGMENT7,
                                               CC.CODE_COMBINATION_ID
                                          INTO V_CC_SEGMENT1,
                                               V_CC_SEGMENT2,
                                               V_CC_SEGMENT3,
                                               V_CC_SEGMENT4,
                                               V_CC_SEGMENT5,
                                               V_CC_SEGMENT6,
                                               V_CC_SEGMENT7,
                                               V_CODE_COMBINATION_ID
                                          FROM ZX_STATUS_B                ZS,
                                               ZX_TAXES_B                 ZT,
                                               ZX_RATES_B                 ZR,
                                               ZX_ACCOUNTS                ZA,
                                               GL_CODE_COMBINATIONS       CC,
                                               HR_ALL_ORGANIZATION_UNITS  OU
                                         WHERE     1 = 1
                                               AND ZS.EFFECTIVE_TO IS NULL
                                               AND ZS.TAX_REGIME_CODE =
                                                   ZT.TAX_REGIME_CODE
                                               AND ZS.TAX = ZT.TAX
                                               AND ZS.CONTENT_OWNER_ID =
                                                   ZT.CONTENT_OWNER_ID
                                               AND ZS.TAX_STATUS_CODE =
                                                   ZR.TAX_STATUS_CODE
                                               AND ZS.TAX_REGIME_CODE =
                                                   ZR.TAX_REGIME_CODE
                                               AND ZS.TAX = ZR.TAX
                                               AND ZS.CONTENT_OWNER_ID =
                                                   ZR.CONTENT_OWNER_ID
                                               AND ZR.ACTIVE_FLAG = 'Y'
                                               AND ZR.TAX_RATE_ID =
                                                   ZA.TAX_ACCOUNT_ENTITY_ID
                                               AND ZA.TAX_ACCOUNT_CCID =
                                                   CC.CODE_COMBINATION_ID
                                               AND ZA.INTERNAL_ORGANIZATION_ID =
                                                   OU.ORGANIZATION_ID
                                               AND TAX_RATE_CODE =
                                                   'IEPS LT ED'
                                               AND ZA.INTERNAL_ORGANIZATION_ID =
                                                   REG_LIN.ORG_ID;

                                        INSERT INTO RA_INTERFACE_DISTRIBUTIONS_ALL (
                                                        INTERFACE_LINE_CONTEXT,
                                                        INTERFACE_LINE_ATTRIBUTE1,
                                                        INTERFACE_LINE_ATTRIBUTE2,
                                                        INTERFACE_LINE_ATTRIBUTE3,
                                                        INTERFACE_LINE_ATTRIBUTE4,
                                                        INTERFACE_LINE_ATTRIBUTE5,
                                                        INTERFACE_LINE_ATTRIBUTE6,
                                                        INTERFACE_LINE_ATTRIBUTE7,
                                                        INTERFACE_LINE_ATTRIBUTE8,
                                                        INTERFACE_LINE_ATTRIBUTE9,
                                                        INTERFACE_LINE_ATTRIBUTE10,
                                                        INTERFACE_LINE_ATTRIBUTE11,
                                                        INTERFACE_LINE_ATTRIBUTE12,
                                                        INTERFACE_LINE_ATTRIBUTE13,
                                                        INTERFACE_LINE_ATTRIBUTE14,
                                                        INTERFACE_LINE_ATTRIBUTE15,
                                                        ACCOUNT_CLASS,
                                                        AMOUNT,
                                                        PERCENT,
                                                        CODE_COMBINATION_ID,
                                                        SEGMENT1,
                                                        SEGMENT2,
                                                        SEGMENT3,
                                                        SEGMENT4,
                                                        SEGMENT5,
                                                        SEGMENT6,
                                                        SEGMENT7,
                                                        ORG_ID,
                                                        CREATION_DATE,
                                                        SEGMENT25)
                                                 VALUES (
                                                            REG_LIN.INTERFACE_LINE_CONTEXT,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE1,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE2,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE3,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE4,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE5,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE6,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE7,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE8,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE9,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE10,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE11,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE12,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE13,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE14,
                                                            REG_LIN.INTERFACE_LINE_ATTRIBUTE15,
                                                            'REV',
                                                            REG_LIN.AMOUNT,
                                                            '100',
                                                            V_CODE_COMBINATION_ID,
                                                            V_CC_SEGMENT1,
                                                            V_CC_SEGMENT2,
                                                            V_CC_SEGMENT3,
                                                            V_CC_SEGMENT4,
                                                            V_CC_SEGMENT5,
                                                            V_CC_SEGMENT6,
                                                            V_CC_SEGMENT7,
                                                            REG_LIN.ORG_ID,
                                                            REG_LIN.CREATION_DATE,
                                                            REG_LIN.TRX_NUMBER);
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            V_ERROR := 1;

                                            MSJOUT (
                                                   '## ERROR:: [ORDER ENTRY] AL INSERTAR DISTRIBUCION DE IEPS EN RA_INTERFACE_DISTRIBUTIONS_ALL'
                                                || SQLERRM);
                                    END;
                                END IF;

                                l ('    Inserta order entry');
                                v_tot_reg_ins := v_tot_reg_ins + 1;
                            END IF;
                        END IF;
                    END IF; -- NOV2025 IF vo_ieps_litro_ed <> 0 AND vo_chk_ieps_litro_ed = 1
                END IF;
            END IF;                                     --- if linea descuento

            ----
            ----
            -- Se inserta la funci¿n para determinar la cuenta contable.
            -- CEDC
            --            l ('Proceso de derivacion contable');
            DECLARE
                v_SetAccount   NUMBER := 0;
                v_err_msj      VARCHAR2 (4000);
                v_err_num      NUMBER;
            BEGIN
                EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''AMERICAN'' ';

                SELECT COUNT (vl.lookup_code)
                  INTO v_SetAccount
                  FROM fnd_lookup_values_vl vl
                 WHERE     lookup_type = 'XXAR_TP_NC_INTERCOMPANY'
                       AND vl.enabled_flag = 'Y'
                       AND vl.tag NOT IN ('NCMAN', 'REFVENTAMAN')
                       AND vl.lookup_code = r_l.interface_line_attribute2
                       AND SYSDATE BETWEEN start_date_active
                                       AND NVL (end_date_active, SYSDATE + 1);

                --                SELECT COUNT(cty.CUST_TRX_TYPE_ID)
                --                INTO v_SetAccount
                --                FROM ra_cust_trx_types_all cty
                --                WHERE 1=1
                --                AND NAME IN
                --                (
                --                    SELECT  b.FLEX_VALUE
                --                    FROM    APPS.fND_FLEX_VALUE_SETS a,
                --                            APPs.FND_FLEX_VALUEs b,
                --                            APPS.FND_FLEX_VALUES_TL c
                --                    WHERE     FLEX_VALUE_SET_NAME LIKE 'XXAR_TT_NC_INTERCOMPANY'
                --                    AND a.FLEX_VALUE_SET_ID = b.FLEX_VALUE_SET_ID
                --                    AND c.FLEX_VALUE_ID = b.FLEX_VALUE_ID
                --                    AND b.ENABLED_FLAG = 'Y'
                --                    AND SYSDATE BETWEEN NVL (b.START_DATE_ACTIVE, SYSDATE) AND NVL (b.END_DATE_ACTIVE, SYSDATE)
                --                    AND c.LANGUAGE = USERENV('LANG')
                --                )
                --                AND CUST_TRX_TYPE_ID = r_l.cust_trx_type_id;

                IF v_SetAccount > 0 AND r_l.amount != 0
                THEN
                    l ('Proceso de derivacion contable call before');
                    APPS.CUST_SLA_AR_SOURCE_PKG.cust_sla_set_cta (r_l,
                                                                  NULL,
                                                                  v_err_msj,
                                                                  v_err_num);



                    DECLARE
                        v_usoCfdiInterco   VARCHAR2 (100);
                        v_trx_type         VARCHAR2 (100);
                    BEGIN
                        SELECT TYPE
                          INTO v_trx_type
                          FROM AR.RA_CUST_TRX_TYPES_ALL
                         WHERE     1 = 1
                               AND cust_trx_type_id = r_l.CUST_TRX_TYPE_ID;

                        IF v_trx_type = 'INV'
                        THEN                              -- Solo facturas INV
                            CUST_SLA_AR_SOURCE_PKG.cust_get_uso_cfdi_icia (
                                r_l,
                                v_err_msj,
                                v_err_num,
                                v_usoCfdiInterco);

                            IF v_err_num != 0
                            THEN
                                l (
                                       'v_err_num:'
                                    || v_err_num
                                    || ' -> '
                                    || v_err_msj);
                            ELSE
                                l (
                                       'v_err_num:'
                                    || v_err_num
                                    || ' -> '
                                    || v_err_msj);

                                --l('v_usoCfdiInterco:'||v_usoCfdiInterco);
                                UPDATE ra_interface_lines_all
                                   SET HEADER_ATTRIBUTE14 = v_usoCfdiInterco
                                 WHERE CURRENT OF c_lineas;
                            END IF;
                        END IF;
                    END;

                    l ('Proceso de derivacion contable call after');
                END IF;
            END;
        END LOOP;

        -- SI SOLO HUBO UN NUMERO DE PEDIDO O EL ULTIMO DEL CICLO TIENE UN REFERENCE_LINE_ID AQUI SE ACTUALIZA
        -- JIBARRA 17-ABR-2017    SALE A PROD [27-NOV-2017]
        IF (V_VALIDA_REFERENCE_LINE_ID = 'Y')
        THEN
            --MSJOUT('### VX0:: SE ACTUALIZAN LOS REFERENCE_LINE_ID DE TODO EL PEDIDO A NULL _ V_NUMERO_PEDIDO::' || V_NUMERO_PEDIDO);

            UPDATE RA_INTERFACE_LINES_ALL
               SET REFERENCE_LINE_ID = NULL
             WHERE     1 = 1
                   AND ORG_ID = FND_PROFILE.VALUE ('ORG_ID')
                   AND BATCH_SOURCE_NAME =
                       NVL (P_BATCH_SOURCE_NAME, BATCH_SOURCE_NAME)
                   AND INTERFACE_LINE_ATTRIBUTE1 = V_NUMERO_PEDIDO
                   AND INTERFACE_LINE_CONTEXT = 'ORDER ENTRY';

            V_VALIDA_REFERENCE_LINE_ID := NULL;
            V_NUMERO_PEDIDO := NULL;
        --        ELSE
        --            MSJOUT('### V9.2.2:: SE ACTUALIZAN EL NUEVP NUMERO DE PEDIDO ');
        --            V_NUMERO_PEDIDO := REG_LIN.INTERFACE_LINE_ATTRIBUTE1;
        END IF;

        ----
        IF v_error = 0
        THEN
            COMMIT;
            l ('     ');
            l ('     ');
            l (
                '**************************************************************************');
            l ('     ');
            l (
                   '   Total de registros actualizados:  '
                || TO_CHAR (v_tot_reg_act));
            l (
                   '   Total de registros insertados  :  '
                || TO_CHAR (v_tot_reg_ins));
            l ('     ');
            l (
                '**************************************************************************');
        ELSE
            ROLLBACK;
            l ('     ');
            l ('     ');
            l (
                '**************************************************************************');
            l ('     ');
            l ('   ERROR: No existe el tipo de cambio para Corporate');
            l ('     ');
            l (
                '**************************************************************************');
            errbuf := '0000- ERROR de programa';
            retcode := 2;
        END IF;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX
        THEN
            l (
                   ' ERROR Inesperado dup_val_on_index,Error Code ='
                || SQLCODE
                || ' Error message ='
                || SQLERRM);
            retcode := 2;
        ----
        WHEN error_fatal
        THEN
            l ('     ');
            l ('     ');
            l (
                '**************************************************************************');
            l ('     ');
            l ('   ERROR: Fatal ');
            l ('     ');
            l (
                '**************************************************************************');
            errbuf := '0000- ERROR de programa';
            retcode := 2;
        ---
        WHEN OTHERS
        THEN
            l ('ERROR Inesperado al procesar lineas de IEPS');
            l ('Error Code =' || SQLCODE || ' Error message =' || SQLERRM);
            retcode := 2;
    END;

    --------
    PROCEDURE pa_ar_mod_dcon_cust (errbuf       OUT NOCOPY VARCHAR2,
                                   retcode      OUT NOCOPY NUMBER)
    IS
        CURSOR c_req IS
            SELECT request_id
              FROM fnd_concurrent_requests
             WHERE     priority_request_id =
                       (SELECT DISTINCT priority_request_id
                          FROM fnd_concurrent_requests
                         WHERE request_id = fnd_global.conc_request_id)
                   AND program_application_id = 222;

        v_err   NUMBER := 0;
    BEGIN
        l (fnd_global.conc_request_id);

        FOR l_req IN c_req
        LOOP
            l ('--Procesando req:' || TO_CHAR (l_req.request_id));
            l ('  - distribucion.');
            v_err := pa_ar_cambia_distcont (l_req.request_id);
            l ('  - links.');
            pa_ar_act_link_lin_ieps (l_req.request_id);
        END LOOP;

        COMMIT;

        IF v_err <> 0
        THEN
            errbuf := '0000- ERROR de programa en el cambio de distribucion';
            retcode := v_err;
        END IF;
    END pa_ar_mod_dcon_cust;

    --------
    PROCEDURE pa_ar_act_link_lin_ieps (p_req_id IN NUMBER)
    IS
        CURSOR c_lieps IS
            SELECT customer_trx_id,
                   customer_trx_line_id,
                   line_type,
                   request_id,
                   description,
                   sales_order,
                   SUBSTR (sales_order_line,
                           1,
                           INSTR (sales_order_line, '.') - 1)
                       sales_order_l,
                   inventory_item_id,
                   SUBSTR (sales_order_line,
                           INSTR (sales_order_line, '.') + 1)
                       id_seq
              FROM ra_customer_trx_lines_all
             WHERE     request_id = p_req_id
                   AND line_type = 'LINE'
                   AND SUBSTR (description, 1, 7) = 'IEPS_LT';
    BEGIN
        FOR r_l IN c_lieps
        LOOP
            UPDATE ra_customer_trx_lines_all_cust
               SET attribute2 = r_l.id_seq
             WHERE customer_trx_line_id =
                   (SELECT customer_trx_line_id
                      FROM ra_customer_trx_lines_all
                     WHERE     sales_order = r_l.sales_order
                           AND sales_order_line = r_l.sales_order_l
                           AND inventory_item_id = r_l.inventory_item_id
                           AND unit_standard_price > 0
                           AND ROWNUM = 1);
        END LOOP;

        l ('  -- Termino act link lineas.');
    END;

    FUNCTION pa_ar_cambia_distcont (p_req_id IN NUMBER)
        RETURN NUMBER
    IS
        v_cc_id            NUMBER;
        v_cc_seg5          VARCHAR2 (30);
        v_cc_seg6          VARCHAR2 (30);
        v_err              NUMBER := 0;
        v_err_fin          NUMBER := 0;

        CURSOR c_lieps IS
            SELECT l.customer_trx_id,
                   l.customer_trx_line_id,
                   ld.cust_trx_line_gl_dist_id,
                   cc.segment1,
                   cc.segment2,
                   cc.segment3,
                   cc.segment4,
                   cc.segment5,
                   cc.segment6,
                   cc.segment7,
                   ld.org_id
              FROM ra_customer_trx_lines_all       l,
                   ra_cust_trx_line_gl_dist_all    ld,
                   gl_code_combinations            cc,
                   ra_customer_trx_lines_all_cust  lc
             WHERE     l.request_id = p_req_id
                   AND l.line_type = 'LINE'
                   AND l.customer_trx_line_id = ld.customer_trx_line_id
                   AND ld.code_combination_id = cc.code_combination_id
                   AND l.customer_trx_line_id = lc.customer_trx_line_id
                   AND lc.attribute1 = 'IEPS_LT';

        v_modif_distcont   BOOLEAN := FALSE;
    BEGIN
        FOR r_l IN c_lieps
        LOOP
            v_cc_id := NULL;
            v_err := 0;
            v_modif_distcont :=
                cambiar_dist_cont (r_l.org_id, r_l.customer_trx_id);

            IF v_modif_distcont
            THEN
                BEGIN
                    --   select cc.segment5,cc.segment6  into v_cc_seg5,v_cc_seg6    ---- modificacion 2014ene31, se cambia la cta contable completa
                    SELECT cc.code_combination_id
                      INTO v_cc_id
                      FROM zx_status_b                zs,
                           zx_taxes_b                 zt,
                           zx_rates_b                 zr,
                           zx_accounts                za,
                           gl_code_combinations       cc,
                           hr_all_organization_units  ou
                     WHERE     1 = 1
                           AND zs.effective_to IS NULL
                           AND zs.tax_regime_code = zt.tax_regime_code
                           AND zs.tax = zt.tax
                           AND zs.content_owner_id = zt.content_owner_id
                           AND zs.tax_status_code = zr.tax_status_code
                           AND zs.tax_regime_code = zr.tax_regime_code
                           AND zs.tax = zr.tax
                           AND zs.content_owner_id = zr.content_owner_id
                           AND zr.active_flag = 'Y'
                           AND zr.tax_rate_id = za.tax_account_entity_id
                           AND za.tax_account_ccid = cc.code_combination_id
                           AND za.internal_organization_id =
                               ou.organization_id
                           AND tax_rate_code = 'IEPS LT'
                           AND za.internal_organization_id = r_l.org_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l (
                               'Error: Cta no encontrada en impuestos  IEPS_LT:'
                            || TO_CHAR (r_l.org_id)
                            || ' id distrib:'
                            || TO_CHAR (r_l.cust_trx_line_gl_dist_id)
                            || ', Cta no cambiada');
                        v_err := 1;
                        v_err_fin := 1;
                    WHEN TOO_MANY_ROWS
                    THEN
                        l (
                               'Error: Cta con muchos regs  IEPS_LT:'
                            || TO_CHAR (r_l.org_id)
                            || ' id distrib:'
                            || TO_CHAR (r_l.cust_trx_line_gl_dist_id)
                            || ', Cta no cambiada');
                        v_err := 1;
                        v_err_fin := 1;
                END;

                /*  if v_err = 0 then     ---- modificacion 2014ene31, se cambia la cta contable completa
                    begin
                       select code_combination_id into v_cc_id
                       from  gl_code_combinations cc
                       where segment1 = r_l.segment1 and
                       segment2 = r_l.segment2 and
                       segment3 = r_l.segment3 and
                       segment4 = r_l.segment4 and
                       segment5 = v_cc_seg5 and
                       segment6 = v_cc_seg6 and
                       segment7 = r_l.segment7;*/
                IF v_err = 0
                THEN
                    UPDATE ra_cust_trx_line_gl_dist_all
                       SET code_combination_id = v_cc_id
                     WHERE cust_trx_line_gl_dist_id =
                           r_l.cust_trx_line_gl_dist_id;

                    l (
                           '   update.'
                        || TO_CHAR (SQL%ROWCOUNT)
                        || ' * '
                        || TO_CHAR (r_l.cust_trx_line_gl_dist_id)
                        || ' cta. orig:'
                        || r_l.segment1
                        || '.'
                        || r_l.segment2
                        || '.'
                        || r_l.segment3
                        || '.'
                        || r_l.segment4
                        || '.'
                        || r_l.segment5
                        || '.'
                        || r_l.segment6
                        || '.'
                        || r_l.segment7
                        || ' cta. nva:'
                        || r_l.segment1
                        || '.'
                        || r_l.segment2
                        || '.'
                        || r_l.segment3
                        || '.'
                        || r_l.segment4
                        || '.'
                        || v_cc_seg5
                        || '.'
                        || v_cc_seg6
                        || '.'
                        || r_l.segment7);
                /*  exception when no_data_found then
                   l('  Error: NO se encontro cuenta contable para lin.id.:'||to_char(r_l.customer_trx_line_id)    );
                   v_err_fin   := 1;
                  when too_many_rows then
                   l('  Error: MULTIPLES cuentas contables para lin.id.:'||to_char(r_l.customer_trx_line_id)    );
                   v_err_fin  := 1;
                 END;*/
                END IF;
            END IF;
        END LOOP;

        RETURN v_err_fin;
    END;

    --------
    FUNCTION pa_obten_impuestos (p_cod_imp IN VARCHAR2)
        RETURN NUMBER
    IS
        i_tab                  NUMBER;
        i                      NUMBER;
        v_porcentaje           NUMBER;
        v_inclusive_tax_flag   VARCHAR2 (14);
        v_compuesto            NUMBER;

        ----
        CURSOR c_tax (p_codigo IN VARCHAR)
        IS
            SELECT ROWNUM,
                   pr.tax_status_code,
                   pr.result_type_code,
                   cg.alphanumeric_value1,
                   alphanumeric_result,
                   DECODE (NVL (pr.tax_status_code, '*'),
                           alphanumeric_result, 'TAX',
                           '*', 'N/A',
                           'BSE')    tipo
              FROM zx.zx_process_results     pr,
                   zx.zx_rules_b             ru,
                   zx.zx_condition_groups_b  cg
             WHERE     cg.alphanumeric_value1 = p_codigo --'IEPS INC 25% INC 11%'  --    'IVA 11%' --
                   AND ru.det_factor_templ_code = cg.condition_group_code --- 'IEPS 25% INC 11%'
                   AND pr.condition_group_code = ru.det_factor_templ_code --'IEPS 25% IVA 16%'
                   AND pr.tax_rule_id = ru.tax_rule_id
                   AND ru.enabled_flag = 'Y';
    BEGIN
        t_cve_tax :=
            datos_tax ('',
                       '',
                       '',
                       '',
                       '',
                       '',
                       '',
                       '',
                       '',
                       '');
        t_por_tax :=
            datos_tax ('',
                       '',
                       '',
                       '',
                       '',
                       '',
                       '',
                       '',
                       '',
                       '');
        t_tipo_tax :=
            datos_tax ('',
                       '',
                       '',
                       '',
                       '',
                       '',
                       '',
                       '',
                       '',
                       '');
        i_tab := 0;
        v_compuesto := 0;
        l ('       []cod.impuesto|' || p_cod_imp || '|');

        FOR r_t IN c_tax (p_cod_imp)
        LOOP
            IF r_t.result_type_code = 'FORMULA'
            THEN
                v_compuesto := 1;
            END IF;

            IF r_t.tipo <> 'N/A'
            THEN
                i_tab := i_tab + 1;
                t_cve_tax (i_tab) := r_t.tax_status_code;
                t_tipo_tax (i_tab) := r_t.tipo;
                l (
                       '       [] stat.cod:'
                    || r_t.tax_status_code
                    || '*tipo:'
                    || r_t.tipo
                    || '*'
                    || TO_CHAR (i_tab)
                    || '*');                        --to_char(r_t.tipo)     );
            END IF;
        END LOOP;

        --
        i := 1;

        FOR i IN 1 .. i_tab
        LOOP
            BEGIN
                IF t_tipo_tax (i) = 'BSE'
                THEN                                                  --1 then
                    SELECT percentage_rate,
                           DECODE (inclusive_tax_flag,
                                   'Y', 'INCLUSIVE',
                                   'NOINCLUSI')
                      INTO v_porcentaje, v_inclusive_tax_flag
                      FROM zx.zx_rates_b
                     WHERE     tax_status_code = t_cve_tax (i)
                           AND tax_rate_code = p_cod_imp
                           AND ROWNUM = 1;
                ELSE
                    SELECT percentage_rate,
                           DECODE (inclusive_tax_flag,
                                   'Y', 'INCLUSIVE',
                                   'NOINCLUSI')
                      INTO v_porcentaje, v_inclusive_tax_flag
                      FROM zx.zx_rates_b
                     WHERE tax_status_code = t_cve_tax (i);
                END IF;
            ------
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l (
                           'error no existio:'
                        || t_cve_tax (i)
                        || '.v_compuesto:'
                        || TO_CHAR (v_compuesto));
                    v_porcentaje := 0;
                    v_inclusive_tax_flag := 'NOINCLUSI';
                WHEN TOO_MANY_ROWS
                THEN
                    l (
                           'error muchos registros:'
                        || t_cve_tax (i)
                        || '.v_compuesto:'
                        || TO_CHAR (v_compuesto));
                    v_porcentaje := 0;
                    v_inclusive_tax_flag := 'NOINCLUSI';
            END;

            t_por_tax (i) := v_porcentaje;
            t_tipo_tax (i) := t_tipo_tax (i) || '.' || v_inclusive_tax_flag;
            l (
                   '       [>]t_cve_tax.('
                || i
                || ') = '
                || t_cve_tax (i)
                || '*  porc_tax:'
                || t_por_tax (i)
                || '*  tipo_tax:'
                || t_tipo_tax (i));
        END LOOP;

        IF v_compuesto = 0
        THEN
            l ('       [>]tipo de impuesto: NORMAL');
        ELSE
            l ('       [>]tipo de impuesto: COMPUESTO');
        END IF;

        RETURN v_compuesto;
    ----
    END;

    FUNCTION cambiar_dist_cont (p_in_org_id            IN NUMBER,
                                p_in_customer_trx_id   IN NUMBER)
        RETURN BOOLEAN
    IS
        v_trx_type_name   ra_cust_trx_types_all.NAME%TYPE;
        v_tt_name         ra_cust_trx_types_all.NAME%TYPE;
        v_source_name     ra_batch_sources_all.NAME%TYPE;
        v_source          VARCHAR2 (10) := '';
        v_customer_id     ra_customer_trx_all.bill_to_customer_id%TYPE;
        v_trx_number      ra_customer_trx_all.trx_number%TYPE;
        v_ref             VARCHAR2 (10) := '';
        v_sour_ref        VARCHAR2 (10) := '';
        v_sio             NUMBER := 0;
        v_agrupa          NUMBER := 0;
        v_cust_agrup      BOOLEAN;
        v_refact          BOOLEAN;
        v_is_sio          BOOLEAN;
        v_agrup           BOOLEAN;
        v_modify_distr    BOOLEAN := TRUE;
    BEGIN
        SELECT rct.trx_number,
               rctt.NAME,
               rbs.NAME,
               hcas.attribute8
          INTO v_trx_number,
               v_tt_name,
               v_source_name,
               v_agrupa
          FROM ra_customer_trx_all     rct,
               ra_cust_trx_types_all   rctt,
               ra_batch_sources_all    rbs,
               hz_cust_accounts        hca,
               hz_cust_acct_sites_all  hcas
         WHERE     1 = 1
               AND rct.cust_trx_type_id = rctt.cust_trx_type_id
               AND rct.batch_source_id = rbs.batch_source_id
               AND hca.cust_account_id = rct.bill_to_customer_id
               AND hca.cust_account_id = hcas.cust_account_id
               AND hcas.org_id = rct.org_id
               AND rct.org_id = rbs.org_id
               AND bill_to_flag = 'P'
               AND rct.customer_trx_id = p_in_customer_trx_id
               AND rct.org_id = p_in_org_id;

        l (
               '==> '
            || v_trx_number
            || '  -  '
            || v_tt_name
            || '  -  '
            || v_source_name
            || '  -  '
            || v_agrupa
            || ' <==');
        v_ref := SUBSTR (v_tt_name, 0, 3);

        IF v_ref = 'REF'
        THEN
            BEGIN
                SELECT NAME
                  INTO v_trx_type_name
                  FROM ra_cust_trx_types_all
                 WHERE 1 = 1 AND TRIM (attribute14) = v_tt_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    v_trx_type_name := v_tt_name;
                    l ('Error consulta tipo de transacci¿n');
            END;

            l ('Trx_type:              ' || v_trx_type_name);
            v_sio := 0;
            v_source := 'NO';
            v_agrupa := 0;
        ELSE
            l ('NO es de refactura');
            v_trx_type_name := v_tt_name;
            l ('Trx_type:              ' || v_trx_type_name);
            v_sio := ar_cust_reinvoicing_pkg.es_sio (v_trx_type_name);
            v_source := SUBSTR (v_source_name, -3);
        END IF;



        --       v_cust_agrup := cust_ar_agrupador_pkg.is_customer_grouped (v_customer_id);

        IF v_source_name LIKE 'CA%FACTURA-ECP-SIO'
        THEN
            v_is_sio := FALSE;
            l (' La transacci¿n es SIO pero de cuenta puente FALSE');
        ELSIF v_sio = 1 OR v_source = 'SIO'
        THEN
            v_is_sio := TRUE;
            l (' La transacci¿n es de SIO       TRUE');
        ELSE
            v_is_sio := FALSE;
            l (' La transacci¿n NO es de SIO       FALSE');
        END IF;

        IF v_agrupa = 1
        THEN
            v_cust_agrup := TRUE;
            l (' El cliente si es de agrupaci¿n       TRUE');
        ELSE
            v_cust_agrup := FALSE;
            l (' El cliente no es de agrupaci¿n       FALSE');
        END IF;

        /* SE AGREGA LA VALIDACION CON EL ORIGEN QUE CONTENGA [NAGRUP]
        * JIBARRA 01-MAR-2017
        * SE QUITA CA%AFACTURA-GRUPA Y CA%NFACTURA-AGRUP Y SE DEJA LA VALIDACION SIN FACTURA
        * JIBARRA 08-MAR-2017 ** SE QUEDA PENDIENTE VALIDACION Y APROVACION
        */

        IF     (v_is_sio OR v_cust_agrup)
           AND (   v_source_name LIKE 'CA%AGRUPA'
                OR v_source_name LIKE 'CA%NAGRUP')
        THEN
            v_modify_distr := FALSE;
            l ('No modifica');
        ELSIF     v_is_sio
              AND (   v_source_name LIKE 'CA%FACTURA-SIO'
                   OR v_source_name LIKE 'CA%NC-SIO')
        THEN
            v_modify_distr := FALSE;
            l ('No modificar es SIO pero DAS');
        ELSE
            v_modify_distr := TRUE;
        END IF;

        RETURN v_modify_distr;
    EXCEPTION
        WHEN OTHERS
        THEN
            l ('Error en cambiar_dist_cont -  ' || SQLERRM);
            RETURN FALSE;
    END cambiar_dist_cont;


    PROCEDURE CUSTOM_TRIGG_IEPS (P_TRX_ID                     NUMBER,
                                 P_CUST_TRX_LINE_GL_DIST_ID   NUMBER,
                                 P_CC_ID                      NUMBER)
    IS
        --    PRAGMA AUTONOMOUS_TRANSACTION;
        v_existe   NUMBER := 0;
        V_ERR      VARCHAR2 (1000);
        v_cont     NUMBER;
    BEGIN
        Mo_global.init ('AR');
        v_existe := 0;
        v_cont := 0;

        WHILE (v_existe = 0 AND v_cont <= 10)
        LOOP
            DBMS_LOCK.SLEEP (1);

            BEGIN
                SELECT COUNT (1)
                  INTO v_existe
                  FROM RA_CUSTOMER_TRX_ALL
                 WHERE CUSTOMER_TRX_ID = P_TRX_ID;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_existe := 0;
            END;

            v_cont := v_cont + 1;

            INSERT INTO ra_customer_trx_ieps_log
                SELECT P_CUST_TRX_LINE_GL_DIST_ID || '-' || v_existe, SYSDATE
                  FROM DUAL;

            COMMIT;
        END LOOP;

        IF v_existe > 0
        THEN
            BEGIN
                UPDATE ar.ra_cust_trx_line_gl_dist_all
                   SET code_combination_id = P_CC_ID
                 WHERE     cust_trx_line_gl_dist_id =
                           P_CUST_TRX_LINE_GL_DIST_ID
                       AND customer_trx_id = P_TRX_ID;

                INSERT INTO ra_customer_trx_ieps_log
                    SELECT    P_CUST_TRX_LINE_GL_DIST_ID
                           || '- ACTUALIZADO -'
                           || P_CC_ID,
                           SYSDATE
                      FROM DUAL;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    V_ERR := SQLERRM;

                    INSERT INTO ra_customer_trx_ieps_log (PASO, FECHA)
                             VALUES (
                                           P_CUST_TRX_LINE_GL_DIST_ID
                                        || '- ERROR ACTUALIZACION -'
                                        || V_ERR,
                                        SYSDATE);

                    COMMIT;
            END;
        ELSE
            INSERT INTO ra_customer_trx_ieps_log
                SELECT P_CUST_TRX_LINE_GL_DIST_ID || '- NO EXISTE TRX',
                       SYSDATE
                  FROM DUAL;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            V_ERR := SQLERRM;

            INSERT INTO ra_customer_trx_ieps_log (PASO, FECHA)
                     VALUES (
                                   P_CUST_TRX_LINE_GL_DIST_ID
                                || '- ERROR GRAL -'
                                || V_ERR,
                                SYSDATE);

            COMMIT;
    END CUSTOM_TRIGG_IEPS;
END PKG_AR_IEPS_CUST;