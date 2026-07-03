import * as admin from "firebase-admin";
import { getFirestore } from "firebase-admin/firestore";

function db() {
  return getFirestore(admin.app(), "lifegoal");
}

export interface SavedNotification {
  id: string;
  title: string;
  body: string;
  suggestedAction: string;
  trigger: string;
  eventName?: string;
  relatedGoalId?: string;
  createdAt: string;
  isRead: boolean;
  isAiGenerated: boolean;
  suggestionType?: string;
  suggestedNewGoalName?: string;
  suggestedNewGoalTargetCost?: number;
  suggestedNewGoalMonths?: number;
  suggestedNewGoalAccount?: string;
}

export async function getRecentNotifications(
  familyId: string,
  limit: number,
): Promise<Array<{ title: string; body: string; suggestedAction: string; relatedGoalId?: string }>> {
  const snapshot = await db()
    .collection("families")
    .doc(familyId)
    .collection("notifications")
    .orderBy("createdAt", "desc")
    .limit(limit)
    .get();

  return snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      title: String(data.title ?? ""),
      body: String(data.body ?? ""),
      suggestedAction: String(data.suggestedAction ?? ""),
      relatedGoalId: data.relatedGoalId ? String(data.relatedGoalId) : undefined,
    };
  });
}

export async function saveNotification(
  familyId: string,
  data: {
    title: string;
    body: string;
    suggestedAction: string;
    trigger: string;
    eventName?: string;
    relatedGoalId?: string;
    suggestionType?: string;
    suggestedNewGoalName?: string;
    suggestedNewGoalTargetCost?: number;
    suggestedNewGoalMonths?: number;
    suggestedNewGoalAccount?: string;
  },
): Promise<SavedNotification> {
  const id = `${Date.now()}`;
  const notification: SavedNotification = {
    id,
    title: data.title,
    body: data.body,
    suggestedAction: data.suggestedAction,
    trigger: data.trigger,
    createdAt: new Date().toISOString(),
    isRead: false,
    isAiGenerated: true,
  };

  if (data.eventName) {
    notification.eventName = data.eventName;
  }
  if (data.relatedGoalId) {
    notification.relatedGoalId = data.relatedGoalId;
  }
  if (data.suggestionType) {
    notification.suggestionType = data.suggestionType;
  }
  if (data.suggestedNewGoalName) {
    notification.suggestedNewGoalName = data.suggestedNewGoalName;
  }
  if (data.suggestedNewGoalTargetCost != null) {
    notification.suggestedNewGoalTargetCost = data.suggestedNewGoalTargetCost;
  }
  if (data.suggestedNewGoalMonths != null) {
    notification.suggestedNewGoalMonths = data.suggestedNewGoalMonths;
  }
  if (data.suggestedNewGoalAccount) {
    notification.suggestedNewGoalAccount = data.suggestedNewGoalAccount;
  }

  await db()
    .collection("families")
    .doc(familyId)
    .collection("notifications")
    .doc(id)
    .set(notification);

  return notification;
}
