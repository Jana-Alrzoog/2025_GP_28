import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { signInWithEmailAndPassword } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { auth, db } from "@/lib/firebase";

export default function Login() {
  const navigate = useNavigate();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [emailError, setEmailError] = useState("");
  const [passError, setPassError] = useState("");
  const [generalError, setGeneralError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const isValidEmail = (v: string) =>
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    setEmailError("");
    setPassError("");
    setGeneralError("");

    const ev = email.trim();
    const pv = password.trim();

    let ok = true;

    if (!ev) {
      setEmailError("ادخل البريد الإلكتروني.");
      ok = false;
    } else if (!isValidEmail(ev)) {
      setEmailError("صيغة البريد الإلكتروني غير صحيحة");
      ok = false;
    }

    if (!pv) {
      setPassError("ادخل كلمة المرور.");
      ok = false;
    } else if (pv.length < 8) {
      setPassError("كلمة المرور لازم تكون 8 أحرف أو أكثر.");
      ok = false;
    }

    if (!ok) return;

    setIsLoading(true);

    try {
      const cred = await signInWithEmailAndPassword(auth, ev, pv);
      const snap = await getDoc(doc(db, "staff", cred.user.uid));

      if (!snap.exists()) {
        setGeneralError("هذا الحساب غير مصرح له.");
        setIsLoading(false);
        return;
      }

      if (snap.data().active !== true) {
        setGeneralError("هذا الحساب غير مفعل.");
        setIsLoading(false);
        return;
      }

      navigate("/dashboard");
    } catch (err: any) {
      const c = err?.code || "";

      setGeneralError(
        ["auth/invalid-credential", "auth/user-not-found", "auth/wrong-password"].includes(c)
          ? "البريد الإلكتروني أو كلمة المرور غير صحيحة."
          : "حدث خطأ أثناء تسجيل الدخول."
      );

      setIsLoading(false);
    }
  };

  return (
    <>
      <style>{`
        *, *::before, *::after {
          box-sizing: border-box;
          margin: 0;
          padding: 0;
        }

.lr-root{
  min-height:100vh;

  background-image:
    linear-gradient(
      rgba(255,255,255,0.05),
      rgba(255,255,255,0.05)
    ),
    url('/images/background.png');

  background-size:cover;

  background-position:center;

  background-repeat:no-repeat;

  display:flex;
  align-items:center;
  justify-content:center;

  padding:24px 20px;

  direction:rtl;

  font-family:'ThmanyahDisplay','Tajawal',serif;
}

        .lr-card {
          width: 100%;
          max-width: 820px;
          min-height: 470px;
          background: #fff;
          border-radius: 28px;
          overflow: hidden;
          display: flex;
          flex-direction: row-reverse;
          box-shadow:
            0 22px 55px rgba(0,0,0,0.16),
            0 8px 20px rgba(0,0,0,0.08);
        }

        .lr-photo {
          flex: 0.82;
          position: relative;
          margin: 14px;
          border-radius: 24px;
          overflow: hidden;
          min-height: 442px;

          background-image:
            linear-gradient(
              to top,
              rgba(0,0,0,0.78) 0%,
              rgba(0,0,0,0.35) 45%,
              rgba(0,0,0,0.05) 100%
            ),
            url('/images/masarlogin.png');

          background-size: cover;
          background-position: center;
          background-repeat: no-repeat;

          display: flex;
          align-items: flex-end;
          justify-content: flex-start;

          box-shadow:
            0 18px 36px rgba(0,0,0,0.28),
            0 6px 16px rgba(0,0,0,0.18);
        }

        .lr-side-content {
          position: absolute;
          bottom: 34px;
          left: 28px;
          z-index: 2;
          width: calc(100% - 56px);
          display: flex;
          flex-direction: column;
          align-items: flex-start;
          text-align: left;
          color: #fff;
        }

        .lr-side-content h2 {
          font-size: 25px;
          font-weight: 800;
          margin-bottom: 8px;
          text-shadow: 0 4px 18px rgba(0,0,0,0.55);
        }

        .lr-side-content p {
          font-size: 14px;
          line-height: 1.9;
          color: rgba(255,255,255,0.92);
          text-shadow: 0 3px 12px rgba(0,0,0,0.45);
        }

        .lr-form-side {
          flex: 1.08;
          background: #fff;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 34px 40px;
        }

        .lr-logo {
          width: 100%;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          text-align: center;
          margin-bottom: 12px;
        }

        .lr-logo img {
          height: 96px;
          width: auto;
          max-width: 230px;
          object-fit: contain;
          display: block;
          margin-left: auto;
          margin-right: auto;
          transform: translateX(50px);
        }

        .lr-divider {
          width: 44px;
          height: 3px;
          margin-top: 10px;
          border-radius: 999px;
          background: linear-gradient(90deg, #00ADE5, #984C9D);
        }

        .lr-title {
          font-size: 23px;
          font-weight: 800;
          color: #111;
          margin: 10px 0 5px;
        }

        .lr-sub {
          font-size: 12px;
          color: #8c8c8c;
          margin-bottom: 20px;
        }

        .lr-fields {
          width: 100%;
        }

        .lr-field {
          margin-bottom: 14px;
        }

        .lr-label {
          display: block;
          font-size: 14px;
          font-weight: 700;
          color: #222;
          margin-bottom: 7px;
        }

        .lr-input {
          width: 100%;
          padding: 13px 18px;
          border-radius: 50px;
          border: 2px solid #e5e5e5;
          background: #f8f8f8;
          outline: none;
          transition: .2s ease;
          font-size: 14px;
          text-align: right;
          direction: rtl;
          font-family: 'ThmanyahDisplay','Tajawal',serif;
        }

        .lr-input::placeholder {
          color: #bdbdbd;
          font-size: 13px;
        }

        .lr-email {
          border-color: #37B44A;
          background: #f6fdf6;
        }

        .lr-email:focus {
          background: #fff;
          box-shadow: 0 0 0 4px rgba(55,180,74,0.10);
        }

        .lr-pass {
          border-color: #00ADE5;
          background: #f4fbff;
        }

        .lr-pass:focus {
          background: #fff;
          box-shadow: 0 0 0 4px rgba(0,173,229,0.10);
        }

        .lr-email.err,
        .lr-pass.err {
          border-color: #ef4444;
          background: #fff5f5;
        }

        .lr-err {
          display: block;
          margin-top: 5px;
          padding-right: 10px;
          font-size: 12px;
          color: #ef4444;
        }

        .lr-general-err {
          background: #fff1f1;
          border: 1px solid #ffbdbd;
          color: #dc2626;
          padding: 10px 14px;
          border-radius: 12px;
          font-size: 13px;
          margin-bottom: 14px;
          text-align: center;
        }

        .lr-btn {
          width: 100%;
          margin-top: 14px;
          padding: 13px;
          border: none;
          border-radius: 50px;
          background: #171717;
          color: #fff;
          font-size: 15px;
          font-weight: 700;
          cursor: pointer;
          transition: .2s ease;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
        }

        .lr-btn:hover:not(:disabled) {
          background: #2a2a2a;
          transform: translateY(-2px);
          box-shadow: 0 10px 22px rgba(0,0,0,0.22);
        }

        .lr-btn:disabled {
          opacity: .7;
          cursor: not-allowed;
        }

        .lr-spinner {
          width: 16px;
          height: 16px;
          border: 2px solid rgba(255,255,255,.3);
          border-top-color: #fff;
          border-radius: 50%;
          animation: spin .7s linear infinite;
        }

        @keyframes spin {
          to {
            transform: rotate(360deg);
          }
        }

        .lr-footer {
          margin-top: 16px;
          text-align: center;
        }

        .lr-dots {
          display: flex;
          justify-content: center;
          gap: 5px;
          margin-bottom: 6px;
        }

        .lr-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
        }

        .lr-powered {
          font-size: 10px;
          color: #b1b1b1;
        }

        @media (max-width: 700px) {
          .lr-card {
            flex-direction: column;
            max-width: 95%;
          }

          .lr-photo {
            min-height: 260px;
          }

          .lr-form-side {
            padding: 30px 24px;
          }

          .lr-logo img {
            height: 82px;
            transform: none;
          }
        }
      `}</style>

      <div className="lr-root">
        <div className="lr-card">
          <div className="lr-photo">
            <div className="lr-side-content">
              <h2>بوابة إدارة مسار</h2>
              <p>
                وصول آمن لمتابعة البلاغات
                <br />
                وإدارة المفقودات
              </p>
            </div>
          </div>

          <div className="lr-form-side">
            <div className="lr-logo">
              <img src="/images/masar-logo.png" alt="Masar" />
              <div className="lr-divider" />
            </div>

            <h1 className="lr-title">مرحباً بعودتك!</h1>
            <p className="lr-sub">بوابة الموظفين — نظام مسار</p>

            <div className="lr-fields">
              <form onSubmit={handleSubmit} noValidate>
                {generalError && (
                  <div className="lr-general-err">
                    {generalError}
                  </div>
                )}

                <div className="lr-field">
                  <label className="lr-label">البريد الإلكتروني</label>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="أدخل بريدك الإلكتروني"
                    className={`lr-input lr-email${emailError ? " err" : ""}`}
                    autoComplete="email"
                  />
                  {emailError && (
                    <small className="lr-err">
                      {emailError}
                    </small>
                  )}
                </div>

                <div className="lr-field">
                  <label className="lr-label">كلمة المرور</label>
                  <input
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="أدخل كلمة المرور"
                    className={`lr-input lr-pass${passError ? " err" : ""}`}
                    autoComplete="current-password"
                  />
                  {passError && (
                    <small className="lr-err">
                      {passError}
                    </small>
                  )}
                </div>

                <button
                  type="submit"
                  className="lr-btn"
                  disabled={isLoading}
                >
                  {isLoading ? (
                    <>
                      <div className="lr-spinner" />
                      <span>جاري التحقق...</span>
                    </>
                  ) : (
                    "تسجيل الدخول"
                  )}
                </button>
              </form>
            </div>

            <div className="lr-footer">
              <div className="lr-dots">
                {[
                  "#00ADE5",
                  "#D12027",
                  "#FFD105",
                  "#984C9D",
                  "#3DB14A",
                  "#F37021",
                  "#0EADA0",
                ].map((c) => (
                  <div
                    key={c}
                    className="lr-dot"
                    style={{ background: c }}
                  />
                ))}
              </div>

              <p className="lr-powered">
                مترو الرياض &nbsp;·&nbsp; نظام مسار
              </p>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}