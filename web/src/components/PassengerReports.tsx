import { useState, useEffect, useRef, useMemo } from 'react';
import { statusLabels, type PassengerReport, type ReportStatus } from '@/data/mockData';
import { Package, Search, ShieldCheck, Send, CheckCircle2 } from 'lucide-react';
import { ItemThumbnail } from './ImagePreviewModal';

interface Props {
  onSelectReport: (report: PassengerReport) => void;
  reports: PassengerReport[];
  onPreviewImage: (url: string) => void;
  onConfirmCollection?: (report: PassengerReport) => void;
  onSendMatchConfirmation?: (report: PassengerReport) => void;
}

type FilterKey = 'all' | 'open' | 'matched' | 'awaiting' | 'collected';

const filterLabels: Record<FilterKey, string> = {
  all: 'الكل',
  open: 'جاري البحث',
  matched: 'تم العثور على تطابق',
  awaiting: 'بانتظار الاستلام',
  collected: 'تم الاستلام',
};

const statusClass: Record<ReportStatus, string> = {
  open: 'status-searching',
  matched: 'status-matched',
  awaiting: 'status-awaiting',
  collected: 'status-collected',
  closed: 'status-closed',
};

const PassengerReports = ({
  onSelectReport,
  reports,
  onPreviewImage,
  onConfirmCollection,
  onSendMatchConfirmation,
}: Props) => {
  const [filter, setFilter] = useState<FilterKey>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [debouncedQuery, setDebouncedQuery] = useState('');
  const highlightRef = useRef<HTMLDivElement>(null);

  const counts = useMemo(() => {
    const c: Record<FilterKey, number> = {
      all: reports.length,
      open: 0,
      matched: 0,
      awaiting: 0,
      collected: 0,
    };

    reports.forEach((r) => {
      if (r.status in c) c[r.status as FilterKey]++;
    });

    return c;
  }, [reports]);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedQuery(searchQuery), 300);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  useEffect(() => {
    if (debouncedQuery && highlightRef.current) {
      highlightRef.current.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  }, [debouncedQuery]);

  const filtered = reports.filter((r) => {
    const matchesFilter = filter === 'all' || r.status === filter;
    const matchesSearch =
      !debouncedQuery ||
      r.id.includes(debouncedQuery) ||
      (r.ticket_id && r.ticket_id.includes(debouncedQuery)) ||
      (r.name && r.name.includes(debouncedQuery));

    return matchesFilter && matchesSearch;
  });

  return (
    <div className="animate-fade-in">
      <div className="relative mb-4">
        <Search className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="بحث برقم البلاغ / الاسم..."
          className="w-full pr-10 pl-4 py-2.5 rounded-[20px] border border-white/90 bg-white text-foreground text-sm text-right outline-none focus:border-primary transition-colors shadow-[0_2px_12px_rgba(0,0,0,0.06)]"
        />
      </div>

      <div className="flex flex-wrap gap-2 mb-6">
        {(Object.keys(filterLabels) as FilterKey[]).map((key) => (
          <button
            key={key}
            type="button"
            onClick={() => setFilter(key)}
            className={`filter-btn flex items-center gap-2 ${
              filter === key ? 'filter-btn-active' : 'filter-btn-inactive'
            }`}
          >
            {filterLabels[key]}
            <span
              className={`inline-flex items-center justify-center min-w-[22px] h-6 px-1.5 rounded-full text-xs font-extrabold ${
                filter === key
                  ? 'bg-primary-foreground/25 text-primary-foreground dark:bg-zinc-900/25 dark:text-zinc-900'
                  : 'bg-muted text-foreground dark:bg-white/10 dark:text-zinc-100'
              }`}
            >
              {counts[key]}
            </span>
          </button>
        ))}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {filtered.map((report, i) => {
          const isHighlighted =
            !!debouncedQuery &&
            (report.id.includes(debouncedQuery) ||
              (report.ticket_id && report.ticket_id.includes(debouncedQuery)));

          const confirmationSent = Boolean((report as any).confirmation_email_sent);

          return (
            <div
              key={report.id}
              ref={isHighlighted ? highlightRef : undefined}
              onClick={() => onSelectReport(report)}
              className={`dashboard-card p-4 text-right w-full hover:ring-2 hover:ring-primary/20 transition-all duration-200 cursor-pointer flex flex-col justify-between ${
                isHighlighted ? 'ring-2 ring-primary shadow-lg' : ''
              }`}
              style={{ animationDelay: `${i * 60}ms`, minHeight: '200px' }}
            >
              <div>
                <div className="flex gap-3">
                  <ItemThumbnail
                    imageUrl={report.photo_url || report.imageUrl}
                    onClick={() => {
                      const img = report.photo_url || report.imageUrl;
                      if (img) onPreviewImage(img);
                    }}
                    size="md"
                  />

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between mb-1">
                      <span
                        className={`status-badge ${
                          statusClass[report.status as ReportStatus] || 'status-searching'
                        }`}
                      >
                        {statusLabels[report.status as ReportStatus] || report.status}
                      </span>

                      <span className="text-[10px] text-muted-foreground font-mono">
                        {report.ticket_id || report.id}
                      </span>
                    </div>

                    <p className="text-xs font-bold text-foreground mb-1">
                      {report.item_type || report.itemType}
                    </p>

                    <p className="text-xs text-muted-foreground mb-1 line-clamp-2">
                      {report.description}
                    </p>

                    <div className="flex items-center gap-1 text-xs text-muted-foreground mt-1">
                      <span>{report.station_name}</span>
                    </div>

                    <div className="flex items-center gap-1 text-xs text-muted-foreground">
                      <span>{report.lost_datetime || report.date}</span>
                    </div>

                    {report.name && (
                      <div className="flex items-center gap-1 text-xs text-muted-foreground">
                        <span>👤 {report.name}</span>
                      </div>
                    )}
                  </div>
                </div>
              </div>

              <div className="mt-auto pt-3">
                {report.status === 'matched' && !report.photo_url && onSendMatchConfirmation ? (
                  confirmationSent ? (
                    <button
                      type="button"
                      disabled
                      onClick={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                      }}
                      className="w-full flex items-center justify-center gap-2 py-2 rounded-xl bg-muted text-muted-foreground text-xs font-bold cursor-not-allowed"
                    >
                      <CheckCircle2 className="h-4 w-4" />
                      تم إرسال التأكيد
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        onSendMatchConfirmation(report);
                      }}
                      className="w-full flex items-center justify-center gap-2 py-2 rounded-xl bg-primary text-primary-foreground text-xs font-bold hover:opacity-90 transition-opacity"
                    >
                      <Send className="h-4 w-4" />
                      إرسال تأكيد للراكب
                    </button>
                  )
                ) : report.status === 'awaiting' && onConfirmCollection ? (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      onConfirmCollection(report);
                    }}
                    className="w-full flex items-center justify-center gap-2 py-2 rounded-xl bg-primary text-primary-foreground text-xs font-bold hover:opacity-90 transition-opacity"
                  >
                    <ShieldCheck className="h-4 w-4" />
                    تأكيد الاستلام
                  </button>
                ) : (
                  <div className="h-[36px]" />
                )}
              </div>
            </div>
          );
        })}
      </div>

      {filtered.length === 0 && (
        <div className="text-center py-16 text-muted-foreground">
          <Package className="h-12 w-12 mx-auto mb-3 opacity-40" />
          <p className="text-lg">
            {debouncedQuery ? 'لا توجد نتائج للبحث' : 'لا توجد بلاغات'}
          </p>
        </div>
      )}
    </div>
  );
};

export default PassengerReports;