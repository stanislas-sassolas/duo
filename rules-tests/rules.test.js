// Tests des Security Rules Firestore de Duo.
// Lancer : cd rules-tests && npm test   (démarre l'émulateur Firestore local)
const { test, before, after, beforeEach } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  getDocs,
  query,
  where,
  writeBatch,
  serverTimestamp,
  Timestamp,
} = require("firebase/firestore");

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-duo",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8"),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

const db = (uid) => env.authenticatedContext(uid).firestore();

/** Prépare un couple A (+ B si complet) avec son invitation, sans règles. */
async function seed({ complete = true, inviteActive = !complete, expired = false } = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, "users/alice"), { displayName: "Alice", coupleId: "c1" });
    await setDoc(doc(f, "users/bob"), {
      displayName: "Bob",
      coupleId: complete ? "c1" : null,
    });
    await setDoc(doc(f, "users/eve"), { displayName: "Eve", coupleId: null });
    await setDoc(doc(f, "couples/c1"), {
      userA: "alice",
      userB: complete ? "bob" : null,
      members: complete ? ["alice", "bob"] : ["alice"],
      inviteCode: "LOVE-ABCDEF",
      createdAt: Timestamp.now(),
      lastDrawingAt: null,
    });
    await setDoc(doc(f, "invites/LOVE-ABCDEF"), {
      coupleId: "c1",
      createdBy: "alice",
      active: inviteActive,
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(Date.now() + (expired ? -1 : 1) * 3600e3),
    });
  });
}

function drawingData(overrides = {}) {
  return {
    senderId: "alice",
    receiverId: "bob",
    strokes: [{ p: [{ x: 0.1, y: 0.1, t: 0 }], c: 0, wr: 0.02, t: "pen", ts: 0 }],
    aspectRatio: 0.75,
    message: null,
    replyToDrawingId: null,
    thumbnailUrl: null,
    createdAt: serverTimestamp(),
    viewedAt: null,
    ...overrides,
  };
}

// ---------- Rejoindre un couple ----------

async function join(uid) {
  const f = db(uid);
  const batch = writeBatch(f);
  batch.update(doc(f, "couples/c1"), { userB: uid, members: ["alice", uid] });
  batch.set(doc(f, `users/${uid}`), { coupleId: "c1" }, { merge: true });
  batch.update(doc(f, "invites/LOVE-ABCDEF"), { active: false });
  return batch.commit();
}

test("rejoindre avec une invitation active fonctionne", async () => {
  await seed({ complete: false });
  await assertSucceeds(getDoc(doc(db("bob"), "invites/LOVE-ABCDEF")));
  await assertSucceeds(getDoc(doc(db("bob"), "couples/c1")));
  await assertSucceeds(join("bob"));
});

test("impossible de lister les couples ou les invitations", async () => {
  await seed({ complete: false });
  await assertFails(getDocs(query(collection(db("eve"), "couples"), where("userB", "==", null))));
  await assertFails(getDocs(collection(db("eve"), "invites")));
});

test("rejoindre avec une invitation désactivée ou expirée échoue", async () => {
  await seed({ complete: false, inviteActive: false });
  await assertFails(join("bob"));

  await seed({ complete: false, expired: true });
  await assertFails(join("bob"));
});

test("un couple complet ne peut pas être rejoint", async () => {
  await seed({ complete: true });
  await assertFails(getDoc(doc(db("eve"), "couples/c1")));
  await assertFails(join("eve"));
});

test("on ne peut pas rejoindre son propre couple", async () => {
  await seed({ complete: false });
  const f = db("alice");
  await assertFails(updateDoc(doc(f, "couples/c1"), { userB: "alice", members: ["alice", "alice"] }));
});

test("rejoindre en modifiant d'autres champs échoue", async () => {
  await seed({ complete: false });
  const f = db("bob");
  await assertFails(
    updateDoc(doc(f, "couples/c1"), { userB: "bob", members: ["alice", "bob"], userA: "bob" }),
  );
});

// ---------- Création d'un couple ----------

test("créer un couple et son invitation fonctionne", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "users/eve"), { displayName: "Eve", coupleId: null });
  });
  const f = db("eve");
  const batch = writeBatch(f);
  batch.set(doc(f, "couples/c2"), {
    userA: "eve", userB: null, members: ["eve"], inviteCode: "LOVE-QWERTY",
    createdAt: serverTimestamp(), lastDrawingAt: null,
  });
  batch.set(doc(f, "invites/LOVE-QWERTY"), {
    coupleId: "c2", createdBy: "eve", active: true, createdAt: serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + 3600e3),
  });
  batch.set(doc(f, "users/eve"), { coupleId: "c2" }, { merge: true });
  await assertSucceeds(batch.commit());
});

test("créer une invitation pour le couple de quelqu'un d'autre échoue", async () => {
  await seed({ complete: false });
  await assertFails(
    setDoc(doc(db("eve"), "invites/LOVE-HACKED"), { coupleId: "c1", createdBy: "eve", active: true }),
  );
});

// ---------- Dessins ----------

test("un membre peut envoyer un dessin à son partenaire", async () => {
  await seed();
  await assertSucceeds(setDoc(doc(db("alice"), "couples/c1/drawings/d1"), drawingData()));
});

test("un dessin envoyé par l'ancienne version de l'app (sans aspectRatio) passe", async () => {
  await seed();
  const data = drawingData();
  delete data.aspectRatio;
  await assertSucceeds(setDoc(doc(db("alice"), "couples/c1/drawings/d1"), data));
});

test("un inconnu ne peut ni lire ni écrire les dessins d'un couple", async () => {
  await seed();
  await assertSucceeds(setDoc(doc(db("alice"), "couples/c1/drawings/d1"), drawingData()));
  await assertFails(getDoc(doc(db("eve"), "couples/c1/drawings/d1")));
  await assertFails(getDocs(collection(db("eve"), "couples/c1/drawings")));
  await assertFails(
    setDoc(doc(db("eve"), "couples/c1/drawings/d2"), drawingData({ senderId: "eve" })),
  );
});

test("usurper l'expéditeur, forger la date ou ajouter des champs échoue", async () => {
  await seed();
  const f = db("alice");
  await assertFails(setDoc(doc(f, "couples/c1/drawings/a"), drawingData({ senderId: "bob", receiverId: "alice" })));
  await assertFails(setDoc(doc(f, "couples/c1/drawings/b"), drawingData({ createdAt: Timestamp.fromMillis(0) })));
  await assertFails(setDoc(doc(f, "couples/c1/drawings/c"), drawingData({ viewedAt: serverTimestamp() })));
  await assertFails(setDoc(doc(f, "couples/c1/drawings/d"), drawingData({ admin: true })));
  await assertFails(setDoc(doc(f, "couples/c1/drawings/e"), drawingData({ receiverId: "alice" })));
});

test("réécrire un dessin existant (renvoi) est refusé", async () => {
  await seed();
  const f = db("alice");
  await assertSucceeds(setDoc(doc(f, "couples/c1/drawings/d1"), drawingData()));
  await assertFails(setDoc(doc(f, "couples/c1/drawings/d1"), drawingData()));
  // …mais l'expéditeur peut vérifier qu'il existe (idempotence de l'outbox).
  await assertSucceeds(getDoc(doc(f, "couples/c1/drawings/d1")));
});

test("seul le destinataire peut marquer un dessin comme vu", async () => {
  await seed();
  await assertSucceeds(setDoc(doc(db("alice"), "couples/c1/drawings/d1"), drawingData()));
  await assertFails(
    setDoc(doc(db("alice"), "couples/c1/drawings/d1"), { viewedAt: serverTimestamp() }, { merge: true }),
  );
  await assertSucceeds(
    setDoc(doc(db("bob"), "couples/c1/drawings/d1"), { viewedAt: serverTimestamp() }, { merge: true }),
  );
});

test("un membre met à jour lastDrawingAt, mais pas les membres", async () => {
  await seed();
  const f = db("alice");
  await assertSucceeds(setDoc(doc(f, "couples/c1"), { lastDrawingAt: serverTimestamp() }, { merge: true }));
  await assertFails(updateDoc(doc(f, "couples/c1"), { members: ["alice", "eve"] }));
});

// ---------- Dissociation ----------

async function unlink(uid) {
  const f = db(uid);
  const drawings = await getDocs(collection(f, "couples/c1/drawings"));
  const batch = writeBatch(f);
  drawings.forEach((d) => batch.delete(d.ref));
  await batch.commit();

  const final = writeBatch(f);
  final.set(doc(f, `users/${uid}`), { coupleId: null }, { merge: true });
  final.delete(doc(f, "invites/LOVE-ABCDEF"));
  final.delete(doc(f, "couples/c1"));
  return final.commit();
}

test("le partenaire qui a rejoint (userB) peut dissocier et tout effacer", async () => {
  await seed();
  await assertSucceeds(setDoc(doc(db("alice"), "couples/c1/drawings/d1"), drawingData()));
  await assertSucceeds(unlink("bob"));
  await env.withSecurityRulesDisabled(async (ctx) => {
    const snap = await getDocs(collection(ctx.firestore(), "couples/c1/drawings"));
    assert.strictEqual(snap.size, 0);
  });
});

test("après dissociation, l'ex-partenaire peut former un nouveau couple", async () => {
  await seed();
  await assertSucceeds(unlink("alice"));
  // Bob a encore coupleId = c1 (couple supprimé) : il doit pouvoir rejoindre.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, "couples/c3"), {
      userA: "eve", userB: null, members: ["eve"], inviteCode: "LOVE-NEWONE",
    });
    await setDoc(doc(f, "invites/LOVE-NEWONE"), { coupleId: "c3", createdBy: "eve", active: true });
  });
  const f = db("bob");
  const batch = writeBatch(f);
  batch.update(doc(f, "couples/c3"), { userB: "bob", members: ["eve", "bob"] });
  batch.set(doc(f, "users/bob"), { coupleId: "c3" }, { merge: true });
  batch.update(doc(f, "invites/LOVE-NEWONE"), { active: false });
  await assertSucceeds(batch.commit());
});

test("un inconnu ne peut pas supprimer un couple ou ses dessins", async () => {
  await seed();
  await assertSucceeds(setDoc(doc(db("alice"), "couples/c1/drawings/d1"), drawingData()));
  await assertFails(deleteDoc(doc(db("eve"), "couples/c1/drawings/d1")));
  await assertFails(deleteDoc(doc(db("eve"), "couples/c1")));
});

// ---------- Profils ----------

test("profils : lecture du partenaire oui, d'un inconnu non", async () => {
  await seed();
  await assertSucceeds(getDoc(doc(db("alice"), "users/bob")));
  await assertFails(getDoc(doc(db("eve"), "users/alice")));
  await assertFails(setDoc(doc(db("eve"), "users/alice"), { displayName: "pirate" }));
});

test("petits mots : privés, même pour le partenaire", async () => {
  await seed();
  await assertSucceeds(
    setDoc(doc(db("alice"), "users/alice/private/phrases"), { items: ["❤️ Mon amour"] }),
  );
  await assertSucceeds(getDoc(doc(db("alice"), "users/alice/private/phrases")));
  await assertFails(getDoc(doc(db("bob"), "users/alice/private/phrases")));
  await assertFails(setDoc(doc(db("bob"), "users/alice/private/phrases"), { items: [] }));
});

test("un dessin avec un petit mot passe, un mot trop long non", async () => {
  await seed();
  const f = db("alice");
  await assertSucceeds(setDoc(doc(f, "couples/c1/drawings/m1"), drawingData({ message: "❤️ Bisous" })));
  await assertFails(setDoc(doc(f, "couples/c1/drawings/m2"), drawingData({ message: "x".repeat(141) })));
});

test("lire un couple qui n'existe pas (encore / plus) renvoie vide sans erreur", async () => {
  await seed();
  const snap = await assertSucceeds(getDoc(doc(db("bob"), "couples/inexistant")));
  assert.strictEqual(snap.exists(), false);
});

test("réactions : seul le destinataire réagit, avec un emoji court", async () => {
  await seed();
  await assertSucceeds(setDoc(doc(db("alice"), "couples/c1/drawings/r1"), drawingData()));
  await assertSucceeds(
    setDoc(doc(db("bob"), "couples/c1/drawings/r1"), { reaction: "❤️" }, { merge: true }),
  );
  await assertSucceeds(
    setDoc(doc(db("bob"), "couples/c1/drawings/r1"), { reaction: null }, { merge: true }),
  );
  await assertFails(
    setDoc(doc(db("alice"), "couples/c1/drawings/r1"), { reaction: "❤️" }, { merge: true }),
  );
  await assertFails(
    setDoc(doc(db("bob"), "couples/c1/drawings/r1"), { reaction: "x".repeat(50) }, { merge: true }),
  );
});

test("stickers : partagés dans le couple, invisibles pour les autres", async () => {
  await seed();
  const sticker = { data: "iVBORw0KGgo=", createdBy: "alice", createdAt: serverTimestamp(), hidden: false };
  await assertSucceeds(setDoc(doc(db("alice"), "couples/c1/stickers/s1"), sticker));
  await assertSucceeds(getDoc(doc(db("bob"), "couples/c1/stickers/s1")));
  await assertSucceeds(updateDoc(doc(db("bob"), "couples/c1/stickers/s1"), { hidden: true }));
  await assertFails(getDoc(doc(db("eve"), "couples/c1/stickers/s1")));
  await assertFails(setDoc(doc(db("eve"), "couples/c1/stickers/s2"), { ...sticker, createdBy: "eve" }));
  await assertFails(
    setDoc(doc(db("alice"), "couples/c1/stickers/s3"), { ...sticker, data: "x".repeat(300001) }),
  );
});

test("un dessin avec des stickers passe (30 maximum)", async () => {
  await seed();
  const f = db("alice");
  const one = { e: "🐞", x: 0.5, y: 0.5, w: 0.3, r: 0 };
  await assertSucceeds(setDoc(doc(f, "couples/c1/drawings/st1"), drawingData({ stickers: [one] })));
  await assertFails(
    setDoc(doc(f, "couples/c1/drawings/st2"), drawingData({ stickers: Array(31).fill(one) })),
  );
});
