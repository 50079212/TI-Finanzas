select count(lv.lookup_code)
-- into v_supplier_exception
from apps.fnd_lookup_values lv
where lv.lookup_type = 'CUST_AP_RECEP_EXCEP'
and lv.lookup_code = 'DRA950811S25' --v_rfc_emisor
      and lv.enabled_flag = 'Y'
      and trunc(sysdate) between nvl(lv.start_date_active,trunc(sysdate)
        ) and nvl(lv.end_date_active, trunc(sysdate)
);
