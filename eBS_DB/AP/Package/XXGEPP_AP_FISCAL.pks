 CREATE OR REPLACE PACKAGE SI2EBS.XXGEPP_AP_FISCAL AS

 PROCEDURE CREATE_DATA_GL_AP(P_USER VARCHAR2
                            ,P_APP_ID NUMBER
                            ,P_APP_PAGE NUMBER
                            ,P_PERIOD_NAME VARCHAR2  
                            ,P_CIA VARCHAR2                          
                            ,P_OUT_CODE OUT NUMBER
                            ,P_OUT_MESSAGE OUT VARCHAR2
                            );

 PROCEDURE POPULATE_TABLE(P_PERIOD_NAME VARCHAR2  
                         ,P_CIA VARCHAR2);

 END XXGEPP_AP_FISCAL;
 /
 GRANT EXECUTE ON XXGEPP_AP_FISCAL TO XX_APEX;