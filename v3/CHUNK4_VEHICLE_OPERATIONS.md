# V3 Chunk 4 — Vehicle + Operations

Status: BUILDING
Owners: Vehicle + Operations
Consumes: Core identity/persistence contracts; Driver truth only as independent coexistence evidence

## User-confirmed invariant
Changing the driver's **current** truck/combination must never rewrite which truck/combination was used by a **past** operation.

## Ownership
- Vehicle owns physical vehicle/combination identity and configuration truth.
- Operations owns Drive, Stop, Load, Unload, Transfer, Wait, Maintenance and Incident activity history.
- Driver remains the sole owner of work/rest truth.
- Cargo/Fuel remains deferred to Chunk 5; operation kinds do not own transported-product quantities.

## Historical model
An Operation captures an immutable `VehicleCombinationSnapshot`. A later current-vehicle selection/configuration creates new present/future truth; it does not retroactively alter an earlier operation's snapshot.

## Gate
1. Drive/Stop lifecycle exists independently of Driver work/rest.
2. An operation preserves the vehicle combination used at occurrence time.
3. A materially different second vehicle fixture attaches without Driver or Operations redesign.
4. Changing current vehicle leaves past operations unchanged.
5. Operations and captured Vehicle history survive Codable replay/relaunch.
6. Driver truth remains unchanged by Vehicle/Operations actions.

## Non-goals
- Fuel/cargo compartments, quantities, DG or cargo mass.
- Regulatory work/rest interpretation.
- Replacing Chunk 2 distance/ODO evidence rules.
- Full production UI.
