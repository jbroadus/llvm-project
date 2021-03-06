// RUN: mlir-tblgen -gen-op-defs -I %S/../../include %s | FileCheck %s

include "mlir/IR/OpBase.td"

def Test_Dialect : Dialect {
  let name = "test";
}
class NS_Op<string mnemonic, list<OpTrait> traits> :
    Op<Test_Dialect, mnemonic, traits>;

def OpA : NS_Op<"one_normal_result_op", []> {
  let results = (outs I32:$result);
}

// CHECK-LABEL: void OpA::build
// CHECK:         ArrayRef<Type> resultTypes, ValueRange operands
// CHECK:         assert(resultTypes.size() == 1u && "mismatched number of return types");
// CHECK-NEXT:    odsState.addTypes(resultTypes);

def OpB : NS_Op<"same_input_output_type_op", [SameOperandsAndResultType]> {
  let arguments = (ins I32:$x);
  let results = (outs I32:$y);
}

// CHECK-LABEL: OpB definitions
// CHECK: void OpB::build(Builder *odsBuilder, OperationState &odsState, Type y, Value x)
// CHECK:   odsState.addTypes(y);
// CHECK: void OpB::build(Builder *odsBuilder, OperationState &odsState, Value x)
// CHECK:   odsState.addTypes({x.getType()});

def OpC : NS_Op<"three_normal_result_op", []> {
  let results = (outs I32:$x, /*unnamed*/I32, I32:$z);
}

// CHECK-LABEL: OpC definitions
// CHECK:       void OpC::build(Builder *odsBuilder, OperationState &odsState, Type x, Type resultType1, Type z)
// CHECK-NEXT:   odsState.addTypes(x)
// CHECK-NEXT:   odsState.addTypes(resultType1)
// CHECK-NEXT:   odsState.addTypes(z)

def IntegerTypeAttr : TypeAttrBase<"IntegerType", "Integer type attribute">;
def OpD : NS_Op<"type_attr_as_result_type", [FirstAttrDerivedResultType]> {
  let arguments = (ins I32:$x, IntegerTypeAttr:$attr, F32Attr:$f32);
  let results = (outs AnyTensor:$y);
}

// CHECK-LABEL: OpD definitions
// CHECK: void OpD::build(Builder *odsBuilder, OperationState &odsState, ValueRange operands, ArrayRef<NamedAttribute> attributes)
// CHECK: odsState.addTypes({attr.second.cast<TypeAttr>().getValue()});

def OpE : NS_Op<"value_attr_as_result_type", [FirstAttrDerivedResultType]> {
  let arguments = (ins I32:$x, F32Attr:$attr);
  let results = (outs AnyTensor:$y);
}

// CHECK-LABEL: OpE definitions
// CHECK: void OpE::build(Builder *odsBuilder, OperationState &odsState, ValueRange operands, ArrayRef<NamedAttribute> attributes)
// CHECK: odsState.addTypes({attr.second.getType()});

def OpF : NS_Op<"one_variadic_result_op", []> {
  let results = (outs Variadic<I32>:$x);
}

// CHECK-LABEL: void OpF::build
// CHECK-SAME:    ArrayRef<Type> x
// CHECK-NOT:     assert
// CHECK:         odsState.addTypes(x);

def OpG : NS_Op<"one_normal_and_one_variadic_result_op", []> {

  let results = (outs I32:$x, Variadic<I32>:$y);
}

// CHECK-LABEL: OpG definitions

// CHECK:      void OpG::build(Builder *odsBuilder, OperationState &odsState, Type x, ArrayRef<Type> y)
// CHECK-NEXT:   odsState.addTypes(x);
// CHECK-NEXT:   odsState.addTypes(y);

// CHECK:       void OpG::build
// CHECK:         ArrayRef<Type> resultTypes
// CHECK:         assert(resultTypes.size() >= 1u && "mismatched number of return types");
// CHECK-NEXT:    odsState.addTypes(resultTypes);

def OpI : NS_Op<"mix_variadic_and_normal_results_op", [SameVariadicResultSize]> {
  let results = (outs Variadic<AnyTensor>:$output1, AnyTensor:$output2, Variadic<AnyTensor>:$output3);
}

// CHECK-LABEL: Operation::result_range OpI::output1
// CHECK-NEXT:    return getODSResults(0);

// CHECK-LABEL: Value OpI::output2
// CHECK-NEXT:    return *getODSResults(1).begin();

// CHECK-LABEL: OpI::build
// CHECK-NEXT:    odsState.addTypes(output1);
// CHECK-NEXT:    odsState.addTypes(output2);
// CHECK-NEXT:    odsState.addTypes(output3);

// Test that if the only operand is variadic, we access the first value in the
// pack to set result type
// ---
def OpK : NS_Op<"only_input_is_variadic_with_same_value_type_op", [SameOperandsAndResultType]> {
  let arguments = (ins Variadic<AnyTensor>:$input);
  let results = (outs AnyTensor:$result);
}

// CHECK-LABEL: OpK::build(Builder *odsBuilder, OperationState &odsState, ValueRange input)
// CHECK: odsState.addTypes({input.front().getType()});
