import { NavLink } from 'react-router-dom';
import { User, LogOut, Moon, Sun } from 'lucide-react';
import { useTheme } from '@/hooks/useTheme';

const navItems = [
  { label: 'لوحة التحكم', path: '/' },
  { label: 'المفقودات', path: '/lost-found' },
];

const Navbar = () => {
  const { isDark, toggle } = useTheme();

  return (
    <div className="fixed top-0 left-0 right-0 z-50 px-6 pt-4 pb-2">
      <header className="max-w-[1400px] mx-auto bg-card/90 backdrop-blur-md border border-border/60 rounded-2xl shadow-sm">
        <div className="px-6 py-3">
          <div className="flex items-center justify-between">
            {/* Left side - user actions */}
            <div className="flex items-center gap-2">
              <button className="border border-destructive/60 text-destructive px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 hover:bg-destructive/5 transition-colors">
                <LogOut className="h-3.5 w-3.5" />
                خروج
              </button>
              <button className="p-2 rounded-xl hover:bg-secondary transition-colors">
                <User className="h-4 w-4 text-muted-foreground" />
              </button>
              <button
                onClick={toggle}
                className="p-2 rounded-xl hover:bg-secondary transition-colors"
                title={isDark ? 'الوضع الفاتح' : 'الوضع الداكن'}
              >
                {isDark ? (
                  <Sun className="h-4 w-4 text-yellow-400" />
                ) : (
                  <Moon className="h-4 w-4 text-muted-foreground" />
                )}
              </button>
            </div>

            {/* Nav links - center */}
            <nav className="hidden md:flex items-center gap-1">
              {navItems.map((item) => (
                <NavLink
                  key={item.path}
                  to={item.path}
                  className={({ isActive }) =>
                    `px-4 py-2 rounded-xl text-sm font-medium transition-all ${
                      isActive
                        ? 'text-primary font-bold bg-primary/5'
                        : 'text-muted-foreground hover:text-foreground hover:bg-secondary/50'
                    }`
                  }
                >
                  {item.label}
                </NavLink>
              ))}
            </nav>

            {/* Logo - right side */}
            <div className="flex items-center gap-2">
              <img src="/images/masar-logo.png" alt="مسار" className="h-10" />
            </div>
          </div>
        </div>
      </header>
    </div>
  );
};

export default Navbar;
