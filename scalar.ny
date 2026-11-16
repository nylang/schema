// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief Shared scalar comparison and bounds for document schema dialects. */
module DocumentSchemaScalars;

export "interface/scalar.ni";
import "interface/scalar.ni";
import "stdlib:stdlib.ny";

pub struct SchemaDecimal {
  readonly sign: int32;
  readonly point: int64;
  readonly head: string;
  readonly tail: string;
}

pub static method(SchemaDecimal) FromDigits(
  digits: ref string, point: int64, {negative: bool = false}
) -> SchemaDecimal {
  if digits.length == 0 {
    return SchemaDecimal{};
  }

  return SchemaDecimal{sign: negative ? -1 : 1, point: point, head: digits};
}

pub static method(SchemaDecimal) FromParts(
  whole: ref string, fraction: ref string, {negative: bool = false}
) -> SchemaDecimal {
  if whole.length > 0 {
    return SchemaDecimal{
      sign: negative ? -1 : 1, point: whole.length as int64, head: whole, tail: fraction
    };
  }

  var leading: int32 = 0;
  while leading < fraction.length && fraction.ByteAt(leading) == 48 {
    leading += 1;
  }

  return SchemaDecimal.FromDigits(fraction.View(leading, fraction.length - leading),
    -(leading as int64), negative: negative);
}

method(SchemaDecimal) DigitAt(index: int64) -> int32 {
  let head_length = self.head.length as int64;
  if index < head_length {
    return self.head.ByteAt(index as int32);
  }

  let tail_index = index - head_length;
  return tail_index < (self.tail.length as int64) ? self.tail.ByteAt(tail_index as int32) : 48;
}

pub method(SchemaDecimal) Compare(other: ref SchemaDecimal) -> int32 {
  if self.sign != other.sign {
    return self.sign < other.sign ? -1 : 1;
  }

  if self.sign == 0 {
    return 0;
  }

  if self.point != other.point {
    return self.point < other.point ? -self.sign : self.sign;
  }

  var index: int64 = 0;
  if self.head.length == other.head.length {
    let order = self.head.Compare(other.head);
    if order != 0 {
      return order * self.sign;
    }

    if self.tail.length == other.tail.length {
      return self.tail.Compare(other.tail) * self.sign;
    }

    index = self.head.length as int64;
  }

  // Different spellings can omit any number of insignificant trailing zeroes.
  let left_length = (self.head.length as int64) + (self.tail.length as int64);
  let right_length = (other.head.length as int64) + (other.tail.length as int64);
  while index < left_length || index < right_length {
    let left = self.DigitAt(index);
    let right = other.DigitAt(index);
    if left != right {
      return left < right ? -self.sign : self.sign;
    }

    index += 1i64;
  }

  return 0;
}

pub method(SchemaBound) AllowsOrder(order: int32) -> bool {
  if self == SchemaBound.Equal {
    return order == 0;
  }

  if self == SchemaBound.AtLeast {
    return order >= 0;
  }

  if self == SchemaBound.AtMost {
    return order <= 0;
  }

  return self == SchemaBound.GreaterThan ? order > 0 : order < 0;
}

pub method(SchemaBound) AllowsSize(size: uint64, bound: uint64) -> bool {
  return self.AllowsOrder(size < bound ? -1 : (size > bound ? 1 : 0));
}
