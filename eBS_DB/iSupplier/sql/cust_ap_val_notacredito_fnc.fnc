CREATE OR REPLACE FUNCTION XXWEBC.cust_ap_val_notacredito_fnc (
    p_idregx           NUMBER,
    p_transaccion_id   NUMBER)
    RETURN CLOB
-- $Id: cust_ap_val_notacredito_fnc.fnc 4639 2024-11-08 17:21:24Z vvelasco $
-- $URL: http://mxapediprdl.gepp.pvt:18080/svn/r12/iSupplier/sql/cust_ap_val_notacredito_fnc.fnc $

-- Funcion de validacion de las reglas de notas de credito
-- NOTA: el transaccion_id corresponde a la FACTURA original para validar.
-- Origen de llamada APPS.xxgepp_cust_reglas_val_fac

IS
    v_mensaje              VARCHAR2 (1000) := NULL; -- Mensaje de error o correcto.
    v_error                NUMBER := 0;                 -- 0 no error, 1 error

    xmlRFCEmisor           VARCHAR2 (20);
    xmlTipoDeComprobante   VARCHAR2 (50);
    xmlMetodoPago          VARCHAR2 (50);
    xmlFormaPago           VARCHAR2 (50);
    xmlTipoRelacion        VARCHAR2 (50);
    xmluuidRelacionado     VARCHAR2 (50);
    xmlUsoCFDI             VARCHAR2 (50);
    xmlSubtotal            VARCHAR2 (50);

    v_unidad_xml           NUMBER;
    v_unidad_validos       NUMBER;
    v_clave_xml            NUMBER;
    v_clave_validos        NUMBER;
    v_ap_monto_original    NUMBER;
    v_tolerancia           NUMBER;
    v_factor_tolerancia    NUMBER;

    v_formapago            VARCHAR2 (50);
    v_tipodecomprobante    VARCHAR2 (50);
    v_metodopago           VARCHAR2 (50);
    v_tiporelacion         VARCHAR2 (50);
    v_usocfdi              VARCHAR2 (50);
    v_RFCpermitido         VARCHAR2 (50);
    
    
BEGIN
    --    EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE =  "LATIN AMERICAN SPANISH" ';
--        INSERT INTO APPS.EAM_AUX3 VALUES ('NC: ', 'entre', SYSDATE);
--        COMMIT;
    --    return 'INCORRECTO';

    -- Extraemos datos del XML
    SELECT x.RFCEmisor,
         x.TipoDeComprobante,
         x.MetodoPago,
         x.FormaPago,
         x.UsoCFDI,
         x.SubTotal
    INTO xmlRFCEmisor,
         xmlTipoDeComprobante,
         xmlMetodoPago,
         xmlFormaPago,
         xmlUsoCFDI,
         xmlSubtotal
    FROM apps.xxgepp_cust_registro_facturas2 t,
         XMLTABLE (
             XMLNAMESPACES (
                 'http://www.sat.gob.mx/cfd/4' AS "cfdi",
                 'http://www.w3.org/2001/XMLSchema-instance' AS "xsi"),
             '$d/cfdi:Comprobante'
             PASSING t.xml_Content AS "d"
             COLUMNS RFCEmisor            VARCHAR2 (20) PATH '/cfdi:Comprobante/cfdi:Emisor/@Rfc',
                     TipoDeComprobante    VARCHAR2 (120) PATH '@TipoDeComprobante',
                     MetodoPago           VARCHAR2 (120) PATH '@MetodoPago',
                     FormaPago            VARCHAR2 (120) PATH '@FormaPago',
                     UsoCFDI              VARCHAR2 (10) PATH '/cfdi:Comprobante/cfdi:Receptor/@UsoCFDI',
                     SubTotal             VARCHAR2 (50) PATH '/cfdi:Comprobante/@SubTotal')
         x
    WHERE t.REGISTRO_ID = (p_idregx);               -- 3032928;
    
--    Ticket 14122957 Autorizacion para subir Notas de Credito.
    SELECT COUNT (fl.lookup_code)
      INTO v_RFCpermitido 
    FROM apps.fnd_lookup_values_vl fl
    WHERE     1 = 1
       AND fl.lookup_type = 'XX_ISUPPLIER_NC_ACCESO'
       AND fl.enabled_flag = 'Y'
       AND fl.lookup_code = xmlRFCEmisor;

    if v_RFCpermitido = 0 then 
        v_mensaje := v_mensaje || ' No autorizado para carga de Notas de Crédito, haga llegar el XML y PDF a su comprador y/o contacto de almacén, quienes se encargarán de realizar el proceso interno. ';
        v_error := 1;
    END IF;

    BEGIN
        SELECT xt.UUID, xt.TipoRelacion
        INTO xmluuidRelacionado, xmlTipoRelacion
        FROM apps.xxgepp_cust_registro_facturas2 x
            CROSS JOIN XMLTABLE (
                 XMLNAMESPACES (
                     'http://www.sat.gob.mx/cfd/4' AS "cfdi"),
                     'for $j in /cfdi:Comprobante/cfdi:CfdiRelacionados
                     where ($j/@TipoRelacion = "01")
                        return $j'
                 PASSING x.xml_content
                 COLUMNS UUID VARCHAR2 (50) PATH 'cfdi:CfdiRelacionado/@UUID',
                         TipoRelacion VARCHAR2 (50) PATH '@TipoRelacion'
                 )
             xt
        WHERE x.registro_id = p_idregx;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            xmluuidRelacionado := NULL;
            v_mensaje := v_mensaje || ' No se encontro el elemento de CFDI Relacionados. ';
            v_error := 1;
    END;        
    
    IF xmluuidRelacionado IS NOT NULL
    THEN
        SELECT MAX (CASE tag WHEN 'FORMAPAGO' THEN meaning END),
               MAX (CASE tag WHEN 'TIPODECOMPROBANTE' THEN meaning END),
               MAX (CASE tag WHEN 'METODOPAGO' THEN meaning END),
               MAX (CASE tag WHEN 'TIPORELACION' THEN meaning END),
               MAX (CASE tag WHEN 'USOCFDI' THEN meaning END),
               MAX (CASE tag WHEN 'FACTORTOLERANCIA' THEN meaning END)
          INTO v_formapago,
               v_tipodecomprobante,
               v_metodopago,
               v_tiporelacion,
               v_usocfdi,
               v_factor_tolerancia
          FROM apps.fnd_lookup_values_vl
         WHERE     lookup_type = 'CUST_AP_NOTACREDITO'
               AND (   end_date_active IS NULL
                    OR TRUNC (end_date_active) > TRUNC (SYSDATE));

        IF UPPER (v_formapago) <> UPPER (xmlFormaPago)
        THEN
            v_mensaje :=
                   v_mensaje
                || 'Error. CFDI XML Atributo FormaPago, se esperada: '
                || v_formapago
                || '. ';
            v_error := 1;
        END IF;

        IF UPPER (v_tipodecomprobante) <> UPPER (xmlTipoDeComprobante)
        THEN
            v_mensaje :=
                   v_mensaje
                || 'Error. CFDI XML Atributo TipoDeComprobante, se esperada: '
                || v_tipodecomprobante
                || '. ';
            v_error := 1;
        END IF;

        IF UPPER (v_metodopago) <> UPPER (xmlMetodoPago)
        THEN
            v_mensaje :=
                   v_mensaje
                || 'Error. CFDI XML Atributo MetodoPago, se esperada: '
                || v_metodopago
                || '. ';
            v_error := 1;
        END IF;

        IF UPPER (v_tiporelacion) <> UPPER (xmlTipoRelacion)
        THEN
            v_mensaje :=
                   v_mensaje
                || 'Error. CFDI XML Atributo TipoRelacion, se esperada: '
                || v_tiporelacion
                || '. ';
            v_error := 1;
        END IF;

        IF UPPER (v_usocfdi) <> UPPER (xmlUsoCFDI)
        THEN
            v_mensaje :=
                   v_mensaje
                || 'Error. CFDI XML Atributo UsoCFDI, se esperada: '
                || v_usocfdi
                || '. ';
            v_error := 1;
        END IF;
    ELSE
        v_mensaje :=
            v_mensaje || ' err. La nota de credito no tiene UUID relacionado';
        v_error := 1;
    END IF;

    --Verificamos la ClaveProdServ
    SELECT COUNT (x.ClaveProdServ), COUNT (look.meaning)
    INTO v_clave_xml, v_clave_validos
    FROM apps.xxgepp_cust_registro_facturas2 t,
         XMLTABLE (
             XMLNAMESPACES (
                 'http://www.sat.gob.mx/cfd/4' AS "cfdi",
                 'http://www.w3.org/2001/XMLSchema-instance' AS "xsi"),
             '$d/cfdi:Comprobante/cfdi:Conceptos/cfdi:Concepto'
             PASSING t.xml_Content AS "d"
             COLUMNS ClaveProdServ    VARCHAR2 (20) PATH '@ClaveProdServ')
         x
         LEFT OUTER JOIN
         (SELECT MEANING
            FROM APPS.FND_LOOKUP_VALUES_VL
           WHERE     (    (    (LOOKUP_TYPE = 'CUST_AP_NOTACREDITO')
                           AND (TAG = 'CLAVE'))
                      AND (ENABLED_FLAG = 'Y'))
                 AND (   (END_DATE_ACTIVE IS NULL)
                      OR (TRUNC (END_DATE_ACTIVE) > TRUNC (SYSDATE)))) look
             ON x.ClaveProdServ = look.meaning
    WHERE t.registro_id = p_idregx;                       --3032928

    --dbms_output.put_line ( 'clave: ' || v_clave_xml || ' ' || v_clave_validos);

    IF v_clave_xml <> v_clave_validos
    THEN
        v_mensaje :=
            v_mensaje || 'Error en ClaveProdServ, facturar con clave 84111506 o comunicarse a MASProveedores@gepp.com';
        v_error := 1;
    END IF;

    --Verificamos la ClaveUnidad
    SELECT COUNT (x.ClaveUnidad), COUNT (look.meaning)
    INTO v_unidad_xml, v_unidad_validos
    FROM apps.xxgepp_cust_registro_facturas2 t,
       XMLTABLE (
           XMLNAMESPACES (
               'http://www.sat.gob.mx/cfd/4' AS "cfdi",
               'http://www.w3.org/2001/XMLSchema-instance' AS "xsi"),
           '$d/cfdi:Comprobante/cfdi:Conceptos/cfdi:Concepto'
           PASSING t.xml_Content AS "d"
           COLUMNS ClaveUnidad    VARCHAR2 (50) PATH '@ClaveUnidad') x
       LEFT OUTER JOIN
       (SELECT MEANING
          FROM APPS.FND_LOOKUP_VALUES_VL
         WHERE     (    (    (LOOKUP_TYPE = 'CUST_AP_NOTACREDITO')
                         AND (TAG = 'CLAVEUNIDAD'))
                    AND (ENABLED_FLAG = 'Y'))
               AND (   (END_DATE_ACTIVE IS NULL)
                    OR (TRUNC (END_DATE_ACTIVE) > TRUNC (SYSDATE)))) look
           ON x.ClaveUnidad = look.meaning
    WHERE t.registro_id = p_idregx;                         --3032928

    IF v_unidad_xml <> v_unidad_validos
    THEN
        v_mensaje :=
            v_mensaje || ' Error en ClaveUnidad, contactar a Tesoreria AP.';
        v_error := 1;
    END IF;
    
    -- Verificar que la factura original no exceda el 80% 
    
    BEGIN
        SELECT DISTINCT (ai.invoice_amount)
              INTO v_ap_monto_original
              FROM po.rcv_transactions                  rt,
                   ap_invoice_lines_all                 ail,
                   ap_invoices_all                      ai
             WHERE     1 = 1
                   AND rt.shipment_header_id = p_transaccion_id
                   AND ail.rcv_transaction_id = rt.transaction_id
                   AND ai.invoice_id = ail.invoice_id
                   AND apps.ap_invoices_pkg.get_approval_status (
                            ai.invoice_id,
                            ai.invoice_amount,
                            ai.payment_status_flag,
                            ai.invoice_type_lookup_code) = 'APPROVED';
    EXCEPTION
        WHEN OTHERS THEN
            v_error := 1;
            v_mensaje := v_mensaje || ' error al extraer los montos de factura ' || SQLERRM;
    END;
                                
    
    v_tolerancia := (xmlSubtotal / v_ap_monto_original) * 100;
    
    --dbms_output.put_line (v_tolerancia ||' ' || v_ap_monto_original ||' ' || xmlSubtotal || ' ' || v_factor_tolerancia);
    
    if v_tolerancia >= v_factor_tolerancia then 
        v_mensaje := v_mensaje || ' El subtotal de la NC excede porcentaje autorizado, favor de validar o comunicarse a MASProveedores@gepp.com ';
        v_error := 1;
    END IF;

    IF v_error = 0
    THEN
        v_mensaje := 'CORRECTO';
    END IF;

    DBMS_OUTPUT.put_line ('v_mensaje ' || v_mensaje);
    RETURN v_mensaje;
END;

/