CREATE OR REPLACE FUNCTION apps.CUST_AP_BLOQUEO_CLAVEPRODSERV (
    p_idregx         NUMBER,
    p_transaccion_id NUMBER
) RETURN CLOB

-- $Id: CUST_AP_BLOQUEO_CLAVEPRODSERV.fnc 4738 2025-07-02 18:18:59Z vvelasco $
-- $URL: http://mxapediprdl.gepp.pvt:18080/svn/r12/iSupplier/sql/CUST_AP_BLOQUEO_CLAVEPRODSERV.fnc $
 
-- Funcion para no permitir la carga de ciertos ClaveProdServ
-- El ticket era 14636649 Candado para facturas tipo anticipo isupplier
 IS
    v_mensaje        CLOB := NULL; -- Mensaje de error o correcto.
    v_error          NUMBER := 0;             -- 0 no error, 1 error

    v_ClaveProdServ VARCHAR2(20);

BEGIN
    -- Extraemos los datos del XML
    FOR x IN (SELECT x.ClaveProdServ, look.MEANING, count (x.ClaveProdServ)
          FROM apps.xxgepp_cust_registro_facturas2  t,
               XMLTABLE (
                   XMLNAMESPACES ('http://www.sat.gob.mx/cfd/4' AS "cfdi",
                                  'http://www.w3.org/2001/XMLSchema-instance' AS "xsi"),
                   '$d/cfdi:Comprobante/cfdi:Conceptos/cfdi:Concepto'
                   PASSING t.xml_Content AS "d"
                   COLUMNS ClaveProdServ VARCHAR2 (20) PATH '@ClaveProdServ') x
               INNER JOIN
               (SELECT LOOKUP_CODE, MEANING
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'CUST_AP_BLOQUEO_CLAVEPROD'
                       AND enabled_flag = 'Y'
                       AND (end_date_active IS NULL OR TRUNC (end_date_active) > TRUNC (SYSDATE)))
               look
                   ON x.ClaveProdServ = look.LOOKUP_CODE
         WHERE t.registro_id = p_idregx
         group by x.ClaveProdServ, look.meaning) 
         LOOP
            if x.ClaveProdServ is not null then
                v_error := 1;
                v_mensaje := v_mensaje || 'Clave Producto o Servicio ' || x.ClaveProdServ || ' tipo ' || x.meaning || ',' ;  
            end if;
         END LOOP;


IF v_error = 0 THEN
    v_mensaje := 'CORRECTO';
else
    v_mensaje := v_mensaje || ' no puede ingresarse en el portal favor comunicarse con su comprador. ';
END IF;

--dbms_output.put_line('v_mensaje ' || v_mensaje);

RETURN v_mensaje;

end;