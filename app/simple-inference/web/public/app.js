const chatContainer = document.getElementById("chat-container");
const chatForm = document.getElementById("chat-form");
const userInput = document.getElementById("user-input");
const modelSelect = document.getElementById("model-select");
const sendBtn = document.getElementById("send-btn");
const clearBtn = document.getElementById("clear-btn");
const routeInfo = document.getElementById("route-info");

let messages = [];
let modelMetadata = {}; // id -> { owned_by, display_name, description }

// Auto-resize textarea
userInput.addEventListener("input", () => {
  userInput.style.height = "auto";
  userInput.style.height = Math.min(userInput.scrollHeight, 120) + "px";
});

// Submit on Enter (Shift+Enter for newline)
userInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    chatForm.dispatchEvent(new Event("submit"));
  }
});

// Update route info on model change
modelSelect.addEventListener("change", () => {
  updateRouteInfo();
});

function updateRouteInfo() {
  const modelId = modelSelect.value;
  const meta = modelMetadata[modelId];
  if (meta && meta.owned_by === "bedrock") {
    routeInfo.textContent = `Bedrock Mantle → ${meta.display_name || modelId}`;
  } else {
    routeInfo.textContent = `Envoy AI Gateway → vLLM (${modelId})`;
  }
}

// Clear chat
clearBtn.addEventListener("click", () => {
  messages = [];
  chatContainer.innerHTML = `
    <div class="message system">
      <p>Chat cleared. Select a model and start chatting.</p>
    </div>
  `;
});

// Load available models from the API
async function loadModels() {
  try {
    const res = await fetch("/api/models");
    const data = await res.json();
    if (data.data && data.data.length > 0) {
      modelSelect.innerHTML = "";
      data.data.forEach((model) => {
        const opt = document.createElement("option");
        opt.value = model.id;
        opt.textContent = model.display_name || model.id;
        modelSelect.appendChild(opt);

        modelMetadata[model.id] = {
          owned_by: model.owned_by,
          display_name: model.display_name,
          description: model.description,
        };
      });
      updateRouteInfo();
    }
  } catch {
    // Keep defaults in HTML
  }
}

function addMessage(role, content, model) {
  const div = document.createElement("div");
  div.className = `message ${role}`;

  if (role === "assistant" && model) {
    const tag = document.createElement("div");
    tag.className = "model-tag";
    const meta = modelMetadata[model];
    tag.textContent = meta ? meta.display_name || model : model;
    div.appendChild(tag);
  }

  const p = document.createElement("p");
  p.textContent = content;
  div.appendChild(p);

  chatContainer.appendChild(div);
  chatContainer.scrollTop = chatContainer.scrollHeight;
  return p;
}

// Handle form submit
chatForm.addEventListener("submit", async (e) => {
  e.preventDefault();

  const text = userInput.value.trim();
  if (!text) return;

  // Add user message
  messages.push({ role: "user", content: text });
  addMessage("user", text);

  userInput.value = "";
  userInput.style.height = "auto";
  sendBtn.disabled = true;

  const model = modelSelect.value;

  // Create assistant message placeholder
  const assistantP = addMessage("assistant", "", model);
  assistantP.parentElement.classList.add("typing-indicator");

  try {
    const res = await fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model, messages, stream: true }),
    });

    if (!res.ok) {
      const err = await res.json();
      assistantP.textContent = `Error: ${err.error || "Request failed"}`;
      assistantP.parentElement.classList.remove("typing-indicator");
      sendBtn.disabled = false;
      return;
    }

    // Read SSE stream
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let fullResponse = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value, { stream: true });
      const lines = chunk.split("\n");

      for (const line of lines) {
        if (!line.startsWith("data: ")) continue;
        const data = line.slice(6);
        if (data === "[DONE]") continue;

        try {
          const parsed = JSON.parse(data);
          const delta = parsed.choices?.[0]?.delta?.content;
          if (delta) {
            fullResponse += delta;
            assistantP.textContent = fullResponse;
            chatContainer.scrollTop = chatContainer.scrollHeight;
          }
        } catch {
          // Skip malformed chunks
        }
      }
    }

    assistantP.parentElement.classList.remove("typing-indicator");
    messages.push({ role: "assistant", content: fullResponse });
  } catch (err) {
    assistantP.textContent = `Connection error: ${err.message}`;
    assistantP.parentElement.classList.remove("typing-indicator");
  }

  sendBtn.disabled = false;
  userInput.focus();
});

// Init
loadModels();
