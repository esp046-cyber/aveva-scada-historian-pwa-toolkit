# AGC SCADA Ops — AVEVA Companion PWA

Field-ready companion dashboard and toolkit for AVEVA SCADA, System Platform, and AVEVA
Historian, built for **Al Gurg Automation & Controls**, Dubai, UAE.

---

## 1. What's in this repo

| Area | Location | Purpose |
|---|---|---|
| Historian SQL scripts | `database/` | Retrieval, alarms/events, manual telemetry insert, daily maintenance |
| PWA architecture | `src/app/api/**`, `src/lib/` | Next.js Edge/Node bridge between Historian SQL/REST and the browser |
| Frontend (Industrial Glassmorphism) | `src/app`, `src/components` | Dark-mode SCADA dashboard shell |
| Icons | `src/components/icons` | Inline SVG SCADA + social icon sets |
| Offline-first | `public/sw.js`, `public/manifest.json` | Service worker, IndexedDB outbox, installable manifest |
| Realtime transport | `src/app/api/stream/route.ts`, `server.js` | SSE (Edge) + optional WebSocket bridge |

## 2. Architecture — Edge to Cloud

```
┌────────────────────┐        ┌──────────────────────────┐        ┌────────────────────┐
│ AVEVA System        │  OPC/  │ SQL Server + AVEVA         │  TDS   │ Next.js API routes   │
│ Platform / SCADA     │ DAS    │ Historian (Runtime DB)      │  1433  │ (Node runtime, mssql) │
│ field controllers    │───────▶│ + AGC_App staging DB        │───────▶│ /api/historian/*      │
└────────────────────┘        │ + database/*.sql procs      │        │ /api/telemetry/log     │
                                └──────────────────────────┘        └─────────┬──────────────┘
                                                                                │
                                                            SSE (Edge runtime) │ WebSocket (server.js)
                                                                                ▼
                                                                    ┌────────────────────┐
                                                                    │ Next.js App Router    │
                                                                    │ PWA — Service Worker,  │
                                                                    │ IndexedDB outbox,       │
                                                                    │ offline-first caching   │
                                                                    └────────────────────┘
                                                                                │
                                                                     installed on field
                                                                     tablets / desktops
```

- **Retrieval path**: browser → `/api/historian/history` or `/api/historian/alarms` (Node
  runtime, since `mssql` needs Node sockets) → stored procedures in `database/`.
- **Realtime path**: `/api/stream` runs on the **Edge runtime** as Server-Sent Events so it
  survives corporate proxies on remote UAE site VPNs that block WebSocket upgrades. For sites
  that need bidirectional operator actions (alarm ack round-trips), run `npm run start:ws`
  instead of `npm start` to use the WebSocket bridge in `server.js`.
- **Offline-first**: `public/sw.js` applies cache-first to the app shell and
  stale-while-revalidate to `/api/historian/*` reads, so the dashboard still renders the last
  known telemetry with zero signal at a remote pump station. Manual telemetry POSTs that fail
  offline are queued in IndexedDB and flushed via Background Sync on reconnect.
- **Recommended stack**: Next.js 15 (App Router), TypeScript, Tailwind CSS, `mssql` driver
  direct to the Historian Runtime DB, Vercel Edge Functions (or any Node 20+ host) for the
  read/write API routes, and a small Node worker (or SQL Agent + `server.js`) for Historian
  promotion of staged rows.

## 3. Database setup

Run these against your SQL Server instance, in order:

```sql
:r database/04_sql_maintenance.sql   -- creates AGC_App + usp_RunDailyMaintenance
:r database/01_sp_get_tag_history.sql
:r database/02_sp_get_alarms_events.sql
:r database/03_sp_insert_telemetry_log.sql
```

Then register the daily maintenance job (uncomment the `sp_add_job` block at the bottom of
`04_sql_maintenance.sql`).

## 4. Running the app

```bash
npm install
cp .env.example .env.local     # fill in your Historian SQL credentials
npm run dev                    # http://localhost:3000, SSE realtime
# or, for the WebSocket bridge with operator ack round-trips:
npm run build && npm run start:ws
```

## 5. Design system — Industrial Glassmorphism

- **Palette**: gunmetal `#0A0E12` canvas, graphite `#131A21` panels, steel-line `#1F2A33`
  borders, cyan `#2DE1E8` (live telemetry), amber `#FFB020` (warning), crimson `#FF3B4E`
  (critical alarm).
- **Type**: IBM Plex Sans for UI chrome, IBM Plex Mono for every numeric readout — the two
  faces let an operator tell "label" from "live value" at a glance, the way a real HMI does.
- **Layout**: fixed top status strip, left icon nav rail, and a schematic-grid canvas
  (subtle blueprint gridlines) carrying frosted glass panels — deliberately modeled on a
  control-room HMI client rather than a generic SaaS card grid.

## 6. Directory tree

```
aveva-algurg-pwa/
├── database/
│   ├── 01_sp_get_tag_history.sql
│   ├── 02_sp_get_alarms_events.sql
│   ├── 03_sp_insert_telemetry_log.sql
│   └── 04_sql_maintenance.sql
├── public/
│   ├── manifest.json
│   └── sw.js
├── src/
│   ├── app/
│   │   ├── api/
│   │   │   ├── health/route.ts
│   │   │   ├── historian/alarms/route.ts
│   │   │   ├── historian/history/route.ts
│   │   │   ├── stream/route.ts
│   │   │   └── telemetry/log/route.ts
│   │   ├── globals.css
│   │   ├── layout.tsx
│   │   └── page.tsx
│   ├── components/
│   │   ├── icons/ScadaIcons.tsx
│   │   ├── icons/SocialIcons.tsx
│   │   ├── AlarmPanel.tsx
│   │   ├── DashboardLayout.tsx
│   │   ├── Footer.tsx
│   │   ├── NavRail.tsx
│   │   ├── StatusBar.tsx
│   │   └── TelemetryPanel.tsx
│   └── lib/
│       ├── db.ts
│       ├── historianApi.ts
│       └── websocket.ts
├── .env.example
├── .gitignore
├── next.config.js
├── package.json
├── postcss.config.js
├── server.js
├── tailwind.config.js
└── tsconfig.json
```

## 7. Deploying to GitHub

```bash
cd aveva-algurg-pwa
git init
git add .
git commit -m "Initial commit: AGC SCADA Ops PWA"
git branch -M main
git remote add origin https://github.com/<your-org>/aveva-algurg-pwa.git
git push -u origin main
```

---
Internal engineering tool — Al Gurg Automation & Controls, Dubai, UAE.
