CREATE OR REPLACE VIEW xxwebc.XXAR_PRECIOS_SKU_V1
AS
select sq.org_id
    ,sq.name
    ,sq.organization_code
    ,sq.organization_name
    ,sq.item_no
    ,sq.descripcion
    ,sq.enabled_flag
    ,sq.factura_activada
    ,sq.codigo_estado
    ,sq.codigo_impuesto_sku
    ,sq.percentage_rate_iva_sku
    ,sq.percentage_rate_ieps_sku
    ,sq.tiene_estimulo
    ,sq.tiene_mapeo_ieps
    ,sq.ieps
    ,sq.ieps_litro
    ,sq.ieps_ed
    ,sq.ieps_litro_ed
    ,case when sq.tiene_estimulo = 'SI' then 'ESTIMULO'
          when sq.codigo_impuesto_sku is not null THEN 'SKU'
          else 'CLIENTE'
      end factor_iva_obtenido_en
    ,case when sq.tiene_estimulo = 'SI' then 0
          when sq.codigo_impuesto_sku is not null THEN sq.percentage_rate_iva_sku
          else null
      end factor_iva_sku
    ,case when sq.percentage_rate_ieps_sku is null then 0
          when sq.codigo_impuesto_sku is not null THEN sq.percentage_rate_ieps_sku
          else 0
      end factor_ieps_ener_alim_sku
    ,NVL(sq.ieps_litro,0)+NVL(sq.ieps_litro_ed,0) as ieps_x_sku   
from (
        SELECT 
            ou.organization_id   AS org_id,
            ou.name              AS name,
            osp.master_organization_id AS organization_id,
            iop.organization_code AS organization_code,
            haou.name            AS organization_name
            ,b.segment1 AS item_no
            ,tl.description AS descripcion
            ,b.enabled_flag
            ,b.invoice_enabled_flag       AS factura_activada
            ,b.inventory_item_status_code AS codigo_estado
            ,b.tax_code                   AS codigo_impuesto_sku
            ,case when b.tax_code is not null then 
                    (SELECT R.percentage_rate
                        FROM zx.zx_process_results pr
                             ,zx.zx_rules_b ru
                             ,zx.zx_condition_groups_b cg
                             ,zx.zx_rates_b r
                        WHERE cg.alphanumeric_value1 = b.tax_code--'IEPS 8% IVA 0%'--'IVA 16%'
                            AND ru.det_factor_templ_code = cg.condition_group_code
                            AND pr.condition_group_code = ru.det_factor_templ_code
                            AND pr.tax_rule_id = ru.tax_rule_id
                            AND ru.enabled_flag = 'Y'
                            AND pr.tax_status_code IS NOT NULL
                            AND R.tax_rate_code = alphanumeric_result
                            AND ru.tax ='IVA MEXICO') 
                    else null
                    end as percentage_rate_iva_sku
            ,case when b.tax_code is not null then 
                    (SELECT R.percentage_rate
                        FROM zx.zx_process_results pr
                             ,zx.zx_rules_b ru
                             ,zx.zx_condition_groups_b cg
                             ,zx.zx_rates_b r
                        WHERE cg.alphanumeric_value1 = b.tax_code--'IEPS 8% IVA 0%'--'IVA 16%'
                            AND ru.det_factor_templ_code = cg.condition_group_code
                            AND pr.condition_group_code = ru.det_factor_templ_code
                            AND pr.tax_rule_id = ru.tax_rule_id
                            AND ru.enabled_flag = 'Y'
                            AND pr.tax_status_code IS NOT NULL
                            AND R.tax_rate_code = alphanumeric_result
                            AND ru.tax ='IEPS') 
                    else 0
                    end as percentage_rate_ieps_sku
            ,estimulo.tiene_estimulo
            ,case when ieps.segment1 is not null then 'SI'
                else 'NO'
            end as tiene_mapeo_ieps
            ,ieps.ieps
            ,ieps.ieps_litro
            ,ieps.ieps_ed
            ,ieps.ieps_litro_ed   
        FROM 
            apps.oe_system_parameters_all osp
            ,apps.hr_operating_units ou
            ,apps.xle_entity_profiles le
            ,apps.mtl_parameters iop
            ,apps.hr_all_organization_units haou
            ,apps.mtl_system_items_b b
            ,apps.mtl_system_items_tl tl
            ,(SELECT to_NUMBER(REGEXP_SUBSTR (flv.lookup_code,'[^-]+',1,1)) org_id, REGEXP_SUBSTR (flv.lookup_code,'[^-]+',1,2) item_no 
                    ,'SI' tiene_estimulo
                FROM apps.fnd_lookup_types flt, apps.fnd_lookup_values flv
                WHERE     1 = 1
                    AND flt.lookup_type = flv.lookup_type
                    AND TO_NUMBER (REGEXP_SUBSTR (flv.lookup_code,'[^-]+',1,1)) = 84
        --                       AND REGEXP_SUBSTR (flv.lookup_code,'[^-]+',1,2) = p_sku                       
                    AND flv.enabled_flag = 'Y'
                    AND flv.language = 'ESA'                       
                    AND SYSDATE BETWEEN start_date_active AND NVL (end_date_active, SYSDATE + 1)
                    AND flt.lookup_type = 'CUST_ART_ESTIMULO_FISCAL'
                    GROUP BY to_NUMBER(REGEXP_SUBSTR (flv.lookup_code,'[^-]+',1,1)), REGEXP_SUBSTR (flv.lookup_code,'[^-]+',1,2)) estimulo
            ,apps.xxar_ieps ieps
        where 1=1
        --and ou.organization_id= 84
        /*and b.segment1 in ('3730','4267',
                            '4270',
                            '8260',
                            '8575',
                            '3137'
                            ,'3299')*/
        and b.segment1 = ieps.segment1(+)
        and ou.organization_id = ieps.org_id(+)
        --and ou.organization_id IN (84)--,180)
        and osp.org_id = ou.organization_id
        and ou.default_legal_context_id = le.legal_entity_id
        and osp.master_organization_id = iop.organization_id
        and iop.organization_id = haou.organization_id
        and b.organization_id = osp.master_organization_id
        and b.item_type = 'PT'
        and tl.inventory_item_id = b.inventory_item_id
        and tl.organization_id = b.organization_id
        and tl.language = 'ESA'
        --and b.tax_code is not null
        --and b.tax_code <> 'IVA 0%'
        --and b.inventory_item_status_code !='Inactive'
        and b.segment1 = estimulo.item_no(+)
        and ou.organization_id = estimulo.org_id(+)
) sq
;

/* Estos se ejecutan en APPS
begin
GRANT SELECT ON ZX_TAXES_B TO xxbot,xxwebc;
GRANT SELECT ON zx_taxes_tl TO xxbot,xxwebc;
GRANT SELECT ON zx_rates_b TO xxbot,xxwebc;
GRANT SELECT ON zx_rates_tl TO xxbot,xxwebc;
GRANT SELECT ON xxar_cuenta_impuesto_v TO xxbot,xxwebc;
GRANT SELECT ON apps.zx_process_results TO xxbot,xxwebc;
GRANT SELECT ON apps.zx_rules_b TO xxbot,xxwebc;
GRANT SELECT ON apps.zx_condition_groups_b TO xxbot,xxwebc;
end;
/
*/

