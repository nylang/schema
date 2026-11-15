// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of DocumentSchema;

/** A reader and its current handle remain within the synchronous schema walk. */
struct SchemaValue {
  readonly reader: SchemaReader;
  readonly handle: uintptr;
}

static method(SchemaValue) Root(reader: SchemaReader) -> SchemaValue {
  return SchemaValue{reader: reader, handle: reader.Root()};
}

method(SchemaValue) Kind() -> SchemaKind {
  return (self.reader).Kind(self.handle);
}

method(SchemaValue) Scalar() -> SchemaScalar {
  return (self.reader).Scalar(self.handle);
}

method(SchemaValue) Len() -> int32 {
  return (self.reader).Len(self.handle);
}

method(SchemaValue) KeyAt(index: int32) -> string {
  return (self.reader).KeyAt(self.handle, index);
}

method(SchemaValue) ValueAt(index: int32) -> SchemaValue {
  return SchemaValue{reader: self.reader, handle: (self.reader).ChildAt(self.handle, index)};
}

method(SchemaValue) Get(key: string) -> SchemaValue? {
  var i: int32 = 0;
  let length = self.Len();
  while i < length {
    if self.KeyAt(i) == key {
      return self.ValueAt(i);
    }

    i += 1;
  }

  return nil;
}

method(SchemaValue) AsBool() -> bool? {
  if self.Kind() == SchemaKind.Boolean {
    return self.Scalar().boolean;
  }

  return nil;
}

method(SchemaValue) AsNumber() -> string? {
  if self.Kind() == SchemaKind.Number {
    return self.Scalar().text;
  }

  return nil;
}

method(SchemaValue) AsUInt64() -> uint64? {
  if self.Kind() == SchemaKind.Number {
    return self.Scalar().count;
  }

  return nil;
}

method(SchemaValue) AsStr() -> string? {
  if self.Kind() == SchemaKind.String {
    return self.Scalar().text;
  }

  return nil;
}

method(SchemaValue) AsObject() -> SchemaValue? {
  if self.Kind() == SchemaKind.Object {
    return self;
  }

  return nil;
}

method(SchemaValue) AsArray() -> SchemaValue? {
  if self.Kind() == SchemaKind.Array {
    return self;
  }

  return nil;
}
