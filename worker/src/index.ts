import { Hono } from "hono";
import { bearerAuth } from "hono/bearer-auth";

type Bindings = {
  DB: D1Database;
  API_TOKEN: string;
};

type PushItem = {
  id: string;
  data: unknown;
  last_modified: string;
};

type PushRequest = {
  device_id: string;
  items: PushItem[];
};

const MAX_BATCH_SIZE = 500;

// Hardcoded SQL per entity to avoid any table-name injection risk.
// Each key maps to the full set of prepared statements needed.
type EntitySQL = {
  upsert: string;
  selectPage: string;
  softDelete: string;
  purgeDeleted: string;
};

const ENTITY_SQL: Record<string, EntitySQL> = {
  reminders: {
    upsert: `INSERT INTO reminders (id, data, last_modified, updated_at, source_device)
      VALUES (?1, ?2, ?3, datetime('now'), ?4)
      ON CONFLICT(id) DO UPDATE SET
        data = excluded.data, last_modified = excluded.last_modified,
        deleted = 0, updated_at = datetime('now'), source_device = excluded.source_device
      WHERE reminders.last_modified <= excluded.last_modified`,
    selectPage:
      "SELECT id, data, deleted, updated_at, last_modified FROM reminders WHERE (updated_at > ?1 OR (updated_at = ?1 AND id > ?2)) ORDER BY updated_at ASC, id ASC LIMIT ?3",
    softDelete:
      "UPDATE reminders SET deleted = 1, updated_at = datetime('now') WHERE id = ? AND last_modified <= ?",
    purgeDeleted:
      "DELETE FROM reminders WHERE deleted = 1 AND updated_at < datetime('now', '-30 days')",
  },
  calendar_events: {
    upsert: `INSERT INTO calendar_events (id, data, last_modified, updated_at, source_device)
      VALUES (?1, ?2, ?3, datetime('now'), ?4)
      ON CONFLICT(id) DO UPDATE SET
        data = excluded.data, last_modified = excluded.last_modified,
        deleted = 0, updated_at = datetime('now'), source_device = excluded.source_device
      WHERE calendar_events.last_modified <= excluded.last_modified`,
    selectPage:
      "SELECT id, data, deleted, updated_at, last_modified FROM calendar_events WHERE (updated_at > ?1 OR (updated_at = ?1 AND id > ?2)) ORDER BY updated_at ASC, id ASC LIMIT ?3",
    softDelete:
      "UPDATE calendar_events SET deleted = 1, updated_at = datetime('now') WHERE id = ? AND last_modified <= ?",
    purgeDeleted:
      "DELETE FROM calendar_events WHERE deleted = 1 AND updated_at < datetime('now', '-30 days')",
  },
  reminder_lists: {
    upsert: `INSERT INTO reminder_lists (id, data, last_modified, updated_at, source_device)
      VALUES (?1, ?2, ?3, datetime('now'), ?4)
      ON CONFLICT(id) DO UPDATE SET
        data = excluded.data, last_modified = excluded.last_modified,
        deleted = 0, updated_at = datetime('now'), source_device = excluded.source_device
      WHERE reminder_lists.last_modified <= excluded.last_modified`,
    selectPage:
      "SELECT id, data, deleted, updated_at, last_modified FROM reminder_lists WHERE (updated_at > ?1 OR (updated_at = ?1 AND id > ?2)) ORDER BY updated_at ASC, id ASC LIMIT ?3",
    softDelete:
      "UPDATE reminder_lists SET deleted = 1, updated_at = datetime('now') WHERE id = ? AND last_modified <= ?",
    purgeDeleted:
      "DELETE FROM reminder_lists WHERE deleted = 1 AND updated_at < datetime('now', '-30 days')",
  },
};

const ENTITY_NAMES = Object.keys(ENTITY_SQL);

function getSQL(entity: string): EntitySQL | null {
  return ENTITY_SQL[entity] ?? null;
}

// Normalize ISO 8601 timestamps to UTC for consistent string comparison.
// Accepts formats like "2026-03-10T14:00:00Z", "2026-03-10T14:00:00+08:00",
// or bare "2026-03-10 14:00:00" (treated as UTC).
function normalizeTimestamp(ts: string): string {
  const d = new Date(ts);
  if (isNaN(d.getTime())) {
    return ts;
  }
  return d.toISOString();
}

const app = new Hono<{ Bindings: Bindings }>();

// Auth middleware for all /api/* routes
app.use("/api/*", async (c, next) => {
  const auth = bearerAuth({ token: c.env.API_TOKEN });
  return auth(c, next);
});

// Health check (no auth required)
app.get("/health", (c) => c.json({ status: "ok" }));

// Push: batch upsert with last-write-wins
app.post("/api/v1/:entity/push", async (c) => {
  const sql = getSQL(c.req.param("entity"));
  if (!sql) {
    return c.json({ error: "Invalid entity" }, 400);
  }

  const body = await c.req.json<PushRequest>();
  const { device_id, items } = body;

  if (!device_id || !Array.isArray(items)) {
    return c.json({ error: "Missing device_id or items" }, 400);
  }

  if (items.length === 0) {
    return c.json({ synced: 0, skipped: 0 });
  }

  if (items.length > MAX_BATCH_SIZE) {
    return c.json(
      { error: `Batch size ${items.length} exceeds maximum of ${MAX_BATCH_SIZE}` },
      400
    );
  }

  // Atomic upsert: INSERT ... ON CONFLICT with last_modified guard
  const stmts = items.map((item) => {
    const normalizedLM = normalizeTimestamp(item.last_modified);
    return c.env.DB.prepare(sql.upsert).bind(
      item.id,
      JSON.stringify(item.data),
      normalizedLM,
      device_id
    );
  });

  const results = await c.env.DB.batch(stmts);
  const synced = results.reduce((n, r) => n + (r.meta.changes ?? 0), 0);

  return c.json({ synced, skipped: items.length - synced });
});

// Pull: incremental cursor-based fetch using composite (updated_at, id) cursor
app.get("/api/v1/:entity/pull", async (c) => {
  const sql = getSQL(c.req.param("entity"));
  if (!sql) {
    return c.json({ error: "Invalid entity" }, 400);
  }

  const rawCursor = c.req.query("cursor") ?? "";
  const limit = 101; // fetch one extra to detect has_more

  let cursorTime: string;
  let cursorId: string;

  if (rawCursor.includes("|")) {
    [cursorTime, cursorId] = rawCursor.split("|", 2);
  } else {
    cursorTime = rawCursor || "1970-01-01T00:00:00";
    cursorId = "";
  }

  const { results } = await c.env.DB.prepare(sql.selectPage)
    .bind(cursorTime, cursorId, limit)
    .all<{
      id: string;
      data: string;
      deleted: number;
      updated_at: string;
      last_modified: string;
    }>();

  const hasMore = results.length === limit;
  const page = hasMore ? results.slice(0, limit - 1) : results;

  const items = page.map((row) => ({
    id: row.id,
    data: JSON.parse(row.data),
    deleted: row.deleted === 1,
    updated_at: row.updated_at,
    last_modified: row.last_modified,
  }));

  const last = page[page.length - 1];
  const newCursor = last ? `${last.updated_at}|${last.id}` : rawCursor;

  return c.json({ items, cursor: newCursor, has_more: hasMore });
});

// Soft delete with last_modified guard
app.delete("/api/v1/:entity/:id", async (c) => {
  const sql = getSQL(c.req.param("entity"));
  const id = c.req.param("id");

  if (!sql) {
    return c.json({ error: "Invalid entity" }, 400);
  }

  const body = await c.req.json<{ last_modified?: string }>().catch(() => ({}));
  const lastModified = body.last_modified
    ? normalizeTimestamp(body.last_modified)
    : new Date().toISOString();

  const result = await c.env.DB.prepare(sql.softDelete).bind(id, lastModified).run();

  return c.json({ deleted: (result.meta.changes ?? 0) > 0 });
});

// Purge soft-deleted records older than 30 days
app.post("/api/v1/purge", async (c) => {
  const stmts = ENTITY_NAMES.map((name) =>
    c.env.DB.prepare(ENTITY_SQL[name].purgeDeleted)
  );
  const results = await c.env.DB.batch(stmts);

  const purged: Record<string, number> = {};
  for (let i = 0; i < ENTITY_NAMES.length; i++) {
    purged[ENTITY_NAMES[i]] = results[i].meta.changes ?? 0;
  }

  return c.json({ purged });
});

export default app;
