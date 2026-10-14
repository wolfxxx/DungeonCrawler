// Generates Dungeon Crawler audio with ElevenLabs API into sounds/
// Usage: ELEVENLABS_API_KEY=... node tools/gen_audio.mjs [--force]
import { writeFile, mkdir, access } from 'node:fs/promises';
import path from 'node:path';

const KEY = process.env.ELEVENLABS_API_KEY;
if (!KEY) {
  console.error('ELEVENLABS_API_KEY not set');
  process.exit(1);
}

const OUT = path.resolve('sounds');
const force = process.argv.includes('--force');

const SFX = {
  player_attack: ['sharp medieval broadsword slash whoosh through air with metallic ring, crisp game sound effect', 0.6],
  player_special: ['powerful spinning whirlwind sword slash with magical arcane energy burst shockwave', 1.2],
  player_dash: ['fast agile evasion dash whoosh with light armor cloth rustle', 0.5],
  enemy_hit: ['heavy sword impact hitting monster armor and bone, crunchy thud', 0.6],
  enemy_death: ['dungeon monster grunts and collapses into rattling bones on stone floor', 1.0],
  player_hit: ['heavy impact on knight metal shield and plate armor with short grunt', 0.6],
  pickup_health: ['magical glass potion bottle clink followed by warm sparkling healing chime', 1.0],
  pickup_gold: ['handful of heavy gold coins clinking and jingling brightly', 0.8],
  chest_open: ['heavy iron-bound wooden treasure chest creaking open with bright magical treasure shimmer', 1.5],
  barrel_break: ['wooden dungeon barrel smashing and splintering into pieces', 0.8],
  door_open: ['heavy ancient stone and iron dungeon portcullis gate grinding open', 1.4],
  boss_roar: ['deep terrifying demonic monster roar echoing in a dark stone cavern', 2.0],
  fireball: ['dark magic fireball cast whoosh and crackling arcane bolt', 0.8],
  victory: ['triumphant medieval fantasy brass and timpani fanfare sting', 3.0],
  game_over: ['deep ominous dungeon bell toll with dark dramatic low brass chord', 2.5],
};

// Deep dramatic British voice (George)
const VOICE_ID = 'JBFqnCBsd6RMkjVDRZzb';
const VOICE = {
  vo_enter: 'Descend into the Forgotten Catacombs. Slay the Abyssal Warden.',
  vo_cleared: 'Chamber cleared. The gate opens.',
  vo_boss: 'You dare trespass into the Throne of the Abyss?',
  vo_victory: 'The Abyssal Warden has fallen. Victory is yours, champion.',
};

const MUSIC = {
  music_dungeon: [
    'Dark fantasy dungeon crawler action RPG soundtrack: driving cello and lute ostinato, deep medieval war drums, atmospheric echoing stone cavern pad, mysterious minor key melody, 118 bpm, loopable instrumental, no vocals',
    40000,
  ],
};

async function exists(f) {
  try {
    await access(f);
    return true;
  } catch {
    return false;
  }
}

async function post(url, body) {
  for (let attempt = 0; attempt < 3; attempt++) {
    const r = await fetch(url, {
      method: 'POST',
      headers: {
        'xi-api-key': KEY,
        'Content-Type': 'application/json',
        Accept: 'audio/mpeg',
      },
      body: JSON.stringify(body),
    });
    if (r.ok) return Buffer.from(await r.arrayBuffer());
    const t = await r.text();
    if (r.status === 429) {
      await new Promise((s) => setTimeout(s, 3500));
      continue;
    }
    throw new Error(`${r.status} ${t.slice(0, 300)}`);
  }
  throw new Error('retries exhausted');
}

async function job(name, fn) {
  const file = path.join(OUT, name + '.mp3');
  if (!force && (await exists(file))) {
    console.log('skip', name);
    return;
  }
  try {
    const buf = await fn();
    await writeFile(file, buf);
    console.log('ok  ', name, buf.length, 'bytes');
  } catch (e) {
    console.error('FAIL', name, e.message);
  }
}

await mkdir(OUT, { recursive: true });
const jobs = [];
for (const [n, [text, dur]] of Object.entries(SFX)) {
  jobs.push(() =>
    job(n, () =>
      post('https://api.elevenlabs.io/v1/sound-generation', {
        text,
        duration_seconds: dur,
        prompt_influence: 0.6,
      })
    )
  );
}
for (const [n, text] of Object.entries(VOICE)) {
  jobs.push(() =>
    job(n, () =>
      post(`https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}`, {
        text,
        model_id: 'eleven_multilingual_v2',
        voice_settings: { stability: 0.6, similarity_boost: 0.8, style: 0.35 },
      })
    )
  );
}
for (const [n, [prompt, ms]] of Object.entries(MUSIC)) {
  jobs.push(() =>
    job(n, () =>
      post('https://api.elevenlabs.io/v1/music', {
        prompt,
        music_length_ms: ms,
        force_instrumental: true,
      })
    )
  );
}

const queue = [...jobs];
await Promise.all(
  Array.from({ length: 3 }, async () => {
    while (queue.length) await queue.shift()();
  })
);
console.log('Audio generation finished.');
