create or replace PACKAGE xxutilities_app_mobile
is
    vg_esquema varchar2(100):='XX_APEX';
    vg_perfil varchar2(100):='XXAPP_CLIENT_AR_ROL';
    vg_secretKey varchar2(4000):='secretKey';

function login_gepp(pin_user_name in varchar2) return clob;
function get_token_jwt(pin_user_name in varchar2) return clob;
procedure XXGEPP_TOKEN_JWT_PRC(pout_Code OUT number, pout_Msj OUT varchar2, pin_UserName in varchar2,pout_Token_JWT OUT varchar2, pin_datos clob);
function validate_token_jwt(pin_header_value varchar2) return CLOB;
end xxutilities_app_mobile;