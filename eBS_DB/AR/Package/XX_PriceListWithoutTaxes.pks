CREATE OR REPLACE PACKAGE XX_PriceListWithoutTaxes AS    

    FUNCTION GetPriceWithoutTaxes (pin_Org_Id           IN  NUMBER
                                  ,pin_Customer_Number     IN  VARCHAR2
                                  ,pin_Item_No              IN  VARCHAR2
                                 ) RETURN xxar_precios_cte_v1%ROWTYPE;
                                 
    FUNCTION GetFinalPriceWithoutTaxes (pin_Org_Id           IN  NUMBER
                                          ,pin_Customer_Number     IN  VARCHAR2
                                          ,pin_Item_No              IN  VARCHAR2
                                          ,pin_PriceWithTaxes     IN  NUMBER
                                         ) RETURN NUMBER;

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
                                         );
END XX_PriceListWithoutTaxes;
/
--GRANT EXECUTE ON XXWEBC.XX_PRICELISTWITHOUTTAXES TO APPS;
