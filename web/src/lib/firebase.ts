import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore, collection, getDocs, query, where, doc, updateDoc } from "firebase/firestore";
import { getStorage } from "firebase/storage";


const firebaseConfig = {
  apiKey: "AIzaSyA5wzcZsMpd206vELbZ45Ve1pYYjIEcN8w",
  authDomain: "masarapp-b9521.firebaseapp.com",
  projectId: "masarapp-b9521",
  storageBucket: "masarapp-b9521.firebasestorage.app",
  messagingSenderId: "379250614209",
  appId: "1:379250614209:web:45409d5803cec3625c9940",
  measurementId: "G-DTN8MESMJT",
};


const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

export default app;


// Fetch open lost reports
export async function getLostReports() {
  const q = query(
    collection(db, 'lost_found_reports'),
    where('status', '==', 'open')
  );

  const snapshot = await getDocs(q);
  return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as any[];
}

// Fetch found reports
export async function getFoundReports() {
  const q = query(
    collection(db, 'found_reports'),
    where('status', '==', 'found')
  );

  const snapshot = await getDocs(q);
  return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as any[];
}

// Approve match
export async function approveMatch(foundReportId: string, lostReportId: string) {
  await updateDoc(doc(db, 'found_reports', foundReportId), {
    status: 'matched',
    lost_report_id: lostReportId,
  });

  await updateDoc(doc(db, 'lost_found_reports', lostReportId), {
    status: 'matched',
  });
}

// Confirm collection
export async function confirmCollection(foundReportId: string, lostReportId: string) {
  await updateDoc(doc(db, 'found_reports', foundReportId), {
    status: 'collected',
  });

  await updateDoc(doc(db, 'lost_found_reports', lostReportId), {
    status: 'collected',
  });
}
