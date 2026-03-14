import { alerts } from '@/data/mockData';
import { AlertTriangle, Info, XCircle, Bell } from 'lucide-react';

const iconMap = {
  critical: XCircle,
  warning: AlertTriangle,
  info: Info,
};

const colorMap = {
  critical: 'text-destructive',
  warning: 'text-status-searching',
  info: 'text-status-awaiting',
};

const bgMap = {
  critical: 'bg-destructive/5',
  warning: 'bg-status-searching/5',
  info: 'bg-status-awaiting/5',
};

const AlertsPanel = () => {
  return (
    <div className="dashboard-card p-4 h-full">
      <div className="flex items-center gap-2 mb-4 justify-end">
        <h3 className="text-base font-bold">التنبيهات المباشرة</h3>
        <Bell className="h-5 w-5 text-primary" />
        <span className="relative flex h-2 w-2">
          <span className="animate-pulse-dot absolute inline-flex h-full w-full rounded-full bg-destructive opacity-75" />
          <span className="relative inline-flex rounded-full h-2 w-2 bg-destructive" />
        </span>
      </div>

      <div className="space-y-3">
        {alerts.map((alert, i) => {
          const Icon = iconMap[alert.type];
          return (
            <div
              key={alert.id}
              className={`rounded-lg p-3 ${bgMap[alert.type]} animate-fade-in`}
              style={{ animationDelay: `${i * 80}ms` }}
            >
              <div className="flex items-start gap-2 justify-end">
                <div className="text-right flex-1">
                  <p className="text-sm font-bold text-foreground">{alert.title}</p>
                  <p className="text-xs text-muted-foreground mt-1">{alert.message}</p>
                  <p className="text-[11px] text-muted-foreground/60 mt-1">{alert.time}</p>
                </div>
                <Icon className={`h-4 w-4 mt-0.5 shrink-0 ${colorMap[alert.type]}`} />
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default AlertsPanel;
