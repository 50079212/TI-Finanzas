create or replace  package body XXDF_DIGITAL_FILE_PKG
as
    -- PACKAGE TO MANAGER DIGITAL FILE RECORDS
    PROCEDURE INSERT_OR_UPDATE_FILE_DIGITAL( pin_ReferenceIdNumber IN number
                                            ,pin_ReferenceIdStr IN VARCHAR2
                                            ,pin_Array_Code IN VARCHAR2
                                            ,pout_code OUT NUMBER
                                            ,pout_msj OUT VARCHAR2
                                            )                                 
    IS
        v_header_id_trx NUMBER;
        v_array_file_id NUMBER;
        v_structure_exists number := 0;
        v_out_code NUMBER;
        v_out_msj VARCHAR2(255);

        exception_process EXCEPTION;
    BEGIN
        v_out_code := 0;
        v_out_msj := 'Success';
        v_array_file_id := NULL;

        BEGIN
            -- Get array_file_id based on pin_Array_Code
            SELECT array_file_id
            INTO v_array_file_id
            FROM XXDF_FILES_ARRAY_HEADER
            WHERE array_code = pin_Array_Code;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_out_code := -1;
                v_out_msj := 'No data found for the given array code';
                RAISE exception_process;
            WHEN OTHERS THEN
                v_out_code := -1;
                v_out_msj := 'Error occurred while fetching array_file_id';
                RAISE exception_process;
        END;

        -- Check if the structure exists before inserting lines
        SELECT COUNT(*)
        INTO v_structure_exists
        FROM XXDF_HEADER_TRX_TBL h
        WHERE 1=1
        and h.array_code = pin_Array_Code
        and h.reference_id_number = pin_ReferenceIdNumber
        and h.reference_id_string = pin_ReferenceIdStr;
            
        IF v_structure_exists = 0 THEN
            -- Insert the structure into the header table
             v_header_id_trx := XXDF_HEADER_TRX_TBL_SEQ.NEXTVAL;
            -- Insert header and lines to save files
            INSERT INTO XXDF_HEADER_TRX_TBL (header_id_trx,array_code,array_file_id,  reference_id_number, reference_id_string)
            VALUES (v_header_id_trx, pin_Array_Code, v_array_file_id, pin_ReferenceIdNumber, pin_ReferenceIdStr)
            ;

            -- Insert lines for the digital file records
            INSERT INTO XXDF_FILES_ARRAY_TRX_ALL (array_file_id, array_file_line_id, header_id_trx, version_number, file_id, creation_date, created_by, last_updated_date, last_updated_by,current_version_flag,load_status_file,process_status_file,response_of_process_file)
            select h.array_file_id, l.ARRAY_FILE_LINE_ID, v_header_id_trx, 1, NULL, SYSDATE, 'admin', SYSDATE,'admin', 'Y', 'NO CARGADO', NULL, NULL
            from XXDF_FILES_ARRAY_HEADER h
                ,XXDF_FILES_ARRAY_LINES l 
            where 1=1
            and h.array_file_id = v_array_file_id
            and h.array_file_id = l.array_file_id
            and l.enabled_flag = 'Y'
            and l.start_date <= sysdate
            and (l.end_date is null or l.end_date >= sysdate);

            commit; 
        ELSE    
            -- Update the existing structure if it already exists
            SELECT header_id_trx
            INTO v_header_id_trx
            FROM XXDF_HEADER_TRX_TBL h
            WHERE 1=1
            and h.array_code = pin_Array_Code
            and h.reference_id_number = pin_ReferenceIdNumber
            and h.reference_id_string = pin_ReferenceIdStr;

            -- Update the existing lines for the digital file records
            INSERT INTO XXDF_FILES_ARRAY_TRX_ALL (array_file_id, array_file_line_id, header_id_trx, version_number, file_id, creation_date, created_by, last_updated_date, last_updated_by,current_version_flag,load_status_file,process_status_file,response_of_process_file)
            select h.array_file_id, l.ARRAY_FILE_LINE_ID, v_header_id_trx, 1, NULL, SYSDATE, 'admin', SYSDATE,'admin', 'Y', 'NO CARGADO', NULL, NULL
            from XXDF_FILES_ARRAY_HEADER h
                ,XXDF_FILES_ARRAY_LINES l 
            where 1=1
            and h.array_file_id = v_array_file_id
            and h.array_file_id = l.array_file_id
            and l.enabled_flag = 'Y'
            and l.start_date <= sysdate
            and (l.end_date is null or l.end_date >= sysdate)
            and not exists (
                            select 1
                            from XXDF_FILES_ARRAY_TRX_ALL t
                            where 1=1
                            and t.HEADER_ID_TRX = v_header_id_trx
                            and t.array_file_id = h.array_file_id
                            and t.array_file_line_id = l.array_file_line_id
                        );

        END IF;

       commit;

    EXCEPTION
        WHEN exception_process THEN 
            v_out_code := v_out_code;
            v_out_msj := v_out_msj;
    END INSERT_OR_UPDATE_FILE_DIGITAL;

    PROCEDURE LOAD_FILE_IN_TABLE(pin_array_file_trx_id IN NUMBER
                                ,in_type_file_name IN VARCHAR2
                                ,pin_File_Blob IN BLOB
                                ,pin_Mime_Type IN VARCHAR2
                                ,pin_File_Name IN VARCHAR2
                                ,pin_Bytes_Size IN NUMBER
                                ,pout_code OUT NUMBER
                                ,pout_msj OUT VARCHAR2
                                )
    IS
        L_CABECERA      VARCHAR2(5);
        L_ARCHIVO        BLOB;
        L_TIPO_ARCHIVO   VARCHAR2(100);

        v_file_id NUMBER;

        exception_process EXCEPTION; 
    BEGIN
        L_ARCHIVO := pin_File_Blob;
        L_TIPO_ARCHIVO := in_type_file_name;

        -- No confiar solamente en la extensión o el tipo MIME.
        L_CABECERA := UTL_RAW.CAST_TO_VARCHAR2(
            DBMS_LOB.SUBSTR(
                L_ARCHIVO,
                5,
                1
            )
        );

        IF L_CABECERA <> '%'|| in_type_file_name || '-' THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'El archivo seleccionado no contiene un PDF válido.'
            );
        END IF;

        IF pin_Bytes_Size > 10 * 1024 * 1024 THEN
            pout_code := -1;
            pout_msj := 'El archivo excede el tamaño máximo de 10 MB.';
            raise exception_process;
        END IF;

        v_file_id := XXDF_FILES_BLOB_SEQ.NEXTVAL;

        -- Implementation for loading the file into the table goes here
        INSERT INTO XXDF_FILES_BLOB (FILE_ID, FILE_BLOB, MIME_TYPE, FILE_NAME, BYTES_SIZE, CREATION_DATE, CREATED_BY, LAST_UPDATED_DATE, LAST_UPDATED_BY)
        VALUES (v_file_id, pin_File_Blob, pin_Mime_Type, pin_File_Name, pin_Bytes_Size, SYSDATE, 'admin', SYSDATE, 'admin');

        COMMIT;

        -- Now lets create reference to reference_id
        declare
            v_version_number NUMBER;
            v_file_id_row NUMBER;
        begin
            select nvl(file_id,0),version_number
            into v_file_id_row,v_version_number
            from XXDF_FILES_ARRAY_TRX_ALL
            where 1=1
            and array_file_trx_id = pin_array_file_trx_id;

            IF v_file_id_row = 0 THEN
                UPDATE XXDF_FILES_ARRAY_TRX_ALL
                set file_id = v_file_id
                    , LAST_UPDATED_DATE = SYSDATE
                    , last_updated_by = 'admin'
                    ,load_status_file = 'CARGADO SIN VALIDAR'
                    ,process_status_file = NULL
                    ,response_of_process_file = NULL
                where 1=1
                and array_file_trx_id = pin_array_file_trx_id;

                commit;
            ELSE
                -- Copy to history table
                INSERT INTO XXDF_FILES_ARRAY_TRX_ALL_HIST (array_file_trx_id, array_file_id, array_file_line_id, header_id_trx, version_number, current_version_flag, file_id, CREATION_DATE, CREATED_BY, LAST_UPDATED_DATE, LAST_UPDATED_BY, LOAD_STATUS_FILE, PROCESS_STATUS_FILE, RESPONSE_OF_PROCESS_FILE)
                SELECT array_file_trx_id, array_file_id, array_file_line_id, header_id_trx, version_number, current_version_flag, file_id, CREATION_DATE, CREATED_BY, LAST_UPDATED_DATE, LAST_UPDATED_BY, LOAD_STATUS_FILE, PROCESS_STATUS_FILE, RESPONSE_OF_PROCESS_FILE
                FROM XXDF_FILES_ARRAY_TRX_ALL
                WHERE array_file_trx_id = pin_array_file_trx_id;
                
                v_version_number := v_version_number + 1;
                -- Update the current record with the new file_id
                UPDATE XXDF_FILES_ARRAY_TRX_ALL
                SET file_id = v_file_id
                    , LAST_UPDATED_DATE = SYSDATE
                    , last_updated_by = 'admin'
                    , version_number = v_version_number
                    ,load_status_file = 'CARGADO SIN VALIDAR'
                    ,process_status_file = NULL
                    ,response_of_process_file = NULL
                WHERE array_file_trx_id = pin_array_file_trx_id;
                commit;
            END IF;
        end;

        pout_code := 0;
        pout_msj := 'File loaded successfully pin_array_file_trx_id:' || pin_array_file_trx_id  ;
    EXCEPTION
        WHEN exception_process THEN
            pout_code := -1;

        WHEN OTHERS THEN
            pout_code := -1;
            pout_msj := SQLERRM;
    END LOAD_FILE_IN_TABLE;
end XXDF_DIGITAL_FILE_PKG;