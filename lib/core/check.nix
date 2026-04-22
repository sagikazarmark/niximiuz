# Tiny helpers for writing readable manifest validators.
#
# Usage:
#   let c = check "mkTutorial"; in
#   c.kind m "tutorial";
#   c.nonEmptyString m "name";
#   c.string m "title";
#   m
#
# Each helper throws on failure with a clear "<context>: <field> <reason>"
# message and returns `true` on success (so they compose via `assert`).
{
  check = context: {
    # Assert m ? kind and m.kind == expected
    kind =
      m: expected:
      let
        prefix = "${context}: manifest.kind";
      in
      if !(m ? kind) then
        throw "${prefix} is required"
      else if !(builtins.isString m.kind) then
        throw "${prefix} must be a string"
      else if m.kind != expected then
        throw ''${prefix} must be "${expected}" (got "${m.kind}")''
      else
        true;

    # Assert m ? field and m.<field> is a non-empty string.
    nonEmptyString =
      m: field:
      let
        prefix = "${context}: manifest.${field}";
      in
      if !(m ? ${field}) then
        throw "${prefix} is required"
      else if !(builtins.isString m.${field}) then
        throw "${prefix} must be a string"
      else if m.${field} == "" then
        throw "${prefix} must not be empty"
      else
        true;

    # Assert m ? field and m.<field> is a string (empty OK).
    string =
      m: field:
      let
        prefix = "${context}: manifest.${field}";
      in
      if !(m ? ${field}) then
        throw "${prefix} is required"
      else if !(builtins.isString m.${field}) then
        throw "${prefix} must be a string"
      else
        true;

    # Assert m ? field and m.<field> is an attrset.
    attrs =
      m: field:
      let
        prefix = "${context}: manifest.${field}";
      in
      if !(m ? ${field}) then
        throw "${prefix} is required"
      else if !(builtins.isAttrs m.${field}) then
        throw "${prefix} must be an attrset"
      else
        true;

    # If m has the field, assert it's a string. Absent = OK.
    optionalString =
      m: field:
      let
        prefix = "${context}: manifest.${field}";
      in
      if !(m ? ${field}) then
        true
      else if !(builtins.isString m.${field}) then
        throw "${prefix} must be a string if present"
      else
        true;
  };
}
