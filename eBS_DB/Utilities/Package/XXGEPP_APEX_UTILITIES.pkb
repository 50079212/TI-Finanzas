CREATE OR REPLACE PACKAGE BODY XX_APEX.XXGEPP_APEX_UTILITIES AS

    PROCEDURE  SAVE_LONG_FILES(P_USER VARCHAR2
                            ,P_APP_ID NUMBER
                            ,P_APP_PAGE NUMBER
                            ,P_MODULE VARCHAR2
                            ,P_SUBMODULE VARCHAR2
                            ,P_QUERY_NUMBER NUMBER
                            ,P_QUERY_VERSION NUMBER
                            ,P_FILE_NAME VARCHAR2
                            ,P_MIME_TYPE VARCHAR2
                            ,P_CREATE_ZIP BOOLEAN
                            ,P_PARAM1 VARCHAR2
                            ,P_PARAM2 VARCHAR2
                            ,P_PARAM3 VARCHAR2
                            ,P_PARAM4 VARCHAR2
                            ,P_PARAM5 VARCHAR2
                            ,P_SQL_EXECUTE VARCHAR2
                            ,p_OUT_CODE OUT NUMBER
                            ,P_OUT_MESSAGE OUT VARCHAR2
                            ,P_CONTROL_ID OUT NUMBER
                            )

    IS         

        V_CONFIG_ID NUMBER;
        V_TEXT_QUERY VARCHAR2(4000);
        EXCEPTION_ERR_MSJ EXCEPTION;

        V_OUT_CODE NUMBER;
        V_OUT_MESSAGE VARCHAR2(4000);

        V_CONTROL_ID NUMBER;
        V_PHASE VARCHAR2(20);
        V_WORKSPACE_ID apex_applications.workspace%TYPE;

        V_JOB_NAME VARCHAR2(100);

    BEGIN
        P_CONTROL_ID := 0;
        p_OUT_CODE := 0;
        P_OUT_MESSAGE := null;

        V_PHASE :='INICIO';
        BEGIN
            -- Get ConfigID
            SELECT CONFIG_ID,QUERY_TEXT
            INTO V_CONFIG_ID,V_TEXT_QUERY
            FROM SI2EBS.XXGEPP_SAVE_LONG_FILES_CONFIG_TBL
            WHERE 1=1
            AND MODULE =P_MODULE
            AND SUBMODULE=P_SUBMODULE
            AND QUERY_NUMBER=P_QUERY_NUMBER
            AND QUERY_VERSION=P_QUERY_VERSION;

            V_JOB_NAME := REPLACE(P_MODULE,' ','') || '_' || REPLACE(P_SUBMODULE,' ','');

        EXCEPTION 
            WHEN OTHERS THEN
                V_OUT_CODE := 666;
                V_OUT_MESSAGE := 'NO SE ENCONTRO LA CONFIGURACIÓN MODULO:' ||P_MODULE ||
                                'SUBMODULO:'||P_SUBMODULE ||
                                'QUERY_NUMBER:'||P_QUERY_NUMBER ||
                                'QUERY_VERSION:'||P_QUERY_VERSION;
             RAISE EXCEPTION_ERR_MSJ;
        END;

        DECLARE
            V_COUNT NUMBER;
        BEGIN   
            SELECT COUNT(*) 
            INTO V_COUNT
            FROM ALL_SCHEDULER_JOBS a
            WHERE a.job_name  = V_JOB_NAME;

            IF V_COUNT > 0 THEN
                V_OUT_CODE := 666;
                V_OUT_MESSAGE := 'EXISTE OTRO PROCESO EN EJECUCION (JOB: '|| V_JOB_NAME||'). INTENTE MAS TARDE.';
                RAISE EXCEPTION_ERR_MSJ;
            END IF;

        END;

        BEGIN   
            SELECT a.workspace 
            INTO v_workspace_id
            FROM apex_applications a
            WHERE a.application_id  = P_APP_ID;

        EXCEPTION 
            WHEN OTHERS THEN
                V_OUT_CODE := 666;
                V_OUT_MESSAGE := 'NO SE ENCONTRO EL WORKSPACE PARA EL APP_ID:' || P_APP_ID;
             RAISE EXCEPTION_ERR_MSJ;
        END;

        BEGIN   
            IF P_MIME_TYPE NOT IN ('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/csv') THEN            
                V_OUT_CODE := 666;
                V_OUT_MESSAGE := 'NO TRABAJA CON ESTE MIME_TYPE:' || P_MIME_TYPE;
                RAISE EXCEPTION_ERR_MSJ;
            END IF;
        END;


        SELECT SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_SEQ.NEXTVAL 
        INTO V_CONTROL_ID
        FROM DUAL;

        V_PHASE := 'NORMAL';

        -- Inserted row in control table
        INSERT INTO SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL
                (CTRL_ID
                ,FILE_ID
                ,CONFIG_ID 
                ,STATUS 
                ,PHASE 
                ,MESSAGE 
                ,CREATION_DATE  
                ,CREATED_BY 
                ,LAST_UPDATED_DATE)
        VALUES(
                V_CONTROL_ID
                ,NULL--FILE_ID
                ,V_CONFIG_ID 
                ,'EJECUCION'--STATUS 
                ,V_PHASE--phase 
                ,NULL--MESSAGE 
                ,SYSDATE--CREATION_DATE  
                ,P_USER --created_by 
                ,SYSDATE --LAST_UPDATED_DATE
                );
        COMMIT;

        P_CONTROL_ID := V_CONTROL_ID;

        -- Se ejecuta el JOB
        DECLARE
            v_param1 varchar2(100);
            v_param2 varchar2(100);
            v_param3 varchar2(100);
            v_param4 varchar2(100);
            v_param5 varchar2(100);
            v_sql_execute varchar2(100);
            v_script varchar2(4000);
            v_create_zip varchar2(10);
        BEGIN
            v_param1 := ''''''''||p_param1||'''''''';
            v_param2 := ''''''''||p_param2||'''''''';
            v_param3 := ''''''''||p_param3||'''''''';
            v_param4 := ''''''''||p_param4||'''''''';
            v_param5 := ''''''''||p_param5||'''''''';

            v_sql_execute:= P_SQL_EXECUTE;

            if P_CREATE_ZIP then
                v_create_zip :='TRUE';
            ELSE
                v_create_zip :='FALSE';
            END IF;

            v_script := 'BEGIN XXGEPP_APEX_UTILITIES.LOAD_FILE('''||P_USER||'''
                                                                ,'||P_APP_ID||'
                                                                ,'||P_APP_PAGE||'
                                                                ,'||V_CONFIG_ID||'
                                                                ,'''||P_FILE_NAME||'''
                                                                ,'''||P_MIME_TYPE||'''
                                                                ,'||v_create_zip||'
                                                                ,'||V_CONTROL_ID||'
                                                                ,'||v_param1 ||'
                                                                ,'||v_param2 ||'
                                                                ,'||v_param3 ||'
                                                                ,'||v_param4 ||'
                                                                ,'||v_param5 ||'
                                                                ,'''||v_sql_execute||'''
                                                                ); END;';

            UPDATE SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL
                SET LAST_UPDATED_DATE = SYSDATE
                    ,MESSAGE = v_script
                WHERE 1=1
                AND CTRL_ID=V_CONTROL_ID;
            commit;

            DBMS_SCHEDULER.CREATE_JOB (
                job_name        => V_JOB_NAME,
                job_type        => 'PLSQL_BLOCK',
                job_action      => v_script,
                start_date => sysdate, 
                enabled => TRUE, 
                auto_drop => TRUE, --una vez ejecutado se auto eliminará :(
                comments => 'este job correra solo una vez '
            );
        END;
        V_OUT_CODE :=0;
        V_OUT_MESSAGE :=null;

        P_OUT_CODE := V_OUT_CODE;
        P_OUT_MESSAGE:=V_OUT_MESSAGE;

    EXCEPTION
        WHEN EXCEPTION_ERR_MSJ THEN
            P_OUT_CODE := V_OUT_CODE;
            P_OUT_MESSAGE:=V_OUT_MESSAGE;
        WHEN OTHERS THEN
            V_OUT_CODE := 666;
            V_OUT_MESSAGE:=SQLCODE || '-->' ||  SUBSTR(SQLERRM, 1, 200);

            IF V_PHASE !='INICIO' THEN
                UPDATE SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL
                SET LAST_UPDATED_DATE = SYSDATE
                    ,STATUS ='ERROR'
                    ,PHASE = V_PHASE
                    --,MESSAGE = V_OUT_MESSAGE
                WHERE 1=1
                AND CTRL_ID=V_CONTROL_ID;

                COMMIT;
            END IF;            

            P_OUT_CODE := V_OUT_CODE;
            P_OUT_MESSAGE:=V_OUT_MESSAGE;
    END SAVE_LONG_FILES;

    PROCEDURE LOAD_FILE(P_USER VARCHAR2
                        ,P_APP_ID NUMBER
                        ,P_APP_PAGE NUMBER
                        ,P_CONFIG_ID NUMBER
                        ,P_FILE_NAME VARCHAR2
                        ,P_MIME_TYPE VARCHAR2
                        ,P_CREATE_ZIP BOOLEAN
                        ,P_CONTROL_ID NUMBER
                        ,P_PARAM1 VARCHAR2
                        ,P_PARAM2 VARCHAR2
                        ,P_PARAM3 VARCHAR2
                        ,P_PARAM4 VARCHAR2
                        ,P_PARAM5 VARCHAR2
                        ,P_SQL_EXECUTE VARCHAR2
                        )
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        V_OUT_CODE NUMBER;
        V_OUT_MESSAGE VARCHAR2(4000);

        V_WORKSPACE_ID VARCHAR2(100);
        V_CONTROL_ID NUMBER;
        V_PHASE VARCHAR2(30);
        V_FILE_ID NUMBER;

        l_context   apex_exec.t_context;
        l_export    apex_data_export.t_export;

        V_TEXT_QUERY VARCHAR2(4000);

        L_ZIP BLOB;
        V_FILE_NAME VARCHAR2(50);
        V_MIME_TYPE VARCHAR2(80);
    BEGIN
        V_PHASE := 'CARGANDO STEP 1';  
        V_CONTROL_ID :=  P_CONTROL_ID;

        UPDATE SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL
        SET LAST_UPDATED_DATE = SYSDATE
            ,PHASE = V_PHASE
        WHERE 1=1
        AND CTRL_ID=V_CONTROL_ID;
        COMMIT;

        IF LENGTH(P_SQL_EXECUTE)>10 THEN
            V_PHASE := 'CARGANDO STEP - EXECUTE PLSQL'; 

            UPDATE SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL
            SET LAST_UPDATED_DATE = SYSDATE
                ,PHASE = V_PHASE
                ,query = 'plsq '|| P_SQL_EXECUTE
            WHERE 1=1
            AND CTRL_ID=V_CONTROL_ID;
            COMMIT;

            EXECUTE IMMEDIATE P_SQL_EXECUTE;
        END IF;

        V_PHASE := 'CARGANDO STEP 1.5 - TEXT QUERY'; 

        SELECT QUERY_TEXT
        INTO V_TEXT_QUERY
        FROM SI2EBS.XXGEPP_SAVE_LONG_FILES_CONFIG_TBL
        WHERE CONFIG_ID = P_CONFIG_ID;

        IF P_PARAM1 IS NOT NULL THEN
            V_TEXT_QUERY := REPLACE(V_TEXT_QUERY,'PARAM1',P_PARAM1);
        END IF;

        IF P_PARAM2 IS NOT NULL THEN
            V_TEXT_QUERY := REPLACE(V_TEXT_QUERY,'PARAM2',P_PARAM2);
        END IF;

        IF P_PARAM3 IS NOT NULL THEN
            V_TEXT_QUERY := REPLACE(V_TEXT_QUERY,'PARAM3',P_PARAM3);
        END IF;

        IF P_PARAM4 IS NOT NULL THEN
            V_TEXT_QUERY := REPLACE(V_TEXT_QUERY,'PARAM4',P_PARAM4);
        END IF;

        IF P_PARAM5 IS NOT NULL THEN
            V_TEXT_QUERY := REPLACE(V_TEXT_QUERY,'PARAM5',P_PARAM5);
        END IF;

        APEX_UTIL.SET_WORKSPACE (
                                    p_workspace         => v_workspace_id
                                );

        UPDATE SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL
        SET LAST_UPDATED_DATE = SYSDATE
            ,PHASE = V_PHASE
            ,query = V_TEXT_QUERY
        WHERE 1=1
        AND CTRL_ID=V_CONTROL_ID;
        COMMIT;

        V_PHASE := 'CARGANDO STEP 2';
        APEX_UTIL.SET_SECURITY_GROUP_ID (
                                            p_security_group_id => APEX_UTIL.FIND_SECURITY_GROUP_ID(p_workspace => v_workspace_id)
                                        );



        V_PHASE := 'CARGANDO STEP 3';
	    APEX_UTIL.SET_USERNAME (
                                p_userid            => APEX_UTIL.GET_USER_ID(P_USER),
                                p_username          => P_USER
                                );



        V_PHASE := 'CARGANDO STEP 4';
	    APEX_SESSION.CREATE_SESSION
                                    (
                                        P_APP_ID => P_APP_ID,
                                        P_PAGE_ID => P_APP_PAGE,
                                        P_USERNAME => P_USER -- THIS PARAMETER IS MANDATORY BUT CAN BE ANY STRING APPARENTLY
                                    );



        V_PHASE := 'CARGANDO STEP 5';
        -- Create query context
        l_context := apex_exec.open_query_context(
                                                    p_location => apex_exec.c_location_local_db,
                                                    p_sql_query => V_TEXT_QUERY);



        V_PHASE := 'CARGANDO STEP 6';  
        UPDATE SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL
        SET LAST_UPDATED_DATE = SYSDATE
            ,PHASE = V_PHASE
        WHERE 1=1
        AND CTRL_ID=V_CONTROL_ID;
        COMMIT;

        -- Export data
        IF P_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' THEN
            l_export := apex_data_export.export(
                                                    p_context => l_context,
                                                    p_format  => apex_data_export.c_format_xlsx --c_format_csv--                                            
                                                );
        ELSIF P_MIME_TYPE ='text/csv' THEN
            l_export := apex_data_export.export(
                                                    p_context => l_context,
                                                    p_format  => apex_data_export.c_format_csv--                                            
                                                );
        END IF;


        V_PHASE := 'CARGANDO STEP 7';
        -- Close context
        apex_exec.close(l_context);



        V_PHASE := 'CARGANDO STEP 8 LF';

        UPDATE SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL
        SET LAST_UPDATED_DATE = SYSDATE
            ,PHASE = V_PHASE
        WHERE 1=1
        AND CTRL_ID=V_CONTROL_ID;
        COMMIT;

        select SI2EBS.XXGEPP_SAVE_LONG_FILES_SEQ.NEXTVAL
        into V_FILE_ID
        from dual;

        IF P_CREATE_ZIP THEN
            V_FILE_NAME := substr(P_FILE_NAME,1,instr(P_FILE_NAME,'.')-1);
            V_MIME_TYPE := 'application/zip';

            dbms_lob.createtemporary(L_ZIP, true);

            /*apex_zip.add_file(
                p_zipped_blob => L_ZIP,
                p_file_name   => P_FILE_NAME,
                p_content     => l_export.content_blob ,
                p_charset     => 'AL32UTF8'
            );*/

            apex_zip.finish(L_ZIP);

            -- Insert File in table
            INSERT INTO SI2EBS.XXGEPP_SAVE_LONG_FILES_TBL
                (FILE_ID
                ,FILE_NAME
                ,MIME_TYPE
                ,FILE_CONTENT
                ,CREATION_DATE)
            VALUES(
                V_FILE_ID
                ,V_FILE_NAME
                ,V_MIME_TYPE
                ,L_ZIP  
                ,SYSDATE
            );

            COMMIT;
        ELSE
            V_FILE_NAME := P_FILE_NAME;
            V_MIME_TYPE := P_MIME_TYPE;

            -- Insert File in table
            INSERT INTO SI2EBS.XXGEPP_SAVE_LONG_FILES_TBL
                (FILE_ID
                ,FILE_NAME
                ,MIME_TYPE
                ,FILE_CONTENT
                ,CREATION_DATE)
            VALUES(
                V_FILE_ID
                ,V_FILE_NAME
                ,V_MIME_TYPE
                ,l_export.content_blob
                ,SYSDATE
            );

            COMMIT;
        END IF;




        V_PHASE := 'CORRECTO';

        UPDATE SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL
        SET LAST_UPDATED_DATE = SYSDATE
            ,STATUS ='TERMINADO'
            ,PHASE = V_PHASE
            ,FILE_ID = V_FILE_ID
        WHERE 1=1
        AND CTRL_ID=V_CONTROL_ID;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            V_OUT_CODE := 666;
            V_OUT_MESSAGE:=SQLCODE || '-->' ||  SUBSTR(SQLERRM, 1, 200);


                UPDATE SI2EBS.XXGEPP_SAVE_LONG_FILES_CTRL_TBL
                SET LAST_UPDATED_DATE = SYSDATE
                    ,STATUS ='ERROR'
                    ,PHASE = V_PHASE
                    ,MESSAGE = V_OUT_MESSAGE

                WHERE 1=1
                AND CTRL_ID=V_CONTROL_ID;

                COMMIT;            
    END LOAD_FILE;

 END XXGEPP_APEX_UTILITIES;