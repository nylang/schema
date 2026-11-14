// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

import "stdlib:stdlib.ny";
import "json:json.ny";
import "yaml:yaml.ny";

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

/** @brief An admitted schema that retains its JSON tree for reuse. */
pub struct Schema;

/** @brief Admit a JSON Schema object or boolean before validating documents.
 * @param rule Parsed schema tree. Its durable allocator must outlive the schema.
 * @returns An admitted schema or a diagnostic describing the first invalid or unsupported rule. */
pub static method(Schema) Compile(rule: Json) -> Result<Schema, SchemaError>;

/** @brief Admit a YAML schema using the same rules and scalar types as YAML validation.
 * @param rule Parsed YAML schema, expressed as a mapping or boolean.
 * @returns An admitted schema or the first conversion or admission failure. */
pub static method(Schema) CompileYaml(rule: Yaml) -> Result<Schema, SchemaError>;

/** @brief Apply the admitted schema to one JSON value.
 * @param value Parsed JSON value, including scalar or container roots.
 * @returns Unit on success or the first violation with instance and schema paths. */
pub method(Schema) Validate(value: Json) -> Result<Unit, SchemaError>;

/** @brief Apply the same schema to one YAML value using its parsed scalar types.
 * @param value Parsed YAML value. Quoted numbers remain strings.
 * @returns Unit on success or the first conversion or validation failure. */
pub method(Schema) ValidateYaml(value: Yaml) -> Result<Unit, SchemaError>;
