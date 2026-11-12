CREATE OR REPLACE PACKAGE BODY XX_PriceListWithoutTaxes AS

    FUNCTION GetPriceWithoutTaxes (pin_Org_Id           IN  NUMBER
                                  ,pin_Customer_Number     IN  VARCHAR2
                                  ,pin_Item_No              IN  VARCHAR2
                                 ) RETURN xxar_precios_cte_v1%ROWTYPE
    IS
        v_Result xxar_precios_cte_v1%ROWTYPE;
        v_Customer_Number VARCHAR2(20);
    BEGIN
        --
        -- Si se coloca la palabra IVA16 se tomara el cliente 12657 para hacer los calculos con 16%
        -- Si se coloca la palabra IVA8 se tomara el cliente 88612 para hacer los calculos con 8%
        -- Cabe mencionar que lo mas certero es ocupar el cliente que corresponda.
        IF pin_Customer_Number = 'IVA16' THEN
            v_Customer_Number := '12657';
        ELSIF pin_Customer_Number = 'IVA8' THEN
            v_Customer_Number := '88612';
        ELSE
            v_Customer_Number := pin_Customer_Number;
        END IF;

        SELECT *
        INTO v_Result
        FROM xxar_precios_cte_v1
        WHERE org_id = pin_Org_Id
          AND customer_number = v_Customer_Number
          AND item_no = pin_Item_No
          ;

        
    RETURN v_Result;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(
            -20001,'No existe el registro con Org ID ' || pin_Org_Id ||
            ', Customer Number ' || v_Customer_Number ||
            ', Item No ' || pin_Item_No
        );
    WHEN TOO_MANY_ROWS THEN
        RAISE_APPLICATION_ERROR(
            -20002,'Existe más de un registro con Org ID ' || pin_Org_Id ||
            ', Customer Number ' || v_Customer_Number ||
            ', Item No ' || pin_Item_No
        );
    END GetPriceWithoutTaxes;

    FUNCTION GetFinalPriceWithoutTaxes (pin_Org_Id           IN  NUMBER
                                          ,pin_Customer_Number     IN  VARCHAR2
                                          ,pin_Item_No              IN  VARCHAR2
                                          ,pin_PriceWithTaxes     IN  NUMBER
                                         ) RETURN NUMBER
    IS
        v_Result xxar_precios_cte_v1%ROWTYPE;
        v_IVA NUMBER;
        v_FinalPrice NUMBER;
    BEGIN
        v_Result := GetPriceWithoutTaxes(pin_Org_Id, pin_Customer_Number, pin_Item_No);
        v_FinalPrice := round((abs(pin_PriceWithTaxes) / (1+(v_Result.factor_iva_final/100))) - v_Result.ieps_x_sku,2);
       -- v_FinalPrice := abs(pin_PriceWithTaxes) - v_IVA;--- v_Result.ieps_x_sku;
        --v_FinalPrice := 0;
        RETURN v_FinalPrice;
    
    END GetFinalPriceWithoutTaxes;

    PROCEDURE GetFinalPriceWithoutTaxesPrc (pin_Org_Id           IN  NUMBER
                                          ,pin_Customer_Number     IN  VARCHAR2
                                          ,pin_Item_No              IN  VARCHAR2
                                          ,pin_PriceWithTaxes     IN  NUMBER
                                          ,pout_FinalPrice           OUT NUMBER
                                          ,pout_IVA           OUT NUMBER
                                          ,pout_IEPS           OUT NUMBER
                                          ,pout_IEPS_Ener_Alim_sku    OUT NUMBER
                                          ,pout_PriceWithOutIva           OUT NUMBER
                                          ,pout_SourceIva           OUT VARCHAR2
                                         ) 
    IS
        v_Result xxar_precios_cte_v1%ROWTYPE;
        v_IVA NUMBER;
        v_FinalPrice NUMBER;
    BEGIN
        v_Result := GetPriceWithoutTaxes(pin_Org_Id, pin_Customer_Number, pin_Item_No);
        pout_IVA := abs(pin_PriceWithTaxes) - round((abs(pin_PriceWithTaxes) / (1+(v_Result.factor_iva_final/100))),2);
        pout_IEPS := v_Result.ieps_x_sku;
        
        v_FinalPrice := round((abs(pin_PriceWithTaxes) / (1+(v_Result.factor_iva_final/100))) - v_Result.ieps_x_sku,2);
        -- If have others ieps it´s discounted
        pout_IEPS_Ener_Alim_sku := round(v_FinalPrice * (v_Result.factor_ieps_ener_alim_sku/100),2);

        v_FinalPrice := v_FinalPrice - pout_IEPS_Ener_Alim_sku;
       -- v_FinalPrice := abs(pin_PriceWithTaxes) - v_IVA;--- v_Result.ieps_x_sku;
        --v_FinalPrice := 0;
        pout_FinalPrice := v_FinalPrice;
        pout_PriceWithOutIva := round((abs(pin_PriceWithTaxes) / (1+(v_Result.factor_iva_final/100))),2);
        pout_SourceIva := v_Result.factor_iva_obtenido_en;
    
    END GetFinalPriceWithoutTaxesPrc;

END XX_PriceListWithoutTaxes;
/