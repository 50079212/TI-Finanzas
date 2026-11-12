--drop procedure XXBOT.XXBOT_LOG_EDOCTA
CREATE OR REPLACE procedure XXBOT.XXBOT_LOG_EDOCTA(
			p_org_id NUMBER,P_ESTATUS NUMBER, P_PUNTO_CONTROL NUMBER, P_TEXT VARCHAR2
			,P_INS_CONTEO VARCHAR2
            ,P_REQUEST_ID NUMBER)
        is
          v_return number;
          v_request_id NUMBER;
        BEGIN

            IF P_REQUEST_ID IS NOT NULL THEN
                v_request_id := P_REQUEST_ID;
            ELSE
                v_request_id := NVL(fnd_global.conc_request_id,0);
            END IF;
    
	      insert into XXBOT.XXBOT_LOG_CONTROL_EDO_CTA (estatus,fecha,punto_control, text,ORG_ID,REQUEST_ID) 
	      values (P_ESTATUS,sysdate,P_PUNTO_CONTROL,'0' ||P_TEXT,p_org_id,v_request_id); 

	      IF P_INS_CONTEO IN ('Y','S','YES','SI') THEN
	          v_return := 0;
				
	          SELECT count(*)
	            into v_return
	          from XXBOT.XXAR_BOTS_EDO_CTA ecl
	          WHERE 1=1		
	          AND ecl.org_id = p_org_id       
	          AND ecl.last_update_date_prc >=trunc(sysdate-2);
				
	          insert into XXBOT.XXBOT_LOG_CONTROL_EDO_CTA (estatus,fecha,punto_control, text,ORG_ID,REQUEST_ID) 
	          values (P_ESTATUS,sysdate,P_PUNTO_CONTROL,'666 Conteo:'||v_return,p_org_id,v_request_id); 
	                     
	     	END IF;                                                                           
          
         commit;
end xxbot_log_edocta;