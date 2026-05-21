import { MapPin, Clock, Package } from 'lucide-react';
import type { FoundItem } from '@/data/mockData';

interface Props {
  items: FoundItem[];
  onOpenAdd: () => void;
  onPreviewImage: (url: string) => void;
}

const StaffReports = ({ items, onPreviewImage }: Props) => {
  return (
    <div className="animate-fade-in" dir="rtl">
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
        {items.map((item, i) => {
          return (
            <div
              key={item.id}
              className="dashboard-card p-3 animate-fade-in"
              style={{ animationDelay: `${i * 60}ms` }}
            >
              <div className="flex gap-3 items-start mb-2 flex-row-reverse">
                <div className="flex-1">
                  <div className="flex items-center justify-end mb-1">
                    <span className="text-[10px] text-muted-foreground font-mono ml-auto">
                      {item.item_id}
                    </span>
                  </div>

                  <h3 className="text-sm font-bold text-foreground text-right mb-1">
                    {item.itemType}
                  </h3>

                  <p className="text-xs text-muted-foreground line-clamp-2 text-right">
                    {item.description}
                  </p>
                </div>

                <button
                  onClick={() => item.imageUrl && onPreviewImage(item.imageUrl)}
                  className="w-24 h-24 rounded-xl overflow-hidden bg-muted border border-border flex items-center justify-center shrink-0 hover:ring-2 hover:ring-primary/30 transition-all"
                >
                  {item.imageUrl ? (
                    <img
                      src={item.imageUrl}
                      alt="صورة الغرض"
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <Package className="h-8 w-8 text-muted-foreground opacity-40" />
                  )}
                </button>
              </div>

              <div className="flex flex-wrap gap-1 justify-start mb-2">
                <span className="status-badge status-collected text-[10px] px-2 py-0.5">
                  تم العثور عليه
                </span>

                <span className="text-[10px] px-2 py-0.5 rounded-full bg-secondary text-foreground">
                  {item.color}
                </span>

                {item.brand && (
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-accent/20 text-accent">
                    {item.brand}
                  </span>
                )}
              </div>

              <div className="space-y-0.5 text-xs text-muted-foreground">
                <div className="flex items-center gap-1">
                  <MapPin className="h-3 w-3 text-accent shrink-0" />
                  <span>{item.foundLocation}</span>
                </div>

                <div className="flex items-center gap-1">
                  <Clock className="h-3 w-3 shrink-0" />
                  <span>
                    {item.date} - {item.time}
                  </span>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {items.length === 0 && (
        <div className="text-center py-16 text-muted-foreground">
          <Package className="h-12 w-12 mx-auto mb-3 opacity-40" />
          <p className="text-base">لا توجد أغراض</p>
        </div>
      )}
    </div>
  );
};

export default StaffReports;