CREATE OR REPLACE PACKAGE BODY CFDI_AP_AR.XXCASH_APEX_CASHLESS_PKG AS
   
    -- Importa la información de SIO deposita en DW.
    -- Estatus: NUEVO --> generado header --> conciliado.
    
    -- $Id: CFDI_AP_AR.XXCASH_APEX_CASHLESS_PKG.pkb 4482 2023-11-28 19:44:59Z vvelasco $
    -- $URL: http://mxapediprdl.gepp.pvt:18080/svn/r12/Developer/CASH/SantaderCashless/CFDI_AP_AR.XXCASH_APEX_CASHLESS_PKG.pkb $
    
    FUNCTION imp_dw_sio_fnc RETURN VARCHAR2 IS
        PRAGMA autonomous_transaction;
    BEGIN

        -- Importamos datos de DW
        INSERT INTO cfdi_ap_ar.sto_conciliacion_bancos_tbl (
                    ID,
                    CLAVE_BODEGA,
                    REFERENCIA_GLOBAL,
                    REFERENCIA_BANCARIA,
                    FECHA_VENTA,
                    MONTO,
                    TIPO_PAGO,
                    ID_POLIZA,
                    UNIDAD_OPERATIVA,
                    REGION,
                    ESTATUS,
                    CREATION_DATE,
                    LAST_UPDATED_DATE,
                    PERIOD_NAME)
            SELECT cfdi_ap_ar.sto_sio_seq.nextval,
                   dwhsio.clave_bodega,
                   dwhsio.referencia_global,
                   TRIM(dwhsio.referencia_bancaria),
                   dwhsio.fecha_venta,
                   dwhsio.monto,
                   TRIM(dwhsio.tipo_pago),
                   TRIM(dwhsio.id_poliza),
                   TRIM(dwhsio.unidad_operativa),
                   TRIM(dwhsio.REGION),
                   'NUEVO'                                estatus,
                   sysdate                                    creation_date,
                   sysdate                                    last_updated_date
                   ,to_char(dwhsio.fecha_venta,'MON-YY','NLS_DATE_LANGUAGE=SPANISH') periodo_name

            FROM dwstorage.sto_conciliacion_bancos@oraprod19_to_dwh   dwhsio                 
            WHERE NOT EXISTS (select 'ex'
                                from cfdi_ap_ar.sto_conciliacion_bancos_tbl sto
                                WHERE trim(dwhsio.referencia_bancaria) = sto.referencia_bancaria)
            and instr(dwhsio.referencia_bancaria,'-')=5
            AND fecha_venta >= to_date('01-10-2023','dd-mm-yyyy');

-- DBMS_OUTPUT.PUT_LINE('antes commit: ') ;
            COMMIT;

        -- Se actualizan los datos faltantes
        BEGIN
            UPDATE cfdi_ap_ar.sto_conciliacion_bancos_tbl dwhsio
            SET (SEGMENT5, SEGMENT6) = (SELECT regexp_substr(lookup_code, '[^-"]+', 1, 2) segment5
                                               ,regexp_substr(lookup_code, '[^-"]+', 1, 3) segment6
                                        FROM apps.fnd_lookup_values@ora19_to_ebsprod       fl
                                        WHERE 1=1
                                        AND fl.language = 'ESA'
                                        AND fl.lookup_type = 'XXCASH_REG_CASHLESS_LV'
                                        AND regexp_substr(fl.description, '[^|"]+', 1, 2) = TRIM(dwhsio.region)
                                        )
                ,(ORG_ID, CIA_NAME) = (SELECT hao.organization_id
                                              ,hao.name
                                            FROM hr.hr_all_organization_units@ORA19_TO_EBSPROD hao
                                            WHERE 1=1
                                            AND hao.name = TRIM(substr(dwhsio.id_poliza,2,instr(dwhsio.id_poliza, ' ') - 1))
                                            )
            WHERE 1=1
            AND ESTATUS = 'NUEVO';
            COMMIT;

            -- Se valida si todos los campos ya tienen compañia y segment5 y 6
            declare
                v_count number;
            begin
                v_count := 0;

                select count(*)
                into v_count
                from cfdi_ap_ar.sto_conciliacion_bancos_tbl dwhsio
                where 1=1
                AND ESTATUS = 'NUEVO'                
                and cia_name is null;

                if v_count = 0 then 
                    -- Inserta el cabecero
                    -- Generamos el header
                    INSERT INTO cfdi_ap_ar.sto_conciliacion_bancos_head_tbl (
                        id,
                        id_poliza,
                        fecha_venta,
                        referencia_global,
                        unidad_operativa,
                        clave_bodega,
                        tipo_pago,
                        smonto,
                        estatus,
                        period_name,
                        last_updated_date,
                        creation_date,
                        org_id,
                        cia_name,
                        segment5,
                        segment6,
                        REGION,
                        ESTATUS_MSJ
                    )
                        SELECT cfdi_ap_ar.sto_sio_head_seq.nextval,
                               a.*
                        FROM (
                            SELECT id_poliza,
                                   fecha_venta,
                                   referencia_global,
                                   unidad_operativa,
                                   clave_bodega,
                                   tipo_pago,
                                   SUM(monto) AS smonto,
                                   'NUEVO'    estatus,
                                   to_char(fecha_venta,'MON-YY','NLS_DATE_LANGUAGE=SPANISH') periodo_name,
                                   sysdate    last_updated_date,
                                   sysdate    creation_date,
                                   org_id,
                                   cia_name,
                                   segment5,
                                   segment6,
                                   REGION
                                   ,null--'SIN CONCILIAR DETALLE' ESTATUS_MSJ
                            FROM cfdi_ap_ar.sto_conciliacion_bancos_tbl tsio
                            WHERE NOT EXISTS (
                                                SELECT fecha_venta
                                                FROM sto_conciliacion_bancos_head_tbl head
                                                WHERE head.id_poliza = tsio.id_poliza
                                                  AND head.fecha_venta = tsio.fecha_venta
                                            )
                            GROUP BY id_poliza,
                                     fecha_venta,
                                     referencia_global,
                                     unidad_operativa,
                                     clave_bodega,
                                     tipo_pago,
                                     org_id,
                                     cia_name,
                                     segment5,
                                     segment6,
                                     REGION
                        ) a;

                    COMMIT;
                end if;
            end;


        EXCEPTION
            WHEN OTHERS THEN
                NULL;
                DBMS_OUTPUT.PUT_LINE('ERROr: ' ||SQLERRM);
                return SQLERRM;
                -- Si ocurre un error no truena el proceso pero deja los datos vacios
                -- No genera el Headaer hasta que se valide por que no hace match con los datos
        END;

         COMMIT;
        RETURN '0';
--    exception 
--        when others then
--            RETURN '1 ERROR';
    END imp_dw_sio_fnc;

    -- Funcion para importar los datos de GL
    FUNCTION imp_gl_fnc RETURN VARCHAR2 IS
        v_cuenta_contable VARCHAR2(5) := '1102';
        PRAGMA autonomous_transaction;
    BEGIN

        -- Insertamos de EBS
        INSERT INTO xxcash_cashless_gl_ctrl_tbl (
            id,
            accounting_date,
            segment1,
            segment5,
            segment6,
            reference11,
            reference13,
            id_poliza,
            tipo_pago,
            scr,
            sdr,
            fecha_creacion,
            group_id,
            estatus,
            last_updated_date,
            creation_date,
            period_name,
            org_id,
            cia_name
            --,ESTATUS_MSJ
        )
            SELECT "CFDI_AP_AR"."GL_CTR_SEQ".nextval,
                   a.*
            FROM (
                SELECT tgl.accounting_date,
                       segment1,
                       segment5,
                       segment6,
                       tgl.reference11,
                       tgl.reference13,
                       tgl.reference6      AS id_poliza,
                       tgl.reference12     AS tipo_pago,
                       SUM(tgl.entered_cr) scr,
                       SUM(tgl.entered_dr) sdr,
                       date_created        AS fecha_creacion,
                       group_id,
                       'NUEVO'             AS estatus,
                       sysdate             last_update_date,
                       sysdate             creation_date,
                       to_char(tgl.accounting_date,'MON-YY','NLS_DATE_LANGUAGE=SPANISH')                periodo_name,
                       hao.organization_id,
                       hao.name
                       --,'SIN CONCILIAR DETALLE' ESTATUS_MSJ
                FROM gl.gl_interface@ora19_to_ebsprod              tgl,
                     hr.hr_all_organization_units@ora19_to_ebsprod hao
                WHERE 1 = 1
                      and tgl.reference12 is not null
                      AND (SEGMENT5, SEGMENT6) IN (SELECT regexp_substr(lookup_code, '[^-"]+', 1, 2) segment5
                                                           ,regexp_substr(lookup_code, '[^-"]+', 1, 3) segment6
                                                    FROM apps.fnd_lookup_values@ora19_to_ebsprod       fl
                                                    WHERE 1=1
                                                    AND fl.lookup_type = 'XXCASH_REG_CASHLESS_LV'
                                                    AND fl.language = 'ESA')
                      --AND tgl.segment5 = v_cuenta_contable
                      --AND tgl.reference12 IN ( 'TDC', 'TDD', 'CODI' )
                      AND hao.attribute15 = tgl.segment1
                      AND NOT EXISTS (
                                        SELECT reference11
                                        FROM xxcash_cashless_gl_ctrl_tbl ccgl
                                        WHERE ccgl.reference13 = tgl.reference13
                                    )
                GROUP BY tgl.reference13,
                         tgl.reference6,
                         tgl.reference12,
                         tgl.reference11,
                         tgl.accounting_date,
                         segment1,
                         segment5,
                         segment6,
                         date_created,
                         group_id,
                         hao.organization_id,
                         hao.name
            ) a;

        COMMIT;
        RETURN '0';
--    exception 
--        when others then
--            ROLLBACK;
--            RETURN '1';
    END imp_gl_fnc;


-- Funcion para conciliar GL vs SIO
    FUNCTION conciliasiovsgl RETURN VARCHAR2 IS

        param1              VARCHAR2(100) := NULL;
        v_poliza            VARCHAR2(100);
        v_fecha_venta       DATE;
        v_gl_cia            VARCHAR2(100);
        v_org_id            NUMBER;
        v_estatus           VARCHAR2(100);
        v_tipo_pago         VARCHAR2(10);
        v_monto             NUMBER;
        v_id                NUMBER;
        v_referencia_global VARCHAR2(100);
        v_estatus_final     VARCHAR2(100);
        v_estatus_gl varchar2(100);
        PRAGMA autonomous_transaction;
    BEGIN       -- Conciliar GL vs DWH

        FOR cur  IN (SELECT gl.id ID_GL, sio.id ID_SIO,GL.SDR MONTO_GL, SIO.SMONTO MONTO_SIO,gl.id_poliza
                        FROM cfdi_ap_ar.xxcash_cashless_gl_ctrl_tbl gl  -- Tabla GL
                            ,cfdi_ap_ar.sto_conciliacion_bancos_head_tbl sio
                        WHERE gl.estatus IN ('NUEVO','NO ENCONTRADO')
                        AND sio.estatus IN ('NUEVO','NO ENCONTRADO')
                        --AND sio.estatus_msj = gl.ESTATUS_MSJ
                        --AND sio.estatus_msj = 'DETALLE CONCILIADO'
                          AND sio.fecha_venta = gl.accounting_date
                          AND sio.id_poliza = gl.id_poliza
                          AND sio.tipo_pago = gl.tipo_pago)
        LOOP
            v_estatus_gl := null;
            IF cur.MONTO_GL = cur.MONTO_SIO then
                v_estatus_gl := 'CONCILIADO';
                update cfdi_ap_ar.xxcash_cashless_gl_ctrl_tbl GL
                set GL.estatus = v_estatus_gl
                    ,LAST_UPDATED_DATE =SYSDATE
                WHERE ID = cur.ID_GL;

                update cfdi_ap_ar.sto_conciliacion_bancos_head_tbl sio
                set sio.estatus = v_estatus_gl
                    ,SIO.LAST_UPDATED_DATE = SYSDATE
                WHERE ID = cur.id_sio;
            ELSE
                v_estatus_gl := 'NO CONCILIADO';
                update cfdi_ap_ar.xxcash_cashless_gl_ctrl_tbl GL
                set GL.estatus = v_estatus_gl
                    ,LAST_UPDATED_DATE =SYSDATE
                WHERE ID = cur.id_GL;

                update cfdi_ap_ar.sto_conciliacion_bancos_head_tbl sio
                set sio.estatus = v_estatus_gl
                    ,SIO.LAST_UPDATED_DATE = SYSDATE
                WHERE ID = cur.id_sio;
            END IF;

            COMMIT;
            if v_estatus_gl = 'CONCILIADO' THEN
                -- Se actualizan el estatus de la tabla gl_interface

                UPDATE gl.gl_interface@ora19_to_ebsprod tgl
                SET tgl.ledger_id = abs(tgl.ledger_id)
                    ,tgl.attribute13 = v_estatus_gl   --@TODO Solo para probar quitar en prod.
                WHERE tgl.reference6 = cur.id_poliza
                and tgl.ledger_id <0;

                COMMIT;
            END IF;
        END LOOP;

        -- TODO LO QUE SE QUEDO EN NUEVO PASA A NO ENCONTRADO
        update cfdi_ap_ar.xxcash_cashless_gl_ctrl_tbl gl
        set gl.estatus = 'NO ENCONTRADO'
            ,LAST_UPDATED_DATE =SYSDATE
        WHERE ESTATUS = 'NUEVO';

        update cfdi_ap_ar.sto_conciliacion_bancos_head_tbl sio
        set sio.estatus = 'NO ENCONTRADO'
            ,SIO.LAST_UPDATED_DATE = SYSDATE
        WHERE ESTATUS = 'NUEVO';

        COMMIT;


         -- Se valida que ya esta en GL
         declare
            vReturn varchar2(1000);
         begin
            vReturn := revisa_gl_posted_fnc();
         end;
         COMMIT;
         RETURN '0';
    END conciliasiovsgl;


-- Funcion para conciliar banco vs SIO. 
-- Excepcion especial los movimientos SIO que las fechas no coinciden.
    FUNCTION conciliacionbancovssio RETURN VARCHAR2 IS
        texto VARCHAR2(10);
        PRAGMA autonomous_transaction;
    BEGIN
        FOR cur IN (SELECT banco.id id_banco, banco.line_number, sio.id id_sio ,banco.monto MONTO_BANCO, sio.monto MONTO_SIO,sio.period_name period_name_sio
                          ,banco.fecha_operacion FECHA_BANCO, sio.fecha_venta FECHA_SIO, sio.tipo_pago
                    FROM cfdi_ap_ar.xxcash_lines_file_sant_tbl banco
                        ,cfdi_ap_ar.sto_conciliacion_bancos_tbl sio                        
                    WHERE 1=1
                        and banco.REFERENCIA_SIO = sio.REFERENCIA_BANCARIA
                        and sio.estatus IN ('NUEVO','NO ENCONTRADO','NO CONCILIADO')
                        AND banco.estatus IN ('NUEVO','NO ENCONTRADO','NO CONCILIADO')
                        --and banco.monto = sio.monto
                    )
        LOOP
            IF cur.MONTO_BANCO != cur.MONTO_SIO then                            
                update cfdi_ap_ar.xxcash_lines_file_sant_tbl banco
                set banco.estatus = 'NO CONCILIADO'
                    ,LAST_UPDATED_DATE =SYSDATE
                    ,period_name = cur.period_name_sio
                    ,msj_status = 'EL MONTO DEL BANCO ES DIFERENTE AL DE SIO'
                WHERE ID = cur.id_banco
                and line_number = cur.line_number;

                update cfdi_ap_ar.sto_conciliacion_bancos_tbl sio
                set sio.estatus = 'NO CONCILIADO'
                    ,SIO.LAST_UPDATED_DATE = SYSDATE
                    ,estatus_msj = 'EL MONTO DEL BANCO ES DIFERENTE AL DE SIO'
                WHERE ID = cur.id_sio;
            ELSIF (cur.FECHA_BANCO != cur.FECHA_SIO) AND (cur.tipo_pago <> 'CODI') then
                update cfdi_ap_ar.xxcash_lines_file_sant_tbl banco
                set banco.estatus = 'NO CONCILIADO'
                    ,LAST_UPDATED_DATE =SYSDATE
                    ,period_name = cur.period_name_sio
                    ,msj_status = 'LA FECHA DEL BANCO ES DIFERENTE A LA FECHA DE SIO'
                WHERE ID = cur.id_banco
                and line_number = cur.line_number;

                update cfdi_ap_ar.sto_conciliacion_bancos_tbl sio
                set sio.estatus = 'NO CONCILIADO'
                    ,SIO.LAST_UPDATED_DATE = SYSDATE
                    ,estatus_msj = 'LA FECHA DEL BANCO ES DIFERENTE A LA FECHA DE SIO'
                WHERE ID = cur.id_sio;
            ELSE
                update cfdi_ap_ar.xxcash_lines_file_sant_tbl banco
                set banco.estatus = 'CONCILIADO'
                    ,LAST_UPDATED_DATE =SYSDATE
                    ,period_name = cur.period_name_sio
                    ,msj_status = NULL
                WHERE ID = cur.id_banco
                and line_number = cur.line_number;

                update cfdi_ap_ar.sto_conciliacion_bancos_tbl sio
                set sio.estatus = 'CONCILIADO'
                    ,SIO.LAST_UPDATED_DATE = SYSDATE
                    ,estatus_msj = NULL                    
                WHERE ID = cur.id_sio;
            END IF;

            COMMIT;
        END LOOP;

        -- se revisa si alguna linea del cabecero de SIO pasa a conciliado a nivel detalle
        /*for cur in (SELECT sio.id_poliza
                            ,sio.fecha_venta
                            ,SIO.referencia_global
                            ,SUM(CASE WHEN SIOL.ESTATUS != 'CONCILIADO' THEN 1 ELSE 0 END) NO_CONCILIADOS
                        from cfdi_ap_ar.sto_conciliacion_bancos_head_tbl sio
                             ,cfdi_ap_ar.sto_conciliacion_bancos_tbl siol
                        WHERE 1=1
                        AND sio.estatus IN ('NUEVO','NO ENCONTRADO')
                        AND (sio.estatus_msj = 'SIN CONCILIAR DETALLE' OR SIO.estatus_msj IS NULL) 
                        and sio.id_poliza = siol.id_poliza
                        and sio.fecha_venta = siol.fecha_venta
                        and sio.referencia_global = siol.referencia_global
                        --and siol.estatus != 'CONCILIADO'
                        GROUP BY sio.id_poliza
                            ,sio.fecha_venta
                            ,SIO.referencia_global
                        )
        LOOP
            -- si no conciliados es 0 se cambia a estatus 'DETALLE CONCILIADO'
            IF cur.no_conciliados = 0 then
                UPDATE cfdi_ap_ar.sto_conciliacion_bancos_head_tbl sio
                SET ESTATUS_MSJ ='DETALLE CONCILIADO'
                WHERE 1=1
                AND sio.id_poliza = cur.id_poliza
                AND sio.fecha_venta = cur.fecha_venta
                AND sio.referencia_global = cur.referencia_global; 

                commit;
            END IF;
        END LOOP;*/

        -- TODO LO QUE SE QUEDO EN NUEVO PASA A NO ENCONTRADO
        update cfdi_ap_ar.xxcash_lines_file_sant_tbl banco
            set banco.estatus = 'NO ENCONTRADO'
                ,LAST_UPDATED_DATE =SYSDATE
            WHERE ESTATUS = 'NUEVO';

            update cfdi_ap_ar.sto_conciliacion_bancos_tbl sio
            set sio.estatus = 'NO ENCONTRADO'
                ,SIO.LAST_UPDATED_DATE = SYSDATE
            WHERE ESTATUS = 'NUEVO';

            COMMIT;

        RETURN '0';
    END conciliacionbancovssio;

    FUNCTION revisa_gl_posted_fnc RETURN VARCHAR2
    IS
        v_lote           VARCHAR2 (100);
        v_asiento        VARCHAR2 (100);
        v_status         VARCHAR2 (1);
        v_fecha_posteo   DATE;
        v_Je_Header_Id number;
    BEGIN
        -- barre las polizas conciliadas para ver si ya estan en GL
        FOR GL_CONCILIADOS IN (  SELECT id_poliza,PERIOD_NAME
                                   FROM xxcash_cashless_gl_ctrl_tbl
                                  WHERE 1 = 1 
                                  AND estatus = 'CONCILIADO'
                                  AND GL_Je_Header_Id IS NULL
                                  --and id_poliza = '(BEPUSA TRADICIO)VT202302151028_0181'
                               GROUP BY id_poliza,PERIOD_NAME)
        LOOP
            FOR cur IN (SELECT gb.name             lote,
                               gjh.name            asiento,
                               gjh.status,
                               gjh.posted_date     
                               ,Gjh.Je_Header_Id              
                          FROM gl.gl_je_headers@ora19_to_ebsprod     gjh,
                               gl.gl_je_batches@ora19_to_ebsprod     gb
                         WHERE     1 = 1
                               AND GJH.PERIOD_NAME = gl_conciliados.period_name
                               AND gb.je_batch_id = gjh.je_batch_id
                               AND gjh.external_reference = GL_CONCILIADOS.id_poliza)
            LOOP
                UPDATE xxcash_cashless_gl_ctrl_tbl
                   SET GL_STATUS = CUR.status,
                       GL_LOTE = CUR.lote,
                       GL_ASIENTO = CUR.asiento,
                       GL_FECHA_POSTEO = CUR.posted_date
                       ,GL_Je_Header_Id = CUR.Je_Header_Id
                       ,LAST_UPDATED_DATE = sysdate
                 WHERE id_poliza = GL_CONCILIADOS.id_poliza;
                COMMIT;
            END LOOP;            
        END LOOP;

        -- barre las polizas conciliadas que aun no esten posteadas en tabla de cashless para ver si ya han cambiado de estatus
        FOR GL_CONCILIADOS IN (  SELECT GL_Je_Header_Id,id_poliza
                                   FROM xxcash_cashless_gl_ctrl_tbl
                                  WHERE 1 = 1 
                                  AND estatus = 'CONCILIADO'
                                  AND GL_Je_Header_Id IS NOT NULL
                                  AND GL_STATUS != 'P' 
                               GROUP BY GL_Je_Header_Id,id_poliza)
        LOOP
            FOR cur IN (SELECT gjh.status,
                               gjh.posted_date                
                          FROM gl.gl_je_headers@ora19_to_ebsprod     gjh
                         WHERE     1 = 1
                               AND gjh.Je_Header_Id = GL_CONCILIADOS.GL_Je_Header_Id)
            LOOP
                UPDATE xxcash_cashless_gl_ctrl_tbl
                   SET GL_STATUS = CUR.status,                       
                       GL_FECHA_POSTEO = CUR.posted_date
                       ,LAST_UPDATED_DATE = sysdate
                 WHERE id_poliza = GL_CONCILIADOS.id_poliza
                 and GL_Je_Header_Id = GL_CONCILIADOS.GL_Je_Header_Id;
                COMMIT;
            END LOOP;            
        END LOOP;

        RETURN '0';
    END revisa_gl_posted_fnc;
END XXCASH_APEX_CASHLESS_PKG;