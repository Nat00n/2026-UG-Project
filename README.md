# TaskTrain - Algorithm Education Through Game-Based Learning

An interactive browser-based educational game that teaches algorithm concepts through Python programming tasks with real-time visualizations.

## Play the Game

[Play TaskTrain on itch.io](https://nat00n.itch.io/tasktrain)

## About

TaskTrain is a game-based learning tool designed to bridge the gap between theoretical algorithm knowledge and practical implementation.
Students write Python code to solve algorithm challenges across four categories:

- **Sorting Algorithms** (Bubble, Insertion, Merge, Quick Sort)
- **Searching Algorithms** (Linear, Binary Search)
- **Graph Traversal** (DFS, BFS, Dijkstra, A*)
- **Dynamic Programming** (0/1 Knapsack, Exact Change)

### Key Features

-  **In-Browser Python IDE** powered by Pyodide (no installation required)
-  **Real-Time Algorithm Visualizations** triggered by student code using custom Python functions
-  **AI-Powered Hints** using WebLLM (on-demand, client-side)
-  **Pedagogical Techniques** scaffolding with Gradual Release of Responsibility and Self-Regulated Learning
-  **Competitive Leaderboard** with score and time tracking
-  **Progress Persistence** via browser localStorage

## Technology

- **Game Engine:** Godot 4.6 (exported to HTML5/WebAssembly)
- **Python Execution:** Pyodide (CPython in browser)
- **AI Inference:** WebLLM (Qwen2.5-Coder-1.5B)
- **Leaderboard:** SilentWolf cloud backend
- **Analytics:** Google Apps Script + Google Sheets
- **Languages:** GDScript, Python, JavaScript

## Quick Start

### Playing the Game

1. Visit the [itch.io page](https://nat00n.itch.io/tasktrain)
2. Enter a username
3. Select a level and start coding!

No installation, downloads, or account creation required.

### Development Setup

1. Install [Godot 4.6](https://godotengine.org)
2. Clone this repository
3. Open `project.godot` in Godot Editor
4. To test, run locally

### Running Locally

Recommended that you use Chrome or Edge for full features

```bash
# Clone the repository
git clone https://github.com/yourusername/TaskTrain.git
cd TaskTrain

# Navigate to export directory
cd exports/

# Start local server (required for Pyodide/WebLLM)
python -m http.server 8000

# Open browser to http://localhost:8000
```

## Credit To Assets

% Graphical Assets
% https://dobyagame.itch.io/train
% https://kenney.nl/assets/hexagon-tiles
% https://kenney.nl/assets/background-elements-remastered
% https://kenney.nl/assets/new-platformer-pack
% https://kooky.itch.io/pixel-train
% https://opengameart.org/content/communication-terminal-32x32
% https://kenney.nl/assets/emotes-pack

% Music Assets
% https://opengameart.org/content/slow-stride
% https://opengameart.org/content/desert-theme
% https://opengameart.org/content/fall
% https://opengameart.org/content/lord-of-the-mountain
% https://opengameart.org/content/bossa-nova
% https://opengameart.org/content/somewhere-in-the-elevator

% SFX Assets
% https://opengameart.org/content/16bit-success-sound
% https://opengameart.org/content/8bit-menu-select
% https://freesound.org/people/GabrielAraujo/sounds/242503/
% https://freesound.org/people/Geoff-Bremner-Audio/sounds/733021/
% https://freesound.org/people/digimistic/sounds/705174/
% https://freesound.org/people/NIKOS34/sounds/656393/
% https://freesound.org/people/dland/sounds/320181/
% https://freesound.org/people/CmdRobot/sounds/264828/
