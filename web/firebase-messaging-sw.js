// Service worker for Firebase Cloud Messaging (web).
// Handles background push notifications.
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBsvitE78bCdlMmay1-3gREkerNS0ajnlE',
  authDomain: 'rental-ledger-app.firebaseapp.com',
  projectId: 'rental-ledger-app',
  storageBucket: 'rental-ledger-app.firebasestorage.app',
  messagingSenderId: '1036946500500',
  appId: '1:1036946500500:web:60bcf2414e01e86f5abd81',
});

const messaging = firebase.messaging();

// Display the notification when received in the background.
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'Rental Ledger';
  const options = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  };
  self.registration.showNotification(title, options);
});
