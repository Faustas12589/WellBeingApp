// Adds temporary demo data to a user for screenshots, and removes it again.
//
//   node seed.js seed  [userId]   -> backs up the user, then adds demo data
//   node seed.js clean [userId]   -> deletes demo data and restores the backup
//
// Needs serviceAccountKey.json next to this file
// (Firebase Console -> Project settings -> Service accounts -> Generate new private key).
// If userId is omitted, the only user in `users` is used.

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const KEY_PATH = path.join(__dirname, 'serviceAccountKey.json');
const BACKUP_PATH = path.join(__dirname, 'backup.json');
const PREFIX = 'demo_';
const DAYS = 30;

admin.initializeApp({ credential: admin.credential.cert(require(KEY_PATH)) });
const db = admin.firestore();
const { Timestamp } = admin.firestore;

// ─── demo content ────────────────────────────────────────────────────────────

const habits = [
  { id: `${PREFIX}water`, name: 'Drink water', kind: 'number', min: 0, max: 12, icon: 'water' },
  { id: `${PREFIX}run`, name: 'Morning run', kind: 'checkbox', icon: 'run' },
  { id: `${PREFIX}read`, name: 'Read 20 pages', kind: 'checkbox', icon: 'book' },
  { id: `${PREFIX}meditate`, name: 'Meditation', kind: 'checkbox', icon: 'meditation' },
  { id: `${PREFIX}sleep`, name: 'Sleep quality', kind: 'scale', min: 1, max: 5, icon: 'sleep' },
  { id: `${PREFIX}food`, name: 'Healthy meals', kind: 'enumerator', options: ['None', 'Some', 'All day'], icon: 'food' },
].map((h) => ({
  min: null, max: null, options: null, archived: false, systemOnly: false, stepGoal: null, ...h,
}));

const goals = [
  { id: `${PREFIX}g_water`, name: '8 glasses a day', habbitID: `${PREFIX}water`, target: 8, period: 'day', customDays: null, repeat: true },
  { id: `${PREFIX}g_run`, name: 'Run 4 times a week', habbitID: `${PREFIX}run`, target: 4, period: 'week', customDays: null, repeat: true },
  { id: `${PREFIX}g_read`, name: 'Read 20 days this month', habbitID: `${PREFIX}read`, target: 20, period: 'month', customDays: null, repeat: true },
];

// Mood keys must match DiaryProvider.moods; images match AppColors.moodImages.
const MOODS = ['Puikiai', 'Gerai', 'Normaliai', 'Prastai', 'Blogai'];
const MOOD_IMAGES = ['happy', 'okay', 'neutral', 'eh', 'bad'].map((m) => `assets/ui/emojis/light_mood_${m}.png`);

const diary = [
  { daysAgo: 0, mood: 0, highlight: 'Finished my project presentation', better: 'Go to bed earlier', gratitude: 'My friends cheering me on', text: 'The presentation went really well. Felt proud of how far the project has come.' },
  { daysAgo: 1, mood: 1, highlight: 'Long walk in the park', better: 'Less time on my phone', gratitude: 'Sunny weather', text: 'Calm day. Walked for an hour and listened to a podcast.' },
  { daysAgo: 2, mood: 2, highlight: 'Cooked a new recipe', better: 'Start homework sooner', gratitude: 'A warm dinner', text: 'Nothing special, but the pasta turned out great.' },
  { daysAgo: 4, mood: 1, highlight: 'Morning run, new personal best', better: 'Drink more water', gratitude: 'Feeling healthy', text: 'Ran 5 km faster than ever before.' },
  { daysAgo: 5, mood: 3, highlight: 'Evening with family', better: 'Stress less about exams', gratitude: 'My family', text: 'A bit tired and stressed today, but dinner with family helped.' },
  { daysAgo: 7, mood: 0, highlight: 'Got a great grade', better: 'Keep the routine going', gratitude: 'Supportive teachers', text: 'All the studying paid off!' },
  { daysAgo: 9, mood: 2, highlight: 'Read half a book', better: 'Get outside more', gratitude: 'A quiet afternoon', text: 'Slow rainy day spent reading.' },
  { daysAgo: 12, mood: 1, highlight: 'Meditated for 15 minutes', better: 'Eat breakfast', gratitude: 'Good sleep', text: 'Meditation is getting easier every day.' },
  { daysAgo: 16, mood: 4, highlight: 'Talked things through with a friend', better: 'Ask for help sooner', gratitude: 'People who listen', text: 'Rough day, but talking about it made it lighter.' },
  { daysAgo: 21, mood: 1, highlight: 'Cleaned my room', better: 'Plan the week ahead', gratitude: 'A fresh start', text: 'Tidy room, tidy mind.' },
];

// ─── helpers ─────────────────────────────────────────────────────────────────

const dateKey = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

const daysAgo = (n, hour = 21) => {
  const d = new Date();
  d.setDate(d.getDate() - n);
  d.setHours(hour, Math.floor(Math.random() * 60), 0, 0);
  return d;
};

// Deterministic "random" so re-seeding looks the same.
let seedState = 42;
const rand = () => ((seedState = (seedState * 16807) % 2147483647) / 2147483647);

function entriesForDay(n) {
  const good = rand() < 0.8; // most days are good days
  const e = {
    [`${PREFIX}water`]: { t: 'n', v: good ? 6 + Math.floor(rand() * 4) : 3 + Math.floor(rand() * 3) },
    [`${PREFIX}sleep`]: { t: 'n', v: good ? 4 + Math.floor(rand() * 2) : 2 + Math.floor(rand() * 2) },
    [`${PREFIX}food`]: { t: 'e', v: good ? 'All day' : 'Some' },
  };
  if (rand() < (good ? 0.7 : 0.2)) e[`${PREFIX}run`] = { t: 'b', v: true };
  if (rand() < 0.85) e[`${PREFIX}read`] = { t: 'b', v: true };
  if (rand() < 0.6) e[`${PREFIX}meditate`] = { t: 'b', v: true };
  if (n === 0) delete e[`${PREFIX}meditate`]; // leave something unchecked today
  return e;
}

async function resolveUser(arg) {
  if (arg) return db.collection('users').doc(arg);
  const snap = await db.collection('users').get();
  if (snap.size !== 1) {
    throw new Error(`Found ${snap.size} users; pass the userId: node seed.js <seed|clean> <userId>`);
  }
  return snap.docs[0].ref;
}

// ─── seed ────────────────────────────────────────────────────────────────────

async function seed(userRef) {
  if (fs.existsSync(BACKUP_PATH)) {
    throw new Error('backup.json already exists. Run "clean" first so the original data is not lost.');
  }

  const userSnap = await userRef.get();
  if (!userSnap.exists) throw new Error(`User ${userRef.id} not found`);
  const user = userSnap.data();

  // Back up the user doc and any day logs we are about to touch.
  const logKeys = Array.from({ length: DAYS }, (_, n) => dateKey(daysAgo(n)));
  const logRefs = logKeys.map((k) => userRef.collection('dayLogs').doc(k));
  const logSnaps = await db.getAll(...logRefs);
  const backup = {
    userId: userRef.id,
    user: serialize(user),
    dayLogs: Object.fromEntries(logSnaps.map((s) => [s.id, s.exists ? serialize(s.data()) : null])),
  };
  fs.writeFileSync(BACKUP_PATH, JSON.stringify(backup, null, 2));
  console.log(`Backup written to ${BACKUP_PATH}`);

  const batch = db.batch();

  habits.forEach((h) => batch.set(userRef.collection('habits').doc(h.id), h));
  goals.forEach((g) => batch.set(userRef.collection('goals').doc(g.id), g));

  logSnaps.forEach((s, n) => {
    const existing = s.exists ? s.data().entries || {} : {};
    batch.set(s.ref, { date: s.id, entries: { ...existing, ...entriesForDay(n) } });
  });

  diary.forEach((d, i) => {
    const createdAt = daysAgo(d.daysAgo);
    const preview = d.highlight.length > 50 ? `${d.highlight.slice(0, 47)}...` : d.highlight;
    batch.set(userRef.collection('diary').doc(`${PREFIX}${createdAt.getTime()}_${i}`), {
      createdAt: Timestamp.fromDate(createdAt),
      mood: MOODS[d.mood],
      moodImage: MOOD_IMAGES[d.mood],
      highlight: d.highlight,
      better: d.better,
      gratitude: d.gratitude,
      diaryText: d.text,
      preview,
      imageUrl: null,
      category: null,
    });
  });

  // Nicer-looking stats; owned pets are levelled up a bit.
  const ownedPets = { ...(user.ownedPets || {}) };
  for (const [id, p] of Object.entries(ownedPets)) {
    ownedPets[id] = { ...p, level: Math.max(p.level || 1, 4), xp: 65 };
  }
  batch.update(userRef, {
    level: Math.max(user.level || 1, 7),
    xp: 72,
    coins: Math.max(user.coins || 0, 1250),
    streak: Math.max(user.streak || 0, 12),
    petMood: 'happy',
    ownedPets,
  });

  await batch.commit();
  console.log(`Seeded ${habits.length} habits, ${goals.length} goals, ${DAYS} day logs, ${diary.length} diary entries for ${userRef.id}.`);
}

// ─── clean ───────────────────────────────────────────────────────────────────

async function clean(userRef) {
  if (!fs.existsSync(BACKUP_PATH)) throw new Error('No backup.json found; nothing to restore.');
  const backup = JSON.parse(fs.readFileSync(BACKUP_PATH, 'utf8'));
  if (backup.userId !== userRef.id) throw new Error(`backup.json belongs to user ${backup.userId}`);

  const batch = db.batch();
  for (const sub of ['habits', 'goals', 'diary']) {
    const snap = await userRef.collection(sub).get();
    snap.docs.filter((d) => d.id.startsWith(PREFIX)).forEach((d) => batch.delete(d.ref));
  }
  for (const [key, data] of Object.entries(backup.dayLogs)) {
    const ref = userRef.collection('dayLogs').doc(key);
    if (data) batch.set(ref, deserialize(data));
    else batch.delete(ref);
  }
  batch.set(userRef, deserialize(backup.user));
  await batch.commit();

  fs.renameSync(BACKUP_PATH, BACKUP_PATH.replace('.json', `.restored-${Date.now()}.json`));
  console.log(`Demo data removed and user ${userRef.id} restored.`);
}

// Timestamps don't survive JSON, so tag them.
function serialize(v) {
  if (v instanceof Timestamp) return { __ts: v.toMillis() };
  if (Array.isArray(v)) return v.map(serialize);
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, serialize(x)]));
  return v;
}
function deserialize(v) {
  if (v && typeof v === 'object' && '__ts' in v) return Timestamp.fromMillis(v.__ts);
  if (Array.isArray(v)) return v.map(deserialize);
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, deserialize(x)]));
  return v;
}

// ─── main ────────────────────────────────────────────────────────────────────

(async () => {
  const [mode, userId] = process.argv.slice(2);
  if (!['seed', 'clean'].includes(mode)) {
    console.log('Usage: node seed.js <seed|clean> [userId]');
    process.exit(1);
  }
  const userRef = await resolveUser(userId);
  await (mode === 'seed' ? seed(userRef) : clean(userRef));
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
