import { useMemo, useState } from 'react';
import { type PassengerReport, type FoundItem, type SimilarityMatch, calculateSimilarity, statusLabels } from '@/data/mockData';
import { CheckCircle2, MapPin, Layers, Package, X } from 'lucide-react';
import { ItemThumbnail } from './ImagePreviewModal';
import { Dialog, DialogContent } from './ui/dialog';

interface Props {
  selectedReport: PassengerReport | null;
  foundItems: FoundItem[];
  reports: PassengerReport[];
  onSelectMatch: (match: SimilarityMatch) => void;
  onConfirmFound: (report: PassengerReport) => void;
  onConfirmCollection: (report: PassengerReport) => void;
  onPreviewImage: (url: string) => void;
}

const getSimColor = (score: number) => {
  if (score >= 80) return 'sim-bar-high';
  if (score >= 60) return 'sim-bar-medium';
  return 'sim-bar-low';
};

const getSimTextColor = (score: number) => {
  if (score >= 80) return 'text-[hsl(var(--sim-high))]';
  if (score >= 60) return 'text-[hsl(var(--sim-medium))]';
  return 'text-[hsl(var(--sim-low))]';
};

const SimilarityMatching = ({ selectedReport, foundItems, reports, onSelectMatch, onConfirmFound, onConfirmCollection, onPreviewImage }: Props) => {
  const [confirmData, setConfirmData] = useState<{ match: any; item: FoundItem } | null>(null);

  // For each found item, calculate similarity with all passenger reports
  const matchCards = useMemo(() => {
    return foundItems.map((item) => {
      const matches = reports.map((report) => {
        const sims = calculateSimilarity(report, [item]);
        return sims[0] ? { report, ...sims[0] } : null;
      }).filter(Boolean).sort((a, b) => (b?.finalScore || 0) - (a?.finalScore || 0)).slice(0, 3);
      
      return { item, matches };
    });
  }, [foundItems, reports]);

  if (!selectedReport && matchCards.length === 0) {
    return (
      <div className="text-center py-16 text-muted-foreground animate-fade-in">
        <Layers className="h-12 w-12 mx-auto mb-3 opacity-40" />
        <p className="text-lg">لا توجد أغراض للمقارنة</p>
      </div>
    );
  }

  // If a report is selected and has status matched/awaiting, show action buttons
  const showActions = selectedReport && (selectedReport.status === 'matched' || selectedReport.status === 'awaiting');

  return (
    <div className="animate-fade-in">
      {/* Action bar for selected report */}
      {selectedReport && selectedReport.status === 'matched' && (
        <div className="dashboard-card p-4 mb-6 text-center animate-fade-in">
          <p className="text-sm text-muted-foreground mb-3">تم اختيار التطابق الأفضل للبلاغ {selectedReport.id}</p>
          <button
            onClick={() => onConfirmFound(selectedReport)}
            className="bg-[hsl(var(--status-awaiting))] text-primary-foreground px-6 py-3 rounded-xl font-bold text-sm hover:opacity-90 transition-opacity"
          >
            تأكيد العثور على المفقودات
          </button>
        </div>
      )}

      {selectedReport && selectedReport.status === 'awaiting' && (
        <div className="dashboard-card p-4 mb-6 text-center animate-fade-in">
          <p className="text-sm text-muted-foreground mb-3">المفقودات بانتظار الاستلام - البلاغ {selectedReport.id}</p>
          <button
            onClick={() => onConfirmCollection(selectedReport)}
            className="bg-[hsl(var(--status-awaiting))] text-primary-foreground px-6 py-3 rounded-xl font-bold text-sm hover:opacity-90 transition-opacity"
          >
            تأكيد الاستلام
          </button>
        </div>
      )}

      {/* Grid of found items with their top 3 passenger matches */}
      <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
        {matchCards.map(({ item, matches }, cardIndex) => (
          <div
            key={item.id}
            className="dashboard-card p-5 animate-fade-in"
            style={{ animationDelay: `${cardIndex * 80}ms` }}
          >
            {/* Found item header */}
            <div className="flex items-center gap-3 mb-4 pb-3 border-b border-border">
              <ItemThumbnail
                imageUrl={item.imageUrl}
                onClick={() => item.imageUrl && onPreviewImage(item.imageUrl)}
                size="sm"
              />
              <div className="flex-1 text-right min-w-0">
                <p className="text-sm font-bold text-foreground">{item.itemType}</p>
                <p className="text-xs text-muted-foreground line-clamp-1">{item.description}</p>
                <div className="flex items-center gap-1 justify-end text-xs text-muted-foreground mt-1">
                  <span>{item.foundLocation}</span>
                  <MapPin className="h-3 w-3 text-primary" />
                </div>
              </div>
              <span className="status-badge status-collected text-[10px] shrink-0">غرض موظف</span>
            </div>

            {/* Top 3 passenger matches */}
            <p className="text-xs font-bold text-muted-foreground mb-3 text-right">أعلى 3 تطابقات مع بلاغات الركاب:</p>
            
            {matches.length === 0 ? (
              <p className="text-xs text-muted-foreground text-center py-4">لا توجد تطابقات</p>
            ) : (
              <div className="space-y-3">
                {matches.map((match, i) => {
                  if (!match) return null;
                  const { report, finalScore, descriptionMatch, colorMatch, locationMatch } = match;
                  const isSelected = selectedReport?.id === report.id;

                  return (
                    <div
                      key={report.id}
                      className={`rounded-xl border p-3 transition-all duration-200 ${
                        isSelected ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/30'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-2">
                        <button
                          onClick={() => setConfirmData({ match, item: matchCards[cardIndex].item })}
                          className="text-[10px] bg-primary text-primary-foreground px-2.5 py-1 rounded-lg font-medium hover:opacity-90 transition-opacity flex items-center gap-1"
                        >
                          <CheckCircle2 className="h-3 w-3" />
                          اختيار
                        </button>
                        <div className="text-left">
                          <span className={`text-xl font-extrabold ${getSimTextColor(finalScore)}`}>
                            {finalScore}%
                          </span>
                        </div>
                      </div>

                      <div className="text-right mb-2">
                        <p className="text-xs font-bold text-foreground">{report.itemType}</p>
                        <p className="text-[10px] text-muted-foreground">رقم: {report.id}</p>
                      </div>

                      {/* Mini progress bars */}
                      <div className="space-y-1.5">
                        {[
                          { label: 'الوصف', value: descriptionMatch },
                          { label: 'اللون', value: colorMatch },
                          { label: 'الموقع', value: locationMatch },
                        ].map((metric) => (
                          <div key={metric.label} className="flex items-center gap-2">
                            <span className={`text-[10px] font-bold w-8 ${getSimTextColor(metric.value)}`}>{metric.value}%</span>
                            <div className="flex-1 bg-muted rounded-full h-1.5" dir="ltr">
                              <div
                                className={`h-full rounded-full transition-all duration-700 ${getSimColor(metric.value)}`}
                                style={{ width: `${metric.value}%` }}
                              />
                            </div>
                            <span className="text-[10px] text-muted-foreground w-10 text-right">{metric.label}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        ))}
      </div>

      {matchCards.length === 0 && (
        <div className="text-center py-16 text-muted-foreground">
          <Package className="h-12 w-12 mx-auto mb-3 opacity-40" />
          <p className="text-lg">لا توجد أغراض للمقارنة، أضف أغراض من تبويب بلاغات العاملين</p>
        </div>
      )}
      {/* Confirmation Dialog */}
      <Dialog open={!!confirmData} onOpenChange={(open) => !open && setConfirmData(null)}>
        <DialogContent className="max-w-md p-0 overflow-hidden" dir="rtl">
          <div className="p-6">
            <h3 className="text-lg font-bold text-center text-foreground mb-5">هل أنت متأكد من اختيار هذا المتشابه؟</h3>
            
            {confirmData && (
              <div className="flex gap-4 items-start justify-center mb-6">
                {/* Staff item */}
                <div className="flex-1 text-center">
                  <p className="text-[10px] font-bold text-muted-foreground mb-2">غرض الموظف</p>
                  <div className="w-20 h-20 mx-auto rounded-xl overflow-hidden border border-border mb-2">
                    {confirmData.item.imageUrl ? (
                      <img src={confirmData.item.imageUrl} className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full bg-muted flex items-center justify-center">
                        <Package className="h-6 w-6 text-muted-foreground" />
                      </div>
                    )}
                  </div>
                  <p className="text-xs font-bold text-foreground">{confirmData.item.itemType}</p>
                  <p className="text-[10px] text-muted-foreground line-clamp-2">{confirmData.item.description}</p>
                </div>

                {/* Divider */}
                <div className="flex flex-col items-center gap-1 pt-8">
                  <div className="w-px h-12 bg-border" />
                  <span className="text-xs font-bold text-primary">↔</span>
                  <div className="w-px h-12 bg-border" />
                </div>

                {/* Passenger item */}
                <div className="flex-1 text-center">
                  <p className="text-[10px] font-bold text-muted-foreground mb-2">بلاغ الراكب</p>
                  <div className="w-20 h-20 mx-auto rounded-xl overflow-hidden border border-border mb-2">
                    {confirmData.match.report.imageUrl ? (
                      <img src={confirmData.match.report.imageUrl} className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full bg-muted flex items-center justify-center">
                        <Package className="h-6 w-6 text-muted-foreground" />
                      </div>
                    )}
                  </div>
                  <p className="text-xs font-bold text-foreground">{confirmData.match.report.itemType}</p>
                  <p className="text-[10px] text-muted-foreground">رقم: {confirmData.match.report.id}</p>
                  <p className="text-[10px] text-muted-foreground line-clamp-2">{confirmData.match.report.description}</p>
                </div>
              </div>
            )}

            <div className="flex gap-3">
              <button
                onClick={() => {
                  if (confirmData) onSelectMatch(confirmData.match);
                  setConfirmData(null);
                }}
                className="flex-1 bg-primary text-primary-foreground py-2.5 rounded-xl font-bold text-sm hover:opacity-90 transition-opacity"
              >
                نعم، تأكيد
              </button>
              <button
                onClick={() => setConfirmData(null)}
                className="flex-1 bg-muted text-muted-foreground py-2.5 rounded-xl font-bold text-sm hover:opacity-80 transition-opacity"
              >
                إلغاء
              </button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default SimilarityMatching;
