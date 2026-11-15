// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief Admits reusable schema trees and evaluates them against document values.
 * @note Schema owns the admitted snapshot. A validation borrows a reader for the call. */
module DocumentSchema;
part "admission.ny";
part "evaluation.ny";
part "comparison.ny";
part "reader.ny";
part "rules.ny";
import "stdlib:stdlib.ny";
import "interface/schema.ni";

/** @brief An admitted document schema. */
pub struct Schema {
  readonly rules: SchemaRules;
}

constexpr kSchemaDepthLimit: int32 = 128;
constexpr kSchemaVisitLimit: int32 = 100000;

struct SchemaWalk {
  readonly root: SchemaValue;
  visits: int32;
}

struct SchemaLocation {
  instance: string;
  rule: string;
}

pub static method(Schema) Compile(rule: SchemaReader) -> Result<Schema, SchemaError> {
  let location = SchemaLocation{};
  let root = SchemaValue.Root(rule);
  if root.handle == 0up {
    return Err<Schema, SchemaError>(location.Error(SchemaErrorKind.InvalidSchema, "schema root is missing"));
  }

  var walk = SchemaWalk{root: root};
  let failure = walk.Admit(root, location, 0);
  if failure != nil {
    return Err<Schema, SchemaError>(failure as SchemaError);
  }

  var snapshot = SchemaRules{nodes: Array<SchemaRuleNode>.New()};
  let copied = snapshot.Capture(root, location, 0);
  if copied.IsErr() {
    return Err<Schema, SchemaError>(copied.get_if<SchemaError>() as SchemaError);
  }

  return Ok<Schema, SchemaError>(Schema{rules: move(snapshot)});
}

pub method(Schema) Validate(value: SchemaReader) -> Result<Unit, SchemaError> {
  let location = SchemaLocation{};
  if self.rules.nodes.Len() == 0 {
    return Err<Unit, SchemaError>(
      location.Error(SchemaErrorKind.InvalidSchema, "Schema.Compile must succeed before validation")
    );
  }

  let instance = SchemaValue.Root(value);
  if instance.handle == 0up {
    return Err<Unit, SchemaError>(location.Error(SchemaErrorKind.InvalidDocument, "document root is missing"));
  }

  let rules: SchemaRules = self.rules;
  let root = SchemaValue.Root(rules);
  var walk = SchemaWalk{root: root};
  let failure = walk.Evaluate(instance, root, location, 0);
  if failure != nil {
    return Err<Unit, SchemaError>(failure as SchemaError);
  }

  return Ok<Unit, SchemaError>(UnitValue());
}

method(SchemaWalk) Visit(location: SchemaLocation, depth: int32) -> SchemaError? {
  self.visits += 1;
  if self.visits > kSchemaVisitLimit || depth > kSchemaDepthLimit {
    return location.Error(SchemaErrorKind.LimitExceeded, "schema traversal limit exceeded");
  }

  return nil;
}

method(SchemaLocation) Rule(key: string) -> SchemaLocation {
  return SchemaLocation{instance: self.instance, rule: append_pointer(self.rule, key)};
}

method(SchemaLocation) Instance(key: string) -> SchemaLocation {
  return SchemaLocation{instance: append_pointer(self.instance, key), rule: self.rule};
}

method(SchemaLocation) Error(kind: SchemaErrorKind, message: string) -> SchemaError {
  return SchemaError{
    kind: kind, instance_path: self.instance, schema_path: self.rule, message: message
  };
}

// JSON Pointer encodes the two reserved bytes inside a token.
func append_pointer(path: string, key: string) -> string {
  var out = StringBuffer.New();
  out.Append(path);
  out.Append("/");
  var start: int32 = 0;
  var i: int32 = 0;
  while i < key.length {
    let byte = key.ByteAt(i);
    if byte == 126 || byte == 47 {
      out.Append(key.View(start, i - start));
      if byte == 126 {
        out.Append("~0");
      } else {
        out.Append("~1");
      }
      start = i + 1;
    }
    i += 1;
  }
  out.Append(key.View(start, key.length - start));

  return out.Take();
}

method(SchemaWalk) Definition(reference: string) -> SchemaValue? {
  let root = self.root.AsObject();
  if root == nil {
    return nil;
  }

  let defs = (root as SchemaValue).Get("$defs");
  if defs == nil {
    return nil;
  }

  let definitions = (defs as SchemaValue).AsObject();
  if definitions == nil {
    return nil;
  }

  let entries = definitions as SchemaValue;
  var i: int32 = 0;
  while i < entries.Len() {
    let name = entries.KeyAt(i);
    if append_pointer("#/$defs", name) == reference {
      return entries.ValueAt(i);
    }
    i += 1;
  }

  return nil;
}
