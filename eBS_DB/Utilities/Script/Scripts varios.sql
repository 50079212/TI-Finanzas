


DECLARE 
    V_SQL VARCHAR2(4000);
    V_ID NUMBER := 1;
    
BEGIN
    V_SQL:='select *
            from SI2EBS.XXAP_FISCAL_GL_FILES_DATA_TT';
    

    UPDATE SI2EBS.XXGEPP_SAVE_LONG_FILES_CONFIG_TBL
    SET QUERY_TEXT = V_SQL
    WHERE 1=1
    AND CONFIG_ID = V_ID;
    COMMIT;

    --V_SQL := REPLACE(V_SQL,'PARAM1',V_PARAM1);
    --V_SQL := REPLACE(V_SQL,'PARAM2',V_PARAM2);

    DBMS_OUTPUT.PUT_LINE(V_SQL);

END;
/


-- Inserta query para ejecución
insert into SI2EBS.XXGEPP_SAVE_LONG_FILES_CONFIG_TBL
(MODULE
,submodule
,query_number
,query_version 
,query_text
,CRAETION_DATE)
values('AP','FISCAL_APEX',1,2,'DW',SYSDATE);

COMMIT;

DELETE SI2EBS.XXAP_FISCAL_GL_FILES_TBL b;

DELETE SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL ctrl

DELETE SI2EBS.XXGEPP_SAVE_LONG_FILES_TBL F;

COMMIT;


SELECT *
FROM SI2EBS.XXGEPP_SAVE_LONG_FILES_CONFIG_TBL;

SELECT *-- ctrl_id, to_char(creation_date,'hh24_mi:ss'),to_char(last_updated_date,'hh24_mi:ss') 
FROM SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL;

select periodo,cia,file_id, nombre_archivo
from SI2EBS.XXAP_FISCAL_GL_FILES_V;

BEGIN XXGEPP_APEX_UTILITIES.LOAD_FILE('50079212'
                                                                ,123
                                                                ,8
                                                                ,1
                                                                ,'FEB-26_20260318174324.xlsx'
                                                                ,'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                                                                ,FALSE
                                                                ,130
                                                                ,'''FEB-26'''
                                                                ,'''209'''
                                                                ,''''''
                                                                ,''''''
                                                                ,''''''
                                                                ,'BEGIN SI2EBS.XXGEPP_AP_FISCAL.POPULATE_TABLE(''FEB-26'',''209''); END;'
                                                                ); END;
/
select *
from 
--UPDATE 
SI2EBS.XXAP_FISCAL_GL_FILES_TBL b
--SET CONTROL_ID =83
where 1=1
--and period_name ='DIC-25'
;
COMMIT;

SELECT *
FROM SI2EBS.XXAP_FISCAL_GL_FILES_V
WHERE 1=1
AND CIA = :P8_CIA_DL
AND PERIOD_YEAR = :P8_YEAR;


select *
            from SI2EBS.XXAP_FISCAL_GL_FILES_DATA_TT;


update  SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL
set status='EJECUCION'
    ,PHASE='NORMAL'
    , MESSAGE =NULL
    ,QUERY=NULL;


DECLARE
    V_OUT_CODE NUMBER;
    V_OUT_MESSAGE VARCHAR2(4000);
    V_CONTROL_ID NUMBER;
BEGIN

    XXGEPP_APEX_UTILITIES.SAVE_LONG_FILES('50079212'
                            ,123
                            ,6
                            ,'AP'
                            ,'FISCAL_APEX'
                            ,1--P_QUERY_NUMBER NUMBER
                            ,2--P_QUERY_VERSION NUMBER
                            ,'ENE-26.xlsx'---P_FILE_NAME VARCHAR2
                            ,'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' --VARCHAR2
                            ,FALSE --P_CREATE_ZIP BOOLEAN
                            ,'ENE-26'
                            ,'209'
                            ,NULL
                            ,NULL
                            ,NULL
                            ,V_OUT_CODE
                            ,V_OUT_MESSAGE
                            ,V_CONTROL_ID
                            );
DBMS_OUTPUT.PUT_LINE('V_OUT_CODE:'||V_OUT_CODE);
DBMS_OUTPUT.PUT_LINE('V_OUT_MESSAGE:'||V_OUT_MESSAGE);
DBMS_OUTPUT.PUT_LINE('V_CONTROL_ID:'||V_CONTROL_ID);

END;
/

DECLARE
    V_OUT_CODE NUMBER;
    V_OUT_MESSAGE VARCHAR2(4000);
    V_CONTROL_ID NUMBER;
BEGIN

        SI2EBS.XXGEPP_AP_FISCAL.CREATE_DATA_GL_AP('50079212'
                                    ,123
                                    ,6
                                    ,'ENE-26'
                                    ,'209'                          
                                    ,V_OUT_CODE
                                    ,V_OUT_MESSAGE
                                    );

        DBMS_OUTPUT.PUT_LINE('V_OUT_CODE:'||V_OUT_CODE);
        DBMS_OUTPUT.PUT_LINE('V_OUT_MESSAGE:'||V_OUT_MESSAGE);
END;
/

SELECT B.CIA, B.PERIOD_NAME AS PERIODO
    , B.LAST_UPDATE_DATE AS ACTUALIZADO_EL
    , B.LAST_UPDATED_BY AS ACTUALIZADO_POR
    , CASE WHEN B.ALLOW_REGENERATION = 0 THEN 'SI' ELSE 'NO' END AS SE_PUEDE_RECREAR
   ,CTRL.STATUS AS ESTATUS
   ,CTRL.PHASE AS FASE
   ,F.FILE_NAME
   ,F.MIME_TYPE
   ,F.FILE_CONTENT
   ,P.PERIOD_YEAR
   ,P.PERIOD_NUM
FROM SI2EBS.XXAP_FISCAL_GL_FILES_TBL b
    ,SI2EBS.XXGEPP_GL_PERIOD_STATUSES p
    ,SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL ctrl
    ,SI2EBS.XXGEPP_SAVE_LONG_FILES_TBL F
WHERE 1=1
AND P.PERIOD_NAME = b.period_name
AND p.APPLICATION_ID = 200
and P.CLOSING_STATUS = 'C'
AND CTRL.CTRL_ID (+) = b.CONTROL_ID
AND F.FILE_ID (+) = CTRL.FILE_ID
ORDER BY P.PERIOD_YEAR
   ,P.PERIOD_NUM;



select *
from ALL_OBJECTS
where 1=1
and object_name like '%PERIO%';




SELECT PERIOD_NAME
FROM SI2EBS.XXGEPP_GL_PERIOD_STATUSES
WHERE APPLICATION_ID = 200
AND PERIOD_NAME NOT LIKE 'AJU%'
AND CLOSING_STATUS = 'C'
ORDER BY PERIOD_YEAR DESC, PERIOD_NUM DESC;

select *
from si2ebs.XXAP_FISCAL_GL_FILES_V


;

SELECT FILE_CONTENT,
         FILE_NAME,
         mime_type
    FROM SI2EBS.XXAP_FISCAL_GL_FILES_V
   WHERE PERIODO = 'ENE-26';

   SELECT contenido,
        nombre_archivo,
         mime_type,
         
    
    FROM xxrep_excel
   WHERE id = 20260310221951;


    select /*+index(a CUST_AP_SLA2_POLIZAS_IDX1)*/  distinct a.categoria
   FROM
    SLA2EBS.cust_ap_sla2_polizas a
WHERE 1=1
    --AND ROWNUM <=20
    AND a.periodo  = 'FEB-26'
    AND a.segment1 = '209'   
    AND a.categoria IN ('Facturas Compra') 

    ;


    SELECT SID,sess.TYPE,sess.process, sess.status, sess.username, sess.schemaname, sql.sql_text
    FROM v$session sess,
        v$sql sql
  WHERE sql.sql_id(+) = sess.sql_id
      --AND sess.username= 'APEX_PUBLIC_USER'
      AND SCHEMANAME='XX_APEX'
      AND SID=1307
   ;


   