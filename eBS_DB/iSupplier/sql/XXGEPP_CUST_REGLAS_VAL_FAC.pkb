create or replace PACKAGE BODY  "APPS"."XXGEPP_CUST_REGLAS_VAL_FAC" 
IS
    -- $Id: XXGEPP_CUST_REGLAS_VAL_FAC.pkb 4852 2025-12-31 01:45:38Z vvelasco $
    -- $URL: http://mxapediprdl.gepp.pvt:18080/svn/r12/iSupplier/sql/XXGEPP_CUST_REGLAS_VAL_FAC.pkb $
    
    FUNCTION consume_ws (xsd_ws CLOB)
            RETURN VARCHAR2
        IS
            soap_request   CLOB;
            soap_respond   CLOB;
            i              INTEGER;
            http_req       UTL_HTTP.req;
            http_resp      UTL_HTTP.resp;
            l_http_req     UTL_HTTP.req;
            v_code         VARCHAR2 (1000);
            v_mensaje      VARCHAR2 (4000);
            ocode          VARCHAR2 (1000);
            omensaje       VARCHAR2 (4000);
            
            V_URLM                        VARCHAR2 (200);
            V_WALLET_PATH                 VARCHAR2 (200);
            V_WALLET_PASS                 VARCHAR2 (200);
            V_SOAP                        CLOB := NULL;
            
        BEGIN
            BEGIN
                SELECT MEANING, description, tag
                  INTO V_WALLET_PATH, V_URLM, V_WALLET_PASS
                  FROM fnd_lookup_values_vl
                 WHERE     ENABLED_FLAG = 'Y'
                       AND lookup_type = 'CUST_FND_WALLET_CFDI'
                       AND lookup_code = 10
                       AND (   END_DATE_ACTIVE IS NULL
                            OR TRUNC (END_DATE_ACTIVE) > TRUNC (SYSDATE));
            EXCEPTION
                WHEN OTHERS
                THEN
                    ocode := '1';

                    omensaje :=
                           'err - En la obtención del lookup CUST_FND_WALLET_CFDI '
                        || SQLERRM;
            END;

            --DBMS_OUTPUT.PUT_LINE('1.2');
            soap_request := xsd_ws;
            --DBMS_OUTPUT.PUT_LINE('1.3');
            --      message_log(soap_request);
            --DBMS_OUTPUT.PUT_LINE (soap_request);
            --        message_log('url_ws:' || url_ws);
            --       DBMS_OUTPUT.PUT_LINE ('TEST');
            UTL_HTTP.SET_WALLET (V_WALLET_PATH, V_WALLET_PASS);
            -- DBMS_OUTPUT.PUT_LINE('1.4');
            http_req := UTL_HTTP.begin_request (V_URLM, 'POST');
            DBMS_OUTPUT.PUT_LINE ('1.3');
            --  DBMS_OUTPUT.PUT_LINE ('1.5');
            /*El contenido que enviamos es XML: */
            UTL_HTTP.set_header (http_req,
                                 'Content-Type',
                                 'text/xml; charset=UTF-8');

            /*Establecemos el SOAPAction a invocar: */

            UTL_HTTP.set_header (
                http_req,
                'SOAPAction',
                '"http://www.gepp.com.mx/ValidaFacturaGEPPV/Validar"');  --ypr

            /*Indicamos en el header el tamano del mensaje enviado: */

            UTL_HTTP.set_header (http_req,
                                 'Content-Length',
                                 LENGTH (soap_request));

            /*Escribimos el body del request */

            DECLARE
                req_length   BINARY_INTEGER;
                offset       PLS_INTEGER := 1;
                amount       PLS_INTEGER := 2000;
                BUFFER       VARCHAR2 (2000);
            BEGIN
                DBMS_OUTPUT.PUT_LINE ('1.4');
                req_length := DBMS_LOB.GETLENGTH (soap_request);

                IF req_length <= 32767
                THEN
                    UTL_HTTP.write_text (http_req, soap_request);
                ELSE
                    --               UTL_HTTP.set_header (http_req, 'Transfer-Encoding', 'chunked');
                    WHILE (offset < req_length)
                    LOOP
                        DBMS_LOB.READ (soap_request,
                                       amount,
                                       offset,
                                       BUFFER);

                        UTL_HTTP.write_text (http_req, BUFFER);

                        offset := offset + amount;
                    END LOOP;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    DBMS_OUTPUT.PUT_LINE ('EXCEPCION' || SQLERRM);
            END;

            /*Obtenemos la respuesta */

            http_resp := UTL_HTTP.get_response (http_req);

            --http_resp

            BEGIN
                LOOP
                    UTL_HTTP.read_text (http_resp, soap_respond);

                    V_SOAP := V_SOAP || SOAP_RESPOND;
                --DBMS_OUTPUT.put_line (soap_respond);
                --DBMS_OUTPUT.put_line ('$$$$|||'||V_SOAP);

                END LOOP;
            EXCEPTION
                WHEN UTL_HTTP.end_of_body
                THEN
                    NULL;
            END;

            DBMS_OUTPUT.PUT_LINE ('1.5');

            /*Cargamos en la variable respVal la devolución del servidor */
            --                                UTL_HTTP.read_text (http_resp, soap_respond);
            /*Finalizamos la conexión HTTP */
            UTL_HTTP.end_response (http_resp);
            DBMS_OUTPUT.PUT_LINE ('1.6a');
            --    DBMS_OUTPUT.PUT_LINE ('http_resp:'||http_resp);
            --  message_log('Respuesta WS:'||soap_respond);
            DBMS_OUTPUT.PUT_LINE ('Respuesta WS:' || soap_respond);
            v_code := '';
            --message_log(ocode);
            --message_log(omensaje);
            /*    IF NVL (TRIM (ocode), 'nulo') = 'nulo' THEN
                   ocode := '1';
                   omensaje := 'NO se encontro la respuesta del Web Service PACK';
                END IF; */
            -- DBMS_OUTPUT.put_line ('omensaje ' || soap_respond);

            RETURN soap_respond;

            DBMS_OUTPUT.PUT_LINE ('1.7');
        EXCEPTION
            WHEN UTL_HTTP.end_of_body
            THEN
                ocode := '1';
                omensaje := 'Error en UTL_HTTP.end_of_body';
                --message_log(ocode);
                --message_log(omensaje);
                RETURN omensaje;
            WHEN UTL_HTTP.request_failed
            THEN
                ocode := '1';
                omensaje :=
                       'Falló solicitud al Web Service(Sin Respuesta): '
                    || SQLERRM;
                DBMS_OUTPUT.PUT_LINE (OCODE);
                DBMS_OUTPUT.PUT_LINE (omensaje);
                DBMS_OUTPUT.PUT_LINE (UTL_HTTP.get_detailed_sqlerrm);
                --message_log(ocode);
                --message_log(omensaje);
                RETURN omensaje;
            WHEN OTHERS
            THEN
                ocode := '1';

                omensaje :=
                       'Error: '
                    || SQLERRM
                    || ', Respuesta ws:'
                    || SUBSTR (soap_respond, 1, 100);

                --message_log(ocode);
                --message_log(omensaje);

                RETURN omensaje;
        END consume_ws;
        
    -- Programa consolida las reglas de negocio para la recepcion de los CFDI XML.

    PROCEDURE valida_y_addenda (P_origen           IN OUT VARCHAR2,
                                P_XML              IN     CLOB,
                                P_Transaccion_ID   IN     NUMBER,
                                p_estatus             OUT VARCHAR2,
                                P_ADDENDA             OUT CLOB,
                                p_id_control          OUT NUMBER)
    IS
        V_RETURN                      VARCHAR2 (32000);
        V_RETURN2                     VARCHAR2 (2000);
        --        V_RETURN_EXC                  VARCHAR2 (1000);
        --        v_mensaje                     apps.xxgepp_cust_registro_facturas.mensaje_ws%TYPE;
        NO_FILES                      EXCEPTION;
        V_EX                          VARCHAR2 (1000);
        V_EX2                         NUMBER := 0;
        V_FLAGVALIDACION              BOOLEAN := FALSE;
        --        V_EXISTE2                     VARCHAR2 (1000);
        V_EXISTE3                     NUMBER := 0;
        V_ERROR_CONCA                 CLOB;
        --        V_FUNCION                     VARCHAR2 (1000);
        V_CUENTA_UUID                 NUMBER := 0;
        V_TRANSFER_NO                 VARCHAR2 (100);
        ----------------
        --V_URLM         VARCHAR2(100) :=  'https://cfditaxshield.gepp.com/servicios/ws1/service.asmx';
        V_URLM                        VARCHAR2 (200);
        V_WALLET_PATH                 VARCHAR2 (200);
        V_WALLET_PASS                 VARCHAR2 (200);
        --        RESULTADOM                    VARCHAR2 (2000);
        V_XMLCONTENTGLM               CLOB;
        --        V_XMLCONTENTGLMB              BLOB;
        V_XMLBASE64GLM                CLOB;
        --        V_CONCANUEVAM                 CLOB;
        --VARIABLES PARA ATRIBUTOS XML
        --        V_ERROR_CONCAM                CLOB;
        --        V_INVOICEIDM                  VARCHAR2 (50);
        --V_VERSIONM         NUMBER;
        V_VERSIONM                    VARCHAR2 (50);
        V_SERIEM                      VARCHAR2 (25);
        V_FOLIOM                      VARCHAR2 (40);
        V_FECHAM                      VARCHAR2 (75);
        V_FECHAMP                     VARCHAR2 (75);
        ------------------------------------
        --        V_SELLOM                      VARCHAR2 (500);
        --        V_FORMAPAGOM                  VARCHAR2 (100);
        --        V_NUMCERM                     VARCHAR2 (50);
        --        V_CERTIFICADOM                VARCHAR2 (1000);
        --        V_CONDICIONESM                VARCHAR2 (1000);
        ---------------------------------
        V_SUBTOTALM                   VARCHAR2 (50);
        --        V_DESCUENTOM                  VARCHAR2 (50);
        V_MONEDAM                     VARCHAR2 (500);
        --        V_TipoCambio                  NUMBER;
        V_TOTALM                      VARCHAR2 (50);
        V_METODOPAGOM                 VARCHAR2 (100);
        V_TIPOCOMPROM                 VARCHAR2 (100);
        --        V_LUGARM                      VARCHAR2 (1000);
        --        V_EXPORTACION                 VARCHAR2 (50);
        ---------------------------------
        V_EMIRFCM                     VARCHAR2 (100);
        --        V_EMINOMBREM                  VARCHAR2 (255);
        --        -------------------------------
        --        V_RECEPNOMBREM                VARCHAR2 (255);
        --        V_DOMFISCALCPM                VARCHAR2 (50);
        --
        --        V_EXPRFCM                     VARCHAR2 (100);
        --        V_EXPNOMBREM                  VARCHAR2 (100);
        --        V_EXPCPM                      VARCHAR2 (100);
        --        V_REGIMENM                    VARCHAR2 (100);
        --------------------------------
        V_RECRFCM                     VARCHAR2 (100);
        V_IVAM                        NUMBER;
        V_RETENCIONM                  NUMBER := 0;
        V_UUIDM                       VARCHAR2 (250);
        V_LUUIDM                      VARCHAR2 (50);
        V_BASE64                      CLOB;
        V_XMLTYPE                     XMLTYPE;
        V_IDREGX                      NUMBER;
        V_RESPONSETYPE                XMLTYPE;
        V_SOAP                        CLOB := NULL;
        V_MEN                         VARCHAR2 (32000);
        V_REG                         VARCHAR2 (1000);
        RAISE_ERROR                   EXCEPTION;
        RAISE_ADDENDA                 EXCEPTION;
        V_CUENTA                      NUMBER := 0;
        RAISE_ORIGEN                  EXCEPTION;
        RAISE_FECHA                   EXCEPTION;
        V_FECHAL                      VARCHAR2 (50);
        V_FECHAL_EMI                  VARCHAR2 (50); --11341181 Validación XML ampliación de fecha 29 de Abril
        --        V_FECHAC                      DATE;
        V_CUENTAVERSION               NUMBER := 0;
        --        V_CUENTAFECHA                 NUMBER := 0;
        V_PROD                        VARCHAR2 (10);
        V_ORIG                        VARCHAR2 (10);
        V_INSTANCIA                   VARCHAR2 (10);
        --        V_VAR                         VARCHAR2 (100) := '';
        V_P_XML                       CLOB;
        V_USOCFDI                     VARCHAR2 (1000);
        V_ERROR                       VARCHAR2 (10000);
        VFECHAuso                     DATE;
        --        V_WARNING_USOCFDI             VARCHAR2 (100);
        V_BANDERA                     VARCHAR2 (100);
        v_debug                       VARCHAR2 (3000);
        v_user_id                     NUMBER;
        V_COUNTMONEDA                 NUMBER := 0;
        V_COUNT_USOCFDI_PROV          NUMBER := 0;
        -- variables de combustible
        V_subtotalC                   NUMBER := 0;
        V_totalC                      NUMBER := 0;
        V_invoice_idC                 NUMBER;
        V_invoice_amountC             NUMBER := 0;
        V_TOTAL_TAX_AMOUNTC           NUMBER := 0;
        V_INVOICE_CURRENCY_CODEC      VARCHAR2 (100);
        V_TOLERANCIA                  NUMBER;

        --IVA 8%
        v_TotalImpuestosTrasladados   VARCHAR2 (100);
        v_TotalImpuestosRetenidos     VARCHAR2 (100);
        --        v_iva_sp                      NUMBER := 0;
        --        v_ret_sp                      NUMBER := 0;
        --        v_is_iva                      VARCHAR2 (3000);
        V_IMP                         CLOB;
        v_cartaporte                  CLOB;
        v_xml_impuestos               CLOB;
        V_VALCFDI                     CLOB;
        V_ADVERTENCIA                 CLOB;
        --        V_COUNT_TAX                   NUMBER := 0;
        --OIE
        V_DIAS                        VARCHAR2 (10);
        V_HISTORIAL                   VARCHAR2 (10);
        V_COUNT_OIE_PROCESADO         NUMBER := 0;
        V_COUNT_EMP_DIAS              NUMBER := 0;
        V_PORTAL_ORG_ID               NUMBER := 0;

        v_masiva                      NUMBER := 0;
        v_msg_masiva                  CLOB;

        v_msg_fiscal                  CLOB;

        v_notacredito                 NUMBER := 0;
        --NC 13180431 Ingreso de Notas de Crédito a través de WS
        v_msg_notacredito             CLOB;
        V_UUID_RELACIONADO            VARCHAR2 (100);
        V_FACTURA_RELACIONADO         VARCHAR2 (1000);

        --VALS DE SP DE XML 14639695
        V_SP_VALS                     CLOB;

        --ANTICIPO
        V_TRANSFER_NO_TYPE            VARCHAR2 (100);
        V_SA_VALS                     CLOB;
        --14122899 Validación uso del CFDI de Anticipos a Proveedores
        V_TIPO_ANT                    VARCHAR2 (100);


        v_VersionValeDespensa         VARCHAR2 (10) := NULL;
        v_ValValesDespensa            CLOB;

        PROCEDURE sp_ObtenerBase (p_registro_id NUMBER)
        IS
            V_XMLBASE64    CLOB;
            V_XMLCONTENT   XMLTYPE;
        BEGIN
            SELECT XML_CONTENT --,                                    XML_BASE64
              INTO V_XMLCONTENT --                                  ,V_XMLBASE64GLM
              FROM xxgepp_cust_registro_facturas2
             WHERE REGISTRO_ID = P_REGISTRO_ID; --ACA VA LA SECUENCIA CONSUMIDA

            V_XMLCONTENTGLM := V_XMLCONTENT.getClobVal ();

            UPDATE XXAP_PRUEBA
               SET TEXTO = V_XMLCONTENTGLM
             WHERE REGISTRO = V_IDREGX;

            COMMIT;

            BEGIN
                SELECT TEXTO
                  INTO V_XMLCONTENTGLM
                  FROM XXAP_PRUEBA
                 WHERE REGISTRO = V_IDREGX;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            /*V_BASE64 :=
               UTL_ENCODE.text_encode (V_XMLCONTENTGLM,
                                       -- UTL_ENCODE.text_encode (P_XML,
                                       'AL32UTF8',
                                       UTL_ENCODE.BASE64);
            */

            V_BASE64 := CUST_EncodeBASE64_FNC (V_XMLCONTENTGLM);
            --V_XMLCONTENTGLMB := V_XMLCONTENT.getBlobVal ();
            -- V_XMLCONTENTGLMB:=clob2blob(V_XMLCONTENTGLM);
            -- V_BASE64:=base64EncodeBlob_plsql(V_XMLCONTENTGLMB);
            --   V_BASE64  :=APPS.EncodeBASE64(V_XMLCONTENTGLM);
            --V_XMLBASE64GLM := V_BASE64;
            V_XMLBASE64GLM := V_BASE64;
        EXCEPTION
            WHEN OTHERS
            THEN
                BEGIN
                    V_BASE64 :=
                        APPS.CUST_ENCODEBASE64_fnc (
                            REPLACE (REPLACE ((V_XMLCONTENTGLM), CHR (10)),
                                     CHR (13)));

                    V_XMLBASE64GLM := V_BASE64;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        V_ERROR := SQLERRM;

                        V_ERROR_CONCA :=
                               V_ERROR_CONCA
                            || 'Error en transformar a BASE64 '
                            || V_ERROR;

                        V_FLAGVALIDACION := TRUE;
                END;
        -- || SUBSTR (V_RETURN2, 1, 60);

        -- DBMS_OUTPUT.PUT_LINE ('EXCEPCION' || SQLERRM);

        END;

        --Se quita sub-funcion y se declara en un bloque independiente
        
    ----------------------------------    BEGIN PRINCIPAL
    BEGIN
        --insert into eam_aux3 values ('XX 1',sysdate);
        --COMMIT;
        ---bueno
        BEGIN
            --EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE =  "LATIN AMERICAN SPANISH" ';
            EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE =  "AMERICAN" ';

            DBMS_OUTPUT.PUT_LINE (
                'Entre al proceso XXGEPP_CUST_REGLAS_VAL_FAC.');

            SELECT xxgepp_cust_reg_fac2x.NEXTVAL INTO V_IDREGX FROM DUAL;

            SELECT FND_GLOBAL.user_id INTO v_user_id FROM DUAL;

            V_P_XML := REGEXP_REPLACE (P_XML, '<\?.*\?>', '');

            V_P_XML := REPLACE (V_P_XML, 'ï»¿', '');
            V_P_XML := REPLACE (V_P_XML, 'xmlns:cfdi="Addenda"', '');

            -- Si se recibe un 3.0 cambiamos a 4.0 este codigo solo sirve a hasta Enero 2023
            -- V_P_XML :=
            --     REPLACE (V_P_XML,
            --              'xmlns:cfdi="http://www.sat.gob.mx/cfd/3"',
            --              'xmlns:cfdi="http://www.sat.gob.mx/cfd/4"');

            -- Validacion Masiva bandera.
            IF p_origen = 'MASIVA'
            THEN
                p_origen := 'ISUPPLIER';
                v_masiva := 1;    -- Indica que la carga masiva esta activada.
            END IF;

            -- Validacion para Notas de Credito
            IF p_origen = 'NOTACREDITO'
            THEN
                p_origen := 'ISUPPLIER';
                v_notacredito := 1; -- Indica que entra una Nota de Credito por iSupplier
            END IF;

            IF NVL (V_USER_ID, 0) = -1
            THEN
                V_P_XML := REPLACE (V_P_XML, '''', '''''');
            ELSE
                V_P_XML := REPLACE (V_P_XML, '''''', '''');
            END IF;


            -- Este codigo quita la addenda, pero parece que no sirve.
            -- Si el XML trae addenda marca error que no puede parser el XML
            IF UPPER (p_origen) IN ('ISUPPLIER', 'ISUPPLIERC')
            THEN
                V_xmltype := XMLTYPE.createxml (V_P_XML);
            ELSE
                WITH
                    XML_TABLE
                    AS
                        (SELECT XMLTYPE (V_P_XML) AS XML_COLUMN FROM DUAL)
                SELECT XMLQUERY (
                           'declare namespace cfdi = "http://www.sat.gob.mx/cfd/4"; (: :)
                            copy $NEWXML := $XML modify (
                            delete nodes $NEWXML/cfdi:Comprobante/cfdi:Addenda
                            )
                            return $NEWXML'
                           PASSING XML_COLUMN AS "XML"      --'TEST' as "NAME"
                                                      RETURNING CONTENT)
                  INTO V_xmltype
                  FROM XML_TABLE;
            END IF;

            INSERT INTO xxgepp_cust_registro_facturas2 (REGISTRO_ID,
                                                        NOMBRE_APLICACION,
                                                        XML_CONTENT,
                                                        NUM_ID_TRANSACCION)
                 VALUES (V_IDREGX,
                         P_ORIGEN,
                         V_XMLTYPE,
                         P_Transaccion_ID);
            
            --  insert into xxgepp_cust_registro_facturas3 (REGISTRO_ID) values (V_IDREGX);

            COMMIT;

            --insert into eam_aux3 values ('XX 4',sysdate);
            --COMMIT;

            INSERT INTO xxgepp_cust_registro_fact_all (REGISTRO_ID,
                                                       NOMBRE_APLICACION,
                                                       NUM_ID_TRANSACCION)
                 VALUES (V_IDREGX, P_ORIGEN, P_Transaccion_ID);

            COMMIT;

            v_debug := 'Termina de insercción en tablas';
        EXCEPTION
            WHEN OTHERS
            THEN
                V_RETURN2 := SQLERRM;
                p_estatus :=
                       'err - en el insert xxgepp_cust_registro_facturas2 '
                    || V_IDREGX
                    || SUBSTR (V_RETURN2, 1, 60);
                RETURN;
                DBMS_OUTPUT.PUT_LINE ('EXCEPCION' || SQLERRM);
        END;

        ---------------------------------------------------------------------------------

        BEGIN
            SELECT COUNT (MEANING)
              INTO V_CUENTA
              FROM FND_LOOKUP_VALUES_VL
             WHERE     LOOKUP_TYPE = 'CUST_FND_ORIGEN_CFDI_LKP'
                   AND MEANING = P_ORIGEN;

            IF V_CUENTA = 0
            THEN
                V_RETURN := 'err - NO EXISTE ORIGEN  ' || P_ORIGEN;

                DELETE FROM xxgepp_cust_registro_facturas2
                      WHERE registro_id = V_IDREGX;

                --RETURN V_RETURN;

                p_estatus := V_RETURN;

                RAISE RAISE_ORIGEN;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE ('EXCEPCION 00 ' || SQLERRM);

                V_RETURN2 := SQLERRM;

                p_estatus :=
                       'err - en la obtencion del Origen '
                    || SUBSTR (V_RETURN2, 1, 60);

                RETURN;
        END;

        --VALS DE SP DE XML 14639695
        BEGIN
            IF p_origen = 'SP'
            THEN
                V_TRANSFER_NO_TYPE :=
                    XXWEBC.cust_ap_transfer_type_fnc (p_transaccion_id);

                IF V_TRANSFER_NO_TYPE = 'SP'
                THEN
                    V_SP_VALS :=
                        XXWEBC.CUST_AP_SP_XML_VAL_FNC (V_IDREGX,
                                                       P_TRANSACCION_ID);

                    IF V_SP_VALS <> 'CORRECTO'
                    THEN
                        V_ERROR_CONCA := V_ERROR_CONCA || V_SP_VALS;
                        V_FLAGVALIDACION := TRUE;
                    END IF;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                V_RETURN2 := SQLERRM;
                p_estatus :=
                       'err - al invocar la función CUST_AP_SP_XML_VAL_FNC'
                    || SUBSTR (V_RETURN2, 1, 60);
                RETURN;
        END;

        --ANTICIPO
        BEGIN
            IF p_origen = 'SP'
            THEN
                V_TRANSFER_NO_TYPE :=
                    XXWEBC.cust_ap_transfer_type_fnc (p_transaccion_id);

                IF V_TRANSFER_NO_TYPE = 'SA'
                THEN
                    V_SA_VALS :=
                        XXWEBC.CUST_AP_SA_XML_VALS_FNC (V_IDREGX,
                                                        P_TRANSACCION_ID);

                    --14122899 Validación uso del CFDI de Anticipos a Proveedores
                    V_TIPO_ANT :=
                        XXWEBC.cust_ap_ant_type_fnc (p_transaccion_id);

                    IF V_SA_VALS <> 'CORRECTO'
                    THEN
                        V_ERROR_CONCA := V_ERROR_CONCA || V_SA_VALS;
                        V_FLAGVALIDACION := TRUE;
                    END IF;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                V_RETURN2 := SQLERRM;
                p_estatus :=
                       'err - al invocar la función CUST_AP_SA_XML_VALS_FNC'
                    || SUBSTR (V_RETURN2, 1, 60);
                RETURN;
        END;


        BEGIN
            IF P_ORIGEN IN ('SP', 'OIE')
            THEN
                IF P_ORIGEN = 'SP'
                THEN
                    SELECT COUNT (TRANSFER_ID)
                      INTO V_EXISTE3
                      FROM cust_ap_terceros_h
                     WHERE TRANSFER_ID = P_Transaccion_ID;

                    IF V_EXISTE3 = 0
                    THEN
                        V_RETURN :=
                               'err - NO EXISTE TRANSFER_ID  '
                            || P_Transaccion_ID;

                        DELETE FROM xxgepp_cust_registro_facturas2
                              WHERE registro_id = V_IDREGX;

                        DELETE FROM xxgepp_cust_registro_fact_all
                              WHERE registro_id = V_IDREGX;

                        p_estatus := V_RETURN;

                        --RETURN V_RETURN;

                        RAISE RAISE_ORIGEN;
                    END IF;
                ELSIF P_ORIGEN = 'OIE'
                THEN
                    SELECT COUNT (REPORT_HEADER_ID)
                      INTO V_EXISTE3
                      FROM apps.xxexp_report_headers_all
                     WHERE REPORT_HEADER_ID = P_Transaccion_ID;

                    IF V_EXISTE3 = 0
                    THEN
                        V_RETURN :=
                               'err - NO EXISTE TRANSFER_ID  '
                            || P_Transaccion_ID;

                        DELETE FROM xxgepp_cust_registro_facturas2
                              WHERE registro_id = V_IDREGX;

                        DELETE FROM xxgepp_cust_registro_fact_all
                              WHERE registro_id = V_IDREGX;

                        COMMIT;

                        p_estatus := V_RETURN;

                        --RETURN V_RETURN;

                        RAISE RAISE_ORIGEN;
                    END IF;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE ('EXCEPCION 00 ' || SQLERRM);
                V_RETURN2 := SQLERRM;
                p_estatus :=
                       'err - al obtener el transfer_id o el report_header_id '
                    || SUBSTR (V_RETURN2, 1, 60);
                RETURN;
        END;

        v_debug := 'Inicia validación versión ' || V_IDREGX;

        BEGIN
            SELECT (COUNT (xt.versio))                    --xt.versio,xt.Fecha
              INTO V_CUENTAVERSION                       --V_VERSIONM,V_FECHAM
              FROM xxgepp_cust_registro_facturas2  x,
                   XMLTABLE (
                       XMLNAMESPACES (
                           'http://www.sat.gob.mx/cfd/4' AS "cfdi",
                           'http://www.sat.gob.mx/TimbreFiscalDigital'
                               AS "tfd"),
                       '/cfdi:Comprobante'
                       PASSING x.xml_content -- COLUMNS versio number PATH '@Version',
                       COLUMNS versio VARCHAR2 (50)
                                   PATH '@Version',
                               fecha VARCHAR2 (50)
                                   PATH '@Fecha') xt
             WHERE REGISTRO_ID = V_IDREGX;

            --Aqui es donde se coloca la secuencia consumida
            --  DBMS_OUTPUT.PUT_LINE(V_CUENTAVERSION);

            v_debug := 'Inicia validación versión. ';
        END;

        BEGIN
            IF V_CUENTAVERSION = 1
            THEN
                SELECT xt.versio, xt.Fecha
                  INTO V_VERSIONM, V_FECHAM
                  FROM xxgepp_cust_registro_facturas2  x,
                       XMLTABLE (
                           XMLNAMESPACES (
                               'http://www.sat.gob.mx/cfd/4' AS "cfdi",
                               'http://www.sat.gob.mx/TimbreFiscalDigital'
                                   AS "tfd"),
                           '/cfdi:Comprobante'
                           PASSING x.xml_content -- COLUMNS versio NUMBER PATH '@Version',
                           COLUMNS versio VARCHAR2 (50)
                                       PATH '@Version',
                                   fecha VARCHAR2 (50)
                                       PATH '@Fecha') xt
                 WHERE REGISTRO_ID = V_IDREGX;
            --Aqui es donde se coloca la secuencia consumida

            -- DBMS_OUTPUT.PUT_LINE(V_CUENTAVERSION);

            ELSIF V_CUENTAVERSION = 0
            THEN
                SELECT xt.versio, xt.Fecha
                  INTO V_VERSIONM, V_FECHAM
                  FROM xxgepp_cust_registro_facturas2  x,
                       XMLTABLE (
                           XMLNAMESPACES (
                               'http://www.sat.gob.mx/cfd/4' AS "cfdi",
                               'http://www.sat.gob.mx/TimbreFiscalDigital'
                                   AS "tfd"),
                           '/cfdi:Comprobante'
                           PASSING x.xml_content --COLUMNS versio NUMBER PATH '@version',
                           COLUMNS versio VARCHAR2 (50)
                                       PATH '@version',
                                   fecha VARCHAR2 (50)
                                       PATH '@fecha') xt
                 WHERE REGISTRO_ID = V_IDREGX;
            --Aqui es donde se coloca la secuencia consumida
            --  DBMS_OUTPUT.PUT_LINE(V_CUENTAVERSION);

            END IF;

            v_debug := 'Termina validación versión';

            -- DBMS_OUTPUT.PUT_LINE(V_VERSIONM||'***');

            UPDATE xxgepp_cust_registro_facturas2
               SET XML_VERSION = V_VERSIONM
             WHERE REGISTRO_ID = V_IDREGX;

            COMMIT;

            UPDATE xxgepp_cust_registro_fact_all
               SET XML_VERSION = V_VERSIONM
             WHERE REGISTRO_ID = V_IDREGX;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                V_RETURN2 := SQLERRM;

                p_estatus :=
                       'err - al obtener la Version '
                    || SUBSTR (V_RETURN2, 1, 60);

                DBMS_OUTPUT.PUT_LINE ('EXCEPCION' || SQLERRM);

                RETURN;
        END;

        BEGIN
            SELECT MEANING, TAG --11341181 Validación XML ampliación de fecha 29 de Abril
              INTO V_FECHAL, V_FECHAL_EMI --11341181 Validación XML ampliación de fecha 29 de Abril
              FROM FND_LOOKUP_VALUES_VL
             WHERE LOOKUP_TYPE = 'CUST_AP_SAT_FECHA_LIMIT';

            V_FECHAM :=
                TRUNC (
                    TO_DATE (REPLACE (V_FECHAM, 'T', ' '),
                             'YYYY/MM/DD HH24:MI:ss'));

            V_FECHAMP :=
                TO_CHAR (TO_DATE (V_FECHAM, 'DD/MM/YYYY'), 'YYYY-MM-DD');
            --V_FECHAL := TO_DATE(V_FECHAL,'YYYY-MM-DD');

            V_FECHAL := TRUNC (TO_DATE (V_FECHAL, 'DD/MM/YY'));
            V_FECHAL_EMI := TRUNC (TO_DATE (V_FECHAL_EMI, 'DD/MM/YY')); --11341181 Validación XML ampliación de fecha 29 de Abril

            --  DBMS_OUTPUT.PUT_LINE('***'||V_FECHAL||'***'||V_FECHAMP);

            --NUEVO DEADLINE 3.3
            IF V_VERSIONM NOT IN ('3.3', '4.0')
            THEN
                V_FLAGVALIDACION := TRUE;
                V_ERROR_CONCA :=
                    'ERROR: Version de CFDI no soportada:  ' || V_VERSIONM;
            END IF;

            IF V_VERSIONM != '4.0'
            THEN
                --IF TO_DATE (V_FECHAM, 'DD-MM-YY') >
                IF TRUNC (SYSDATE) > ----11341181 Validación XML ampliación de fecha 29 de Abril
                                     TO_DATE (V_FECHAL, 'DD-MM-YY')
                THEN
                    V_FLAGVALIDACION := TRUE;
                    V_ERROR_CONCA :=
                           'ERROR: La version del xml '
                        || V_VERSIONM
                        || ' es invalida,'
                        --|| V_FECHAM
                        || ' es posterior a lo permitido '
                        || V_FECHAL;
                ELSIF TO_DATE (V_FECHAM, 'DD-MM-YY') > ----11341181 Validación XML ampliación de fecha 29 de Abril
                      TO_DATE (V_FECHAL_EMI, 'DD-MM-YY')
                THEN
                    V_FLAGVALIDACION := TRUE;
                    V_ERROR_CONCA :=
                           'ERROR: La version del xml '
                        || V_VERSIONM
                        || ' es invalida,'
                        || ' la fecha del XML es:'
                        || V_FECHAM
                        || ' , posterior a lo permitido '
                        || V_FECHAL_EMI;
                END IF;
            END IF;
        --insert into eam_aux3 values ('A1 ',sysdate);
        --commit;

        END;

        BEGIN
            IF V_VERSIONM IN ('3.2', '3.3')
            THEN
                DBMS_OUTPUT.PUT_LINE ('***3.2 o 3.3***');
                V_FLAGVALIDACION := TRUE;
                V_ERROR_CONCA :=
                    'ERROR: Version de CFDI no soportada:  ' || V_VERSIONM;
            ELSIF V_VERSIONM IN ('4.0')
            THEN
                v_debug := 'Inicia validaciones 4.0';

                BEGIN
                    SELECT xt.version,
                           xt.serie,
                           xt.folio,
                           xt.RFC_Emisor,
                           xt.RFC_Receptor,
                           xt.UUID,
                           xt.Moneda,
                           xt.tipoCompro,
                           xt.total,
                           xt.subTotal,
                           xt.USOCFDI,
                           xt.TotalImpuestosTrasladados,
                           xt.TotalImpuestosRetenidos,
                           xt.VersionValeDespensa
                      INTO V_VERSIONM,
                           V_SERIEM,
                           V_FOLIOM,
                           V_EMIRFCM,
                           V_RECRFCM,
                           V_UUIDM,
                           V_MONEDAM,
                           V_TIPOCOMPROM,
                           V_TOTALM,
                           V_SUBTOTALM,
                           V_USOCFDI,
                           v_TotalImpuestosTrasladados,
                           v_TotalImpuestosRetenidos,
                           v_VersionValeDespensa
                      FROM xxgepp_cust_registro_facturas2  x,
                           XMLTABLE (
                               XMLNAMESPACES (
                                   'http://www.sat.gob.mx/cfd/4' AS "cfdi",
                                   'http://www.sat.gob.mx/TimbreFiscalDigital'
                                       AS "tfd",
                                   'http://www.sat.gob.mx/valesdedespensa'
                                       AS "valesdedespensa"),
                               '/cfdi:Comprobante'
                               PASSING x.xml_content
                               COLUMNS serie VARCHAR (100)
                                           PATH '@Serie',
                                       folio VARCHAR2 (100)
                                           PATH '@Folio',
                                       version VARCHAR2 (10)
                                           PATH '@Version',
                                       Moneda VARCHAR2 (50)
                                           PATH '@Moneda',
                                       TipoCambio VARCHAR2 (50)
                                           PATH '@TipoCambio',
                                       metodoDePago VARCHAR2 (100)
                                           PATH '@MetodoDePago',
                                       exportacion VARCHAR2 (10)
                                           PATH '@Exportacion',
                                       tipoCompro VARCHAR2 (50)
                                           PATH '@TipoDeComprobante',
                                       NomEmisor VARCHAR2 (400)
                                           PATH 'cfdi:Emisor/@Nombre',
                                       RFC_Emisor VARCHAR2 (50)
                                           PATH 'cfdi:Emisor/@Rfc',
                                       NomReceptor VARCHAR2 (400)
                                           PATH 'cfdi:Receptor/@Nombre',
                                       RFC_Receptor VARCHAR2 (50)
                                           PATH 'cfdi:Receptor/@Rfc',
                                       USOCFDI VARCHAR2 (50)
                                           PATH 'cfdi:Receptor/@UsoCFDI',
                                       DomicilioFiscalReceptor VARCHAR2 (50)
                                           PATH 'cfdi:Receptor/@DomicilioFiscalReceptor',
                                       RegimenFiscalReceptor VARCHAR2 (50)
                                           PATH 'cfdi:Receptor/@RegimenFiscalReceptor',
                                       total VARCHAR2 (50)
                                           PATH '@Total',
                                       subTotal VARCHAR2 (50)
                                           PATH '@SubTotal',
                                       retencion VARCHAR2 (50)
                                           PATH 'cfdi:Impuestos/cfdi:Retenciones/cfdi:Retencion/@Importe',
                                       UUID VARCHAR2 (250)
                                           PATH 'cfdi:Complemento/tfd:TimbreFiscalDigital/@UUID',
                                       TotalImpuestosTrasladados VARCHAR2 (50)
                                           PATH 'cfdi:Impuestos/@TotalImpuestosTrasladados',
                                       TotalImpuestosRetenidos VARCHAR2 (50)
                                           PATH 'cfdi:Impuestos/@TotalImpuestosRetenidos',
                                       VersionValeDespensa VARCHAR2 (10)
                                           PATH '/cfdi:Comprobante/cfdi:Complemento/valesdedespensa:ValesDeDespensa/@version')
                           xt
                     WHERE REGISTRO_ID = V_IDREGX; --Aqui es donde se coloca la secuencia consumida
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('EXCEPCION XML' || SQLERRM);
                        V_RETURN2 := SQLERRM;
                        p_estatus :=
                               'err - al obtener etiqueta de XML Version 3.3 o 4.0 '
                            || '°°°'
                            || V_FOLIOM
                            || ' |||2 '
                            || V_SERIEM
                            || ' |||6 '
                            || V_UUIDM
                            || ' |||8 '
                            || V_METODOPAGOM
                            || ' |||13 '
                            || V_IVAM
                            || ' |||14 '
                            || V_UUIDM
                            || ' |||15 '
                            || V_USOCFDI
                            || SUBSTR (V_RETURN2, 1, 60);
                        RETURN;
                END;

            -- Recepción de facturas en iSupplier - cambio de año fiscal
            -- Ticket: 16530595 RECEPCIÓN DE FACTURAS EN ISUPPLIER-CAMBIO DE AÑO FISCAL
                BEGIN
                    IF p_origen = 'ISUPPLIER' AND v_notacredito = 0 
                    THEN
                        V_msg_fiscal :=
                            xxwebc.xx_ap_recepciones_fiscales_fnc (
                                v_idregx,
                                p_transaccion_id);

                        IF V_msg_fiscal <> 'CORRECTO'
                        THEN
                            v_error_conca := v_error_conca || V_msg_fiscal;
                            v_flagvalidacion := TRUE;
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_return2 := SQLERRM;
                        p_estatus :=
                               'err - al invocar la función xx_ap_recepciones_fiscales_fnc '
                            || SUBSTR (v_return2, 1, 60);
                        RETURN;
                END;

                -- Validacion MASIVA reglas de OAF portadas a PLSQL. Ticket: 9519477 VV
                -- @TODO agregar que tambien tenga warnings

                BEGIN
                    IF p_origen = 'ISUPPLIER' AND V_MASIVA = 1
                    THEN
                        v_msg_masiva :=
                            apps.cust_ap_is_vals_oaf_fnc (v_idregx,
                                                          p_transaccion_id,
                                                          v_emirfcm);
                        DBMS_OUTPUT.put_line (
                               'v_msg_masiva: '
                            || v_msg_masiva
                            || ' uuid: '
                            || V_UUIDM);

                        IF REGEXP_SUBSTR (v_msg_masiva,
                                          '(.*?)(\||$)',
                                          1,
                                          1,
                                          NULL,
                                          1) <> 'CORRECTO'
                        THEN
                            V_ERROR_CONCA :=
                                   V_ERROR_CONCA
                                || REGEXP_SUBSTR (v_msg_masiva,
                                                  '(.*?)(\||$)',
                                                  1,
                                                  1,
                                                  NULL,
                                                  1);
                            V_FLAGVALIDACION := TRUE;

                            IF REGEXP_SUBSTR (v_msg_masiva,
                                              '(.*?)(\||$)',
                                              1,
                                              2,
                                              NULL,
                                              1) <> EMPTY_CLOB ()
                            THEN
                                V_ADVERTENCIA :=
                                       V_ADVERTENCIA
                                    || REGEXP_SUBSTR (v_msg_masiva,
                                                      '(.*?)(\||$)',
                                                      1,
                                                      2,
                                                      NULL,
                                                      1);
                            END IF;
                        ELSIF REGEXP_SUBSTR (v_msg_masiva,
                                             '(.*?)(\||$)',
                                             1,
                                             2,
                                             NULL,
                                             1) <> EMPTY_CLOB ()
                        THEN
                            V_ADVERTENCIA :=
                                   V_ADVERTENCIA
                                || REGEXP_SUBSTR (v_msg_masiva,
                                                  '(.*?)(\||$)',
                                                  1,
                                                  2,
                                                  NULL,
                                                  1);
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_return2 := SQLERRM;
                        p_estatus :=
                               'err - al invocar la función cust_ap_is_vals_oaf_fnc. '
                            || SUBSTR (v_return2, 1, 60);
                        RETURN;
                END;

                -- Validaciones 4.0 Ticket 8647609
                BEGIN
                    V_VALCFDI := APPS.CUST_AP_CFDI_VALS_FNC (V_IDREGX);

                    -- V_VALCFDI regresa datos separados por | regex para traer el dato.
                    IF REGEXP_SUBSTR (V_VALCFDI,
                                      '(.*?)(\||$)',
                                      1,
                                      1,
                                      NULL,
                                      1) <> 'CORRECTO'
                    THEN
                        --V_ERROR_CONCA := V_ERROR_CONCA || V_VALCFDI;
                        V_ERROR_CONCA :=
                               V_ERROR_CONCA
                            || REGEXP_SUBSTR (V_VALCFDI,
                                              '(.*?)(\||$)',
                                              1,
                                              1,
                                              NULL,
                                              1);
                        V_FLAGVALIDACION := TRUE;

                        IF REGEXP_SUBSTR (V_VALCFDI,
                                          '(.*?)(\||$)',
                                          1,
                                          2,
                                          NULL,
                                          1) <> EMPTY_CLOB ()
                        THEN
                            V_ADVERTENCIA :=
                                   V_ADVERTENCIA
                                || REGEXP_SUBSTR (V_VALCFDI,
                                                  '(.*?)(\||$)',
                                                  1,
                                                  2,
                                                  NULL,
                                                  1);
                        END IF;
                    ELSIF REGEXP_SUBSTR (V_VALCFDI,
                                         '(.*?)(\||$)',
                                         1,
                                         2,
                                         NULL,
                                         1) <> EMPTY_CLOB ()
                    THEN
                        V_ADVERTENCIA :=
                               V_ADVERTENCIA
                            || REGEXP_SUBSTR (V_VALCFDI,
                                              '(.*?)(\||$)',
                                              1,
                                              2,
                                              NULL,
                                              1);
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_return2 := SQLERRM;
                        p_estatus :=
                               'err - al invocar la función CUST_AP_CFDI_VALS_FNC. '
                            || SUBSTR (v_return2, 1, 60);
                        RETURN;
                END;


                -- Ticket  12881471    Validaciones de Notas de Credito Pepsico
                BEGIN
                    IF p_origen = 'ISUPPLIER' AND v_notacredito = 1
                    THEN
                        v_msg_notacredito :=
                            XXWEBC.cust_ap_val_notacredito_fnc (
                                v_idregx,
                                p_transaccion_id);

                        IF v_msg_notacredito <> 'CORRECTO'
                        THEN
                            v_error_conca :=
                                v_error_conca || v_msg_notacredito;
                            v_flagvalidacion := TRUE;
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_return2 := SQLERRM;
                        p_estatus :=
                               'err - al invocar la función cust_ap_val_notacredito_fnc. '
                            || SUBSTR (v_return2, 1, 60);
                        RETURN;
                END;



                -- Ticket 8223779 Carta Porte Validaciones. VV

                BEGIN
                    IF p_origen = 'ISUPPLIER' AND v_notacredito = 0
                    THEN
                        v_cartaporte :=
                            XXWEBC.cust_ap_val_cartaporte2_fnc (
                                v_idregx,
                                p_transaccion_id);

                        IF v_cartaporte <> 'CORRECTO'
                        THEN
                            v_error_conca := v_error_conca || v_cartaporte;
                            v_flagvalidacion := TRUE;
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_return2 := SQLERRM;
                        p_estatus :=
                               'err - al invocar la función cust_ap_val_cartaporte2_fnc. '
                            || SUBSTR (v_return2, 1, 60);
                        RETURN;
                END;


                -- Ticket 10194741 Validación XML Campos Impuestos. VV
                BEGIN
                    IF p_origen = 'ISUPPLIER'
                    THEN
                        v_xml_impuestos :=
                            --apps.cust_ap_val_xml_impuestos_fnc (
                             XXWEBC.cust_ap_val_imp01_fnc (v_idregx,
                                                           p_transaccion_id);

                        IF v_xml_impuestos <> 'CORRECTO'
                        THEN
                            v_error_conca := v_error_conca || v_xml_impuestos;
                            v_flagvalidacion := TRUE;
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_return2 := SQLERRM;
                        p_estatus :=
                               'err - al invocar la función cust_ap_val_imp0_fnc. '
                            || SUBSTR (v_return2, 1, 60);
                        RETURN;
                END;

                -- Ticket 14636649 Candado para facturas tipo anticipo isupplier. VV
                BEGIN
                    IF p_origen = 'ISUPPLIER' AND v_notacredito = 0 
                    THEN
                        v_xml_impuestos :=
                            APPS.cust_ap_bloqueo_claveprodserv (
                                v_idregx,
                                p_transaccion_id);

                        IF v_xml_impuestos <> 'CORRECTO'
                        THEN
                            v_error_conca := v_error_conca || v_xml_impuestos;
                            v_flagvalidacion := TRUE;
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_return2 := SQLERRM;
                        p_estatus :=
                               'err - al invocar la función cust_ap_bloqueo_claveprodserv. '
                            || SUBSTR (v_return2, 1, 60);
                        RETURN;
                END;


                -- Validación de EDENRED para vales de despensa. VV
                -- Ticket 9393989 y 10555397
                BEGIN
                    IF     p_origen = 'ISUPPLIER'
                       AND v_VersionValeDespensa = '1.0'
                    THEN
                        v_ValValesDespensa :=
                            APPS.CUST_AP_VALESDESPENSA_FNC (V_IDREGX,
                                                            p_transaccion_id);

                        IF REGEXP_SUBSTR (v_ValValesDespensa,
                                          '(.*?)(\||$)',
                                          1,
                                          1,
                                          NULL,
                                          1) <> 'CORRECTO'
                        THEN
                            V_ERROR_CONCA :=
                                   V_ERROR_CONCA
                                || REGEXP_SUBSTR (v_ValValesDespensa,
                                                  '(.*?)(\||$)',
                                                  1,
                                                  1,
                                                  NULL,
                                                  1);
                            V_FLAGVALIDACION := TRUE;
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_return2 := SQLERRM;
                        p_estatus :=
                               'err - al invocar la función CUST_AP_VALESDESPENSA_FNC. '
                            || SUBSTR (v_return2, 1, 60);
                        RETURN;
                END;


                --VALIDACION DE IVA/RETENCION
                --comento para desarrollo de ret6%
                --COMENTADO POR EL TICKET 3821803 Y 6131387

                /*   BEGIN
                      IF p_origen = 'SP'
                      THEN
                         SELECT NVL (SUM (TOTAL), 0)
                           INTO v_iva_sp
                           FROM cust_ap_terceros_l
                          WHERE     1 = 1
                                AND TYPE_LINE = 'TAX'
                                AND transfer_id = P_Transaccion_ID;

                         SELECT NVL (SUM (TOTAL), 0)
                           INTO v_ret_sp
                           FROM cust_ap_terceros_l
                          WHERE     1 = 1
                                AND TYPE_LINE = '0ITEM'
                                AND transfer_id = P_Transaccion_ID;

                         IF v_iva_sp <>
                               TO_NUMBER (NVL (v_TotalImpuestosTrasladados, 0))
                         THEN
                            V_ERROR_CONCA :=
                                  V_ERROR_CONCA
                               || ' El Total del Iva capturado en la solicitud NO coincide con el Total de los Impuestos Tralsadados del XML, favor de corregir para poder continuar. ';

                            V_FLAGVALIDACION := TRUE;
                         END IF;

                         IF (-1) * v_ret_sp <>
                               TO_NUMBER (NVL (v_TotalImpuestosRetenidos, 0))
                         THEN
                            V_ERROR_CONCA :=
                                  V_ERROR_CONCA
                               || ' El Total de Retención capturado en la solicitud NO coincide con el Total de los Impuestos Retenidos del XML, favor de corregir para poder continuar. ';

                            V_FLAGVALIDACION := TRUE;
                         END IF;
                      END IF;
                   EXCEPTION
                      WHEN OTHERS
                      THEN
                         V_RETURN2 := SQLERRM;

                         p_estatus :=
                               'err - al obtener los totales de impuestos / retención '
                            || SUBSTR (V_RETURN2, 1, 60);

                         RETURN;
                   END;

                   BEGIN
                      IF p_origen = 'SP'
                      THEN
                         V_IMP :=
                            APPS.CUST_AP_SP_IMP_FNC (V_IDREGX, P_Transaccion_ID);

                         IF V_IMP <> 'CORRECTO'
                         THEN
                            V_ERROR_CONCA := V_ERROR_CONCA || V_IMP;

                            V_FLAGVALIDACION := TRUE;
                         END IF;

                         --YPR MAS DE UN IMPUESTO

                         SELECT COUNT (1)
                           INTO V_COUNT_TAX
                           FROM apps.cust_ap_terceros_l
                          WHERE TYPE_LINE = 'TAX' AND TRANSFER_ID = P_Transaccion_ID;
                         IF V_COUNT_TAX > 1
                         THEN
                            V_ERROR_CONCA :=
                                  V_ERROR_CONCA
                               || ' Favor de revisar los codigos de impuesto, se encontro mas de una línea de impuesto con el mismo regimen fiscal';
                            V_FLAGVALIDACION := TRUE;
                         END IF;
                      END IF;
                   EXCEPTION
                      WHEN OTHERS
                      THEN
                         V_RETURN2 := SQLERRM;

                         p_estatus :=
                               'err - al obtener los totales de impuestos / retención - CUST_AP_SP_IMP_FNC '
                            || SUBSTR (V_RETURN2, 1, 60);

                         RETURN;
                   END;    */
                -- FUNCIONES POR EL TICKET 3821803 Y 6131387

                --validacion de Juan Miranda
                BEGIN
                    IF p_origen = 'SP' AND V_TRANSFER_NO_TYPE <> 'SA' -- 13606153 ANTICIPOS
                    THEN
                        --V_IMP:=APPS.CUST_AP_SP_AGRUPA_RET_VAL_FNC(V_IDREGX,P_Transaccion_ID);
                        V_IMP :=
                            APPS.CUST_AP_SP_AGRUPA_RET_VAL_FNC2 (
                                V_IDREGX,
                                P_Transaccion_ID);

                        IF V_IMP <> 'CORRECTO'
                        THEN
                            V_ERROR_CONCA := V_ERROR_CONCA || V_IMP;

                            V_FLAGVALIDACION := TRUE;
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        V_RETURN2 := SQLERRM;
                        p_estatus :=
                               'err - al invocar la función CUST_AP_SP_AGRUPA_RET_VAL_FNC'
                            || SUBSTR (V_RETURN2, 1, 60);
                        RETURN;
                END;

                --validacion de Juan Miranda
                BEGIN
                    IF p_origen = 'SP' AND V_TRANSFER_NO_TYPE <> 'SA' -- 13606153 ANTICIPOS
                    THEN
                        V_IMP :=
                            APPS.CUST_AP_SP_AGRUPA_TRAS_VAL_FNC (
                                V_IDREGX,
                                P_Transaccion_ID);

                        IF V_IMP <> 'CORRECTO'
                        THEN
                            V_ERROR_CONCA := V_ERROR_CONCA || V_IMP;

                            V_FLAGVALIDACION := TRUE;
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        V_RETURN2 := SQLERRM;
                        p_estatus :=
                               'err - al invocar la función CUST_AP_SP_AGRUPA_TRAS_VAL_FNC '
                            || SUBSTR (V_RETURN2, 1, 60);
                        RETURN;
                END;



                /*
                   BEGIN
                      IF P_ORIGEN IN ('ISUPPLIER')
                      THEN
                         SELECT CUST_AP_UOP_IVA8_fnc (P_ORIGEN,p_transaccion_id) resultado
                           INTO V_IS_IVA
                           FROM DUAL;
                         IF V_IS_IVA = ('EXITOSO')
                         THEN
                           -- DBMS_OUTPUT.PUT_LINE ('');
                           NULL;
                         --DBMS_OUTPUT.PUT_LINE(V_EMIRFC||' '||V_EXISTE2);
                         ELSE
                            V_ERROR_CONCA := V_ERROR_CONCA || V_IS_IVA || CHR (10);
                            V_FLAGVALIDACION := TRUE;
                         END IF;
                      END IF;
                   EXCEPTION
                      WHEN OTHERS
                      THEN
                         ---DBMS_OUTPUT.PUT_LINE ('EXCEPCION 4 ' || SQLERRM);
                         V_RETURN2 := SQLERRM;
                         p_estatus :=
                               'err - en la función del 8% '
                            || SUBSTR (V_RETURN2, 1, 60);
                         RETURN;
                   END;
                   */
                ---- VALIDA SI EXISTE EL XML

                BEGIN
                    IF p_origen = 'SP'
                    THEN
                        SELECT COUNT (ATTRIBUTE8)
                          INTO V_CUENTA_UUID
                          FROM cust_ap_terceros_h
                         WHERE     ATTRIBUTE8 = V_UUIDM
                               AND TRANSFER_ID <> P_Transaccion_ID
                               AND STATUS NOT IN ('CANCELADO', 'RECHAZADO');

                        --inseRt into eam_aux3 values ('B 1 '||V_UUIDM||' '||P_Transaccion_ID,sysdate);

                        --COMMIT;

                        IF V_CUENTA_UUID != 0
                        THEN
                            SELECT TRANSFER_NO
                              INTO V_TRANSFER_NO
                              FROM cust_ap_terceros_h
                             WHERE     ATTRIBUTE8 = V_UUIDM
                                   AND TRANSFER_ID <> P_Transaccion_ID
                                   AND STATUS NOT IN
                                           ('CANCELADO', 'RECHAZADO')
                                   AND ROWNUM = 1;

                            V_FLAGVALIDACION := TRUE;

                            V_ERROR_CONCA :=
                                   V_ERROR_CONCA
                                || 'EL XML YA FUE UTILIZADO EN LA SOLICITUD DE PAGO: '
                                || ' --> '
                                || V_TRANSFER_NO
                                || CHR (10);
                        -- DBMS_OUTPUT.PUT_LINE(V_TRANSFER_NO||'  '||'EXISTE');

                        END IF;
                    --insert into eam_aux3 values ('B 2 '||V_UUIDM||' '||P_Transaccion_ID,sysdate);
                    --COMMIT;

                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        NULL;
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('EXCEPCION 2 ' || SQLERRM);

                        V_RETURN2 := SQLERRM;

                        p_estatus :=
                               'err - al obtener existencia de XML '
                            || SUBSTR (V_RETURN2, 1, 60);

                        RETURN;
                END;



                --10779335 CANDADO PARA EVITAR SUBIR UN XML EN  DIFERENTES PLATAFORMAS Y SUCURSALES
                IF p_origen = 'SP'
                THEN
                    BEGIN
                        V_EX :=
                            XXWEBC.CUST_AP_UUID_DUPLICIDAD_FNC (
                                P_ORIGEN,
                                V_UUIDM,
                                P_Transaccion_ID);

                        IF V_EX != 'CORRECTO'
                        THEN
                            --DBMS_OUTPUT.PUT_LINE('ERROR');
                            V_ERROR_CONCA :=
                            V_ERROR_CONCA || V_EX || CHR (10);
                            V_FLAGVALIDACION := TRUE;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            V_RETURN2 := SQLERRM;
                            p_estatus :=
                                   'err - al Obtener CUST_AP_UUID_DUPLICIDAD_FNC '
                                || SUBSTR (V_RETURN2, 1, 60);

                            RETURN;
                    END;
                END IF;


                -------------  STATUS EN MODO CAPTURADO 

                BEGIN
                    IF p_origen = 'SP'
                    THEN
                        IF p_origen = 'SP'
                        THEN
                            V_EX2 := 0;

                            SELECT COUNT (status)
                              INTO V_EX2
                              FROM apps.cust_ap_terceros_h
                             WHERE     transfer_id = P_Transaccion_ID
                                   AND STATUS = 'CAPTURADO';

                            IF V_EX2 = 1
                            THEN
                                --  DBMS_OUTPUT.PUT_LINE(V_EXISTE||'  '||'EXISTE');
                                DBMS_OUTPUT.PUT_LINE ('');
                            ELSE
                                V_FLAGVALIDACION := TRUE;
                                V_ERROR_CONCA :=
                                       V_ERROR_CONCA
                                    || 'EL STATUS NO EXISTE'
                                    || ' --> '
                                    || V_EX2
                                    || CHR (10);
                            --  DBMS_OUTPUT.PUT_LINE(V_EXISTE||'  '||'NO EXISTE');
                            END IF;
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('EXCEPCION 2 ' || SQLERRM);
                        V_RETURN2 := SQLERRM;
                        p_estatus :=
                               'err - al obtener Status '
                            || SUBSTR (V_RETURN2, 1, 60);

                        RETURN;
                END;

                --VALIDACION DE PROVEEDOR RFC EMISOR Y RECEPCION 

                BEGIN
                    IF p_origen = 'SP' AND V_TRANSFER_NO_TYPE <> 'SA' -- 13606153 ANTICIPOS
                    THEN
                        SELECT cust_ap_prov_sp_fnc (V_EMIRFCM, V_RECRFCM)    resultado
                          INTO V_EX
                          FROM DUAL;

                        IF V_EX LIKE ('EXITOSO%')
                        THEN
                            DBMS_OUTPUT.PUT_LINE ('');
                        --DBMS_OUTPUT.PUT_LINE(V_EMIRFC||' '||V_EXISTE2);
                        ELSE
                            V_ERROR_CONCA :=
                                V_ERROR_CONCA /*|| 'EL PROVEEDOR CON EL RFC'
                                              || ' --> '
                                              || V_EMIRFCM
                                              || '-- NO CUENTA CON LAS CARACTERÍSTICAS PARA CREAR SOLICITUDES DE PAGO, FAVOR DE CONTACTAR A CONTRALORIA AP '*/
                                              || V_EX || CHR (10);
                            --  DBMS_OUTPUT.PUT_LINE('EL PROVEEDOR CON EL RFC ' || V_EMIRFC
                            --                        || '-- NO CUENTA CON LAS CARACTERÍSTICAS PARA CREAR SOLICITUDES DE PAGO, FAVOR DE CONTACTAR A CONTRALORIA AP ');
                            V_FLAGVALIDACION := TRUE;
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('EXCEPCION 3 ' || SQLERRM);
                        V_RETURN2 := SQLERRM;
                        p_estatus :=
                               'err - al obtener proveedor Emisor y Receptor '
                            || SUBSTR (V_RETURN2, 1, 60);
                        RETURN;
                END;

                ----  VALIDACION DE PROVEEDOR CERTIFICADO 

                BEGIN
                    IF p_origen = 'SP'
                    THEN
                        V_EX :=
                            apps.cust_ap_prov_certifica2 (V_EMIRFCM,
                                                          NULL,
                                                          '1');

                        --DBMS_OUTPUT.PUT_LINE(V_EXISTE2);

                        IF V_EX = 'NO'
                        THEN
                            -- DBMS_OUTPUT.PUT_LINE('ERROR');
                            V_ERROR_CONCA :=
                                   V_ERROR_CONCA
                                || 'EL PROVEEDOR NO ES CERTIFICADO'
                                || ' --> '
                                || V_EMIRFCM
                                || CHR (10);
                            V_FLAGVALIDACION := TRUE;
                        ELSIF V_EX = 'SI'
                        THEN
                            DBMS_OUTPUT.PUT_LINE ('');
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('EXCEPCION 4 ' || SQLERRM);
                        V_RETURN2 := SQLERRM;
                        p_estatus :=
                               'err - al obtener proveedor certificado '
                            || SUBSTR (V_RETURN2, 1, 60);
                        RETURN;
                END;

                --- ********* VALIDACIONES DE LA MATRIZ

                BEGIN
                    V_EX :=
                        FN_CUST_FORMAPAGO (p_origen,
                                           V_IDREGX,
                                           P_Transaccion_ID);


                    -- Las facturas de vales de despensa se validan en otro pkg.
                    IF v_VersionValeDespensa IS NOT NULL
                    THEN
                        V_EX := 'CORRECTO';
                    END IF;

                    -- Las notas de credito se validan en otro pkg con reglas diferentes.
                    IF v_notacredito = 1
                    THEN
                        V_EX := 'CORRECTO';
                    END IF;

                    IF V_EX != 'CORRECTO'
                    THEN
                        --DBMS_OUTPUT.PUT_LINE('ERROR');
                        V_ERROR_CONCA := V_EX || CHR (10);
                        V_FLAGVALIDACION := TRUE;
                    ELSIF V_EX = 'CORRECTO'
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('');
                    END IF;

                    IF V_EX = 'NO ENCONTRADO'
                    THEN
                        DBMS_OUTPUT.PUT_LINE (
                            'NO ENCONTRADO EN FORMA DE PAGO');
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('EXCEPCION 5 ' || SQLERRM);

                        V_RETURN2 := SQLERRM;

                        p_estatus :=
                               'err - al obtener Forma de Pago'
                            || SUBSTR (V_RETURN2, 1, 60);

                        RETURN;
                END;

                v_debug := 'Inicia FN_CUST_METODOPAGO';

                BEGIN
                    V_EX :=
                        FN_CUST_METODOPAGO (p_origen,
                                            V_IDREGX,
                                            P_TRANSACCION_ID);

                    --DBMS_OUTPUT.PUT_LINE(V_EX);

                    -- Las notas de credito se validan en otro pkg.
                    IF v_notacredito = 1
                    THEN
                        V_EX := 'CORRECTO';
                    END IF;

                    -- Las facturas con complemento de Vales de Despensa se validan en otra función.
                    IF v_VersionValeDespensa IS NOT NULL
                    THEN
                        V_EX := 'CORRECTO';
                    END IF;

                    IF V_EX != 'CORRECTO'
                    THEN
                        --DBMS_OUTPUT.PUT_LINE('ERROR');
                        V_ERROR_CONCA := V_ERROR_CONCA || V_EX || CHR (10);
                        V_FLAGVALIDACION := TRUE;
                    ELSIF V_EX = 'CORRECTO'
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('');
                    END IF;

                    IF V_EX = 'NO ENCONTRADO'
                    THEN
                        DBMS_OUTPUT.PUT_LINE (
                            'NO ENCONTRADO EN METODO DE PAGO');
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('EXCEPCION 6 ' || SQLERRM);
                        V_RETURN2 := SQLERRM;
                        p_estatus :=
                               'err - al Obtener Metodo de Pago '
                            || SUBSTR (V_RETURN2, 1, 60);

                        RETURN;
                END;

                v_debug := 'Inicia FN_CUST_TIPORELACION';

                BEGIN
                    V_EX :=
                        FN_CUST_TIPORELACION (p_origen,
                                              V_IDREGX,
                                              P_TRANSACCION_ID);

                    --DBMS_OUTPUT.PUT_LINE(V_EX);

                    IF V_EX <> 'CORRECTO'
                    THEN
                        --DBMS_OUTPUT.PUT_LINE('ERROR');
                        V_ERROR_CONCA := V_ERROR_CONCA || V_EX || CHR (10);
                        V_FLAGVALIDACION := TRUE;
                    ELSIF V_EX = 'CORRECTO'
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('');
                    --ELSIF V_EX = 'NO APLICA'
                    --THEN
                    -- DBMS_OUTPUT.PUT_LINE ('');
                    --DBMS_OUTPUT.PUT_LINE ('NO APLICA EN "' || P_ORIGEN || '"');
                    END IF;

                    IF V_EX = 'NO ENCONTRADO'
                    THEN
                        DBMS_OUTPUT.PUT_LINE (
                            'NO ENCONTRADO EN TIPO DE RELACION');
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('EXCEPCION 7 ' || SQLERRM);
                        V_RETURN2 := SQLERRM;
                        p_estatus :=
                               'err - al obtener Tipo de Relacion '
                            || SUBSTR (V_RETURN2, 1, 60);

                        RETURN;
                END;

                v_debug := 'Inicia FN_CUST_RESIDENCIAFISCAL';

                BEGIN
                    V_EX := FN_CUST_RESIDENCIAFISCAL (p_origen, V_IDREGX);

                    --DBMS_OUTPUT.PUT_LINE(V_EX);

                    IF V_EX != 'CORRECTO'
                    THEN
                        --DBMS_OUTPUT.PUT_LINE('ERROR');
                        V_ERROR_CONCA := V_ERROR_CONCA || V_EX || CHR (10);
                        V_FLAGVALIDACION := TRUE;
                    ELSIF V_EX = 'CORRECTO'
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('');
                    END IF;

                    IF V_EX = 'NO ENCONTRADO'
                    THEN
                        DBMS_OUTPUT.PUT_LINE (
                            'NO ENCONTRADO EN RESIDENCIA FISCAL');
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('EXCEPCION 8 ' || SQLERRM);
                        V_RETURN2 := SQLERRM;
                        p_estatus :=
                               'err - al obtenener Residencia Fiscal '
                            || SUBSTR (V_RETURN2, 1, 60);
                        RETURN;
                END;

                v_debug := 'Inicia FN_CUST_NUMREGIDTRIB';

                BEGIN
                    V_EX := FN_CUST_NUMREGIDTRIB (p_origen, V_IDREGX);

                    --DBMS_OUTPUT.PUT_LINE(V_EX);

                    IF V_EX != 'CORRECTO'
                    THEN
                        --DBMS_OUTPUT.PUT_LINE('ERROR');
                        V_ERROR_CONCA := V_ERROR_CONCA || V_EX || CHR (10);
                        V_FLAGVALIDACION := TRUE;
                    ELSIF V_EX = 'CORRECTO'
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('');
                    END IF;

                    IF V_EX = 'NO ENCONTRADO'
                    THEN
                        DBMS_OUTPUT.PUT_LINE (
                            'NO ENCONTRADO EN RESIDENCIA FISCAL');
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.PUT_LINE ('EXCEPCION 9 ' || SQLERRM);
                        V_RETURN2 := SQLERRM;
                        p_estatus :=
                               'err - al obtener Numero de Registro '
                            || SUBSTR (V_RETURN2, 1, 60);
                        RETURN;
                END;

                BEGIN
                    BEGIN
                        SELECT TO_DATE (MEANING, 'DD-MM-YY')
                          INTO VFECHAuso
                          FROM fnd_lookup_values_vl
                         WHERE     ENABLED_FLAG = 'Y'
                               AND lookup_type =
                                   'CUST_AP_USOCFDI_FECHA_LIMITE'
                               AND (   END_DATE_ACTIVE IS NULL
                                    OR TRUNC (END_DATE_ACTIVE) >
                                       TRUNC (SYSDATE));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            V_ERROR_CONCA :=
                                   V_ERROR_CONCA
                                || 'Configuracion en la fecha limite del UsoCFDI dentro del lookup '
                                || SQLERRM
                                || CHR (10);

                            V_FLAGVALIDACION := TRUE;
                    --RETURN 'Configuracion en la fecha limite del UsoCFDI dentro del lookup '
                    --         || SQLERRM;
                    END;

                    v_debug := 'Inicia CUST_CFDI_USO_FNC';

                    IF VFECHAuso >= TRUNC (SYSDATE)
                    THEN
                        V_BANDERA := '0';
                    ELSE
                        V_BANDERA := '1';
                    END IF;

                    --insert into eam_aux3 values ('cfdi '||V_EX,sysdate);
                    --commit;
                    --V_EX := CUST_CFDI_USO_FNC(P_ORIGEN,V_USOCFDI,V_IDREGX);

                    IF P_ORIGEN <> 'INTERCOS'
                    THEN
                        --YPRUSOCFDI  CUST_SAT_USOCFDI_PROV_LKP

                        SELECT COUNT (1)
                          INTO V_COUNT_USOCFDI_PROV
                          FROM FND_LOOKUP_VALUES_VL fv
                         WHERE     1 = 1
                               AND LOOKUP_CODE = V_EMIRFCM
                               AND ENABLED_FLAG = 'Y'
                               AND NVL (END_DATE_ACTIVE, SYSDATE + 1) >=
                                   SYSDATE
                               AND LOOKUP_TYPE = 'CUST_SAT_USOCFDI_PROV_LKP';

                        IF    V_COUNT_USOCFDI_PROV > 0
                           --14122899 Validación uso del CFDI de Anticipos a Proveedores
                           OR V_TIPO_ANT IN
                                  ('PROVEEDORES', 'ANTICIPADO', 'PARCIAL')
                        THEN
                            NULL;
                        ELSE
                            V_EX :=
                                CUST_CFDI_USO_FNC (P_ORIGEN,
                                                   V_USOCFDI,
                                                   p_transaccion_id,
                                                   V_IDREGX);

                            --insert into eam_aux3 values ('cfdi2 '||V_EX,sysdate);
                            --commit;
                            /*    IF V_EX != 'CORRECTO'
                                THEN
                                   V_ERROR_CONCA := V_ERROR_CONCA || V_EX || CHR (10);
                                   V_FLAGVALIDACION := TRUE;
                                END IF;*/

                            -- Las notas de credito se validan en otro pkg.
                            IF v_notacredito = 1
                            THEN
                                V_EX := 'CORRECTO';
                            END IF;

                            IF (V_EX) != 'CORRECTO' AND V_BANDERA = '1'
                            THEN
                                V_ERROR_CONCA :=
                                    V_ERROR_CONCA || V_EX || CHR (10);

                                V_FLAGVALIDACION := TRUE;
                            ELSIF (V_EX) != 'CORRECTO' AND V_BANDERA = '0'
                            THEN
                                --V_WARNING_USOCFDI := V_EX;
                                --V_FLAGVALIDACIONW := TRUE;
                                NULL;
                            END IF;
                        END IF;
                    END IF;
                --insert into eam_aux3 values ('cfdi 3'||V_EX,sysdate);
                --commit;

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        V_RETURN2 := SQLERRM;
                        p_estatus :=
                               'err - al obtener Uso de CFDI '
                            || SUBSTR (V_RETURN2, 1, 60);

                        RETURN;
                END;
            END IF;
        END;

        -- Ticket  13180431 Ingreso de Notas de Crédito a través de WS
        BEGIN
            IF p_origen = 'SP' AND V_TRANSFER_NO_TYPE = 'SN'              --NC
            THEN
                v_msg_notacredito :=
                    XXWEBC.CUST_AP_NC_VALS_FNC (v_idregx, p_transaccion_id);

                IF SUBSTR (v_msg_notacredito, 1, 1) <> '0'
                THEN
                    V_ERROR_CONCA := V_ERROR_CONCA || v_msg_notacredito;
                    V_FLAGVALIDACION := TRUE;
                ELSE
                    --                        V_UUID_RELACIONADO:=SUBSTR (v_msg_notacredito, 3);
                    V_UUID_RELACIONADO :=
                        REGEXP_SUBSTR (v_msg_notacredito,
                                       '[^|]+',
                                       1,
                                       2);
                    V_FACTURA_RELACIONADO :=
                        REGEXP_SUBSTR (v_msg_notacredito,
                                       '[^|]+',
                                       1,
                                       3);

                    UPDATE apps.cust_ap_terceros_h h
                       SET ATTRIBUTE3 =
                                  V_UUID_RELACIONADO
                               || '|'
                               || V_FACTURA_RELACIONADO
                     WHERE TRANSFER_ID = p_transaccion_id;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                v_return2 := SQLERRM;
                p_estatus :=
                       'err - al invocar la función CUST_AP_NC_VALS_FNC '
                    || SUBSTR (v_return2, 1, 60);
                RETURN;
        END;

        -- EDENRED y GASNGO Complemento de Combustible
        BEGIN
            IF P_ORIGEN IN ('ISUPPLIER')
            THEN
                BEGIN
                    SELECT xt.subtotal, xt.total
                      INTO V_subtotalC, V_totalC
                      FROM xxgepp_cust_registro_facturas2  x,
                           XMLTABLE (
                               XMLNAMESPACES (
                                   'http://www.sat.gob.mx/cfd/4' AS "cfdi",
                                   'http://www.sat.gob.mx/TimbreFiscalDigital'
                                       AS "tfd",
                                   'http://www.sat.gob.mx/EstadoDeCuentaCombustible12'
                                       AS "ecc12"),
                               '/cfdi:Comprobante'
                               PASSING x.xml_content
                               COLUMNS subtotal VARCHAR2 (250)
                                           PATH 'cfdi:Complemento/ecc12:EstadoDeCuentaCombustible/@SubTotal',
                                       total VARCHAR2 (250)
                                           PATH 'cfdi:Complemento/ecc12:EstadoDeCuentaCombustible/@Total')
                           xt
                     WHERE REGISTRO_ID = V_IDREGX;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        V_totalC := 0;
                END;

                IF V_totalC <> 0
                THEN
                    BEGIN
                        SELECT DISTINCT ai.invoice_id,
                                        ai.invoice_amount,
                                        ai.TOTAL_TAX_AMOUNT,
                                        INVOICE_CURRENCY_CODE
                          INTO V_invoice_idC,
                               V_invoice_amountC,
                               V_TOTAL_TAX_AMOUNTC,
                               V_INVOICE_CURRENCY_CODEC
                          FROM ap_invoices_all       ai,
                               ap_invoice_lines_all  ail,
                               rcv_transactions      RT
                         WHERE     1 = 1
                               AND AIL.AMOUNT <> 0
                               AND ai.invoice_id = ail.invoice_id
                               AND AIL.RCV_TRANSACTION_ID = RT.TRANSACTION_ID
                               AND RT.SHIPMENT_HEADER_ID = P_Transaccion_ID;
                    EXCEPTION
                        WHEN TOO_MANY_ROWS
                        THEN
                            V_ERROR_CONCA :=
                                   V_ERROR_CONCA
                                || 'El CFDI cuenta con apartado de estado de cuenta combustible, sin embargo no se puede extraer la información de la factura puesto que existe mas de una factura con la recepción relacionada, favor de validar - '
                                || SQLERRM
                                || CHR (10);

                            V_FLAGVALIDACION := TRUE;
                        WHEN OTHERS
                        THEN
                            V_ERROR_CONCA :=
                                   V_ERROR_CONCA
                                || 'El CFDI cuenta con apartado de estado de cuenta combustible, sin embargo no se pudo extraer la información de la factura '
                                || SQLERRM
                                || CHR (10);

                            V_FLAGVALIDACION := TRUE;
                    --RETURN 'Configuracion en la fecha limite del UsoCFDI dentro del lookup '
                    --     || SQLERRM;
                    END;

                    BEGIN
                        SELECT TO_NUMBER (tag)
                          INTO V_TOLERANCIA
                          FROM fnd_lookup_values_vl
                         WHERE     LOOKUP_CODE = V_INVOICE_CURRENCY_CODEC
                               AND ENABLED_FLAG = 'Y'
                               AND lookup_type = 'CUST_AP_IS_TOLERANCIA_LKP'
                               AND (   END_DATE_ACTIVE IS NULL
                                    OR TRUNC (END_DATE_ACTIVE) >=
                                       TRUNC (SYSDATE));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            V_ERROR_CONCA :=
                                   V_ERROR_CONCA
                                || 'Ocurrio un error al obtener la tolerancia para la moneda '
                                || V_INVOICE_CURRENCY_CODEC
                                || ' - '
                                || SQLERRM
                                || CHR (10);

                            V_FLAGVALIDACION := TRUE;
                    END;

                    IF ABS (
                             V_subtotalC
                           - (  NVL (V_invoice_amountC, 0)
                              - NVL (V_TOTAL_TAX_AMOUNTC, 0))) >
                       V_TOLERANCIA
                    THEN
                        V_ERROR_CONCA :=
                               V_ERROR_CONCA
                            || 'Existe variación de importe de: '
                            || ABS (
                                     V_subtotalC
                                   - (  NVL (V_invoice_amountC, 0)
                                      - NVL (V_TOTAL_TAX_AMOUNTC, 0)))
                            || ' sobre el Subtotal de factura VS subtotal CFDI, favor de validar con almacén de entrega o corregir su factura'
                            || CHR (10);

                        V_FLAGVALIDACION := TRUE;
                    END IF;

                    IF ABS (V_totalC - (NVL (V_invoice_amountC, 0))) >
                       V_TOLERANCIA
                    THEN
                        V_ERROR_CONCA :=
                               V_ERROR_CONCA
                            || 'Existe variación de importe de: '
                            || ABS (V_totalC - (NVL (V_invoice_amountC, 0)))
                            || ' sobre el Total de factura VS subtotal CFDI, favor de validar con almacén de entrega o corregir su factura'
                            || CHR (10);

                        V_FLAGVALIDACION := TRUE;
                    END IF;
                END IF;
            END IF;
        END;

        BEGIN
            IF P_ORIGEN IN ('ISUPPLIER')
            THEN
                SELECT COUNT (*)
                  INTO V_COUNTMONEDA
                  FROM rcv_transactions rt, po_headers_all po
                 WHERE     1 = 1
                       AND PO.CURRENCY_CODE <> NVL (V_MONEDAM, 'X')
                       AND po.PO_HEADER_ID = RT.PO_HEADER_ID
                       AND RT.SHIPMENT_HEADER_ID = p_transaccion_id;

                --GROUP BY PO.CURRENCY_CODE;

                --DBMS_OUTPUT.PUT_LINE(V_EXISTE2);

                IF V_COUNTMONEDA > 0
                THEN
                    -- DBMS_OUTPUT.PUT_LINE('ERROR');
                    V_ERROR_CONCA :=
                           V_ERROR_CONCA
                        || 'LA MONEDA DEL CFDI: '
                        || V_MONEDAM
                        || ' NO CORRESPONDE A LA MONEDA DE LA ORDEN DE COMPRA, FAVOR DE VALIDAR'
                        || ' --> '
                        || V_EMIRFCM
                        || CHR (10);
                    V_FLAGVALIDACION := TRUE;
                END IF;
            END IF;

            IF P_ORIGEN IN ('ISUPPLIERC')
            THEN
                SELECT COUNT (*)
                  INTO V_COUNTMONEDA
                  FROM ap_invoices_all ai
                 WHERE     1 = 1
                       AND AI.INVOICE_CURRENCY_CODE <> NVL (V_MONEDAM, 'X')
                       AND AI.INVOICE_ID = p_transaccion_id;

                --GROUP BY AI.INVOICE_CURRENCY_CODE;
                --DBMS_OUTPUT.PUT_LINE(V_EXISTE2);

                IF V_COUNTMONEDA > 0
                THEN
                    -- DBMS_OUTPUT.PUT_LINE('ERROR');
                    V_ERROR_CONCA :=
                           V_ERROR_CONCA
                        || 'LA MONEDA DEL CFDI: '
                        || V_MONEDAM
                        || ' NO CORRESPONDE A LA MONEDA DE LA ORDEN DE COMPRA, FAVOR DE VALIDAR'
                        || ' --> '
                        || V_EMIRFCM
                        || CHR (10);

                    V_FLAGVALIDACION := TRUE;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE ('EXCEPCION 4 ' || SQLERRM);
                V_RETURN2 := SQLERRM;
                p_estatus :=
                       'err - al validar la moneda del CFDI contra lo que se tiene registro en sistema '
                    || SUBSTR (V_RETURN2, 1, 60);

                RETURN;
        END;

        --YPR 22ABR22 YA EXISTE
        BEGIN
            IF P_ORIGEN IN ('ISUPPLIER', 'ISUPPLIERC') AND v_notacredito = 0
            THEN
                V_EX := CUST_IS_CFDI_EXIST_FNC (p_origen, p_transaccion_id);

                -- SOLO TEST - DEV VV
                -- if V_INSTANCIA != 'PROD' then
                    --V_EX := 'CORRECTO';
                -- end if;

                --DBMS_OUTPUT.PUT_LINE(V_EX);
                IF V_EX != 'CORRECTO'
                THEN
                    --DBMS_OUTPUT.PUT_LINE('ERROR');
                    V_ERROR_CONCA := V_ERROR_CONCA || V_EX || CHR (10);
                    V_FLAGVALIDACION := TRUE;
                ELSIF V_EX = 'CORRECTO'
                THEN
                    NULL;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE ('EXCEPCION 4 ' || SQLERRM);
                --V_RETURN2 := SQLERRM;
                V_RETURN2 := SQLCODE;
                p_estatus :=
                       'err - al validar si ya existe el cfdi '
                    || SUBSTR (V_RETURN2, 1, 60);
                RETURN;
        END;

        BEGIN
            --ypr PORTAL RFC 11oct19
            IF P_ORIGEN IN ('PORTAL')
            THEN
                SELECT organization_id
                  INTO V_PORTAL_ORG_ID
                  FROM XLE_FIRSTPARTY_INFORMATION_V  X,
                       HR_ALL_ORGANIZATION_UNITS     B,
                       gl_ledger_norm_seg_vals       G
                 WHERE     G.LEGAL_ENTITY_ID = X.LEGAL_ENTITY_ID
                       AND DECODE (LEGAL_ENTITY_IDENTIFIER,
                                   'SAEG', 'TENOR',
                                   'SAPRO', 'BRTSA',
                                   LEGAL_ENTITY_IDENTIFIER) =
                           B.NAME
                       AND REGISTRATION_NUMBER = V_RECRFCM;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                V_ERROR_CONCA :=
                       V_ERROR_CONCA
                    || 'err - El RFC receptor '
                    || V_RECRFCM
                    || ' no pertenece a ninguna compañia del grupo GEPP, favor de validar'
                    || CHR (10);
                V_FLAGVALIDACION := TRUE;
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE ('EXCEPCION 4 ' || SQLERRM);
                --V_RETURN2 := SQLERRM;
                V_RETURN2 := SQLCODE;
                p_estatus :=
                       'err - al validar el RFC receptor '
                    || SUBSTR (V_RETURN2, 1, 60);
                RETURN;
        END;

        --YPROIE
        v_debug :=
               'Inicia CUST_CFDI_USO_FNC2 '
            || P_ORIGEN
            || ' '
            || V_USOCFDI
            || ' '
            || p_transaccion_id
            || ' '
            || V_IDREGX;

        IF P_ORIGEN IN ('OIE')
        THEN
            BEGIN
                SELECT MEANING, TAG
                  INTO V_DIAS, V_HISTORIAL
                  FROM fnd_lookup_values_vl
                 WHERE     ENABLED_FLAG = 'Y'
                       AND lookup_type = 'CUST_OIE_LIMITE_DIAS_LKP'
                       AND (   END_DATE_ACTIVE IS NULL
                            OR TRUNC (END_DATE_ACTIVE) >= TRUNC (SYSDATE));
            EXCEPTION
                WHEN OTHERS
                THEN
                    V_RETURN2 := SQLERRM;

                    p_estatus :=
                           'err - al obtener los lookups del OIE '
                        || SUBSTR (V_RETURN2, 1, 70);

                    RETURN;
            END;

            v_debug :=
                   'Inicia dias de tolerancia '
                || V_FECHAM
                || ' '
                || V_DIAS
                || ' '
                || P_Transaccion_ID
                || ' '
                || V_UUIDM;

            --,'NLS_DATE_LANGUAGE=ENGLISH'

            IF   TO_DATE (V_FECHAM, 'DD-MM-YY', 'NLS_DATE_LANGUAGE=ENGLISH')
               + TO_NUMBER (V_DIAS) <
               TRUNC (SYSDATE)
            THEN
                v_debug :=
                       'Inicia dias de tolerancia2 '
                    || V_FECHAM
                    || ' '
                    || V_DIAS
                    || ' '
                    || P_Transaccion_ID
                    || ' '
                    || V_UUIDM;

                SELECT COUNT (*)
                  INTO V_COUNT_OIE_PROCESADO
                  FROM APPS.XXEXP_REPORT_HEADERS_ALL       XR,
                       APPS.xxgepp_cust_registro_fact_all  XC --, APPS.XXEXP_EMPLEADOS XE--, fnd_lookup_values_vl FL
                 WHERE     1 = 1
                       --AND XE.EMPLOYEE_ID=XR.EMPLOYEE_ID

                       AND ESTATUS = 'EXITOSO'
                       AND NUM_ID_TRANSACCION = REPORT_HEADER_ID
                       AND REPORT_HEADER_ID = P_Transaccion_ID
                       AND UUID = V_UUIDM;

                v_debug :=
                       'Inicia CUST_CFDI_USO_FNC4 '
                    || P_ORIGEN
                    || ' '
                    || V_USOCFDI
                    || ' '
                    || p_transaccion_id
                    || ' '
                    || V_IDREGX;

                IF V_COUNT_OIE_PROCESADO > 0 AND UPPER (V_HISTORIAL) = 'SI'
                THEN
                    NULL;
                ELSE
                    SELECT COUNT (*)
                      INTO V_COUNT_EMP_DIAS
                      FROM APPS.XXEXP_REPORT_HEADERS_ALL  XR,
                           APPS.XXEXP_EMPLEADOS           XE,
                           fnd_lookup_values_vl           FL
                     WHERE     1 = 1
                           AND FL.MEANING = USER_NAME
                           AND ENABLED_FLAG = 'Y'
                           AND lookup_type = 'CUST_OIE_DIAS_EMP_EXCEP_LKP'
                           AND (   END_DATE_ACTIVE IS NULL
                                OR TRUNC (END_DATE_ACTIVE) >= TRUNC (SYSDATE))
                           AND XE.EMPLOYEE_ID = XR.EMPLOYEE_ID
                           AND REPORT_HEADER_ID = P_Transaccion_ID;

                    IF V_COUNT_EMP_DIAS = 0
                    THEN
                        V_ERROR_CONCA :=
                               V_ERROR_CONCA
                            || 'No puede ser cargado, venció plazo para cargar XML, de acuerdo a política GEPP se tienen '
                            || V_DIAS
                            || ' días a partir de la fecha de emisión para su carga'
                            || CHR (10);

                        V_FLAGVALIDACION := TRUE;
                    END IF;
                END IF;
            END IF;
        END IF;

        -------------------   ASIGNACION DE VARIABLES PARA CONSUMIR EL WS

        BEGIN
            --CAMBIO A OCI
            SELECT APPS.XXGEPP_FND_SESION_FNC INTO V_INSTANCIA FROM DUAL;

            IF V_INSTANCIA = 'PROD'
            THEN
                V_PROD := 'S';
            ELSIF V_INSTANCIA != 'PROD'
            THEN
                V_PROD := 'N';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE ('EXCEPCION 2 ' || SQLERRM);
                V_RETURN2 := SQLERRM;
                p_estatus :=
                    'err - al obtener Instancia' || SUBSTR (V_RETURN2, 1, 60);
                RETURN;
        END;

        BEGIN
            IF P_ORIGEN = 'SP'
            THEN
                V_ORIG := 'W';
            ELSIF P_ORIGEN IN ('OIE', 'PORTAL')
            THEN
                V_ORIG := 'G';
            ELSIF P_ORIGEN IN ('ISUPPLIER', 'ISUPPLIERC')
            THEN
                V_ORIG := 'I';
            ELSIF P_ORIGEN IN ('INTERCOS')
            THEN
                V_ORIG := 'ICE';
            ELSIF P_ORIGEN IN ('N')
            THEN
                V_ORIG := 'N';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE ('EXCEPCION 2 ' || SQLERRM);
                V_RETURN2 := SQLERRM;
                p_estatus :=
                       'err - al obtener y colocar el Origen '
                    || SUBSTR (V_RETURN2, 1, 60);
                RETURN;
        END;

        -- Proceso temporal en transicion de CFDI 3.3 a 4.0 Quitar codigo enero 2024
        -- IF V_VERSIONM = '3.3'
        -- THEN
        --     --            insert into eam_aux3 values ('CFDI40: ', 'entre '|| P_Transaccion_ID  , sysdate);
        --     --            COMMIT;

        --     V_P_XML :=
        --         REPLACE (V_P_XML,
        --                  'xmlns:cfdi="http://www.sat.gob.mx/cfd/4"',
        --                  'xmlns:cfdi="http://www.sat.gob.mx/cfd/3"');

        --     IF NVL (V_USER_ID, 0) = -1
        --     THEN
        --         V_P_XML := REPLACE (V_P_XML, '''', '''''');
        --     ELSE
        --         V_P_XML := REPLACE (V_P_XML, '''''', '''');
        --     END IF;

        --     V_xmltype := XMLTYPE.createxml (V_P_XML);

        --     UPDATE xxgepp_cust_registro_facturas2
        --        SET XML_CONTENT = V_XMLTYPE
        --      WHERE registro_id = V_IDREGX;

        --     COMMIT;
        -- END IF;

        --  FIN PROCESO TEMPORAL de TRANSICION 3.0 a 4.0

        v_debug := 'Inicia F_CUST_CADDENDA_GEPP';

        BEGIN
            IF P_ORIGEN IN ('OIE', 'SP', 'PORTAL')
            THEN
                --inseRt into eam_aux3 values ('RFC 1.1'||V_EMIRFCM,sysdate);
                --COMMIT;
                /*V_FUNCION :=
                   F_CUST_CADDENDA_GEPP (P_ORIGEN,
                                         P_TRANSACCION_ID,
                                         V_IDREGX,
                                         V_EMIRFCM);

               IF V_FUNCION <> 'CORRECTO'
                THEN

                  V_FLAGVALIDACION := TRUE;
                   V_ERROR_CONCA :=
                         V_ERROR_CONCA
                      || ' ERROR EN LA GENERACIÓN DE LA ADDENDA '
                      || V_FUNCION
                      || CHR (10);
                --RETURN  'ERROR EN LA GENERACIÓN DE LA ADDENDA '||V_FUNCION;
                --RAISE RAISE_ADDENDA;
                END IF;  */

                APPS.F_CUST_CADDENDA_GEPP_PRC (P_ORIGEN,
                                               P_TRANSACCION_ID,
                                               V_IDREGX,
                                               V_EMIRFCM,
                                               p_estatus,
                                               P_ADDENDA);
            --inseRt into eam_aux3 values ('X 1.10 ' ||V_IDREGX,sysdate);
            --COMMIT;
            -- DBMS_OUTPUT.PUT_LINE(V_FUNCION||'*******');

            END IF;
        END;

        ----  VALIDACION DE LA BANDERA
        IF V_FLAGVALIDACION = TRUE
        THEN
            UPDATE xxgepp_cust_registro_facturas2
               SET UUID = V_UUIDM,
                   ESTATUS = 'ERROR',
                   NUM_ID_TRANSACCION = p_transaccion_id,
                   MENSAJE_WS = 'err - ' || V_ERROR_CONCA,
                   ATTRIBUTE1 = V_ADVERTENCIA --14122899 Validación uso del CFDI de Anticipos a Proveedores
                                             ,
                   ATTRIBUTE2 = V_USOCFDI
             WHERE REGISTRO_ID = V_IDREGX;

            COMMIT;

            UPDATE xxgepp_cust_registro_fact_all
               SET UUID = V_UUIDM,
                   ESTATUS = 'ERROR',
                   NUM_ID_TRANSACCION = p_transaccion_id,
                   MENSAJE_WS = 'err - ' || V_ERROR_CONCA,
                   ATTRIBUTE1 = V_ADVERTENCIA --14122899 Validación uso del CFDI de Anticipos a Proveedores
                                             ,
                   ATTRIBUTE2 = V_USOCFDI
             WHERE REGISTRO_ID = V_IDREGX;

            COMMIT;

            --  DBMS_OUTPUT.PUT_LINE ('*** Estos son los errores: ***');
            -- DBMS_OUTPUT.PUT_LINE (V_ERROR_CONCA);
            --  DBMS_OUTPUT.PUT_LINE ('*******************************');

            IF V_ADVERTENCIA IS NOT NULL
            THEN                                                     --27FEB22
                p_estatus :=
                    'err - ' || V_ERROR_CONCA || ' AVISO:' || V_ADVERTENCIA;
            ELSE
                p_estatus := 'err - ' || V_ERROR_CONCA;
            END IF;

            RETURN;
        --RAISE NO_FILES;

        END IF;

        DBMS_OUTPUT.PUT_LINE ('V_MEN2 2365 ');

        -- DBMS_OUTPUT.PUT_LINE(V_MEN);
        ---------   TERMINO EN EXITO
        --  DBMS_OUTPUT.PUT_LINE(' AQUI EXITO');

        UPDATE xxgepp_cust_registro_facturas2
           SET UUID = V_UUIDM,
               ESTATUS = 'VALIDADO',
               MENSAJE_WS = V_MEN,
               NUM_ID_TRANSACCION = p_transaccion_id,
               ATTRIBUTE1 = V_ADVERTENCIA --14122899 Validación uso del CFDI de Anticipos a Proveedores
                                         ,
               ATTRIBUTE2 = V_USOCFDI
         WHERE REGISTRO_ID = V_IDREGX;

        COMMIT;

        UPDATE xxgepp_cust_registro_fact_all
           SET UUID = V_UUIDM,
               ESTATUS = 'VALIDADO',
               MENSAJE_WS = V_MEN,
               NUM_ID_TRANSACCION = p_transaccion_id,
               ATTRIBUTE1 = V_ADVERTENCIA --14122899 Validación uso del CFDI de Anticipos a Proveedores
                                         ,
               ATTRIBUTE2 = V_USOCFDI
         WHERE REGISTRO_ID = V_IDREGX;

        COMMIT;

        V_RETURN := V_MEN;                --'PROCESO FINALIZADO EXITOSAMENTE';
        p_estatus := 'EXITOSO';
        P_ID_CONTROL := V_IDREGX;
    --p_estatus := V_RETURN;
    --RETURN V_RETURN;

    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            DBMS_OUTPUT.PUT_LINE ('NO EXISTE');
            V_RETURN2 := SQLERRM;
            p_estatus :=
                   'err - '
                || v_debug
                || ' No EXiste.  '
                || SUBSTR (V_RETURN2, 1, 60);
        WHEN RAISE_ERROR
        THEN
            V_RETURN := 'err -. ' || V_ERROR_CONCA;

            UPDATE xxgepp_cust_registro_facturas2
               SET UUID = V_UUIDM,
                   ESTATUS = 'ERROR',
                   NUM_ID_TRANSACCION = p_transaccion_id,
                   ATTRIBUTE1 = V_ADVERTENCIA
             WHERE REGISTRO_ID = V_IDREGX;

            COMMIT;

            UPDATE xxgepp_cust_registro_fact_all
               SET UUID = V_UUIDM,
                   ESTATUS = 'ERROR',
                   NUM_ID_TRANSACCION = p_transaccion_id,
                   ATTRIBUTE1 = V_ADVERTENCIA
             WHERE REGISTRO_ID = V_IDREGX;

            COMMIT;

            p_estatus := V_RETURN;
        WHEN RAISE_ORIGEN
        THEN
            p_estatus := V_RETURN;
        WHEN RAISE_FECHA
        THEN
            p_estatus := V_RETURN;
        WHEN RAISE_ADDENDA
        THEN
            p_estatus := V_RETURN;
        WHEN NO_FILES
        THEN
            ROLLBACK;

            DBMS_OUTPUT.PUT_LINE ('FIN DE PROCESO');
            apps.fnd_file.put_line (fnd_file.output, ' ');
            apps.fnd_file.put_line (fnd_file.output, ' ');
            apps.fnd_file.put_line (
                fnd_file.output,
                LPAD ('*****Proceso Finalizado Error*****', 70, ' '));
            V_RETURN2 := SQLERRM;

            p_estatus := 'err - NO_FILES ' || SUBSTR (V_RETURN2, 1, 60);
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.PUT_LINE ('NO EXISTE');
            V_RETURN2 := SQLERRM;
            p_estatus :=
                ' err -.. ' || v_debug || ' ' || SUBSTR (V_RETURN2, 1, 60);
    END valida_y_addenda;
    
    FUNCTION consume_ws_v2 (xsd_ws CLOB,p_registro_id number)            
    RETURN VARCHAR2
    IS
    RESULTADOM            VARCHAR2 (2000);
    v_msg clob;
    v_result varchar2(3000);
    V_RESPONSETYPE        XMLTYPE;
    v_pathServer varchar2(100):='/u07/cargas/ap/validacfdi/';
    v_depurar varchar2(1):='Y';
    begin
--        select validador_facturas_ws(xsd_ws) into v_msg from dual;
        
        v_msg:=CONVERT(validador_facturas_ws(xsd_ws,v_pathServer,v_depurar),'WE8ISO8859P1','UTF8');
        
        V_RESPONSETYPE := XMLTYPE.createxml (v_msg);
        
        with 
        t_response
            AS (        
        select EXTRACTVALUE (V_RESPONSETYPE,'//ValidarResult','xmlns="http://www.gepp.com.mx/ValidaFacturaGEPPV/') AS result from dual)
        select CASE
                     WHEN SUBSTR (result, 1, 5) = '<?xml'
                     THEN
                         REGEXP_REPLACE (
                             EXTRACT (XMLTYPE (result), '//mensaje'),
                             '</?mensaje>',
                             '')
                     ELSE
                         result 
                 END    Mensaje into v_result from t_response;                                   
        
        -- update xxgepp_cust_registro_facturas3
        --  set response=V_RESPONSETYPE, mensaje_ws=v_result
        -- where registro_id=p_registro_id;
        
        RETURN v_msg;
        
    exception when others then
        null;
    end consume_ws_v2;
    
    FUNCTION valida_cfdi (p_origen           VARCHAR2,
                          P_BASE64           CLOB,
                          P_Transaccion_ID   NUMBER,
                          P_ID_CONTROL       NUMBER)
        RETURN VARCHAR2
    IS
        V_RETURN              VARCHAR2 (32000);
        V_RETURN2             VARCHAR2 (2000);
        
        NO_FILES              EXCEPTION;
        V_FLAGVALIDACION      BOOLEAN := FALSE;
        V_ERROR_CONCA         CLOB;

        -- V_URLM                VARCHAR2 (200);
        -- V_WALLET_PATH         VARCHAR2 (200);
        -- V_WALLET_PASS         VARCHAR2 (200);
        RESULTADOM            VARCHAR2 (2000);

        V_CONCANUEVAM         CLOB;

        V_RESPONSETYPE        XMLTYPE;
        V_SOAP                CLOB := NULL;
        V_MEN                 VARCHAR2 (32000);
        V_REG                 VARCHAR2 (1000);
        RAISE_ERROR           EXCEPTION;
        RAISE_ADDENDA         EXCEPTION;

        RAISE_ORIGEN          EXCEPTION;
        RAISE_FECHA           EXCEPTION;

        V_PROD                VARCHAR2 (10);
        V_ORIG                VARCHAR2 (10);
        V_INSTANCIA           VARCHAR2 (10);

        v_debug               VARCHAR2 (3000);

        V_ADVERTENCIA_FINAL   CLOB;
        V_NOTACREDITO_MSG     CLOB;
        v_ai_invoice_id       NUMBER;

        V_WS_SEL              NUMBER;
        
    BEGIN
        BEGIN
            --CAMBIO A OCI
            SELECT APPS.XXGEPP_FND_SESION_FNC INTO V_INSTANCIA FROM DUAL;

            BEGIN
                SELECT ATTRIBUTE1
                  INTO V_ADVERTENCIA_FINAL
                  FROM xxgepp_cust_registro_fact_all
                 WHERE REGISTRO_ID = P_ID_CONTROL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    V_ADVERTENCIA_FINAL := NULL;
            END;

            IF V_INSTANCIA = 'PROD'
            THEN
                V_PROD := 'S';
            ELSIF V_INSTANCIA != 'PROD'
            THEN
                V_PROD := 'N';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE ('EXCEPCION 2 ' || SQLERRM);
                V_RETURN2 := SQLERRM;
                RETURN    'Error al obtener Instancia'
                       || SUBSTR (V_RETURN2, 1, 60);
        END;

        BEGIN
            IF P_ORIGEN = 'SP'
            THEN
                V_ORIG := 'W';
            --     ELSIF P_ORIGEN IN ('OIE', 'PORTAL')
            ELSIF P_ORIGEN IN ('OIE')
            THEN
                V_ORIG := 'G';
            ELSIF P_ORIGEN IN ('PORTAL') --YPR 14ENE19 PARA QUE TOME LA ADDENDA PORTAL EXTERNO
            THEN
                --V_ORIG := 'N';
                V_ORIG := 'SDO';
            ELSIF P_ORIGEN IN ('ISUPPLIER', 'ISUPPLIERC', 'NOTACREDITO')
            THEN
                V_ORIG := 'I';
            ELSIF P_ORIGEN IN ('INTERCOS')
            THEN
                V_ORIG := 'ICE';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.PUT_LINE ('EXCEPCION 2 ' || SQLERRM);
                V_RETURN2 := SQLERRM;
                RETURN    'Error al obtener y colocar el Origen '
                       || SUBSTR (V_RETURN2, 1, 60);
        END;

        BEGIN
            -- Seleccion del Webservice o CURL para consumo
            SELECT MEANING
              INTO V_WS_SEL
              FROM fnd_lookup_values_vl
             WHERE     ENABLED_FLAG = 'Y'
                   AND lookup_type = 'CUST_FND_WALLET_CFDI'
                   AND lookup_code = 20
                   AND (   END_DATE_ACTIVE IS NULL
                        OR TRUNC (END_DATE_ACTIVE) > TRUNC (SYSDATE));
        EXCEPTION
            WHEN OTHERS
            THEN
                V_FLAGVALIDACION := TRUE;

                V_ERROR_CONCA :=
                       V_ERROR_CONCA
                    || ' Error en la obtención del lookup CUST_FND_WALLET_CFDI code 20'
                    || SQLERRM;

                V_RETURN2 := SQLERRM;

                RETURN    'Error en la obtención del lookup CUST_FND_WALLET_CFDI code 20 '
                       || SUBSTR (V_RETURN2, 1, 60);
        END;

        V_CONCANUEVAM :=
               '<?xml version="1.0" encoding="utf-8"?>
                                            <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
                                              <soap:Body>
                                                <Validar xmlns="http://www.gepp.com.mx/ValidaFacturaGEPPV/">
                                                  <Comprobante>'
            --|| V_XMLBASE64GLM
            || P_BASE64
            || '</Comprobante>
                                                  <esProduccion>'
            || V_PROD
            || '</esProduccion>
                                                  <Origen>'
            || V_ORIG
            || '</Origen>
                                                  <Parametro></Parametro>
                                                </Validar>
                                              </soap:Body>
                                            </soap:Envelope>';

        --DBMS_OUTPUT.PUT_LINE ('resultado  23423523454235asdasd ' || ' | ' || RESULTADOM);
        --DBMS_OUTPUT.PUT_LINE ('resultado ' || V_XMLBASE64GLM);
        --   DBMS_OUTPUT.PUT_LINE('2.0');

        --DBMS_OUTPUT.PUT_LINE ('test3');

        if V_WS_SEL = 1 then 
            -- Invoca Webservice con PAEBSA.
            RESULTADOM := xxgepp_cust_reglas_val_fac.consume_ws (V_CONCANUEVAM);
        elsif V_WS_SEL = 2 THEN
            -- Invoca Nuevo Webservice Local Gepp via CURL
            RESULTADOM := consume_ws_v2 (V_CONCANUEVAM, P_ID_CONTROL);
        elsif V_WS_SEL = 3 THEN
            -- Consumir ambos para poblar el portal viejo.
            RESULTADOM := xxgepp_cust_reglas_val_fac.consume_ws (V_CONCANUEVAM);
            RESULTADOM := consume_ws_v2 (V_CONCANUEVAM, P_ID_CONTROL);
        else
            RESULTADOM := consume_ws_v2 (V_CONCANUEVAM, P_ID_CONTROL);
        end if;
        
        -- DBMS_OUTPUT.PUT_LINE ('resultado  del consumo de WS: ' || ' | ' || RESULTADOM);
        v_debug := 'Inicia V_RESPONSETYPE';
        V_RESPONSETYPE := XMLTYPE.createxml (RESULTADOM);
        v_debug := 'Finaliza V_RESPONSETYPE';

        UPDATE xxgepp_cust_registro_facturas2
           SET RESPONSE = V_RESPONSETYPE, XML_BASE64 = P_BASE64
         WHERE REGISTRO_ID = P_ID_CONTROL;                       --- V_IDREGX;

        COMMIT;

        v_debug := 'Actualiza respuesta P_BASE64';

        WITH
            t_response
            AS
                (SELECT registro_id,
                        EXTRACTVALUE (
                            response,
                            '//ValidarResult',
                            'xmlns="http://www.gepp.com.mx/ValidaFacturaGEPPV/')    AS result
                   FROM xxgepp_cust_registro_facturas2)
          SELECT registro_id,
                 CASE
                     WHEN SUBSTR (result, 1, 5) = '<?xml'
                     THEN
                         REGEXP_REPLACE (
                             EXTRACT (XMLTYPE (result), '//mensaje'),
                             '</?mensaje>',
                             '')
                     ELSE
                         result
                 END    Mensaje
            INTO V_REG, V_MEN
            FROM t_response
           WHERE registro_id = p_id_control
        ---V_IDREGX

        ORDER BY registro_id;

        --DBMS_OUTPUT.PUT_LINE ('V_MEN ' || V_MEN);
        v_debug := 'Termina t_response';

        --DBMS_OUTPUT.PUT_LINE ('V_MEN1 ');

        -- Para forzar el proceso sin importar que arroje la validacion del Webservice.
--                IF P_ORIGEN IN ('ISUPPLIER', 'ISUPPLIERC', 'NOTACREDITO') 
                    --  AND V_INSTANCIA != 'PROD'
                    -- THEN
--                    V_MEN := 'CFDI Valido';
--                END IF;

        IF NVL (V_MEN, 'X') != 'CFDI Valido'
        --IF V_MEN  != 'CFDI Valido'

        THEN
            DBMS_OUTPUT.PUT_LINE ('V_MEN1.1 ' || V_ERROR_CONCA);
            --   DBMS_OUTPUT.PUT_LINE('AQUI ERROR 1');
            V_FLAGVALIDACION := TRUE;
            V_ERROR_CONCA :=
                   V_ERROR_CONCA
                || 'ERROR EN EL Web Service --> '
                || V_MEN
                || CHR (10);

            DBMS_OUTPUT.PUT_LINE ('V_MEN1.2 ' || V_ERROR_CONCA);

            UPDATE xxgepp_cust_registro_facturas2
               SET ESTATUS = 'ERROR',
                   MENSAJE_WS = 'err - ' || V_MEN,
                   NUM_ID_TRANSACCION = p_transaccion_id
             WHERE REGISTRO_ID = P_ID_CONTROL;                     --V_IDREGX;

            DBMS_OUTPUT.PUT_LINE ('V_MEN1.3 ' || V_ERROR_CONCA);

            COMMIT;

            UPDATE xxgepp_cust_registro_fact_all
               SET ESTATUS = 'ERROR',
                   MENSAJE_WS = 'err - ' || V_MEN,
                   NUM_ID_TRANSACCION = p_transaccion_id
             WHERE REGISTRO_ID = P_ID_CONTROL;                     --V_IDREGX;

            DBMS_OUTPUT.PUT_LINE ('V_MEN1.4 ' || V_ERROR_CONCA);

            COMMIT;

            --  DBMS_OUTPUT.PUT_LINE('AQUI ERROR 2'||' '||V_IDREGX);
            /*   IF P_ORIGEN<>'OIE' THEN
                RAISE RAISE_ERROR;
                ELSE
                RETURN 'CFDI Valido';
                END IF; */


            -- DESCOMENTAR PARA PRUEBAS E IGNORAR LOS ERRORES. VV
            --                           IF P_ORIGEN = 'ISUPPLIER' THEN
            --                           RAISE RAISE_ERROR;
            --ELSE
            --RETURN 'CFDI Valido';
            --END IF;


            RAISE RAISE_ERROR;
        END IF;

        --    EXCEPTION
        --           WHEN OTHERS
        --           THEN
        --           DBMS_OUTPUT.PUT_LINE(SQLERRM);
        --           DBMS_OUTPUT.PUT_LINE('EXCEPCION CFDI VALIDO   '||V_IDREGX||'  '||SQLERRM);
        --      END;

        DBMS_OUTPUT.PUT_LINE ('V_MEN2 2967 ');

        -- **************************************************************************************
        -- Envio de Notas de Credito a la Interfaz.
        -- **************************************************************************************


        BEGIN

--@TODO VV agregar el lookup para verificar que sea PEPSICO. Invertir la logica.
-- Si esta en el lookup crea la nota en la interfaz.

    -- SELECT COUNT (fl.lookup_code)
    --   INTO v_RFCpermitido 
    -- FROM apps.fnd_lookup_values_vl fl
    -- WHERE     1 = 1
    --    AND fl.lookup_type = 'XX_ISUPPLIER_NC_ACCESO'
    --    AND fl.enabled_flag = 'Y'
    --    AND fl.lookup_code = xmlRFCEmisor;

    -- if v_RFCpermitido = 0 then 
    --     v_mensaje := v_mensaje || ' No autorizado para carga de Notas de Crédito, haga llegar el XML y PDF a su comprador y/o contacto de almacén, quienes se encargarán de realizar el proceso interno. ';
    --     v_error := 1;
    -- END IF;


            IF p_origen = 'NOTACREDITO'
            THEN
                SELECT DISTINCT (ai.invoice_id)
                  INTO v_ai_invoice_id
                  FROM rcv_transactions      rt,
                       ap_invoice_lines_all  ail,
                       ap_invoices_all       ai
                 WHERE     1 = 1
                       AND rt.shipment_header_id = P_Transaccion_ID -- 21777119
                       AND ail.rcv_transaction_id = rt.transaction_id
                       AND ai.invoice_id = ail.invoice_id
                       AND apps.ap_invoices_pkg.get_approval_status (
                               ai.invoice_id,
                               ai.invoice_amount,
                               ai.payment_status_flag,
                               ai.invoice_type_lookup_code) = 'APPROVED';

                -- INICIO Ticket de NC no liberado.
                -- BEGIN
                --     select distinct ( ai.invoice_id )
                --         into v_ai_invoice_id
                --         from rcv_transactions rt,
                --             ap_invoice_lines_all ail,
                --             ap_invoices_all ai,
                --             apps.fnd_lookup_values_vl fl,
                --             ap_suppliers aps
                --         where 1 = 1
                --         and rt.shipment_header_id = P_Transaccion_ID -- 21777119, 23748734
                --         and ail.rcv_transaction_id = rt.transaction_id
                --         and ai.source = 'ERS'
                --         and ai.invoice_id = ail.invoice_id
                --         and fl.lookup_type = 'XX_ISUPPLIER_NC_ACCESO'
                --         and ai.vendor_id = aps.vendor_id
                --         and fl.enabled_flag = 'Y'
                --         and fl.lookup_code = aps.num_1099 --P_RFCEmisor
                --         and apps.ap_invoices_pkg.get_approval_status(
                --                                                 ai.invoice_id,
                --                                                 ai.invoice_amount,
                --                                                 ai.payment_status_flag,
                --                                                 ai.invoice_type_lookup_code) = 'APPROVED';
                -- EXCEPTION
                --     WHEN NO_DATA_FOUND
                --     THEN NULL;
                --     WHEN TOO_MANY_ROWS
                --     THEN
                --         V_ADVERTENCIA_FINAL :=
                --                v_error_conca
                --             || ' err - Más de una factura relacionada a la transacción, favor de contactar a su comprador y/o contacto de almacén. ';
                --         RAISE RAISE_ERROR;                            
                -- END;
                -- if v_ai_invoice_id is not null then
                -- FIN Ticket de NC no liberado.

                    XXWEBC.CUST_AP_CREACION_NC_PRC (P_ID_CONTROL,
                                                P_Transaccion_ID,
                                                v_ai_invoice_id,
                                                V_NOTACREDITO_MSG);

                --        INSERT INTO APPS.EAM_AUX3 VALUES ('Linea3045: ', 'datos ' || V_NOTACREDITO_MSG, SYSDATE);
                --        COMMIT;

                    IF REGEXP_SUBSTR (V_NOTACREDITO_MSG,
                                    '[^|]+',
                                    1,
                                    1) = '1'
                    THEN
                        --                INSERT INTO APPS.EAM_AUX3 VALUES ('Entre if: ', 'datos ' || P_Transaccion_ID || ' ' || P_ID_CONTROL, SYSDATE);
                        --        COMMIT;
                        V_ADVERTENCIA_FINAL :=
                            v_error_conca
                            || REGEXP_SUBSTR (V_NOTACREDITO_MSG,
                                            '[^|]+',
                                            1,
                                            2);

                        RAISE RAISE_ERROR;
                    END IF;
                -- END IF;    
            END IF;
        END;


        -- DBMS_OUTPUT.PUT_LINE(V_MEN);
        ---------   TERMINO EN EXITO
        --  DBMS_OUTPUT.PUT_LINE(' AQUI EXITO');

        UPDATE xxgepp_cust_registro_facturas2
           SET                                               --UUID = V_UUIDM,
               ESTATUS = 'EXITOSO',
               MENSAJE_WS = V_MEN,
               NUM_ID_TRANSACCION = p_transaccion_id
         WHERE REGISTRO_ID = P_ID_CONTROL;                         --V_IDREGX;

        COMMIT;

        UPDATE xxgepp_cust_registro_fact_all
           SET                                              ---UUID = V_UUIDM,
               ESTATUS = 'EXITOSO',
               MENSAJE_WS = V_MEN,
               NUM_ID_TRANSACCION = p_transaccion_id
         WHERE REGISTRO_ID = P_ID_CONTROL;                         --V_IDREGX;

        COMMIT;

        IF V_ADVERTENCIA_FINAL IS NOT NULL
        THEN
            V_RETURN := V_MEN || ' AVISO:' || V_ADVERTENCIA_FINAL; --'PROCESO FINALIZADO EXITOSAMENTE'; 27FEB22
        ELSE
            V_RETURN := V_MEN;
        END IF;



        RETURN V_RETURN;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            DBMS_OUTPUT.PUT_LINE ('NO EXISTE');

            V_RETURN2 := SQLERRM;

            RETURN 'No existe  ' || SUBSTR (V_RETURN2, 1, 60);
        WHEN RAISE_ERROR
        THEN
            IF V_ADVERTENCIA_FINAL IS NOT NULL
            THEN                                                     --27FEB22
                V_RETURN :=
                       'err -. '
                    || V_ERROR_CONCA
                    || ' AVISO:'
                    || V_ADVERTENCIA_FINAL;
            ELSE
                V_RETURN := 'err -. ' || V_ERROR_CONCA;
            END IF;

            UPDATE xxgepp_cust_registro_facturas2
               SET                                          ---UUID = V_UUIDM,
                   ESTATUS = 'ERROR', NUM_ID_TRANSACCION = p_transaccion_id
             WHERE REGISTRO_ID = P_ID_CONTROL;                     --V_IDREGX;

            COMMIT;

            UPDATE xxgepp_cust_registro_fact_all
               SET                                          ---UUID = V_UUIDM,
                   ESTATUS = 'ERROR', NUM_ID_TRANSACCION = p_transaccion_id
             WHERE REGISTRO_ID = P_ID_CONTROL;                     --V_IDREGX;

            COMMIT;

            RETURN V_RETURN;
        WHEN RAISE_ORIGEN
        THEN
            RETURN V_RETURN;
        WHEN RAISE_FECHA
        THEN
            RETURN V_RETURN;
        WHEN RAISE_ADDENDA
        THEN
            RETURN V_RETURN;
        WHEN NO_FILES
        THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE ('FIN DE PROCESO');
            apps.fnd_file.put_line (fnd_file.output, ' ');
            apps.fnd_file.put_line (fnd_file.output, ' ');
            apps.fnd_file.put_line (
                fnd_file.output,
                LPAD ('*****Proceso Finalizado Error*****', 70, ' '));
            V_RETURN2 := SQLERRM;
            RETURN 'Error NO_FILES ' || SUBSTR (V_RETURN2, 1, 60);
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.PUT_LINE ('NO EXISTE');
            V_RETURN2 := SQLERRM;
            RETURN ' err -.. ' || v_debug || ' ' || SUBSTR (V_RETURN2, 1, 60);
    END valida_cfdi;


   -- 3/nov/2025  Se comenta funcion valida_mat dejo de ser operativa.
   -- Quitar el codigo en Julio 2026


    FUNCTION valida_mat (p_origen           VARCHAR2,
                         P_XML              CLOB,
                         P_Transaccion_ID   NUMBER)
        RETURN VARCHAR2
    IS

    -- Esta seccion es para regresar NULL debido a que algunos PKG todavia la usan
    BEGIN
        RETURN NULL;
    END valida_mat;
    -- FIN sesccion es para regresar NULL debido a que algunos PKG todavia la usan

    --     V_RETURN              VARCHAR2 (32000);
    --     V_RETURN2             VARCHAR2 (2000);
    --     V_RETURN_EXC          VARCHAR2 (1000);
    --     v_mensaje             apps.xxgepp_cust_registro_facturas.mensaje_ws%TYPE;
    --     NO_FILES              EXCEPTION;
    --     V_EX                  VARCHAR2 (1000);
    --     V_EX2                 NUMBER := 0;
    --     V_FLAGVALIDACION      BOOLEAN := FALSE;
    --     V_EXISTE2             VARCHAR2 (1000);
    --     V_EXISTE3             NUMBER := 0;
    --     V_ERROR_CONCA         CLOB;
    --     V_FUNCION             VARCHAR2 (1000);
    --     V_CUENTA_UUID         NUMBER := 0;
    --     V_TRANSFER_NO         VARCHAR2 (100);

    --     ----------------
    --     --V_URLM         VARCHAR2(100) :=  'https://cfditaxshield.gepp.com/servicios/ws1/service.asmx';
    --     V_URLM                VARCHAR2 (200);
    --     V_WALLET_PATH         VARCHAR2 (200);
    --     V_WALLET_PASS         VARCHAR2 (200);
    --     RESULTADOM            VARCHAR2 (2000);
    --     V_XMLCONTENTGLM       CLOB;
    --     V_XMLCONTENTGLMB      BLOB;
    --     V_XMLBASE64GLM        CLOB;
    --     V_CONCANUEVAM         CLOB;
    --     V_VALCFDI             CLOB;
    --     --VARIABLES PARA ATRIBUTOS XML
    --     V_ERROR_CONCAM        CLOB;
    --     V_INVOICEIDM          VARCHAR2 (50);
    --     --V_VERSIONM         NUMBER;
    --     V_VERSIONM            VARCHAR2 (50);
    --     V_SERIEM              VARCHAR2 (2);
    --     V_FOLIOM              VARCHAR2 (50);
    --     V_FECHAM              VARCHAR2 (75);
    --     V_FECHAMP             VARCHAR2 (75);
    --     ------------------------------------
    --     V_SELLOM              VARCHAR2 (500);
    --     V_FORMAPAGOM          VARCHAR2 (100);
    --     V_NUMCERM             VARCHAR2 (50);
    --     V_CERTIFICADOM        VARCHAR2 (1000);
    --     V_CONDICIONESM        VARCHAR2 (1000);
    --     ---------------------------------
    --     V_SUBTOTALM           VARCHAR2 (50);
    --     V_DESCUENTOM          VARCHAR2 (50);
    --     V_MONEDAM             VARCHAR2 (500);
    --     V_TOTALM              VARCHAR2 (50);
    --     V_METODOPAGOM         VARCHAR2 (100);
    --     V_TIPOCOMPROM         VARCHAR2 (100);
    --     V_LUGARM              VARCHAR2 (1000);
    --     ---------------------------------
    --     V_EMIRFCM             VARCHAR2 (100);
    --     V_EMINOMBREM          VARCHAR2 (100);
    --     V_EMICALLEM           VARCHAR2 (100);
    --     V_EMINUMEXTM          VARCHAR2 (500);
    --     V_EMINUMINTM          VARCHAR2 (500);
    --     V_EMICOLONIAM         VARCHAR2 (1000);
    --     V_EMIMUNICIPIOM       VARCHAR2 (1000);
    --     V_EMIESTADOM          VARCHAR2 (1000);
    --     V_EMIPAISM            VARCHAR2 (1000);
    --     V_EMICPM              VARCHAR2 (1000);
    --     -------------------------------
    --     V_EXPRFCM             VARCHAR2 (100);
    --     V_EXPNOMBREM          VARCHAR2 (100);
    --     V_EXPCPM              VARCHAR2 (100);
    --     V_REGIMENM            VARCHAR2 (100);
    --     --        --------------------------------
    --     V_RECRFCM             VARCHAR2 (100);
    --     V_IVAM                NUMBER;
    --     V_RETENCIONM          NUMBER := 0;
    --     V_UUIDM               VARCHAR2 (250);
    --     V_LUUIDM              VARCHAR2 (50);
    --     V_BASE64              CLOB;
    --     V_XMLTYPE             XMLTYPE;
    --     V_IDREGX              NUMBER;
    --     V_RESPONSETYPE        XMLTYPE;
    --     V_SOAP                CLOB := NULL;
    --     V_MEN                 VARCHAR2 (32000);
    --     V_REG                 VARCHAR2 (1000);
    --     RAISE_ERROR           EXCEPTION;
    --     RAISE_ADDENDA         EXCEPTION;
    --     V_CUENTA              NUMBER := 0;
    --     RAISE_ORIGEN          EXCEPTION;
    --     RAISE_FECHA           EXCEPTION;
    --     V_FECHAL              VARCHAR2 (50);
    --     V_FECHAC              DATE;
    --     V_CUENTAVERSION       NUMBER := 0;
    --     V_CUENTAFECHA         NUMBER := 0;
    --     V_PROD                VARCHAR2 (10);
    --     V_ORIG                VARCHAR2 (10);
    --     V_INSTANCIA           VARCHAR2 (10);
    --     V_VAR                 VARCHAR2 (100) := '';
    --     V_P_XML               CLOB;
    --     V_USOCFDI             VARCHAR2 (1000);
    --     V_ERROR               VARCHAR2 (10000);
    --     VFECHAuso             DATE;
    --     V_WARNING_USOCFDI     VARCHAR2 (100);
    --     V_BANDERA             VARCHAR2 (100);
    --     v_debug               VARCHAR2 (3000);
    --     v_user_id             NUMBER;
    --     V_ADVERTENCIA         CLOB;
    --     V_ADVERTENCIA_FINAL   CLOB;

    --     PROCEDURE sp_ObtenerBase (p_registro_id NUMBER)
    --     IS
    --         V_XMLBASE64    CLOB;

    --         V_XMLCONTENT   XMLTYPE;
    --     BEGIN
    --         SELECT XML_CONTENT --,                                    XML_BASE64
    --           INTO V_XMLCONTENT --                                  ,V_XMLBASE64GLM
    --           FROM xxgepp_cust_registro_facturas2
    --          WHERE REGISTRO_ID = P_REGISTRO_ID; --ACA VA LA SECUENCIA CONSUMIDA

    --         V_XMLCONTENTGLM := V_XMLCONTENT.getClobVal ();

    --         UPDATE XXAP_PRUEBA
    --            SET TEXTO = V_XMLCONTENTGLM
    --          WHERE REGISTRO = V_IDREGX;

    --         COMMIT;

    --         BEGIN
    --             SELECT TEXTO
    --               INTO V_XMLCONTENTGLM
    --               FROM XXAP_PRUEBA
    --              WHERE REGISTRO = V_IDREGX;
    --         EXCEPTION
    --             WHEN OTHERS
    --             THEN
    --                 NULL;
    --         END;

    --         /*V_BASE64 :=
    --            UTL_ENCODE.text_encode (V_XMLCONTENTGLM,
    --                                    -- UTL_ENCODE.text_encode (P_XML,
    --                                    'AL32UTF8',
    --                                    UTL_ENCODE.BASE64);
    --         */
    --         V_BASE64 := CUST_EncodeBASE64_FNC (V_XMLCONTENTGLM);
    --         --V_XMLCONTENTGLMB := V_XMLCONTENT.getBlobVal ();
    --         -- V_XMLCONTENTGLMB:=clob2blob(V_XMLCONTENTGLM);
    --         -- V_BASE64:=base64EncodeBlob_plsql(V_XMLCONTENTGLMB);
    --         --   V_BASE64  :=APPS.EncodeBASE64(V_XMLCONTENTGLM);
    --         --V_XMLBASE64GLM := V_BASE64;
    --         V_XMLBASE64GLM := V_BASE64;
    --     EXCEPTION
    --         WHEN OTHERS
    --         THEN
    --             BEGIN
    --                 V_BASE64 :=
    --                     APPS.CUST_ENCODEBASE64_fnc (
    --                         REPLACE (REPLACE ((V_XMLCONTENTGLM), CHR (10)),
    --                                  CHR (13)));

    --                 V_XMLBASE64GLM := V_BASE64;
    --             EXCEPTION
    --                 WHEN OTHERS
    --                 THEN
    --                     V_ERROR := SQLERRM;

    --                     V_ERROR_CONCA :=
    --                            V_ERROR_CONCA
    --                         || 'Error en transformar a BASE64 '
    --                         || V_ERROR;

    --                     V_FLAGVALIDACION := TRUE;
    --             END;
    --     -- || SUBSTR (V_RETURN2, 1, 60);
    --     -- DBMS_OUTPUT.PUT_LINE ('EXCEPCION' || SQLERRM);
    --     END;

    --     FUNCTION consume_ws (xsd_ws CLOB, v_url_ws VARCHAR2)
    --         RETURN VARCHAR2
    --     IS
    --         soap_request   CLOB;
    --         soap_respond   CLOB;
    --         i              INTEGER;
    --         http_req       UTL_HTTP.req;
    --         http_resp      UTL_HTTP.resp;
    --         l_http_req     UTL_HTTP.req;
    --         v_code         VARCHAR2 (1000);
    --         v_mensaje      VARCHAR2 (4000);
    --         ocode          VARCHAR2 (1000);
    --         omensaje       VARCHAR2 (4000);
    --     BEGIN
    --         BEGIN
    --             SELECT MEANING, description, tag
    --               INTO V_WALLET_PATH, V_URLM, V_WALLET_PASS
    --               FROM fnd_lookup_values_vl
    --              WHERE     ENABLED_FLAG = 'Y'
    --                    AND lookup_type = 'CUST_FND_WALLET_CFDI'
    --                    AND lookup_code = 10
    --                    AND (   END_DATE_ACTIVE IS NULL
    --                         OR TRUNC (END_DATE_ACTIVE) > TRUNC (SYSDATE));
    --         EXCEPTION
    --             WHEN OTHERS
    --             THEN
    --                 ocode := '1';
    --                 omensaje :=
    --                        'err - En la obtención del lookup CUST_FND_WALLET_CFDI '
    --                     || SQLERRM;
    --         END;

    --         --DBMS_OUTPUT.PUT_LINE('1.2');
    --         soap_request := xsd_ws;
    --         --DBMS_OUTPUT.PUT_LINE('1.3');
    --         --      message_log(soap_request);
    --         --DBMS_OUTPUT.PUT_LINE (soap_request);
    --         --        message_log('url_ws:' || url_ws);
    --         --       DBMS_OUTPUT.PUT_LINE ('TEST');
    --         UTL_HTTP.SET_WALLET (V_WALLET_PATH, V_WALLET_PASS);
    --         -- DBMS_OUTPUT.PUT_LINE('1.4');
    --         http_req := UTL_HTTP.begin_request (v_url_ws, 'POST');
    --         DBMS_OUTPUT.PUT_LINE ('1.3');
    --         --  DBMS_OUTPUT.PUT_LINE ('1.5');
    --         /*El contenido que enviamos es XML: */
    --         UTL_HTTP.set_header (http_req,
    --                              'Content-Type',
    --                              'text/xml; charset=UTF-8');

    --         /*Establecemos el SOAPAction a invocar: */
    --         UTL_HTTP.set_header (
    --             http_req,
    --             'SOAPAction',
    --             '"http://www.gepp.com.mx/ValidaFacturaGEPPV/Validar"');  --ypr

    --         /*Indicamos en el header el tamano del mensaje enviado: */
    --         UTL_HTTP.set_header (http_req,
    --                              'Content-Length',
    --                              LENGTH (soap_request));

    --         /*Escribimos el body del request */
    --         DECLARE
    --             req_length   BINARY_INTEGER;
    --             offset       PLS_INTEGER := 1;
    --             amount       PLS_INTEGER := 2000;
    --             BUFFER       VARCHAR2 (2000);
    --         BEGIN
    --             DBMS_OUTPUT.PUT_LINE ('1.4');
    --             req_length := DBMS_LOB.GETLENGTH (soap_request);

    --             IF req_length <= 32767
    --             THEN
    --                 UTL_HTTP.write_text (http_req, soap_request);
    --             ELSE
    --                 UTL_HTTP.set_header (http_req,
    --                                      'Transfer-Encoding',
    --                                      'chunked');

    --                 WHILE (offset < req_length)
    --                 LOOP
    --                     DBMS_LOB.READ (soap_request,
    --                                    amount,
    --                                    offset,
    --                                    BUFFER);
    --                     UTL_HTTP.write_text (http_req, BUFFER);
    --                     offset := offset + amount;
    --                 END LOOP;
    --             END IF;
    --         EXCEPTION
    --             WHEN OTHERS
    --             THEN
    --                 DBMS_OUTPUT.PUT_LINE ('EXCEPCION' || SQLERRM);
    --         END;

    --         /*Obtenemos la respuesta */
    --         http_resp := UTL_HTTP.get_response (http_req);

    --         --http_resp
    --         BEGIN
    --             LOOP
    --                 UTL_HTTP.read_text (http_resp, soap_respond);
    --                 V_SOAP := V_SOAP || SOAP_RESPOND;
    --             --DBMS_OUTPUT.put_line (soap_respond);
    --             --DBMS_OUTPUT.put_line ('$$$$|||'||V_SOAP);
    --             END LOOP;
    --         EXCEPTION
    --             WHEN UTL_HTTP.end_of_body
    --             THEN
    --                 NULL;
    --         END;

    --         DBMS_OUTPUT.PUT_LINE ('1.5');
    --         /*Cargamos en la variable respVal la devolución del servidor */
    --         --                                UTL_HTTP.read_text (http_resp, soap_respond);
    --         /*Finalizamos la conexión HTTP */
    --         UTL_HTTP.end_response (http_resp);
    --         DBMS_OUTPUT.PUT_LINE ('1.6');
    --         --      DBMS_OUTPUT.PUT_LINE ('http_resp:'||http_resp);
    --         --  message_log('Respuesta WS:'||soap_respond);
    --         --DBMS_OUTPUT.PUT_LINE('Respuesta WS:'||soap_respond);
    --         v_code := '';
    --         --message_log(ocode);
    --         --message_log(omensaje);
    --         /*    IF NVL (TRIM (ocode), 'nulo') = 'nulo' THEN
    --                ocode := '1';
    --                omensaje := 'NO se encontro la respuesta del Web Service PACK';
    --             END IF; */
    --         -- DBMS_OUTPUT.put_line ('omensaje ' || soap_respond);
    --         RETURN soap_respond;
    --         DBMS_OUTPUT.PUT_LINE ('1.7');
    --     EXCEPTION
    --         WHEN UTL_HTTP.end_of_body
    --         THEN
    --             ocode := '1';
    --             omensaje := 'Error en UTL_HTTP.end_of_body';
    --             --message_log(ocode);
    --             --message_log(omensaje);
    --             RETURN omensaje;
    --         WHEN UTL_HTTP.request_failed
    --         THEN
    --             ocode := '1';
    --             omensaje :=
    --                    'Falló solicitud al Web Service(Sin Respuesta): '
    --                 || SQLERRM;
    --             DBMS_OUTPUT.PUT_LINE (OCODE);
    --             DBMS_OUTPUT.PUT_LINE (omensaje);
    --             DBMS_OUTPUT.PUT_LINE (UTL_HTTP.get_detailed_sqlerrm);
    --             --message_log(ocode);
    --             --message_log(omensaje);
    --             RETURN omensaje;
    --         WHEN OTHERS
    --         THEN
    --             ocode := '1';
    --             omensaje :=
    --                    'Error: '
    --                 || SQLERRM
    --                 || ', Respuesta ws:'
    --                 || SUBSTR (soap_respond, 1, 100);
    --             --message_log(ocode);
    --             --message_log(omensaje);
    --             RETURN omensaje;
    --     END consume_ws;
    -- ----------------------------------    BEGIN PRINCIPAL

    -- BEGIN
    --     --inseRt into eam_aux3 values ('XX 1',sysdate);
        
    --     --COMMIT;
    --     BEGIN
    --         --EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE =  "LATIN AMERICAN SPANISH" ';
    --         EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE =  "AMERICAN" ';

    --         --            DBMS_OUTPUT.PUT_LINE ('test');
    --         SELECT xxgepp_cust_reg_fac2x.NEXTVAL INTO V_IDREGX FROM DUAL;

    --         SELECT FND_GLOBAL.user_id INTO v_user_id FROM DUAL;

    --         insert into XXGEPP_CUST_REGISTRO_FACTURAS3 values (V_IDREGX, 'valida_mat ' || sysdate, null);
    --         commit;

    --         V_P_XML := REGEXP_REPLACE (P_XML, '<\?.*\?>', '');

    --         V_P_XML :=
    --             REPLACE (V_P_XML,
    --                      'xmlns:cfdi="http://www.sat.gob.mx/cfd/3"',
    --                      'xmlns:cfdi="http://www.sat.gob.mx/cfd/4"');

    --         --V_P_XML :=
    --         -- REGEXP_REPLACE (V_P_XML, '<cfdi:Addenda>*</cfdi:Addenda>', '');
    --         --V_P_XML :=
    --         --REGEXP_REPLACE (V_P_XML, '<cfdi:Addenda>.*</cfdi:Addenda>', '');
    --         --V_P_XML := P_XML;
    --         V_P_XML := REPLACE (V_P_XML, 'ï»¿', '');
    --         V_P_XML := REPLACE (V_P_XML, 'xmlns:cfdi="Addenda"', '');

    --         IF NVL (V_USER_ID, 0) = -1
    --         THEN
    --             V_P_XML := REPLACE (V_P_XML, '''', '''''');
    --         ELSE
    --             V_P_XML := REPLACE (V_P_XML, '''''', '''');
    --         END IF;

    --         INSERT INTO xxgepp_cust_registro_facturas2 (REGISTRO_ID,
    --                                                     NOMBRE_APLICACION,
    --                                                     XML_CONTENT,
    --                                                     NUM_ID_TRANSACCION)
    --              VALUES (V_IDREGX,
    --                      P_ORIGEN,
    --                      V_XMLTYPE,
    --                      P_Transaccion_ID);

    --         COMMIT;

    --         --inseRt into eam_aux3 values ('XX 4',sysdate);
    --         --COMMIT;
    --         INSERT INTO xxgepp_cust_registro_fact_all (REGISTRO_ID,
    --                                                    NOMBRE_APLICACION,
    --                                                    NUM_ID_TRANSACCION)
    --              VALUES (V_IDREGX, P_ORIGEN, P_Transaccion_ID);

    --         COMMIT;

    --         v_debug := 'Termina de insercción en tablas';
    --     EXCEPTION
    --         WHEN OTHERS
    --         THEN
    --             V_RETURN2 := SQLERRM;

    --             RETURN    'Error en el insert xxgepp_cust_registro_facturas2 '
    --                    || SUBSTR (V_RETURN2, 1, 60);

    --             DBMS_OUTPUT.PUT_LINE ('EXCEPCION' || SQLERRM);
    --     END;

    --     ---------------------------------------------------------------------------------

    --     BEGIN
    --         SELECT COUNT (MEANING)
    --           INTO V_CUENTA
    --           FROM FND_LOOKUP_VALUES_VL
    --          WHERE     LOOKUP_TYPE = 'CUST_FND_ORIGEN_CFDI_LKP'
    --                AND MEANING = P_ORIGEN;

    --         IF V_CUENTA = 0
    --         THEN
    --             V_RETURN := 'ERROR: NO EXISTE ORIGEN  ' || P_ORIGEN;

    --             DELETE FROM xxgepp_cust_registro_facturas2
    --                   WHERE registro_id = V_IDREGX;

    --             RETURN V_RETURN;

    --             RAISE RAISE_ORIGEN;
    --         END IF;
    --     EXCEPTION
    --         WHEN OTHERS
    --         THEN
    --             DBMS_OUTPUT.PUT_LINE ('EXCEPCION 00 ' || SQLERRM);

    --             V_RETURN2 := SQLERRM;

    --             RETURN    'Error en la obtencion del Origen '
    --                    || SUBSTR (V_RETURN2, 1, 60);
    --     END;

    --     BEGIN
    --         IF P_ORIGEN IN ('SP', 'OIE')
    --         THEN
    --             IF P_ORIGEN = 'SP'
    --             THEN
    --                 SELECT COUNT (TRANSFER_ID)
    --                   INTO V_EXISTE3
    --                   FROM cust_ap_terceros_h
    --                  WHERE TRANSFER_ID = P_Transaccion_ID;

    --                 IF V_EXISTE3 = 0
    --                 THEN
    --                     V_RETURN :=
    --                            'ERROR: NO EXISTE TRANSFER_ID  '
    --                         || P_Transaccion_ID;

    --                     DELETE FROM xxgepp_cust_registro_facturas2
    --                           WHERE registro_id = V_IDREGX;

    --                     DELETE FROM xxgepp_cust_registro_fact_all
    --                           WHERE registro_id = V_IDREGX;

    --                     RETURN V_RETURN;

    --                     RAISE RAISE_ORIGEN;
    --                 END IF;
    --             ELSIF P_ORIGEN = 'OIE'
    --             THEN
    --                 SELECT COUNT (REPORT_HEADER_ID)
    --                   INTO V_EXISTE3
    --                   FROM apps.xxexp_report_headers_all
    --                  WHERE REPORT_HEADER_ID = P_Transaccion_ID;

    --                 IF V_EXISTE3 = 0
    --                 THEN
    --                     V_RETURN :=
    --                            'ERROR: NO EXISTE TRANSFER_ID  '
    --                         || P_Transaccion_ID;

    --                     DELETE FROM xxgepp_cust_registro_facturas2
    --                           WHERE registro_id = V_IDREGX;

    --                     DELETE FROM xxgepp_cust_registro_fact_all
    --                           WHERE registro_id = V_IDREGX;

    --                     COMMIT;

    --                     RETURN V_RETURN;

    --                     RAISE RAISE_ORIGEN;
    --                 END IF;
    --             END IF;
    --         END IF;
    --     EXCEPTION
    --         WHEN OTHERS
    --         THEN
    --             DBMS_OUTPUT.PUT_LINE ('EXCEPCION 00 ' || SQLERRM);

    --             V_RETURN2 := SQLERRM;

    --             RETURN    'Error al obtener el transfer_id o el report_header_id '
    --                    || SUBSTR (V_RETURN2, 1, 60);
    --     END;

    --     v_debug := 'Inicia validación versión ' || V_IDREGX;

    --     BEGIN
    --         SELECT (COUNT (xt.versio))                    --xt.versio,xt.Fecha
    --           INTO V_CUENTAVERSION                       --V_VERSIONM,V_FECHAM
    --           FROM xxgepp_cust_registro_facturas2  x,
    --                XMLTABLE (
    --                    XMLNAMESPACES (
    --                        'http://www.sat.gob.mx/cfd/4' AS "cfdi"),
    --                    '/cfdi:Comprobante'
    --                    PASSING x.xml_content -- COLUMNS versio number PATH '@Version',
    --                    COLUMNS versio VARCHAR2 (50)
    --                                PATH '@Version',
    --                            fecha VARCHAR2 (50)
    --                                PATH '@Fecha') xt
    --          WHERE REGISTRO_ID = V_IDREGX;

    --         --Aqui es donde se coloca la secuencia consumida
    --         --  DBMS_OUTPUT.PUT_LINE(V_CUENTAVERSION);

    --         v_debug := 'Inicia validación versión. ';
    --     END;

    --     BEGIN
    --         IF V_CUENTAVERSION = 1
    --         THEN
    --             SELECT xt.versio, xt.Fecha
    --               INTO V_VERSIONM, V_FECHAM
    --               FROM xxgepp_cust_registro_facturas2  x,
    --                    XMLTABLE (
    --                        XMLNAMESPACES (
    --                            'http://www.sat.gob.mx/cfd/4' AS "cfdi"),
    --                        '/cfdi:Comprobante'
    --                        PASSING x.xml_content -- COLUMNS versio NUMBER PATH '@Version',
    --                        COLUMNS versio VARCHAR2 (50)
    --                                    PATH '@Version',
    --                                fecha VARCHAR2 (50)
    --                                    PATH '@Fecha') xt
    --              WHERE REGISTRO_ID = V_IDREGX;
    --         --Aqui es donde se coloca la secuencia consumida
    --         -- DBMS_OUTPUT.PUT_LINE(V_CUENTAVERSION);

    --         ELSIF V_CUENTAVERSION = 0
    --         THEN
    --             SELECT xt.versio, xt.Fecha
    --               INTO V_VERSIONM, V_FECHAM
    --               FROM xxgepp_cust_registro_facturas2  x,
    --                    XMLTABLE (
    --                        XMLNAMESPACES (
    --                            'http://www.sat.gob.mx/cfd/4' AS "cfdi"),
    --                        '/cfdi:Comprobante'
    --                        PASSING x.xml_content --COLUMNS versio NUMBER PATH '@version',
    --                        COLUMNS versio VARCHAR2 (50)
    --                                    PATH '@version',
    --                                fecha VARCHAR2 (50)
    --                                    PATH '@fecha') xt
    --              WHERE REGISTRO_ID = V_IDREGX;
    --         --Aqui es donde se coloca la secuencia consumida
    --         --  DBMS_OUTPUT.PUT_LINE(V_CUENTAVERSION);

    --         END IF;

    --         v_debug := 'Termina validación versión';

    --         DBMS_OUTPUT.PUT_LINE ('Termina validación versión');

    --         -- DBMS_OUTPUT.PUT_LINE(V_VERSIONM||'***');

    --         UPDATE xxgepp_cust_registro_facturas2
    --            SET XML_VERSION = V_VERSIONM
    --          WHERE REGISTRO_ID = V_IDREGX;

    --         COMMIT;

    --         UPDATE xxgepp_cust_registro_fact_all
    --            SET XML_VERSION = V_VERSIONM
    --          WHERE REGISTRO_ID = V_IDREGX;

    --         COMMIT;
    --     EXCEPTION
    --         WHEN OTHERS
    --         THEN
    --             V_RETURN2 := SQLERRM;

    --             RETURN    ' Error al obtener la Version '
    --                    || SUBSTR (V_RETURN2, 1, 60);

    --             DBMS_OUTPUT.PUT_LINE ('EXCEPCION' || SQLERRM);
    --     END;

    --     BEGIN
    --         SELECT MEANING
    --           INTO V_FECHAL
    --           FROM FND_LOOKUP_VALUES_VL
    --          WHERE LOOKUP_TYPE = 'CUST_AP_SAT_FECHA_LIMIT';

    --         V_FECHAM :=
    --             TRUNC (
    --                 TO_DATE (REPLACE (V_FECHAM, 'T', ' '),
    --                          'YYYY/MM/DD HH24:MI:ss'));

    --         V_FECHAMP :=
    --             TO_CHAR (TO_DATE (V_FECHAM, 'DD/MM/YYYY'), 'YYYY-MM-DD');
    --         --V_FECHAL := TO_DATE(V_FECHAL,'YYYY-MM-DD');
    --         V_FECHAL := TRUNC (TO_DATE (V_FECHAL, 'DD/MM/YY'));

    --         --  DBMS_OUTPUT.PUT_LINE('***'||V_FECHAL||'***'||V_FECHAMP);

    --         --NUEVO DEADLINE 3.3
    --         IF V_VERSIONM NOT IN ('3.3', '4.0')
    --         THEN
    --             V_FLAGVALIDACION := TRUE;
    --             V_ERROR_CONCA :=
    --                 'ERROR: Version de CFDI no soportada:  ' || V_VERSIONM;
    --         END IF;

    --         IF V_VERSIONM != '4.0'
    --         THEN
    --             IF TO_DATE (V_FECHAM, 'DD-MM-YY') >
    --                TO_DATE (V_FECHAL, 'DD-MM-YY')
    --             THEN
    --                 V_FLAGVALIDACION := TRUE;
    --                 V_ERROR_CONCA :=
    --                        'ERROR: LA VERSION DEL XML '
    --                     || V_VERSIONM
    --                     || ' ES INVALIDA YA QUE LA FECHA DEL XML '
    --                     || V_FECHAM
    --                     || ' ES POSTERIOR A LO PERMITIDO '
    --                     || V_FECHAL;
    --             END IF;
    --         END IF;
    --     END;

    --     BEGIN
    --         IF V_VERSIONM IN ('3.2', '3.3')
    --         THEN
    --             V_FLAGVALIDACION := TRUE;
    --             V_ERROR_CONCA := 'Version CFDI no soportada: ' || V_VERSIONM;
    --         -- DBMS_OUTPUT.PUT_LINE('***3.2***');
    --         ELSIF V_VERSIONM IN ('4.0')
    --         THEN
    --             v_debug := 'Inicia validaciones 3.3 y 4.0';

    --             --  DBMS_OUTPUT.PUT_LINE('3.3 y 4.0');

    --             BEGIN
    --                 SELECT xt.serie,
    --                        xt.folio,
    --                        xt.RFC_Emisor,
    --                        xt.NomEmisor,
    --                        xt.UUID,
    --                        xt.Moneda,
    --                        xt.metodoDePago,
    --                        xt.tipoCompro,
    --                        xt.RFC_Receptor,
    --                        xt.total,
    --                        xt.subTotal,
    --                        --xt.Iva,
    --                        xt.UUID,
    --                        xt.USOCFDI
    --                   INTO V_SERIEM,
    --                        V_FOLIOM,
    --                        V_EMIRFCM,
    --                        V_EMINOMBREM,
    --                        V_UUIDM,
    --                        V_MONEDAM,
    --                        V_METODOPAGOM,
    --                        V_TIPOCOMPROM,
    --                        V_RECRFCM,
    --                        V_TOTALM,
    --                        V_SUBTOTALM,
    --                        --V_IVAM,
    --                        V_UUIDM,
    --                        V_USOCFDI
    --                   FROM xxgepp_cust_registro_facturas2  x,
    --                        XMLTABLE (
    --                            XMLNAMESPACES (
    --                                'http://www.sat.gob.mx/cfd/4' AS "cfdi",
    --                                'http://www.sat.gob.mx/TimbreFiscalDigital'
    --                                    AS "tfd"),
    --                            '/cfdi:Comprobante'
    --                            PASSING x.xml_content
    --                            COLUMNS serie VARCHAR (2)
    --                                        PATH '@Serie',
    --                                    folio VARCHAR2 (50)
    --                                        PATH '@Folio',
    --                                    Moneda VARCHAR2 (50)
    --                                        PATH '@Moneda',
    --                                    metodoDePago VARCHAR2 (100)
    --                                        PATH '@MetodoDePago',
    --                                    tipoCompro VARCHAR2 (50)
    --                                        PATH '@TipoDeComprobante',
    --                                    NomEmisor VARCHAR2 (50)
    --                                        PATH 'cfdi:Emisor/@Nombre',
    --                                    RFC_Emisor VARCHAR2 (50)
    --                                        PATH 'cfdi:Emisor/@Rfc',
    --                                    NomReceptor VARCHAR2 (100)
    --                                        PATH 'cfdi:Receptor/@Nombre',
    --                                    RFC_Receptor VARCHAR2 (50)
    --                                        PATH 'cfdi:Receptor/@Rfc',
    --                                    USOCFDI VARCHAR2 (50)
    --                                        PATH 'cfdi:Receptor/@UsoCFDI',
    --                                    total VARCHAR2 (50)
    --                                        PATH '@Total',
    --                                    subTotal VARCHAR2 (50)
    --                                        PATH '@SubTotal',
    --                                    --                                  IVA VARCHAR2 (50) PATH
    --                                    --                                  'cfdi:Impuestos/cfdi:Traslados/cfdi:Traslado/@Importe',
    --                                    retencion VARCHAR2 (50)
    --                                        PATH 'cfdi:Impuestos/cfdi:Retenciones/cfdi:Retencion/@Importe',
    --                                    UUID VARCHAR2 (250)
    --                                        PATH 'cfdi:Complemento/tfd:TimbreFiscalDigital/@UUID')
    --                        xt
    --                  WHERE REGISTRO_ID = V_IDREGX; --Aqui es donde se coloca la secuencia consumida
    --             EXCEPTION
    --                 WHEN OTHERS
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('EXCEPCION XML' || SQLERRM);
    --                     V_RETURN2 := SQLERRM;
    --                     RETURN    'Error al obtener etiqueta de XML Version 3.3 '
    --                            || '°°°'
    --                            || V_FOLIOM
    --                            || ' |||2 '
    --                            || V_SERIEM
    --                            || ' |||6 '
    --                            || V_UUIDM
    --                            || ' |||8 '
    --                            || V_METODOPAGOM
    --                            || ' |||13 '
    --                            || V_IVAM
    --                            || ' |||14 '
    --                            || V_UUIDM
    --                            || ' |||15 '
    --                            || V_USOCFDI
    --                            || SUBSTR (V_RETURN2, 1, 60);
    --             END;

    --             ---- VALIDA SI EXISTE EL XML
    --             DBMS_OUTPUT.PUT_LINE ('VALIDA EXISTENCIA DE XML');

    --             BEGIN
    --                 IF p_origen = 'SP'
    --                 THEN
    --                     SELECT COUNT (ATTRIBUTE8)
    --                       INTO V_CUENTA_UUID
    --                       FROM cust_ap_terceros_h
    --                      WHERE     ATTRIBUTE8 = V_UUIDM
    --                            AND TRANSFER_ID <> P_Transaccion_ID
    --                            AND STATUS NOT IN ('CANCELADO', 'RECHAZADO');

    --                     --inseRt into eam_aux3 values ('B 1 '||V_UUIDM||' '||P_Transaccion_ID,sysdate);
    --                     --COMMIT;

    --                     IF V_CUENTA_UUID != 0
    --                     THEN
    --                         SELECT TRANSFER_NO
    --                           INTO V_TRANSFER_NO
    --                           FROM cust_ap_terceros_h
    --                          WHERE     ATTRIBUTE8 = V_UUIDM
    --                                AND TRANSFER_ID <> P_Transaccion_ID
    --                                AND STATUS NOT IN
    --                                        ('CANCELADO', 'RECHAZADO')
    --                                AND ROWNUM = 1;

    --                         V_FLAGVALIDACION := TRUE;

    --                         V_ERROR_CONCA :=
    --                                V_ERROR_CONCA
    --                             || 'EL XML YA FUE UTILIZADO EN LA SOLICITUD DE PAGO: '
    --                             || ' --> '
    --                             || V_TRANSFER_NO
    --                             || CHR (10);
    --                     -- DBMS_OUTPUT.PUT_LINE(V_TRANSFER_NO||'  '||'EXISTE');
    --                     END IF;
    --                 --              inseRt into eam_aux3 values ('B 2 '||V_UUIDM||' '||P_Transaccion_ID,sysdate);
    --                 --COMMIT;

    --                 END IF;
    --             EXCEPTION
    --                 WHEN NO_DATA_FOUND
    --                 THEN
    --                     NULL;
    --                 WHEN OTHERS
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('EXCEPCION 2 ' || SQLERRM);
    --                     V_RETURN2 := SQLERRM;
    --                     RETURN    'Error al obtener existencia de XML '
    --                            || SUBSTR (V_RETURN2, 1, 60);
    --             END;

    --             -------------  STATUS EN MODO CAPTURADO 3.3

    --             BEGIN
    --                 IF p_origen = 'SP'
    --                 THEN
    --                     IF p_origen = 'SP'
    --                     THEN
    --                         V_EX2 := 0;

    --                         SELECT COUNT (status)
    --                           INTO V_EX2
    --                           FROM apps.cust_ap_terceros_h
    --                          WHERE     transfer_id = P_Transaccion_ID
    --                                AND STATUS = 'CAPTURADO';

    --                         IF V_EX2 = 1
    --                         THEN
    --                             --  DBMS_OUTPUT.PUT_LINE(V_EXISTE||'  '||'EXISTE');

    --                             DBMS_OUTPUT.PUT_LINE ('');
    --                         ELSE
    --                             V_FLAGVALIDACION := TRUE;

    --                             V_ERROR_CONCA :=
    --                                    V_ERROR_CONCA
    --                                 || 'EL STATUS NO EXISTE'
    --                                 || ' --> '
    --                                 || V_EX2
    --                                 || CHR (10);
    --                         --  DBMS_OUTPUT.PUT_LINE(V_EXISTE||'  '||'NO EXISTE');

    --                         END IF;
    --                     END IF;
    --                 END IF;
    --             EXCEPTION
    --                 WHEN OTHERS
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('EXCEPCION 2 ' || SQLERRM);
    --                     V_RETURN2 := SQLERRM;
    --                     RETURN    'Error al obtener Status '
    --                            || SUBSTR (V_RETURN2, 1, 60);
    --             END;

    --             -- Validaciones 4.0 Ticket 8647609
    --             BEGIN
    --                 V_VALCFDI := APPS.CUST_AP_CFDI_VALS_FNC (V_IDREGX);

    --                 -- V_VALCFDI regresa datos separados por | regex para traer el dato.
    --                 IF REGEXP_SUBSTR (V_VALCFDI,
    --                                   '(.*?)(\||$)',
    --                                   1,
    --                                   1,
    --                                   NULL,
    --                                   1) <> 'CORRECTO'
    --                 THEN
    --                     V_ERROR_CONCA := V_ERROR_CONCA || V_VALCFDI;
    --                     V_FLAGVALIDACION := TRUE;
    --                 ELSIF REGEXP_SUBSTR (V_VALCFDI,
    --                                      '(.*?)(\||$)',
    --                                      1,
    --                                      2,
    --                                      NULL,
    --                                      1) <> EMPTY_CLOB ()
    --                 THEN
    --                     V_ADVERTENCIA :=
    --                            V_ADVERTENCIA
    --                         || REGEXP_SUBSTR (V_VALCFDI,
    --                                           '(.*?)(\||$)',
    --                                           1,
    --                                           2,
    --                                           NULL,
    --                                           1);
    --                 END IF;
    --             EXCEPTION
    --                 WHEN OTHERS
    --                 THEN
    --                     v_return2 := SQLERRM;
    --                     RETURN    'err - al invocar la función CUST_AP_CFDI_VALS_FNC. '
    --                            || SUBSTR (v_return2, 1, 60);
    --             END;

    --             --VALIDACION DE PROVEEDOR RFC EMISOR Y RECEPCION 3.3
    --             BEGIN
    --                 IF p_origen = 'SP'
    --                 THEN
    --                     SELECT cust_ap_prov_sp_fnc (V_EMIRFCM, V_RECRFCM)    resultado
    --                       INTO V_EX
    --                       FROM DUAL;

    --                     IF V_EX LIKE ('EXITOSO%')
    --                     THEN
    --                         DBMS_OUTPUT.PUT_LINE ('');
    --                     --DBMS_OUTPUT.PUT_LINE(V_EMIRFC||' '||V_EXISTE2);

    --                     ELSE
    --                         V_ERROR_CONCA :=
    --                             V_ERROR_CONCA /*|| 'EL PROVEEDOR CON EL RFC'
    --                                           || ' --> '
    --                                           || V_EMIRFCM
    --                                           || '-- NO CUENTA CON LAS CARACTERÍSTICAS PARA CREAR SOLICITUDES DE PAGO, FAVOR DE CONTACTAR A CONTRALORIA AP '*/
    --                                           || V_EX || CHR (10);
    --                         --  DBMS_OUTPUT.PUT_LINE('EL PROVEEDOR CON EL RFC ' || V_EMIRFC
    --                         --                        || '-- NO CUENTA CON LAS CARACTERÍSTICAS PARA CREAR SOLICITUDES DE PAGO, FAVOR DE CONTACTAR A CONTRALORIA AP ');
    --                         V_FLAGVALIDACION := TRUE;
    --                     END IF;
    --                 END IF;
    --             EXCEPTION
    --                 WHEN OTHERS
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('EXCEPCION 3 ' || SQLERRM);
    --                     V_RETURN2 := SQLERRM;
    --                     RETURN    'Error al obtener proveedor Emisor y Receptor '
    --                            || SUBSTR (V_RETURN2, 1, 60);
    --             END;

    --             ----  VALIDACION DE PROVEEDOR CERTIFICADO 3.3

    --             BEGIN
    --                 IF p_origen = 'SP'
    --                 THEN
    --                     V_EX :=
    --                         apps.cust_ap_prov_certifica2 (V_EMIRFCM,
    --                                                       NULL,
    --                                                       '1');

    --                     --DBMS_OUTPUT.PUT_LINE(V_EXISTE2);

    --                     IF V_EX = 'NO'
    --                     THEN
    --                         -- DBMS_OUTPUT.PUT_LINE('ERROR');
    --                         V_ERROR_CONCA :=
    --                                V_ERROR_CONCA
    --                             || 'EL PROVEEDOR NO ES CERTIFICADO'
    --                             || ' --> '
    --                             || V_EMIRFCM
    --                             || CHR (10);

    --                         V_FLAGVALIDACION := TRUE;
    --                     ELSIF V_EX = 'SI'
    --                     THEN
    --                         DBMS_OUTPUT.PUT_LINE ('');
    --                     END IF;
    --                 END IF;
    --             EXCEPTION
    --                 WHEN OTHERS
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('EXCEPCION 4 ' || SQLERRM);
    --                     V_RETURN2 := SQLERRM;
    --                     RETURN    ' Error al obtener proveedor certificado '
    --                            || SUBSTR (V_RETURN2, 1, 60);
    --             END;

    --             --- ********* VALIDACIONES DE LA MATRIZ

    --             BEGIN
    --                 V_EX :=
    --                     FN_CUST_FORMAPAGO (p_origen,
    --                                        V_IDREGX,
    --                                        P_Transaccion_ID);

    --                 --V_EX := FN_CUST_FORMAPAGO (p_origen, P_Transaccion_ID);
    --                 -- DBMS_OUTPUT.PUT_LINE(V_EX);

    --                 IF V_EX != 'CORRECTO'
    --                 THEN
    --                     --DBMS_OUTPUT.PUT_LINE('ERROR');
    --                     V_ERROR_CONCA := V_EX || CHR (10);
    --                     V_FLAGVALIDACION := TRUE;
    --                 ELSIF V_EX = 'CORRECTO'
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('');
    --                 END IF;

    --                 IF V_EX = 'NO ENCONTRADO'
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE (
    --                         'NO ENCONTRADO EN FORMA DE PAGO');
    --                 END IF;
    --             EXCEPTION
    --                 WHEN OTHERS
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('EXCEPCION 5 ' || SQLERRM);

    --                     V_RETURN2 := SQLERRM;

    --                     RETURN    ' Error al obtener Forma de Pago'
    --                            || SUBSTR (V_RETURN2, 1, 60);
    --             END;

    --             v_debug := 'Inicia FN_CUST_METODOPAGO';

    --             BEGIN
    --                 V_EX :=
    --                     FN_CUST_METODOPAGO (p_origen,
    --                                         V_IDREGX,
    --                                         P_TRANSACCION_ID);

    --                 --DBMS_OUTPUT.PUT_LINE(V_EX);

    --                 IF V_EX != 'CORRECTO'
    --                 THEN
    --                     --DBMS_OUTPUT.PUT_LINE('ERROR');
    --                     V_ERROR_CONCA := V_ERROR_CONCA || V_EX || CHR (10);
    --                     V_FLAGVALIDACION := TRUE;
    --                 ELSIF V_EX = 'CORRECTO'
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('');
    --                 END IF;

    --                 IF V_EX = 'NO ENCONTRADO'
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE (
    --                         'NO ENCONTRADO EN METODO DE PAGO');
    --                 END IF;
    --             EXCEPTION
    --                 WHEN OTHERS
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('EXCEPCION 6 ' || SQLERRM);

    --                     V_RETURN2 := SQLERRM;

    --                     RETURN    ' Error al Obtener Metodo de Pago '
    --                            || SUBSTR (V_RETURN2, 1, 60);
    --             END;

    --             v_debug := 'Inicia FN_CUST_TIPORELACION';

    --             BEGIN
    --                 V_EX :=
    --                     FN_CUST_TIPORELACION (p_origen,
    --                                           V_IDREGX,
    --                                           P_TRANSACCION_ID);

    --                 --DBMS_OUTPUT.PUT_LINE(V_EX);

    --                 IF V_EX <> 'CORRECTO'
    --                 THEN
    --                     --DBMS_OUTPUT.PUT_LINE('ERROR');
    --                     V_ERROR_CONCA := V_ERROR_CONCA || V_EX || CHR (10);
    --                     V_FLAGVALIDACION := TRUE;
    --                 ELSIF V_EX = 'CORRECTO'
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('');
    --                 --ELSIF V_EX = 'NO APLICA'
    --                 --THEN
    --                 -- DBMS_OUTPUT.PUT_LINE ('');
    --                 --DBMS_OUTPUT.PUT_LINE ('NO APLICA EN "' || P_ORIGEN || '"');

    --                 END IF;

    --                 IF V_EX = 'NO ENCONTRADO'
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE (
    --                         'NO ENCONTRADO EN TIPO DE RELACION');
    --                 END IF;
    --             EXCEPTION
    --                 WHEN OTHERS
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('EXCEPCION 7 ' || SQLERRM);
    --                     V_RETURN2 := SQLERRM;
    --                     RETURN    ' Error al obtener Tipo de Relacion '
    --                            || SUBSTR (V_RETURN2, 1, 60);
    --             END;

    --             v_debug := 'Inicia FN_CUST_RESIDENCIAFISCAL';

    --             BEGIN
    --                 V_EX := FN_CUST_RESIDENCIAFISCAL (p_origen, V_IDREGX);

    --                 --DBMS_OUTPUT.PUT_LINE(V_EX);
    --                 IF V_EX != 'CORRECTO'
    --                 THEN
    --                     --DBMS_OUTPUT.PUT_LINE('ERROR');
    --                     V_ERROR_CONCA := V_ERROR_CONCA || V_EX || CHR (10);
    --                     V_FLAGVALIDACION := TRUE;
    --                 ELSIF V_EX = 'CORRECTO'
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('');
    --                 END IF;

    --                 IF V_EX = 'NO ENCONTRADO'
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE (
    --                         'NO ENCONTRADO EN RESIDENCIA FISCAL');
    --                 END IF;
    --             EXCEPTION
    --                 WHEN OTHERS
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('EXCEPCION 8 ' || SQLERRM);
    --                     V_RETURN2 := SQLERRM;
    --                     RETURN    'Error al obtenener Residencia Fiscal '
    --                            || SUBSTR (V_RETURN2, 1, 60);
    --             END;

    --             v_debug := 'Inicia FN_CUST_NUMREGIDTRIB';

    --             BEGIN
    --                 V_EX := FN_CUST_NUMREGIDTRIB (p_origen, V_IDREGX);

    --                 --DBMS_OUTPUT.PUT_LINE(V_EX);
    --                 IF V_EX != 'CORRECTO'
    --                 THEN
    --                     --DBMS_OUTPUT.PUT_LINE('ERROR');
    --                     V_ERROR_CONCA := V_ERROR_CONCA || V_EX || CHR (10);
    --                     V_FLAGVALIDACION := TRUE;
    --                 ELSIF V_EX = 'CORRECTO'
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('');
    --                 END IF;

    --                 IF V_EX = 'NO ENCONTRADO'
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE (
    --                         'NO ENCONTRADO EN RESIDENCIA FISCAL');
    --                 END IF;
    --             EXCEPTION
    --                 WHEN OTHERS
    --                 THEN
    --                     DBMS_OUTPUT.PUT_LINE ('EXCEPCION 9 ' || SQLERRM);
    --                     V_RETURN2 := SQLERRM;
    --                     RETURN    'Error al obtener Numero de Registro '
    --                            || SUBSTR (V_RETURN2, 1, 60);
    --             END;

    --             BEGIN
    --                 BEGIN
    --                     SELECT TO_DATE (MEANING, 'DD-MM-YY')
    --                       INTO VFECHAuso
    --                       FROM fnd_lookup_values_vl
    --                      WHERE     ENABLED_FLAG = 'Y'
    --                            AND lookup_type =
    --                                'CUST_AP_USOCFDI_FECHA_LIMITE'
    --                            AND (   END_DATE_ACTIVE IS NULL
    --                                 OR TRUNC (END_DATE_ACTIVE) >
    --                                    TRUNC (SYSDATE));
    --                 EXCEPTION
    --                     WHEN OTHERS
    --                     THEN
    --                         V_ERROR_CONCA :=
    --                                V_ERROR_CONCA
    --                             || 'Configuracion en la fecha limite del UsoCFDI dentro del lookup '
    --                             || SQLERRM
    --                             || CHR (10);

    --                         V_FLAGVALIDACION := TRUE;
    --                 --RETURN 'Configuracion en la fecha limite del UsoCFDI dentro del lookup '
    --                 --     || SQLERRM;

    --                 END;

    --                 v_debug := 'Inicia CUST_CFDI_USO_FNC';

    --                 IF VFECHAuso >= TRUNC (SYSDATE)
    --                 THEN
    --                     V_BANDERA := '0';
    --                 ELSE
    --                     V_BANDERA := '1';
    --                 END IF;

    --                 --insert into eam_aux3 values ('cfdi '||V_EX,sysdate);
    --                 --commit;
    --                 --V_EX := CUST_CFDI_USO_FNC(P_ORIGEN,V_USOCFDI,V_IDREGX);

    --                 IF P_ORIGEN <> 'INTERCOS'
    --                 THEN
    --                     V_EX :=
    --                         CUST_CFDI_USO_FNC (P_ORIGEN,
    --                                            V_USOCFDI,
    --                                            p_transaccion_id,
    --                                            V_IDREGX);

    --                     --insert into eam_aux3 values ('cfdi2 '||V_EX,sysdate);
    --                     --commit;
    --                     /*    IF V_EX != 'CORRECTO'
    --                         THEN
    --                            V_ERROR_CONCA := V_ERROR_CONCA || V_EX || CHR (10);
    --                            V_FLAGVALIDACION := TRUE;
    --                         END IF;*/

    --                     IF (V_EX) != 'CORRECTO' AND V_BANDERA = '1'
    --                     THEN
    --                         V_ERROR_CONCA :=
    --                             V_ERROR_CONCA || V_EX || CHR (10);

    --                         V_FLAGVALIDACION := TRUE;
    --                     ELSIF (V_EX) != 'CORRECTO' AND V_BANDERA = '0'
    --                     THEN
    --                         --V_WARNING_USOCFDI := V_EX;
    --                         --V_FLAGVALIDACIONW := TRUE;
    --                         NULL;
    --                     END IF;
    --                 END IF;
    --             --insert into eam_aux3 values ('cfdi 3'||V_EX,sysdate);
    --             --commit;

    --             EXCEPTION
    --                 WHEN OTHERS
    --                 THEN
    --                     V_RETURN2 := SQLERRM;
    --                     RETURN    'Error al obtener Uso de CFDI '
    --                            || SUBSTR (V_RETURN2, 1, 60);
    --             END;
    --         END IF;
    --     END;

    --     DBMS_OUTPUT.PUT_LINE ('aqui ya va paa las variables de consumo');

    --     -------------------   ASIGNACION DE VARIABLES PARA CONSUMIR EL WS

    --     BEGIN
    --         --CAMBIO A OCI
    --         SELECT APPS.XXGEPP_FND_SESION_FNC INTO V_INSTANCIA FROM DUAL;

    --         BEGIN
    --             SELECT ATTRIBUTE1
    --               INTO V_ADVERTENCIA_FINAL
    --               FROM xxgepp_cust_registro_fact_all
    --              WHERE REGISTRO_ID = V_IDREGX;
    --         EXCEPTION
    --             WHEN OTHERS
    --             THEN
    --                 V_ADVERTENCIA_FINAL := NULL;
    --         END;

    --         IF P_ORIGEN = 'PORTAL'
    --         THEN
    --             V_PROD := 'N';
    --         ELSIF V_INSTANCIA = 'PROD' AND P_ORIGEN <> 'PORTAL'
    --         THEN
    --             V_PROD := 'S';
    --         ELSIF V_INSTANCIA != 'PROD'
    --         THEN
    --             V_PROD := 'N';
    --         END IF;
    --     EXCEPTION
    --         WHEN OTHERS
    --         THEN
    --             DBMS_OUTPUT.PUT_LINE ('EXCEPCION 2 ' || SQLERRM);
    --             V_RETURN2 := SQLERRM;
    --             RETURN    'Error al obtener Instancia'
    --                    || SUBSTR (V_RETURN2, 1, 60);
    --     END;

    --     BEGIN
    --         IF P_ORIGEN = 'SP'
    --         THEN
    --             V_ORIG := 'W';
    --         ELSIF P_ORIGEN IN ('OIE', 'PORTAL')
    --         THEN
    --             V_ORIG := 'G';
    --         ELSIF P_ORIGEN IN ('ISUPPLIER', 'ISUPPLIERC')
    --         THEN
    --             V_ORIG := 'I';
    --         ELSIF P_ORIGEN IN ('INTERCOS')
    --         THEN
    --             V_ORIG := 'ICE';
    --         END IF;
    --     EXCEPTION
    --         WHEN OTHERS
    --         THEN
    --             DBMS_OUTPUT.PUT_LINE ('EXCEPCION 2 ' || SQLERRM);
    --             V_RETURN2 := SQLERRM;
    --             RETURN    'Error al obtener y colocar el Origen '
    --                    || SUBSTR (V_RETURN2, 1, 60);
    --     END;

    --     v_debug := 'Inicia F_CUST_CADDENDA_GEPP';

    --     BEGIN
    --         IF P_ORIGEN IN ('OIE', 'SP', 'PORTAL')
    --         THEN
    --             --inseRt into eam_aux3 values ('RFC 1.1'||V_EMIRFCM,sysdate);
    --             --COMMIT;

    --             V_FUNCION :=
    --                 F_CUST_CADDENDA_GEPP (P_ORIGEN,
    --                                       P_TRANSACCION_ID,
    --                                       V_IDREGX,
    --                                       V_EMIRFCM);

    --             IF V_FUNCION <> 'CORRECTO'
    --             THEN
    --                 V_FLAGVALIDACION := TRUE;

    --                 V_ERROR_CONCA :=
    --                        V_ERROR_CONCA
    --                     || ' ERROR EN LA GENERACIÓN DE LA ADDENDA '
    --                     || V_FUNCION
    --                     || CHR (10);
    --             --RETURN  'ERROR EN LA GENERACIÓN DE LA ADDENDA '||V_FUNCION;
    --             --RAISE RAISE_ADDENDA;

    --             END IF;
    --         --inseRt into eam_aux3 values ('X 1.10 ' ||V_IDREGX,sysdate);
    --         --COMMIT;
    --         -- DBMS_OUTPUT.PUT_LINE(V_FUNCION||'*******');

    --         END IF;
    --     END;

    --     BEGIN
    --         SELECT description
    --           INTO V_URLM
    --           FROM fnd_lookup_values_vl
    --          WHERE     ENABLED_FLAG = 'Y'
    --                AND lookup_type = 'CUST_FND_WALLET_CFDI'
    --                AND lookup_code = 10
    --                AND (   END_DATE_ACTIVE IS NULL
    --                     OR TRUNC (END_DATE_ACTIVE) > TRUNC (SYSDATE));
    --     EXCEPTION
    --         WHEN OTHERS
    --         THEN
    --             V_FLAGVALIDACION := TRUE;

    --             V_ERROR_CONCA :=
    --                    V_ERROR_CONCA
    --                 || ' Error en la obtención del lookup CUST_FND_WALLET_CFDI '
    --                 || SQLERRM;

    --             V_RETURN2 := SQLERRM;

    --             RETURN    'Error en la obtención del lookup CUST_FND_WALLET_CFDI  '
    --                    || SUBSTR (V_RETURN2, 1, 60);
    --     END;

    --     --------
    --     -- Proceso temporal en transicion de CFDI 3.3 a 4.0
    --     IF V_VERSIONM = '3.3'
    --     THEN
    --         V_P_XML :=
    --             REPLACE (V_P_XML,
    --                      'xmlns:cfdi="http://www.sat.gob.mx/cfd/4"',
    --                      'xmlns:cfdi="http://www.sat.gob.mx/cfd/3"');

    --         IF NVL (V_USER_ID, 0) = -1
    --         THEN
    --             V_P_XML := REPLACE (V_P_XML, '''', '''''');
    --         ELSE
    --             V_P_XML := REPLACE (V_P_XML, '''''', '''');
    --         END IF;

    --         V_xmltype := XMLTYPE.createxml (V_P_XML);

    --         UPDATE xxgepp_cust_registro_facturas2
    --            SET XML_CONTENT = V_XMLTYPE
    --          WHERE registro_id = V_IDREGX;

    --         COMMIT;
    --     END IF;

    --     --  FIN PROCESO TEMPORAL de TRANSICION 3.0 a 4.0

    --     ----  VALIDACION DE LA BANDERA

    --     IF V_FLAGVALIDACION = TRUE
    --     THEN
    --         UPDATE xxgepp_cust_registro_facturas2
    --            SET UUID = V_UUIDM,
    --                ESTATUS = 'ERROR',
    --                NUM_ID_TRANSACCION = p_transaccion_id,
    --                MENSAJE_WS = 'err - ' || V_ERROR_CONCA,
    --                ATTRIBUTE1 = V_ADVERTENCIA
    --          WHERE REGISTRO_ID = V_IDREGX;

    --         COMMIT;

    --         UPDATE xxgepp_cust_registro_fact_all
    --            SET UUID = V_UUIDM,
    --                ESTATUS = 'ERROR',
    --                NUM_ID_TRANSACCION = p_transaccion_id,
    --                MENSAJE_WS = 'err - ' || V_ERROR_CONCA,
    --                ATTRIBUTE1 = V_ADVERTENCIA
    --          WHERE REGISTRO_ID = V_IDREGX;

    --         COMMIT;

    --         --  DBMS_OUTPUT.PUT_LINE ('*** Estos son los errores: ***');
    --         -- DBMS_OUTPUT.PUT_LINE (V_ERROR_CONCA);
    --         --  DBMS_OUTPUT.PUT_LINE ('*******************************');
    --         RETURN 'err - ' || V_ERROR_CONCA;
    --         RAISE NO_FILES;
    --     END IF;

    --     --inseRt into eam_aux3 values ('X 1.0',sysdate);
    --     --COMMIT;
    --     DBMS_OUTPUT.PUT_LINE ('test2');

    --     --insert into eam_aux3 values ('A4 ',sysdate);
    --     --commit;
    --     BEGIN
    --         --     DBMS_OUTPUT.PUT_LINE('1.0');
    --         v_debug := 'Inicia sp_ObtenerBase';
    --         sp_ObtenerBase (V_IDREGX);
    --         -- DBMS_OUTPUT.PUT_LINE('1.1');
    --         --DBMS_OUTPUT.PUT_LINE('******************************************************************************************************'||V_XMLBASE64GL);

    --         V_CONCANUEVAM :=
    --                '<?xml version="1.0" encoding="utf-8"?>
    --                                         <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    --                                           <soap:Body>
    --                                             <Validar xmlns="http://www.gepp.com.mx/ValidaFacturaGEPPV/">
    --                                               <Comprobante>'
    --             || V_XMLBASE64GLM
    --             || '</Comprobante>
    --                                               <esProduccion>'
    --             || V_PROD
    --             || '</esProduccion>
    --                                               <Origen>'
    --             || V_ORIG
    --             || '</Origen>
    --                                               <Parametro></Parametro>
    --                                             </Validar>
    --                                           </soap:Body>
    --                                         </soap:Envelope>';
    --         --DBMS_OUTPUT.PUT_LINE ('resultado  23423523454235asdasd ' || ' | ' || RESULTADOM);
    --         --DBMS_OUTPUT.PUT_LINE ('resultado ' || V_XMLBASE64GLM);
    --         --   DBMS_OUTPUT.PUT_LINE('2.0');
    --         --insert into eam_aux3 values ('A5 ',sysdate);
    --         --commit;
    --         --insert into eam_aux4 values (V_CONCANUEVAM ,sysdate);
    --         --commit;
    --         /*  INSERT INTO eam_aux4
    --             VALUES   (V_XMLBASE64GLM, SYSDATE);
    --           COMMIT;
    --           INSERT INTO eam_aux4
    --             VALUES   (V_XMLCONTENTGLM, SYSDATE);
    --           COMMIT;
    --           INSERT INTO eam_aux4
    --             VALUES   (P_XML, SYSDATE);
    --           COMMIT;*/
    --         --            DBMS_OUTPUT.PUT_LINE ('test3');
    --         v_debug := 'Inicia consume_ws';
    --         RESULTADOM := consume_ws (V_CONCANUEVAM, V_URLM);
    --         --            DBMS_OUTPUT.PUT_LINE ('test4');
    --         -- DBMS_OUTPUT.PUT_LINE ('resultado  23423523454235asdasd ' || ' | ' || RESULTADOM);
    --         v_debug := 'Inicia V_RESPONSETYPE';
    --         V_RESPONSETYPE := XMLTYPE.createxml (RESULTADOM);

    --         --            DBMS_OUTPUT.PUT_LINE ('test5');
    --         --insert into eam_aux3 values ('A7 ',sysdate);
    --         --commit;
    --         -- DBMS_OUTPUT.PUT_LINE('"#$%&/()(&%'||RESULTADOM);
    --         UPDATE xxgepp_cust_registro_facturas2
    --            SET RESPONSE = V_RESPONSETYPE
    --          WHERE REGISTRO_ID = V_IDREGX;

    --         COMMIT;
    --     --DBMS_OUTPUT.PUT_LINE('"#$%&/()(&%');

    --     END;

    --     BEGIN
    --         WITH
    --             t_response
    --             AS
    --                 (SELECT registro_id,
    --                         EXTRACTVALUE (
    --                             response,
    --                             '//ValidarResult',
    --                             'xmlns="http://www.gepp.com.mx/ValidaFacturaGEPPV/')    AS result
    --                    FROM xxgepp_cust_registro_facturas2)
    --           SELECT registro_id,
    --                  CASE
    --                      WHEN SUBSTR (result, 1, 5) = '<?xml'
    --                      THEN
    --                          REGEXP_REPLACE (
    --                              EXTRACT (XMLTYPE (result), '//mensaje'),
    --                              '</?mensaje>',
    --                              '')
    --                      ELSE
    --                          result
    --                  END    Mensaje
    --             INTO V_REG, V_MEN
    --             FROM t_response
    --            WHERE registro_id = V_IDREGX
    --         ORDER BY registro_id;

    --         DBMS_OUTPUT.PUT_LINE ('V_MEN ' || V_MEN);

    --         v_debug := 'Termina t_response';

    --         DBMS_OUTPUT.PUT_LINE ('V_MEN1 ');

    --         IF NVL (V_MEN, 'X') != 'CFDI Valido'
    --         THEN
    --             DBMS_OUTPUT.PUT_LINE ('V_MEN1.1 ' || V_ERROR_CONCA);

    --             --   DBMS_OUTPUT.PUT_LINE('AQUI ERROR 1');

    --             V_FLAGVALIDACION := TRUE;

    --             V_ERROR_CONCA :=
    --                    V_ERROR_CONCA
    --                 || 'ERROR EN EL Web Service --> '
    --                 || V_MEN
    --                 || CHR (10);

    --             DBMS_OUTPUT.PUT_LINE ('V_MEN1.2 ' || V_ERROR_CONCA);

    --             UPDATE xxgepp_cust_registro_facturas2
    --                SET ESTATUS = 'ERROR',
    --                    MENSAJE_WS = 'err - ' || V_MEN,
    --                    NUM_ID_TRANSACCION = p_transaccion_id,
    --                    ATTRIBUTE1 = V_ADVERTENCIA
    --              WHERE REGISTRO_ID = V_IDREGX;

    --             DBMS_OUTPUT.PUT_LINE ('V_MEN1.3 ' || V_ERROR_CONCA);

    --             COMMIT;

    --             UPDATE xxgepp_cust_registro_fact_all
    --                SET ESTATUS = 'ERROR',
    --                    MENSAJE_WS = 'err - ' || V_MEN,
    --                    NUM_ID_TRANSACCION = p_transaccion_id,
    --                    ATTRIBUTE1 = V_ADVERTENCIA
    --              WHERE REGISTRO_ID = V_IDREGX;

    --             DBMS_OUTPUT.PUT_LINE ('V_MEN1.4 ' || V_ERROR_CONCA);

    --             COMMIT;
    --             --  DBMS_OUTPUT.PUT_LINE('AQUI ERROR 2'||' '||V_IDREGX);
    --             RAISE RAISE_ERROR;
    --         END IF;
    --     --    EXCEPTION
    --     --           WHEN OTHERS
    --     --           THEN
    --     --           DBMS_OUTPUT.PUT_LINE(SQLERRM);
    --     --           DBMS_OUTPUT.PUT_LINE('EXCEPCION CFDI VALIDO   '||V_IDREGX||'  '||SQLERRM);
    --     END;

    --     DBMS_OUTPUT.PUT_LINE ('V_MEN2 4942 ');

    --     -- DBMS_OUTPUT.PUT_LINE(V_MEN);
    --     ---------   TERMINO EN EXITO
    --     --  DBMS_OUTPUT.PUT_LINE(' AQUI EXITO');

    --     UPDATE xxgepp_cust_registro_facturas2
    --        SET UUID = V_UUIDM,
    --            ESTATUS = 'EXITOSO',
    --            MENSAJE_WS = V_MEN,
    --            NUM_ID_TRANSACCION = p_transaccion_id,
    --            ATTRIBUTE1 = V_ADVERTENCIA
    --      WHERE REGISTRO_ID = V_IDREGX;

    --     COMMIT;

    --     UPDATE xxgepp_cust_registro_fact_all
    --        SET UUID = V_UUIDM,
    --            ESTATUS = 'EXITOSO',
    --            MENSAJE_WS = V_MEN,
    --            NUM_ID_TRANSACCION = p_transaccion_id,
    --            ATTRIBUTE1 = V_ADVERTENCIA
    --      WHERE REGISTRO_ID = V_IDREGX;

    --     COMMIT;

    --     IF V_ADVERTENCIA_FINAL IS NOT NULL
    --     THEN
    --         V_RETURN := V_MEN || ' AVISO:' || V_ADVERTENCIA_FINAL;
    --     ELSE
    --         V_RETURN := V_MEN;
    --     END IF;

    --     RETURN V_RETURN;
    -- EXCEPTION
    --     WHEN NO_DATA_FOUND
    --     THEN
    --         DBMS_OUTPUT.PUT_LINE ('NO EXISTE');

    --         V_RETURN2 := SQLERRM;

    --         RETURN 'No existe  ' || SUBSTR (V_RETURN2, 1, 60);
    --     WHEN RAISE_ERROR
    --     THEN
    --         IF V_ADVERTENCIA_FINAL IS NOT NULL
    --         THEN
    --             V_RETURN :=
    --                    'err -. '
    --                 || V_ERROR_CONCA
    --                 || ' AVISO:'
    --                 || V_ADVERTENCIA_FINAL;
    --         ELSE
    --             V_RETURN := 'err -. ' || V_ERROR_CONCA;
    --         END IF;

    --         UPDATE xxgepp_cust_registro_facturas2
    --            SET UUID = V_UUIDM,
    --                ESTATUS = 'ERROR',
    --                NUM_ID_TRANSACCION = p_transaccion_id
    --          WHERE REGISTRO_ID = V_IDREGX;

    --         COMMIT;

    --         UPDATE xxgepp_cust_registro_fact_all
    --            SET UUID = V_UUIDM,
    --                ESTATUS = 'ERROR',
    --                NUM_ID_TRANSACCION = p_transaccion_id
    --          WHERE REGISTRO_ID = V_IDREGX;

    --         COMMIT;

    --         RETURN V_RETURN;
    --     WHEN RAISE_ORIGEN
    --     THEN
    --         RETURN V_RETURN;
    --     WHEN RAISE_FECHA
    --     THEN
    --         RETURN V_RETURN;
    --     WHEN RAISE_ADDENDA
    --     THEN
    --         RETURN V_RETURN;
    --     WHEN NO_FILES
    --     THEN
    --         ROLLBACK;

    --         DBMS_OUTPUT.PUT_LINE ('FIN DE PROCESO');
    --         apps.fnd_file.put_line (fnd_file.output, ' ');
    --         apps.fnd_file.put_line (fnd_file.output, ' ');
    --         apps.fnd_file.put_line (
    --             fnd_file.output,
    --             LPAD ('*****Proceso Finalizado Error*****', 70, ' '));
    --         V_RETURN2 := SQLERRM;
    --         RETURN 'Error NO_FILES ' || SUBSTR (V_RETURN2, 1, 60);
    --     WHEN OTHERS
    --     THEN
    --         DBMS_OUTPUT.PUT_LINE ('NO EXISTE');
    --         V_RETURN2 := SQLERRM;
    --         RETURN ' err -.. ' || v_debug || ' ' || SUBSTR (V_RETURN2, 1, 60);
    -- END valida_mat;

    PROCEDURE get_directory_list (p_directory IN VARCHAR2)
    IS
        LANGUAGE JAVA
        NAME 'JListDirectory.getList(java.lang.String )' ;
END;