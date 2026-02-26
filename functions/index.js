const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();
const db = admin.firestore();

// ─── Helper: Verify Firebase Auth Token ───

async function verifyAuth(req) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        throw new functions.https.HttpsError("unauthenticated", "No token provided");
    }
    const idToken = authHeader.split("Bearer ")[1];
    return await admin.auth().verifyIdToken(idToken);
}

// ─── Helper: Send FCM Notification ───

async function sendNotification(uid, title, body) {
    const userDoc = await db.collection("users").doc(uid).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return;

    try {
        await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            android: {
                notification: {
                    channelId: "usage_alerts",
                },
            },
        });
    } catch (err) {
        console.error("FCM send error:", err);
    }
}

// ═══════════════════════════════════════════════
// 1. FREE TIER PROXY — Chutes.ai
// ═══════════════════════════════════════════════

exports.freeTierProxy = functions
    .runWith({ secrets: ["CHUTES_API_KEY"], timeoutSeconds: 120, memory: "256MB" })
    .https.onRequest(async (req, res) => {
        // CORS
        res.set("Access-Control-Allow-Origin", "*");
        res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
        if (req.method === "OPTIONS") { res.status(204).send(""); return; }

        try {
            const decoded = await verifyAuth(req);
            const uid = decoded.uid;

            // Check quota
            const userRef = db.collection("users").doc(uid);
            const userDoc = await userRef.get();
            const userData = userDoc.data();

            if (!userData || userData.freeMessagesRemaining <= 0) {
                res.status(403).json({ error: { message: "Free messages exhausted. Add your own API key or subscribe to Pro." } });
                return;
            }

            // Forward to Chutes.ai with Geepity system prompt
            const geepitySystemPrompt = {
                role: "system",
                content: "You are Geepity, a helpful AI assistant. You are friendly, knowledgeable, and concise. Never refer to yourself as GPT, GPT-OSS, or any other model name — you are Geepity."
            };
            const messagesWithPrompt = [geepitySystemPrompt, ...req.body.messages];

            // Use model from request or default
            const requestedModel = req.body.model || "openai/openai/gpt-oss-120b-TEE";

            const chutesResponse = await fetch("https://llm.chutes.ai/v1/chat/completions", {
                method: "POST",
                headers: {
                    "Authorization": `Bearer ${process.env.CHUTES_API_KEY}`,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    model: requestedModel,
                    messages: messagesWithPrompt,
                    stream: true,
                    max_tokens: 2048,
                    temperature: 0.7,
                }),
            });

            if (!chutesResponse.ok) {
                const errorText = await chutesResponse.text();
                res.status(chutesResponse.status).json({ error: { message: errorText } });
                return;
            }

            // Stream SSE response
            res.set("Content-Type", "text/event-stream");
            res.set("Cache-Control", "no-cache");
            res.set("Connection", "keep-alive");

            chutesResponse.body.on("data", (chunk) => {
                res.write(chunk);
            });

            chutesResponse.body.on("end", async () => {
                res.end();

                // Atomically decrement counter
                try {
                    const currentCount = userData.freeMessagesRemaining;
                    // Fix NaN or missing values — reset to 100
                    if (currentCount === undefined || currentCount === null || isNaN(currentCount)) {
                        await userRef.update({ freeMessagesRemaining: 99 });
                    } else {
                        await userRef.update({
                            freeMessagesRemaining: admin.firestore.FieldValue.increment(-1)
                        });
                    }

                    // Re-read for notification thresholds
                    const updatedDoc = await userRef.get();
                    const newCount = updatedDoc.data().freeMessagesRemaining;

                    if (newCount === 10) {
                        await sendNotification(uid, "Geepity", "You have 10 free messages left in Geepity");
                    }
                    if (newCount === 0) {
                        await sendNotification(uid, "Geepity", "Free messages used up — add your Z.ai key or go Pro");
                    }
                } catch (err) {
                    console.error("Error updating counter:", err);
                }
            });

            chutesResponse.body.on("error", (err) => {
                console.error("Stream error:", err);
                res.end();
            });

        } catch (err) {
            console.error("freeTierProxy error:", err);
            res.status(500).json({ error: { message: err.message } });
        }
    });

// ═══════════════════════════════════════════════
// 2. PRO TIER PROXY — Z.ai
// ═══════════════════════════════════════════════

exports.proTierProxy = functions
    .runWith({ secrets: ["OPENROUTER_API_KEY"], timeoutSeconds: 120, memory: "256MB" })
    .https.onRequest(async (req, res) => {
        // CORS
        res.set("Access-Control-Allow-Origin", "*");
        res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
        if (req.method === "OPTIONS") { res.status(204).send(""); return; }

        try {
            const decoded = await verifyAuth(req);
            const uid = decoded.uid;

            // Check subscription
            const userRef = db.collection("users").doc(uid);
            const userDoc = await userRef.get();
            const userData = userDoc.data();

            if (!userData || userData.subscriptionTier !== "pro") {
                res.status(403).json({ error: { message: "Pro subscription required." } });
                return;
            }

            if (userData.subscriptionExpiry && userData.subscriptionExpiry.toDate() < new Date()) {
                res.status(403).json({ error: { message: "Pro subscription expired." } });
                return;
            }

            if (userData.proMessagesUsedThisMonth >= 500) {
                res.status(403).json({ error: { message: "Pro messages used up for this month — resets on the 1st." } });
                return;
            }

            // Validate model — only Pro-tier models through OpenRouter
            const allowedModels = [
                "google/gemini-2.5-pro-preview",
                "anthropic/claude-sonnet-4",
                "anthropic/claude-opus-4",
                "openai/gpt-4.1",
            ];
            const model = allowedModels.includes(req.body.model) ? req.body.model : "google/gemini-2.5-pro-preview";

            // Forward to OpenRouter
            const orResponse = await fetch("https://openrouter.ai/api/v1/chat/completions", {
                method: "POST",
                headers: {
                    "Authorization": `Bearer ${process.env.OPENROUTER_API_KEY}`,
                    "Content-Type": "application/json",
                    "HTTP-Referer": "https://geepity.com",
                    "X-Title": "Geepity",
                },
                body: JSON.stringify({
                    model: model,
                    messages: req.body.messages,
                    stream: true,
                    max_tokens: 4096,
                }),
            });

            if (!orResponse.ok) {
                const errorText = await orResponse.text();
                res.status(orResponse.status).json({ error: { message: errorText } });
                return;
            }

            // Stream SSE
            res.set("Content-Type", "text/event-stream");
            res.set("Cache-Control", "no-cache");
            res.set("Connection", "keep-alive");

            orResponse.body.on("data", (chunk) => {
                res.write(chunk);
            });

            orResponse.body.on("end", async () => {
                res.end();

                // Atomically increment counter
                try {
                    await userRef.update({
                        proMessagesUsedThisMonth: admin.firestore.FieldValue.increment(1)
                    });

                    const updatedDoc = await userRef.get();
                    const newCount = updatedDoc.data().proMessagesUsedThisMonth;

                    if (newCount === 450) {
                        await sendNotification(uid, "Geepity", "You've used 450 of 500 Pro messages this month");
                    }
                    if (newCount === 500) {
                        await sendNotification(uid, "Geepity", "Pro messages used up for this month — resets on the 1st");
                    }
                } catch (err) {
                    console.error("Error updating pro counter:", err);
                }
            });

            orResponse.body.on("error", (err) => {
                console.error("Stream error:", err);
                res.end();
            });

        } catch (err) {
            console.error("proTierProxy error:", err);
            res.status(500).json({ error: { message: err.message } });
        }
    });

// ═══════════════════════════════════════════════
// 3. REVENUECAT WEBHOOK
// ═══════════════════════════════════════════════

exports.revenueCatWebhook = functions
    .runWith({ secrets: ["REVENUECAT_WEBHOOK_SECRET"] })
    .https.onRequest(async (req, res) => {
        try {
            // Validate webhook secret (optional — if set in RevenueCat dashboard)
            const webhookSecret = process.env.REVENUECAT_WEBHOOK_SECRET;
            const authHeader = req.headers.authorization;
            if (webhookSecret && webhookSecret !== 'placeholder_revenuecat_webhook_secret') {
                if (authHeader !== `Bearer ${webhookSecret}`) {
                    res.status(401).json({ error: "Unauthorized" });
                    return;
                }
            }

            const event = req.body.event;
            if (!event) {
                res.status(400).json({ error: "No event data" });
                return;
            }

            const appUserId = event.app_user_id; // Firebase UID
            const eventType = event.type;

            if (!appUserId) {
                res.status(400).json({ error: "No app_user_id" });
                return;
            }

            const userRef = db.collection("users").doc(appUserId);

            switch (eventType) {
                case "INITIAL_PURCHASE":
                case "RENEWAL":
                case "PRODUCT_CHANGE":
                    const expirationDate = event.expiration_at_ms
                        ? new Date(event.expiration_at_ms)
                        : null;
                    await userRef.update({
                        subscriptionTier: "pro",
                        subscriptionExpiry: expirationDate
                            ? admin.firestore.Timestamp.fromDate(expirationDate)
                            : null,
                    });
                    break;

                case "CANCELLATION":
                case "EXPIRATION":
                    await userRef.update({
                        subscriptionTier: "free",
                        subscriptionExpiry: null,
                    });
                    break;

                case "BILLING_ISSUE":
                    await sendNotification(
                        appUserId,
                        "Geepity",
                        "There's an issue with your subscription payment. Please update your payment method."
                    );
                    break;

                default:
                    console.log("Unhandled RevenueCat event:", eventType);
            }

            res.status(200).json({ received: true });
        } catch (err) {
            console.error("revenueCatWebhook error:", err);
            res.status(500).json({ error: err.message });
        }
    });

// ═══════════════════════════════════════════════
// 4. MONTHLY USAGE RESET (Scheduled)
// ═══════════════════════════════════════════════

exports.monthlyUsageReset = functions.pubsub
    .schedule("0 0 1 * *")  // 00:00 UTC on the 1st of each month
    .timeZone("UTC")
    .onRun(async (context) => {
        try {
            // Query all Pro users
            const proUsers = await db.collection("users")
                .where("subscriptionTier", "==", "pro")
                .get();

            const batch = db.batch();
            const notifications = [];

            proUsers.forEach((doc) => {
                batch.update(doc.ref, { proMessagesUsedThisMonth: 0 });
                notifications.push(
                    sendNotification(doc.id, "Geepity", "Your 500 Pro messages have been refreshed!")
                );
            });

            await batch.commit();
            await Promise.all(notifications);

            console.log(`Reset monthly usage for ${proUsers.size} Pro users`);
        } catch (err) {
            console.error("monthlyUsageReset error:", err);
        }
    });
