# OllamaClient

A native macOS chat client for [Ollama](https://ollama.com/) servers — local or on your LAN.

![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)

## Features

- **Model browser** — connects to any Ollama server and lists every installed model with its size
- **Streaming responses** — replies appear token-by-token as they are generated, just like a terminal client
- **Full conversation history** — every turn is replayed to the model so it retains context across messages
- **Stop generation** — cancel a streaming reply mid-flight
- **New conversation** — clear the transcript and start fresh without restarting the app
- **Persisted server address** — your last-used host is remembered across launches
- **LAN support** — connects over plain `http://` to Ollama servers on your local network (no HTTPS required)

## Requirements

- macOS 15 or later
- An [Ollama](https://ollama.com/) server reachable on `localhost` or your LAN with at least one model pulled

## Usage

1. Launch **OllamaClient.app**.
2. In the sidebar, enter your Ollama server address (default: `http://localhost:11434`).  
   Press **Return** or click the refresh button — the model list will populate.
3. Select a model from the list.
4. Type a message in the composer and press **Return** (or click the send button) to chat.  
   The reply streams in as it is generated.
5. To stop a reply early, click the **stop** button that appears during generation.
6. To start a new conversation, click the **pencil** button in the toolbar.

### Connecting to a remote Ollama server

Enter the server's address including port, e.g.:

```
http://192.168.1.50:11434
```

The app uses `NSAllowsLocalNetworking` so cleartext `http://` connections to LAN addresses work without any extra configuration.

## Building from source

1. Open `OllamaClient.xcodeproj` in Xcode 16 or later.
2. Select the **OllamaClient** scheme and a macOS destination.
3. Press **⌘R** to build and run.

No third-party dependencies — the app uses only `Foundation` and `SwiftUI`.

## Project structure

| File | Purpose |
|---|---|
| `OllamaModels.swift` | Data types for the Ollama REST API |
| `OllamaService.swift` | Async networking — `GET /api/tags` and streaming `POST /api/chat` |
| `ChatViewModel.swift` | Observable state: host, models, conversation history, send/stop logic |
| `ContentView.swift` | Root `NavigationSplitView` layout |
| `SidebarView.swift` | Server address field and model picker |
| `ChatView.swift` | Scrolling transcript and message composer |
| `MessageBubbleView.swift` | Individual message bubbles (user right, assistant left) |
| `Info.plist` | ATS exception for LAN cleartext HTTP |

## Known limitations

- Conversation history is in-memory only — it is not saved to disk between sessions.
- No image or file attachment support.
- No system prompt configuration in the UI (can be added to the `messages` array in `ChatViewModel`).
