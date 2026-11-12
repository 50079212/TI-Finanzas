create or replace function JWT return boolean
is
    v_x01      VARCHAR2(32767);
    l_jwt      APEX_JWT.T_TOKEN;
    l_jwt_user VARCHAR2(4000);
    v_resp VARCHAR2(4000);
    v_code VARCHAR2(100);
     v_msj VARCHAR2(4000);
     v_token VARCHAR2(4000);

     v_auth_header  VARCHAR2(4000);
     V_ID NUMBER;
begin
    if apex_application.g_user is not null then
        return true;
    end if;

    V_ID := to_number(to_char(sysdate,'YYYYMMDDHH24MISS'));

    insert into xx_jwt_log (id, text, fecha) 
    values (V_ID, 'inicio usu:' ||apex_application.g_user, sysdate);
    commit;

    -- get the token from the url
    v_x01 := v('APP_AJAX_X01');

    --v_auth_header := owa_util.get_cgi_env('Authorization');

    --insert into xx_jwt_log (id, text, fecha) 
    --values (1, 'v_auth_header:'||v_auth_header, sysdate);
    --commit;

    --apex_util.set_session_state('PIN_HEADER_VALUE', v_x01);

    insert into xx_jwt_log (id, text, fecha) 
    values (V_ID, 'v_x01:'||v_x01, sysdate);
    commit;

    v_resp := xxutilities_app_mobile.validate_token_jwt(v_x01);

    SELECT json_value(v_resp,'$."code"') as code
              ,json_value(v_resp,'$."msj"') as msj
              ,json_value(v_resp,'$."user_name"') as user_name              
              ,json_value(v_resp,'$."token"') as token
            into v_code, v_msj,l_jwt_user,v_token
        from dual;

    insert into xx_jwt_log (id, text, fecha) 
    values (V_ID, 'v_code:'||v_code, sysdate);
    commit;

    insert into xx_jwt_log (id, text, fecha) 
    values (V_ID, 'v_msj:'||v_msj, sysdate);

    insert into xx_jwt_log (id, text, fecha) 
    values (V_ID, 'v_token:'||v_token, sysdate);

    insert into xx_jwt_log (id, text, fecha) 
    values (V_ID, 'l_jwt_user:'||l_jwt_user, sysdate);


    commit;

    --if l_jwt_user is not null then

       --APEX_UTIL.SET_AUTHENTICATED_SESSION(p_username => l_jwt_user);
    --else
    --    return false;
    --end if;

    -- check if the token has the jwt format xxx.xxx.xxx
    /*if v_x01 like '%.%.%' then
        -- decode the token
        l_jwt := apex_jwt.decode (
                    p_value         => v_x01,
                    p_signature_key => sys.utl_raw.cast_to_raw('secretKey') );


        insert into xx_jwt_log (id, text, fecha) 
        values (1, 'paso por aqui', sysdate);
        commit;
        -- validate the token using the same issuer and audience values 
        -- used to encrypt the token
        apex_jwt.validate (
            p_token => l_jwt,
            p_iss   => 'XX_APEX',
            p_aud   => 'XXAPP_CLIENT_AR_ROL' );

        insert into xx_jwt_log (id, text, fecha) 
        values (1, 'paso por aqui 2', sysdate);
        commit;

        -- parse the payload 
        apex_json.parse (
            p_source => l_jwt.payload );
        -- get the username from the payload
        l_jwt_user := apex_json.get_varchar2('sub');
    end if;

    insert into xx_jwt_log (id, text, fecha) 
    values (1, 'l_jwt_user:'||l_jwt_user, sysdate);
    commit;

    -- if the user is not logged in
    if apex_authentication.is_public_user then
        -- if the token does not contain username
        if l_jwt_user is not null then
            apex_authentication.post_login (
                p_username => l_jwt_user );
        else
            return false;
        end if;

    -- if the logged in user != the username in the token
    elsif apex_application.g_user <> l_jwt_user then
        return false;
    end if;*/

    if v_code != '0' then
        return false;
    else
        insert into xx_jwt_log (id, text, fecha) 
        values (V_ID, 'entro a asignar usuario:'||l_jwt_user, sysdate);
        commit;

        apex_authentication.post_login ( p_username => l_jwt_user );

        insert into xx_jwt_log (id, text, fecha) 
        values (V_ID, 'paso de asignar usuario:'||l_jwt_user, sysdate);
        commit;

        insert into xx_jwt_log (id, text, fecha) 
        values (V_ID, 'paso de asignar usuario2:'||apex_application.g_user, sysdate);
        commit;


        return true;
    end if;

    --return true;

    exception when others then
        apex_debug.trace('---error---: %s', sqlerrm);

        insert into xx_jwt_log (id, text, fecha) 
        values (V_ID, 'otro error:', sysdate);
        commit;

end JWT;