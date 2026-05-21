import { useMemo, useState } from 'react';
import { type PassengerReport, type FoundItem, type SimilarityMatch } from '@/data/mockData';
import { type MatchGroup } from '@/hooks/useMatching';
import { CheckCircle2, MapPin, Layers, Package, Clock, User, Tag, ZoomIn, X } from 'lucide-react';
import { ItemThumbnail } from './ImagePreviewModal';
import { Dialog, DialogContent } from './ui/dialog';

interface Props {
  selectedReport: PassengerReport | null;
  foundItems: FoundItem[];
  reports: PassengerReport[];
  matchGroups?: MatchGroup[];
  onSelectMatch: (match: SimilarityMatch) => void;
  onConfirmFound: (report: PassengerReport) => void;
  onConfirmCollection: (report: PassengerReport) => void;
  onApproveMatch?: (foundReportId: string, lostReportId: string) => void;
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

const getScoreBg = (score: number) => {
  if (score >= 80) return 'bg-[hsl(var(--status-collected-bg))] text-[hsl(var(--sim-high))]';
  if (score >= 50) return 'bg-[hsl(var(--status-searching-bg))] text-[hsl(var(--sim-medium))]';
  return 'bg-muted text-muted-foreground';
};

const PreviewableImage = ({
  imageUrl,
  onPreview,
}: {
  imageUrl?: string | null;
  onPreview: () => void;
}) => (
  <button
    onClick={(e) => { e.stopPropagation(); imageUrl && onPreview(); }}
    className="w-24 h-24 mx-auto rounded-xl overflow-hidden border border-border mb-2 relative group cursor-zoom-in block hover:ring-2 hover:ring-primary/30 transition-all"
  >
    {imageUrl ? (
      <>
        <img src={imageUrl} className="w-full h-full object-cover" />
        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
          <ZoomIn className="h-6 w-6 text-white" />
        </div>
      </>
    ) : (
      <div className="w-full h-full bg-muted flex items-center justify-center">
        <Package className="h-6 w-6 text-muted-foreground" />
      </div>
    )}
  </button>
);

const SimilarityMatching = ({
  selectedReport,
  foundItems,
  reports,
  matchGroups,
  onSelectMatch,
  onConfirmFound,
  onConfirmCollection,
  onApproveMatch,
  onPreviewImage,
}: Props) => {
  const [confirmData, setConfirmData] = useState<{ match: any; item: FoundItem } | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  const matchCards = useMemo(() => {
    if (matchGroups && matchGroups.length > 0) {
      return matchGroups.map(({ found, matches }) => ({
        item: found,
        matches: matches.map(m => {
          const report = reports.find(r => r.id === m.lost_report_id)
          if (!report) return null
          return {
            report,
            finalScore: m.final_score,
            descriptionMatch: m.semantic_similarity,
            colorMatch: m.color_match,
            locationMatch: m.location_score,
            timeScore: m.time_score,
            brandMatch: m.brand_match,
            imageMatch: m.image_similarity,
            ...m,
          }
        }).filter(Boolean),
      }))
    }
    return []
  }, [foundItems, reports, matchGroups]);

  if (!selectedReport && matchCards.length === 0) {
    return (
      <div className="text-center py-16 text-muted-foreground animate-fade-in">
        <Layers className="h-12 w-12 mx-auto mb-3 opacity-40" />
        <p className="text-lg">لا توجد أغراض للمقارنة</p>
      </div>
    );
  }

  return (
    <div className="animate-fade-in">
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

      <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
        {matchCards.map(({ item, matches }, cardIndex) => (
          <div
            key={item.id}
            className="dashboard-card p-5 animate-fade-in"
            style={{ animationDelay: `${cardIndex * 80}ms` }}
          >
            <div className="flex items-center gap-3 mb-4 pb-3 border-b border-border">
              <ItemThumbnail
                imageUrl={item.imageUrl}
                onClick={() => item.imageUrl && onPreviewImage(item.imageUrl)}
                size="sm"
              />
              <div className="flex-1 text-right min-w-0">
                <p className="text-sm font-bold text-foreground">{item.itemType || item.item_type}</p>
                <p className="text-xs text-muted-foreground line-clamp-1">{item.description}</p>
                <div className="flex items-center gap-1 justify-end text-xs text-muted-foreground mt-1">
                  <span>{item.foundLocation}</span>
                  <MapPin className="h-3 w-3 text-primary" />
                </div>
              </div>
            </div>

            <p className="text-xs font-bold text-muted-foreground mb-3 text-right">
              أعلى {matches.length} تطابقات مع بلاغات الركاب:
            </p>

            {matches.length === 0 ? (
              <p className="text-xs text-muted-foreground text-center py-4">لا توجد تطابقات فوق 50%</p>
            ) : (
              <div className="space-y-3">
                {matches.map((match) => {
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
                          onClick={() => setConfirmData({ match, item })}
                          className="text-[10px] bg-primary text-primary-foreground px-2.5 py-1 rounded-lg font-medium hover:opacity-90 transition-opacity flex items-center gap-1"
                        >
                          <CheckCircle2 className="h-3 w-3" />
                          اختيار
                        </button>
                        <span className={`text-xl font-extrabold ${getSimTextColor(finalScore)}`}>
                          {finalScore}%
                        </span>
                      </div>

                      <div className="text-right mb-2">
                        <p className="text-xs font-bold text-foreground">
                          {report.item_type || report.itemType}
                        </p>
                        <p className="text-[10px] text-muted-foreground">
                          رقم: {report.ticket_id || report.id}
                        </p>
                      </div>

                      <div className="space-y-1.5">
                        {[
                          { label: 'الوصف', value: descriptionMatch },
                          { label: 'اللون', value: colorMatch },
                          { label: 'الموقع', value: locationMatch },
                        ].map((metric) => (
                          <div key={metric.label} className="flex items-center gap-2">
                            <span className={`text-[10px] font-bold w-8 ${getSimTextColor(metric.value)}`}>
                              {metric.value}%
                            </span>
                            <div className="flex-1 bg-muted rounded-full h-1.5" dir="ltr">
                              <div
                                className={`h-full rounded-full transition-all duration-700 ${getSimColor(metric.value)}`}
                                style={{ width: `${metric.value}%` }}
                              />
                            </div>
                            <span className="text-[10px] text-muted-foreground w-10 text-right">
                              {metric.label}
                            </span>
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
          <p className="text-lg">لا توجد أغراض للمقارنة</p>
        </div>
      )}

      {/* ← Preview فوق كل شيء بـ z-[9999] */}
      {previewUrl && (
        <div
          className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/80 backdrop-blur-sm"
          onClick={() => setPreviewUrl(null)}
        >
          <button
            onClick={() => setPreviewUrl(null)}
            className="absolute top-4 left-4 bg-white/20 hover:bg-white/30 text-white p-2 rounded-full transition-colors"
          >
            <X className="h-5 w-5" />
          </button>
          <img
            src={previewUrl}
            className="max-w-[90vw] max-h-[90vh] rounded-2xl shadow-2xl object-contain"
            onClick={(e) => e.stopPropagation()}
          />
        </div>
      )}

      <Dialog open={!!confirmData} onOpenChange={(open) => !open && setConfirmData(null)}>
        <DialogContent className="max-w-lg p-0 overflow-hidden" dir="rtl">
          <div className="p-6 overflow-y-auto max-h-[85vh]">
            <h3 className="text-lg font-bold text-center text-foreground mb-2">
              مقارنة تفصيلية
            </h3>
            <p className="text-xs text-muted-foreground text-center mb-5">
              هل أنت متأكد من اختيار هذا التطابق؟
            </p>

            {confirmData && (
              <>
                <div className="flex gap-4 items-start justify-center mb-5">
                  <div className="flex-1 text-center">
                    <p className="text-[10px] font-bold text-muted-foreground mb-2">بلاغ الراكب</p>
                    <PreviewableImage
                      imageUrl={confirmData.match.report.photo_url}
                      onPreview={() => setPreviewUrl(confirmData.match.report.photo_url)}
                    />
                    <p className="text-xs font-bold text-foreground">
                      {confirmData.match.report.item_type || confirmData.match.report.itemType}
                    </p>
                    <p className="text-[10px] text-muted-foreground">
                      {confirmData.match.report.ticket_id || confirmData.match.report.id}
                    </p>
                  </div>

                  <div className="flex flex-col items-center gap-1 pt-10">
                    <div className="w-px h-8 bg-border" />
                    <span className="text-sm font-bold text-primary">↔</span>
                    <div className="w-px h-8 bg-border" />
                  </div>

                  <div className="flex-1 text-center">
                    <p className="text-[10px] font-bold text-muted-foreground mb-2">غرض الموظف</p>
                    <PreviewableImage
                      imageUrl={confirmData.item.imageUrl}
                      onPreview={() => setPreviewUrl(confirmData.item.imageUrl || null)}
                    />
                    <p className="text-xs font-bold text-foreground">
                      {confirmData.item.itemType || confirmData.item.item_type}
                    </p>
                    <p className="text-[10px] text-muted-foreground">
                      {confirmData.item.foundLocation}
                    </p>
                  </div>
                </div>

                <div className={`rounded-xl p-3 text-center mb-4 ${getScoreBg(confirmData.match.finalScore || confirmData.match.final_score)}`}>
                  <p className="text-xs font-bold mb-1">نسبة التطابق الإجمالية</p>
                  <p className="text-3xl font-extrabold">
                    {confirmData.match.finalScore || confirmData.match.final_score}%
                  </p>
                </div>

                <div className="dashboard-card p-4 mb-4">
                  <p className="text-xs font-bold text-foreground mb-3 text-right">تفاصيل المقارنة:</p>
                  <div className="space-y-2.5">
                    {[
                      { label: 'الوصف والمعنى', value: confirmData.match.descriptionMatch || confirmData.match.semantic_similarity || 0 },
                      { label: 'اللون', value: confirmData.match.colorMatch || confirmData.match.color_match || 0 },
                      { label: 'الموقع', value: confirmData.match.locationMatch || confirmData.match.location_score || 0 },
                      { label: 'الوقت', value: confirmData.match.timeScore || confirmData.match.time_score || 0 },
                      ...(confirmData.match.brandMatch || confirmData.match.brand_match
                        ? [{ label: 'الماركة', value: confirmData.match.brandMatch || confirmData.match.brand_match }]
                        : []),
                      ...(confirmData.match.imageMatch || confirmData.match.image_similarity
                        ? [{ label: 'الصورة', value: confirmData.match.imageMatch || confirmData.match.image_similarity }]
                        : []),
                    ].map((metric) => (
                      <div key={metric.label} className="flex items-center gap-3">
                        <span className={`text-[10px] font-bold w-6 text-left ${getSimTextColor(metric.value)}`}>
                          {metric.value}%
                        </span>
                        <div className="flex-1 bg-muted rounded-full h-2" dir="ltr">
                          <div
                            className={`h-full rounded-full transition-all duration-700 ${getSimColor(metric.value)}`}
                            style={{ width: `${metric.value}%` }}
                          />
                        </div>
                        <span className="text-[10px] text-muted-foreground w-20 text-right">
                          {metric.label}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="dashboard-card p-4 mb-4">
                  <p className="text-xs font-bold text-foreground mb-3 text-right">معلومات الراكب:</p>
                  <div className="space-y-1.5">
                    {confirmData.match.report.name && (
                      <div className="flex items-center gap-2 text-xs text-muted-foreground">
                        <User className="h-3 w-3 shrink-0" />
                        <span>{confirmData.match.report.name}</span>
                      </div>
                    )}
                    {confirmData.match.report.station_name && (
                      <div className="flex items-center gap-2 text-xs text-muted-foreground">
                        <MapPin className="h-3 w-3 shrink-0" />
                        <span>{confirmData.match.report.station_name}</span>
                      </div>
                    )}
                    {confirmData.match.report.lost_datetime && (
                      <div className="flex items-center gap-2 text-xs text-muted-foreground">
                        <Clock className="h-3 w-3 shrink-0" />
                        <span>{confirmData.match.report.lost_datetime}</span>
                      </div>
                    )}
                    {confirmData.match.report.description && (
                      <div className="flex items-center gap-2 text-xs text-muted-foreground">
                        <Tag className="h-3 w-3 shrink-0" />
                        <span>{confirmData.match.report.description}</span>
                      </div>
                    )}
                  </div>
                </div>
              </>
            )}

            <div className="flex gap-3">
              <button
                onClick={async () => {
                  if (confirmData) {
                    if (onApproveMatch && confirmData.match.found_report_id) {
                      await onApproveMatch(
                        confirmData.match.found_report_id,
                        confirmData.match.lost_report_id
                      )
                    } else {
                      onSelectMatch(confirmData.match)
                    }
                  }
                  setConfirmData(null)
                }}
                className="flex-1 bg-primary text-primary-foreground py-2.5 rounded-xl font-bold text-sm hover:opacity-90 transition-opacity"
              >
                نعم، تأكيد التطابق
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