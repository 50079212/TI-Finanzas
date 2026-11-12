CREATE OR REPLACE EDITIONABLE FUNCTION "APPS"."XXAR_SLA_GAIN_LOST_CCID" (p_GAIN_LOST_CCID   IN NUMBER,
                                                                        P_cash_receipt_id            IN NUMBER,
                                                                        p_gain_lost_type IN VARCHAR2
                                                                        ,p_gain_system IN varchar2
                                                                        ,p_lost_system IN varchar2)
    RETURN NUMBER
IS
    v_code_combination_id number;
    v_tipo_cliente varchar2(100);
    v_org_id    number;
    vl_gain_lost_type varchar2(20);
    v_cta_sla_gain_lost varchar2(50);
    v_no_cliente varchar2(20);
	v_GAIN_LOST_TYPE varchar2(20);
BEGIN    
	IF p_GAIN_LOST_CCID = p_gain_system THEN
		v_GAIN_LOST_TYPE := 'GAIN';
	ELSIF p_GAIN_LOST_CCID = p_lost_system THEN
		v_GAIN_LOST_TYPE := 'LOST';
	END IF;
	
	--v_GAIN_LOST_TYPE := p_gain_lost_type;

    IF p_GAIN_LOST_CCID IS NOT NULL THEN
        v_code_combination_id := 1;
        --Se obtiene el tipo de cliente
        begin
            select case when cm.prov_invalidos is null then
                                    'TERCERO'
                              when cm.prov_invalidos like 'ASOCI%' then
                                    'ASOCIADA'
                              when cm.prov_invalidos like 'INTERCO%' then
                                    'ICIA'
                              else
                                'OTRA'
                         end
                         ,r.org_id
                         ,cm.customer_number
            INTO v_tipo_cliente,v_org_id,v_no_cliente
            from AR_CASH_RECEIPTS_ALL r
                ,cm_mstr cm
            where 1=1
            and r.cash_receipt_id = P_cash_receipt_id
            and cm.site_use_id = r.CUSTOMER_SITE_USE_ID
            and cm.org_id = r.org_id;
            
        exception 
            when others then
                v_tipo_cliente :='OTRA ERR';
        end;
        -- Si no es posible obtener el tipo de cliente deja el valor 1
        IF v_tipo_cliente NOT IN ('OTRA','OTRA ERR') THEN
            v_code_combination_id := 2;
            -- Se asigna la variable para el lookup de perdida o ganancia
            IF v_GAIN_LOST_TYPE = 'GAIN' THEN
                --v_code_combination_id := 2070068;
                vl_gain_lost_type :='GANANCIA';
            ELSIF v_GAIN_LOST_TYPE = 'LOST' THEN
                vl_gain_lost_type :='PERDIDA';
                --v_code_combination_id := 2070069;
            ELSE
                vl_gain_lost_type :='OTRO';
                --v_code_combination_id :=1;
            END IF;
            IF vl_gain_lost_type != 'OTRO' THEN
                v_code_combination_id := 3;
                v_cta_sla_gain_lost := 'VACIO';
                for cur in (SELECT  FL.DESCRIPTION AS CTA_PERDIDA_GANACIA
                            FROM apps.fnd_lookup_values  fl
                            WHERE 1=1
                            AND fl.language = 'ESA'
                            AND fl.lookup_type = 'XXAR_CUENTAS_PERDIDA_GANANCIA'
                            AND enabled_flag='Y'
                            and regexp_substr(fl.meaning, '[^_"]+', 1, 1) = vl_gain_lost_type
                            and regexp_substr(fl.meaning, '[^_"]+', 1, 2) = v_tipo_cliente
                            and regexp_substr(fl.meaning, '[^_"]+', 1, 3) = v_org_id)
                LOOP
                    if v_tipo_cliente in ('ICIA') then
                        v_cta_sla_gain_lost := substr(cur.CTA_PERDIDA_GANACIA,1,26) || v_no_cliente;
                    elsif v_tipo_cliente in ('ASOCIADA') then
                    	begin
                    		v_code_combination_id := 5;
                    		select  valor
                    		into	v_no_cliente
				from    apps.xxar_mapeo_lines_cust
				where   1 = 1
				and     tipo_transaccion = 'INGRESOS'
				and     tipo_cliente = v_tipo_cliente
				and     no_cadena = v_no_cliente;
				v_cta_sla_gain_lost := substr(cur.CTA_PERDIDA_GANACIA,1,26) || v_no_cliente;
			exception 
            			when others then
                		v_tipo_cliente :='ERR ASOCIADA';	
                    	end;
                    else
                        v_cta_sla_gain_lost := cur.CTA_PERDIDA_GANACIA;
                    end if;
                END LOOP;
                -- obtiene el code_combination_id de la cuenta
                IF v_cta_sla_gain_lost != 'VACIO' THEN
                    v_code_combination_id := 4;
                    FOR cur IN (SELECT CODE_COMBINATION_ID
                                 FROM GL_CODE_COMBINATIONS_KFV
                                 WHERE 1=1
                                 AND CONCATENATED_SEGMENTS = v_cta_sla_gain_lost)
                    LOOP
                        v_code_combination_id := CUR.CODE_COMBINATION_ID;
                    END LOOP;
                END IF;        
            END IF;
        END IF;
    END IF;
    --v_code_combination_id := p_GAIN_LOST_CCID;
    INSERT INTO XXWEBC.XXAR_DATOSPBA_SLA (CODE_COMBINATION_ID, CASH_RECEIPT_ID,GAIN_LOST_TYPE,FECHA,CTA_GAIN_LOST,TIPO_CLIENTE,GANANCIAPERDIDA,org_id)
    VALUES (v_code_combination_id, P_cash_receipt_id,p_gain_lost_type,SYSDATE,v_cta_sla_gain_lost,v_tipo_cliente,v_GAIN_LOST_TYPE || '-' || vl_gain_lost_type || '-' || p_gain_system ||'-'||p_lost_system,v_org_id);
     --VALUES (v_code_combination_id, P_cash_receipt_id,p_gain_lost_type,SYSDATE,v_cta_sla_gain_lost,v_tipo_cliente,vl_gain_lost_type,v_org_id);
    --COMMIT;
    --v_code_combination_id := p_GAIN_LOST_CCID;
    
    RETURN v_code_combination_id;
END XXAR_SLA_GAIN_LOST_CCID;