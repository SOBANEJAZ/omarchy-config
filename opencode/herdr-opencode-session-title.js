import net from "node:net";

const SOURCE = "user:opencode-session-title";
const AGENT = "opencode";
const ROUTE_POLL_INTERVAL_MS = 100;
const PLACEHOLDER_TITLES = new Set(["new session", "untitled", "untitled session"]);

let reportSeq = Date.now() * 1_000;
let requestChain = Promise.resolve();

function nextReportSeq() {
  reportSeq += 1;
  return reportSeq;
}

function displayTitle(title) {
  if (typeof title !== "string") {
    return undefined;
  }

  const trimmed = title.trim();
  return trimmed && !PLACEHOLDER_TITLES.has(trimmed.toLowerCase()) ? trimmed : undefined;
}

function requestOnce(title) {
  const paneId = process.env.HERDR_PANE_ID;
  const socketPath = process.env.HERDR_SOCKET_PATH;
  if (!paneId || !socketPath) {
    return Promise.resolve(false);
  }

  const socketEndpoint =
    process.platform === "win32" ? `\\\\.\\pipe\\${socketPath}` : socketPath;
  const request = {
    id: `${SOURCE}:${Date.now()}:${Math.floor(Math.random() * 1_000_000)
      .toString()
      .padStart(6, "0")}`,
    method: "pane.report_metadata",
    params: {
      pane_id: paneId,
      source: SOURCE,
      agent: AGENT,
      seq: nextReportSeq(),
      ...(title
        ? { display_agent: title }
        : { clear_display_agent: true }),
    },
  };

  return new Promise((resolve) => {
    const client = net.createConnection(socketEndpoint, () => {
      client.write(`${JSON.stringify(request)}\n`);
    });
    let settled = false;
    const finish = (accepted) => {
      if (settled) {
        return;
      }
      settled = true;
      client.destroy();
      resolve(accepted);
    };

    client.setTimeout(500, () => finish(false));
    client.on("data", (data) => {
      try {
        const response = JSON.parse(data.toString());
        finish(!response.error);
      } catch {
        finish(true);
      }
    });
    client.on("error", () => finish(false));
    client.on("end", () => finish(false));
    client.on("close", () => finish(false));
  });
}

function reportMetadata(title) {
  const pending = requestChain.then(() => requestOnce(title));
  requestChain = pending.catch(() => false);
  return pending;
}

export default {
  id: "herdr.opencode.session-title",
  tui: async (api) => {
    if (
      process.env.HERDR_ENV !== "1" ||
      !process.env.HERDR_SOCKET_PATH ||
      !process.env.HERDR_PANE_ID
    ) {
      return;
    }

    let lastReportedKey;
    let reportPending = false;

    const currentSelection = () => {
      const route = api.route.current;
      if (route?.name !== "session") {
        return { key: "home", title: undefined };
      }

      const sessionID = route.params?.sessionID;
      if (typeof sessionID !== "string" || !sessionID) {
        return { key: "home", title: undefined };
      }

      const session = api.state.session.get(sessionID);
      if (session?.parentID) {
        return undefined;
      }

      const title = displayTitle(session?.title);
      return {
        key: `${sessionID}\u0000${title ?? ""}`,
        title,
      };
    };

    const syncSelectedTitle = async () => {
      const selection = currentSelection();
      if (!selection || selection.key === lastReportedKey || reportPending) {
        return;
      }

      const reportingKey = selection.key;
      reportPending = true;
      try {
        const accepted = await reportMetadata(selection.title);
        if (accepted && currentSelection()?.key === reportingKey) {
          lastReportedKey = reportingKey;
        }
      } finally {
        reportPending = false;
      }
    };

    await syncSelectedTitle();
    const routePoll = setInterval(() => void syncSelectedTitle(), ROUTE_POLL_INTERVAL_MS);
    api.lifecycle.onDispose(() => clearInterval(routePoll));
  },
};
