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
exports.manageFamilyMemberAdmin = exports.deleteFamilyAdmin = exports.getAllFamiliesAdmin = exports.scheduledDailyNotifications = exports.scheduledWeeklyNotifications = exports.generateNotification = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const financial_math_1 = require("./financial_math");
const notifications_1 = require("./notifications");
admin.initializeApp();
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
    const goals = goalsSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
    }));
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
    const mathResult = (0, financial_math_1.computeFinancialNotification)({
        goals,
        familyProfile: familyData.familyProfile,
        members: memberProfiles,
        recentNotifications: recent,
        trigger,
        eventName,
        relatedGoalId,
        globalInflation: familyData.globalInflation ?? 6,
        globalReturn: familyData.globalReturn ?? 14,
        todayIso: familyData.today ?? new Date().toISOString(),
    });
    const notification = await (0, notifications_1.saveNotification)(familyId, {
        title: mathResult.title,
        body: mathResult.body,
        suggestedAction: mathResult.suggestedAction,
        trigger,
        eventName,
        relatedGoalId: mathResult.relatedGoalId ?? relatedGoalId,
        suggestionType: mathResult.suggestionType,
        suggestedNewGoalName: mathResult.suggestedNewGoalName,
        suggestedNewGoalTargetCost: mathResult.suggestedNewGoalTargetCost,
        suggestedNewGoalMonths: mathResult.suggestedNewGoalMonths,
        suggestedNewGoalAccount: mathResult.suggestedNewGoalAccount,
    });
    return notification;
}
exports.generateNotification = (0, https_1.onCall)({
    region: "asia-south1",
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
// Scheduled notification runs once a week: every Monday at 10:00 AM IST
exports.scheduledWeeklyNotifications = (0, scheduler_1.onSchedule)({
    schedule: "0 10 * * 1",
    timeZone: "Asia/Kolkata",
    region: "asia-south1",
}, async () => {
    const familiesSnapshot = await db().collection("families").get();
    for (const familyDoc of familiesSnapshot.docs) {
        try {
            await generateForFamily(familyDoc.id, "scheduled", "scheduled_weekly_mon_10am");
        }
        catch (error) {
            console.error(`Scheduled weekly notification failed for ${familyDoc.id}:`, error);
        }
    }
});
// Backward-compatible alias for scheduled weekly notifications
exports.scheduledDailyNotifications = exports.scheduledWeeklyNotifications;
exports.getAllFamiliesAdmin = (0, https_1.onCall)({
    region: "asia-south1",
}, async (request) => {
    const userEmail = request.auth?.token?.email?.toLowerCase() ?? "";
    const isSuperAdminEmail = userEmail === "ankur.kus1@gmail.com" ||
        userEmail === "admin@lifegoal.ai" ||
        userEmail === "ankurkushwaha@gmail.com" ||
        userEmail.endsWith("@lifegoal.ai");
    const pin = request.data?.pin ?? "";
    const isPinValid = pin === "8899";
    if (!isSuperAdminEmail && !isPinValid) {
        throw new https_1.HttpsError("permission-denied", "Only super admin with authorized email or master PIN can fetch all families.");
    }
    const firestore = db();
    const familiesSnapshot = await firestore.collection("families").get();
    const results = await Promise.all(familiesSnapshot.docs.map(async (doc) => {
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
    }));
    return { families: results };
});
exports.deleteFamilyAdmin = (0, https_1.onCall)({
    region: "asia-south1",
}, async (request) => {
    const userEmail = request.auth?.token?.email?.toLowerCase() ?? "";
    const isSuperAdminEmail = userEmail === "ankur.kus1@gmail.com" ||
        userEmail === "admin@lifegoal.ai" ||
        userEmail === "ankurkushwaha@gmail.com" ||
        userEmail.endsWith("@lifegoal.ai");
    const pin = request.data?.pin ?? "";
    const isPinValid = pin === "8899";
    if (!isSuperAdminEmail && !isPinValid) {
        throw new https_1.HttpsError("permission-denied", "Only super admin with authorized email or master PIN can delete families.");
    }
    const familyId = request.data?.familyId;
    if (!familyId || typeof familyId !== "string" || familyId.trim().length === 0) {
        throw new https_1.HttpsError("invalid-argument", "Valid familyId is required.");
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
});
exports.manageFamilyMemberAdmin = (0, https_1.onCall)({
    region: "asia-south1",
}, async (request) => {
    const userEmail = request.auth?.token?.email?.toLowerCase() ?? "";
    const isSuperAdminEmail = userEmail === "ankur.kus1@gmail.com" ||
        userEmail === "admin@lifegoal.ai" ||
        userEmail === "ankurkushwaha@gmail.com" ||
        userEmail.endsWith("@lifegoal.ai");
    const pin = request.data?.pin ?? "";
    const isPinValid = pin === "8899";
    if (!isSuperAdminEmail && !isPinValid) {
        throw new https_1.HttpsError("permission-denied", "Only super admin with authorized email or master PIN can manage family members.");
    }
    const action = request.data?.action; // 'add' | 'update' | 'remove'
    const familyId = request.data?.familyId;
    if (!familyId || !action) {
        throw new https_1.HttpsError("invalid-argument", "familyId and action are required.");
    }
    const firestore = db();
    const familyRef = firestore.collection("families").doc(familyId);
    const familyDoc = await familyRef.get();
    if (!familyDoc.exists) {
        throw new https_1.HttpsError("not-found", "Family not found.");
    }
    const familyData = familyDoc.data() ?? {};
    if (action === "add") {
        const email = request.data?.email?.trim().toLowerCase() ?? "";
        if (!email || !email.includes("@")) {
            throw new https_1.HttpsError("invalid-argument", "A valid email is required.");
        }
        const displayName = request.data?.displayName?.trim() || null;
        const role = request.data?.role === "admin" ? "admin" : "member";
        const memberProfile = request.data?.memberProfile ?? {};
        const makePrimaryAdmin = Boolean(request.data?.makePrimaryAdmin);
        // Check if user exists in Firebase Auth
        let userId;
        try {
            const authUser = await admin.auth().getUserByEmail(email);
            userId = authUser.uid;
        }
        catch {
            userId = firestore.collection("users").doc().id;
        }
        const joinedAt = new Date().toISOString();
        const memberData = {
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
        const memberId = request.data?.memberId;
        if (!memberId) {
            throw new https_1.HttpsError("invalid-argument", "memberId is required for update.");
        }
        const memberRef = familyRef.collection("members").doc(memberId);
        const memberDoc = await memberRef.get();
        if (!memberDoc.exists) {
            throw new https_1.HttpsError("not-found", "Member not found in family.");
        }
        const updateData = {};
        if (request.data?.displayName !== undefined) {
            updateData.displayName = request.data.displayName.trim();
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
        const memberId = request.data?.memberId;
        if (!memberId) {
            throw new https_1.HttpsError("invalid-argument", "memberId is required for remove.");
        }
        const memberRef = familyRef.collection("members").doc(memberId);
        const batch = firestore.batch();
        batch.delete(memberRef);
        batch.set(firestore.collection("users").doc(memberId), {
            familyId: admin.firestore.FieldValue.delete(),
        }, { merge: true });
        // If removed member was admin, reassign to another member if available
        let newAdminId = request.data?.newAdminId;
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
    throw new https_1.HttpsError("invalid-argument", `Unknown action: ${action}`);
});
//# sourceMappingURL=index.js.map