// Partenaire simulé pour tester Duo de bout en bout avec un seul téléphone.
//
// Usage (depuis rules-tests/) :
//   node partner-sim.js join LOVE-XXXXXX   → crée un compte "Testeur", rejoint
//                                            l'espace, envoie un dessin, puis
//                                            attend les dessins reçus (Ctrl+C).
//
// Pour nettoyer : « Dissocier le partenaire » dans l'app efface le couple et
// tous ses dessins (seul reste le petit profil "Testeur").
const fs = require("node:fs");
const path = require("node:path");
const { initializeApp } = require("firebase/app");
const {
  getAuth,
  signInAnonymously,
  inMemoryPersistence,
  setPersistence,
} = require("firebase/auth");
const {
  getFirestore,
  doc,
  getDoc,
  setDoc,
  runTransaction,
  writeBatch,
  collection,
  query,
  where,
  onSnapshot,
  serverTimestamp,
} = require("firebase/firestore");

const app = initializeApp({
  apiKey: process.env.DUO_API_KEY,
  authDomain: "your-firebase-project.firebaseapp.com",
  projectId: "your-firebase-project",
});
const auth = getAuth(app);
const db = getFirestore(app);
const STATE = path.join(__dirname, ".partner-sim.json");

function heartStrokes() {
  // Un petit cœur, coordonnées normalisées.
  const pts = [];
  for (let i = 0; i <= 60; i++) {
    const t = (i / 60) * 2 * Math.PI;
    const x = 16 * Math.sin(t) ** 3;
    const y = 13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t);
    pts.push({ x: +(0.5 + x / 45).toFixed(4), y: +(0.45 - y / 45).toFixed(4), t: i * 16 });
  }
  return [{ p: pts, c: 0xffe53935, wr: 0.025, t: "pen", ts: Date.now() }];
}

async function join(code) {
  await setPersistence(auth, inMemoryPersistence);
  const { user } = await signInAnonymously(auth);
  const uid = user.uid;
  fs.writeFileSync(STATE, JSON.stringify({ uid, refreshToken: user.refreshToken }));
  console.log("Compte test :", uid);

  await setDoc(doc(db, "users", uid), {
    displayName: process.env.SIM_NAME || "Testeur",
    signature: process.env.SIM_SIGNATURE || "",
    photoUrl: null,
    coupleId: null,
    fcmTokens: [],
    createdAt: serverTimestamp(),
  });

  const invite = await getDoc(doc(db, "invites", code));
  if (!invite.exists()) throw new Error("Code inconnu");
  const coupleId = invite.data().coupleId;

  await runTransaction(db, async (tx) => {
    const c = await tx.get(doc(db, "couples", coupleId));
    const userA = c.data().userA;
    tx.update(doc(db, "couples", coupleId), { userB: uid, members: [userA, uid] });
    tx.set(doc(db, "users", uid), { coupleId }, { merge: true });
    tx.update(doc(db, "invites", code), { active: false });
  });
  const couple = (await getDoc(doc(db, "couples", coupleId))).data();
  console.log("Couple rejoint :", coupleId);
  fs.writeFileSync(STATE, JSON.stringify({ uid, coupleId }));

  const drawingId = `sim-${Date.now()}`;
  const batch = writeBatch(db);
  batch.set(doc(db, "couples", coupleId, "drawings", drawingId), {
    senderId: uid,
    receiverId: couple.userA,
    strokes: heartStrokes(),
    aspectRatio: 0.75,
    message: process.env.SIM_MESSAGE || null,
    replyToDrawingId: null,
    thumbnailUrl: null,
    createdAt: serverTimestamp(),
    viewedAt: null,
  });
  batch.set(doc(db, "couples", coupleId), { lastDrawingAt: serverTimestamp() }, { merge: true });
  await batch.commit();
  console.log("Dessin envoyé :", drawingId);

  // Second dessin différé (pour tester la notification app en arrière-plan).
  const extraAfter = Number(process.env.EXTRA_SEND_AFTER_MS || 0);
  if (extraAfter) {
    setTimeout(async () => {
      const id2 = `sim-${Date.now()}`;
      await setDoc(doc(db, "couples", coupleId, "drawings", id2), {
        senderId: uid, receiverId: couple.userA, strokes: heartStrokes(),
        aspectRatio: 0.75, message: null, replyToDrawingId: null,
        thumbnailUrl: null, createdAt: serverTimestamp(), viewedAt: null,
      });
      console.log("Second dessin envoyé :", id2);
    }, extraAfter);
  }

  const seen = new Set();
  onSnapshot(
    query(collection(db, "couples", coupleId, "drawings"), where("receiverId", "==", uid)),
    (snap) => {
      snap.docs.forEach((d) => {
        if (seen.has(d.id)) return;
        seen.add(d.id);
        const data = d.data();
        const points = data.strokes.reduce((n, s) => n + s.p.length, 0);
        console.log(
          `Dessin reçu : ${d.id} (${data.strokes.length} traits, ${points} points,` +
            ` ratio ${data.aspectRatio}, réponse à ${data.replyToDrawingId},` +
            ` petit mot : ${data.message})`,
        );
        // Réaction automatique (ex. SIM_REACT=❤️) quelques secondes après.
        if (process.env.SIM_REACT) {
          setTimeout(async () => {
            await setDoc(d.ref, { reaction: process.env.SIM_REACT }, { merge: true });
            console.log(`Réaction envoyée : ${process.env.SIM_REACT} sur ${d.id}`);
          }, 4000);
        }
      });
    },
    (err) => console.log("Écoute impossible :", err.code),
  );
  // Réactions posées par l'autre sur les dessins du partenaire simulé.
  const reactions = new Map();
  onSnapshot(
    query(collection(db, "couples", coupleId, "drawings"), where("senderId", "==", uid)),
    (snap) => {
      snap.docs.forEach((d) => {
        const r = d.data().reaction ?? null;
        if (reactions.has(d.id) && reactions.get(d.id) !== r) {
          console.log(`Réaction reçue sur ${d.id} : ${r}`);
        }
        reactions.set(d.id, r);
      });
    },
    () => {},
  );

  const waitMs = Number(process.env.WAIT_MS || 0);
  if (waitMs) setTimeout(() => process.exit(0), waitMs);
}

module.exports = { join };
if (require.main === module) {
  const [cmd, arg] = process.argv.slice(2);
  if (cmd === "join") join(arg).catch((e) => { console.error("Échec :", e.code || e.message); process.exit(1); });
  else console.log("Usage : node partner-sim.js join LOVE-XXXXXX");
}
