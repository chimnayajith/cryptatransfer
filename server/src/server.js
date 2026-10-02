const WebSocket = require("ws");

const PORT = 8000;

const wss = new WebSocket.Server({
  host: "0.0.0.0",
  port: PORT,
});

const users = new Map();

console.log(`CryptaTransfer server running on port ${PORT}`);

// Heartbeat
function heartbeat() {
  this.isAlive = true;
}

wss.on("connection", (socket) => {
  console.log("Client connected");

  socket.isAlive = true;
  socket.on("pong", heartbeat);

  socket.on("message", (raw) => {
    try {
      const message = JSON.parse(raw.toString());

      switch (message.type) {
        case "register":
          register(socket, message);
          break;

        case "get_public_key":
          getPublicKey(socket, message);
          break;

        case "transfer_init":
        case "transfer_response":
        case "transfer_start":
        case "transfer_chunk":
        case "transfer_complete":
        case "transfer_result":
          relay(message);
          break;

        default:
          send(socket, {
            type: "error",
            message: "Unknown message type",
          });
      }
    } catch (error) {
      console.error("Message error:", error);

      send(socket, {
        type: "error",
        message: "Invalid message",
      });
    }
  });

  socket.on("close", () => {
    removeUser(socket);
  });

  socket.on("error", () => {
    removeUser(socket);
  });
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
  const { userId, publicKey } = message;

  if (!userId || !publicKey) {
    send(socket, {
      type: "error",
      message: "Username and public key are required",
    });

    return;
  }

  const existing = users.get(userId);

  if (existing && existing.socket !== socket) {
    existing.socket.close();
  }

  users.set(userId, {
    socket,
    publicKey,
  });

  socket.userId = userId;

  console.log(`Registered: ${userId}`);

  send(socket, {
    type: "registered",
    userId,
  });

  broadcastUsers();
}

function broadcastUsers() {
  const onlineUsers = Array.from(users.entries()).map(
    ([userId, user]) => ({
      userId,
      publicKey: user.publicKey,
    }),
  );

  console.log(
    "Broadcasting users:",
    onlineUsers.map((user) => user.userId),
  );

  for (const user of users.values()) {
    send(user.socket, {
      type: "users",
      users: onlineUsers,
    });
  }
}

function getPublicKey(socket, message) {
  const user = users.get(message.userId);

  if (!user) {
    send(socket, {
      type: "error",
      message: "User is not online",
    });

    return;
  }

  send(socket, {
    type: "public_key",
    userId: message.userId,
    publicKey: user.publicKey,
  });
}

function relay(message) {
  const recipient = users.get(message.recipientId);

  if (!recipient) {
    console.log(
      `Recipient ${message.recipientId} is not connected`,
    );

    return;
  }

  console.log(
    `${message.type}: ${message.senderId} -> ${message.recipientId}`,
  );

  send(recipient.socket, message);
}

function send(socket, message) {
  if (socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify(message));
  }
}

// Check clients every 10 seconds
const heartbeatInterval = setInterval(() => {
  wss.clients.forEach((socket) => {
    if (socket.isAlive === false) {
      console.log(
        `Heartbeat timeout: ${socket.userId ?? "unknown"}`,
      );

      socket.terminate();
      return;
    }

    socket.isAlive = false;
    socket.ping();
  });
}, 10000);

wss.on("close", () => {
  clearInterval(heartbeatInterval);
});