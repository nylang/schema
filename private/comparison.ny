// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of DocumentSchema;

// JSON number readers have already admitted the lexical form and its exponent.
static method(SchemaDecimal) Parse(raw: string) -> SchemaDecimal? {
  let negative = raw.ByteAt(0) == 45;
  var i: int32 = negative ? 1 : 0;
  var whole: int32 = 0;
  var leading: int32 = 0;
  var has_digit: bool = false;
  var before_point: bool = true;
  var digits = StringBuffer.New();
  while i < raw.length {
    let byte = raw.ByteAt(i);
    if byte == 101 || byte == 69 {
      break;
    }
    if byte == 46 {
      before_point = false;
    } else {
      if before_point {
        whole += 1;
      }
      has_digit = has_digit || byte != 48;
      if has_digit {
        digits.Append(raw.View(i, 1));
      } else {
        leading += 1;
      }
    }
    i += 1;
  }

  if !has_digit {
    return SchemaDecimal{};
  }

  var exponent: int64 = 0;
  if i < raw.length {
    i += 1;
    let marker = raw.ByteAt(i);
    if marker == 43 || marker == 45 {
      i += 1;
    }
    while i < raw.length {
      // Leave headroom for the next digit and the mantissa's decimal-point offset.
      if exponent > 99999999999999999i64 {
        return nil;
      }
      exponent = exponent * 10i64 + ((raw.ByteAt(i) - 48) as int64);
      i += 1;
    }
    if marker == 45 {
      exponent = -exponent;
    }
  }

  return SchemaDecimal.FromDigits(digits.Take(), exponent + (whole as int64) - (leading as int64),
    negative: negative);
}

method(SchemaWalk) Equal(
  value: ref SchemaValue, expected: ref SchemaValue, position: SchemaLocation, depth: int32
) -> Result<bool, SchemaError> {
  let limit = self.Visit(position, depth);
  if limit != nil {
    return Err<bool, SchemaError>(limit as SchemaError);
  }

  let number = value.AsNumber();
  if number != nil {
    let other = expected.AsNumber();
    if other == nil {
      return Ok<bool, SchemaError>(false);
    }
    let order = compare_numbers(number as string, other as string, position);
    if order.IsErr() {
      return Err<bool, SchemaError>(order.get_if<SchemaError>() as SchemaError);
    }

    return Ok<bool, SchemaError>((order.get_if<int32>() as int32) == 0);
  }

  let array = value.AsArray();
  if array != nil {
    let other = expected.AsArray();
    if other == nil {
      return Ok<bool, SchemaError>(false);
    }

    let items = array as SchemaValue;
    let wanted = other as SchemaValue;
    if items.Len() != wanted.Len() {
      return Ok<bool, SchemaError>(false);
    }
    var i: int32 = 0;
    while i < items.Len() {
      let item = items.ValueAt(i);
      let target = wanted.ValueAt(i);
      let result = self.Equal(item, target, position.Instance(i.ToString()), depth + 1);
      if result.IsErr() || !(result.get_if<bool>() as bool) {
        return result;
      }
      i += 1;
    }

    return Ok<bool, SchemaError>(true);
  }

  let object = value.AsObject();
  if object != nil {
    let other = expected.AsObject();
    if other == nil {
      return Ok<bool, SchemaError>(false);
    }

    let entries = object as SchemaValue;
    let wanted = other as SchemaValue;
    if entries.Len() != wanted.Len() {
      return Ok<bool, SchemaError>(false);
    }
    var i: int32 = 0;
    while i < entries.Len() {
      let key = entries.KeyAt(i);
      let target = wanted.Get(key);
      if target == nil {
        return Ok<bool, SchemaError>(false);
      }
      let member = entries.ValueAt(i);
      let other_member = target as SchemaValue;
      let result = self.Equal(member, other_member, position.Instance(key), depth + 1);
      if result.IsErr() || !(result.get_if<bool>() as bool) {
        return result;
      }
      i += 1;
    }

    return Ok<bool, SchemaError>(true);
  }

  let kind = value.Kind();
  if kind != expected.Kind() {
    return Ok<bool, SchemaError>(false);
  }

  if kind == SchemaKind.Null {
    return Ok<bool, SchemaError>(true);
  }

  let left = value.Scalar();
  let right = expected.Scalar();
  if kind == SchemaKind.Boolean {
    return Ok<bool, SchemaError>(left.boolean == right.boolean);
  }

  return Ok<bool, SchemaError>(left.text == right.text);
}

method(SchemaWalk) EvaluateValues(
  value: ref SchemaValue, constraint: ref SchemaValue, name: string, position: SchemaLocation, depth: int32
) -> SchemaError? {
  if name == "const" {
    let result = self.Equal(value, constraint, position, depth + 1);
    if result.IsErr() {
      return result.get_if<SchemaError>();
    }
    if !(result.get_if<bool>() as bool) {
      return position.Error(SchemaErrorKind.Violation, "value differs from const");
    }
    return nil;
  }

  let choices = constraint.AsArray() as SchemaValue;
  var i: int32 = 0;
  while i < choices.Len() {
    let choice = choices.ValueAt(i);
    let result = self.Equal(value, choice, position.Rule(i.ToString()), depth + 1);
    if result.IsErr() {
      return result.get_if<SchemaError>();
    }
    if result.get_if<bool>() as bool {
      return nil;
    }
    i += 1;
  }

  return position.Error(SchemaErrorKind.Violation, "value is absent from enum");
}

func compare_numbers(a: string, b: string, position: SchemaLocation) -> Result<int32, SchemaError> {
  if a == b {
    return Ok<int32, SchemaError>(0);
  }

  let left = SchemaDecimal.Parse(a);
  let right = SchemaDecimal.Parse(b);
  if left == nil || right == nil {
    return Err<int32, SchemaError>(
      position.Error(SchemaErrorKind.LimitExceeded, "numeric comparison exponent exceeds 18 digits")
    );
  }

  let lhs = left as SchemaDecimal;
  let rhs = right as SchemaDecimal;

  return Ok<int32, SchemaError>(lhs.Compare(rhs));
}

func check_numeric_bound(
  value: ref SchemaValue, rule: ref SchemaValue, name: string, position: SchemaLocation
) -> SchemaError? {
  let raw = value.AsNumber();
  if raw == nil {
    return nil;
  }

  let result = compare_numbers(raw as string, rule.AsNumber() as string, position);
  if result.IsErr() {
    return result.get_if<SchemaError>();
  }

  let order = result.get_if<int32>() as int32;
  let bound = name == "minimum" ? SchemaBound.AtLeast :
    (name == "maximum" ? SchemaBound.AtMost :
      (name == "exclusiveMinimum" ? SchemaBound.GreaterThan : SchemaBound.LessThan));
  if !bound.AllowsOrder(order) {
    return position.Error(SchemaErrorKind.Violation, "number is outside the allowed bound");
  }

  return nil;
}
