import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  doc,
  getDoc,
  updateDoc,
  serverTimestamp,
  collection,
  query,
  where,
  getDocs,
} from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { CheckCircle2, XCircle, Loader2, MapPin, ShieldCheck } from 'lucide-react';
import emailjs from '@emailjs/browser';

const EMAILJS_SERVICE_ID = 'service_y8bl7uo';
const EMAILJS_FOUND_NOTICE_TEMPLATE = 'template_5d2nr6u';
const EMAILJS_PUBLIC_KEY = 'zRX2gpxOt5DM0-v39';

const ConfirmMatch = () => {
  const [searchParams] = useSearchParams();
  const [status, setStatus] = useState<'loading' | 'success' | 'error' | 'already_used'>('loading');
  const [message, setMessage] = useState('');
  const [stationName, setStationName] = useState('');
  const [itemImage, setItemImage] = useState('');

  const getPassengerEmail = async (passengerId: string) => {
    try {
      const snap = await getDoc(doc(db, 'Passenger', passengerId));
      return snap.data()?.email || '';
    } catch (e) {
      console.error(e);
      return '';
    }
  };

  const getFoundItemImage = async (reportId: string) => {
    try {
      const q = query(collection(db, 'found_reports'), where('lost_report_id', '==', reportId));
      const snap = await getDocs(q);
      if (snap.empty) return '';
      return snap.docs[0].data().imageUrl || '';
    } catch (e) {
      console.error(e);
      return '';
    }
  };

  useEffect(() => {
    const confirm = async () => {
      const token = searchParams.get('token');
      const reportId = searchParams.get('reportId');

      if (!token || !reportId) {
        setStatus('error');
        setMessage('الرابط غير صحيح أو ناقص.');
        return;
      }

      try {
        const reportRef = doc(db, 'lost_found_reports', reportId);
        const reportSnap = await getDoc(reportRef);

        if (!reportSnap.exists()) {
          setStatus('error');
          setMessage('لم يتم العثور على البلاغ.');
          return;
        }

        const reportData = reportSnap.data();

        if (reportData.confirm_token !== token) {
          setStatus('error');
          setMessage('الرابط غير صحيح أو انتهت صلاحيته.');
          return;
        }

        if (reportData.status !== 'matched') {
          setStatus('already_used');
          setMessage('تم تأكيد هذا البلاغ مسبقًا أو تغيّرت حالته.');
          setStationName(reportData.station_name || '');
          return;
        }

        await updateDoc(reportRef, {
          status: 'awaiting',
          confirm_token: null,
          confirmed_at: serverTimestamp(),
        });

        const email = await getPassengerEmail(reportData.passenger_id || '');
        const image = await getFoundItemImage(reportId);

        setStationName(reportData.station_name || '');
        setItemImage(image);

        if (email) {
          await emailjs.send(
            EMAILJS_SERVICE_ID,
            EMAILJS_FOUND_NOTICE_TEMPLATE,
            {
              email,
              passenger_name: reportData.name || 'عزيزي الراكب',
              station_name: reportData.station_name || '',
              item_image: image,
            },
            EMAILJS_PUBLIC_KEY
          );
        }

        setStatus('success');
        setMessage('تم تأكيد ملكيتك للغرض بنجاح. تم تحديث البلاغ إلى بانتظار الاستلام، وسيتم إرسال رمز تحقق مؤقت عند وصولك للمحطة.');
      } catch (e) {
        console.error('Confirm error:', e);
        setStatus('error');
        setMessage('حدث خطأ أثناء تأكيد البلاغ. حاول مرة أخرى.');
      }
    };

    confirm();
  }, [searchParams]);

  const isSuccess = status === 'success';
  const isError = status === 'error';
  const isUsed = status === 'already_used';

  return (
    <div className="min-h-screen flex items-center justify-center p-6 relative overflow-hidden" dir="rtl">
      <div className="absolute inset-0 bg-gradient-to-br from-slate-950 via-slate-900 to-zinc-950" />
      <div className="absolute inset-0 opacity-20 bg-[radial-gradient(circle_at_top,#f59e0b,transparent_35%),radial-gradient(circle_at_bottom,#38bdf8,transparent_35%)]" />

      <div className="relative w-full max-w-md rounded-[32px] border border-white/15 bg-white/10 backdrop-blur-xl shadow-2xl p-7 text-center">
        <img
          src="/images/masar-logo-dark.png"
          alt="مسار"
          className="h-20 mx-auto mb-5 object-contain"
        />

        {status === 'loading' && (
          <>
            <div className="mx-auto mb-5 h-20 w-20 rounded-full bg-white/10 flex items-center justify-center">
              <Loader2 className="h-10 w-10 animate-spin text-amber-400" />
            </div>
            <h2 className="text-2xl font-black text-white mb-2">جاري تأكيد الغرض...</h2>
            <p className="text-sm text-zinc-300">لحظات فقط، يتم التحقق من الرابط.</p>
          </>
        )}

        {(isSuccess || isUsed || isError) && (
          <>
            <div
              className={`mx-auto mb-5 h-20 w-20 rounded-full flex items-center justify-center ${
                isSuccess
                  ? 'bg-emerald-500/15'
                  : isUsed
                  ? 'bg-amber-500/15'
                  : 'bg-red-500/15'
              }`}
            >
              {isError ? (
                <XCircle className="h-12 w-12 text-red-400" />
              ) : (
                <CheckCircle2 className={`h-12 w-12 ${isSuccess ? 'text-emerald-400' : 'text-amber-400'}`} />
              )}
            </div>

            <h2 className="text-2xl font-black text-white mb-3">
              {isSuccess ? 'تم التأكيد بنجاح' : isUsed ? 'تم التأكيد مسبقًا' : 'تعذر التأكيد'}
            </h2>

            <p className="text-sm leading-7 text-zinc-300 mb-5">{message}</p>

            {itemImage && (
              <img
                src={itemImage}
                alt="صورة الغرض"
                className="w-32 h-32 object-cover rounded-2xl mx-auto mb-5 border border-white/15"
              />
            )}

            {stationName && (
              <div className="rounded-2xl bg-white/10 border border-white/10 p-4 mb-5 text-right">
                <div className="flex items-center gap-2 text-white font-bold mb-1">
                  <MapPin className="h-4 w-4 text-amber-400" />
                  محطة الاستلام
                </div>
                <p className="text-zinc-300 text-sm">{stationName}</p>
              </div>
            )}

            {isSuccess && (
              <div className="rounded-2xl bg-emerald-500/10 border border-emerald-400/20 p-4 text-right">
                <div className="flex items-center gap-2 text-emerald-300 font-bold mb-1">
                  <ShieldCheck className="h-4 w-4" />
                  الخطوة التالية
                </div>
                <p className="text-zinc-300 text-sm leading-6">
                  توجّه إلى المحطة، وسيقوم الموظف بإرسال رمز تحقق مؤقت لإتمام الاستلام.
                </p>
              </div>
            )}
          </>
        )}

        <p className="text-[11px] text-zinc-500 mt-6">MASAR Lost & Found</p>
      </div>
    </div>
  );
};

export default ConfirmMatch;