create or replace view XXWEBC.XXAR_PRECIOS_CTE_V1 as 
SELECT psku.*
     ,cic.cuenta customer_number
     ,cic.impuesto codigo_impuesto_customer
     ,(SELECT c.percentage_rate
        FROM apps.ZX_TAXES_B a
            ,apps.zx_taxes_tl x
            ,apps.zx_rates_b c
            ,apps.zx_rates_tl d
        where 1=1
        and a.tax_id = x.tax_id
        and x.source_lang = 'ESA'
        and a.tax = c.tax
        and c.tax_rate_id = d.tax_rate_id
        and d.source_lang = 'ESA'
        and c.tax_rate_code = cic.impuesto) factor_iva_customer
    ,case when factor_iva_obtenido_en != 'CLIENTE' then 
            factor_iva_sku
        else
            (SELECT c.percentage_rate
                FROM apps.ZX_TAXES_B a
                    ,apps.zx_taxes_tl x
                    ,apps.zx_rates_b c
                    ,apps.zx_rates_tl d
                where 1=1
                and a.tax_id = x.tax_id
                and x.source_lang = 'ESA'
                and a.tax = c.tax
                and c.tax_rate_id = d.tax_rate_id
                and d.source_lang = 'ESA'
                and c.tax_rate_code = cic.impuesto)
        end as factor_iva_final        
from xxar_precios_sku_v1 psku
    ,apps.xxar_cuenta_impuesto_v cic
where 1=1
--and psku.org_id = 84
AND psku.org_id = cic.org_id
 --and cic.cuenta='12657'
 --AND psku.ITEM_NO = '175'
--and psku.org_id = cic.org_id

;