# 🚀 GitHub Pages Deployment Guide

This Godot project is configured to automatically deploy to GitHub Pages - just like your Phaser games!

## Quick Start (5 minutes)

### 1️⃣ Create GitHub Repository

```bash
# In your DungeonCrawler folder
git init
git add .
git commit -m "Initial commit: Godot dungeon crawler"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
git push -u origin main
```

### 2️⃣ Enable GitHub Pages

1. Go to your repository on GitHub
2. Click **Settings** (top menu)
3. Click **Pages** (left sidebar)
4. Under "Source", select **GitHub Actions**
5. Done! ✅

### 3️⃣ Watch It Deploy

- Go to the **Actions** tab in your repo
- You'll see "Deploy to GitHub Pages" running
- Takes ~2-3 minutes
- When it's green ✅, your game is live!

### 4️⃣ Play Your Game

Visit: `https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/`

---

## How It Works

### Automatic Deployment

Every time you push to `main`:

1. **GitHub Actions** triggers (see `.github/workflows/deploy.yml`)
2. **Godot exports** your game to HTML5/WebAssembly
3. **Deploys** to GitHub Pages
4. **Live in ~2-3 minutes** 🎉

### What Gets Deployed

The exported game consists of:
- `index.html` - Main page
- `*.wasm` - WebAssembly (your game compiled to run in browsers)
- `*.pck` - Godot packed resources (scenes, scripts, assets)
- `*.js` - JavaScript loader

Total size: ~5-10MB (includes Godot engine + your game)

---

## Workflow Comparison: Phaser vs Godot

### Your Phaser Games
```
Write JS → Push to GitHub → Live on GitHub Pages
```

### This Godot Game
```
Design in Editor → Export → Push to GitHub → Auto-deploy → Live on GitHub Pages
```

**The difference?** GitHub Actions handles the export step automatically!

---

## Manual Export (Optional)

If you want to test locally or use a different host:

### From Godot Editor

1. **Project** → **Export**
2. If first time: Click **Add...** → **Web**
3. Click **Export Project**
4. Choose folder: `build/web/`
5. Click **Save**

### Test Locally

You need a local server (browsers block local file access):

```bash
# Python 3
cd build/web
python -m http.server 8000

# Or use VS Code Live Server extension
```

Open: `http://localhost:8000`

### Upload Manually

The `build/web/` folder contents can be uploaded to:
- GitHub Pages (manually)
- Netlify
- Vercel
- itch.io (HTML5 upload)
- Any static web host

---

## Troubleshooting

### "Workflow permissions" error?

1. Go to **Settings** → **Actions** → **General**
2. Under "Workflow permissions", select **Read and write permissions**
3. Click **Save**
4. Re-run the workflow

### Page shows 404?

- Make sure you selected **GitHub Actions** as the source (not branch)
- Wait a few minutes after the workflow completes
- Check the Actions tab for errors

### Game doesn't load?

- Check browser console (F12) for errors
- Make sure all scenes are saved before committing
- Try the manual export to test locally first

### Large file warnings?

- Godot games are 5-10MB (includes engine)
- GitHub Pages supports up to 1GB
- You're fine! 👍

---

## Development Workflow

### Recommended Flow

1. **Develop in Godot** (F5 to test)
2. **Commit changes** locally
3. **Push to GitHub** when ready
4. **Auto-deploys** to web
5. **Share the link** with friends!

### Tips

- Test thoroughly in Godot before pushing
- Commit working versions only
- Use branches for experimental features
- Web builds may run slightly differently than desktop - always test!

---

## File Size Optimization (Future)

When your game grows, you can optimize:

1. **Compress textures** (already enabled in export preset)
2. **Use texture atlases** for sprites
3. **Enable PCK compression** in export settings
4. **Remove unused assets** before export

For now, don't worry about it! 🎮

---

## Next Steps

- [ ] Push to GitHub
- [ ] Enable GitHub Pages (select GitHub Actions)
- [ ] Wait for deployment
- [ ] Share your game URL!
- [ ] Keep building awesome features

**Pro tip:** Add your live game URL to the top of your README.md:

```markdown
# Dungeon Crawler

🎮 **[Play Now!](https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/)**
```

Happy game dev! 🚀



