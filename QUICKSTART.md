# ⚡ Quick Start Guide

Get your dungeon crawler running in **10 minutes**!

## Step 1: Download Godot (2 minutes)

1. Go to https://godotengine.org/download/
2. Download **Godot 4.2** (Standard version)
3. Extract the ZIP
4. Run `Godot_v4.2.x_win64.exe` (no installation needed!)

## Step 2: Open the Project (1 minute)

1. In Godot, click **Import**
2. Click **Browse** and select the `project.godot` file in this folder
3. Click **Import & Edit**
4. Wait for Godot to import assets (~30 seconds)

## Step 3: Play! (instant)

Press **F5** or click the ▶️ **Play** button at the top right.

**Controls:**
- **WASD** to move
- **Space** to attack
- **ESC** to quit

## Step 4: Explore the Editor (5 minutes)

### Understanding the Layout

```
┌─────────────────────────────────────────────────┐
│  Scene  ▶️ Run  FileSystem  Debug              │  ← Toolbar
├──────────┬──────────────────────┬───────────────┤
│  Scene   │                      │   Inspector   │
│  Tree    │    2D Viewport       │   (Properties)│
│          │    (Your game view)  │               │
│  ├Player │                      │   Position    │
│  ├Enemy  │                      │   Rotation    │
│  └Room   │                      │   Scale       │
├──────────┴──────────────────────┴───────────────┤
│  FileSystem (Your project files)                │
│  Output (Print statements and errors)           │
└─────────────────────────────────────────────────┘
```

### Try This:

1. **Scene Tree** (left): Click on "Player"
2. **Inspector** (right): See all the Player's properties
3. Find `Speed` - change it to `400`
4. Press **F5** - your player is now faster!
5. Want it back? Change to `200`

### Explore the Files:

**FileSystem panel** (bottom-left):

```
res://
├── scenes/
│   ├── player.tscn      ← Double-click to open
│   ├── enemy.tscn
│   └── main.tscn
└── scripts/
    ├── player.gd        ← Double-click to see code
    └── enemy.gd
```

**Try:**
1. Double-click `scenes/player.tscn`
2. Click the green hexagon in the viewport (that's your player!)
3. Look at the **Inspector** - you can edit all these values!

## Step 5: Make Your First Change (2 minutes)

Let's make enemies faster:

1. Double-click `scenes/enemy.tscn` in FileSystem
2. Click the red hexagon enemy in the Scene tree
3. In the **Inspector**, find `Speed: 80`
4. Change it to `150`
5. Press **Ctrl+S** to save
6. Press **F5** to test - enemies are faster now!

## Step 6: Read Some Code (optional)

1. Double-click `scripts/player.gd` in FileSystem
2. Read through it - it's heavily commented!
3. It's GDScript (Python-like) - you'll recognize most of it

```gdscript
# See? Just like Python!
var speed = 200.0

func _physics_process(delta):
    handle_movement(delta)
    move_and_slide()
```

## Next Steps

### Learn More
- Read the main [README.md](README.md) for full documentation
- Check out [DEPLOYMENT.md](DEPLOYMENT.md) to publish to GitHub Pages
- Watch: [Your First 2D Game](https://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html) (official tutorial)

### Modify the Game

**Easy wins:**
- Change colors in `Polygon2D` nodes (Inspector → Color)
- Add more enemies (Scene tree → right-click Enemy → Duplicate)
- Change health/damage values in Inspector
- Modify the room size

**Next level:**
- Add a health bar (UI → ProgressBar)
- Create a second room
- Add sound effects (AudioStreamPlayer)
- Add different enemy types

### Deploy to Web

When you're ready to show off:

1. Follow [DEPLOYMENT.md](DEPLOYMENT.md)
2. Push to GitHub
3. Share your link!

## Common First-Time Questions

**Q: Where's the game loop?**
A: It's automatic! `_physics_process(delta)` runs every frame.

**Q: How do I add images/sprites?**
A: Drag images into the FileSystem, then assign to a `Sprite2D` node.

**Q: Why use scenes instead of code?**
A: Scenes are reusable templates. Make one enemy scene, spawn 100 enemies!

**Q: Is GDScript fast enough?**
A: Yes! It's JIT-compiled and optimized for games.

**Q: Can I use C#/C++ instead?**
A: Yes, but GDScript is recommended for learning.

## Keyboard Shortcuts

- **F5**: Run game
- **F6**: Run current scene
- **Ctrl+S**: Save scene
- **Ctrl+D**: Duplicate node
- **Ctrl+Z**: Undo
- **F1**: Open documentation

## Getting Help

- Godot Docs: https://docs.godotengine.org/
- Godot Discord: https://discord.gg/godotengine
- Reddit: r/godot
- Ask me! I'm here to help 😊

---

**You're ready!** Start experimenting and have fun! 🎮

The best way to learn is to try things, break stuff, and fix it. You've got this! 🚀



