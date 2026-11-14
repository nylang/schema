// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of DocumentSchema;

pub static method(Schema) CompileYaml(rule: Yaml) -> Result<Schema, SchemaError> {
  var walk = SchemaWalk{};
  let converted = walk.ConvertYaml(rule, SchemaLocation{}, 0);
  if converted.IsErr() {
    let diagnostic = converted.get_if<SchemaError>() as SchemaError;
    return Err<Schema, SchemaError>(SchemaError{
      kind: diagnostic.kind, schema_path: diagnostic.instance_path, message: diagnostic.message
    });
  }

  return Schema.Compile(converted.get_if<Json>() as Json);
}

pub method(Schema) ValidateYaml(value: Yaml) -> Result<Unit, SchemaError> {
  var walk = SchemaWalk{};
  let converted = walk.ConvertYaml(value, SchemaLocation{}, 0);
  if converted.IsErr() {
    return Err<Unit, SchemaError>(converted.get_if<SchemaError>() as SchemaError);
  }

  return self.Validate(converted.get_if<Json>() as Json);
}

// Preserve the parsed YAML scalar tags and feed the resulting value to the same evaluator.
method(SchemaWalk) ConvertYaml(
  value: Yaml, location: SchemaLocation, depth: int32
) -> Result<Json, SchemaError> {
  let limit = self.Visit(location, depth);
  if limit != nil {
    return Err<Json, SchemaError>(limit as SchemaError);
  }

  let mapping = value.AsMap();
  if mapping != nil {
    let entries = mapping as YamlMap;
    var children = Array<JsonObjectEntry>.New();
    var i: int32 = 0;
    while i < entries.Len() {
      let key = entries.KeyAt(i) as string;
      let child = self.ConvertYaml(entries.ValueAt(i) as Yaml, location.Instance(key), depth + 1);
      if child.IsErr() {
        return child;
      }
      children.Push(JsonObjectEntry{key: key, value: child.get_if<Json>() as Json});
      i += 1;
    }
    return Ok<Json, SchemaError>(Json.FromObject(children));
  }

  let sequence = value.AsSeq();
  if sequence != nil {
    let items = sequence as YamlSeq;
    var children = Array<Json>.New();
    var i: int32 = 0;
    while i < items.Len() {
      let child = self.ConvertYaml(items.Get(i) as Yaml, location.Instance(i.ToString()), depth + 1);
      if child.IsErr() {
        return child;
      }
      children.Push(child.get_if<Json>() as Json);
      i += 1;
    }
    return Ok<Json, SchemaError>(Json.FromArray(children));
  }

  let text = value.AsStr();
  if text != nil {
    return Ok<Json, SchemaError>(Json.FromStr(text as string));
  }
  let number = value.AsInt();
  if number != nil {
    return Ok<Json, SchemaError>(Json.FromInt(number as int64));
  }
  let boolean = value.AsBool();
  if boolean != nil {
    return Ok<Json, SchemaError>(Json.FromBool(boolean as bool));
  }

  return Ok<Json, SchemaError>(Json{});
}
