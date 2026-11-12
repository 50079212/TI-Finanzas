create or replace PACKAGE body xxutilities_app_mobile
is
function login_gepp(pin_user_name in varchar2) return clob
is
    
    v_resp clob;
    v_code number;
    v_msj varchar2(300);

    v_user_type varchar2(1000); -- CUSTOMER SUPPLIER USER_GEPP
    v_user_num varchar2(1000);
    v_user_id number;
    --v_user_gepp varchar2(100);
    v_user_description VARCHAR2(1000);

    v_exist_user varchar2(1000);
BEGIN
    v_code := 0;
    v_msj := 'success';
    v_user_type := 'NO CLASIFICADO';

    /*select *
from APEX_WORKSPACE_GROUP_USERS
where 1=1
and user_name = '50079212';*/
    -- Validamos si es un usuario valido para la APP
    BEGIN
        SELECT user_name
        INTO v_exist_user
        from APEX_WORKSPACE_APEX_USERS
        where 1=1
        and user_name = pin_user_name;

    EXCEPTION
    WHEN OTHERS THEN    
        v_user_num := NULL;
        v_user_id := NULL;
        v_msj := 'Usuario '|| pin_user_name || ' No Valido';
        v_code := 1;
    END;

    -- Validamos si es un usuario valido para la APP
    BEGIN
        select user_name
        INTO v_exist_user
        from APEX_WORKSPACE_GROUP_USERS
        where 1=1
        and user_name = pin_user_name
        and group_name = vg_perfil;        

    EXCEPTION
    WHEN OTHERS THEN    
        v_user_num := NULL;
        v_user_id := NULL;
        v_msj := 'Usuario '|| pin_user_name || ' No valido - No cuenta con el perfil';
        v_code := 1;
    END;

    IF v_code = 0 THEN
        BEGIN
            -- Valida si esta sincronizada su información con el catálogo de clientes

                select USER_TYPE,ACCOUNT_NUMBER,ACCOUNT_ID
                into v_user_type, v_user_num , v_user_id        
                from XXAPEX_WORKSPACE_APEX_USERS
                where 1=1
                and user_name = pin_user_name;

                select customer_name, customer_number--, tax_reference
                INTO v_user_description, v_user_num
                from apps.RA_CUSTOMERS@ORA19_TO_EBSPROD.SUBNETPRODUCCIO.VCNDATABASESTIE.ORACLEVCN.COM
                where 1=1
                and customer_id = v_user_id
                and tax_reference = pin_user_name;

                v_user_type := 'CUSTOMER';
        exception
        when others THEN
            v_code := 0;
            v_user_num := NULL;
            v_user_id := NULL;
            v_msj := 'Usuario Valido pero no esta clasificado como cliente';
        end;
    END IF;

    if v_user_type = 'NO CLASIFICADO' then
        begin
            select USER_NAME, 'USER_EBS', DESCRIPTION, user_id
            into v_user_num, v_user_type, v_user_description, v_user_id
            from fnd_user@ORA19_TO_EBSPROD.SUBNETPRODUCCIO.VCNDATABASESTIE.ORACLEVCN.COM
            where FAX = pin_user_name;
        EXCEPTION
            WHEN OTHERS THEN   
                NULL;
        end;
    end if;

    SELECT JSON_OBJECT('code' value v_code
                   ,'msj' value v_msj
                   --,'user_name' value pin_user_name
                   ,'user_type' value v_user_type
                   ,'user_num' value v_user_num
                   ,'user_id' value v_user_id 
                   ,'user_description' value v_user_description
                   --,'user_gepp' value v_user_gepp
                   )
    into v_resp
    FROM DUAL;

    --v_resp := v_text;
    --v_resp := replace(v_resp, '\"', '"');
    --v_resp := replace(v_resp, '\n', chr(10));

    return v_resp;
end login_gepp;

function get_token_jwt(pin_user_name in varchar2) return clob
is
    pout_Code       number;

    pin_UserName    varchar2(50);
    pout_Token_JWT  varchar2(4000);
    v_text  CLOB;

    v_code number;
    v_msj varchar2(4000);
    pout_Msj        varchar2(4000);

    v_user_type varchar2(50);
    v_user_num varchar2(50);
    v_user_id number;
    v_user_description varchar2(200);
    v_user_gepp varchar2(100);

    v_result CLOB;

    v_perfil VARCHAR2(100):='Admins';--p_aud

begin
    -- current_user es una variable de entorno que guarda el usuario que se loguea
    pin_UserName := pin_user_name;

    /*
    select XX_APEX.xxutilities_app_mobile.login_gepp(pin_UserName) as respuesta
    into v_text
    from dual;


        SELECT json_value(v_text,'$."code"') as code
              ,json_value(v_text,'$."msj"') as msj
              --,json_value(v_text,'$."user_type"') as msj
              --,json_value(v_text,'$."user_num"') as msj
              --,json_value(v_text,'$."user_id"') as msj
              --,json_value(v_text,'$."user_description"') as msj
              --,json_value(v_text,'$."user_gepp"') as msj
        into v_code, v_msj
            --,v_user_type
            --,v_user_num
            --,v_user_id
            --,v_user_description
           -- ,v_user_gepp
        FROM  dual;
    */
    v_code := 0;
    IF v_code = 0 THEN

        --v_text := replace(v_text, '\', '"');

        xxutilities_app_mobile.XXGEPP_TOKEN_JWT_PRC(v_code
                                                    , pout_Msj
                                                    , pin_UserName
                                                    ,pout_Token_JWT                                                    
                                                    ,v_text);

        v_msj := v_msj || '|' || pout_Msj;



    END IF;

        SELECT json_object('code' value v_code
                    ,'msj' value v_msj
                    --,'user_type' value v_user_type
                    --,'user_num' value v_user_num
                    --,'user_id' value v_user_id
                    --,'user_description' value v_user_description
                    --,'user_gepp' value v_user_gepp                    
                    ,'profiles' value json_arrayagg(json_object(key 'profile' value g.group_name))
                    ,'token' value pout_Token_JWT)
             INTO v_result
            FROM DUAL d
                ,APEX_WORKSPACE_GROUP_USERS g 
            where 1=1
            and g.user_name = pin_UserName
            and substr(g.group_name,1,5) = 'XXAPP';

    return v_result;

end get_token_jwt;

procedure XXGEPP_TOKEN_JWT_PRC(pout_Code OUT number, pout_Msj OUT varchar2, pin_UserName in varchar2,pout_Token_JWT OUT varchar2, pin_datos clob)
as
    l_token           VARCHAR2 (4000);

    v_UserName VARCHAR2(100):=pin_UserName;

    v_esquema VARCHAR2(100) :=vg_esquema; -- Esquema donde vive el proceso
    v_perfil VARCHAR2(100):= vg_perfil;--'XXGEPP_APP_ROLE';-- Perfil para poder ocupar estos servicios
    v_time_exp_token number :=20*60; -- Tiempo para que expire el token en segundos
    v_secretKey varchar2(1000) := vg_secretKey;-- Frase secreta para encriptar y desencriptar 
BEGIN    


    /***
    use the apex_jwt package to generate the jwt token
    @param p_iss the issuer of the token
    @param p_sub the "sub" (subject) claim identifies the principal that is the
           subject of the JWT
    @param p_aud the "aud" (audience) claim identifies the recipients 
           that the JWT is intended for
    @param p_iat_ts the "iat" (issued at) claim identifies the time at 
           which the JWT was issued
    @param p_exp_sec token expiration in seconds
    @param p_signature_key signature key used to encrypt the token
    ***/

    l_token :=
        apex_jwt.encode (
            p_iss       => v_esquema,--'ORDS',
            p_sub       => v_UserName,
            p_aud       => v_perfil,--'Admins',--l_user_role,
            p_iat_ts    => CURRENT_TIMESTAMP, -- Se deja esta variable ya que sino el server de Ords no lo toma correcto
            p_exp_sec   => v_time_exp_token,--60 * 5,
            p_other_claims   =>
                   '"user_id": '
                || apex_json.stringify (json_value(pin_datos,'$."user_id"'))
                || ',"user_num": '
                || apex_json.stringify (json_value(pin_datos,'$."user_num"'))
                || ',"user_type": '
                || apex_json.stringify (json_value(pin_datos,'$."user_type"'))
                || ',"user_description": '
                || apex_json.stringify (json_value(pin_datos,'$."user_description"'))                
                ,
            p_signature_key   =>
                sys.UTL_RAW.cast_to_raw (
                    --'secretKey'
                    v_secretKey
                    ));

    dbms_output.put_line('Success generating token');
    dbms_output.put_line('l_token:' || l_token);
    pout_Code := 0;
    pout_Msj := 'Success generating token';
    pout_Token_JWT := l_token;
EXCEPTION
    WHEN OTHERS THEN
        pout_Code := SQLCODE;
        pout_Msj := 'Error:' || SQLERRM;
        pout_Token_JWT := 'NA - '||l_token ;
        dbms_output.put_line('code:' ||SQLCODE);      
        dbms_output.put_line('msj:' ||SQLERRM);      
end XXGEPP_TOKEN_JWT_PRC;

function validate_token_jwt(pin_header_value varchar2) return clob-- pin_bearer_token varchar2) return clob
is
    raise_token_gepp EXCEPTION;
    --pin_bearer_token   VARCHAR2(4000):='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJYWF9BUEVYIiwic3ViIjoiNTAwNzkyMTIiLCJhdWQiOiJYWEdFUFBfQVBQX1JPTEUiLCJpYXQiOjE3NDA2MDEwNDMsImV4cCI6MTc0MDYwMTEwMywidXNlcl9pZCI6ICIzOTk0IiwidXNlcl9udW0iOiAiQ0VEQVZJTEFDIiwidXNlcl90eXBlIjogIlVTRVJfRUJTIiwidXNlcl9kZXNjcmlwdGlvbiI6ICJEQVZJTEEgQ0FTVEVMQVpPLCBDQVJMT1MgRURVQVJETyJ9.1TIMcLd4Y__867BrB34lsXFNeZMRmBhbev5RGIcoENQ';
    --pin_bearer_token   VARCHAR2(4000):='hbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJYWF9BUEVYIiwic3ViIjoiNTAwNzkyMTIiLCJhdWQiOiJYWEdFUFBfQVBQX1JPTEUiLCJpYXQiOjE3NDA1MTk3NDgsImV4cCI6MTc0MDUxOTgwOCwidXNlcl9pZCI6ICIzOTk0IiwidXNlcl9udW0iOiAiQ0VEQVZJTEFDIiwidXNlcl90eXBlIjogIlVTRVJfRUJTIiwidXNlcl9kZXNjcmlwdGlvbiI6ICJEQVZJTEEgQ0FTVEVMQVpPLCBDQVJMT1MgRURVQVJETyJ9.S2P46SeB69fuKnJM7IVJf-WPtfO3ruNaB5gtlyEucU4';
    v_code number;
    v_msj varchar2(4000);
    l_bearer_token     VARCHAR2(4000);
    l_token            APEX_JWT.T_TOKEN;
    l_user_object      APEX_JSON.T_VALUES;

    v_user varchar2(100);

    v_expiration_date_num number;
    v_expiration_date date;

    v_esquema VARCHAR2(100) :=vg_esquema;--'XX_APEX'; -- Esquema donde vive el proceso
    v_perfil VARCHAR2(100):=vg_perfil;--'XXGEPP_APP_ROLE';
    v_secretKey varchar2(1000) := vg_secretKey;--'G3ppApp1c@t10n KeySecrey!';
    v_seconds_for_renew_token number:=180;
    v_seconds_for_token_expiration number;
    v_resp_login CLOB;
    v_token varchar2(4000);
    v_result clob;
begin
    v_code := 0;

    IF pin_header_value IS NOT NULL AND INSTR(pin_header_value, 'Bearer ') = 1 THEN
        -- Extract the token part after 'Bearer '
        l_bearer_token := SUBSTR(pin_header_value, 8);        
    ELSE
        --return error message in json format if the token is not founded
        v_code := 1;
        v_msj := 'Error: No token found pin_header_value - ' || pin_header_value;
        raise raise_token_gepp;
    END IF;


    begin
    l_token :=
        apex_jwt.DECODE (
            p_value   => l_bearer_token,
            p_signature_key   =>
                sys.UTL_RAW.cast_to_raw (
                    v_secretKey));
    exception
        when others then    
            v_code := 1;
            v_msj := 'Error: No fue posible leer el Token - ' || l_bearer_token;
            raise raise_token_gepp;
    end;
    --extract the payload from the token
    apex_json.parse (l_user_object, l_token.payload);

    --v_user := apex_json.does_exist (p_path => 'sub', p_values => l_user_object);
    v_expiration_date_num := apex_json.get_varchar2 (p_path => 'exp', p_values => l_user_object);
    v_user := apex_json.get_varchar2 (p_path => 'sub', p_values => l_user_object);

    v_expiration_date_num := v_expiration_date_num - 21600;

    select to_date('1970-01-01','YYYY-MM-DD') + numtodsinterval(v_expiration_date_num,'SECOND')    
    into  v_expiration_date
    from dual;

    -- Si el token ya esta caduco sale
    if v_expiration_date < sysdate then
        v_code := 1;
        v_msj :='Error: Token Expirado';
        raise raise_token_gepp;
    end if;

    /***
    validate the token using the apex_jwt package
    @param p_token the JWT
    @param p_iss if not null, verify that the "iss" claim equals p_iss
    @param p_aud if not null, verify that the single "aud" value equals 
    p_aud. If "aud" is an array, verify that the "azp" (Authorized Party) claim equals p_aud. This is an OpenID extension
    ***/
    begin
        apex_jwt.VALIDATE (p_token            => l_token,
                        p_iss              => v_esquema,
                        p_aud              => v_perfil);
    exception
    when others then
        v_code := 1;
        v_msj :='Error: Token no valido ' ;
        raise raise_token_gepp;
    end;


     v_seconds_for_token_expiration := round((v_expiration_date-sysdate)*86400,2);

     if v_seconds_for_token_expiration <= v_seconds_for_renew_token then
         v_resp_login := xxutilities_app_mobile.get_token_jwt(v_user);


        SELECT json_value(v_resp_login,'$."code"') as code
              ,json_value(v_resp_login,'$."msj"') as msj
              ,json_value(v_resp_login,'$."token"') as msj
            into v_code, v_msj,v_token
        from dual;

        if v_code != 0 then
            v_msj := v_msj || ' - RenewTokenFnd';
            raise raise_token_gepp;
        else
            v_code := 0;
            v_msj := 'New Token Assigned!';-- || v_seconds_for_token_expiration || '-' || to_char(v_expiration_date,'ddmmyyyyhh24miss');
            raise raise_token_gepp;
        end if;
     end if;

     v_code := 0;     
     v_msj := 'Token Valid!';-- || v_seconds_for_token_expiration || '-' || to_char(v_expiration_date,'ddmmyyyyhh24miss');
     v_token := null;

        SELECT json_object('code' value v_code
                    ,'msj' value v_msj
                    ,'user_name' value v_user
                    ,'token' value v_token
                    )
             INTO v_result
            FROM DUAL d;
    return v_result;
    --dbms_output.put_line('v_expiration_date_num:'||v_expiration_date_num);
    --dbms_output.put_line('v_expiration_date:'|| to_char(v_expiration_date));
    --dbms_output.put_line('v_code:'||v_expiration_date_num);
    --dbms_output.put_line('v_msj:'|| to_char(v_expiration_date));
exception
    when raise_token_gepp then
        SELECT json_object('code' value v_code
                    ,'msj' value v_msj
                    ,'user_name' value v_user
                    ,'token' value v_token)
             INTO v_result
            FROM DUAL d;
        dbms_output.put_line('v_code:'||v_code);
        dbms_output.put_line('v_msj:'|| v_msj);
        return v_result;
    when others then
        dbms_output.put_line('v_code:'||v_expiration_date_num);
        dbms_output.put_line('v_msj:'|| to_char(v_expiration_date));
        v_code := 1;
        v_msj := v_msj || ' Err ' || SQLERRM;
        SELECT json_object('code' value v_code
                    ,'msj' value v_msj
                    ,'token' value v_token)
             INTO v_result
            FROM DUAL d;
        return v_result;
end validate_token_jwt;

end xxutilities_app_mobile;