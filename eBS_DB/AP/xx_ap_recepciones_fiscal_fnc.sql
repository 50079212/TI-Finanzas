CREATE OR REPLACE FUNCTION xxwebc.xx_ap_recepciones_fiscales_fnc (
    p_registro_id    NUMBER,
    p_transaccion_id NUMBER
    ) RETURN CLOB

-- $Id: xx_ap_recepciones_fiscal_fnc.sql 4851 2025-12-31 00:15:39Z vvelasco $
-- $URL: http://mxapediprdl.gepp.pvt:18080/svn/r12/iSupplier/sql/xx_ap_recepciones_fiscal_fnc.sql $

-- Recepción de facturas en iSupplier - cambio de año fiscal
-- Ticket: 16530595 RECEPCIÓN DE FACTURAS EN ISUPPLIER-CAMBIO DE AÑO FISCAL
 IS

    v_result             PLS_INTEGER := 0;
    v_error              PLS_INTEGER := 0;
    v_mensaje            CLOB;
    v_fecha_cfdi         DATE;
    v_shipment_header_id PLS_INTEGER;
    v_ultima_recepcion   DATE;
    v_year_actual        PLS_INTEGER;
    v_rango_inicio       DATE;
    v_rango_fin          DATE;
    v_supplier_exception PLS_INTEGER := 0;
    v_rfc_emisor         VARCHAR2(50);

    FUNCTION fechas_recepcion (
        p_rango_inicio    DATE,
        p_rango_fin       DATE,
        p_fecha_trans     DATE,
        p_fecha_cfdi      DATE,
        p_fecha_recepcion DATE,
        p_mensaje         OUT VARCHAR2
    ) RETURN PLS_INTEGER IS

        v_result        PLS_INTEGER := 1;  -- por defecto "malo" si no aplica ninguna regla
        v_anio          PLS_INTEGER;
        r_anio          PLS_INTEGER;
        f_anio          PLS_INTEGER;
        in_rango        BOOLEAN;
        r_es_31dic_prev BOOLEAN;
        f_es_01ene_anio BOOLEAN;
    BEGIN
        p_mensaje := NULL;
      -- Año de la transacción
        v_anio := extract(YEAR FROM p_fecha_trans);

      -- Años de recepción y CFDI
        r_anio := extract(YEAR FROM p_fecha_recepcion);
        f_anio := extract(YEAR FROM p_fecha_cfdi);

      -- ¿Transacción dentro del rango? (comparación por fecha truncada)
        in_rango := ( trunc(p_fecha_trans) BETWEEN trunc(p_rango_inicio) AND trunc(p_rango_fin) );

      -- Casos especiales de frontera: 31-Dic-(año-1) y 01-Ene-(año)
        r_es_31dic_prev := ( trunc(p_fecha_recepcion) = TO_DATE ( to_char(v_anio - 1)
                                                                  || '1231', 'YYYYMMDD' ) );

        f_es_01ene_anio := ( trunc(p_fecha_cfdi) = TO_DATE ( to_char(v_anio)
                                                             || '0101', 'YYYYMMDD' ) );

        IF in_rango THEN
         -- Reglas cuando la transacción está dentro del rango
            IF r_es_31dic_prev AND f_es_01ene_anio
            THEN
               -- R=31-dic-(año-1) y F=01-ene-(año) => OK
                v_result := 0;
            ELSIF ( r_anio = v_anio - 1 AND f_anio = v_anio - 1 ) THEN
               -- R=año-1, F=año-1 => OK
                v_result := 0;
            ELSIF ( r_anio = v_anio - 1 AND f_anio = v_anio
            ) THEN
               -- R=año-1, F=año => malo
                v_result := 1;
                p_mensaje := 'La fecha límite para carga de facturas con fecha de emisión '
                             || ( v_anio - 1 )
                             || ' expiró el 15 de enero de '
                             || v_anio
                             || '.';

            ELSIF ( r_anio = v_anio AND f_anio = v_anio - 1 ) THEN
               -- R=año, F=año-1 => malo
                v_result := 1;
                p_mensaje := 'La fecha de emisión del CFDI no corresponde con el ejercicio fiscal de la recepción en almacén.';
            ELSE
               -- Combinaciones no especificadas => malo (por defecto)
                v_result := 1;
                p_mensaje := 'No especifica - La fecha de emisión del CFDI no corresponde con el ejercicio fiscal de la recepción en almacén.'
                ;
            END IF;
        ELSE
         -- Reglas cuando la transacción está fuera del rango
            IF ( r_anio = v_anio - 1 AND f_anio = v_anio - 1 ) THEN
               -- R=año-1, F=año-1 => malo
                v_result := 1;
                p_mensaje := 'La fecha de emisión del CFDI no corresponde con el ejercicio fiscal de la recepción en almacén.';
            ELSIF ( r_anio = v_anio AND f_anio = v_anio ) THEN
               -- R=año, F=año => OK
                v_result := 0;
            ELSE
               -- Combinaciones no especificadas => malo (por defecto)
                v_result := 1;
                p_mensaje := 'La fecha de emisión del CFDI no corresponde con el ejercicio fiscal de la recepción en almacén.';
            END IF;
        END IF;

        RETURN v_result;
    END fechas_recepcion;

BEGIN
   -- buscamos la fecha del cfdi
    SELECT
        trunc(TO_DATE(xt.fecha, 'YYYY-MM-DD"T"HH24:MI:SS')),
        xt.RFC_Emisor
    INTO v_fecha_cfdi,
         v_rfc_emisor
    FROM
        apps.xxgepp_cust_registro_facturas2 x,
        XMLTABLE ( XMLNAMESPACES ( 'http://www.sat.gob.mx/cfd/4' AS "cfdi", 'http://www.sat.gob.mx/TimbreFiscalDigital' AS "tfd" ),
        '/cfdi:Comprobante'
                PASSING x.xml_content
            COLUMNS
                fecha VARCHAR2(50) PATH '@Fecha',
                RFC_Emisor VARCHAR2 (50) PATH 'cfdi:Emisor/@Rfc'
        )                                   xt
    WHERE
        registro_id = p_registro_id;

   -- buscamos la fecha de la transanccion
    SELECT
        b.num_id_transaccion,
        max(rt.transaction_date)
    INTO
        v_shipment_header_id,
        v_ultima_recepcion
    FROM
             apps.rcv_transactions rt
        INNER JOIN apps.xxgepp_cust_registro_facturas2 b ON rt.shipment_header_id = b.num_id_transaccion
        INNER JOIN ap_invoice_lines_all                ail ON ail.rcv_transaction_id = rt.transaction_id
    WHERE
            1 = 1
        AND rt.transaction_type = 'RECEIVE'
    -- AND trunc (rt.transaction_date) = '28-aug-2025'
    AND b.NUM_ID_TRANSACCION = p_transaccion_id --24972800 --24983874
    GROUP BY
        b.num_id_transaccion;

   -- Rango de fechas para aceptar facturas con excepcion.
    BEGIN
        SELECT
            start_date_active,
            end_date_active
        INTO
            v_rango_inicio,
            v_rango_fin
        FROM
            apps.fnd_lookup_values_vl
        WHERE
                lookup_type = 'CUST_AP_RECEP_FISCAL'
            AND meaning = EXTRACT(YEAR FROM sysdate);

    EXCEPTION
        WHEN no_data_found THEN
            v_rango_inicio := TO_DATE ( '01-jan-'
                                        || EXTRACT(YEAR FROM sysdate), 'DD-MON-YYYY' );
            v_rango_fin := TO_DATE ( '15-jan-'
                                     || EXTRACT(YEAR FROM sysdate), 'DD-MON-YYYY' );
    END;

    -- Proveedores con Excepcion
    BEGIN
        select count(lv.lookup_code)
        into v_supplier_exception
        from apps.fnd_lookup_values lv
        where lv.lookup_type = 'CUST_AP_RECEP_EXCEP'
        and lv.lookup_code = v_rfc_emisor
            and lv.enabled_flag = 'Y'
            and trunc(sysdate) between nvl(lv.start_date_active,trunc(sysdate)
                ) and nvl(lv.end_date_active, trunc(sysdate)
        );

    EXCEPTION
        WHEN no_data_found THEN
            null;
    END;

   dbms_output.put_line('Entrada): '
                        || ' RangoInicio='
                        || TO_CHAR ( v_rango_inicio, 'DD-MON-YYYY' )
                        || ' RangoFin='
                        || TO_CHAR ( v_rango_fin, 'DD-MON-YYYY' )
                        || ' FechaCFDI='
                        || TO_CHAR ( v_fecha_cfdi, 'DD-MON-YYYY' )
                        || ' UltimaRecepcion='
                        || TO_CHAR ( v_ultima_recepcion, 'DD-MON-YYYY' ) );

    if v_supplier_exception = 0 AND EXTRACT(YEAR FROM sysdate) = 2026 then

        v_error := fechas_recepcion(v_rango_inicio,
                                    v_rango_fin,
                                    trunc(sysdate),
                                    v_fecha_cfdi,
                                    v_ultima_recepcion,
                                    v_mensaje);
    ELSE
        v_error := 0;
    end if;

    dbms_output.put_line('Salida): '
                         || v_error
                         || ' - '
                         || v_mensaje);
    IF v_error = 0 THEN
        v_mensaje := 'CORRECTO';
        -- v_mensaje := 'CORRECTO ' || v_rango_inicio || ' ' ||
        --                         v_rango_fin || ' ' || v_fecha_cfdi || ' ' ||
        --                         v_ultima_recepcion || ' ' || to_date ('16-jan-2025','DD-MON-YYYY');
    END IF;

    RETURN v_mensaje;
END xx_ap_recepciones_fiscales_fnc;
/

-- GRANT EXECUTE ON xxwebc.xx_ap_recepciones_fiscales_fnc TO apps;
-- COMMIT;