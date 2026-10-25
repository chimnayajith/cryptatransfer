const WebSocket = require("ws");

const PORT = Number(process.env.PORT || process.env.SERVER_PORT || 4017);
const LOG_MESSAGES = process.env.CT_LOG_MESSAGES === "1";
let corruptNextChunk = process.env.CT_CORRUPT_NEXT_CHUNK === "1";

const wss = new WebSocket.Server({ host: "0.0.0.0", port: PORT });
const users = new Map();

console.log(`CryptaTransfer server running on port ${PORT}`);
console.log(`Debug payload logging: ${LOG_MESSAGES ? "ON" : "OFF"}`);
console.log(`Corrupt next chunk: ${corruptNextChunk ? "ARMED" : "OFF"}`);

function heartbeat() { this.isAlive = true; }

wss.on("connection", (socket) => {
  console.log("Client connected");
  socket.isAlive = true;
  socket.on("pong", heartbeat);

  socket.on("message", (raw) => {
    try {
      const message = JSON.parse(raw.toString());
      if (LOG_MESSAGES) {
        // Demo-only: shows the server-visible protocol fields and ciphertext.
        // Never enable this in production because metadata may be sensitive.
        console.log("[CT DEBUG] inbound:", JSON.stringify(message));
      } else {
        console.log(`[${message.type || "unknown"}] message received`);
      }

      switch (message.type) {
        case "register": register(socket, message); break;
        case "get_public_key": getPublicKey(socket, message); break;
        case "transfer_init":
        case "transfer_response":
        case "transfer_start":
        case "transfer_chunk":
        case "transfer_complete":
        case "transfer_result":
          relay(socket, message);
          break;
        default:
          send(socket, { type: "error", message: "Unknown message type" });
      }
    } catch (error) {
      console.error("Message error:", error);
      send(socket, { type: "error", message: "Invalid message" });
    }
  });

  socket.on("close", () => removeUser(socket));
  socket.on("error", () => removeUser(socket));
});

function removeUser(socket) {
  if (!socket.userId) return;
  if (users.get(socket.userId)?.socket === socket) {
    const userId = socket.userId;
    users.delete(userId);
    console.log(`Disconnected: ${userId}`);
    broadcastUsers();
  }
}

function register(socket, message) {
  const userId = typeof message.userId === "string" ? message.userId.trim() : "";
  const publicKey = message.publicKey;

  if (!userId || !publicKey) {
    send(socket, { type: "error", message: "Username and public key are required" });
    return;
  }
  if (socket.userId) {
    send(socket, { type: "error", message: "This connection is already registered" });
    return;
  }
  if (users.has(userId)) {
    // Do not disconnect the existing session: prevent simple username takeover.
    send(socket, { type: "error", message: "Username is already in use" });
    console.warn(`Rejected duplicate username registration: ${userId}`);
    return;
  }

  users.set(userId, { socket, publicKey });
  socket.userId = userId;
  console.log(`Registered: ${userId}`);
  send(socket, { type: "registered", userId });
  broadcastUsers();
}

function broadcastUsers() {
  const onlineUsers = Array.from(users.entries()).map(([userId, user]) => ({
    userId,
    publicKey: user.publicKey,
  }));
  for (const user of users.values()) {
    send(user.socket, { type: "users", users: onlineUsers });
  }
}

function getPublicKey(socket, message) {
  if (!socket.userId) {
    send(socket, { type: "error", message: "Register before requesting public keys" });
    return;
  }
  const user = users.get(message.userId);
  if (!user) {
    send(socket, { type: "error", message: "User is not online" });
    return;
  }
  send(socket, { type: "public_key", userId: message.userId, publicKey: user.publicKey });
}

function relay(socket, message) {
  if (!socket.userId) {
    send(socket, { type: "error", message: "Register before sending messages" });
    return;
  }
  if (message.senderId !== socket.userId) {
    console.warn(`Rejected forged senderId: socket=${socket.userId}, claimed=${message.senderId}`);
    send(socket, { type: "error", message: "Sender identity does not match registered session" });
    return;
  }

  const recipient = users.get(message.recipientId);
  if (!recipient) {
    send(socket, { type: "error", message: `Recipient ${message.recipientId} is not connected` });
    return;
  }

  let outgoing = message;
  if (message.type === "transfer_chunk" && corruptNextChunk) {
    corruptNextChunk = false;
    try {
      const bytes = Buffer.from(String(message.data), "base64");
      if (bytes.length > 0) {
        bytes[0] ^= 0x01;
        outgoing = { ...message, data: bytes.toString("base64"), debugCorrupted: true };
        console.warn("[CT DEBUG] Corrupted one byte in a transfer_chunk (one-shot demo)");
      }
    } catch (error) {
      console.error("Could not corrupt demo chunk:", error);
    }
  }

  if (LOG_MESSAGES) {
    console.log(`[CT DEBUG] relaying ${message.type} ${message.senderId} -> ${message.recipientId}`);
    if (message.type === "transfer_chunk") {
      console.log(`[CT DEBUG] chunk payload is base64 ciphertext; chars=${String(message.data || "").length}`);
    }
  } else {
    console.log(`${message.type}: ${message.senderId} -> ${message.recipientId}`);
  }
  send(recipient.socket, outgoing);
}

function send(socket, message) {
  if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message));
}

const heartbeatInterval = setInterval(() => {
  wss.clients.forEach((socket) => {
    if (socket.isAlive === false) {
      console.log(`Heartbeat timeout: ${socket.userId ?? "unknown"}`);
      socket.terminate();
      return;
    }
    socket.isAlive = false;
    socket.ping();
  });
}, 10000);

wss.on("close", () => clearInterval(heartbeatInterval));
