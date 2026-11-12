create or replace  package XXDF_DIGITAL_FILE_PKG
as
    -- PACKAGE TO MANAGER DIGITAL FILE RECORDS
    PROCEDURE INSERT_OR_UPDATE_FILE_DIGITAL(pin_ReferenceIdNumber IN number
                                            ,pin_ReferenceIdStr IN VARCHAR2
                                            ,pin_Array_Code IN VARCHAR2
                                            ,pout_code OUT NUMBER
                                            ,pout_msj OUT VARCHAR2
                                            );

    PROCEDURE LOAD_FILE_IN_TABLE(pin_array_file_trx_id IN NUMBER
                                ,in_type_file_name IN VARCHAR2
                                ,pin_File_Blob IN BLOB
                                ,pin_Mime_Type IN VARCHAR2
                                ,pin_File_Name IN VARCHAR2
                                ,pin_Bytes_Size IN NUMBER
                                ,pout_code OUT NUMBER
                                ,pout_msj OUT VARCHAR2                                
                                );
                                
end XXDF_DIGITAL_FILE_PKG;
/
GRANT EXECUTE ON CFDI_AP_AR.XXDF_DIGITAL_FILE_PKG TO xx_apex;