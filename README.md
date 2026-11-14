# JSON and YAML document schemas

Import `schema:schema.ny` from a package that declares `schema` as a dependency.
Declare a Git dependency with the URL `https://github.com/nylang/schema.git`
and an explicit revision, then run `nyra lock` and `nyra fetch --frozen`.
Use the `json` and `yaml` packages to parse the schema and instance documents.
The package uses the hosted Nyra SDK 1.1.2 runtime.

```nyra
import "stdlib:stdlib.ny";
import "json:json.ny";
import "yaml:yaml.ny";
import "schema:schema.ny";

func validate_config(rule: JsonDocument, config: YamlDocument) -> Result<Unit, SchemaError> {
  let compiled = Schema.Compile(rule.Root());
  if compiled.IsErr() {
    return Err<Unit, SchemaError>(compiled.get_if<SchemaError>() as SchemaError);
  }

  let schema = compiled.get_if<Schema>() as Schema;
  return schema.ValidateYaml(config.Root());
}
```

Call `Schema.Compile(json_document.Root())` or
`Schema.CompileYaml(yaml_document.Root())` once and reuse the admitted value.
Call `Validate` for a JSON instance and `ValidateYaml` for a YAML instance.
Keep the schema's durable allocator and its callback context alive for the
lifetime of the admitted value. YAML validation uses the types exposed by the
YAML DOM. Quoted scalars remain strings and numeric scalars are limited to the
parser's signed 64-bit integers.

A failure reports its category, a diagnostic message and two JSON Pointer
paths. `instance_path` identifies the failing value or the expected location
of a missing property. `schema_path` identifies the applicable schema rule.
An empty path identifies the root.

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
