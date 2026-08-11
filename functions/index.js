/**
 * Cloud Function that sends a push notification via FCM
 * whenever a new document is created in the `notifications` collection.
 *
 * Deploy:
 *   cd functions && npm install && firebase deploy --only functions
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotificationOnCreate = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap) => {
    const data = snap.data();

    // The user who should receive the notification.
    const userId = data.userId;
    if (!userId) return null;

    // Look up the recipient's FCM token from their profile.
    const userSnap = await admin.firestore().collection('users').doc(userId).get();
    const token = userSnap.data()?.fcmToken;
    if (!token) return null;

    const payload = {
      notification: {
        title: data.title || 'Rental Ledger',
        body: data.body || '',
      },
      data: {
        type: data.type || '',
        relatedId: data.relatedId || '',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token,
    };

    try {
      await admin.messaging().send(payload);
      console.log('Notification sent to', userId);
    } catch (e) {
      console.error('FCM send error:', e.message);
      // If the token is invalid, remove it so we don't retry forever.
      if (e.code === 'messaging/registration-token-not-registered') {
        await admin.firestore().collection('users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }
    }

    return null;
  });
