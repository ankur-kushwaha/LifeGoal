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

export const getAllFamiliesAdmin = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const userEmail = request.auth?.token?.email?.toLowerCase() ?? "";
    const isSuperAdminEmail =
      userEmail === "ankur.kus1@gmail.com" ||
      userEmail === "admin@lifegoal.ai" ||
      userEmail === "ankurkushwaha@gmail.com" ||
      userEmail.endsWith("@lifegoal.ai");

    const pin = (request.data?.pin as string | undefined) ?? "";
    const isPinValid = pin === "8899";

    if (!isSuperAdminEmail && !isPinValid) {
      throw new HttpsError(
        "permission-denied",
        "Only super admin with authorized email or master PIN can fetch all families.",
      );
    }

    const firestore = db();
    const familiesSnapshot = await firestore.collection("families").get();

    const results = await Promise.all(
      familiesSnapshot.docs.map(async (doc) => {
        const familyId = doc.id;
        const familyData = doc.data() ?? {};

        const [membersSnap, goalsSnap] = await Promise.all([
          firestore
            .collection("families")
            .doc(familyId)
            .collection("members")
            .get(),
          firestore
            .collection("families")
            .doc(familyId)
            .collection("goals")
            .get(),
        ]);

        const members = membersSnap.docs.map((m) => {
          const mData = m.data();
          return {
            userId: m.id,
            ...mData,
          };
        });

        const goals = goalsSnap.docs.map((g) => {
          const gData = g.data();
          return {
            id: g.id,
            ...gData,
          };
        });

        return {
          family: {
            id: familyId,
            name: familyData.name ?? "Family",
            adminId: familyData.adminId ?? "",
            createdAt: familyData.createdAt ?? new Date().toISOString(),
          },
          globalInflation: familyData.globalInflation ?? 6,
          globalReturn: familyData.globalReturn ?? 14,
          today: familyData.today ?? new Date().toISOString(),
          members,
          goals,
        };
      }),
    );

    return { families: results };
  },
);

export const deleteFamilyAdmin = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const userEmail = request.auth?.token?.email?.toLowerCase() ?? "";
    const isSuperAdminEmail =
      userEmail === "ankur.kus1@gmail.com" ||
      userEmail === "admin@lifegoal.ai" ||
      userEmail === "ankurkushwaha@gmail.com" ||
      userEmail.endsWith("@lifegoal.ai");

    const pin = (request.data?.pin as string | undefined) ?? "";
    const isPinValid = pin === "8899";

    if (!isSuperAdminEmail && !isPinValid) {
      throw new HttpsError(
        "permission-denied",
        "Only super admin with authorized email or master PIN can delete families.",
      );
    }

    const familyId = request.data?.familyId as string | undefined;
    if (!familyId || typeof familyId !== "string" || familyId.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Valid familyId is required.");
    }

    const firestore = db();
    const familyRef = firestore.collection("families").doc(familyId);
    const familyDoc = await familyRef.get();

    if (!familyDoc.exists) {
      return { success: true, message: "Family not found or already deleted." };
    }

    // Delete family and all nested subcollections recursively
    await firestore.recursiveDelete(familyRef);

    return { success: true, familyId };
  },
);

export const manageFamilyMemberAdmin = onCall(
  {
    region: "asia-south1",
  },
  async (request) => {
    const userEmail = request.auth?.token?.email?.toLowerCase() ?? "";
    const isSuperAdminEmail =
      userEmail === "ankur.kus1@gmail.com" ||
      userEmail === "admin@lifegoal.ai" ||
      userEmail === "ankurkushwaha@gmail.com" ||
      userEmail.endsWith("@lifegoal.ai");

    const pin = (request.data?.pin as string | undefined) ?? "";
    const isPinValid = pin === "8899";

    if (!isSuperAdminEmail && !isPinValid) {
      throw new HttpsError(
        "permission-denied",
        "Only super admin with authorized email or master PIN can manage family members.",
      );
    }

    const action = request.data?.action as string | undefined; // 'add' | 'update' | 'remove'
    const familyId = request.data?.familyId as string | undefined;

    if (!familyId || !action) {
      throw new HttpsError("invalid-argument", "familyId and action are required.");
    }

    const firestore = db();
    const familyRef = firestore.collection("families").doc(familyId);
    const familyDoc = await familyRef.get();
    if (!familyDoc.exists) {
      throw new HttpsError("not-found", "Family not found.");
    }
    const familyData = familyDoc.data() ?? {};

    if (action === "add") {
      const email = (request.data?.email as string | undefined)?.trim().toLowerCase() ?? "";
      if (!email || !email.includes("@")) {
        throw new HttpsError("invalid-argument", "A valid email is required.");
      }
      const displayName = (request.data?.displayName as string | undefined)?.trim() || null;
      const role = (request.data?.role as string | undefined) === "admin" ? "admin" : "member";
      const memberProfile = (request.data?.memberProfile as Record<string, unknown> | undefined) ?? {};
      const makePrimaryAdmin = Boolean(request.data?.makePrimaryAdmin);

      // Check if user exists in Firebase Auth
      let userId: string;
      try {
        const authUser = await admin.auth().getUserByEmail(email);
        userId = authUser.uid;
      } catch {
        userId = firestore.collection("users").doc().id;
      }

      const joinedAt = new Date().toISOString();
      const memberData: Record<string, unknown> = {
        email,
        displayName: displayName || email.split("@")[0],
        role,
        joinedAt,
        memberProfile,
      };

      const batch = firestore.batch();
      batch.set(familyRef.collection("members").doc(userId), memberData, { merge: true });
      batch.set(firestore.collection("users").doc(userId), {
        familyId,
        email,
        ...(displayName ? { displayName } : {}),
      }, { merge: true });

      if (makePrimaryAdmin || !familyData.adminId) {
        batch.update(familyRef, { adminId: userId });
      }

      await batch.commit();

      return {
        success: true,
        action: "add",
        member: {
          userId,
          ...memberData,
        },
        familyAdminId: makePrimaryAdmin || !familyData.adminId ? userId : familyData.adminId,
      };
    }

    if (action === "update") {
      const memberId = request.data?.memberId as string | undefined;
      if (!memberId) {
        throw new HttpsError("invalid-argument", "memberId is required for update.");
      }
      const memberRef = familyRef.collection("members").doc(memberId);
      const memberDoc = await memberRef.get();
      if (!memberDoc.exists) {
        throw new HttpsError("not-found", "Member not found in family.");
      }

      const updateData: Record<string, unknown> = {};
      if (request.data?.displayName !== undefined) {
        updateData.displayName = (request.data.displayName as string).trim();
      }
      if (request.data?.role !== undefined) {
        updateData.role = request.data.role === "admin" ? "admin" : "member";
      }
      if (request.data?.memberProfile !== undefined) {
        updateData.memberProfile = request.data.memberProfile;
      }

      const makePrimaryAdmin = Boolean(request.data?.makePrimaryAdmin);

      const batch = firestore.batch();
      if (Object.keys(updateData).length > 0) {
        batch.set(memberRef, updateData, { merge: true });
      }
      if (makePrimaryAdmin) {
        batch.update(familyRef, { adminId: memberId });
      }

      await batch.commit();

      const updatedSnap = await memberRef.get();
      return {
        success: true,
        action: "update",
        member: {
          userId: memberId,
          ...updatedSnap.data(),
        },
        familyAdminId: makePrimaryAdmin ? memberId : familyData.adminId,
      };
    }

    if (action === "remove") {
      const memberId = request.data?.memberId as string | undefined;
      if (!memberId) {
        throw new HttpsError("invalid-argument", "memberId is required for remove.");
      }

      const memberRef = familyRef.collection("members").doc(memberId);
      const batch = firestore.batch();
      batch.delete(memberRef);
      batch.set(firestore.collection("users").doc(memberId), {
        familyId: admin.firestore.FieldValue.delete(),
      }, { merge: true });

      // If removed member was admin, reassign to another member if available
      let newAdminId = request.data?.newAdminId as string | undefined;
      if (familyData.adminId === memberId) {
        if (!newAdminId) {
          const remainingMembers = await familyRef.collection("members").get();
          const other = remainingMembers.docs.find((d) => d.id !== memberId);
          if (other) {
            newAdminId = other.id;
          }
        }
        if (newAdminId) {
          batch.update(familyRef, { adminId: newAdminId });
          batch.set(familyRef.collection("members").doc(newAdminId), { role: "admin" }, { merge: true });
        }
      }

      await batch.commit();

      return {
        success: true,
        action: "remove",
        memberId,
        familyAdminId: newAdminId ?? (familyData.adminId === memberId ? "" : familyData.adminId),
      };
    }

    throw new HttpsError("invalid-argument", `Unknown action: ${action}`);
  },
);
