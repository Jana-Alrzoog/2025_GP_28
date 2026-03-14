import { useState, useEffect, useRef } from 'react';
import { MapPin, Clock, Package, Search } from 'lucide-react';
import type { FoundItem } from '@/data/mockData';
import { ItemThumbnail } from './ImagePreviewModal';

interface Props {
  items: FoundItem[];
  onOpenAdd: () => void;
  onPreviewImage: (url: string) => void;
}

const StaffReports = ({ items, onOpenAdd, onPreviewImage }: Props) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [debouncedQuery, setDebouncedQuery] = useState('');
  const highlightRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedQuery(searchQuery), 300);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  useEffect(() => {
    if (debouncedQuery && highlightRef.current) {
      highlightRef.current.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  }, [debouncedQuery]);

  const filtered = debouncedQuery
    ? items.filter((item) => item.id.includes(debouncedQuery))
    : items;

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

      <div className="flex items-center justify-end mb-4">
        <h2 className="text-lg font-bold text-foreground">الأغراض المُعثور عليها ({items.length})</h2>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {filtered.map((item, i) => {
          const isHighlighted = debouncedQuery && item.id.includes(debouncedQuery);
          return (
            <div
              key={item.id}
              ref={isHighlighted ? highlightRef : undefined}
              className={`dashboard-card p-4 animate-fade-in ${isHighlighted ? 'ring-2 ring-primary shadow-lg' : ''}`}
              style={{ animationDelay: `${i * 60}ms` }}
            >
              <div className="flex gap-3">
                <ItemThumbnail
                  imageUrl={item.imageUrl}
                  onClick={() => item.imageUrl && onPreviewImage(item.imageUrl)}
                  size="md"
                />
                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between mb-1">
                    <span className="status-badge status-collected">تم العثور عليه</span>
                    <span className="text-xs text-muted-foreground font-mono">{item.id}</span>
                  </div>

                  <h3 className="text-sm font-bold text-foreground mb-1 flex items-center gap-1 justify-end">
                    {item.itemType}
                    <Package className="h-4 w-4 text-primary" />
                  </h3>

                  <p className="text-xs text-muted-foreground mb-2 text-right line-clamp-1">{item.description}</p>

                  <div className="space-y-1 text-xs text-muted-foreground">
                    <div className="flex items-center gap-1 justify-end">
                      {item.foundLocation}
                      <MapPin className="h-3 w-3 text-accent" />
                    </div>
                    <div className="flex items-center gap-1 justify-end">
                      {item.date} - {item.time}
                      <Clock className="h-3 w-3" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {filtered.length === 0 && (
        <div className="text-center py-16 text-muted-foreground">
          <Package className="h-12 w-12 mx-auto mb-3 opacity-40" />
          <p className="text-lg">{debouncedQuery ? 'لا توجد نتائج للبحث' : 'لا توجد أغراض'}</p>
        </div>
      )}
    </div>
  );
};

export default StaffReports;
