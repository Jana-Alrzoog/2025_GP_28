import { AlertTriangle, Info, XCircle, Bell } from 'lucide-react';

interface LostFoundAlert {
  id: string;
  type: 'critical' | 'warning' | 'info';
  title: string;
  message: string;
  time: string;
}

const lostFoundAlerts: LostFoundAlert[] = [
  {
    id: 'LF-1',
    type: 'critical',
    title: 'بلاغ منتهي الصلاحية',
    message: 'البلاغ 1123245557 لم يتم استلامه خلال 7 أيام',
    time: 'منذ 5 دقائق',
  },
  {
    id: 'LF-2',
    type: 'warning',
    title: 'تطابق عالي جديد',
    message: 'تطابق 92% للبلاغ 1123245553 مع غرض FI-501',
    time: 'منذ 15 دقيقة',
  },
  {
    id: 'LF-3',
    type: 'info',
    title: 'غرض جديد',
    message: 'تم تسجيل غرض جديد في محطة العليا',
    time: 'منذ 30 دقيقة',
  },
];

const iconMap = {
  critical: XCircle,
  warning: AlertTriangle,
  info: Info,
};

const colorMap = {
  critical: 'text-destructive',
  warning: 'text-[hsl(var(--status-searching))]',
  info: 'text-[hsl(var(--status-awaiting))]',
};

const bgMap = {
  critical: 'bg-destructive/5',
  warning: 'bg-[hsl(var(--status-searching-bg))]',
  info: 'bg-[hsl(var(--status-awaiting-bg))]',
};

const LostFoundAlerts = () => {
  return (
    <div className="dashboard-card p-4">
      <div className="flex items-center gap-2 mb-4 justify-end">
        <h3 className="text-sm font-bold">تنبيهات المفقودات</h3>
        <Bell className="h-4 w-4 text-primary" />
      </div>

      <div className="space-y-2.5">
        {lostFoundAlerts.map((alert, i) => {
          const Icon = iconMap[alert.type];
          return (
            <div
              key={alert.id}
              className={`rounded-lg p-2.5 ${bgMap[alert.type]} animate-fade-in`}
              style={{ animationDelay: `${i * 80}ms` }}
            >
              <div className="flex items-start gap-2 justify-end">
                <div className="text-right flex-1">
                  <p className="text-xs font-bold text-foreground">{alert.title}</p>
                  <p className="text-[10px] text-muted-foreground mt-0.5">{alert.message}</p>
                  <p className="text-[10px] text-muted-foreground/60 mt-0.5">{alert.time}</p>
                </div>
                <Icon className={`h-3.5 w-3.5 mt-0.5 shrink-0 ${colorMap[alert.type]}`} />
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default LostFoundAlerts;
