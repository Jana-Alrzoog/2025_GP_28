import { useState } from 'react';
import { ClipboardList, Users, Layers, Plus } from 'lucide-react';
import Navbar from '@/components/Navbar';
import PassengerReports from '@/components/PassengerReports';
import StaffReports from '@/components/StaffReports';
import SimilarityMatching from '@/components/SimilarityMatching';
import OTPModal from '@/components/OTPModal';
import AddFoundItemModal from '@/components/AddFoundItemModal';
import ImagePreviewModal from '@/components/ImagePreviewModal';
import LostFoundAlerts from '@/components/LostFoundAlerts';
import { passengerReports as initialReports, foundItems as initialFoundItems, type PassengerReport, type FoundItem, type SimilarityMatch } from '@/data/mockData';

type Tab = 'passenger' | 'staff' | 'similarity';

const tabConfig: { key: Tab; label: string; icon: typeof ClipboardList }[] = [
  { key: 'similarity', label: 'التطابقات', icon: Layers },
  { key: 'staff', label: 'الأغراض المعثور عليها', icon: Users },
  { key: 'passenger', label: 'بلاغات الركاب', icon: ClipboardList },
];

const LostFound = () => {
  const [activeTab, setActiveTab] = useState<Tab>('passenger');
  const [reports, setReports] = useState<PassengerReport[]>(initialReports);
  const [foundItems, setFoundItems] = useState<FoundItem[]>(initialFoundItems);
  const [selectedReport, setSelectedReport] = useState<PassengerReport | null>(null);
  const [otpOpen, setOtpOpen] = useState(false);
  const [addItemOpen, setAddItemOpen] = useState(false);
  const [confirmingReport, setConfirmingReport] = useState<PassengerReport | null>(null);
  const [previewImage, setPreviewImage] = useState<string | null>(null);

  const handleSelectReport = (report: PassengerReport) => {
    // Only navigate to similarity tab if status is 'matched'
    if (report.status === 'matched') {
      setSelectedReport(report);
      setActiveTab('similarity');
    }
  };

  const handleSelectMatch = (match: SimilarityMatch) => {
    if (!selectedReport) return;
    setReports((prev) =>
      prev.map((r) => (r.id === selectedReport.id ? { ...r, status: 'awaiting' as const } : r))
    );
    setSelectedReport((prev) => prev ? { ...prev, status: 'awaiting' as const } : null);
  };

  const handleConfirmFound = (report: PassengerReport) => {
    setReports((prev) =>
      prev.map((r) => (r.id === report.id ? { ...r, status: 'awaiting' as const } : r))
    );
    setConfirmingReport({ ...report, status: 'awaiting' });
    setSelectedReport((prev) => prev ? { ...prev, status: 'awaiting' as const } : null);
  };

  const handleConfirmCollection = (report: PassengerReport) => {
    setConfirmingReport(report);
    setOtpOpen(true);
  };

  const handleOtpConfirm = () => {
    if (!confirmingReport) return;
    setReports((prev) =>
      prev.map((r) => (r.id === confirmingReport.id ? { ...r, status: 'collected' as const } : r))
    );
    setOtpOpen(false);
    setConfirmingReport(null);
    setSelectedReport(null);
    setActiveTab('passenger');
  };

  const handleAddFoundItem = (item: FoundItem) => {
    setFoundItems((prev) => [item, ...prev]);
  };

  return (
    <div className="min-h-screen">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 py-6 pt-24">
        {/* Tabs + Add Button */}
        <div className="flex items-center gap-3 mb-6 flex-wrap">
          {/* Creative floating add button */}
          <button
            onClick={() => setAddItemOpen(true)}
            className="group relative px-5 py-2.5 rounded-2xl bg-gradient-to-l from-primary to-accent text-primary-foreground text-sm font-bold flex items-center gap-2.5 hover:shadow-lg hover:shadow-primary/25 transition-all duration-300 hover:-translate-y-0.5"
          >
            <Plus className="h-4 w-4 opacity-70 group-hover:opacity-100 transition-opacity" />
            إضافة غرض تم العثور عليه
            <div className="absolute inset-0 rounded-2xl bg-primary-foreground/10 opacity-0 group-hover:opacity-100 transition-opacity" />
          </button>

          <div className="flex gap-2 flex-row-reverse ml-auto">
            {tabConfig.map((tab) => (
              <button
                key={tab.key}
                onClick={() => {
                  setActiveTab(tab.key);
                  if (tab.key !== 'similarity') setSelectedReport(null);
                }}
                className={`px-6 py-2.5 rounded-full text-sm font-bold transition-all duration-200 border ${
                  activeTab === tab.key
                    ? 'bg-primary text-primary-foreground border-primary shadow-sm'
                    : 'bg-card/80 text-muted-foreground border-border/60 hover:bg-secondary'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {/* Main content with alerts panel */}
        <div className="flex gap-6 flex-row-reverse">
          {/* Left alerts panel */}
          <div className="hidden lg:block w-[280px] shrink-0">
            <div className="sticky top-24">
              <LostFoundAlerts />
            </div>
          </div>

          {/* Main content */}
          <div className="flex-1 min-w-0">
            {activeTab === 'passenger' && (
              <PassengerReports
                reports={reports}
                onSelectReport={handleSelectReport}
                onPreviewImage={setPreviewImage}
                onConfirmCollection={handleConfirmCollection}
              />
            )}
            {activeTab === 'staff' && (
              <StaffReports
                items={foundItems}
                onOpenAdd={() => setAddItemOpen(true)}
                onPreviewImage={setPreviewImage}
              />
            )}
            {activeTab === 'similarity' && (
              <SimilarityMatching
                selectedReport={selectedReport}
                foundItems={foundItems}
                reports={reports}
                onSelectMatch={handleSelectMatch}
                onConfirmFound={handleConfirmFound}
                onConfirmCollection={handleConfirmCollection}
                onPreviewImage={setPreviewImage}
              />
            )}
          </div>
        </div>

        <footer className="text-center py-6 mt-8 text-xs text-muted-foreground flex items-center justify-center gap-2">
          <img src="/images/masar-logo.png" alt="مسار" className="h-6 opacity-60" />
          <span>© جميع الحقوق محفوظة 2026</span>
        </footer>
      </div>

      <OTPModal open={otpOpen} onClose={() => setOtpOpen(false)} onConfirm={handleOtpConfirm} />
      <AddFoundItemModal open={addItemOpen} onClose={() => setAddItemOpen(false)} onAdd={handleAddFoundItem} />
      <ImagePreviewModal open={!!previewImage} imageUrl={previewImage} onClose={() => setPreviewImage(null)} />
    </div>
  );
};

export default LostFound;
