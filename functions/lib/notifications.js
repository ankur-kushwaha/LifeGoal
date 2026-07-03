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
exports.getRecentNotifications = getRecentNotifications;
exports.saveNotification = saveNotification;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-admin/firestore");
function db() {
    return (0, firestore_1.getFirestore)(admin.app(), "lifegoal");
}
async function getRecentNotifications(familyId, limit) {
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
        };
    });
}
async function saveNotification(familyId, data) {
    const id = `${Date.now()}`;
    const notification = {
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
    await db()
        .collection("families")
        .doc(familyId)
        .collection("notifications")
        .doc(id)
        .set(notification);
    return notification;
}
//# sourceMappingURL=notifications.js.map