# MATAM Car System — Agent Context

**Read this first before touching the code.** This file is meant to be fed
to a coding AI agent (Gemini, Claude, Cursor, Copilot, etc.) so it can
be productive immediately.

---

## 1. What the app does

MATAM is an in-house **car dealership management system** for a small
Israeli used-car business. It replaces spreadsheet workflows with a
web app that runs on the dealership's own PC (self-hosted, no cloud).

Core capabilities:
- Vehicle inventory (open cars for sale)
- Sales pipeline: purchase → pricing → sale → archive
- Financial tracking per vehicle: costs, profit, payments
- Leads (customer interest) with matching against inventory
- Accounting (payments to former owners, VAT, customer payments)
- Multi-user with role-based permissions (agent / manager)
- Real-time updates across concurrent browsers on the LAN
- Hebrew (RTL) UI throughout

Users: 3–10 concurrent, mixed manager + agent roles.

---

## 2. Tech stack (deliberately minimal)

| Layer | Choice | Where |
|---|---|---|
| Frontend | **Plain HTML + vanilla JavaScript + Tailwind CSS via CDN** | `pb_public/index.html` |
| Backend | **PocketBase 0.39.7** (single Go binary + SQLite) | `pocketbase.exe` |
| DB | SQLite via PocketBase | `pb_data/data.db` |
| Auth | PocketBase built-in auth (email + password, JWT) | Same |
| Realtime | PocketBase Server-Sent Events subscription | Same |
| Icons | Font Awesome 6 via CDN | index.html `<head>` |
| Excel I/O | SheetJS (xlsx) via CDN | index.html `<head>` |
| PB SDK | `pocketbase.umd.js` via CDN | index.html `<head>` |

**There is no build step.** No webpack, no npm, no bundler. Edit the
`.html` file and refresh the browser. This is intentional so any dev
(or their AI) can trivially modify it.

RTL/Hebrew is handled at the HTML level (`dir="rtl"` on `<body>`) and by
Tailwind logical properties. All user-facing strings are in Hebrew.

---

## 3. File map

```
matam_server/                          # Root install folder
├── pocketbase.exe                     # Server binary (downloaded from GitHub)
├── pb_data/                           # SQLite DB, uploaded files, WAL
├── pb_public/
│   └── index.html                     # THE ENTIRE FRONTEND. Single file. 4600 lines.
├── deploy/                            # Ops scripts (not touched during feature work)
│   ├── collections_schema.json        # Full DB schema (source of truth for the model)
│   ├── initial_users.json             # Bootstrap admin account
│   ├── setup_schema.ps1               # Applies schema.json to a fresh PB instance
│   ├── install_server.cmd             # One-click server installer
│   ├── enable_firewall.cmd            # Windows firewall rule
│   ├── ...                            # Other operational helpers
│   ├── README_SERVER.md               # Ops guide
│   ├── INSTALLATION_GUIDE.md          # End-user install guide
│   └── AGENT_CONTEXT.md               # This file
└── start_pocketbase.cmd               # Manual start
```

**When adding a feature, you almost only ever touch `pb_public/index.html`.**
The backend schema is edited via the PocketBase admin UI or by editing
`collections_schema.json` and re-applying it.

---

## 4. Data model (PocketBase collections)

### `users` (auth collection)
Standard PocketBase auth + these custom fields:
- `role` — select: `"agent"` | `"manager"` (managers = admin)
- `displayName` — Hebrew display name shown in UI

Access rules: everyone can `list`/`view` their own record; managers can
CRUD any user.

### `vehicles` (base) — the main inventory
Fields grouped by purpose:
- **Identity**: `license` (unique index), `model`, `year`, `month`, `color`, `km`, `hands`, `ownership`, `orderNumber`
- **Deal state**: `status`, `customer`, `agentName`, `datePurchase`, `testDate`
- **Pricing**: `basePrice`, `kmAdd`, `handsAdd`, `warrantyAdd`, `calcPrice` (weighted), `improvementCost`, `miscellaneous`, `targetPrice`, `salePrice`, `depreciationPct`, `payDepreciation`
- **Payments**: `payUnion`, `statusUnion`, `payCustomer`, `statusCustomer`, `payLicensing`
- **Disclosure/legal**: `disclosureText`
- **Attachments**: `inspectionFile`, `insuranceFile`, `licenseFile` (json blobs with `{ name, base64 }`)
- **Autodate**: `created`, `updated`

### `archive` (base) — sold/closed deals
Reduced schema — most `vehicles` fields plus `saleDate`, `archivedDate`.

### `leads` (base) — customer inquiries
- `name`, `phone`, `email`, `interest`, `status`, `agentName`, `notes`, `createdAt`

**Rule of thumb**: If you add a field to `vehicles`, you almost certainly
also need to add it to `archive` (so the record survives sale) and to
the client-side `recToPb` / `pbToRec` mappers in index.html.

---

## 5. Client-side architecture inside `pb_public/index.html`

The file has this order:

```
Lines 1 – 200        <head>: CDN links, styles, meta
Lines 200 – 2000     <body>: all UI (tabs, tables, modals) as static HTML
Lines 2000 – 4600    <script>: all JavaScript
```

### State model (in memory)

```javascript
window.pb            // PocketBase SDK client (singleton)
window.currentUser   // Currently logged-in user (from pb.authStore.model)
window.db.vehicles   // Array of vehicle records (mirror of server)
window.db.archive    // Array of archived records
window.db.leads      // Array of lead records
window.db.users      // Array of user records (managers only)
window.pbRefreshOk   // Flag: false until first successful server load;
                     // used to gate sync writes so we never overwrite
                     // server state with a stale/empty local view
```

### Key functions and their roles

**Auth & session**
- `handleUserLogin(email, password)` — logs in via `pb.collection('users').authWithPassword`
- `handleUserLogout()` — clears auth, resets state
- `attemptSessionRestore()` — on load, re-validates the JWT and refreshes user
- `evalSessionUIState()` — shows/hides `.admin-only-element` and other role gates

**Data lifecycle**
- `refreshFromPB()` — full pull of vehicles + archive + leads from server; sets `pbRefreshOk = true` on success
- `syncCollection(name, records)` — batched push of local changes; uses a queue with optimistic locking
- `subscribeToRealtime()` / `unsubscribeFromRealtime()` — server push for concurrent updates
- `handleRealtime(e)` — merges a single server event (create/update/delete) into local state
- `healLostPbIds()` — re-links local records to server records if a `pb_id` was lost (e.g., after browser storage clear)

**Adapter layer (critical!)**
- `recToPb(rec)` — converts a client record to the PB row shape
- `pbToRec(row)` — converts a PB row back to a client record (this is where you map new fields)

Both must be kept in sync with the schema. **When adding a field, edit
both mappers.**

**UI rendering (all pure functions of state)**
- `renderInventoryTable()` — main vehicles grid
- `renderArchiveTable()` — sold cars
- `renderLeadsTable()`
- `renderAccountingTable()` — payments
- `renderBrandBreakdown()` — dashboard chart data
- `refreshDashboardKPIs()`
- `renderUsersTable(users)` — managers only

**Tabs**
- `switchTab(tabId)` — hides all `.tab-content` sections, shows the given one; also triggers per-tab data loads (e.g., loads users when switching to `settings-tab`)
- Valid tab IDs: `dashboard-tab`, `inventory-tab`, `archive-tab`, `leads-tab`, `accounting-tab`

**Business rules**
- `recalculatePricingModel(vehicle)` — computes `calcPrice` from km/hands/warranty/base; called on any pricing input change
- `applySuggestedPrice(vehicle)` — populates the target price field
- `checkMatchingLeadsForCar(vehicle)` — cross-references new inventory against open leads
- `checkMatchingVehiclesForLead(lead)` — reverse of above
- `commitDownpaymentModalValues()` — writes a paid deposit into the vehicle record

**User management (managers only)**
- `loadUsers()`, `renderUsersTable(users)`
- `openAddUserModal()`, `openEditUserModal(id)`, `closeUserModal()`
- `submitUserModal()` — creates or updates, hits PB `users` collection
- `deleteUser(id)`

---

## 6. Cookbook — how to make common changes

### 6.1 Add a new field to `vehicles` (e.g. `licensePlateType`)

1. **Schema**: add to `deploy/collections_schema.json` under the
   `vehicles` fields array, matching PocketBase field format. Apply
   with `deploy/setup_schema.ps1` **or** add via the admin UI at
   `http://<server>:8090/_/`.
2. **Adapter**: in `pb_public/index.html`, add the field to both
   `recToPb()` and `pbToRec()`.
3. **UI — car edit modal**: find the `id="car-form-modal"` block, add
   an `<input>` for the field with `id="car-modal-<field>"`.
4. **UI — save handler**: find `saveCarForm()`, add the field to the
   record object it builds.
5. **UI — table column** (optional): if it should appear in the
   inventory grid, add a `<th>` and a `<td>` in
   `renderInventoryTable()`.
6. **Archive**: if the field should survive sale, mirror the schema
   change into the `archive` collection too, and update the
   sale-to-archive migration in `saveCarForm()` (search for
   `restoreFromArchive` and its counterpart).

### 6.2 Add a new tab

1. Add a `<button data-tab="foo-tab" ...>` to the main nav bar.
2. Add a `<section id="foo-tab" class="tab-content hidden">...</section>` block.
3. Add a case in `switchTab()` if the tab needs data-load side effects.
4. Add an entry in `evalSessionUIState()` if the tab is role-gated
   (add class `admin-only-element` to the tab button/section).

### 6.3 Add a new user role

The `role` field is a PocketBase `select` — extend it:

1. Edit `deploy/collections_schema.json` → `users.role.values`, add
   e.g. `"viewer"`. Re-apply schema.
2. Update `openEditUserModal` and `submitUserModal` to include the
   new option in the dropdown.
3. Add role checks throughout the app. Pattern:
   `if (currentUser?.role === 'manager') { ... }` — extend to your
   new role as needed.
4. Update PocketBase **collection rules** in the admin UI to grant
   or restrict permissions for the new role. This is enforced
   server-side and cannot be bypassed by client code.

### 6.4 Call an LLM / external API from the app

The app already has one hook: `triggerPricePrediction()`. Follow that
pattern:

1. Add a button in the relevant modal.
2. Add an `async function myAiCall(vehicle)` that does
   `fetch('https://your-endpoint', { method:'POST', body: JSON.stringify(...) })`.
3. Show a spinner via `showToast('...', 'info')` while pending.
4. On response, mutate the vehicle object and call
   `renderInventoryTable()` + `syncCollection('vehicles', ...)`.

**Security note**: Do NOT hardcode API keys in `index.html` — this
file is served publicly by PocketBase. Instead:
- Use PocketBase custom routes (JS hooks in `pb_hooks/`, see
  https://pocketbase.io/docs/js-overview) to proxy the API call.
- The client calls the local PB proxy; PB adds the secret key.

---

## 7. Non-obvious pitfalls (things that will bite you)

### 7.1 **NEVER overwrite `pb_id` on save**
Client records carry a `pb_id` property with the server ID. If you're
updating an existing record, that ID **must** be preserved. Losing it
causes duplicate rows on the server. The healing function
`healLostPbIds()` exists specifically to recover from this bug.
Pattern:

```javascript
const existing = window.db.vehicles.find(v => v.license === newLicense);
const record = { ...existing, ...newFields, pb_id: existing?.pb_id };
```

### 7.2 **Sort by `-created` needs the `autodate` field**
PocketBase 0.23+ rejects `sort=-created` unless the collection has an
explicit `created` field of type `autodate`. Our schema already has
this. If you add a new collection, remember to add `created` and
`updated` as `autodate` type — otherwise `getFullList({sort:'-created'})`
throws.

### 7.3 **Hebrew + UTF-8**
Never write server bodies without explicit UTF-8. In PowerShell scripts
we use a custom `PbRest` wrapper that force-encodes. In JavaScript,
`fetch` and the PB SDK are already UTF-8. In batch files (.cmd), use
`chcp 65001` before echoing Hebrew.

### 7.4 **Realtime + local writes race**
If the local user saves a vehicle and immediately the realtime
subscription pushes back the same change, `handleRealtime` might
overwrite in-flight local state. The current implementation dedupes by
`pb_id` and by `updated` timestamp. Read `handleRealtime` carefully
before changing it.

### 7.5 **CDN dependencies**
Tailwind, Font Awesome, SheetJS, and PocketBase SDK all load from
CDNs. On a network without internet (e.g. dealership Wi-Fi outage),
the app UI degrades severely. For production hardening, download and
bundle these locally into `pb_public/vendor/`.

### 7.6 **Manager-only element hiding is CSS-only**
Class `.admin-only-element` gets `display:none` for non-managers via
`evalSessionUIState()`. This is UI-only — the real access control is
in PocketBase **collection rules** on the server. Do not rely on the
CSS hiding for security.

---

## 8. Running locally for development

**Prerequisites:** Windows 10/11, PowerShell, ~50MB disk.

**Fresh setup (one-time):**

```powershell
# Extract the delivered install_matam.ps1 to a dev folder
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install_matam.ps1 -InstallDir C:\dev\matam
```

That gives you a running PocketBase on `http://127.0.0.1:8090/` with
a bootstrap admin `admin@matam.local` / `matam2026`.

**Development loop:**

1. Edit `C:\dev\matam\pb_public\index.html` in your editor
2. Refresh browser at `http://127.0.0.1:8090/`
3. That's it. No build, no restart of PocketBase needed for frontend changes
4. Backend schema changes → PocketBase admin UI at `http://127.0.0.1:8090/_/`
   or re-run `setup_schema.ps1`

**Seed data:**
- Use the "Import Excel" button in the Inventory tab
- Or use the PocketBase admin UI to add rows directly
- Or hit `loadPredefinedMockData()` from the browser DevTools console

**Reset dev DB:**
Stop PocketBase (`taskkill /IM pocketbase.exe /F`), delete `pb_data\`,
re-run `install_server.cmd`.

**Live-view DB:**
The PocketBase admin at `/_/` is a full DB browser — no external tool
needed.

---

## 9. What NOT to change without a design discussion

- The `vehicles.license` uniqueness constraint. Removing it will
  cause duplicate cars to enter inventory.
- The sync queue / optimistic locking logic in `syncCollection` and
  `runOneSyncPass`. It's subtle and race conditions bit us hard
  before.
- The `pbRefreshOk` gate. Removing it will corrupt the server DB the
  first time a user opens the app on an offline browser.
- The password hashing. It's PocketBase-managed; don't try to
  intercept.
- The Hebrew RTL direction on `<body>`. Individual English strings
  can use `<span dir="ltr">` inline.

---

## 10. Verification checklist before shipping a change

- [ ] Frontend renders without console errors (open DevTools)
- [ ] Login as manager still works
- [ ] Login as agent (create one via User Management first) still works
- [ ] Add a new vehicle → refresh → it's still there (sync worked)
- [ ] Edit a vehicle → refresh → **no duplicate row** (`pb_id` preserved)
- [ ] Log in from a second browser → change in browser A appears in browser B within 2s (realtime)
- [ ] Excel import still works (try `select01.xlsx` if available)
- [ ] Hebrew displays correctly (not `????`) in all new UI elements

---

## 11. Where to look when stuck

| Symptom | Likely file / area |
|---|---|
| Login fails with correct password | `handleUserLogin`, PocketBase admin → users collection rules |
| Data not saving | `saveCarForm`, `syncCollection`, `runOneSyncPass`, browser console |
| Duplicate vehicles appearing | `pb_id` was lost — see `healLostPbIds` |
| Empty tables after login | `refreshFromPB` failed — check `pbRefreshOk` and `showPbBanner` |
| Field not showing up | `recToPb` / `pbToRec` mapper mismatch |
| Manager tab visible to agent | `evalSessionUIState`, `.admin-only-element` class missing |
| Realtime not updating | `subscribeToRealtime`, PocketBase server logs |
| Import Excel silently skips rows | `importExcelData` / `importArchiveExcelData` header keyword matching |

PocketBase server logs live at `pb_data/logs.db` (SQLite, viewable in
admin UI). Frontend logs are in the browser DevTools console.
