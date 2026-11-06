# Shared values

Placement follows one rule, the application's: a value one root needs lives in that root; a
value several roots of an environment agree on lives in that environment's `shared/`; the
derivation both environments share lives in `modules/`. Roots cannot read each other's state,
so `live/<env>/shared` is a module with no provider and no state that each root of the
environment calls, and `modules/naming` is where the environment name and the zone become
the resource prefix, the API hostname (`api.stg.frubble.ai`, `api.dev.frubble.ai`), the osiris hostname (`osiris.stg.frubble.ai`, `osiris.dev.frubble.ai`) and the sending domain
(`stg.frubble.ai`, `dev.frubble.ai`: a subdomain per environment, never the apex). Nothing in them is secret, and a change to
`shared/` is in scope for every plan of that environment. What crosses between roots is only
what one root *produces* and another needs, and it crosses as a handoff object (crossing-roots.md), never as a repository variable.
