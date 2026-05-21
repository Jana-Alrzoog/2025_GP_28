import { useState, useRef, useEffect } from 'react';
import { CheckCircle, X, ShieldCheck, Clock, RefreshCw } from 'lucide-react';

interface Props {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  onResend?: () => Promise<void>;  // إعادة إرسال OTP جديد
  correctOtp?: string;
  expiresAt?: number | null;       // timestamp انتهاء الصلاحية
}

const OTP_DURATION = 10 * 60;     // 10 دقائق بالثواني

const OTPModal = ({ open, onClose, onConfirm, onResend, correctOtp, expiresAt }: Props) => {
  const [otp, setOtp]           = useState(['', '', '', '']);
  const [error, setError]       = useState('');
  const [success, setSuccess]   = useState(false);
  const [timeLeft, setTimeLeft] = useState(OTP_DURATION);
  const [expired, setExpired]   = useState(false);
  const [resending, setResending] = useState(false);
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);
  const timerRef  = useRef<ReturnType<typeof setInterval> | null>(null);

  /* ── عند فتح الـ modal ── */
  useEffect(() => {
    if (!open) return;
    setOtp(['', '', '', '']);
    setError('');
    setSuccess(false);
    setExpired(false);
    setTimeout(() => inputRefs.current[0]?.focus(), 100);
  }, [open]);

  /* ── العداد التنازلي ── */
  useEffect(() => {
    if (!open || success) return;

    // احسب الوقت المتبقي بناءً على expiresAt لو موجود
    const getRemaining = () => {
      if (expiresAt) {
        return Math.max(0, Math.round((expiresAt - Date.now()) / 1000))
      }
      return OTP_DURATION
    }

    setTimeLeft(getRemaining())
    setExpired(getRemaining() === 0)

    timerRef.current = setInterval(() => {
      const remaining = getRemaining()
      setTimeLeft(remaining)
      if (remaining === 0) {
        setExpired(true)
        clearInterval(timerRef.current!)
      }
    }, 1000)

    return () => { if (timerRef.current) clearInterval(timerRef.current) }
  }, [open, expiresAt, success])

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60).toString().padStart(2, '0')
    const s = (secs % 60).toString().padStart(2, '0')
    return `${m}:${s}`
  }

  const handleChange = (index: number, value: string) => {
    if (!/^\d*$/.test(value)) return;
    const newOtp = [...otp];
    newOtp[index] = value.slice(-1);
    setOtp(newOtp);
    setError('');
    if (value && index < 3) inputRefs.current[index + 1]?.focus();
  };

  const handleKeyDown = (index: number, e: React.KeyboardEvent) => {
    if (e.key === 'Backspace' && !otp[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  };

  const handleSubmit = () => {
    if (expired) { setError('انتهت صلاحية الرمز، أعد الإرسال'); return; }
    const enteredOtp = otp.join('');
    const expected   = correctOtp || '1234';
    if (enteredOtp === expected) {
      setSuccess(true);
      if (timerRef.current) clearInterval(timerRef.current);
      setTimeout(() => onConfirm(), 1500);
    } else {
      setError('رمز التحقق غير صحيح');
    }
  };

  const handleResend = async () => {
    if (!onResend) return;
    setResending(true);
    setOtp(['', '', '', '']);
    setError('');
    setExpired(false);
    try {
      await onResend();
    } finally {
      setResending(false);
      setTimeout(() => inputRefs.current[0]?.focus(), 100);
    }
  };

  // لون العداد بناءً على الوقت
  const timerColor = expired ? '#ef4444' : timeLeft < 60 ? '#f59e0b' : '#22c55e';

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-foreground/40 backdrop-blur-sm animate-fade-in">
      <div className="dashboard-card p-8 w-full max-w-sm mx-4 animate-scale-in text-center relative">
        {success ? (
          <div className="py-6">
            <CheckCircle className="h-16 w-16 text-green-500 mx-auto mb-4" />
            <h3 className="text-xl font-bold text-foreground mb-2">تم التأكيد بنجاح!</h3>
            <p className="text-sm text-muted-foreground">تم تسليم المفقودات للراكب</p>
          </div>
        ) : (
          <>
            <button onClick={onClose} className="absolute top-4 left-4 p-1 rounded hover:bg-secondary transition-colors">
              <X className="h-5 w-5 text-muted-foreground" />
            </button>

            <ShieldCheck className="h-12 w-12 text-primary mx-auto mb-4" />
            <h3 className="text-xl font-bold text-foreground mb-1">تأكيد الاستلام</h3>
            <p className="text-sm text-muted-foreground mb-4">أدخل رمز التحقق المرسل للراكب</p>

            {/* ── العداد ── */}
            <div className="flex items-center justify-center gap-2 mb-5">
              <Clock size={15} style={{ color: timerColor }} />
              <span className="text-sm font-bold tabular-nums" style={{ color: timerColor }}>
                {expired ? 'انتهت الصلاحية' : formatTime(timeLeft)}
              </span>
            </div>

            {/* ── حقول الـ OTP ── */}
            <div className="flex gap-3 justify-center mb-4" dir="ltr">
              {otp.map((digit, i) => (
                <input
                  key={i}
                  ref={(el) => { inputRefs.current[i] = el; }}
                  type="text"
                  inputMode="numeric"
                  maxLength={1}
                  value={digit}
                  disabled={expired}
                  onChange={(e) => handleChange(i, e.target.value)}
                  onKeyDown={(e) => handleKeyDown(i, e)}
                  className={`w-14 h-14 text-center text-2xl font-bold rounded-xl border-2 transition-colors outline-none
                    ${error    ? 'border-destructive bg-destructive/5'  : ''}
                    ${expired  ? 'border-border bg-muted opacity-50'    : ''}
                    ${!error && !expired ? 'border-border focus:border-primary bg-card' : ''}
                  `}
                />
              ))}
            </div>

            {error && <p className="text-sm text-destructive mb-3">{error}</p>}

            {/* ── أزرار ── */}
            {expired ? (
              <button
                onClick={handleResend}
                disabled={resending}
                className="w-full flex items-center justify-center gap-2 bg-primary text-primary-foreground py-3 rounded-xl font-bold text-sm hover:opacity-90 transition-opacity disabled:opacity-40"
              >
                <RefreshCw size={15} className={resending ? 'animate-spin' : ''} />
                {resending ? 'جاري الإرسال...' : 'إعادة إرسال الرمز'}
              </button>
            ) : (
              <div className="flex flex-col gap-2">
                <button
                  onClick={handleSubmit}
                  disabled={otp.some(d => !d)}
                  className="w-full bg-primary text-primary-foreground py-3 rounded-xl font-bold text-sm hover:opacity-90 transition-opacity disabled:opacity-40"
                >
                  تأكيد
                </button>
                {onResend && (
                  <button
                    onClick={handleResend}
                    disabled={resending}
                    className="w-full flex items-center justify-center gap-1 text-xs text-muted-foreground hover:text-foreground transition-colors py-1"
                  >
                    <RefreshCw size={11} className={resending ? 'animate-spin' : ''} />
                    {resending ? 'جاري الإرسال...' : 'إعادة إرسال رمز جديد'}
                  </button>
                )}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
};

export default OTPModal;
