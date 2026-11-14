// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

import "stdlib:stdlib.ny";
import "json:json.ny";
import "yaml:yaml.ny";
import "ntest:ntest.ny";
import "schema.ny";

func parse_json(text: string) -> Json {
  let durable = Allocator.ProcessHeap(0i64, 8i64);
  let scratch = Allocator.ProcessHeap(0i64, 8i64);
  let parsed = JsonDocument.Parse(text, durable, scratch);
  AssertTrue(parsed.IsOk());

  return (parsed.get_if<JsonDocument>() as JsonDocument).Root();
}

func parse_yaml(text: string) -> Yaml {
  let durable = Allocator.ProcessHeap(0i64, 8i64);
  let scratch = Allocator.ProcessHeap(0i64, 8i64);
  let parsed = YamlDocument.Parse(text, durable, scratch);
  AssertTrue(parsed.IsOk());

  return (parsed.get_if<YamlDocument>() as YamlDocument).Root();
}

func compile_schema(text: string) -> Schema {
  let admitted = Schema.Compile(parse_json(text));
  AssertTrue(admitted.IsOk());

  return admitted.get_if<Schema>() as Schema;
}

@test
func test_schema_validates_both_document_types() {
  let schema = compile_schema(
    "{\"type\":\"object\",\"required\":[\"name\",\"ports\"],\"additionalProperties\":false,".Concat(
      "\"properties\":{\"name\":{\"type\":\"string\",\"maxLength\":2},\"ports\":{\"type\":\"array\","
    ).Concat("\"minItems\":1,\"items\":{\"type\":[\"integer\",\"null\"]}}}}")
  );
  AssertTrue(schema.Validate(parse_json("{\"name\":\"猫🙂\",\"ports\":[80,null]}")).IsOk());
  AssertTrue(schema.ValidateYaml(parse_yaml("name: 猫🙂\nports: [80, null]\n")).IsOk());

  let failure = schema.ValidateYaml(parse_yaml("name: 猫🙂\nports: [\"80\"]\n"));
  AssertTrue(failure.IsErr());
  let diagnostic = failure.get_if<SchemaError>() as SchemaError;
  AssertTrue(diagnostic.kind == SchemaErrorKind.Violation);
  AssertEqString(diagnostic.instance_path, "/ports/0");
  AssertEqString(diagnostic.schema_path, "/properties/ports/items/type");
  AssertTrue(schema.Validate(parse_json("{\"name\":\"abc\",\"ports\":[80]}")).IsErr());
  AssertTrue(schema.Validate(parse_json("{\"name\":\"x\",\"ports\":[]}")).IsErr());
  AssertTrue(schema.Validate(parse_json("{\"name\":\"x\",\"ports\":[80],\"extra\":true}")).IsErr());
  AssertTrue(schema.Validate(parse_json("{\"name\":\"x\"}")).IsErr());
}

@test
func test_schema_admission_checks_unvisited_rules_and_names() {
  let unsupported = Schema.Compile(parse_json("{\"properties\":{\"a/b~\":{\"pattern\":\"x\"}}}"));
  AssertTrue(unsupported.IsErr());
  let diagnostic = unsupported.get_if<SchemaError>() as SchemaError;
  AssertTrue(diagnostic.kind == SchemaErrorKind.UnsupportedKeyword);
  AssertEqString(diagnostic.schema_path, "/properties/a~1b~0/pattern");
  AssertTrue(Schema.Compile(parse_json("{\"items\":1}")).IsErr());
  AssertTrue(Schema.Compile(parse_json("{\"required\":[\"a\",\"a\"]}")).IsErr());
  AssertTrue(Schema.Compile(parse_json("{\"type\":[\"str\"]}")).IsErr());
  AssertTrue(Schema.Compile(parse_json("{\"$ref\":\"#/$defs/absent\"}")).IsErr());
}

@test
func test_schema_references_and_branch_assertions() {
  let schema = compile_schema(
    "{\"$defs\":{\"a/b~\":{\"type\":\"integer\"}},\"allOf\":[{\"$ref\":\"#/$defs/a~1b~0\"}],"
      .Concat("\"oneOf\":[{\"type\":\"number\"},{\"type\":\"string\"}],\"not\":{\"type\":\"null\"}}")
  );
  AssertTrue(schema.Validate(parse_json("1.000")).IsOk());
  AssertTrue(schema.Validate(parse_json("1.2e1")).IsOk());
  AssertTrue(schema.Validate(parse_json("0e-1000000000000000000")).IsOk());
  AssertTrue(schema.Validate(parse_json("1e-1000000000000000000")).IsErr());

  let failure = schema.Validate(parse_json("0.125"));
  AssertTrue(failure.IsErr());
  AssertEqString((failure.get_if<SchemaError>() as SchemaError).schema_path, "/$defs/a~1b~0/type");

  let exclusive = compile_schema("{\"oneOf\":[{\"type\":\"number\"},{\"type\":\"integer\"}]}");
  AssertTrue(exclusive.Validate(parse_json("1.25")).IsOk());
  AssertTrue(exclusive.Validate(parse_json("1")).IsErr());
  AssertTrue(compile_schema("true").Validate(parse_json("null")).IsOk());
  AssertTrue(compile_schema("false").Validate(parse_json("null")).IsErr());
}

@test
func test_schema_reference_limit_survives_negation() {
  let schema = compile_schema(
    "{\"$defs\":{\"loop\":{\"$ref\":\"#/$defs/loop\"}},\"not\":{\"$ref\":\"#/$defs/loop\"}}"
  );
  let outcome = schema.Validate(parse_json("1"));
  AssertTrue(outcome.IsErr());
  let diagnostic = outcome.get_if<SchemaError>() as SchemaError;
  AssertTrue(diagnostic.kind == SchemaErrorKind.LimitExceeded);
}

@test
func test_yaml_schema_and_exact_numeric_comparisons() {
  let compiled = Schema.CompileYaml(parse_yaml("type: integer\nminimum: 2\nexclusiveMaximum: 10\n"));
  AssertTrue(compiled.IsOk());
  let rule = compiled.get_if<Schema>() as Schema;
  AssertTrue(rule.Validate(parse_json("2.00")).IsOk());
  AssertTrue(rule.ValidateYaml(parse_yaml("9")).IsOk());
  AssertTrue(rule.Validate(parse_json("10.0")).IsErr());
  AssertTrue(rule.Validate(parse_json("1")).IsErr());

  let number = compile_schema("{\"minimum\":9007199254740993,\"exclusiveMaximum\":9007199254740995}");
  AssertTrue(number.Validate(parse_json("9007199254740994.5")).IsOk());
  AssertTrue(number.Validate(parse_json("9007199254740992.9999")).IsErr());
  AssertTrue(number.Validate(parse_json("9007199254740995.0000")).IsErr());
  AssertTrue(compile_schema("{\"maximum\":-0.02}").Validate(parse_json("-0.021")).IsOk());
}

@test
func test_enum_and_const_use_json_schema_value_equality() {
  let constraint = compile_schema("{\"const\":{\"name\":\"x\",\"items\":[0,1.00]}}");
  AssertTrue(constraint.Validate(parse_json("{\"items\":[-0.0,1e0],\"name\":\"x\"}")).IsOk());
  AssertTrue(constraint.ValidateYaml(parse_yaml("name: x\nitems: [0, 1]\n")).IsOk());
  AssertTrue(constraint.Validate(parse_json("{\"items\":[1,0],\"name\":\"x\"}")).IsErr());

  let choices = compile_schema("{\"enum\":[null, 1.23, false, \"1.23\"]}");
  AssertTrue(choices.Validate(parse_json("0.123e1")).IsOk());
  AssertTrue(choices.ValidateYaml(parse_yaml("false")).IsOk());
  AssertTrue(choices.ValidateYaml(parse_yaml("null")).IsOk());
  AssertTrue(choices.Validate(parse_json("1.23000000000000000000001")).IsErr());
  AssertTrue(Schema.Compile(parse_json("{\"enum\":[]}")).IsErr());
}
