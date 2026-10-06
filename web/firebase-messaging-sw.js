// Service worker for Firebase Cloud Messaging (web).
// Handles background push notifications.

// Tapping a notification focuses an open Rental Ledger tab/PWA window, or
// opens one. Registered BEFORE the Firebase scripts so it runs first; it stops
// propagation so the SDK's own click handler cannot open a second window.
self.addEventListener('notificationclick', (event) => {
  event.stopImmediatePropagation();
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const client of windows) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      return clients.openWindow('/');
    }),
  );
});

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// Must match the `web` options in lib/firebase_options.dart.
firebase.initializeApp({
  apiKey: 'AIzaSyBQpWPeBxxNYzarrsUwYy91C6Ha4iFZtJo',
  authDomain: 'rental-ledger-app.firebaseapp.com',
  projectId: 'rental-ledger-app',
  storageBucket: 'rental-ledger-app.firebasestorage.app',
  messagingSenderId: '1036946500500',
  appId: '1:1036946500500:web:60bcf2414e01e86f5abd81',
});

const messaging = firebase.messaging();

// Display the notification when received in the background.
messaging.onBackgroundMessage((payload) => {
  // A message with a `notification` block (what sendNotificationOnCreate
  // sends) is already displayed by the Firebase SDK itself; showing it here
  // as well produced a duplicate. Only data-only messages are shown manually.
  if (payload.notification) return;
  const title = payload.data?.title || 'Rental Ledger';
  const options = {
    body: payload.data?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  };
  self.registration.showNotification(title, options);
});
