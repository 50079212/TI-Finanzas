
CREATE OR REPLACE PACKAGE XX_APEX.XXGEPP_APEX_UTILITIES AS

 PROCEDURE SAVE_LONG_FILES(P_USER VARCHAR2
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
                            );

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
                    );

 END XXGEPP_APEX_UTILITIES;

 /

 GRANT EXECUTE ON XXGEPP_APEX_UTILITIES TO SI2EBS;