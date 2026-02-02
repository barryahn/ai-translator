/* Backfill Firestore users/{uid} for existing Auth users. */
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

function loadServiceAccount() {
  const argPath = process.argv.find((arg) => arg.endsWith(".json"));
  const envPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const jsonPath = argPath || envPath;
  if (!jsonPath) {
    throw new Error(
      "서비스 계정 키 JSON 경로가 필요합니다. 예: node scripts/backfill_users.js /path/to/key.json"
    );
  }
  const absolutePath = path.isAbsolute(jsonPath)
    ? jsonPath
    : path.resolve(process.cwd(), jsonPath);
  const raw = fs.readFileSync(absolutePath, "utf8");
  return JSON.parse(raw);
}

async function main() {
  const isDryRun = process.argv.includes("--dry-run");
  const serviceAccount = loadServiceAccount();
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const db = admin.firestore();
  let nextPageToken;
  let totalUsers = 0;
  let updatedUsers = 0;

  do {
    const result = await admin.auth().listUsers(1000, nextPageToken);
    nextPageToken = result.pageToken;
    totalUsers += result.users.length;

    for (const user of result.users) {
      const docRef = db.collection("users").doc(user.uid);
      const doc = await docRef.get();
      const data = doc.data();
      const hasIsPro =
        data != null && Object.prototype.hasOwnProperty.call(data, "isPro");
      const hasDailyUsage =
        data != null &&
        Object.prototype.hasOwnProperty.call(data, "dailyUsage");
      const hasTotalUsage =
        data != null &&
        Object.prototype.hasOwnProperty.call(data, "totalUsage");
      const hasId =
        data != null && Object.prototype.hasOwnProperty.call(data, "id");

      const updates = {};
      if (!doc.exists || !hasIsPro) {
        updates.isPro = false;
      }
      if (!doc.exists || !hasDailyUsage) {
        updates.dailyUsage = 0;
      }
      if (!doc.exists || !hasTotalUsage) {
        updates.totalUsage = 0;
      }
      if (!doc.exists || !hasId) {
        updates.id = user.email || "";
      }

      if (Object.keys(updates).length > 0) {
        if (!isDryRun) {
          await docRef.set(updates, { merge: true });
        }
        updatedUsers += 1;
      }
    }
  } while (nextPageToken);

  console.log(
    `[done] totalUsers=${totalUsers} updatedUsers=${updatedUsers} dryRun=${isDryRun}`
  );
}

main().catch((err) => {
  console.error("[error]", err);
  process.exit(1);
});
