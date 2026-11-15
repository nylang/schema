// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of DocumentSchema;

struct SchemaRuleChild {
  key: string;
  handle: uintptr;
}

struct SchemaRuleNode {
  kind: SchemaKind;
  scalar: SchemaScalar;
  children: Array<SchemaRuleChild>;
}

/** The snapshot owns its strings and uses one-based indices as stable handles. */
struct SchemaRules implements SchemaReader {
  nodes: Array<SchemaRuleNode>;
}

@override
method(SchemaRules) Root() -> uintptr {
  return self.nodes.Len() as uintptr;
}

@override
method(SchemaRules) Kind(node: uintptr) -> SchemaKind {
  return self.nodes.Get((node - 1up) as int32).kind;
}

@override
method(SchemaRules) Scalar(node: uintptr) -> SchemaScalar {
  return self.nodes.Get((node - 1up) as int32).scalar;
}

@override
method(SchemaRules) Len(node: uintptr) -> int32 {
  return self.nodes.Get((node - 1up) as int32).children.Len();
}

@override
method(SchemaRules) KeyAt(node: uintptr, index: int32) -> string {
  return self.nodes.Get((node - 1up) as int32).children.Get(index).key;
}

@override
method(SchemaRules) ChildAt(node: uintptr, index: int32) -> uintptr {
  return self.nodes.Get((node - 1up) as int32).children.Get(index).handle;
}

method(SchemaRules) Capture(
  value: SchemaValue, location: SchemaLocation, depth: int32
) -> Result<uintptr, SchemaError> {
  // Member containers add levels between the subschemas counted by admission.
  if depth > 2 * kSchemaDepthLimit + 1 || self.nodes.Len() + depth >= kSchemaVisitLimit {
    return Err<uintptr, SchemaError>(
      location.Error(SchemaErrorKind.LimitExceeded, "schema snapshot limit exceeded")
    );
  }

  if value.handle == 0up {
    return Err<uintptr, SchemaError>(location.Error(SchemaErrorKind.InvalidSchema, "schema child is missing"));
  }

  let kind = value.Kind();
  var stored = SchemaRuleNode{kind: kind};
  if kind == SchemaKind.Array || kind == SchemaKind.Object {
    stored.children = Array<SchemaRuleChild>.New();
    var i: int32 = 0;
    let length = value.Len();
    while i < length {
      let key = kind == SchemaKind.Object ? value.KeyAt(i) : i.ToString();
      let child = self.Capture(value.ValueAt(i), location.Rule(key), depth + 1);
      if child.IsErr() {
        return child;
      }

      stored.children.Push(SchemaRuleChild{key: copy(key), handle: child.get_if<uintptr>() as uintptr});
      i += 1;
    }
  } else {
    let scalar = value.Scalar();
    stored.scalar = SchemaScalar{text: copy(scalar.text), boolean: scalar.boolean, count: scalar.count};
  }

  self.nodes.Push(move(stored));
  return Ok<uintptr, SchemaError>(self.nodes.Len() as uintptr);
}
