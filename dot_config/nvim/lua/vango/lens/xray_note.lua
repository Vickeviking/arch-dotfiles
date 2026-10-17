-- What X-ray (the debugger view) shows for a type, so the lens can say it up
-- front. Keys are "crate Type", the crate read from the definition's path;
-- the list mirrors genomlysning's crates.rs and lens.rs. Types without an
-- entry still render in X-ray through the generic reader (fields, newtypes).

local M = {}

local NOTES = {
  -- std
  ["alloc Vec"] = "len / capacity, spare capacity as empty cells, elements as rows",
  ["alloc String"] = "the text, len / capacity, the heap buffer it owns",
  ["alloc Box"] = "an owning arrow to its heap block",
  ["alloc Rc"] = "shared arrow, strong / weak counts",
  ["alloc Arc"] = "shared arrow, strong / weak counts",
  ["alloc Weak"] = "dashed weak arrow, dangling when the value is gone",
  ["alloc BTreeMap"] = "entries decoded from the leaf nodes",
  ["alloc VecDeque"] = "the ring: head, len, wrapped elements",
  ["std HashMap"] = "len / capacity, entries as rows",
  ["std HashSet"] = "len / capacity, elements as rows",
  ["std Mutex"] = "locked or free, poisoned flag, the value inside",
  ["std RwLock"] = "readers / writer, poisoned flag, the value inside",
  ["std JoinHandle"] = "thread still running or finished",
  ["core RefCell"] = "borrow flag: free, n readers, or mutably borrowed",
  ["core Cell"] = "the value inline",
  ["core Option"] = "Some(value) or None, niche-aware",
  ["core Result"] = "Ok / Err with the payload",
  ["core Duration"] = "human time (1.5 s, 250 ms)",
  ["core AtomicUsize"] = "the value, atomic arrow when it holds a pointer",
  ["core AtomicPtr"] = "an atomic arrow to the pointee",
  -- locks and lock-free
  ["lock_api Mutex"] = "parking_lot state bits: LOCKED, PARKED (someone waiting)",
  ["lock_api RwLock"] = "readers count, writer bit, parked waiters",
  ["lock_api ReentrantMutex"] = "owner thread and lock count",
  ["lock_api MutexGuard"] = "holds the lock: a mutable borrow arrow into the mutex",
  ["crossbeam_epoch Atomic"] = "tagged pointer: low tag bits split out, arrow to the pointee",
  ["crossbeam_epoch Owned"] = "owning tagged pointer",
  ["crossbeam_epoch Shared"] = "borrowed tagged pointer, valid while pinned",
  ["crossbeam_epoch Guard"] = "pinned: reads through Shared are safe",
  -- async
  ["tokio JoinHandle"] = "the task: name, idle / running / done, what it is awaiting",
  ["tokio Sender"] = "channel: senders alive, bound, free permits",
  ["tokio Receiver"] = "channel: queued messages, senders alive, closed or open",
  ["tokio UnboundedSender"] = "channel: senders alive, queued messages",
  ["tokio Mutex"] = "async lock: locked or free, waiters",
  ["tokio Notify"] = "waiters and pending notification",
  -- data
  ["serde_json Value"] = "the JSON, pretty, with kind and size",
  ["serde_json Map"] = "the object's keys and values",
  ["ron Value"] = "the RON text, with its kind",
  ["anyhow Error"] = "the whole context chain: outer ← inner ← root cause",
  ["bytes Bytes"] = "the bytes as text when printable, len",
  ["bytes BytesMut"] = "the bytes, len / capacity",
  ["uuid Uuid"] = "formatted 8-4-4-4-12 with its version",
  ["chrono DateTime"] = "the date and time in its zone",
  ["chrono NaiveDate"] = "the date",
  ["chrono NaiveTime"] = "the time",
  ["chrono TimeDelta"] = "human duration",
  -- web
  ["http StatusCode"] = "code and reason (404 Not Found), colored by class",
  ["http Method"] = "GET / POST …",
  ["http Uri"] = "the URI as text",
  ["http HeaderMap"] = "the headers",
  ["http Request"] = "method, URI, headers",
  ["url Url"] = "the URL as text",
  ["reqwest Client"] = "shared connection pool, clone count",
  ["axum Router"] = "the router (routes are opaque in debug info)",
  ["axum Json"] = "the payload inside",
  ["axum Path"] = "the extracted value",
  ["axum Query"] = "the extracted value",
  ["axum State"] = "the shared state inside",
  -- others
  ["tracing Span"] = "the span's name and level, or disabled",
  ["tracing_core Level"] = "ERROR / WARN / INFO …, colored",
  ["sqlx_core Pool"] = "connections: open, idle, max",
  ["rayon_core ThreadPool"] = "worker threads",
  ["rand StdRng"] = "seeded RNG (state hidden on purpose)",
  ["rand ThreadRng"] = "thread-local RNG",
}

-- the crate a file belongs to: registry `name-1.2.3/`, git checkouts, or std's library/
function M.crate_of(fname)
  local std = fname:match("/library/(%w+)/src/")
  if std then
    return std
  end
  local c = fname:match("/([%w_%-]+)%-%d+%.%d+%.%d+[^/]*/src/")
  return c and c:gsub("%-", "_") or nil
end

function M.note(fname, base)
  local crate = fname and M.crate_of(fname)
  if not crate or not base then
    return nil
  end
  return NOTES[crate .. " " .. base], crate
end

return M
