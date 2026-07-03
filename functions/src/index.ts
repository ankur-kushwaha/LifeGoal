import * as admin from "firebase-admin";
import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { generateAINotification, buildGoalContext, buildFamilyProfileContext } from "./ai";
import { saveNotification, getRecentNotifications } from "./notifications";

admin.initializeApp();

const openRouterKey = defineSecret("OPENROUTER_API_KEY");
const db = () => getFirestore(admin.app(), "lifegoal");

async function isFamilyMember(familyId: string, userId: string): Promise<boolean> {
  const doc = await db()
    .collection("families")
    .doc(familyId)
    .collection("members")
    .doc(userId)
    .get();
  return doc.exists;
}

async function generateForFamily(
  familyId: string,
  trigger: string,
  eventName?: string,
  relatedGoalId?: string,
): Promise<import("./notifications").SavedNotification> {
  const firestore = db();
  const familyDoc = await firestore.collection("families").doc(familyId).get();
  if (!familyDoc.exists) {
    throw new HttpsError("not-found", "Family not found");
  }

  const familyData = familyDoc.data() ?? {};
  const goalsSnapshot = await firestore
    .collection("families")
    .doc(familyId)
    .collection("goals")
    .get();

  const goals = goalsSnapshot.docs.map((doc) => doc.data());
  const membersSnapshot = await firestore
    .collection("families")
    .doc(familyId)
    .collection("members")
    .get();
  const memberProfiles = membersSnapshot.docs.map((doc) => {
    const data = doc.data();
    const name =
      (data.displayName as string | undefined) ||
      (data.email as string | undefined) ||
      doc.id;
    return {
      name,
      profile: data.memberProfile as Record<string, unknown> | undefined,
    };
  });
  const recent = await getRecentNotifications(familyId, 5);
  const goalContext = buildGoalContext(
    goals,
    familyData.globalInflation ?? 6,
    familyData.globalReturn ?? 14,
    familyData.today ?? new Date().toISOString(),
  );
  const profileContext = buildFamilyProfileContext(
    familyData.familyProfile as Record<string, unknown> | undefined,
    memberProfiles,
  );
  const context = goalContext;

  const apiKey = openRouterKey.value();
  if (!apiKey) {
    throw new HttpsError("failed-precondition", "OPENROUTER_API_KEY secret is not configured");
  }

  let aiResult;
  try {
    aiResult = await generateAINotification({
      apiKey,
      goalContext: context,
      profileContext,
      recentNotifications: recent,
      trigger,
      eventName,
      relatedGoalId,
    });

    const blockedIds = new Set(
      recent.map((n) => n.relatedGoalId).filter((id): id is string => Boolean(id)),
    );
    if (
      aiResult.relatedGoalId &&
      blockedIds.has(aiResult.relatedGoalId) &&
      recent.length > 0
    ) {
      console.log(
        `AI repeated goal ${aiResult.relatedGoalId}, retrying with blocked list`,
      );
      aiResult = await generateAINotification({
        apiKey,
        goalContext: context,
        profileContext,
        recentNotifications: recent,
        trigger,
        eventName,
        relatedGoalId,
      });
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "AI generation failed";
    console.error("OpenRouter generation failed:", message);
    throw new HttpsError("internal", message);
  }

  const notification = await saveNotification(familyId, {
    title: aiResult.title,
    body: aiResult.body,
    suggestedAction: aiResult.suggestedAction,
    trigger,
    eventName,
    relatedGoalId: aiResult.relatedGoalId ?? relatedGoalId,
    suggestionType: aiResult.suggestionType,
    suggestedNewGoalName: aiResult.suggestedNewGoalName,
    suggestedNewGoalTargetCost: aiResult.suggestedNewGoalTargetCost,
    suggestedNewGoalMonths: aiResult.suggestedNewGoalMonths,
    suggestedNewGoalAccount: aiResult.suggestedNewGoalAccount,
  });

  return notification;
}

export const generateNotification = onCall(
  {
    region: "asia-south1",
    secrets: [openRouterKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }

    const familyId = request.data.familyId as string | undefined;
    const trigger = (request.data.trigger as string | undefined) ?? "custom";
    const eventName = request.data.eventName as string | undefined;
    const relatedGoalId = request.data.relatedGoalId as string | undefined;

    if (!familyId) {
      throw new HttpsError("invalid-argument", "familyId is required");
    }

    const member = await isFamilyMember(familyId, request.auth.uid);
    if (!member) {
      throw new HttpsError("permission-denied", "Not a family member");
    }

    const notification = await generateForFamily(
      familyId,
      trigger,
      eventName,
      relatedGoalId,
    );

    return { notification };
  },
);

export const scheduledDailyNotifications = onSchedule(
  {
    schedule: "0 10 * * *",
    timeZone: "Asia/Kolkata",
    region: "asia-south1",
    secrets: [openRouterKey],
  },
  async () => {
    const familiesSnapshot = await db().collection("families").get();

    for (const familyDoc of familiesSnapshot.docs) {
      try {
        await generateForFamily(familyDoc.id, "scheduled", "scheduled_10am");
      } catch (error) {
        console.error(`Scheduled notification failed for ${familyDoc.id}:`, error);
      }
    }
  },
);
