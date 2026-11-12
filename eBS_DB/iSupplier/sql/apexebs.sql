CREATE OR REPLACE PACKAGE BODY apps.apex_global
AS
   FUNCTION check_ebs_credentials
      RETURN BOOLEAN
   IS
      c_ebs            VARCHAR2 (240) := 'E-Business Suite';
      --
      l_authorized     BOOLEAN;
      l_user_id        NUMBER;
      l_resp_id        NUMBER;
      l_resp_appl_id   NUMBER;
      l_sec_group_id   NUMBER;
      l_org_id         NUMBER;
      l_time_out       NUMBER;
      l_ebs_url        VARCHAR2 (100);
      l_appl_name      VARCHAR2 (240);

--
      CURSOR get_apps_credentials
      IS
         SELECT iss.user_id, iss.responsibility_id,
                iss.responsibility_application_id, iss.security_group_id,
                iss.org_id, iss.time_out, isa.VALUE
           FROM apps.icx_sessions iss, apps.icx_session_attributes isa
          WHERE iss.session_id = apps.icx_sec.getsessioncookie
            AND isa.session_id = iss.session_id
            AND isa.NAME = '_USERORSSWAPORTALURL';

      --
      CURSOR get_appl_name (b_appl_id NUMBER)
      IS
         SELECT application_name
           FROM apps.fnd_application_tl
          WHERE application_id = b_appl_id AND LANGUAGE = USERENV ('LANG');
--
   BEGIN
      OPEN get_apps_credentials;

      FETCH get_apps_credentials
       INTO l_user_id, l_resp_id, l_resp_appl_id, l_sec_group_id, l_org_id,
            l_time_out, l_ebs_url;

      --
      IF get_apps_credentials%NOTFOUND
      THEN
         l_authorized := FALSE;
      ELSE
         l_authorized := TRUE;

         --
         OPEN get_appl_name (l_resp_appl_id);

         FETCH get_appl_name
          INTO l_appl_name;

         IF get_appl_name%NOTFOUND
         THEN
            l_appl_name := c_ebs;
         END IF;

         CLOSE get_appl_name;

--
         apex_util.set_session_state ('EBS_USER_ID', TO_CHAR (l_user_id));
         apex_util.set_session_state ('EBS_RESP_ID', TO_CHAR (l_resp_id));
         apex_util.set_session_state ('EBS_RESP_APPL_ID',
                                      TO_CHAR (l_resp_appl_id)
                                     );
         apex_util.set_session_state ('EBS_SEC_GROUP_ID',
                                      TO_CHAR (l_sec_group_id)
                                     );
         apex_util.set_session_state ('EBS_ORG_ID', TO_CHAR (l_org_id));
--       apex_util.set_session_state('EBS_TIME_OUT',TO_CHAR(l_time_out));
         apex_util.set_session_state ('EBS_URL', l_ebs_url);
         apex_util.set_session_state ('EBS_APPLICATION_NAME', l_appl_name);
--
         apex_util.set_session_max_idle_seconds (l_time_out * 60,
                                                 'APPLICATION'
                                                );
      END IF;

      --
      CLOSE get_apps_credentials;

      RETURN l_authorized;
--
   EXCEPTION
      WHEN OTHERS
      THEN
         IF get_apps_credentials%ISOPEN
         THEN
            CLOSE get_apps_credentials;
         END IF;

         RETURN FALSE;
   END check_ebs_credentials;
END apex_global;