import { NavLink, useNavigate } from 'react-router-dom';
import { LogOut, Moon, Sun } from 'lucide-react';
import { useTheme } from '@/hooks/useTheme';
import { useState, useEffect, useRef } from 'react';

const navItems = [
  { label: 'لوحة التحكم', path: '/dashboard' },
  { label: 'المفقودات', path: '/lost-found' },
];

const Navbar = () => {
  const { isDark, toggle } = useTheme();
  const [visible, setVisible] = useState(true);
  const lastScrollY = useRef(0);
  const navigate = useNavigate();

  useEffect(() => {
    const handleScroll = () => {
      const currentScrollY = window.scrollY;

      if (currentScrollY < 10) {
        setVisible(true);
      } else if (currentScrollY > lastScrollY.current) {
        setVisible(false);
      } else {
        setVisible(true);
      }

      lastScrollY.current = currentScrollY;
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

const logoClassName = isDark
  ? 'h-[54px] w-[132px] object-contain object-center'
  : 'h-[78px] w-[190px] object-contain object-center';

  return (
    <div
      className="fixed top-0 left-0 right-0"
      style={{
        zIndex: 9999,
        background: 'transparent',
        transform: visible ? 'translateY(0)' : 'translateY(-100%)',
        transition: 'transform 0.3s ease',
      }}
    >
      <header className="max-w-[1400px] mx-auto px-6 py-3">
        <div className="flex items-center justify-between">
<div
  className={`flex items-center justify-center min-w-[132px] ${
    !isDark ? 'translate-x-8' : ''
  }`}
>
           <img
              src={isDark ? '/images/masar-logo-dark.png' : '/images/masar-logo.png'}
              alt="مسار"
              className={logoClassName}
            />
          </div>

          <nav
            className="hidden md:flex items-center gap-0.5 rounded-full px-1 py-1"
            style={{
              background: isDark ? 'rgba(20,23,31,0.88)' : 'rgba(255,255,255,0.75)',
              backdropFilter: 'blur(12px)',
              WebkitBackdropFilter: 'blur(12px)',
              border: isDark
                ? '1px solid rgba(209,213,219,0.16)'
                : '1px solid rgba(255,255,255,0.9)',
              boxShadow: isDark
                ? '0 12px 30px rgba(0,0,0,0.34)'
                : '0 2px 12px rgba(0,0,0,0.18)',
            }}
          >
            {navItems.map((item) => (
              <NavLink
                key={item.path}
                to={item.path}
                className={({ isActive }) =>
                  `px-5 py-1.5 rounded-full text-sm font-bold transition-all duration-200 ${
                    isActive
                      ? 'shadow-sm'
                      : isDark
                        ? 'text-zinc-300 hover:text-white'
                        : 'text-muted-foreground hover:text-foreground'
                  }`
                }
                style={({ isActive }) =>
                  isActive
                    ? {
                        background: isDark ? '#D1D5DB' : '#1a1a1a',
                        color: isDark ? '#111827' : '#ffffff',
                      }
                    : {}
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>

          <div className="flex items-center gap-2.5">
            <button
              onClick={() => {
                localStorage.removeItem('loggedIn');
                navigate('/login');
              }}
              className="h-11 px-5 rounded-full text-sm font-bold flex items-center gap-2 transition-all duration-200 border"
              style={{
                color: isDark ? '#FCA5A5' : '#DC2626',
                background: isDark ? 'rgba(239,68,68,0.10)' : 'rgba(220,38,38,0.06)',
                borderColor: isDark ? 'rgba(248,113,113,0.28)' : 'rgba(220,38,38,0.18)',
              }}
            >
              <LogOut className="h-4.5 w-4.5" />
              خروج
            </button>

            <button
              onClick={toggle}
              className="h-11 w-11 rounded-full flex items-center justify-center transition-all duration-200 border"
              style={{
                background: isDark ? 'rgba(31,36,48,0.92)' : 'rgba(255,255,255,0.82)',
                borderColor: isDark ? 'rgba(209,213,219,0.18)' : 'rgba(17,24,39,0.12)',
                boxShadow: isDark
                  ? '0 10px 24px rgba(0,0,0,0.28)'
                  : '0 6px 18px rgba(0,0,0,0.10)',
              }}
              title={isDark ? 'الوضع الفاتح' : 'الوضع الداكن'}
            >
              {isDark ? (
                <Sun className="h-5.5 w-5.5" style={{ color: '#D1D5DB' }} />
              ) : (
                <Moon className="h-5.5 w-5.5" style={{ color: '#4B5563' }} />
              )}
            </button>
          </div>
        </div>
      </header>
    </div>
  );
};

export default Navbar;