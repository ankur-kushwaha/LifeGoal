"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.scheduledDailyNotifications = exports.generateNotification = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const params_1 = require("firebase-functions/params");
const ai_1 = require("./ai");
const notifications_1 = require("./notifications");
admin.initializeApp();
const openRouterKey = (0, params_1.defineSecret)("OPENROUTER_API_KEY");
const db = () => (0, firestore_1.getFirestore)(admin.app(), "lifegoal");
async function isFamilyMember(familyId, userId) {
    const doc = await db()
        .collection("families")
        .doc(familyId)
        .collection("members")
        .doc(userId)
        .get();
    return doc.exists;
}
async function generateForFamily(familyId, trigger, eventName, relatedGoalId) {
    const firestore = db();
    const familyDoc = await firestore.collection("families").doc(familyId).get();
    if (!familyDoc.exists) {
        throw new https_1.HttpsError("not-found", "Family not found");
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
        const name = data.displayName ||
            data.email ||
            doc.id;
        return {
            name,
            profile: data.memberProfile,
        };
    });
    const recent = await (0, notifications_1.getRecentNotifications)(familyId, 5);
    const goalContext = (0, ai_1.buildGoalContext)(goals, familyData.globalInflation ?? 6, familyData.globalReturn ?? 14, familyData.today ?? new Date().toISOString());
    const profileContext = (0, ai_1.buildFamilyProfileContext)(familyData.familyProfile, memberProfiles);
    const context = goalContext;
    const apiKey = openRouterKey.value();
    if (!apiKey) {
        throw new https_1.HttpsError("failed-precondition", "OPENROUTER_API_KEY secret is not configured");
    }
    let aiResult;
    try {
        aiResult = await (0, ai_1.generateAINotification)({
            apiKey,
            goalContext: context,
            profileContext,
            recentNotifications: recent,
            trigger,
            eventName,
            relatedGoalId,
        });
        const blockedIds = new Set(recent.map((n) => n.relatedGoalId).filter((id) => Boolean(id)));
        if (aiResult.relatedGoalId &&
            blockedIds.has(aiResult.relatedGoalId) &&
            recent.length > 0) {
            console.log(`AI repeated goal ${aiResult.relatedGoalId}, retrying with blocked list`);
            aiResult = await (0, ai_1.generateAINotification)({
                apiKey,
                goalContext: context,
                profileContext,
                recentNotifications: recent,
                trigger,
                eventName,
                relatedGoalId,
            });
        }
    }
    catch (error) {
        const message = error instanceof Error ? error.message : "AI generation failed";
        console.error("OpenRouter generation failed:", message);
        throw new https_1.HttpsError("internal", message);
    }
    const notification = await (0, notifications_1.saveNotification)(familyId, {
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
exports.generateNotification = (0, https_1.onCall)({
    region: "asia-south1",
    secrets: [openRouterKey],
}, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Sign in required");
    }
    const familyId = request.data.familyId;
    const trigger = request.data.trigger ?? "custom";
    const eventName = request.data.eventName;
    const relatedGoalId = request.data.relatedGoalId;
    if (!familyId) {
        throw new https_1.HttpsError("invalid-argument", "familyId is required");
    }
    const member = await isFamilyMember(familyId, request.auth.uid);
    if (!member) {
        throw new https_1.HttpsError("permission-denied", "Not a family member");
    }
    const notification = await generateForFamily(familyId, trigger, eventName, relatedGoalId);
    return { notification };
});
exports.scheduledDailyNotifications = (0, scheduler_1.onSchedule)({
    schedule: "0 10 * * *",
    timeZone: "Asia/Kolkata",
    region: "asia-south1",
    secrets: [openRouterKey],
}, async () => {
    const familiesSnapshot = await db().collection("families").get();
    for (const familyDoc of familiesSnapshot.docs) {
        try {
            await generateForFamily(familyDoc.id, "scheduled", "scheduled_10am");
        }
        catch (error) {
            console.error(`Scheduled notification failed for ${familyDoc.id}:`, error);
        }
    }
});
//# sourceMappingURL=index.js.map