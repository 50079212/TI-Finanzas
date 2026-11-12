CREATE OR REPLACE PACKAGE BODY APPS."CUST_AR_AGRUPADOR_PKG" 
IS
   --
   -- $Id: cust_ar_agrupador_pkg.pkb 141 2014-03-21 17:16:44Z eramirez $
   --
   -- GEPP
   --
   -- Requerimiento : Agrupador
   -- Tipo          : Package
   -- Archivo       : cust_ar_agrupador_pkg.pkb
   --
   -- Descripci¿n
   -- ===========
   --   Proporciona las rutinas para agrupacion de facturas
   -- Historial
   -- =========
   --
   -- Fecha       Quien              Que
   -- ----------- ------------------ -----------------------------------------------------
   -- 2012/12/07  genaro ponce       Version Inicial:
   -- 2012/12/28  genaro ponce       Se modifica el valor de perfil a nivel sesion
   --                                AR: Usar la Contabilidad de Factura para Notas de Cr¿dito
   --                                (AR_USE_INV_ACCT_FOR_CM_FLAG)
   -- 2013/01/09 patricia altamirano Modificaci¿n de funci¿n get_batch_source_name para que no tome
   --                                origen de refactura y modificaci¿n a mascara de cantidad para
   --                                que no tome decimales
   -- 2013/01/24 patricia altamirano Modificaci¿n funci¿n get_valor_periodo en la mascara de agrupa
   --                                semanal para que tome las semana con IW

   PROCEDURE l (p_msg_print IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.LOG, p_msg_print);
   END l;

   PROCEDURE o (p_msg_print IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.output, p_msg_print);
   END o;

   PROCEDURE insert_error (
      p_error_rec    IN     cust_ar_agrupador_pkg.error_rec,
      p_errors_tbl   IN OUT cust_ar_agrupador_pkg.errors_tbl)
   IS
      v_index           NUMBER := 0;
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'FUNCTION INSERT_ERROR';
   BEGIN
      IF p_errors_tbl.COUNT > 0
      THEN
         FOR i IN p_errors_tbl.FIRST .. p_errors_tbl.COUNT
         LOOP
            v_index := i;

            IF     p_errors_tbl (i).header_id = p_error_rec.header_id
               AND p_errors_tbl (i).customer_trx_id =
                      p_error_rec.customer_trx_id
               AND p_errors_tbl (i).desc_error = p_error_rec.desc_error
            THEN
               RETURN;
            END IF;
         END LOOP;
      END IF;

      v_index := v_index + 1;
      p_errors_tbl (v_index) := p_error_rec;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_error_rec.header_id        ',
                         p_error_rec.header_id);
         concat_message (v_error_message,
                         'p_error_rec.customer_trx_id  ',
                         p_error_rec.customer_trx_id);
         concat_message (v_error_message,
                         'p_error_rec.desc_error       ',
                         p_error_rec.desc_error);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (log_level   => fnd_log.level_unexpected,
                         module      => 'cust_ar_agrupador_pkg.insert_error',
                         MESSAGE     => v_error_message);
         raise_application_error (-20201, v_error_message);
   END;


   FUNCTION format (p_in_string          IN VARCHAR2,
                    p_in_length          IN NUMBER DEFAULT 15,
                    p_in_left_or_right   IN VARCHAR2 DEFAULT 'L')
      RETURN VARCHAR2
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'FUNCTION FORMAT';
   BEGIN
      IF p_in_left_or_right = 'L'
      THEN
         RETURN    RPAD (SUBSTR (NVL (p_in_string, ' '), 1, p_in_length),
                         p_in_length)
                || ' ';
      ELSE
         RETURN    LPAD (SUBSTR (NVL (p_in_string, ' '), 1, p_in_length),
                         p_in_length)
                || ' ';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message, 'p_in_string        ', p_in_string);
         concat_message (v_error_message, 'p_in_length        ', p_in_length);
         concat_message (v_error_message,
                         'p_in_left_or_right ',
                         p_in_left_or_right);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (log_level   => fnd_log.level_unexpected,
                         module      => 'cust_ar_agrupador_pkg.format',
                         MESSAGE     => v_error_message);
         raise_application_error (-20201, v_error_message);
   END format;

   FUNCTION format (p_in_number IN NUMBER, p_in_length IN NUMBER DEFAULT 15)
      RETURN VARCHAR2
   IS
   BEGIN
      RETURN format (p_in_string          => TO_CHAR (p_in_number),
                     p_in_length          => p_in_length,
                     p_in_left_or_right   => 'R');
   END format;

   PROCEDURE concat_message (p_io_error_message   IN OUT VARCHAR2,
                             p_in_name            IN     VARCHAR2,
                             p_in_value           IN     VARCHAR2)
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'CONCAT_MESSAGE VARCHAR';
   BEGIN
      p_io_error_message :=
         SUBSTR (
            p_io_error_message || CHR (10) || p_in_name || ':' || p_in_value,
            1,
            4000);
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         raise_application_error (-20202, v_error_message);
   END concat_message;

   PROCEDURE concat_message (p_io_error_message   IN OUT VARCHAR2,
                             p_in_name            IN     VARCHAR2,
                             p_in_value           IN     NUMBER)
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'CONCAT_MESSAGE NUMBER';
   BEGIN
      cust_ar_agrupador_pkg.concat_message (p_io_error_message,
                                            p_in_name,
                                            TO_CHAR (p_in_value));
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         raise_application_error (-20203, v_error_message);
   END concat_message;

   PROCEDURE concat_message (p_io_error_message   IN OUT VARCHAR2,
                             p_in_name            IN     VARCHAR2,
                             p_in_value           IN     DATE)
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'CONCAT_MESSAGE DATE';
   BEGIN
      cust_ar_agrupador_pkg.concat_message (
         p_io_error_message,
         p_in_name,
         TO_CHAR (p_in_value, 'YYYY/MM/DD HH24:MI:SS'));
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         raise_application_error (-20204, v_error_message);
   END concat_message;

   PROCEDURE insert_ra_interface_line (
      p_in_interface_lines_rec   IN ra_interface_lines_all%ROWTYPE)
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'INSERT_RA_INTERFACE_LINE';
   BEGIN
      INSERT INTO ra_interface_lines_all
           VALUES p_in_interface_lines_rec;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.insert_ra_interface_line',
            MESSAGE     => v_error_message);
         raise_application_error (-20205, v_error_message);
   END insert_ra_interface_line;

   FUNCTION get_period_name (p_in_date IN DATE)
      RETURN gl_period_statuses.period_name%TYPE
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'GET_PERIOD_NAME';
      v_period_name     gl_period_statuses.period_name%TYPE := NULL;
   BEGIN
      SELECT period_name
        INTO v_period_name
        FROM gl_period_statuses gps, fnd_application_vl fa
       WHERE     1 = 1
             AND fa.application_id = gps.application_id
             AND fa.application_short_name = 'AR'
             AND gps.adjustment_period_flag = 'N'
             AND gps.start_date <= TRUNC (p_in_date)
             AND gps.end_date >= TRUNC (p_in_date);

      RETURN v_period_name;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message, 'p_in_date ', p_in_date);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_period_name',
            MESSAGE     => v_error_message);
         raise_application_error (-20206, v_error_message);
   END get_period_name;

   FUNCTION get_cust_trx_type (
      p_in_cust_trx_type_id   IN ra_customer_trx_all.cust_trx_type_id%TYPE,
      p_in_org_id             IN NUMBER)
      RETURN ra_cust_trx_types_all.TYPE%TYPE
   IS
      v_cust_trx_type   ra_cust_trx_types_all.TYPE%TYPE;
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'GET_CUST_TRX_TYPE';
   BEGIN
      SELECT TYPE
        INTO v_cust_trx_type
        FROM ra_cust_trx_types_all
       WHERE     1 = 1
             AND cust_trx_type_id = p_in_cust_trx_type_id
             AND org_id = p_in_org_id;

      RETURN v_cust_trx_type;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_cust_trx_type_id ',
                         p_in_cust_trx_type_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_cust_trx_type',
            MESSAGE     => v_error_message);
         raise_application_error (-20207, v_error_message);
   END get_cust_trx_type;

   FUNCTION get_term_name (
      p_in_customer_id   IN hz_cust_accounts.cust_account_id%TYPE)
      RETURN ra_terms.NAME%TYPE
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE := 'GET_TERM_NAME';
      v_term_name       ra_terms.NAME%TYPE := NULL;
   BEGIN
      SELECT term.NAME
        INTO v_term_name
        FROM hz_cust_accounts        cust,
             ra_terms                term,
             hz_cust_profile_classes cpc,
             hz_customer_profiles    cp
       WHERE     1 = 1
             AND term.term_id(+) = cpc.standard_terms
             AND cp.cust_account_id = cust.cust_account_id
             AND cp.site_use_id IS NULL
             AND cp.profile_class_id = cpc.profile_class_id(+)
             AND cust.cust_account_id = p_in_customer_id;

      RETURN v_term_name;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_customer_id ',
                         p_in_customer_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (log_level   => fnd_log.level_unexpected,
                         module      => 'cust_ar_agrupador_pkg.get_term_name',
                         MESSAGE     => v_error_message);
         raise_application_error (-20208, v_error_message);
   END get_term_name;

   FUNCTION is_customer_grouped (
      p_in_address_id   IN hz_cust_acct_sites_all.cust_acct_site_id%TYPE)
      RETURN BOOLEAN
   IS
      v_tipo_de_facturacion    hz_cust_acct_sites_all.attribute8%TYPE;
      v_error_message          fnd_log_messages.MESSAGE_TEXT%TYPE
                                  := 'IS_CUSTOMER_GROUPED';
      c_agrupada      CONSTANT VARCHAR2 (1) := '1';
      c_no_agrupada   CONSTANT VARCHAR2 (1) := '2';
   BEGIN
      SELECT cas.attribute8 tipo_de_facturacion
        INTO v_tipo_de_facturacion
        FROM hz_cust_acct_sites_all cas
       WHERE 1 = 1 AND cas.cust_acct_site_id = p_in_address_id;

      IF NVL (v_tipo_de_facturacion, c_no_agrupada) = c_agrupada
      THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_address_id ',
                         p_in_address_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.is_customer_grouped',
            MESSAGE     => v_error_message);
         raise_application_error (-20209, v_error_message);
   END is_customer_grouped;

   FUNCTION is_refactura (
      p_in_batch_source_id   IN ra_batch_sources_all.batch_source_id%TYPE,
      p_org_id               IN NUMBER)
      RETURN BOOLEAN
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE := 'IS_REFACTURA';
      v_name            ra_batch_sources_all.NAME%TYPE := NULL;
   BEGIN
      SELECT MAX (NAME)
        INTO v_name
        FROM ra_batch_sources_all
       WHERE batch_source_id = p_in_batch_source_id AND org_id = p_org_id;

      IF UPPER (v_name) LIKE '%-RE%'
      THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (
                  'BATCH:'
               || p_in_batch_source_id
               || 'ORG'
               || P_ORG_ID
               || ','
               || SQLERRM
               || CHR (10)
               || v_error_message,
               1,
               4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_batch_source_id ',
                         p_in_batch_source_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (log_level   => fnd_log.level_unexpected,
                         module      => 'cust_ar_agrupador_pkg.is_refactura',
                         MESSAGE     => v_error_message);
         raise_application_error (-20210, v_error_message);
   END is_refactura;

   PROCEDURE get_regla_agrupa_info (
      p_in_customer_id     IN     hz_cust_accounts.cust_account_id%TYPE,
      p_out_periodo           OUT ar_regla_agrupa.periodo%TYPE,
      p_out_localidades       OUT ar_regla_agrupa.localidades%TYPE,
      p_out_agrupador_id      OUT ar_regla_agrupa_sucursales.agrupador_id%TYPE)
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'GET_REGLA_AGRUPA_INFO';
   BEGIN
      SELECT ra.periodo, ra.localidades, ras.agrupador_id
        INTO p_out_periodo, p_out_localidades, p_out_agrupador_id
        FROM ar_regla_agrupa ra, ar.ar_regla_agrupa_sucursales ras
       WHERE     1 = 1
             AND ra.org_id = fnd_profile.VALUE ('org_id')
             AND ra.fecha_inicial <= TRUNC (SYSDATE)
             AND NVL (ra.fecha_final, TRUNC (SYSDATE + 1)) > TRUNC (SYSDATE)
             AND ras.fecha_inicial <= TRUNC (SYSDATE)
             AND NVL (ras.fecha_final, TRUNC (SYSDATE + 1)) > TRUNC (SYSDATE)
             AND ra.activo = 'Y'
             AND ra.agrupador_id = ras.agrupador_id
             AND ras.customer_id = p_in_customer_id;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         p_out_periodo := c_desconocido;
         p_out_localidades := c_desconocido;
         p_out_agrupador_id := -1;
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_customer_id ',
                         p_in_customer_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_regla_agrupa_info',
            MESSAGE     => v_error_message);
         raise_application_error (-20211, v_error_message);
   END get_regla_agrupa_info;

   FUNCTION get_cedis (
      p_in_num_cedis          IN ra_customer_trx_all.attribute12%TYPE,
      p_in_cust_trx_type_id   IN ra_customer_trx_all.cust_trx_type_id%TYPE)
      RETURN ar.ar_cedis_sio.num_cedis%TYPE
   IS
      v_num_cedis       ar.ar_cedis_sio.num_cedis%TYPE;
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE := 'GET_CEDIS';
   BEGIN
      IF p_in_num_cedis IS NOT NULL
      THEN
         BEGIN
            RETURN p_in_num_cedis;
         EXCEPTION
            WHEN OTHERS
            THEN
               NULL;
         END;
      END IF;

      SELECT SUBSTR (NAME, INSTR (NAME, '-', -1) + 1) num_cedis
        INTO v_num_cedis
        FROM ra_cust_trx_types_all
       WHERE 1 = 1 AND cust_trx_type_id = p_in_cust_trx_type_id;

      RETURN v_num_cedis;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_num_cedis        ',
                         p_in_num_cedis);
         concat_message (v_error_message,
                         'p_in_cust_trx_type_id ',
                         p_in_cust_trx_type_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (log_level   => fnd_log.level_unexpected,
                         module      => 'cust_ar_agrupador_pkg.get_cedis',
                         MESSAGE     => v_error_message);
         raise_application_error (-20212, v_error_message);
   END get_cedis;

   FUNCTION get_cedis_sio_info (
      p_in_num_ceids   IN ar.ar_cedis_sio.num_cedis%TYPE,
      p_in_column      IN VARCHAR2)
      RETURN VARCHAR2
   IS
      v_error_message     fnd_log_messages.MESSAGE_TEXT%TYPE
                             := 'GET_CEDIS_SIO_INFO';
      v_valor_localidad   VARCHAR2 (255) := NULL;
   BEGIN
      SELECT DECODE (p_in_column,
                     'REGION', region,
                     'ZONA', zona,
                     'CIUDAD', ciudad,
                     'NUM_CEDIS', num_cedis,
                     'UO', uo)
                valor_localidad
        INTO v_valor_localidad
        FROM ar.ar_cedis_sio
       WHERE     1 = 1
             AND num_cedis = p_in_num_ceids
             AND org_id = fnd_profile.VALUE ('ORG_ID');

      RETURN NVL (v_valor_localidad, c_desconocido);
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN c_desconocido;
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message, 'p_in_num_ceids ', p_in_num_ceids);
         concat_message (v_error_message, 'p_in_column    ', p_in_column);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id     ',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_cedis_sio_info',
            MESSAGE     => v_error_message);
         raise_application_error (-20213, v_error_message);
   END get_cedis_sio_info;

   FUNCTION get_header_id (
      p_in_grouping_header_rec   IN cust_ar_grouping_header%ROWTYPE)
      RETURN cust_ar_grouping_header.header_id%TYPE
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE := 'GET_HEADER_ID';
      v_header_id       cust_ar_grouping_header.header_id%TYPE := NULL;
      v_count           NUMBER;
   BEGIN
      SELECT MIN (header_id), COUNT (1)
        INTO v_header_id, v_count
        FROM cust_ar_grouping_header
       WHERE     1 = 1
             AND status = c_nuevo
             AND unidad_operativa = p_in_grouping_header_rec.unidad_operativa
             AND territory_segment1 =
                    p_in_grouping_header_rec.territory_segment1
             AND periodo = p_in_grouping_header_rec.periodo
             AND localidades = p_in_grouping_header_rec.localidades
             AND valor_localidad = p_in_grouping_header_rec.valor_localidad
             AND invoice_currency_code =
                    p_in_grouping_header_rec.invoice_currency_code
             AND exchange_rate = p_in_grouping_header_rec.exchange_rate
             AND agrupador_id = p_in_grouping_header_rec.agrupador_id
             AND status = p_in_grouping_header_rec.status
             AND valor_periodo = p_in_grouping_header_rec.valor_periodo
             AND period_name = p_in_grouping_header_rec.period_name
             AND bill_to_customer_id =
                    p_in_grouping_header_rec.bill_to_customer_id;

      IF v_count > 1
      THEN
         UPDATE cust_ar_grouping_trx trx
            SET header_id = v_header_id
          WHERE EXISTS
                   (SELECT '1'
                      FROM cust_ar_grouping_header h
                     WHERE     1 = 1
                           AND trx.header_id = h.header_id
                           AND header_id <> v_header_id
                           AND unidad_operativa =
                                  p_in_grouping_header_rec.unidad_operativa
                           AND territory_segment1 =
                                  p_in_grouping_header_rec.territory_segment1
                           AND periodo = p_in_grouping_header_rec.periodo
                           AND localidades =
                                  p_in_grouping_header_rec.localidades
                           AND valor_localidad =
                                  p_in_grouping_header_rec.valor_localidad
                           AND invoice_currency_code =
                                  p_in_grouping_header_rec.invoice_currency_code
                           AND exchange_rate =
                                  p_in_grouping_header_rec.exchange_rate
                           AND agrupador_id =
                                  p_in_grouping_header_rec.agrupador_id
                           AND status = p_in_grouping_header_rec.status
                           AND valor_periodo =
                                  p_in_grouping_header_rec.valor_periodo
                           AND period_name =
                                  p_in_grouping_header_rec.period_name
                           AND bill_to_customer_id =
                                  p_in_grouping_header_rec.bill_to_customer_id);

         DELETE FROM cust_ar_grouping_header h
               WHERE     1 = 1
                     AND header_id <> v_header_id
                     AND unidad_operativa =
                            p_in_grouping_header_rec.unidad_operativa
                     AND territory_segment1 =
                            p_in_grouping_header_rec.territory_segment1
                     AND periodo = p_in_grouping_header_rec.periodo
                     AND localidades = p_in_grouping_header_rec.localidades
                     AND valor_localidad =
                            p_in_grouping_header_rec.valor_localidad
                     AND invoice_currency_code =
                            p_in_grouping_header_rec.invoice_currency_code
                     AND exchange_rate =
                            p_in_grouping_header_rec.exchange_rate
                     AND agrupador_id = p_in_grouping_header_rec.agrupador_id
                     AND status = p_in_grouping_header_rec.status
                     AND valor_periodo =
                            p_in_grouping_header_rec.valor_periodo
                     AND period_name = p_in_grouping_header_rec.period_name
                     AND bill_to_customer_id =
                            p_in_grouping_header_rec.bill_to_customer_id;
      END IF;

      RETURN v_header_id;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN -1;
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'periodo               ',
                         p_in_grouping_header_rec.periodo);
         concat_message (v_error_message,
                         'localidades           ',
                         p_in_grouping_header_rec.localidades);
         concat_message (v_error_message,
                         'valor_localidad       ',
                         p_in_grouping_header_rec.valor_localidad);
         concat_message (v_error_message,
                         'invoice_currency_code ',
                         p_in_grouping_header_rec.invoice_currency_code);
         concat_message (v_error_message,
                         'exchange_rate         ',
                         p_in_grouping_header_rec.exchange_rate);
         concat_message (v_error_message,
                         'agrupador_id          ',
                         p_in_grouping_header_rec.agrupador_id);
         concat_message (v_error_message,
                         'status                ',
                         p_in_grouping_header_rec.status);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (log_level   => fnd_log.level_unexpected,
                         module      => 'cust_ar_agrupador_pkg.get_header_id',
                         MESSAGE     => v_error_message);
         raise_application_error (-20214, v_error_message);
   END get_header_id;

   FUNCTION get_trx_grouping_status (
      p_in_customer_trx_id   IN cust_ar_grouping_trx.customer_trx_id%TYPE)
      RETURN cust_ar_grouping_header.status%TYPE
   IS
      v_grouping_status   cust_ar_grouping_trx.grouping_status%TYPE := NULL;
      v_error_message     fnd_log_messages.MESSAGE_TEXT%TYPE
                             := 'GET_TRX_GROUPING_STATUS';
   BEGIN
      SELECT UPPER (grouping_status) grouping_status
        INTO v_grouping_status
        FROM cust_ar_grouping_trx
       WHERE customer_trx_id = p_in_customer_trx_id;

      RETURN NVL (v_grouping_status, c_desconocido);
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN c_no_existe;
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_customer_trx_id ',
                         p_in_customer_trx_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_trx_grouping_status',
            MESSAGE     => v_error_message);
         raise_application_error (-20215, v_error_message);
   END get_trx_grouping_status;

   PROCEDURE set_trx_grouping_status (
      p_in_customer_trx_id   IN cust_ar_grouping_trx.customer_trx_id%TYPE,
      p_in_grouping_status   IN cust_ar_grouping_trx.grouping_status%TYPE)
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'SET_TRX_GROUPING_STATUS';
   BEGIN
      IF cust_ar_agrupador_pkg.get_trx_grouping_status (p_in_customer_trx_id) IN
            (c_correcto, c_advertencia)
      THEN
         raise_application_error (
            -20216,
            'Esta  transaccion ya fue agrupada, no es posible cambiar su estatus');
      END IF;

      UPDATE cust_ar_grouping_trx
         SET grouping_status =
                DECODE (grouping_status,
                        c_correcto, c_correcto,
                        p_in_grouping_status),
             request_id = NVL (l_conc_request_id, request_id),
             last_update_date = SYSDATE,
             last_updated_by = NVL (fnd_profile.VALUE ('USER_ID'), -1)
       WHERE customer_trx_id = p_in_customer_trx_id;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_customer_trx_id ',
                         p_in_customer_trx_id);
         concat_message (v_error_message,
                         'p_in_grouping_status ',
                         p_in_grouping_status);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.set_trx_grouping_status',
            MESSAGE     => v_error_message);
         raise_application_error (-20217, v_error_message);
   END set_trx_grouping_status;

   PROCEDURE set_trx_header_id (
      p_in_customer_trx_id   IN cust_ar_grouping_trx.customer_trx_id%TYPE,
      p_in_old_header_id     IN cust_ar_grouping_trx.header_id%TYPE,
      p_in_new_header_id     IN cust_ar_grouping_trx.header_id%TYPE)
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'SET_TRX_HEADER_ID';
   BEGIN
      IF cust_ar_agrupador_pkg.get_trx_grouping_status (p_in_customer_trx_id) NOT IN
            (c_nuevo, c_error)
      THEN
         raise_application_error (-20218,
                                  'EStado de transaccion no esperado');
      END IF;

      IF cust_ar_agrupador_pkg.get_header_status (p_in_old_header_id) NOT IN
            (c_nuevo, c_error)
      THEN
         raise_application_error (-20219, 'Estado de cabecera no esperado');
      END IF;

      UPDATE cust_ar_grouping_trx
         SET header_id = p_in_new_header_id,
             request_id = NVL (l_conc_request_id, request_id),
             last_update_date = SYSDATE,
             last_updated_by = NVL (fnd_profile.VALUE ('USER_ID'), -1)
       WHERE     1 = 1
             AND header_id = p_in_old_header_id
             AND customer_trx_id = p_in_customer_trx_id;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_customer_trx_id ',
                         p_in_customer_trx_id);
         concat_message (v_error_message,
                         'p_in_old_header_id   ',
                         p_in_old_header_id);
         concat_message (v_error_message,
                         'p_in_new_header_id   ',
                         p_in_new_header_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id           ',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.set_trx_header_id',
            MESSAGE     => v_error_message);
         raise_application_error (-20220, v_error_message);
   END set_trx_header_id;

   FUNCTION get_header_status (
      p_in_header_id   IN cust_ar_grouping_header.header_id%TYPE)
      RETURN cust_ar_grouping_header.status%TYPE
   IS
      v_status          cust_ar_grouping_header.status%TYPE := NULL;
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'GET_HEADER_STATUS';
   BEGIN
      SELECT UPPER (status) status
        INTO v_status
        FROM cust_ar_grouping_header
       WHERE header_id = p_in_header_id;

      RETURN NVL (v_status, c_desconocido);
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN c_no_existe;
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message, 'p_in_header_id ', p_in_header_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_header_status',
            MESSAGE     => v_error_message);
         raise_application_error (-20221, v_error_message);
   END get_header_status;

   PROCEDURE set_header_status (
      p_in_header_id   IN cust_ar_grouping_header.header_id%TYPE,
      p_in_status      IN cust_ar_grouping_header.status%TYPE)
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'SET_HEADER_STATUS';
      v_grouping_date   DATE := NULL;
   BEGIN
      IF p_in_status = c_correcto
      THEN
         v_grouping_date := SYSDATE;
      END IF;

      UPDATE cust_ar_grouping_header
         SET status = DECODE (status, c_correcto, c_correcto, p_in_status),
             request_id = NVL (l_conc_request_id, request_id),
             last_update_date = SYSDATE,
             last_updated_by = NVL (fnd_profile.VALUE ('USER_ID'), -1)
       WHERE header_id = p_in_header_id;

      UPDATE cust_ar_grouping_trx
         SET grouping_status =
                DECODE (grouping_status, c_correcto, c_correcto, p_in_status),
             request_id = NVL (l_conc_request_id, request_id),
             last_update_date = SYSDATE,
             last_updated_by = NVL (fnd_profile.VALUE ('USER_ID'), -1),
             grouping_date =
                DECODE (grouping_status,
                        c_correcto, c_correcto,
                        v_grouping_date)
       WHERE header_id = p_in_header_id;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message, 'p_in_header_id ', p_in_header_id);
         concat_message (v_error_message, 'p_in_status ', p_in_status);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.set_header_status',
            MESSAGE     => v_error_message);
         raise_application_error (-20222, v_error_message);
   END set_header_status;

   FUNCTION get_trx_cm_status (
      p_in_customer_trx_id   IN cust_ar_grouping_trx.customer_trx_id%TYPE)
      RETURN cust_ar_grouping_trx.credit_memo_status%TYPE
   IS
      l_trx_type               ra_cust_trx_types_all.name%TYPE;
      l_amount_due_original    NUMBER;
      l_amount_due_remaining   NUMBER;
      l_amount_credited        NUMBER;
   BEGIN
      SELECT amount_due_original, amount_due_remaining, amount_credited
        INTO l_amount_due_original, l_amount_due_remaining, l_amount_credited
        FROM ar_payment_schedules_all aps
       WHERE customer_trx_id = p_in_customer_trx_id;

      IF l_amount_due_original = l_amount_due_remaining
      THEN
         RETURN 'P';
      ELSIF ABS (l_amount_due_original) = ABS (l_amount_credited)
      THEN
         SELECT rctt.name
           INTO l_trx_type
           FROM ar_receivable_applications_all ara,
                ar_payment_schedules_all       trx,
                ar_payment_schedules_all       cm,
                ra_cust_trx_types_all          rctt
          WHERE     trx.customer_trx_id = p_in_customer_trx_id
                AND ara.applied_customer_trx_id = trx.customer_trx_id
                AND cm.payment_schedule_id = ara.payment_Schedule_id
                AND rctt.cust_trx_type_id = cm.cust_trx_type_id;

         IF INSTR (l_trx_type, '-AG-') > 0
         THEN
            RETURN c_correcto;
         ELSE
            RETURN c_error;
         END IF;
      ELSE
         RETURN c_advertencia;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN c_desconocido;
   END;

   FUNCTION get_header_cm_status (
      p_in_header_id   IN cust_ar_grouping_header.header_id%TYPE)
      RETURN cust_ar_grouping_header.cm_status%TYPE
   IS
      v_cm_status       cust_ar_grouping_header.cm_status%TYPE := NULL;
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'GET_HEADER_CM_STATUS';
   BEGIN
      SELECT UPPER (cm_status) cm_status
        INTO v_cm_status
        FROM cust_ar_grouping_header
       WHERE header_id = p_in_header_id;

      RETURN NVL (v_cm_status, c_desconocido);
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN c_no_existe;
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message, 'p_in_header_id ', p_in_header_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_header_cm_status',
            MESSAGE     => v_error_message);
         raise_application_error (-20223, v_error_message);
   END get_header_cm_status;

   PROCEDURE set_header_cm_status (
      p_in_header_id   IN cust_ar_grouping_header.header_id%TYPE)
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'SET_HEADER_CM_STATUS';

      CURSOR trx_to_credit_error_cur
      IS
         SELECT 'X'
           FROM cust_ar_grouping_trx gt
          WHERE     1 = 1
                AND gt.credit_memo_status NOT IN (c_correcto, c_no_existe)
                AND gt.header_id = p_in_header_id;

      CURSOR trx_to_credit_correcto_cur
      IS
         SELECT 'X'
           FROM cust_ar_grouping_trx gt
          WHERE     1 = 1
                AND gt.credit_memo_status = c_correcto
                AND gt.header_id = p_in_header_id;

      v_dummy           VARCHAR2 (1);
   BEGIN
      IF cust_ar_agrupador_pkg.get_header_cm_status (p_in_header_id) =
            c_correcto
      THEN
         RETURN;
      END IF;

      OPEN trx_to_credit_error_cur;

      FETCH trx_to_credit_error_cur INTO v_dummy;

      IF trx_to_credit_error_cur%NOTFOUND
      THEN
         OPEN trx_to_credit_correcto_cur;

         FETCH trx_to_credit_correcto_cur INTO v_dummy;

         IF NOT trx_to_credit_correcto_cur%NOTFOUND
         THEN
            UPDATE cust_ar_grouping_header
               SET cm_status = c_correcto,
                   request_id = NVL (l_conc_request_id, request_id),
                   last_update_date = SYSDATE,
                   last_updated_by = NVL (fnd_profile.VALUE ('USER_ID'), -1)
             WHERE header_id = p_in_header_id;

            COMMIT;
         END IF;
      ELSE
         UPDATE cust_ar_grouping_header
            SET cm_status = c_error,
                request_id = NVL (l_conc_request_id, request_id),
                last_update_date = SYSDATE,
                last_updated_by = NVL (fnd_profile.VALUE ('USER_ID'), -1)
          WHERE header_id = p_in_header_id;

         COMMIT;
      END IF;

      IF trx_to_credit_error_cur%ISOPEN
      THEN
         CLOSE trx_to_credit_error_cur;
      END IF;

      IF trx_to_credit_correcto_cur%ISOPEN
      THEN
         CLOSE trx_to_credit_correcto_cur;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         IF trx_to_credit_error_cur%ISOPEN
         THEN
            CLOSE trx_to_credit_error_cur;
         END IF;

         IF trx_to_credit_correcto_cur%ISOPEN
         THEN
            CLOSE trx_to_credit_correcto_cur;
         END IF;

         ROLLBACK;
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message, 'p_in_header_id ', p_in_header_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.set_header_cm_status',
            MESSAGE     => v_error_message);
         raise_application_error (-20224, v_error_message);
   END set_header_cm_status;

   PROCEDURE insert_grouping_header (
      p_io_grouping_header_rec   IN OUT cust_ar_grouping_header%ROWTYPE)
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'INSERT_GROUPING_HEADER';
   BEGIN
      p_io_grouping_header_rec.header_id :=
         cust_ar_agrupador_pkg.get_header_sequence;
      p_io_grouping_header_rec.org_id := fnd_profile.VALUE ('ORG_ID');
      p_io_grouping_header_rec.request_id := l_conc_request_id;
      p_io_grouping_header_rec.last_update_date := SYSDATE;
      p_io_grouping_header_rec.last_updated_by :=
         fnd_profile.VALUE ('USER_ID');
      p_io_grouping_header_rec.creation_date := TRUNC (SYSDATE);
      p_io_grouping_header_rec.created_by :=
         fnd_profile.VALUE ('USER_ID');
      p_io_grouping_header_rec.cm_status := c_nuevo;
      p_io_grouping_header_rec.status := c_nuevo;

      INSERT INTO cust_ar_grouping_header
           VALUES p_io_grouping_header_rec;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'header_id             ',
                         p_io_grouping_header_rec.header_id);
         concat_message (v_error_message,
                         'org_id                ',
                         p_io_grouping_header_rec.org_id);
         concat_message (v_error_message,
                         'status                ',
                         p_io_grouping_header_rec.status);
         concat_message (v_error_message,
                         'agrupador_id          ',
                         p_io_grouping_header_rec.agrupador_id);
         concat_message (v_error_message,
                         'bill_to_customer_id   ',
                         p_io_grouping_header_rec.bill_to_customer_id);
         concat_message (v_error_message,
                         'bill_to_address_id    ',
                         p_io_grouping_header_rec.bill_to_address_id);
         concat_message (v_error_message,
                         'ship_to_address_id    ',
                         p_io_grouping_header_rec.ship_to_address_id);
         concat_message (v_error_message,
                         'invoice_currency_code ',
                         p_io_grouping_header_rec.invoice_currency_code);
         concat_message (v_error_message,
                         'exchange_rate         ',
                         p_io_grouping_header_rec.exchange_rate);
         concat_message (v_error_message,
                         'periodo               ',
                         p_io_grouping_header_rec.periodo);
         concat_message (v_error_message,
                         'localidades           ',
                         p_io_grouping_header_rec.localidades);
         concat_message (v_error_message,
                         'valor_localidad       ',
                         p_io_grouping_header_rec.valor_localidad);
         concat_message (v_error_message,
                         'request_id            ',
                         p_io_grouping_header_rec.request_id);
         concat_message (v_error_message,
                         'last_update_date      ',
                         p_io_grouping_header_rec.last_update_date);
         concat_message (v_error_message,
                         'last_updated_by       ',
                         p_io_grouping_header_rec.last_updated_by);
         concat_message (v_error_message,
                         'creation_date         ',
                         p_io_grouping_header_rec.creation_date);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.insert_grouping_header',
            MESSAGE     => v_error_message);
         raise_application_error (-20225, v_error_message);
   END insert_grouping_header;

   FUNCTION get_header_sequence
      RETURN NUMBER
   IS
      v_sequence        NUMBER := NULL;
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'GET_HEADER_SEQUENCE';
   BEGIN
      SELECT cust_ar_grouping_header_s.NEXTVAL INTO v_sequence FROM DUAL;

      RETURN v_sequence;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_header_sequence',
            MESSAGE     => v_error_message);
         raise_application_error (-20226, v_error_message);
   END get_header_sequence;

   FUNCTION get_cust_trx_type_name (
      p_in_org_id               IN ra_cust_trx_types_all.org_id%TYPE,
      p_in_cust_trx_type_name   IN ra_cust_trx_types_all.NAME%TYPE,
      p_in_type                 IN ra_cust_trx_types_all.TYPE%TYPE,
      p_in_unidad_operativa     IN gl_code_combinations.segment2%TYPE)
      RETURN ra_cust_trx_types_all.NAME%TYPE
   IS
      v_cust_trx_type_name   ra_cust_trx_types_all.NAME%TYPE := NULL;
      v_error_message        fnd_log_messages.MESSAGE_TEXT%TYPE
                                := 'GET_CUST_TRX_TYPE_NAME';
      v_unidad_operativa     gl_code_combinations.segment2%TYPE;
   BEGIN
      v_unidad_operativa :=
         NVL (p_in_unidad_operativa,
              fnd_profile.VALUE ('CUST_AR_UNIDAD_OPERATIVA'));

      SELECT ctt.NAME
        INTO v_cust_trx_type_name
        FROM ar.ra_cust_trx_types_all ctt, gl_code_combinations gcc
       WHERE     1 = 1
             AND NVL (end_date, SYSDATE) >= SYSDATE
             AND start_date <= SYSDATE
             AND gcc.segment3 = v_unidad_operativa
             AND ctt.gl_id_rev = gcc.code_combination_id
             AND ctt.org_id = p_in_org_id
             AND ctt.TYPE = p_in_type
             AND ctt.NAME LIKE p_in_cust_trx_type_name;

      RETURN v_cust_trx_type_name;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_org_id             ',
                         p_in_org_id);
         concat_message (v_error_message,
                         'p_in_cust_trx_type_name ',
                         p_in_cust_trx_type_name);
         concat_message (v_error_message,
                         'p_in_type               ',
                         p_in_type);
         concat_message (v_error_message,
                         'p_in_unidad_operativa   ',
                         p_in_unidad_operativa);
         concat_message (v_error_message,
                         'v_unidad_operativa      ',
                         v_unidad_operativa);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_cust_trx_type_name',
            MESSAGE     => v_error_message);
         raise_application_error (-20227, v_error_message);
   END get_cust_trx_type_name;

   FUNCTION get_batch_source_name (
      p_in_org_id              IN ra_batch_sources_all.org_id%TYPE,
      p_in_batch_source_name   IN ra_batch_sources_all.NAME%TYPE,
      p_in_type                IN ra_batch_sources_all.attribute3%TYPE)
      RETURN ra_batch_sources_all.NAME%TYPE
   IS
      v_batch_sources_name   ra_batch_sources_all.NAME%TYPE := NULL;
      v_error_message        fnd_log_messages.MESSAGE_TEXT%TYPE
                                := 'GET_BATCH_SOURCE_NAME';
   BEGIN
      SELECT bs.NAME
        INTO v_batch_sources_name
        FROM ar.ra_batch_sources_all bs
       WHERE     1 = 1
             AND bs.org_id = p_in_org_id
             AND bs.NAME LIKE p_in_batch_source_name
             AND bs.NAME NOT LIKE '%-RE'
             AND bs.attribute3 = p_in_type
             AND BS.BATCH_SOURCE_TYPE = CASE WHEN p_in_type = 'INV' --se agreag condicion para validar nota de credito o factura  jibarra 28mar2018
                                             THEN BATCH_SOURCE_TYPE
                                             --ELSE 'FOREIGN'
                                             ELSE 'INV'
                                             END   
             AND bs.status = 'A';

      RETURN v_batch_sources_name;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_org_id             ',
                         p_in_org_id);
         concat_message (v_error_message,
                         'p_in_batch_source_name  ',
                         p_in_batch_source_name);
         concat_message (v_error_message,
                         'p_in_type               ',
                         p_in_type);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_batch_source_name',
            MESSAGE     => v_error_message);
         raise_application_error (-20228, v_error_message);
   END get_batch_source_name;

   FUNCTION get_valor_periodo (p_in_clave_periodo   IN VARCHAR2,
                               p_in_date            IN DATE)
      RETURN VARCHAR2
   IS
      v_error_message        fnd_log_messages.MESSAGE_TEXT%TYPE
                                := 'GET_VALOR_PERIODO';
      v_valor_periodo        cust_ar_grouping_header.valor_periodo%TYPE := NULL;
      c_diario      CONSTANT VARCHAR2 (1) := 'D';
      c_semanal     CONSTANT VARCHAR2 (1) := 'S';
      c_quincenal   CONSTANT VARCHAR2 (1) := 'Q';
      c_mensual     CONSTANT VARCHAR2 (1) := 'M';
   BEGIN
      CASE p_in_clave_periodo
         WHEN c_diario
         THEN
            v_valor_periodo := TO_CHAR (p_in_date, 'YYYYMMDD');
         WHEN c_semanal
         THEN
            IF TO_CHAR (p_in_date, 'IW') in ('52','53') and to_char(p_in_date,'dd-mm')='01-01' THEN
                v_valor_periodo := TO_CHAR (p_in_date, 'YYYY') || '01';
            ELSE
            v_valor_periodo := TO_CHAR (p_in_date, 'YYYYIW');
            END IF;
         WHEN c_quincenal
         THEN
            v_valor_periodo := TO_CHAR (p_in_date, 'DD');

            IF TO_NUMBER (v_valor_periodo) <= 15
            THEN
               v_valor_periodo := TO_CHAR (p_in_date, 'YYYYMM') || '01';
            ELSE
               v_valor_periodo := TO_CHAR (p_in_date, 'YYYYMM') || '02';
            END IF;
         WHEN c_mensual
         THEN
            v_valor_periodo := TO_CHAR (p_in_date, 'YYYYMM');
         WHEN c_desconocido
         THEN
            v_valor_periodo := TO_CHAR (p_in_date, 'YYYYMM');
         ELSE
            raise_application_error (
               -20229,
                  'Error, Valor para PERIODO no esperado '''
               || p_in_clave_periodo
               || '''');
      END CASE;

      RETURN v_valor_periodo;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_clave_periodo  ',
                         p_in_clave_periodo);
         concat_message (v_error_message, 'p_in_date           ', p_in_date);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_valor_periodo',
            MESSAGE     => v_error_message);
         raise_application_error (-20230, v_error_message);
   END get_valor_periodo;

   FUNCTION get_ultimo_periodo (p_in_clave_periodo   IN VARCHAR2,
                                p_in_date            IN DATE DEFAULT SYSDATE)
      RETURN VARCHAR2
   IS
      v_error_message        fnd_log_messages.MESSAGE_TEXT%TYPE
                                := 'GET_ULTIMO_PERIODO';
      v_valor_periodo        cust_ar_grouping_header.valor_periodo%TYPE := NULL;
      c_diario      CONSTANT VARCHAR2 (1) := 'D';
      c_semanal     CONSTANT VARCHAR2 (1) := 'S';
      c_quincenal   CONSTANT VARCHAR2 (1) := 'Q';
      c_mensual     CONSTANT VARCHAR2 (1) := 'M';
   BEGIN
      v_valor_periodo :=
         cust_ar_agrupador_pkg.get_valor_periodo (
            p_in_clave_periodo   => p_in_clave_periodo,
            p_in_date            => p_in_date);

      CASE p_in_clave_periodo
         WHEN c_diario
         THEN
            v_valor_periodo :=
               cust_ar_agrupador_pkg.get_valor_periodo (
                  p_in_clave_periodo   => p_in_clave_periodo,
                  p_in_date            => p_in_date - 1);
         WHEN c_semanal
         THEN
            IF v_valor_periodo LIKE '%01'
            THEN
               v_valor_periodo :=
                  cust_ar_agrupador_pkg.get_valor_periodo (
                     p_in_clave_periodo   => p_in_clave_periodo,
                     p_in_date            => TRUNC (p_in_date, 'YEAR') - 1);
            ELSE
               v_valor_periodo :=
                  TO_CHAR (TO_NUMBER (v_valor_periodo) - 1, 'FM000000');
            END IF;
         WHEN c_quincenal
         THEN
            IF v_valor_periodo LIKE '%01'
            THEN
               v_valor_periodo :=
                  cust_ar_agrupador_pkg.get_valor_periodo (
                     p_in_clave_periodo   => p_in_clave_periodo,
                     p_in_date            =>   TO_DATE (v_valor_periodo,
                                                        'YYYYMMDD')
                                             - 1);
            ELSE
               v_valor_periodo := TO_CHAR (p_in_date, 'YYYYMM') || '02';
               v_valor_periodo :=
                  TO_CHAR (TO_NUMBER (v_valor_periodo) - 1, 'FM00000000');
            END IF;
         WHEN c_mensual
         THEN
            IF v_valor_periodo LIKE '%01'
            THEN
               v_valor_periodo :=
                  cust_ar_agrupador_pkg.get_valor_periodo (
                     p_in_clave_periodo   => p_in_clave_periodo,
                     p_in_date            => TRUNC (p_in_date, 'YEAR') - 1);
            ELSE
               v_valor_periodo :=
                  TO_CHAR (TO_NUMBER (v_valor_periodo) - 1, 'FM000000');
            END IF;
         ELSE
            raise_application_error (
               -20231,
                  'Error, Valor para PERIODO no esperado '''
               || p_in_clave_periodo
               || '''');
      END CASE;

      RETURN v_valor_periodo;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_clave_periodo ',
                         p_in_clave_periodo);
         concat_message (v_error_message, 'p_in_date          ', p_in_date);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_ultimo_periodo',
            MESSAGE     => v_error_message);
         raise_application_error (-20232, v_error_message);
   END get_ultimo_periodo;

   FUNCTION get_grouping_trx_date (p_in_clave_periodo   IN VARCHAR2,
                                   p_in_valor_periodo   IN VARCHAR2)
      RETURN DATE
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      v_direc_id             ar_regla_agrupa_suc_direc.direc_id%TYPE := NULL;
      v_error_message        fnd_log_messages.MESSAGE_TEXT%TYPE
                                := 'GET_GROUPING_TRX_DATE';
      c_diario      CONSTANT VARCHAR2 (1) := 'D';
      c_semanal     CONSTANT VARCHAR2 (1) := 'S';
      c_quincenal   CONSTANT VARCHAR2 (1) := 'Q';
      c_mensual     CONSTANT VARCHAR2 (1) := 'M';
      l_trx_date             DATE;
      l_anio_mes             VARCHAR2 (10);

      V_NOMBRE_PERIODO       VARCHAR2 (100);
      V_ESTATUS_PERIODO      VARCHAR2 (100);
      V_LANGUAJE             VARCHAR2 (100);
   BEGIN
      /*  SE AGREGA LA FUNCION DE OBTENER EL NOMBRE DEL PERIODO PARA QUE SE OBTENGA SU ESTATUS
      *   SI EL PERIODO ESTA CERRADO EN UN AGRUPADOR SEMANAL SE RETORNARA EL ULTIMO DIA DEL PERIODO
      *   ANTERIOR QUE ES EL QUE ESTA ABIERTO, SI YA ESTA ABIERTO EL PERIODO ACTUAL SE VALIDA LA FECHA CORRECTA
      *   JIBARRA 25-OCT-2017
      */
      SELECT USERENV ('LANG') INTO V_LANGUAJE FROM DUAL;

      O('XXX V_LANGUAJE:: ' || V_LANGUAJE);

      CASE p_in_clave_periodo
         WHEN c_diario
         THEN
            RETURN TO_DATE (p_in_valor_periodo, 'YYYYMMDD');
         WHEN c_semanal
         THEN
            declare
                v_no_semana number;
            begin
                --v_no_semana:= SUBSTR (p_in_valor_periodo, -2);


                l_trx_date := TO_DATE (SUBSTR (p_in_valor_periodo, -2) * 7 - 2, 'DDD');
                DBMS_OUTPUT.PUT_LINE('XXX l_trx_date:: ' || l_trx_date);

                INSERT INTO EAM_AUX (PASO, FECHA)
                    VALUES ('p_in_valor_periodo:' || p_in_valor_periodo || ' incio ANTES RESULTADO:' || l_trx_date, SYSDATE);
                    COMMIT;
                --**** Esto comentado se da al final del a¿o
                /*begin
                    l_trx_date := TO_DATE (v_no_semana * 7 - 2, 'DDD');
                exception
                when others then
                    v_error_message :=
                        SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
                     v_error_message :=
                        SUBSTR (
                           v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
                           1,
                           4000);
                     l (v_error_message);
                     if v_no_semana = 53 then
                        v_no_semana := v_no_semana -1;
                        l ('Se pasa de semana 53 a 52->valor:'||v_no_semana);
                        l_trx_date := TO_DATE (v_no_semana * 7 - 2, 'DDD');    
                     end if;   
                end;*/
            end;
            O ('XXX VALOR_PERIODO:: ' || p_in_valor_periodo);
            L ('XXX VALOR_PERIODO:: ' || p_in_valor_periodo);
            V_NOMBRE_PERIODO :=
               APPS.CUST_AR_AGRUPADOR_PKG.GET_PERIOD_NAME (SYSDATE /*TO_DATE('08-05-2017','DD-MM-YY')*/
                                                                  );      --**
            O ('XXX V_NOMBRE_PERIODO:: ' || V_NOMBRE_PERIODO);            --**
            L ('XXX V_NOMBRE_PERIODO:: ' || V_NOMBRE_PERIODO);            --**
            V_ESTATUS_PERIODO :=
               APPS.CUST_AR_AGRUPADOR_PKG.GET_ESTATUS_PERIODO (
                  V_NOMBRE_PERIODO);                                      --**
            O (
                  'XXX l_trx_date:: '
               || TO_CHAR (l_trx_date, 'DD')
               || ' - '
               || l_trx_date
               || '-'
               || NVL (V_ESTATUS_PERIODO, 'C'));

            L (
                  'XXX l_trx_date:: '
               || TO_CHAR (l_trx_date, 'DD')
               || ' - '
               || l_trx_date
               || '-'
               || NVL (V_ESTATUS_PERIODO, 'C'));

            CASE
               WHEN (/*TO_CHAR (l_trx_date, 'DD') <= 7 AND*/ NVL (V_ESTATUS_PERIODO, 'C') = 'C')
               THEN
                  O ('XXX RETURN LAST_DAY - l_trx_date:: ' || LAST_DAY (ADD_MONTHS (l_trx_date, -1)) || ' AHORA:: ' || LAST_DAY (ADD_MONTHS (SYSDATE, -1)));
                  --RETURN LAST_DAY (ADD_MONTHS (l_trx_date, -1)); -- ¿ltimo d¿a del mes anterior
                  RETURN LAST_DAY (ADD_MONTHS (SYSDATE, -1)); -- ¿ltimo d¿a del mes anterior
               ELSE
                  --JIBARRA 07NOV2017

                  DECLARE
                     V_DIA   NUMBER;
                  BEGIN
                     O ('XXX EVALUA FECHA:: ' || l_trx_date);

                        --SELECT TO_NUMBER (TO_CHAR (l_trx_date, 'd')) DIA
                        --INTO V_DIA
                        --FROM DUAL;
                     SELECT TO_NUMBER(DECODE(TRIM(TO_CHAR (TO_DATE('30-NOV-17'),'DAY', 'NLS_DATE_LANGUAGE=AMERICAN'))
                                              ,'MONDAY',1
                                              ,'TUESDAY',2
                                              ,'WEDNESDAY',3
                                              ,'THURSDAY',4
                                              ,'FRIDAY',5
                                              ,'SATURDAY',6
                                              ,'SUNDAY',7)) DIA
                     INTO V_DIA
                     FROM DUAL
                     ;

                     O ('XXX DIA:: ' || V_DIA);
                     O (
                           'XXX OPERACION:: '
                        || l_trx_date
                        || ' - '
                        || V_DIA
                        || ' + 7');
                  END;

                  --SELECT l_trx_date - DIA + 7
                  --  INTO l_trx_date
                  --  FROM (SELECT TO_NUMBER (TO_CHAR (l_trx_date, 'd')) DIA
                  --          FROM DUAL);
                    --DBMS_OUTPUT.PUT_LINE('XXX ANTES RESULTADO:: ' || l_trx_date);

                    INSERT INTO EAM_AUX (PASO, FECHA)
                    VALUES ('AGRUP ANTES RESULTADO:' || l_trx_date, SYSDATE);
                    COMMIT;

                  SELECT l_trx_date - DIA + 7
                    INTO l_trx_date
                    FROM (SELECT TO_NUMBER(DECODE(TRIM(TO_CHAR (l_trx_date,'DAY', 'NLS_DATE_LANGUAGE=AMERICAN'))
                                              ,'MONDAY',1
                                              ,'TUESDAY',2
                                              ,'WEDNESDAY',3
                                              ,'THURSDAY',4
                                              ,'FRIDAY',5
                                              ,'SATURDAY',6
                                              ,'SUNDAY',7)) DIA
                     FROM DUAL);

                INSERT INTO EAM_AUX (PASO, FECHA)
                    VALUES ('AGRUP  DESPUES RESULTADO:' || l_trx_date, SYSDATE);
                    COMMIT;
                --DBMS_OUTPUT.PUT_LINE('XXX RESULTADO:: ' || l_trx_date);

                  O ('XXX RESULTADO:: ' || l_trx_date);

                  O ('XXX RETURN l_trx_date:: ' || l_trx_date);

                  RETURN l_trx_date;
            END CASE;
         WHEN c_quincenal
         THEN
            l_anio_mes := SUBSTR (p_in_valor_periodo, 1, 6);

            CASE SUBSTR (p_in_valor_periodo, -2)
               WHEN '01'
               THEN
                  RETURN TO_DATE (l_anio_mes || '15', 'YYYYMMDD');
               WHEN '02'
               THEN
                  RETURN LAST_DAY (TO_DATE (l_anio_mes, 'YYYYMM'));
            END CASE;
         WHEN c_mensual
         THEN
            RETURN LAST_DAY (TO_DATE (p_in_valor_periodo, 'YYYYMM'));
         WHEN c_desconocido
         THEN
            RETURN LAST_DAY (TO_DATE (p_in_valor_periodo, 'YYYYMM'));
         ELSE
            raise_application_error (
               -20229,
                  'Error, Valor para PERIODO no esperado '''
               || p_in_clave_periodo
               || '''');
      END CASE;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_clave_periodo ',
                         p_in_clave_periodo);
         concat_message (v_error_message,
                         'p_in_valor_periodo ',
                         p_in_valor_periodo);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_grouping_trx_date',
            MESSAGE     => v_error_message);
         raise_application_error (-20234, v_error_message);
   END get_grouping_trx_date;

   FUNCTION get_direc_id (
      p_in_agrupador_id   IN ar_regla_agrupa_suc_direc.agrupador_id%TYPE,
      p_in_address_id     IN hz_cust_acct_sites_all.cust_acct_site_id%TYPE)
      RETURN ar_regla_agrupa_suc_direc.direc_id%TYPE
   IS
      v_direc_id        ar_regla_agrupa_suc_direc.direc_id%TYPE := NULL;
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE := 'GET_DIREC_ID';
   BEGIN
      SELECT direc_id
        INTO v_direc_id
        FROM hz_cust_acct_sites_all cas, ar_regla_agrupa_suc_direc rasd
       WHERE     cas.cust_account_id = rasd.customer_id
             AND cas.orig_system_reference = rasd.direc_ref
             AND cas.org_id = fnd_profile.VALUE ('ORG_ID')
             AND cas.cust_acct_site_id = p_in_address_id
             AND rasd.agrupador_id = p_in_agrupador_id;

      RETURN v_direc_id;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_agrupador_id ',
                         p_in_agrupador_id);
         concat_message (v_error_message,
                         'p_in_address_id   ',
                         p_in_address_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (log_level   => fnd_log.level_unexpected,
                         module      => 'cust_ar_agrupador_pkg.get_direc_id',
                         MESSAGE     => v_error_message);
         raise_application_error (-20234, v_error_message);
   END get_direc_id;

   FUNCTION insert_header (
      p_in_bill_to_customer_id     IN ra_customer_trx_all.bill_to_customer_id%TYPE,
      p_in_bill_to_address_id      IN ra_customer_trx_all.bill_to_address_id%TYPE,
      p_in_ship_to_address_id      IN ra_customer_trx_all.ship_to_address_id%TYPE,
      p_in_num_cedis               IN ra_customer_trx_all.attribute12%TYPE,
      p_in_cust_trx_type_id        IN ra_customer_trx_all.cust_trx_type_id%TYPE,
      p_in_invoice_currency_code   IN ra_customer_trx_all.invoice_currency_code%TYPE,
      p_in_exchange_rate           IN ra_customer_trx_all.exchange_rate%TYPE,
      p_in_trx_date                IN ra_customer_trx_all.trx_date%TYPE)
      RETURN NUMBER
   IS
      v_error_message       fnd_log_messages.MESSAGE_TEXT%TYPE := 'INSERT_HEADER';
      c_cedis      CONSTANT VARCHAR2 (2) := 'CE';
      c_ciudad     CONSTANT VARCHAR2 (1) := 'C';
      c_region     CONSTANT VARCHAR2 (1) := 'R';
      c_zona       CONSTANT VARCHAR2 (1) := 'Z';
      c_nud        CONSTANT VARCHAR2 (1) := 'N';
      c_sucursal   CONSTANT VARCHAR2 (1) := 'S';
      v_num_cedis           ar.ar_cedis_sio.num_cedis%TYPE;
      grouping_header_rec   cust_ar_grouping_header%ROWTYPE;
   BEGIN
      v_num_cedis :=
         cust_ar_agrupador_pkg.get_cedis (
            p_in_num_cedis          => p_in_num_cedis,
            p_in_cust_trx_type_id   => p_in_cust_trx_type_id);
      grouping_header_rec.status := c_nuevo;
      grouping_header_rec.exchange_rate :=
         NVL (grouping_header_rec.exchange_rate, 1);
      grouping_header_rec.bill_to_customer_id := p_in_bill_to_customer_id;
      grouping_header_rec.bill_to_address_id := p_in_bill_to_address_id;
      grouping_header_rec.ship_to_address_id := NULL;
      grouping_header_rec.invoice_currency_code := p_in_invoice_currency_code;
      grouping_header_rec.period_name :=
         cust_ar_agrupador_pkg.get_period_name (p_in_trx_date);
      grouping_header_rec.exchange_rate :=
         NVL (p_in_exchange_rate, 1);
      grouping_header_rec.unidad_operativa :=
         cust_ar_agrupador_pkg.get_cedis_sio_info (v_num_cedis, 'UO');
      cust_ar_agrupador_pkg.get_regla_agrupa_info (
         p_in_customer_id     => p_in_bill_to_customer_id,
         p_out_periodo        => grouping_header_rec.periodo,
         p_out_localidades    => grouping_header_rec.localidades,
         p_out_agrupador_id   => grouping_header_rec.agrupador_id);
      grouping_header_rec.valor_periodo :=
         cust_ar_agrupador_pkg.get_valor_periodo (
            p_in_clave_periodo   => grouping_header_rec.periodo,
            p_in_date            => p_in_trx_date);

      CASE grouping_header_rec.localidades
         WHEN c_cedis
         THEN
            grouping_header_rec.valor_localidad :=
               cust_ar_agrupador_pkg.get_cedis_sio_info (v_num_cedis,
                                                         'NUM_CEDIS');
            grouping_header_rec.territory_segment1 :=
               cust_ar_agrupador_pkg.get_cedis_sio_info (v_num_cedis, 'ZONA');
         WHEN c_ciudad
         THEN
            grouping_header_rec.valor_localidad :=
               cust_ar_agrupador_pkg.get_cedis_sio_info (v_num_cedis,
                                                         'CIUDAD');
            grouping_header_rec.territory_segment1 := 'ZONA AGRUPADA';
         WHEN c_region
         THEN
            grouping_header_rec.valor_localidad :=
               cust_ar_agrupador_pkg.get_cedis_sio_info (v_num_cedis,
                                                         'REGION');
            grouping_header_rec.territory_segment1 := 'ZONA AGRUPADA';
         WHEN c_zona
         THEN
            grouping_header_rec.valor_localidad :=
               cust_ar_agrupador_pkg.get_cedis_sio_info (v_num_cedis, 'ZONA');
            grouping_header_rec.territory_segment1 :=
               cust_ar_agrupador_pkg.get_cedis_sio_info (v_num_cedis, 'ZONA');
         WHEN c_nud
         THEN
            grouping_header_rec.valor_localidad := p_in_ship_to_address_id;
            grouping_header_rec.ship_to_address_id := p_in_ship_to_address_id;
            grouping_header_rec.territory_segment1 := 'ZONA AGRUPADA';
         WHEN c_sucursal
         THEN
            grouping_header_rec.valor_localidad :=
               cust_ar_agrupador_pkg.get_direc_id (
                  p_in_agrupador_id   => grouping_header_rec.agrupador_id,
                  p_in_address_id     => grouping_header_rec.ship_to_address_id);
            grouping_header_rec.territory_segment1 := 'ZONA AGRUPADA';
         WHEN c_desconocido
         THEN
            grouping_header_rec.valor_localidad := c_desconocido;
            grouping_header_rec.territory_segment1 := 'ZONA AGRUPADA';
         ELSE
            raise_application_error (
               -20235,
                  'Error, Valor para localidad no esperado '''
               || grouping_header_rec.localidades
               || '''');
      END CASE;

      grouping_header_rec.header_id :=
         cust_ar_agrupador_pkg.get_header_id (grouping_header_rec);

      IF grouping_header_rec.header_id > 0
      THEN
         RETURN grouping_header_rec.header_id;
      END IF;

      cust_ar_agrupador_pkg.insert_grouping_header (grouping_header_rec);
      RETURN grouping_header_rec.header_id;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_bill_to_customer_id ',
                         p_in_bill_to_customer_id);
         concat_message (v_error_message,
                         'p_in_bill_to_address_id  ',
                         p_in_bill_to_address_id);
         concat_message (v_error_message,
                         'p_in_ship_to_address_id  ',
                         p_in_ship_to_address_id);
         concat_message (v_error_message,
                         'p_in_num_cedis           ',
                         p_in_num_cedis);
         concat_message (v_error_message,
                         'p_in_cust_trx_type_id    ',
                         p_in_cust_trx_type_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (log_level   => fnd_log.level_unexpected,
                         module      => 'cust_ar_agrupador_pkg.insert_header',
                         MESSAGE     => v_error_message);
         raise_application_error (-20236, v_error_message);
   END insert_header;

   PROCEDURE insert_trx (
      p_in_customer_trx_id         IN ra_customer_trx_all.customer_trx_id%TYPE,
      p_in_attribute7              IN ra_customer_trx_all.attribute7%TYPE,
      p_in_trx_date                IN ra_customer_trx_all.trx_date%TYPE,
      p_in_bill_to_customer_id     IN ra_customer_trx_all.bill_to_customer_id%TYPE,
      p_in_bill_to_address_id      IN ra_customer_trx_all.bill_to_address_id%TYPE,
      p_in_ship_to_address_id      IN ra_customer_trx_all.ship_to_address_id%TYPE,
      p_in_num_cedis               IN ra_customer_trx_all.attribute12%TYPE,
      p_in_cust_trx_type_id        IN ra_customer_trx_all.cust_trx_type_id%TYPE,
      p_in_invoice_currency_code   IN ra_customer_trx_all.invoice_currency_code%TYPE,
      p_in_exchange_rate           IN ra_customer_trx_all.exchange_rate%TYPE)
   IS
      grouping_rec      cust_ar_grouping_trx%ROWTYPE;
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE := 'INSERT_TRX';
   BEGIN
      grouping_rec.header_id :=
         cust_ar_agrupador_pkg.insert_header (
            p_in_bill_to_customer_id     => p_in_bill_to_customer_id,
            p_in_bill_to_address_id      => p_in_bill_to_address_id,
            p_in_ship_to_address_id      => p_in_ship_to_address_id,
            p_in_num_cedis               => p_in_num_cedis,
            p_in_cust_trx_type_id        => p_in_cust_trx_type_id,
            p_in_invoice_currency_code   => p_in_invoice_currency_code,
            p_in_exchange_rate           => p_in_exchange_rate,
            p_in_trx_date                => p_in_trx_date);
      grouping_rec.customer_trx_id := p_in_customer_trx_id;
      grouping_rec.remision := p_in_attribute7;
      grouping_rec.last_update_date := SYSDATE;
      grouping_rec.last_updated_by :=
         NVL (fnd_profile.VALUE ('USER_ID'), -1);
      grouping_rec.creation_date := TRUNC (SYSDATE);
      grouping_rec.created_by :=
         NVL (fnd_profile.VALUE ('USER_ID'), -1);
      grouping_rec.grouping_status := c_nuevo;
      grouping_rec.grouping_date := NULL;
      grouping_rec.request_id := fnd_global.conc_request_id;
      grouping_rec.credit_memo_status := c_nuevo;
      grouping_rec.org_id := fnd_profile.VALUE ('ORG_ID');

      INSERT INTO cust_ar_grouping_trx
           VALUES grouping_rec;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_customer_trx_id       ',
                         p_in_customer_trx_id);
         concat_message (v_error_message,
                         'p_in_bill_to_customer_id   ',
                         p_in_bill_to_customer_id);
         concat_message (v_error_message,
                         'p_in_bill_to_address_id    ',
                         p_in_bill_to_address_id);
         concat_message (v_error_message,
                         'p_in_ship_to_address_id    ',
                         p_in_ship_to_address_id);
         concat_message (v_error_message,
                         'p_in_num_cedis             ',
                         p_in_num_cedis);
         concat_message (v_error_message,
                         'p_in_cust_trx_type_id      ',
                         p_in_cust_trx_type_id);
         concat_message (v_error_message,
                         'p_in_invoice_currency_code ',
                         p_in_invoice_currency_code);
         concat_message (v_error_message,
                         'p_in_exchange_rate         ',
                         p_in_exchange_rate);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (log_level   => fnd_log.level_unexpected,
                         module      => 'cust_ar_agrupador_pkg.insert_trx',
                         MESSAGE     => v_error_message);
         raise_application_error (-20237, v_error_message);
   END insert_trx;

   PROCEDURE update_credit_memo_status (
      p_in_customer_trx_id      IN cust_ar_grouping_trx.customer_trx_id%TYPE,
      p_in_credit_memo_status   IN cust_ar_grouping_trx.credit_memo_status%TYPE)
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'UPDATE_CREDIT_MEMO_STATUS';
   BEGIN
      UPDATE cust_ar_grouping_trx
         SET credit_memo_status = p_in_credit_memo_status,
             request_id = l_conc_request_id
       WHERE customer_trx_id = p_in_customer_trx_id;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_customer_trx_id    ',
                         p_in_customer_trx_id);
         concat_message (v_error_message,
                         'p_in_credit_memo_status ',
                         p_in_credit_memo_status);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.update_credit_memo_status',
            MESSAGE     => v_error_message);
         raise_application_error (-20238, v_error_message);
   END update_credit_memo_status;

   PROCEDURE update_grp_customer_trx_id (
      p_in_header_id         IN ra_customer_trx_all.interface_header_attribute10%TYPE,
      p_in_customer_trx_id   IN ra_customer_trx_all.customer_trx_id%TYPE)
   IS
      v_error_message   fnd_log_messages.MESSAGE_TEXT%TYPE
                           := 'UPDATE_GRP_CUSTOMER_TRX_ID';
   BEGIN
      UPDATE cust_ar_grouping_header
         SET grp_customer_trx_id = p_in_customer_trx_id,
             request_id = l_conc_request_id
       WHERE 1 = 1 AND header_id = p_in_header_id;

      UPDATE cust_ar_grouping_trx
         SET grp_customer_trx_id = p_in_customer_trx_id
       WHERE 1 = 1 AND header_id = p_in_header_id;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_header_id       ',
                         p_in_header_id);
         concat_message (v_error_message,
                         'p_in_customer_trx_id ',
                         p_in_customer_trx_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.update_grp_customer_trx_id',
            MESSAGE     => v_error_message);
         raise_application_error (-20239, v_error_message);
   END update_grp_customer_trx_id;

   FUNCTION create_credit_memo (
      p_in_customer_trx_id     IN ra_customer_trx_all.customer_trx_id%TYPE,
      p_in_header_id           IN cust_ar_grouping_trx.header_id%TYPE,
      p_in_batch_source_name   IN ra_batch_sources_all.NAME%TYPE DEFAULT NULL)
      RETURN VARCHAR2
   IS
      v_error_message       fnd_log_messages.MESSAGE_TEXT%TYPE
                               := 'CREATE_CREDIT_MEMO';
      v_error_message2      fnd_log_messages.MESSAGE_TEXT%TYPE := NULL;
      v_return_status       VARCHAR2 (1) := NULL;
      v_count               NUMBER := 0;
      v_msg_count           NUMBER := NULL;
      v_msg_data            VARCHAR2 (2000) := NULL;
      v_request_id          NUMBER := NULL;
      v_line_amount         ar_payment_schedules_all.amount_line_items_remaining%TYPE
         := 0;
      v_tax_amount          ar_payment_schedules_all.tax_remaining%TYPE := 0;
      v_freight_amount      ar_payment_schedules_all.freight_remaining%TYPE := 0;
      v_org_id              ar_payment_schedules_all.org_id%TYPE := 0;
      v_trx_number          ar_payment_schedules_all.trx_number%TYPE;
      v_batch_source_name   ra_batch_sources_all.NAME%TYPE := NULL;
      l_status_trx_cm       cust_ar_grouping_trx.credit_memo_status%TYPE;
   BEGIN
      fnd_profile.put ('AR_USE_INV_ACCT_FOR_CM_FLAG', 'N');


        SELECT SUM (NVL (amount_line_items_remaining, 0)) * (-1) v_line_amount,
               SUM (NVL (tax_remaining, 0)) * (-1)             v_tax_amount,
               SUM (NVL (freight_remaining, 0)) * (-1)
                  v_freight_amount,
               org_id,
               trx_number
          INTO v_line_amount,
               v_tax_amount,
               v_freight_amount,
               v_org_id,
               v_trx_number
          FROM ar_payment_schedules_all
         WHERE customer_trx_id = p_in_customer_trx_id
      GROUP BY org_id, trx_number;

      l_status_trx_cm := get_trx_cm_status (p_in_customer_trx_id);

      IF (    (  ABS (v_line_amount)
               + ABS (v_tax_amount)
               + ABS (v_freight_amount)) > 0
          AND l_status_trx_cm = c_nuevo)
      THEN
         IF p_in_batch_source_name IS NULL
         THEN
            v_batch_source_name :=
               cust_ar_agrupador_pkg.get_batch_source_name (
                  p_in_org_id              => v_org_id,
                  p_in_batch_source_name   => '%NAGRUP%',
                  p_in_type                => 'CM');
         ELSE
            v_batch_source_name := p_in_batch_source_name;
         END IF;

         ar_credit_memo_api_pub.create_request (
            p_api_version          => 1.0,
            p_init_msg_list        => fnd_api.g_false,
            p_commit               => fnd_api.g_false,
            p_validation_level     => fnd_api.g_valid_level_full,
            x_return_status        => v_return_status,
            x_msg_count            => v_msg_count,
            x_msg_data             => v_msg_data,
            p_customer_trx_id      => p_in_customer_trx_id,
            p_line_credit_flag     => 'N',
            p_line_amount          => v_line_amount,
            p_tax_amount           => v_tax_amount,
            p_freight_amount       => v_freight_amount,
            p_cm_reason_code       => 'NO REASON',
            p_comments             =>    'CANCELA '
                                      || v_trx_number
                                      || ' POR AGRUPACION '
                                      || p_in_header_id,
            p_skip_workflow_flag   => 'Y',
            p_batch_source_name    => v_batch_source_name,
            x_request_id           => v_request_id);

         IF v_msg_count = 1
         THEN
            concat_message (v_error_message2,
                            'v_msg_count     ',
                            v_msg_count);
            concat_message (v_error_message2,
                            'v_return_status ',
                            v_return_status);
            concat_message (v_error_message2,
                            'v_request_id    ',
                            v_request_id);
            concat_message (v_error_message2, 'v_msg_data      ', v_msg_data);
            raise_application_error (
               -20240,
               'Error obtenido de  ar_credit_memo_api_pub.create_request');
         ELSIF v_msg_count > 1
         THEN
            concat_message (v_error_message2,
                            'v_msg_count     ',
                            v_msg_count);
            concat_message (v_error_message2,
                            'v_return_status ',
                            v_return_status);
            concat_message (v_error_message2,
                            'v_request_id    ',
                            v_request_id);

            LOOP
               v_count := v_count + 1;
               v_msg_data :=
                  fnd_msg_pub.get (fnd_msg_pub.g_next, fnd_api.g_false);

               IF v_msg_data IS NULL
               THEN
                  EXIT;
               END IF;

               concat_message (v_error_message,
                               ' message ' || TO_CHAR (v_count, 'FM000'),
                               v_msg_data);
            END LOOP;

            l (' Error ar_credit_memo_api_pub.create_request');
            raise_application_error (
               -20241,
               'Errores obtenidos de  ar_credit_memo_api_pub.create_request');
         END IF;
      ELSIF l_status_trx_cm = c_correcto
      THEN
         RETURN c_correcto;
      ELSIF l_status_trx_cm = c_advertencia
      THEN
         v_error_rec.header_id := p_in_header_id;
         v_error_rec.customer_trx_id := p_in_customer_trx_id;
         v_error_rec.desc_error :=
               'Agrupador : '
            || p_in_header_id
            || ' Remision : '
            || v_trx_number
            || ' Error : '
            || ' la remision '
            || v_trx_number
            || ' tiene aplicaciones';
         insert_error (v_error_rec, v_errors_tbl);
         RETURN c_advertencia;
      ELSIF l_status_trx_cm = c_error
      THEN
         fnd_file.put_line (
            fnd_file.LOG,
               p_in_customer_trx_id
            || ' El documento '
            || v_trx_number
            || ' esta cancelado por una NC que no es del agrupador ');
         v_error_rec.header_id := p_in_header_id;
         v_error_rec.customer_trx_id := p_in_customer_trx_id;
         v_error_rec.desc_error :=
               'Agrupador : '
            || p_in_header_id
            || ' Remision : '
            || v_trx_number
            || ' Error : '
            || ' la remision '
            || v_trx_number
            || ' esta cancelada por una NC que no es del agrupador';
         insert_error (v_error_rec, v_errors_tbl);
         RETURN c_advertencia;
      END IF;

      CASE v_return_status
         WHEN 'S'
         THEN
            v_return_status := c_correcto;
         WHEN 'E'
         THEN
            v_return_status := c_error;
         ELSE
            v_error_rec.header_id := p_in_header_id;
            v_error_rec.customer_trx_id := p_in_customer_trx_id;
            v_error_rec.desc_error :=
                  'Agrupador : '
               || p_in_header_id
               || ' Remision : '
               || v_trx_number
               || ' Error : estatus desconocido ';
            insert_error (v_error_rec, v_errors_tbl);
            v_return_status := c_desconocido;
      END CASE;

      RETURN v_return_status;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN c_no_existe;
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_customer_trx_id   ',
                         p_in_customer_trx_id);
         concat_message (v_error_message,
                         'v_batch_source_name    ',
                         v_batch_source_name);
         v_error_message := v_error_message || v_error_message2;
         l (v_error_message);
         RETURN c_error;
   END create_credit_memo;

   PROCEDURE create_all_credit_memo (
      errbuf           IN OUT VARCHAR2,
      retcode          IN OUT VARCHAR2,
      p_in_header_id   IN     cust_ar_grouping_header.header_id%TYPE)
   IS
      TYPE cursor_reg IS REF CURSOR;

      invoice_to_credit_cur   cursor_reg;
      v_customer_trx_id       cust_ar_grouping_trx.customer_trx_id%TYPE;
      v_trx_number            ra_customer_trx_all.trx_number%TYPE;
      v_error_message         fnd_log_messages.MESSAGE_TEXT%TYPE
                                 := 'CREATE_ALL_CREDIT_MEMO';
      v_query                 VARCHAR2 (2000) := NULL;
      v_cm_status             cust_ar_grouping_header.cm_status%TYPE := NULL;
      v_cm_status_desc        VARCHAR2 (150);
      v_remisiones            NUMBER := 0;
   BEGIN
      v_query := v_query || ' SELECT gt.customer_trx_id, rct.trx_number';
      v_query := v_query || CHR (10) || '   FROM cust_ar_grouping_trx gt';
      v_query := v_query || CHR (10) || '      , cust_ar_grouping_header gh';
      v_query := v_query || CHR (10) || '      , ra_customer_trx_all rct';
      v_query :=
            v_query
         || CHR (10)
         || '  WHERE rct.customer_trx_id(+) = gt.customer_trx_id';
      v_query := v_query || CHR (10) || '    AND gh.header_id = gt.header_id';
      v_query :=
            v_query
         || CHR (10)
         || '    AND gt.credit_memo_status IN  ('''
         || c_nuevo
         || ''', '''
         || c_error
         || ''')';

      IF p_in_header_id IS NOT NULL
      THEN
         IF cust_ar_agrupador_pkg.get_header_cm_status (p_in_header_id) =
               c_correcto
         THEN
            l (
                  'No se puede crear notas de credito, status no esperado para header_id '
               || p_in_header_id);
            RETURN;
         END IF;

         v_query :=
               v_query
            || CHR (10)
            || '    AND gt.header_id = '
            || p_in_header_id;
      ELSE
         v_query :=
               v_query
            || CHR (10)
            || '    AND gh.cm_status IN  ('''
            || c_nuevo
            || ''', '''
            || c_error
            || ''')';
         v_query :=
               v_query
            || CHR (10)
            || '    AND gh.status =  '''
            || c_correcto
            || '''';
      END IF;

      OPEN invoice_to_credit_cur FOR v_query;

      LOOP
         FETCH invoice_to_credit_cur INTO v_customer_trx_id, v_trx_number;

         EXIT WHEN invoice_to_credit_cur%NOTFOUND;
         --
         cust_ar_agrupador_pkg.update_credit_memo_status (
            p_in_customer_trx_id      => v_customer_trx_id,
            p_in_credit_memo_status   => c_en_proceso);
         v_cm_status :=
            cust_ar_agrupador_pkg.create_credit_memo (v_customer_trx_id,
                                                      p_in_header_id);

         v_remisiones := v_remisiones + 1;

         cust_ar_agrupador_pkg.update_credit_memo_status (
            p_in_customer_trx_id      => v_customer_trx_id,
            p_in_credit_memo_status   => v_cm_status);

         IF v_cm_status <> c_correcto
         THEN
            IF v_cm_status = c_error
            THEN
               v_cm_status_desc :=
                  'Error la factura esta saldada por una NC que no es del agrupador';
            ELSIF v_cm_status = c_advertencia
            THEN
               v_cm_status_desc := 'El documento tiene aplicaciones';
            ELSIF v_cm_status = c_no_existe
            THEN
               v_cm_status_desc := 'El documento no existe';
            ELSIF v_cm_status = c_desconocido
            THEN
               v_cm_status_desc := 'Error desconocido';
            END IF;
         END IF;
      END LOOP;

      cust_ar_agrupador_pkg.set_header_cm_status (p_in_header_id);

      IF v_remisiones = 0
      THEN
         retcode := c_advertencia;
      ELSE
         IF cust_ar_agrupador_pkg.get_header_cm_status (
               p_in_header_id   => p_in_header_id) <> c_correcto
         THEN
            retcode := c_error;
         ELSE
            retcode := c_correcto;
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         IF invoice_to_credit_cur%ISOPEN
         THEN
            CLOSE invoice_to_credit_cur;
         END IF;

         ROLLBACK;
         retcode := c_error;
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message, 'p_in_header_id ', p_in_header_id);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.create_all_credit_memo',
            MESSAGE     => v_error_message);
         raise_application_error (-20242, v_error_message);
   END create_all_credit_memo;

   FUNCTION tonumber (p_in_value IN VARCHAR2, p_in_name IN VARCHAR2)
      RETURN NUMBER
   IS
      v_error_message          fnd_log_messages.MESSAGE_TEXT%TYPE
                                  := 'FUNCTION TONUMBER';
      c_format_mask   CONSTANT VARCHAR2 (25) := '99999999999999999.9999';
   BEGIN
      RETURN TO_NUMBER (p_in_value,
                        c_format_mask,
                        'NLS_NUMERIC_CHARACTERS = '',.''');
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message, 'p_in_value ', p_in_value);
         concat_message (v_error_message, 'p_in_name  ', p_in_name);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (log_level   => fnd_log.level_unexpected,
                         module      => 'cust_ar_agrupador_pkg.tonumber',
                         MESSAGE     => v_error_message);
         raise_application_error (-20243, v_error_message);
   END tonumber;

   PROCEDURE re_agrupa_trx (p_in_periodo          IN VARCHAR2,
                            p_valor_periodo_ini   IN VARCHAR2,
                            p_valor_periodo_fin   IN VARCHAR2)
   IS
      v_error_message         fnd_log_messages.MESSAGE_TEXT%TYPE
                                 := 'PROCEDURE RE_AGRUPA_TRX';
      v_grouping_header_rec   cust_ar_grouping_header%ROWTYPE;
      v_old_header_id         cust_ar_grouping_header.header_id%TYPE;
      v_new_header_id         cust_ar_grouping_header.header_id%TYPE;

      CURSOR re_agrupa_rem
      IS
         SELECT *
           FROM cust_ar_grouping_header cgh
          WHERE     periodo = p_in_periodo
                AND cgh.status = c_correcto
                AND cgh.valor_periodo >=
                       NVL (p_valor_periodo_ini, cgh.valor_periodo)
                AND cgh.valor_periodo <=
                       NVL (p_valor_periodo_fin, cgh.valor_periodo)
                AND EXISTS
                       (SELECT '1'
                          FROM cust_ar_grouping_trx cgt
                         WHERE     grouping_status = c_nuevo
                               AND cgt.header_id = cgh.header_id);
   BEGIN
      l ('Reagrupa * 1 * ');

      OPEN re_agrupa_rem;

      LOOP
         FETCH re_agrupa_rem INTO v_grouping_header_rec;

         EXIT WHEN re_agrupa_rem%NOTFOUND;

         v_old_header_id := v_grouping_header_rec.header_id;

         cust_ar_agrupador_pkg.insert_grouping_header (v_grouping_header_rec);

         v_new_header_id := v_grouping_header_rec.header_id;

         l ('Reagrupa : ' || v_old_header_id || ' -> ' || v_new_header_id);



         UPDATE cust_ar_grouping_trx
            SET header_id = v_new_header_id
          WHERE     header_id = v_old_header_id
                AND grouping_status = c_nuevo
                AND credit_memo_status = c_nuevo;
      END LOOP;

      CLOSE re_agrupa_rem;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;

         IF re_agrupa_rem%ISOPEN
         THEN
            CLOSE re_agrupa_rem;
         END IF;

         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_periodo         ',
                         p_in_periodo);
         concat_message (v_error_message,
                         'p_valor_periodo_ini  ',
                         p_valor_periodo_ini);
         concat_message (v_error_message,
                         'p_valor_periodo_fin  ',
                         p_valor_periodo_fin);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (log_level   => fnd_log.level_unexpected,
                         module      => 'cust_ar_agrupador_pkg.re_agrupa_trx',
                         MESSAGE     => v_error_message);
         raise_application_error (-20243, v_error_message);
   END re_agrupa_trx;


   PROCEDURE agrupa_facturas (
      p_in_grouping_header_rec   IN cust_ar_grouping_header_v%ROWTYPE)
   IS
      CURSOR trx_lines_cur (
         p_header_id    NUMBER)
      IS
           SELECT items.segment1   mtl_system_items_seg1,
                  items.description description,
                  ctl.attribute1   clave_producto,
                  SUM (
                     cust_ar_agrupador_pkg.tonumber (
                        ctl.attribute2,
                           'customer_trx_id:'
                        || ctl.customer_trx_id
                        || ' attribute2 '))
                     cantidad_producto,
                  ctl.attribute3   precio_unitario_sin_iva,
                  SUM (
                     cust_ar_agrupador_pkg.tonumber (
                        ctl.attribute4,
                           'customer_trx_id:'
                        || ctl.customer_trx_id
                        || ' attribute4 '))
                     imp_iva,
                  SUM (
                     cust_ar_agrupador_pkg.tonumber (
                        ctl.attribute5,
                           'customer_trx_id:'
                        || ctl.customer_trx_id
                        || ' attribute5 '))
                     imp_total,
                  SUM (
                     cust_ar_agrupador_pkg.tonumber (
                        ctl.attribute6,
                           'customer_trx_id:'
                        || ctl.customer_trx_id
                        || ' attribute6 '))
                     imp_bruto_sin_iva,
                  SUM (
                     cust_ar_agrupador_pkg.tonumber (
                        ctl.attribute7,
                           'customer_trx_id:'
                        || ctl.customer_trx_id
                        || ' attribute7 '))
                     descuento_cc_efectivo,
                  ctl.attribute8   descuento_cc_porciento,
                  SUM (
                     cust_ar_agrupador_pkg.tonumber (
                        ctl.attribute9,
                           'customer_trx_id:'
                        || ctl.customer_trx_id
                        || ' attribute9 '))
                     imp_desc_cc_sin_iva,
                  SUM (
                     cust_ar_agrupador_pkg.tonumber (
                        ctl.attribute10,
                           'customer_trx_id:'
                        || ctl.customer_trx_id
                        || ' attribute10'))
                     imp_neto_m_desc_cc,
                  SUM (
                     cust_ar_agrupador_pkg.tonumber (
                        ctl.attribute11,
                           'customer_trx_id:'
                        || ctl.customer_trx_id
                        || ' attribute11'))
                     descuento_esp,
                  ctl.attribute12  descuento_esp_porciento,
                  SUM (
                     cust_ar_agrupador_pkg.tonumber (
                        ctl.attribute13,
                           'customer_trx_id:'
                        || ctl.customer_trx_id
                        || ' attribute13'))
                     imp_desc_esp_sin_iva,
                  SUM (
                     cust_ar_agrupador_pkg.tonumber (
                        ctl.attribute14,
                           'customer_trx_id:'
                        || ctl.customer_trx_id
                        || ' attribute14'))
                     imp_neto_m_desc_cc_esp,
                  vt.PERCENTAGE_RATE tax_rate,
                  vt.TAX_RATE_CODE tax_code,
                  ctl.uom_code
             FROM cust_ar_grouping_trx    gt,
                  ra_customer_trx_lines_all ctl,
                  ZX_RATES_B              vt,
                  (SELECT msi.segment1,
                          msi.description,
                          osp.org_id,
                          msi.inventory_item_id
                     FROM oe_system_parameters_all osp, mtl_system_items_b msi
                    WHERE     1 = 1
                          AND msi.organization_id =
                                 osp.master_organization_id(+)
                          AND osp.org_id = fnd_profile.VALUE ('org_id')) items
            WHERE     1 = 1
                  AND ctl.TAX_CLASSIFICATION_CODE = vt.TAX_RATE_CODE(+)
                  AND ctl.inventory_item_id = items.inventory_item_id(+)
                  AND ctl.customer_trx_id = gt.customer_trx_id
                  AND gt.grouping_status NOT IN (c_correcto, c_desconocido)
                  AND ctl.line_type = 'LINE'
                  AND ctl.DESCRIPTION NOT LIKE 'IEPS_LT%' -- CEDC ENE26 -- Para que considere el ieps azucarado y edulcorante
                  AND gt.header_id = p_header_id
         GROUP BY ctl.attribute1,
                  ctl.attribute3,
                  ctl.attribute8,
                  ctl.attribute12,
                  vt.PERCENTAGE_RATE,
                  vt.TAX_RATE_CODE,
                  ctl.uom_code,
                  items.segment1,
                  items.description;

      trx_lines_rec            trx_lines_cur%ROWTYPE;
      ra_interface_lines_rec   ra_interface_lines_all%ROWTYPE;
      v_error_message          fnd_log_messages.MESSAGE_TEXT%TYPE
                                  := 'AGRUPA_FACTURAS';
      v_step                   VARCHAR2 (100);
      v_count                  NUMBER := 0;
   BEGIN
      IF cust_ar_agrupador_pkg.get_header_status (
            p_in_grouping_header_rec.header_id) IN
            (c_nuevo, c_error)
      THEN
         cust_ar_agrupador_pkg.set_header_status (
            p_in_grouping_header_rec.header_id,
            c_en_proceso);

         BEGIN
            SELECT 'Complemento de la factura ' || trx_number
              INTO ra_interface_lines_rec.comments
              FROM cust_ar_grouping_header cgh, ra_customer_trx_all rct
             WHERE     cgh.header_id = p_in_grouping_header_rec.header_id
                   AND rct.customer_trx_id = cgh.grp_customer_trx_id;

            UPDATE cust_ar_grouping_header
               SET grp_customer_trx_id = NULL
             WHERE header_id = p_in_grouping_header_rec.header_id;

            UPDATE cust_ar_grouping_trx
               SET grp_customer_trx_id = NULL
             WHERE header_id = p_in_grouping_header_rec.header_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               ra_interface_lines_rec.comments := '';
         END;
      ELSE
         l (
               'No se puede agrupar facturas, status no esperado para header_id '
            || p_in_grouping_header_rec.header_id);
         RETURN;
      END IF;

      v_step := '001';
      ra_interface_lines_rec.batch_source_name :=
         cust_ar_agrupador_pkg.get_batch_source_name (
            p_in_grouping_header_rec.org_id,
            '%NAGRUP%',
            'INV');
      v_step := '002';
      ra_interface_lines_rec.cust_trx_type_name :=
         cust_ar_agrupador_pkg.get_cust_trx_type_name (
            p_in_org_id               => p_in_grouping_header_rec.org_id,
            p_in_cust_trx_type_name   => '%NAGRUP%',
            p_in_type                 => 'INV',
            p_in_unidad_operativa     => p_in_grouping_header_rec.unidad_operativa);
      v_step := '003';
      ra_interface_lines_rec.interface_line_context := 'FACTURA NAGRUP';
      v_step := '004';
      ra_interface_lines_rec.interface_line_attribute7 :=
         TO_CHAR (SYSDATE, 'DD/MM/YYYY');
      v_step := '005';
      ra_interface_lines_rec.interface_line_attribute8 :=
         TO_CHAR (SYSDATE, 'DD/MM/YYYY');
      v_step := '006';
      ra_interface_lines_rec.interface_line_attribute10 :=
         p_in_grouping_header_rec.header_id;
      v_step := '007';
      ra_interface_lines_rec.orig_system_batch_name :=
            'AGRUPADA '
         || TO_CHAR (SYSDATE, 'DD/MM/YYYY')
         || ' '
         || p_in_grouping_header_rec.header_id;
      v_step := '008';
      ra_interface_lines_rec.conversion_type := 'User';
      v_step := '009';
      ra_interface_lines_rec.conversion_rate :=
         p_in_grouping_header_rec.exchange_rate;
      v_step := '010';

      IF p_in_grouping_header_rec.territory_segment1 = c_desconocido
      THEN
         ra_interface_lines_rec.territory_segment1 := 'ZONA AGRUPADA';
      ELSE
         ra_interface_lines_rec.territory_segment1 :=
            p_in_grouping_header_rec.territory_segment1;
      END IF;

      v_step := '011';
      ra_interface_lines_rec.header_attribute9 :=
         TO_CHAR (SYSDATE, 'DD/MM/YYYY');
      v_step := '012';
      ra_interface_lines_rec.created_by :=
         fnd_profile.VALUE ('USER_ID');
      v_step := '013';
      ra_interface_lines_rec.orig_system_bill_address_ref :=
         p_in_grouping_header_rec.orig_system_bill_address_ref;
      v_step := '014';
      ra_interface_lines_rec.orig_system_bill_customer_ref :=
         p_in_grouping_header_rec.orig_system_bill_customer_ref;
      v_step := '015';
      ra_interface_lines_rec.orig_system_ship_address_ref :=
         p_in_grouping_header_rec.orig_system_ship_address_ref;
      v_step := '016';
      ra_interface_lines_rec.orig_system_ship_customer_ref :=
         p_in_grouping_header_rec.orig_system_ship_customer_ref;
      v_step := '017';
      ra_interface_lines_rec.term_name :=
         cust_ar_agrupador_pkg.get_term_name (
            p_in_grouping_header_rec.bill_to_customer_id);
      v_step := '018';
      ra_interface_lines_rec.trx_number :=
         p_in_grouping_header_rec.header_id;
      v_step := '018.5';
      ra_interface_lines_rec.trx_date :=
         get_grouping_trx_date (p_in_grouping_header_rec.periodo,
                                p_in_grouping_header_rec.valor_periodo);
      O (
            'YYY ra_interface_lines_rec.trx_date:: '
         || ra_interface_lines_rec.trx_date);

      v_step := '019';
      ra_interface_lines_rec.org_id :=
         p_in_grouping_header_rec.org_id;
      v_step := '020';
      ra_interface_lines_rec.currency_code :=
         p_in_grouping_header_rec.invoice_currency_code;
      v_step := '021';
      ra_interface_lines_rec.set_of_books_id :=
         fnd_profile.VALUE ('GL_SET_OF_BKS_ID');
      v_step := '022';
      ra_interface_lines_rec.line_type := 'LINE';
      v_step := '23';
      ra_interface_lines_rec.creation_date := TRUNC (SYSDATE);

      OPEN trx_lines_cur (p_in_grouping_header_rec.header_id);

      LOOP
         FETCH trx_lines_cur INTO trx_lines_rec;

         EXIT WHEN trx_lines_cur%NOTFOUND;
         v_step := '025';
         ra_interface_lines_rec.unit_selling_price :=
            TO_CHAR (trx_lines_rec.imp_neto_m_desc_cc_esp,
                     'FM99999999999999990.00');
         v_step := '026';
         ra_interface_lines_rec.description :=
            trx_lines_rec.description;
         v_step := '027';
         ra_interface_lines_rec.attribute1 :=
            trx_lines_rec.clave_producto;
         v_step := '028';
         ra_interface_lines_rec.attribute2 :=
            TO_CHAR (trx_lines_rec.cantidad_producto, 'FM99999999999999990');
         v_step := '029';
         ra_interface_lines_rec.attribute3 :=
            trx_lines_rec.precio_unitario_sin_iva;
         v_step := '030';
         ra_interface_lines_rec.attribute4 :=
            TO_CHAR (trx_lines_rec.imp_iva, 'FM99999999999999990.00');
         v_step := '031';
         ra_interface_lines_rec.attribute5 :=
            TO_CHAR (trx_lines_rec.imp_total, 'FM99999999999999990.00');
         v_step := '032';
         ra_interface_lines_rec.attribute6 :=
            TO_CHAR (trx_lines_rec.imp_bruto_sin_iva,
                     'FM99999999999999990.00');
         v_step := '033';
         ra_interface_lines_rec.attribute7 :=
            TO_CHAR (trx_lines_rec.descuento_cc_efectivo,
                     'FM99999999999999990.00');
         v_step := '034';
         ra_interface_lines_rec.attribute8 :=
            trx_lines_rec.descuento_cc_porciento;
         v_step := '035';
         ra_interface_lines_rec.attribute9 :=
            TO_CHAR (trx_lines_rec.imp_desc_cc_sin_iva,
                     'FM99999999999999990.00');
         v_step := '036';
         ra_interface_lines_rec.attribute10 :=
            TO_CHAR (trx_lines_rec.imp_neto_m_desc_cc,
                     'FM99999999999999990.00');
         v_step := '037';
         ra_interface_lines_rec.attribute11 :=
            TO_CHAR (trx_lines_rec.descuento_esp, 'FM99999999999999990.00');
         v_step := '038';
         ra_interface_lines_rec.attribute12 :=
            trx_lines_rec.descuento_esp_porciento;
         v_step := '039';
         ra_interface_lines_rec.attribute13 :=
            TO_CHAR (trx_lines_rec.imp_desc_esp_sin_iva,
                     'FM99999999999999990.00');
         v_step := '040';
         ra_interface_lines_rec.attribute14 :=
            TO_CHAR (trx_lines_rec.imp_neto_m_desc_cc_esp,
                     'FM99999999999999990.00');
         v_step := '041';
         ra_interface_lines_rec.amount := trx_lines_rec.imp_total;
         v_step := '042';
         ra_interface_lines_rec.tax_rate := trx_lines_rec.tax_rate;
         ra_interface_lines_rec.tax_code := trx_lines_rec.tax_code;
         v_step := '043';
         ra_interface_lines_rec.interface_line_attribute11 :=
            trx_lines_cur%ROWCOUNT;
         v_step := '044';
         ra_interface_lines_rec.uom_code :=
            trx_lines_rec.uom_code;
         v_step := '045';
         ra_interface_lines_rec.mtl_system_items_seg1 :=
            trx_lines_rec.mtl_system_items_seg1;
         v_step := '046';
         cust_ar_agrupador_pkg.insert_ra_interface_line (
            ra_interface_lines_rec);
         v_count := v_count + 1;
      END LOOP;

      IF v_count = 0
      THEN
         raise_application_error (-20244,
                                  'No se encontraron registros para agrupar');
      END IF;

      CLOSE trx_lines_cur;

      cust_ar_agrupador_pkg.set_header_status (
         p_in_grouping_header_rec.header_id,
         c_correcto);
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;

         IF trx_lines_cur%ISOPEN
         THEN
            CLOSE trx_lines_cur;
         END IF;

         cust_ar_agrupador_pkg.set_header_status (
            p_in_grouping_header_rec.header_id,
            c_error);
         v_error_message :=
            SUBSTR (SQLERRM || CHR (10) || v_error_message, 1, 4000);
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message,
                         'p_in_grouping_header_rec.header_id ',
                         p_in_grouping_header_rec.header_id);
         concat_message (v_error_message, 'v_step ', v_step);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.agrupa_facturas',
            MESSAGE     => v_error_message);
   --raise_application_error (-20245, v_error_message);
   END agrupa_facturas;

   PROCEDURE agrupacion_automatica (
      errbuf           IN OUT VARCHAR2,
      retcode          IN OUT VARCHAR2,
      p_in_periodo     IN     VARCHAR2,
      p_in_barrido     IN     VARCHAR2,
      p_in_date_from   IN     VARCHAR2,
      p_in_date_to     IN     VARCHAR2,
      p_in_header_id   IN     VARCHAR2 DEFAULT NULL)
   IS
      TYPE cursor_reg IS REF CURSOR;

      grouping_header_cur   cursor_reg;
      grouping_header_rec   cust_ar_grouping_header_v%ROWTYPE;
      v_error_message       fnd_log_messages.MESSAGE_TEXT%TYPE
                               := 'AGRUPACION_AUTOMATICA';
      v_query               VARCHAR2 (2000) := NULL;
      v_where_clause        VARCHAR2 (2000) := NULL;
      v_line                VARCHAR2 (1000) := NULL;
      v_inv_err_count       NUMBER := 0;
      v_cm_err_count        NUMBER := 0;
      v_inv_count           NUMBER := 0;
      v_cm_count            NUMBER := 0;
      v_valor_periodo_ini   cust_ar_grouping_header.valor_periodo%TYPE
                               := NULL;
      v_valor_periodo_fin   cust_ar_grouping_header.valor_periodo%TYPE
                               := NULL;
      v_header_id           cust_ar_grouping_header.header_id%TYPE := 0;

      l_error               error_rec;
      l_error_tbl           errors_tbl;
   BEGIN
      l ('P_IN_PERIODO   : ' || p_in_periodo);
      l ('P_IN_BARRIDO   : ' || p_in_barrido);
      l ('P_IN_DATE_FROM : ' || p_in_date_from);
      l ('P_IN_DATE_TO   : ' || p_in_date_to);
      l ('CONCURRENT ID  : ' || l_conc_request_id);

      v_query := ' SELECT';
      v_query := v_query || CHR (10) || '   gh.*';
      v_query := v_query || CHR (10) || '  FROM cust_ar_grouping_header_v gh';
      v_query := v_query || CHR (10) || ' WHERE 1 = 1';

      IF p_in_header_id IS NOT NULL
      THEN
         v_where_clause := '   AND gh.header_id = ' || p_in_header_id;
      ELSE
         IF p_in_periodo IS NOT NULL
         THEN
            v_where_clause :=
                  v_where_clause
               || CHR (10)
               || '   AND gh.periodo = '''
               || p_in_periodo
               || '''';
         END IF;

         IF NVL (p_in_barrido, 'N') = 'Y'
         THEN
            IF p_in_date_from IS NOT NULL
            THEN
               v_valor_periodo_ini :=
                  cust_ar_agrupador_pkg.get_valor_periodo (
                     p_in_periodo,
                     TO_DATE (p_in_date_from, 'YYYY/MM/DD HH24/MI/SS'));
               v_where_clause :=
                     v_where_clause
                  || CHR (10)
                  || '   AND gh.valor_periodo >= '''
                  || v_valor_periodo_ini
                  || '''';
            END IF;

            IF p_in_date_to IS NOT NULL
            THEN
               v_valor_periodo_fin :=
                  cust_ar_agrupador_pkg.get_valor_periodo (
                     p_in_periodo,
                     TO_DATE (p_in_date_to, 'YYYY/MM/DD HH24/MI/SS'));
               v_where_clause :=
                     v_where_clause
                  || CHR (10)
                  || '   AND gh.valor_periodo <= '''
                  || v_valor_periodo_fin
                  || '''';
            END IF;

            cust_ar_agrupador_pkg.re_agrupa_trx (p_in_periodo,
                                                 v_valor_periodo_ini,
                                                 v_valor_periodo_fin);
         ELSE
            v_valor_periodo_ini :=
               cust_ar_agrupador_pkg.get_ultimo_periodo (p_in_periodo,
                                                         SYSDATE);
            v_where_clause :=
                  v_where_clause
               || CHR (10)
               || '   AND gh.valor_periodo = '''
               || v_valor_periodo_ini
               || '''';
         END IF;

         v_where_clause :=
            v_where_clause || CHR (10) || '   AND gh.agrupador_id  > 0';
      END IF;

      --v_where_clause := v_where_clause || CHR (10) || '   AND gh.ar_closing_status  =''O''';
      v_where_clause :=
            v_where_clause
         || CHR (10)
         || '   AND gh.status  IN ('''
         || c_nuevo
         || ''', '''
         || c_error
         || ''')';
      l (v_query || v_where_clause);
      v_line := v_line || format ('#', 6, 'R');
      v_line := v_line || format ('HEADER_ID', 10, 'R');
      v_line := v_line || format ('ORG_ID', 6, 'R');
      v_line := v_line || format ('STATUS', 6, 'L');
      v_line := v_line || format ('AGRUPADOR_ID', 12, 'R');
      v_line := v_line || format ('BILL_TO_CUSTOMER_ID', 19, 'R');
      v_line := v_line || format ('BILL_TO_ADDRESS_ID', 18, 'R');
      v_line := v_line || format ('SHIP_TO_ADDRESS_ID', 18, 'R');
      v_line := v_line || format ('INVOICE_CURRENCY_CODE', 21, 'L');
      v_line := v_line || format ('EXCHANGE_RATE', 13, 'R');
      v_line := v_line || format ('PERIODO', 7, 'L');
      v_line := v_line || format ('LOCALIDADES', 11, 'L');
      v_line := v_line || format ('VALOR_LOCALIDAD', 25, 'L');
      v_line := v_line || format ('PERIOD_NAME', 15, 'L');
      v_line := v_line || format ('VALOR_PERIODO', 13, 'L');
      o (v_line);

      OPEN grouping_header_cur FOR v_query || v_where_clause;

      LOOP
         FETCH grouping_header_cur INTO grouping_header_rec;

         EXIT WHEN grouping_header_cur%NOTFOUND;

         cust_ar_agrupador_pkg.create_all_credit_memo (
            errbuf           => errbuf,
            retcode          => retcode,
            p_in_header_id   => grouping_header_rec.header_id);
         retcode := 0;

         IF retcode = c_correcto
         THEN
            cust_ar_agrupador_pkg.agrupa_facturas (grouping_header_rec);
         ELSE
            IF retcode = c_advertencia
            THEN
               cust_ar_agrupador_pkg.set_header_status (
                  p_in_header_id   => grouping_header_rec.header_id,
                  p_in_status      => c_error);
               v_error_rec.header_id := grouping_header_rec.header_id;
               v_error_rec.desc_error :=
                     'No se pudo generar la factura agrupada '
                  || grouping_header_rec.header_id
                  || ' no existen remisiones';
               insert_error (v_error_rec, v_errors_tbl);
            ELSE
               cust_ar_agrupador_pkg.set_header_status (
                  p_in_header_id   => grouping_header_rec.header_id,
                  p_in_status      => c_error);

               v_error_rec.header_id := grouping_header_rec.header_id;
               v_error_rec.desc_error :=
                     'No se pudo generar la factura agrupada '
                  || grouping_header_rec.header_id;
               insert_error (v_error_rec, v_errors_tbl);
            END IF;
         END IF;

         IF cust_ar_agrupador_pkg.get_header_status (
               p_in_header_id   => grouping_header_rec.header_id) = c_correcto
         THEN
            v_inv_count := v_inv_count + 1;
         ELSE
            v_inv_err_count := v_inv_err_count + 1;
         END IF;

         IF cust_ar_agrupador_pkg.get_header_cm_status (
               p_in_header_id   => grouping_header_rec.header_id) = c_correcto
         THEN
            v_cm_count := v_cm_count + 1;
         ELSE
            v_cm_err_count := v_cm_err_count + 1;
         END IF;

         v_line := format (grouping_header_cur%ROWCOUNT, 6);
         v_line := v_line || format (grouping_header_rec.header_id, 10, 'R');
         v_line := v_line || format (grouping_header_rec.org_id, 6, 'R');
         --v_line := v_line || format (grouping_header_rec.status, 6, 'L');
         v_line :=
               v_line
            || format (
                  cust_ar_agrupador_pkg.get_header_status (
                     p_in_header_id   => grouping_header_rec.header_id),
                  6,
                  'L');
         v_line :=
            v_line || format (grouping_header_rec.agrupador_id, 12, 'R');
         v_line :=
               v_line
            || format (grouping_header_rec.bill_to_customer_id, 19, 'R');
         v_line :=
               v_line
            || format (grouping_header_rec.bill_to_address_id, 18, 'R');
         v_line :=
               v_line
            || format (grouping_header_rec.ship_to_address_id, 18, 'R');
         v_line :=
               v_line
            || format (grouping_header_rec.invoice_currency_code, 21, 'L');
         v_line :=
            v_line || format (grouping_header_rec.exchange_rate, 13, 'R');
         v_line := v_line || format (grouping_header_rec.periodo, 7, 'L');
         v_line :=
            v_line || format (grouping_header_rec.localidades, 11, 'L');
         v_line :=
            v_line || format (grouping_header_rec.valor_localidad, 25, 'L');
         v_line :=
            v_line || format (grouping_header_rec.period_name, 15, 'L');
         v_line :=
            v_line || format (grouping_header_rec.valor_periodo, 13, 'L');
         o (v_line);
      END LOOP;

      CLOSE grouping_header_cur;

      COMMIT;
      o ('           Facturas Agrupadas : ' || v_inv_count);
      o ('                     Creditos : ' || v_cm_count);
      o ('Errores en Facturas Agrupadas : ' || v_inv_err_count);
      o ('          Errores en Creditos : ' || v_cm_err_count);


      IF v_errors_tbl.COUNT > 0
      THEN
         o ('');
         o ('');
         o ('+---------------------------------------');
         o ('| Errores ' || v_errors_tbl.COUNT);
         o ('+---------------------------------------');

         FOR i IN v_errors_tbl.FIRST .. v_errors_tbl.COUNT
         LOOP
            IF v_header_id <> v_errors_tbl (i).header_id
            THEN
               o ('Header id : ' || v_errors_tbl (i).header_id);
               v_header_id := v_errors_tbl (i).header_id;
            END IF;

            o ('        Error: ' || v_errors_tbl (i).desc_error);
         END LOOP;
      END IF;

      IF v_inv_err_count + v_cm_err_count > 0
      THEN
         retcode := c_advertencia;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;

         IF grouping_header_cur%ISOPEN
         THEN
            CLOSE grouping_header_cur;
         END IF;

         retcode := c_error;
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         l (v_error_message);
         concat_message (v_error_message,
                         'request_id',
                         fnd_global.conc_request_id);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.agrupacion_automatica',
            MESSAGE     => v_error_message);
         raise_application_error (-20246, v_error_message);
   END agrupacion_automatica;

   PROCEDURE submit_grouping_inv (p_in_header_id IN NUMBER)
   AS
      v_phase                 VARCHAR2 (80) := NULL;
      v_status                VARCHAR2 (80) := NULL;
      v_dev_phase             VARCHAR2 (80) := NULL;
      v_dev_status            VARCHAR2 (80) := NULL;
      v_message               VARCHAR2 (80) := NULL;
      v_new_conc_request_id   NUMBER;
      v_error_message         fnd_log_messages.MESSAGE_TEXT%TYPE
                                 := 'SUBMIT SUBMIT_GROUPING_INV';
   BEGIN
      v_new_conc_request_id :=
         apps.fnd_request.submit_request (
            application   => 'AR',
            PROGRAM       => 'CUST_AR_GROUPING_INV',
            description   => '',
            start_time    => '',
            sub_request   => FALSE,
            argument1     => '',
            argument2     => '',
            argument3     => '',
            argument4     => '',
            argument5     => p_in_header_id,
            argument6     => CHR (0));
      COMMIT;

      IF v_new_conc_request_id = 0
      THEN
         raise_application_error (
            -20247,
            'No se peude ejecutar programa de agrupacion');
      ELSE
         l (
               ' Autoinvoice Master Program conc_request_id '
            || v_new_conc_request_id);

         IF fnd_concurrent.wait_for_request (
               request_id   => v_new_conc_request_id,
               INTERVAL     => 10,
               max_wait     => NULL,
               phase        => v_phase,
               status       => v_status,
               dev_phase    => v_dev_phase,
               dev_status   => v_dev_status,
               MESSAGE      => v_message)
         THEN
            l ('Phase        ' || v_phase);
            l ('Status       ' || v_status);
            l ('Dev_Phase    ' || v_dev_phase);
            l ('Sev_Status   ' || v_dev_status);
            l ('Message      ' || v_message);
         ELSE
            v_error_message :=
               SUBSTR (
                     v_error_message
                  || CHR (10)
                  || 'No se peude esperar por solicitud '
                  || v_new_conc_request_id,
                  1,
                  4000);
            concat_message (v_error_message, 'Status', v_status);
            raise_application_error (-20248, v_error_message);
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_message :=
            SUBSTR (
               v_error_message || CHR (10) || DBMS_UTILITY.format_call_stack,
               1,
               4000);
         concat_message (v_error_message, 'p_in_header_id ', p_in_header_id);
         l (v_error_message);
         fnd_log.STRING (
            log_level   => fnd_log.level_unexpected,
            module      => 'cust_ar_agrupador_pkg.get_period_name',
            MESSAGE     => v_error_message);
         raise_application_error (-20249, v_error_message);
   END submit_grouping_inv;

   /* SE CREA UNA FUNCION PARA OBTENER EL ESTATUS DEL PERIODO, ABIERTO O CERRADO
  *  JIBARRA 25-OCT-2017
  */
   FUNCTION GET_ESTATUS_PERIODO (P_PERIODO VARCHAR2)
      RETURN VARCHAR2
   AS
      V_ESTATUS_PERIODO   VARCHAR2 (100);
   BEGIN
        SELECT GS.CLOSING_STATUS
          INTO V_ESTATUS_PERIODO
          FROM GL.GL_PERIOD_STATUSES GS, APPS.FND_APPLICATION_TL FA
         WHERE     FA.APPLICATION_ID = GS.APPLICATION_ID
               AND FA.APPLICATION_NAME IN ('Receivables')
               AND GS.SET_OF_BOOKS_ID = 2021 --:set_of_books_d -- your set of books id
               AND GS.PERIOD_NAME = P_PERIODO --in ('OCT-17')-- Period Name/s for which you want to check
               AND CLOSING_STATUS IN ('O', 'W', 'C')
      GROUP BY PERIOD_NAME, APPLICATION_NAME, GS.CLOSING_STATUS
      ORDER BY PERIOD_NAME DESC;

      RETURN V_ESTATUS_PERIODO;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         L (
               'GET_ESTATUS_PERIODO - VALIDAR EL PARAMETRO DEL PERIODO, NO SE ENCONTRO INFORMACION:: '
            || P_PERIODO);
         O (
               'GET_ESTATUS_PERIODO - VALIDAR EL PARAMETRO DEL PERIODO, NO SE ENCONTRO INFORMACION:: '
            || P_PERIODO);
         RETURN NULL;
      WHEN OTHERS
      THEN
         L ('GET_ESTATUS_PERIODO - ERROR:: ' || SQLERRM);
         O ('GET_ESTATUS_PERIODO - ERROR:: ' || SQLERRM);
         RETURN NULL;
   END GET_ESTATUS_PERIODO;
END cust_ar_agrupador_pkg;