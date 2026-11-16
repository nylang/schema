// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

import "stdlib:stdlib.ny";
import "ntest:ntest.ny";
import "schema.ny";
import "scalar.ny";

@test
func test_scalar_decimal_representation_is_independent_of_serialization() {
  let fixed = SchemaDecimal.FromParts("", "000120");
  let scientific = SchemaDecimal.FromDigits("12", -3i64);
  AssertEqI32(fixed.Compare(scientific), 0);
  let zero = SchemaDecimal.FromParts("", "000", negative: true);
  AssertEqI32(zero.Compare(SchemaDecimal.FromDigits("", 0i64)), 0);

  let left = SchemaDecimal.FromParts("12345678901234567890", "00001", negative: true);
  let right = SchemaDecimal.FromParts("12345678901234567890", "00002", negative: true);
  AssertTrue(left.Compare(right) > 0);
  let whole = SchemaDecimal.FromParts("12", "30");
  AssertEqI32(whole.Compare(SchemaDecimal.FromDigits("123", 2i64)), 0);
}

struct TestMember {
  key: string;
  kind: SchemaKind;
  scalar: SchemaScalar;
}

// A small reader supplied by an application without either codec.
struct TestReader implements SchemaReader {
  root_kind: SchemaKind;
  root_scalar: SchemaScalar;
  members: Array<TestMember>;
}

@override
method(TestReader) Root() -> uintptr {
  return 1up;
}

@override
method(TestReader) Kind(node: uintptr) -> SchemaKind {
  if node == 1up {
    return self.root_kind;
  }

  return self.members.Get((node - 2up) as int32).kind;
}

@override
method(TestReader) Scalar(node: uintptr) -> SchemaScalar {
  if node == 1up {
    return self.root_scalar;
  }

  return self.members.Get((node - 2up) as int32).scalar;
}

@override
method(TestReader) Len(node: uintptr) -> int32 {
  return node == 1up ? self.members.Len() : 0;
}

@override
method(TestReader) KeyAt(node: uintptr, index: int32) -> string {
  return self.members.Get(index).key;
}

@override
method(TestReader) ChildAt(node: uintptr, index: int32) -> uintptr {
  return 2up + (index as uintptr);
}

static method(TestReader) CompileStringLimit() -> Result<Schema, SchemaError> {
  var members: Array<TestMember> = Array<TestMember>.New();
  members.Push(TestMember{key: "type", kind: SchemaKind.String, scalar: SchemaScalar{text: "string"}});
  members.Push(TestMember{key: "minLength", kind: SchemaKind.Number, scalar: SchemaScalar{text: "2", count: 2u64}});
  let reader = TestReader{root_kind: SchemaKind.Object, members: move(members)};

  return Schema.Compile(reader);
}

@test
func test_schema_owns_rules_beyond_reader_lifetime() {
  let admitted = TestReader.CompileStringLimit();
  if AssertTrue(admitted.IsOk()) != 0 {
    return;
  }

  let compiled = admitted.get_if<Schema>() as Schema;
  let short = TestReader{root_kind: SchemaKind.String, root_scalar: SchemaScalar{text: "猫"}};
  let valid = TestReader{root_kind: SchemaKind.String, root_scalar: SchemaScalar{text: "猫🙂"}};
  let result = compiled.Validate(short);
  if AssertTrue(result.IsErr()) != 0 {
    return;
  }

  let error = result.get_if<SchemaError>() as SchemaError;
  AssertTrue(error.kind == SchemaErrorKind.Violation);
  AssertEqString(error.instance_path, "");
  AssertEqString(error.schema_path, "/minLength");
  AssertTrue(compiled.Validate(valid).IsOk());
}

@test
func test_schema_does_not_read_unneeded_children() {
  let boolean = TestReader{root_kind: SchemaKind.Boolean, root_scalar: SchemaScalar{boolean: true}};
  let admitted = Schema.Compile(boolean);
  if AssertTrue(admitted.IsOk()) != 0 {
    return;
  }

  let compiled = admitted.get_if<Schema>() as Schema;
  // The reader has no initialized members. A true schema only needs a root handle.
  let value = TestReader{root_kind: SchemaKind.Array};
  AssertTrue(compiled.Validate(value).IsOk());
}
