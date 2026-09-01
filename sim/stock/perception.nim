## Compatibility shim: sim/host.nim imports `perception` from every tree it
## hosts (the BR walkability fallback lives there in bot/baseline). The stock
## adapter has no such module and no fallback; `host.nim` guards the call with
## `when compiles(...)`, so an empty module is all the import needs.
