import { useState, useRef, useEffect } from 'react';
import { CheckCircle, X, ShieldCheck } from 'lucide-react';

interface Props {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
}

const OTPModal = ({ open, onClose, onConfirm }: Props) => {
  const [otp, setOtp] = useState(['', '', '', '']);
  const [error, setError] = useState(false);
  const [success, setSuccess] = useState(false);
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

  const CORRECT_OTP = '1234';

  useEffect(() => {
    if (open) {
      setOtp(['', '', '', '']);
      setError(false);
      setSuccess(false);
      setTimeout(() => inputRefs.current[0]?.focus(), 100);
    }
  }, [open]);

  const handleChange = (index: number, value: string) => {
    if (!/^\d*$/.test(value)) return;
    const newOtp = [...otp];
    newOtp[index] = value.slice(-1);
    setOtp(newOtp);
    setError(false);

    if (value && index < 3) {
      inputRefs.current[index + 1]?.focus();
    }
  };

  const handleKeyDown = (index: number, e: React.KeyboardEvent) => {
    if (e.key === 'Backspace' && !otp[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  };

  const handleSubmit = () => {
    const enteredOtp = otp.join('');
    if (enteredOtp === CORRECT_OTP) {
      setSuccess(true);
      setTimeout(() => {
        onConfirm();
      }, 1500);
    } else {
      setError(true);
    }
  };

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-foreground/40 backdrop-blur-sm animate-fade-in">
      <div className="dashboard-card p-8 w-full max-w-sm mx-4 animate-scale-in text-center">
        {success ? (
          <div className="py-6">
            <CheckCircle className="h-16 w-16 text-status-collected mx-auto mb-4" />
            <h3 className="text-xl font-bold text-foreground mb-2">تم التأكيد بنجاح!</h3>
            <p className="text-sm text-muted-foreground">تم تسليم المفقودات للراكب</p>
          </div>
        ) : (
          <>
            <button onClick={onClose} className="absolute top-4 left-4 p-1 rounded hover:bg-secondary transition-colors">
              <X className="h-5 w-5 text-muted-foreground" />
            </button>

            <ShieldCheck className="h-12 w-12 text-primary mx-auto mb-4" />
            <h3 className="text-xl font-bold text-foreground mb-2">تأكيد الاستلام</h3>
            <p className="text-sm text-muted-foreground mb-6">أدخل رمز التحقق المرسل للراكب</p>

            <div className="flex gap-3 justify-center mb-4" dir="ltr">
              {otp.map((digit, i) => (
                <input
                  key={i}
                  ref={(el) => { inputRefs.current[i] = el; }}
                  type="text"
                  inputMode="numeric"
                  maxLength={1}
                  value={digit}
                  onChange={(e) => handleChange(i, e.target.value)}
                  onKeyDown={(e) => handleKeyDown(i, e)}
                  className={`w-14 h-14 text-center text-2xl font-bold rounded-xl border-2 transition-colors outline-none
                    ${error ? 'border-destructive bg-destructive/5' : 'border-border focus:border-primary bg-card'}
                  `}
                />
              ))}
            </div>

            {error && <p className="text-sm text-destructive mb-4">رمز التحقق غير صحيح</p>}

            <button
              onClick={handleSubmit}
              disabled={otp.some((d) => !d)}
              className="w-full bg-primary text-primary-foreground py-3 rounded-xl font-bold text-sm hover:opacity-90 transition-opacity disabled:opacity-40"
            >
              تأكيد
            </button>

            <p className="text-xs text-muted-foreground mt-4">رمز التجربة: 1234</p>
          </>
        )}
      </div>
    </div>
  );
};

export default OTPModal;
