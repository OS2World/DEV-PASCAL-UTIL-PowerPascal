program foo;

type
  Value    = Record
               Case Byte of
                 0 : ( Int   : Longint );
                 1 : ( Float : Double  );
                 2 : ( Ch    : Char    );
                 3 : ( Str   : String  );
             End;


  TForm    = (No_Form,Scalar_Form,Enum_Form,Subrange_Form,
              Array_Form,Record_Form);

  TDef     = (No_Def,Constant_Def,Type_Def,Variable_Def,
              Field_Def,ValueParam_Def,VariableParam_Def,
              Program_Def,Procedure_Def,Function_Def);

  PDefinition = ^TDefinition;
  PSymbol     = ^TSymbol;
  PType       = ^TType;

  TDefinition = Record
                  Key      : TDef; { What type of definition is this? }
                  Case Byte of
                    0 : ( Constant     : Value    );

                    1 : ( Param_Count      : Integer;
                          Total_Param_Size : Integer;
                          Total_Local_Size : Integer;
                          Paramaters       : PSymbol;
                          Locals           : PSymbol;
                          Local_Symbols    : PSymbol;
                          Code_Address     : Longint; );

                    2 : ( Offset           : Integer;
                          Record_Def       : PSymbol; );
                End;

  TType    = Record
               Size   : Integer;
               Symbol : PSymbol;

               Minimum,
               Maximum,
               Count    : Integer;

               Case Form:TForm of
                 Enum_Form      : ( Constant_Symbol : PSymbol );

                 Subrange_Form  : ( Range_Type      : PType;  );

                 Array_Form     : ( Index_Type,
                                    Element_Type    : PType;  );

                 Record_Form    : ( Field_Symbol    : PSymbol );
             End;

  TSymbol  = Record
               Left,Right     : PSymbol;
               Next           : PSymbol;
               Name           : String;
               Definition     : PDefinition;
               TypeDefinition : PType;
               Level          : Integer;
               Label_Index    : Integer;
             End;

begin
end.