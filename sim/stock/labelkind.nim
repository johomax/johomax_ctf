type LabelKind* = enum
  lkOther,
  lkStock

proc classify*(label: string): LabelKind =
  ## The stock bot scans dynamic labels and prefixes, so retain all families.
  lkStock
