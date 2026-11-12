-- json type convertible

BEGIN
    
     DBMS_JSON.json_type_convertible_check(
                   owner => 'SI2EBS',
                   tableName => 'XXGEPP_AR_FE_PAC_TBL',
                   columnName => 'TRX_DOCUMENT',
                   statusTableName => 'precheck_json');

END;
/

select *
from precheck_json
order by stamp desc
;


    --  SELECT TRX_ID,
    -- TRX_ID_OUT,
    -- CUSTOMER_TRX_ID,
    -- TRX_NUMBER,
    -- TRX_PERIODO,
    -- TRX_TYPE_LINE,
    -- TRX_STATUS,
    -- TRX_DOCUMENT,
    -- TRX_TIMBRE,
    -- DATE_EFFECTIVE,
    -- CREATED_BY,
    -- CREATION_DATE,
    -- LAST_UPDATE_BY,
    -- LAST_UPDATE_DATE,
    -- TRX_TYPE,
    -- OPERATIVE_UNIT,
    -- NAME_TRASACTION_TYPE,
    -- CFDI_MON,
    -- CFDI_RESP,
    -- FECHA_DESMARCADO,
    -- USUARIO_DESMARCA,
    -- RA_TRX_DATE,
    -- GROUPING,
    -- ADDENDA FROM XXGEPP_AR_FE_PAC_TBL
    -- order by trx_id desc;