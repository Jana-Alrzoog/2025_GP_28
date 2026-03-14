import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { statusLabels, type PassengerReport, type ReportStatus } from '@/data/mockData';
import { MapPin, Clock, Package, Search, ImageIcon, ShieldCheck } from 'lucide-react';
import { ItemThumbnail } from './ImagePreviewModal';

interface Props {
  onSelectReport: (report: PassengerReport) => void;
  reports: PassengerReport[];
  onPreviewImage: (url: string) => void;
  onConfirmCollection?: (report: PassengerReport) => void;
}

type FilterKey = 'all' | 'searching' | 'matched' | 'awaiting' | 'collected';

const filterLabels: Record<FilterKey, string> = {
  all: 'الكل',
  searching: 'جاري البحث',
  matched: 'تم العثور على تطابق',
  awaiting: 'بانتظار الاستلام',
  collected: 'تم الاستلام',
};

const statusClass: Record<ReportStatus, string> = {
  searching: 'status-searching',
  matched: 'status-matched',
  awaiting: 'status-awaiting',
  collected: 'status-collected',
  closed: 'status-closed',
};

const PassengerReports = ({ onSelectReport, reports, onPreviewImage, onConfirmCollection }: Props) => {
  const [filter, setFilter] = useState<FilterKey>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [debouncedQuery, setDebouncedQuery] = useState('');
  const highlightRef = useRef<HTMLButtonElement>(null);

  // Count reports per status
  const counts = useMemo(() => {
    const c: Record<FilterKey, number> = { all: reports.length, searching: 0, matched: 0, awaiting: 0, collected: 0 };
    reports.forEach((r) => {
      if (r.status in c) c[r.status as FilterKey]++;
    });
    return c;
  }, [reports]);

  // Debounce search
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedQuery(searchQuery), 300);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  // Scroll to highlighted card
  useEffect(() => {
    if (debouncedQuery && highlightRef.current) {
      highlightRef.current.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  }, [debouncedQuery]);

  const filtered = reports.filter((r) => {
    const matchesFilter = filter === 'all' || r.status === filter;
    const matchesSearch = !debouncedQuery || r.id.includes(debouncedQuery);
    return matchesFilter && matchesSearch;
  });

  return (
    <div className="animate-fade-in">
      {/* Search bar */}
      <div className="relative mb-4">
        <Search className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="بحث برقم البلاغ / الرقم التسلسلي..."
          className="w-full pr-10 pl-4 py-2.5 rounded-xl border border-border bg-card text-foreground text-sm text-right outline-none focus:border-primary transition-colors"
        />
      </div>

      {/* Filters with count badges */}
      <div className="flex flex-wrap gap-2 mb-6">
        {(Object.keys(filterLabels) as FilterKey[]).map((key) => (
          <button
            key={key}
            onClick={() => setFilter(key)}
            className={`filter-btn flex items-center gap-1.5 ${filter === key ? 'filter-btn-active' : 'filter-btn-inactive'}`}
          >
            {filterLabels[key]}
            <span
              className={`inline-flex items-center justify-center min-w-[20px] h-5 px-1.5 rounded-full text-[10px] font-bold ${
                filter === key
                  ? 'bg-primary-foreground/20 text-primary-foreground'
                  : 'bg-muted text-muted-foreground'
              }`}
            >
              {counts[key]}
            </span>
          </button>
        ))}
      </div>

      {/* Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {filtered.map((report, i) => {
          const isHighlighted = debouncedQuery && report.id.includes(debouncedQuery);
          return (
            <button
              key={report.id}
              ref={isHighlighted ? highlightRef : undefined}
              onClick={() => onSelectReport(report)}
              className={`dashboard-card p-4 text-right w-full hover:ring-2 hover:ring-primary/20 transition-all duration-200 cursor-pointer ${
                isHighlighted ? 'ring-2 ring-primary shadow-lg' : ''
              }`}
              style={{ animationDelay: `${i * 60}ms` }}
            >
              <div className="flex gap-3">
                {/* Thumbnail */}
                <ItemThumbnail
                  imageUrl={report.imageUrl}
                  onClick={() => report.imageUrl && onPreviewImage(report.imageUrl)}
                  size="md"
                />

                {/* Content */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between mb-1">
                    <span className={`status-badge ${statusClass[report.status]}`}>
                      {statusLabels[report.status]}
                    </span>
                  </div>

                  <p className="text-xs text-muted-foreground mb-1 line-clamp-2">{report.description}</p>

                  <div className="flex items-center gap-1 text-xs text-muted-foreground mt-2">
                    <span>التاريخ : {report.date}</span>
                  </div>
                  <div className="flex items-center gap-1 text-xs text-muted-foreground">
                    <span>رقم المالك : {report.id}</span>
                  </div>
                </div>
              </div>

              {/* Confirm collection button for awaiting status */}
              {report.status === 'awaiting' && onConfirmCollection && (
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    onConfirmCollection(report);
                  }}
                  className="mt-3 w-full flex items-center justify-center gap-2 py-2 rounded-xl bg-primary text-primary-foreground text-xs font-bold hover:opacity-90 transition-opacity"
                >
                  <ShieldCheck className="h-4 w-4" />
                  تأكيد الاستلام
                </button>
              )}
            </button>
          );
        })}
      </div>

      {filtered.length === 0 && (
        <div className="text-center py-16 text-muted-foreground">
          <Package className="h-12 w-12 mx-auto mb-3 opacity-40" />
          <p className="text-lg">{debouncedQuery ? 'لا توجد نتائج للبحث' : 'لا توجد بلاغات'}</p>
        </div>
      )}
    </div>
  );
};

export default PassengerReports;
