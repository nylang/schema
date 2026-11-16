// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief Exact ordering of decimal values after a format admits their lexical form. */
pub struct SchemaDecimal;

/** @brief Construct a decimal from significant ASCII digits and a decimal point position.
 * @note Digits omit leading zeroes, and empty digits represent zero. The point position
 *       is measured from the first significant digit and may be negative. */
pub static method(SchemaDecimal) FromDigits(digits: ref string, point: int64, {negative: bool = false}) -> SchemaDecimal;

/** @brief Construct a decimal from validated unsigned integral and fractional digit strings.
 * @note The integral part omits leading zeroes. Empty parts represent zero. */
pub static method(SchemaDecimal) FromParts(whole: ref string, fraction: ref string, {negative: bool = false}) -> SchemaDecimal;

/** @brief Compare exact numeric values, including equivalent spellings and signed zero. */
pub method(SchemaDecimal) Compare(other: ref SchemaDecimal) -> int32;

/** @brief A bound on an ordered scalar value or an already measured size. */
pub enum SchemaBound {
  Equal,
  AtLeast,
  AtMost,
  GreaterThan,
  LessThan
}

/** @brief Check a signed comparison of the instance value with the required bound. */
pub method(SchemaBound) AllowsOrder(order: int32) -> bool;

/** @brief Check counts in the units selected by the caller. */
pub method(SchemaBound) AllowsSize(size: uint64, bound: uint64) -> bool;
