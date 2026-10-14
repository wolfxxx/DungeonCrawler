# 🔊 Adding Sound Effects

Your game is now set up for sounds! You just need to add the actual audio files.

## 🎵 Where to Get FREE Sound Effects

### Best Free Sound Libraries:

1. **Freesound.org** ⭐ Best option
   - https://freesound.org/
   - Tons of free sounds (CC license)
   - Search for: "sword swing", "punch", "death", "pickup", "win"

2. **Pixabay** ⭐ Easy to use
   - https://pixabay.com/sound-effects/
   - No attribution required
   - Good quality

3. **OpenGameArt.org**
   - https://opengameart.org/
   - Game-specific sounds
   - Great for retro/pixel games

4. **Kenney.nl** ⭐ Game dev favorite
   - https://kenney.nl/assets?q=audio
   - Professional quality packs
   - Completely free

5. **JSFXR** (Generate your own!)
   - https://sfxr.me/
   - Create retro game sounds in browser
   - Perfect for placeholder sounds

---

## 📥 How to Add Sounds to Your Game

### Step 1: Download Sounds

You need these 7 sounds:

| Sound Name | What to Search | Example |
|------------|---------------|---------|
| **PlayerAttack** | "sword swing", "whoosh", "slash" | Quick whoosh sound |
| **EnemyHit** | "punch", "hit", "impact" | Thud/impact sound |
| **EnemyDeath** | "death", "defeat", "explosion" | Satisfying defeat sound |
| **PlayerHit** | "hurt", "ouch", "damage" | Painful grunt/sound |
| **Pickup** | "coin", "pickup", "powerup" | Pleasant chime |
| **Victory** | "win", "success", "fanfare" | Triumphant music/jingle |
| **GameOver** | "game over", "fail", "sad" | Descending/sad sound |

**Tip:** Download as `.wav` or `.ogg` files (Godot supports both)

---

### Step 2: Add to Godot

1. **Create sounds folder:**
   - In FileSystem (bottom-left), right-click
   - New Folder → name it `sounds`

2. **Drag sound files into the folder:**
   - From Windows Explorer, drag your `.wav` or `.ogg` files
   - Drop them into the `sounds` folder in Godot

3. **Assign sounds to AudioManager:**
   - In FileSystem, double-click `scenes/audio_manager.tscn`
   - In the Scene tree (left), click `PlayerAttack`
   - In Inspector (right), find "Stream"
   - Drag your attack sound file from FileSystem into "Stream"
   - Repeat for all 7 sounds:
     - PlayerAttack
     - EnemyHit
     - EnemyDeath
     - PlayerHit
     - Pickup
     - Victory
     - GameOver

4. **Save and test!**
   - Press Ctrl+S
   - Press F5 to play
   - Enjoy your sounds! 🎵

---

## 🎚️ Adjusting Volume

Sounds too loud or quiet?

1. Open `scenes/audio_manager.tscn`
2. Click on the sound player (e.g., "PlayerAttack")
3. In Inspector, find "Volume Db"
4. Adjust:
   - `0 db` = normal volume
   - `-10 db` = quieter
   - `-20 db` = much quieter
   - `+5 db` = louder

---

## 🎮 Quick Start (5 Minutes)

**Want to test immediately?**

1. Go to https://sfxr.me/
2. Click these buttons to generate sounds:
   - **Pickup/Coin** → Download → save as `pickup.wav`
   - **Laser/Shoot** → Download → save as `attack.wav`
   - **Hit/Hurt** → Download → save as `hit.wav`
   - **Explosion** → Download → save as `death.wav`
   - **Powerup** → Download → save as `victory.wav`
3. Drag all into Godot's `sounds` folder
4. Assign them as described above

**That's it!** Your game will have retro game sounds in 5 minutes! 🎉

---

## 🎵 Recommended Sound Packs

If you want a complete set:

**Kenney - Interface Sounds**
- https://kenney.nl/assets/interface-sounds
- 394 UI sounds
- Perfect for menus, pickups

**Kenney - Impact Sounds**
- https://kenney.nl/assets/impact-sounds
- Great for hits and attacks

**Freesound - Game Sound Pack**
- Search "game sound pack" on Freesound
- Many complete packs available

---

## 💡 Tips

- **Format:** Use `.ogg` files for smaller file size (good for web)
- **Length:** Keep sounds under 2 seconds for responsiveness
- **Volume:** Start quiet, you can always turn up later
- **Testing:** Press F5 often to hear how sounds feel in-game
- **Placeholder:** Use JSFXR for quick placeholders, replace later

---

## 🎼 Optional: Background Music

Want to add music too?

1. Find a looping track (30-60 seconds)
2. Add `AudioStreamPlayer` to Main scene
3. Check "Autoplay" and "Loop" in Inspector
4. Keep music volume low (-15 to -20 db)

**Good music sources:**
- https://incompetech.com/ (Kevin MacLeod)
- https://opengameart.org/
- https://freemusicarchive.org/

---

**Need help?** Just ask! Once you add the sound files, your game will feel 10x better! 🎮✨









