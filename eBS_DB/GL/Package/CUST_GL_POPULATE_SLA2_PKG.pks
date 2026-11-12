CREATE OR REPLACE PACKAGE APPS.CUST_GL_POPULATE_SLA2_PKG IS 

PROCEDURE MESSAGE_LOG (P_MESSAGE IN VARCHAR2);

PROCEDURE MESSAGE_OUTPUT (P_MESSAGE IN VARCHAR2); 

PROCEDURE MAIN_VALIDACIONES (ERRBUF             OUT VARCHAR2
                            ,RETCODE            OUT NUMBER
                            ,P_TIPO_EJECUCION   IN VARCHAR2
                            ,P_MODULO           IN VARCHAR2
                            ,P_EJECUCION        IN NUMBER
                            ,P_PERIODO          IN VARCHAR2 --GL_PERIODS.PERIOD_NAME%TYPE
                            ,P_CORREO           IN VARCHAR2); 
                            
PROCEDURE POPULATE_AR (P_PERIODO        IN  VARCHAR2 --GL_PERIODS.PERIOD_NAME%TYPE
                      ,P_EXECUTE_ID     IN  NUMBER
                      ,P_CUENTA         OUT NUMBER
                      ,P_ESTATUS        OUT VARCHAR2
                      ,P_ERROR          OUT BOOLEAN);
                      
PROCEDURE POPULATE_AP (P_PERIODO    IN  VARCHAR2
                                          ,P_EXECUTE_ID IN  NUMBER
                                          ,P_CUENTA     OUT NUMBER
                                          ,P_ESTATUS    OUT VARCHAR2
                                          ,P_ERROR      OUT BOOLEAN); --GL_PERIODS.PERIOD_NAME%TYPE);

PROCEDURE POPULATE_GL (P_PERIODO        IN VARCHAR2 --GL_PERIODS.PERIOD_NAME%TYPE);
                      ,P_EXECUTE_ID     IN  NUMBER
                      ,P_CUENTA         OUT NUMBER
                      ,P_ESTATUS        OUT VARCHAR2
                      ,P_ERROR          OUT BOOLEAN); 
                      
PROCEDURE POPULATE_BLANAZA (P_PERIODO        IN VARCHAR2 --GL_PERIODS.PERIOD_NAME%TYPE);
                                                   ,P_EXECUTE_ID     IN  NUMBER
                                                   ,P_CUENTA         OUT NUMBER
                                                   ,P_ESTATUS        OUT VARCHAR2
                                                   ,P_ERROR          OUT BOOLEAN) ;                      

PROCEDURE POLULATE_CATALOG_ACCOUNTS(ERRBUF             OUT VARCHAR2
                                   ,RETCODE            OUT NUMBER
                                   ,P_VERSION_ID       IN  NUMBER);

END CUST_GL_POPULATE_SLA2_PKG;