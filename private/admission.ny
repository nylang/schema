// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of DocumentSchema;

method(SchemaWalk) Admit(rule: Json, location: SchemaLocation, depth: int32) -> SchemaError? {
  let limit = self.Visit(location, depth);
  if limit != nil {
    return limit;
  }

  if rule.AsBool() != nil {
    return nil;
  }

  let object = rule.AsObject();
  if object == nil {
    return location.Error(SchemaErrorKind.InvalidSchema, "expected an object or boolean schema");
  }

  let entries = object as JsonObject;
  var i: int32 = 0;
  while i < entries.Len() {
    let name = entries.KeyAt(i) as string;
    let child = entries.ValueAt(i) as Json;
    let failure = self.AdmitKeyword(name, child, location.Rule(name), depth);
    if failure != nil {
      return failure;
    }
    i += 1;
  }

  return nil;
}

method(SchemaWalk) AdmitKeyword(
  name: string, rule: Json, location: SchemaLocation, depth: int32
) -> SchemaError? {
  if name == "$schema" {
    let dialect = rule.AsStr();
    if dialect == nil || (dialect as string) != "https://json-schema.org/draft/2020-12/schema" {
      return location.Error(SchemaErrorKind.InvalidSchema, "expected the Draft 2020-12 dialect URI");
    }
    if depth != 0 {
      return location.Error(SchemaErrorKind.UnsupportedKeyword, "nested dialect declarations are unsupported");
    }
  } else if name == "$ref" {
    let text = rule.AsStr();
    if text == nil {
      return location.Error(SchemaErrorKind.InvalidSchema, "expected a reference string");
    }
    let reference = text as string;
    if !reference.StartsWith("#/$defs/") {
      return location.Error(SchemaErrorKind.UnsupportedKeyword, "expected a reference to a root $defs entry");
    }
    if self.Definition(reference) == nil {
      return location.Error(SchemaErrorKind.InvalidSchema, "unknown schema reference");
    }
  } else if name == "properties" || name == "$defs" {
    let entries = rule.AsObject();
    if entries == nil {
      return location.Error(SchemaErrorKind.InvalidSchema, "expected an object of schemas");
    }
    let members = entries as JsonObject;
    var i: int32 = 0;
    while i < members.Len() {
      let key = members.KeyAt(i) as string;
      let failure = self.Admit(members.ValueAt(i) as Json, location.Rule(key), depth + 1);
      if failure != nil {
        return failure;
      }
      i += 1;
    }
  } else if name == "items" || name == "additionalProperties" || name == "not" {
    return self.Admit(rule, location, depth + 1);
  } else if name == "allOf" || name == "anyOf" || name == "oneOf" {
    let array = rule.AsArray();
    if array == nil || (array as JsonArray).Len() == 0 {
      return location.Error(SchemaErrorKind.InvalidSchema, "expected a nonempty array of schemas");
    }
    let children = array as JsonArray;
    var i: int32 = 0;
    while i < children.Len() {
      let failure = self.Admit(children.Get(i) as Json, location.Rule(i.ToString()), depth + 1);
      if failure != nil {
        return failure;
      }
      i += 1;
    }
  } else if name == "type" || name == "required" {
    return self.AdmitNames(name, rule, location);
  } else if name == "enum" {
    let choices = rule.AsArray();
    if choices == nil || (choices as JsonArray).Len() == 0 {
      return location.Error(SchemaErrorKind.InvalidSchema, "expected a nonempty array of values");
    }
  } else if name == "minimum" || name == "maximum" || name == "exclusiveMinimum" ||
      name == "exclusiveMaximum" {
    if rule.AsNumber() == nil {
      return location.Error(SchemaErrorKind.InvalidSchema, "expected a numeric bound");
    }
  } else if name == "minItems" || name == "maxItems" || name == "minProperties" ||
      name == "maxProperties" || name == "minLength" || name == "maxLength" {
    if rule.AsUInt64() == nil {
      return location.Error(SchemaErrorKind.InvalidSchema, "expected a nonnegative integer count");
    }
  } else if name == "title" || name == "description" || name == "$comment" {
    if rule.AsStr() == nil {
      return location.Error(SchemaErrorKind.InvalidSchema, "expected a string annotation");
    }
  } else if name != "default" && name != "const" {
    return location.Error(SchemaErrorKind.UnsupportedKeyword, "unsupported schema keyword");
  }

  return nil;
}

method(SchemaWalk) AdmitNames(keyword: string, rule: Json, location: SchemaLocation) -> SchemaError? {
  let is_type = keyword == "type";
  let name = rule.AsStr();
  if is_type && name != nil {
    if !is_type_name(name as string) {
      return location.Error(SchemaErrorKind.InvalidSchema, "unknown type name");
    }
    return nil;
  }

  let list = rule.AsArray();
  if list == nil {
    return location.Error(SchemaErrorKind.InvalidSchema, "expected an array of names");
  }

  let names = list as JsonArray;
  if is_type && names.Len() == 0 {
    return location.Error(SchemaErrorKind.InvalidSchema, "type array must be nonempty");
  }

  var seen = HashMap<string, int32>.New();
  var i: int32 = 0;
  while i < names.Len() {
    let entry = (names.Get(i) as Json).AsStr();
    let position = location.Rule(i.ToString());
    if entry == nil || (is_type && !is_type_name(entry as string)) {
      return position.Error(SchemaErrorKind.InvalidSchema, "invalid name");
    }
    let text = entry as string;
    if seen.TryGet(text) != nil {
      return position.Error(SchemaErrorKind.InvalidSchema, "duplicate name");
    }
    seen.Put(text, i);
    i += 1;
  }

  return nil;
}

// These are the seven instance type names defined by JSON Schema.
func is_type_name(name: string) -> bool {
  return name == "null" || name == "boolean" || name == "object" || name == "array" ||
    name == "string" || name == "integer" || name == "number";
}
