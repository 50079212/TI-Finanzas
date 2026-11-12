CREATE OR REPLACE package CFDI_AP_AR.XXCASH_APEX_CASHLESS_PKG as

--	$Id: xxcash_apex_dashboard_utilities.pks 4316 2023-04-10 19:20:59Z vvelasco $
--	$URL: http://mxapediprdl.gepp.pvt:18080/svn/r12/Developer/CASH/SantaderCashless/xxcash_apex_dashboard_utilities.pks $    

    function imp_dw_sio_fnc  return varchar2;

    function imp_gl_fnc return varchar2;

    FUNCTION ConciliaSIOvsGL   RETURN VARCHAR2;
    
    FUNCTION conciliacionbancovssio RETURN VARCHAR2;
    
    FUNCTION revisa_gl_posted_fnc RETURN VARCHAR2;
        
    
end XXCASH_APEX_CASHLESS_PKG;