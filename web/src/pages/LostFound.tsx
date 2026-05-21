import { useEffect, useState, useRef } from 'react';
import { ClipboardList, Users, Layers, Plus } from 'lucide-react';
import { useTheme } from '@/hooks/useTheme';

import PassengerReports from '@/components/PassengerReports';
import StaffReports from '@/components/StaffReports';
import SimilarityMatching from '@/components/SimilarityMatching';
import OTPModal from '@/components/OTPModal';
import AddFoundItemModal from '@/components/AddFoundItemModal';
import ImagePreviewModal from '@/components/ImagePreviewModal';
import LostFoundAlerts from '@/components/LostFoundAlerts';

import {
  type PassengerReport,
  type FoundItem,
  type SimilarityMatch,
} from '@/data/mockData';

import {
  addDoc,
  collection,
  onSnapshot,
  serverTimestamp,
  doc,
  updateDoc,
  getDoc,
} from 'firebase/firestore';

import { db } from '@/lib/firebase';
import { useMatching } from '@/hooks/useMatching';
import emailjs from '@emailjs/browser';

const EMAILJS_SERVICE_ID = 'service_y8bl7uo';
const EMAILJS_MATCH_TEMPLATE = 'template_0adlsna';
const EMAILJS_FOUND_NOTICE_TEMPLATE = 'template_5d2nr6u';
const EMAILJS_OTP_TEMPLATE = 'template_ya8jvmk';
const EMAILJS_PUBLIC_KEY = 'zRX2gpxOt5DM0-v39';

const OTP_TTL = 10 * 60 * 1000;

function generateOTP() {
  return Math.floor(1000 + Math.random() * 9000).toString();
}

function generateToken() {
  return Math.random().toString(36).substring(2) + Date.now().toString(36);
}

type Tab = 'passenger' | 'staff' | 'similarity';

const tabConfig: { key: Tab; label: string; icon: typeof ClipboardList }[] = [
  { key: 'similarity', label: 'التطابقات', icon: Layers },
  { key: 'staff', label: 'الأغراض المعثور عليها', icon: Users },
  { key: 'passenger', label: 'بلاغات الركاب', icon: ClipboardList },
];

const LostFound = () => {
  const { isDark } = useTheme();

  const [activeTab, setActiveTab] = useState<Tab>('passenger');
  const [reports, setReports] = useState<PassengerReport[]>([]);
  const [foundItems, setFoundItems] = useState<FoundItem[]>([]);
  const [selectedReport, setSelectedReport] = useState<PassengerReport | null>(null);
  const [otpOpen, setOtpOpen] = useState(false);
  const [addItemOpen, setAddItemOpen] = useState(false);
  const [confirmingReport, setConfirmingReport] = useState<PassengerReport | null>(null);
  const [previewImage, setPreviewImage] = useState<string | null>(null);
  const [currentOtp, setCurrentOtp] = useState<string>('');
  const [otpExpiresAt, setOtpExpiresAt] = useState<number | null>(null);

  const prevReportsLengthRef = useRef(-1);
  const prevFoundLengthRef = useRef(-1);

  const {
    isRunning,
    matchGroups,
    runMatching,
    approveMatch,
    confirmCollection,
  } = useMatching();

  useEffect(() => {
    const unsubscribe = onSnapshot(collection(db, 'lost_found_reports'), (snapshot) => {
      const data = snapshot.docs.map((docSnap) => {
        const d = docSnap.data();

        return {
          id: docSnap.id,
          ticket_id: d.ticket_id,
          name: d.name,
          item_type: d.item_type,
          description: d.description,
          brand: d.brand,
          color: d.color,
          station_id: d.station_id,
          station_name: d.station_name,
          lost_datetime: d.lost_datetime,
          phone: d.phone,
          photo_url: d.photo_url,
          status: d.status,
          created_at: d.created_at,
          passenger_id: d.passenger_id,
          confirm_token: d.confirm_token,
          confirmation_email_sent: d.confirmation_email_sent,
          confirmation_email_sent_at: d.confirmation_email_sent_at,
        } as PassengerReport;
      });

      setReports(data);
    });

    return () => unsubscribe();
  }, []);

  useEffect(() => {
    const unsubscribe = onSnapshot(collection(db, 'found_reports'), (snapshot) => {
      const data = snapshot.docs.map((d) => ({
        id: d.id,
        ...d.data(),
      })) as FoundItem[];

      setFoundItems(data);
    });

    return () => unsubscribe();
  }, []);

  useEffect(() => {
    const openReports = reports.filter((r) => r.status === 'open');
    const pendingFound = foundItems.filter((f) => !f.lost_report_id);

    const reportsGrew =
      prevReportsLengthRef.current !== -1 &&
      reports.length > prevReportsLengthRef.current;

    const foundGrew =
      prevFoundLengthRef.current !== -1 &&
      foundItems.length > prevFoundLengthRef.current;

    prevReportsLengthRef.current = reports.length;
    prevFoundLengthRef.current = foundItems.length;

    if (
      !isRunning &&
      (reportsGrew || foundGrew) &&
      openReports.length > 0 &&
      pendingFound.length > 0
    ) {
      runMatching(openReports, pendingFound);
    }
  }, [reports.length, foundItems.length]);

  const getPassengerEmail = async (passengerId: string) => {
    try {
      const snap = await getDoc(doc(db, 'Passenger', passengerId));
      return snap.data()?.email || '';
    } catch (e) {
      console.error(e);
      return '';
    }
  };

  const sendOtpToPassenger = async (report: PassengerReport) => {
    const otp = generateOTP();
    const expiresAt = Date.now() + OTP_TTL;
    const email = await getPassengerEmail(report.passenger_id || '');

    await updateDoc(doc(db, 'lost_found_reports', report.id), {
      otp_code: otp,
      otp_expires_at: expiresAt,
      status: 'awaiting',
    });

    if (email) {
      await emailjs.send(
        EMAILJS_SERVICE_ID,
        EMAILJS_OTP_TEMPLATE,
        {
          email,
          passenger_name: report.name || 'عزيزي الراكب',
          station_name: report.station_name || '',
          otp_code: otp,
        },
        EMAILJS_PUBLIC_KEY
      );
    }

    setCurrentOtp(otp);
    setOtpExpiresAt(expiresAt);
  };

  const handleApproveMatch = async (foundReportId: string, lostReportId: string) => {
    const report = reports.find((r) => r.id === lostReportId);
    if (!report) return;

    const foundItem = foundItems.find((f) => f.id === foundReportId);
    const email = await getPassengerEmail(report.passenger_id || '');

    if (!email) {
      alert('لم يتم العثور على إيميل الراكب');
      return;
    }

    await approveMatch(foundReportId, lostReportId);

    if (report.photo_url) {
      await updateDoc(doc(db, 'lost_found_reports', lostReportId), {
        status: 'awaiting',
        confirm_token: null,
        confirmation_email_sent: null,
      });

      await emailjs.send(
        EMAILJS_SERVICE_ID,
        EMAILJS_FOUND_NOTICE_TEMPLATE,
        {
          email,
          passenger_name: report.name || 'عزيزي الراكب',
          station_name: report.station_name || '',
          item_image: foundItem?.imageUrl || '',
        },
        EMAILJS_PUBLIC_KEY
      );

      setReports((prev) =>
        prev.map((r) =>
          r.id === lostReportId
            ? { ...(r as any), status: 'awaiting', confirmation_email_sent: null }
            : r
        ) as PassengerReport[]
      );

      setSelectedReport(null);
      setActiveTab('passenger');
      return;
    }

    await updateDoc(doc(db, 'lost_found_reports', lostReportId), {
      status: 'matched',
      confirm_token: null,
      confirmation_email_sent: false,
    });

    setReports((prev) =>
      prev.map((r) =>
        r.id === lostReportId
          ? { ...(r as any), status: 'matched', confirmation_email_sent: false }
          : r
      ) as PassengerReport[]
    );

    setSelectedReport(null);
    setActiveTab('passenger');
  };

  const handleSendMatchConfirmation = async (report: PassengerReport) => {
    try {
      alert('جاري إرسال رسالة التأكيد للراكب...');

      const email = await getPassengerEmail(report.passenger_id || '');

      if (!email) {
        alert('لم يتم العثور على إيميل الراكب');
        return;
      }

      const token = generateToken();

      await updateDoc(doc(db, 'lost_found_reports', report.id), {
        status: 'matched',
        confirm_token: token,
        confirmation_email_sent: true,
        confirmation_email_sent_at: serverTimestamp(),
      });

      const foundItem = foundItems.find((f) => f.lost_report_id === report.id);

      const confirmUrl = `${window.location.origin}/confirm?token=${token}&reportId=${report.id}`;

      await emailjs.send(
        EMAILJS_SERVICE_ID,
        EMAILJS_MATCH_TEMPLATE,
        {
          email,
          passenger_name: report.name || 'عزيزي الراكب',
          station_name: report.station_name || '',
          item_image: foundItem?.imageUrl || '',
          confirm_url: confirmUrl,
        },
        EMAILJS_PUBLIC_KEY
      );

      setReports((prev) =>
        prev.map((r) =>
          r.id === report.id
            ? { ...(r as any), status: 'matched', confirmation_email_sent: true }
            : r
        ) as PassengerReport[]
      );

      alert('تم إرسال رسالة التأكيد للراكب بنجاح');
    } catch (error: any) {
      console.error('Send match confirmation error:', error);
      alert(
        'خطأ EmailJS:\n' +
          (error?.text || error?.message || JSON.stringify(error))
      );
    }
  };

  const handleSelectReport = (report: PassengerReport) => {
    if (report.status === 'matched') {
      setSelectedReport(report);
      setActiveTab('similarity');
    }
  };

  const handleSelectMatch = (match: SimilarityMatch) => {
    console.warn('handleSelectMatch should not directly change status. Use handleApproveMatch instead.');
  };

  const handleConfirmFound = async (report: PassengerReport) => {
    console.warn('handleConfirmFound should not directly change status. Use handleApproveMatch instead.');
  };

  const handleConfirmCollection = async (report: PassengerReport) => {
    setConfirmingReport(report);
    await sendOtpToPassenger(report);
    setOtpOpen(true);
  };

  const handleOtpConfirm = async () => {
    if (!confirmingReport) return;

    try {
      const foundReport = foundItems.find(
        (f) => f.lost_report_id === confirmingReport.id
      );

      if (foundReport) {
        await confirmCollection(foundReport.id, confirmingReport.id);
      } else {
        await updateDoc(doc(db, 'lost_found_reports', confirmingReport.id), {
          status: 'collected',
        });
      }
    } catch (e) {
      console.error(e);
    }

    setReports((prev) =>
      prev.map((r) =>
        r.id === confirmingReport.id
          ? { ...r, status: 'collected' as const }
          : r
      )
    );

    setOtpOpen(false);
    setConfirmingReport(null);
    setSelectedReport(null);
    setCurrentOtp('');
    setOtpExpiresAt(null);
    setActiveTab('passenger');
  };

  const handleAddFoundItem = async (item: FoundItem) => {
    await addDoc(collection(db, 'found_reports'), {
      item_id: item.item_id,
      itemType: item.itemType,
      description: item.description,
      brand: item.brand ?? null,
      color: item.color,
      station_id: item.station_id,
      foundLocation: item.foundLocation,
      lost_report_id: null,
      date: item.date,
      time: item.time,
      foundBy: item.foundBy,
      imageUrl: item.imageUrl || null,
      status: 'found',
      created_at: serverTimestamp(),
    });
  };

  const handleAlertClick = (type: string) => {
    if (type === 'critical' || type === 'info') setActiveTab('passenger');
    else if (type === 'success') setActiveTab('similarity');
    else if (type === 'warning') setActiveTab('staff');
  };

  return (
    <div className="min-h-screen">
      <div className="wave-bg" />

      <div className="max-w-[1400px] mx-auto px-6 py-6 pt-28">
        <div className="flex items-center mb-6 flex-wrap gap-3">
          <button
            onClick={() => setAddItemOpen(true)}
            className="group relative px-6 py-3 rounded-full text-sm font-extrabold flex items-center gap-2.5 transition-all duration-300 border overflow-hidden"
            style={{
              background: '#D97706',
              color: '#ffffff',
              borderColor: 'rgba(217,119,6,0.42)',
              boxShadow: '0 14px 28px rgba(217,119,6,0.20)',
            }}
          >
            <span className="absolute inset-0 rounded-full bg-white/15 opacity-0 group-hover:opacity-100 transition-opacity" />
            <Plus className="relative h-4.5 w-4.5 text-white" />
            <span className="relative">إضافة غرض تم العثور عليه</span>
          </button>

          <div className="flex-1" />

          <div className="flex gap-2 flex-row-reverse lg:ml-[calc(280px+1.5rem)]">
            {tabConfig.map((tab) => (
              <button
                key={tab.key}
                onClick={() => {
                  setActiveTab(tab.key);
                  if (tab.key !== 'similarity') setSelectedReport(null);
                }}
                className={`px-6 py-2.5 rounded-full text-sm font-bold transition-all duration-200 border backdrop-blur-sm ${
                  activeTab === tab.key
                    ? 'bg-primary/90 text-primary-foreground border-primary/50 shadow-md'
                    : 'bg-white/70 dark:bg-white/5 text-gray-800 dark:text-zinc-300 border-gray-300 dark:border-white/10 hover:bg-white dark:hover:bg-white/10'
                }`}
              >
                {tab.label}

                {(tab.key === 'staff' || tab.key === 'similarity') && (
                  <span
                    className="mr-2 inline-flex min-w-[24px] h-6 items-center justify-center rounded-full px-2 text-[11px] font-black border"
                    style={{
                      background: activeTab === tab.key
                        ? (isDark ? '#374151' : '#111827')
                        : (isDark ? 'rgba(255,255,255,0.10)' : '#E5E7EB'),
                      color: activeTab === tab.key
                        ? '#FFFFFF'
                        : (isDark ? '#E5E7EB' : '#111827'),
                      borderColor: isDark
                        ? 'rgba(255,255,255,0.12)'
                        : 'rgba(17,24,39,0.10)',
                    }}
                  >
                    {tab.key === 'staff' ? foundItems.length : matchGroups.length}
                  </span>
                )}
              </button>
            ))}
          </div>
        </div>

        <div className="flex gap-6 flex-row-reverse">
          <div className="hidden lg:block w-[280px] shrink-0">
            <div className="sticky top-24">
              <LostFoundAlerts onAlertClick={handleAlertClick} />
            </div>
          </div>

          <div className="flex-1 min-w-0">
            {activeTab === 'passenger' && (
              <PassengerReports
                reports={reports}
                onSelectReport={handleSelectReport}
                onPreviewImage={setPreviewImage}
                onConfirmCollection={handleConfirmCollection}
                onSendMatchConfirmation={handleSendMatchConfirmation}
              />
            )}

            {activeTab === 'staff' && (
              <StaffReports
                items={foundItems}
                onOpenAdd={() => setAddItemOpen(true)}
                onPreviewImage={setPreviewImage}
              />
            )}

            {activeTab === 'similarity' && (
              <SimilarityMatching
                selectedReport={selectedReport}
                foundItems={foundItems}
                reports={reports}
                matchGroups={matchGroups}
                onSelectMatch={handleSelectMatch}
                onConfirmFound={handleConfirmFound}
                onConfirmCollection={handleConfirmCollection}
                onApproveMatch={handleApproveMatch}
                onPreviewImage={setPreviewImage}
              />
            )}
          </div>
        </div>

        <OTPModal
          open={otpOpen}
          onClose={() => setOtpOpen(false)}
          onConfirm={handleOtpConfirm}
          correctOtp={currentOtp}
          expiresAt={otpExpiresAt}
        />

        <AddFoundItemModal
          open={addItemOpen}
          onClose={() => setAddItemOpen(false)}
          onAdd={handleAddFoundItem}
        />

        <ImagePreviewModal
          open={!!previewImage}
          imageUrl={previewImage}
          onClose={() => setPreviewImage(null)}
        />
      </div>
    </div>
  );
};

export default LostFound;