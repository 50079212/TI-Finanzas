create or replace package        xxar_fluctuacion_pkg
as
    procedure ejecuta_fluctuacion(pin_no_error in out number, pin_msj_error in out varchar2, pin_period_name varchar2,pin_modo_ejecucion varchar2, pin_user_apex varchar2);
    
    function get_status_periodo_ar(pin_period_name varchar2) return varchar2;
    
    function get_status_periodo_fluct(pin_period_name varchar2) return varchar2;
    
    function get_last_period_name return varchar2;
    
    FUNCTION get_user_id_ebs (pin_no_empleado varchar2) return number;
    
    procedure ejecuta_fluctuacion_db(pin_no_error in out number, pin_msj_error in out varchar2, pin_period_name varchar2,pin_modo_ejecucion varchar2, pin_user_id number);
    
end xxar_fluctuacion_pkg;