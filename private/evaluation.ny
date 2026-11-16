// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of DocumentSchema;

method(SchemaWalk) Evaluate(
  value: SchemaValue, rule: SchemaValue, location: SchemaLocation, depth: int32
) -> SchemaError? {
  let limit = self.Visit(location, depth);
  if limit != nil {
    return limit;
  }

  let allow = rule.AsBool();
  if allow != nil {
    if !(allow as bool) {
      return location.Error(SchemaErrorKind.Violation, "rejected by a false schema");
    }
    return nil;
  }

  let rules = rule.AsObject() as SchemaValue;
  var i: int32 = 0;
  while i < rules.Len() {
    let name = rules.KeyAt(i);
    let constraint = rules.ValueAt(i);
    let failure = self.ApplyKeyword(value, rules, name, constraint, location, depth);
    if failure != nil {
      return failure;
    }
    i += 1;
  }

  return nil;
}

method(SchemaWalk) ApplyKeyword(
  value: SchemaValue, rules: SchemaValue, name: string, constraint: SchemaValue,
  location: SchemaLocation, depth: int32
) -> SchemaError? {
  let position = location.Rule(name);
  if name == "type" {
    if !matches_type(value, constraint) {
      return position.Error(SchemaErrorKind.Violation, "value does not match the declared type");
    }
  } else if name == "$ref" {
    let reference = constraint.AsStr() as string;
    let target = self.Definition(reference) as SchemaValue;
    let target_location = SchemaLocation{instance: location.instance, rule: reference.Slice(1, reference.length)};
    return self.Evaluate(value, target, target_location, depth + 1);
  } else if name == "properties" || name == "required" || name == "additionalProperties" {
    let object = value.AsObject();
    if object != nil {
      return self.ApplyObjectKeyword(object as SchemaValue, rules, name, constraint, position, depth);
    }
  } else if name == "items" {
    let array = value.AsArray();
    if array != nil {
      let items = array as SchemaValue;
      var i: int32 = 0;
      while i < items.Len() {
        let failure = self.Evaluate(items.ValueAt(i), constraint, position.Instance(i.ToString()), depth + 1);
        if failure != nil {
          return failure;
        }
        i += 1;
      }
    }
  } else if name == "minItems" || name == "maxItems" || name == "minProperties" ||
      name == "maxProperties" || name == "minLength" || name == "maxLength" {
    return check_size(value, name, constraint.AsUInt64() as uint64, position);
  } else if name == "minimum" || name == "maximum" || name == "exclusiveMinimum" ||
      name == "exclusiveMaximum" {
    return check_numeric_bound(value, constraint, name, position);
  } else if name == "enum" || name == "const" {
    return self.EvaluateValues(value, constraint, name, position, depth);
  } else if name == "allOf" || name == "anyOf" || name == "oneOf" {
    return self.EvaluateBranches(value, constraint.AsArray() as SchemaValue, name, position, depth);
  } else if name == "not" {
    let outcome = self.Evaluate(value, constraint, position, depth + 1);
    if outcome == nil {
      return position.Error(SchemaErrorKind.Violation, "value matches an excluded schema");
    }
    if (outcome as SchemaError).kind != SchemaErrorKind.Violation {
      return outcome;
    }
  }

  return nil;
}

method(SchemaWalk) ApplyObjectKeyword(
  value: SchemaValue, rules: SchemaValue, name: string, constraint: SchemaValue,
  position: SchemaLocation, depth: int32
) -> SchemaError? {
  if name == "required" {
    let keys = constraint.AsArray() as SchemaValue;
    var i: int32 = 0;
    while i < keys.Len() {
      let key = (keys.ValueAt(i)).AsStr() as string;
      if value.Get(key) == nil {
        return position.Rule(i.ToString()).Instance(key).Error(
          SchemaErrorKind.Violation, "required property is missing"
        );
      }
      i += 1;
    }
  } else if name == "properties" {
    let properties = constraint.AsObject() as SchemaValue;
    var i: int32 = 0;
    while i < properties.Len() {
      let key = properties.KeyAt(i);
      let member = value.Get(key);
      if member != nil {
        let failure = self.Evaluate(
          member as SchemaValue, properties.ValueAt(i), position.Rule(key).Instance(key), depth + 1
        );
        if failure != nil {
          return failure;
        }
      }
      i += 1;
    }
  } else {
    let properties = rules.Get("properties");
    var i: int32 = 0;
    while i < value.Len() {
      let key = value.KeyAt(i);
      if properties == nil || ((properties as SchemaValue).AsObject() as SchemaValue).Get(key) == nil {
        let failure = self.Evaluate(value.ValueAt(i), constraint, position.Instance(key), depth + 1);
        if failure != nil {
          return failure;
        }
      }
      i += 1;
    }
  }

  return nil;
}

method(SchemaWalk) EvaluateBranches(
  value: SchemaValue, children: SchemaValue, keyword: string, position: SchemaLocation, depth: int32
) -> SchemaError? {
  var matched: bool = false;
  var i: int32 = 0;
  while i < children.Len() {
    let outcome = self.Evaluate(value, children.ValueAt(i), position.Rule(i.ToString()), depth + 1);
    if outcome != nil {
      if keyword == "allOf" || (outcome as SchemaError).kind != SchemaErrorKind.Violation {
        return outcome;
      }
    } else {
      if keyword == "anyOf" {
        return nil;
      }
      if keyword == "oneOf" && matched {
        return position.Error(SchemaErrorKind.Violation, "value matches more than one branch");
      }
      matched = true;
    }
    i += 1;
  }

  if keyword != "allOf" && !matched {
    return position.Error(SchemaErrorKind.Violation, "value matches no branch");
  }

  return nil;
}

// Bounds on container size and Unicode text length apply only to their own instance type.
func check_size(value: SchemaValue, name: string, bound: uint64, position: SchemaLocation) -> SchemaError? {
  var length: int32 = 0;
  if name == "minItems" || name == "maxItems" {
    let array = value.AsArray();
    if array == nil {
      return nil;
    }
    length = (array as SchemaValue).Len();
  } else if name == "minProperties" || name == "maxProperties" {
    let object = value.AsObject();
    if object == nil {
      return nil;
    }
    length = (object as SchemaValue).Len();
  } else {
    let text = value.AsStr();
    if text == nil {
      return nil;
    }
    length = (text as string).Utf8Count();
  }

  if length < 0 {
    return position.Error(SchemaErrorKind.InvalidDocument, "expected a valid UTF-8 string");
  }

  let size = length as uint64;
  let predicate = name.StartsWith("min") ? SchemaBound.AtLeast : SchemaBound.AtMost;
  if !predicate.AllowsSize(size, bound) {
    return position.Error(SchemaErrorKind.Violation, "value size is outside the allowed bound");
  }

  return nil;
}

func matches_type(value: SchemaValue, rule: SchemaValue) -> bool {
  let name = rule.AsStr();
  if name != nil {
    return matches_type_name(value, name as string);
  }

  let choices = rule.AsArray() as SchemaValue;
  var i: int32 = 0;
  while i < choices.Len() {
    if matches_type_name(value, (choices.ValueAt(i)).AsStr() as string) {
      return true;
    }
    i += 1;
  }

  return false;
}

func matches_type_name(value: SchemaValue, name: string) -> bool {
  if name == "null" {
    return value.Kind() == SchemaKind.Null;
  }
  if name == "boolean" {
    return value.AsBool() != nil;
  }
  if name == "object" {
    return value.AsObject() != nil;
  }
  if name == "array" {
    return value.AsArray() != nil;
  }
  if name == "string" {
    return value.AsStr() != nil;
  }
  let raw = value.AsNumber();
  return raw != nil && (name == "number" || is_integer_lexeme(raw as string));
}

// JSON Schema treats mathematically integral decimals and exponent forms as integers.
func is_integer_lexeme(raw: string) -> bool {
  var i: int32 = 0;
  var fraction: int64 = 0;
  var trailing_zeros: int64 = 0;
  var has_nonzero: bool = false;
  var after_dot: bool = false;
  while i < raw.length {
    let byte = raw.ByteAt(i);
    if byte == 101 || byte == 69 {
      break;
    }
    if byte == 46 {
      after_dot = true;
    } else if byte >= 48 && byte <= 57 {
      if after_dot {
        fraction += 1i64;
      }
      if byte == 48 {
        trailing_zeros += 1i64;
      } else {
        has_nonzero = true;
        trailing_zeros = 0;
      }
    }
    i += 1;
  }

  if !has_nonzero {
    return true;
  }

  var exponent: int64 = 0;
  if i < raw.length {
    i += 1;
    let sign = raw.ByteAt(i);
    if sign == 43 || sign == 45 {
      i += 1;
    }
    // Once this exceeds the longest possible mantissa, the exact exponent is immaterial.
    while i < raw.length && exponent <= 2147483647i64 {
      exponent = exponent * 10i64 + ((raw.ByteAt(i) - 48) as int64);
      i += 1;
    }
    if sign == 45 {
      exponent = -exponent;
    }
  }

  return fraction - trailing_zeros <= exponent;
}
