// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

import "stdlib:stdlib.ny";

/** @brief Result categories for schema admission and document validation. */
pub enum SchemaErrorKind {
  InvalidSchema,
  UnsupportedKeyword,
  InvalidDocument,
  Violation,
  LimitExceeded
}

/** @brief First failure, with JSON Pointer paths relative to the two roots. */
pub struct SchemaError {
  kind: SchemaErrorKind;
  instance_path: string;
  schema_path: string;
  message: string;
}

/** @brief Kinds in the common document data model. Objects have string keys. */
pub enum SchemaKind {
  Null,
  Boolean,
  Number,
  String,
  Array,
  Object
}

/** @brief Scalar content supplied by a reader.
 * @note Use text for strings and exact JSON-compatible decimal lexemes. Set
 *       count for nonnegative integer nodes representable as uint64. */
pub struct SchemaScalar {
  text: string;
  boolean: bool;
  count: uint64?;
}

/** @brief Read-only navigation over a live document.
 * @note Handles are reader-local. Zero denotes an absent root or child. Node
 *       handles and returned string views must remain valid during the call.
 *       Len describes array elements or object entries in document order.
 *       ChildAt must return a valid handle for every index in that range. */
pub interface SchemaReader {
  Root() -> uintptr;
  Kind(node: uintptr) -> SchemaKind;
  Scalar(node: uintptr) -> SchemaScalar;
  Len(node: uintptr) -> int32;
  KeyAt(node: uintptr, index: int32) -> string;
  ChildAt(node: uintptr, index: int32) -> uintptr;
}

/** @brief Owns the admitted rules for reuse with any reader. */
pub struct Schema;

/** @brief Snapshot and admit rules in the supported JSON Schema Draft 2020-12 subset.
 * @note All retained rule data is owned by the compiled schema. */
pub static method(Schema) Compile(rule: SchemaReader) -> Result<Schema, SchemaError>;

/** @brief Validate a document by reading the supplied view synchronously.
 * @returns Unit on success or the first failure with instance and rule paths. */
pub method(Schema) Validate(value: SchemaReader) -> Result<Unit, SchemaError>;
