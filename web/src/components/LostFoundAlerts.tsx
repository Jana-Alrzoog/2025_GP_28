import { useEffect, useState } from 'react';
import { AlertTriangle, Info, XCircle, Bell, CheckCircle2 } from 'lucide-react';
import { collection, onSnapshot } from 'firebase/firestore';
import { db } from '@/lib/firebase';

interface LostFoundAlert {
  id: string;
  type: 'critical' | 'warning' | 'info' | 'success';
  title: string;
  message: string;
  time: string;
  timestamp: number;
}

interface Props {
  onAlertClick: (type: string) => void;
}

const iconMap = {
  critical: XCircle,
  warning: AlertTriangle,
  info: Info,
  success: CheckCircle2,
};

const colorMap = {
  critical: 'text-destructive',
  warning: 'text-[hsl(var(--status-searching))]',
  info: 'text-[hsl(var(--status-awaiting))]',
  success: 'text-[hsl(var(--sim-high))]',
};

const bgMap = {
  critical: 'bg-destructive/5',
  warning: 'bg-[hsl(var(--status-searching-bg))]',
  info: 'bg-[hsl(var(--status-awaiting-bg))]',
  success: 'bg-[hsl(var(--status-collected-bg))]',
};

const typeLabels: Record<string, string> = {
  all: 'الكل',
  critical: 'منتهي الصلاحية',
  success: 'تطابق جديد',
  info: 'بلاغ جديد',
  warning: 'غرض جديد',
}

function parseTimestamp(raw: any): number | null {
  if (!raw) return null
  if (typeof raw.toDate === 'function') return raw.toDate().getTime()
  if (typeof raw === 'string') return new Date(raw).getTime() || null
  if (typeof raw.seconds === 'number') return raw.seconds * 1000
  if (typeof raw === 'number') return raw
  return null
}

function timeAgo(timestamp: number): string {
  const diff = Date.now() - timestamp
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(diff / 3600000)
  const days = Math.floor(diff / 86400000)
  if (minutes < 1) return 'الآن'
  if (minutes < 60) return `منذ ${minutes} دقيقة`
  if (hours < 24) return `منذ ${hours} ساعة`
  return `منذ ${days} يوم`
}

const LostFoundAlerts = ({ onAlertClick }: Props) => {
  const [alerts, setAlerts] = useState<LostFoundAlert[]>([])
  const [dismissed, setDismissed] = useState<Set<string>>(new Set())
  const [activeFilter, setActiveFilter] = useState<string>('all')

  useEffect(() => {
    const unsubLost = onSnapshot(collection(db, 'lost_found_reports'), (snapshot) => {
      const newAlerts: LostFoundAlert[] = []

      snapshot.docs.forEach((doc) => {
        const d = doc.data()
        const createdAt = parseTimestamp(d.created_at)
        if (!createdAt) return // تجاهل البلاغات اللي ما عندها تاريخ صحيح

        if (d.status === 'awaiting') {
          const daysSince = (Date.now() - createdAt) / 86400000
          if (daysSince >= 7) {
            newAlerts.push({
              id: `expired-${doc.id}`,
              type: 'critical',
              title: 'بلاغ منتهي الصلاحية',
              message: `البلاغ ${d.ticket_id || doc.id} لم يتم استلامه خلال 7 أيام`,
              time: timeAgo(createdAt),
              timestamp: createdAt,
            })
          }
        }

        if (d.status === 'matched') {
          const matchedAt = parseTimestamp(d.matched_at) ?? createdAt
          newAlerts.push({
            id: `matched-${doc.id}`,
            type: 'success',
            title: 'تم العثور على تطابق',
            message: `البلاغ ${d.ticket_id || doc.id} تم تطابقه`,
            time: timeAgo(matchedAt),
            timestamp: matchedAt,
          })
        }

        if (d.status === 'open') {
          const hoursSince = (Date.now() - createdAt) / 3600000
          if (hoursSince <= 24) {
            newAlerts.push({
              id: `new-report-${doc.id}`,
              type: 'info',
              title: 'بلاغ جديد من راكب',
              message: `${d.item_type || 'غرض'} في محطة ${d.station_name || ''}`,
              time: timeAgo(createdAt),
              timestamp: createdAt,
            })
          }
        }
      })

      setAlerts(prev => {
        const foundAlerts = prev.filter(a => a.id.startsWith('found-'))
        return [...newAlerts, ...foundAlerts].sort((a, b) => b.timestamp - a.timestamp).slice(0, 20)
      })
    })

    const unsubFound = onSnapshot(collection(db, 'found_reports'), (snapshot) => {
      const foundAlerts: LostFoundAlert[] = []
      snapshot.docChanges().forEach((change) => {
        if (change.type === 'added') {
          const d = change.doc.data()
          const createdAt = parseTimestamp(d.created_at)
          if (!createdAt) return // تجاهل اللي ما عندها تاريخ
          const hoursSince = (Date.now() - createdAt) / 3600000
          if (hoursSince <= 24) {
            foundAlerts.push({
              id: `found-${change.doc.id}`,
              type: 'warning',
              title: 'غرض جديد من الموظف',
              message: `${d.itemType || 'غرض'} في ${d.foundLocation || ''}`,
              time: timeAgo(createdAt),
              timestamp: createdAt,
            })
          }
        }
      })
      if (foundAlerts.length > 0) {
        setAlerts(prev => {
          const otherAlerts = prev.filter(a => !a.id.startsWith('found-'))
          return [...foundAlerts, ...otherAlerts].sort((a, b) => b.timestamp - a.timestamp).slice(0, 20)
        })
      }
    })

    return () => { unsubLost(); unsubFound() }
  }, [])

  const visibleAlerts = alerts.filter(a => !dismissed.has(a.id))
  const availableTypes = ['all', ...Array.from(new Set(visibleAlerts.map(a => a.type)))]
  const filtered = activeFilter === 'all' ? visibleAlerts : visibleAlerts.filter(a => a.type === activeFilter)

  const handleClick = (alert: LostFoundAlert) => {
    onAlertClick(alert.type)
    setDismissed(prev => new Set([...prev, alert.id]))
  }

  return (
    <div className="dashboard-card p-4">
      <div className="flex items-center gap-2 mb-3 justify-end">
        {visibleAlerts.length > 0 && (
          <span className="relative flex h-2 w-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-destructive opacity-75" />
            <span className="relative inline-flex rounded-full h-2 w-2 bg-destructive" />
          </span>
        )}
        <h3 className="text-sm font-bold">تنبيهات المفقودات</h3>
        <Bell className="h-4 w-4 text-primary" />
      </div>

      {visibleAlerts.length > 0 && (
        <div className="flex flex-wrap gap-1.5 mb-3 justify-end">
          {availableTypes.map((type) => {
            const count = type === 'all' ? visibleAlerts.length : visibleAlerts.filter(a => a.type === type).length
            return (
              <button
                key={type}
                onClick={() => setActiveFilter(type)}
                className={`text-[10px] px-2.5 py-1 rounded-full font-bold transition-all duration-200 flex items-center gap-1 ${
                  activeFilter === type
                    ? 'bg-primary text-primary-foreground shadow-sm'
                    : 'bg-muted text-muted-foreground hover:bg-secondary'
                }`}
              >
                {typeLabels[type] || type}
                <span className={`inline-flex items-center justify-center min-w-[14px] h-3.5 px-1 rounded-full text-[9px] font-bold ${
                  activeFilter === type ? 'bg-primary-foreground/20 text-primary-foreground' : 'bg-border text-muted-foreground'
                }`}>
                  {count}
                </span>
              </button>
            )
          })}
        </div>
      )}

      <div className="space-y-2.5 max-h-[400px] overflow-y-auto scrollbar-thin">
        {filtered.length === 0 ? (
          <div className="text-center py-6 text-muted-foreground">
            <Bell className="h-8 w-8 mx-auto mb-2 opacity-30" />
            <p className="text-xs">لا توجد تنبيهات</p>
          </div>
        ) : (
          filtered.map((alert, i) => {
            const Icon = iconMap[alert.type];
            return (
              <button
                key={alert.id}
                onClick={() => handleClick(alert)}
                className={`w-full rounded-lg p-2.5 ${bgMap[alert.type]} animate-fade-in text-right hover:opacity-80 transition-opacity cursor-pointer`}
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
              </button>
            );
          })
        )}
      </div>
    </div>
  );
};

export default LostFoundAlerts;