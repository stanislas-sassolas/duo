/**
 * Cloud Functions Duo.
 *
 * Envoie une notification push au destinataire à chaque nouveau dessin.
 * C'est le SEUL endroit de confiance pour déclencher un FCM : jamais depuis le
 * client (qui ne doit pas détenir de clé serveur).
 */
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.onDrawingCreated = onDocumentCreated(
  "couples/{coupleId}/drawings/{drawingId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const drawing = snap.data();

    const receiverId = drawing.receiverId;
    const senderId = drawing.senderId;
    if (!receiverId || !senderId) return;

    const db = getFirestore();

    // Jetons du destinataire + prénom de l'expéditeur.
    const [receiverDoc, senderDoc] = await Promise.all([
      db.collection("users").doc(receiverId).get(),
      db.collection("users").doc(senderId).get(),
    ]);

    const tokens = (receiverDoc.get("fcmTokens") || []).filter(Boolean);
    if (tokens.length === 0) return;

    const senderName = senderDoc.get("displayName") || "Quelqu'un";
    const isReply = Boolean(drawing.replyToDrawingId);

    const message = {
      tokens,
      notification: {
        title: `${senderName} t'a envoyé un dessin ❤️`,
        body: isReply ? "Une réponse pour toi" : "Ouvre pour le découvrir",
      },
      data: {
        type: "drawing",
        coupleId: event.params.coupleId,
        drawingId: event.params.drawingId,
      },
      android: { priority: "high" },
      apns: {
        payload: { aps: { sound: "default" } },
      },
    };

    const response = await getMessaging().sendEachForMulticast(message);

    // Nettoyage des jetons invalides (désinstallation, etc.).
    const stale = [];
    response.responses.forEach((res, index) => {
      if (
        !res.success &&
        res.error &&
        (res.error.code === "messaging/registration-token-not-registered" ||
          res.error.code === "messaging/invalid-registration-token")
      ) {
        stale.push(tokens[index]);
      }
    });

    if (stale.length > 0) {
      const { FieldValue } = require("firebase-admin/firestore");
      await db
        .collection("users")
        .doc(receiverId)
        .update({ fcmTokens: FieldValue.arrayRemove(...stale) });
    }
  }
);
