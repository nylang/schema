# Format-independent document schema

`schema` provides a reusable validation engine for the common document data
model. It uses the matching hosted Nyra SDK runtime. JSON and YAML applications
can use the `JsonSchema` and `YamlSchema` entry points in their respective
codec packages.

A new format integrates by implementing `SchemaReader` and importing
`schema:schema.ny`. Readers supply stable, nonzero handles for nodes, report
array elements and string-keyed object entries in document order, and expose
exact decimal representations for numbers. The `count` field identifies a
nonnegative integer node representable as `uint64`.

Call `Schema.Compile(reader)` to admit a rule and take an owned snapshot.
The rule document and reader may be released after compilation. Reuse the
resulting `Schema` with `Validate(reader)` to inspect another document.
Validation reads the existing instance tree synchronously, visits only the
nodes required by the rules, and retains neither the reader nor its handles.
A reader must keep its underlying storage unchanged until the call returns.

A failure reports its category, a diagnostic message and two JSON Pointer
paths. `instance_path` identifies the failing value or the expected location
of a missing property. `schema_path` identifies the applicable rule. An empty
path identifies the root.

## Scalar constraints for other schema dialects

Import `schema:scalar.ny` for exact decimal ordering and scalar bounds. A
format admits and normalizes its own values before creating a `SchemaDecimal`.
JSON-compatible numbers supply significant digits and a decimal point position.
XSD decimals and integers supply their normalized integral and fractional
parts. Both use the same comparison, including comparisons of signed zero and
equivalent spellings with trailing zeroes.

`SchemaBound` checks an ordering or a size supplied by the caller. The caller
selects the units, applies whitespace and type rules, and owns its diagnostics.

## Supported Draft 2020-12 rules

- Boolean schemas, `type` and type unions.
- `properties`, `required`, `additionalProperties`, `minProperties` and
  `maxProperties`.
- `items`, `minItems` and `maxItems`.
- `minLength` and `maxLength`, measured in Unicode code points.
- `const`, `enum`, `minimum`, `maximum`, `exclusiveMinimum` and
  `exclusiveMaximum`. Numeric comparisons use decimal values without
  rounding to floating point.
- `allOf`, `anyOf`, `oneOf` and `not`.
- `$defs` and local `$ref` to a direct root definition with the
  `#/$defs/<name>` spelling. Escape `~` and `/` in the name as `~0` and
  `~1`.
- The root `$schema` URI for Draft 2020-12, plus the annotations `title`,
  `description`, `$comment` and `default`.

Admission checks the shape of every subschema. Unknown keywords such as
`format` and `pattern`, as well as remote references, yield
`UnsupportedKeyword`. Count and length bounds use nonnegative JSON integer
literals representable as `uint64`. Each traversal has a depth and visit
budget. Numeric comparisons that require a nonzero decimal exponent with
more than 18 significant digits also yield `LimitExceeded`.

The compiled-rule snapshot also has a depth and node budget. This bounds
storage for value literals and annotations as well as nested rules.

## Migration from v0.1.0

The existing v0.1.0 tag retains the old JSON/YAML-dependent API. Applications
moving to v0.2.0 can use `JsonSchema.Compile` or `YamlSchema.Compile`, then
`Validate` on the corresponding adapter. To reuse a compiled rule across
formats, pass `Compiled()` to the other adapter's `FromCompiled` method.

Run the standalone suite with `nyrac test .`. The same suite exercises a
reader without importing either codec.
