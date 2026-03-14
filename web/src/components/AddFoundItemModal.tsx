import { useState, useEffect } from 'react';
import { X, Plus } from 'lucide-react';
import type { FoundItem } from '@/data/mockData';
import ImageUpload from './ImageUpload';

interface Props {
  open: boolean;
  onClose: () => void;
  onAdd: (item: FoundItem) => void;
}

const stations = [
  'محطة العليا',
  'محطة الملك عبدالله',
  'محطة قصر الحكم',
  'محطة البطحاء',
  'محطة الملك فهد',
  'محطة السليمانية',
  'محطة المروج',
];

const initialForm = {
  itemType: '',
  description: '',
  color: '',
  foundLocation: '',
  date: '',
  time: '',
  imageUrl: undefined as string | undefined,
};

const AddFoundItemModal = ({ open, onClose, onAdd }: Props) => {
  const [form, setForm] = useState(initialForm);

  useEffect(() => {
    if (open) setForm(initialForm);
  }, [open]);

  const handleChange = (field: string, value: string) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const requiredFields = ['itemType', 'description', 'color', 'foundLocation', 'date', 'time'];
  const isValid = requiredFields.every((f) => (form as any)[f]?.trim() !== '');

  const handleSubmit = () => {
    if (!isValid) return;
    const newItem: FoundItem = {
      id: `FI-${Date.now().toString().slice(-4)}`,
      itemType: form.itemType.trim(),
      description: form.description.trim(),
      color: form.color.trim(),
      foundLocation: form.foundLocation,
      date: form.date,
      time: form.time,
      foundBy: 'النظام',
      imageUrl: form.imageUrl,
    };
    onAdd(newItem);
    onClose();
  };

  if (!open) return null;

  const inputClass = "w-full px-3 py-2 rounded-xl border border-border bg-card text-foreground text-sm text-right outline-none focus:border-primary focus:ring-1 focus:ring-primary/20 transition-all";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-foreground/40 backdrop-blur-sm animate-fade-in">
      <div className="dashboard-card p-5 w-full max-w-2xl mx-4 animate-scale-in relative">
        <button onClick={onClose} className="absolute top-3 left-3 p-1 rounded hover:bg-secondary transition-colors">
          <X className="h-5 w-5 text-muted-foreground" />
        </button>

        <div className="text-center mb-4">
          <div className="bg-primary/10 p-2.5 rounded-xl inline-block mb-2">
            <Plus className="h-5 w-5 text-primary" />
          </div>
          <h3 className="text-lg font-bold text-foreground">إضافة غرض مفقود</h3>
          <p className="text-xs text-muted-foreground">أدخل بيانات الغرض الذي تم العثور عليه</p>
        </div>

        <div className="grid grid-cols-2 gap-x-4 gap-y-3">
          {/* Image upload - spans full width but compact */}
          <div className="col-span-2">
            <ImageUpload
              value={form.imageUrl}
              onChange={(url) => setForm((prev) => ({ ...prev, imageUrl: url }))}
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-foreground mb-1 text-right">نوع الغرض</label>
            <input
              type="text"
              value={form.itemType}
              onChange={(e) => handleChange('itemType', e.target.value)}
              placeholder="مثال: حقيبة ظهر"
              className={inputClass}
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-foreground mb-1 text-right">اللون</label>
            <input
              type="text"
              value={form.color}
              onChange={(e) => handleChange('color', e.target.value)}
              placeholder="مثال: أسود"
              className={inputClass}
            />
          </div>

          <div className="col-span-2">
            <label className="block text-xs font-medium text-foreground mb-1 text-right">الوصف</label>
            <input
              type="text"
              value={form.description}
              onChange={(e) => handleChange('description', e.target.value)}
              placeholder="وصف تفصيلي للغرض..."
              className={inputClass}
            />
          </div>

          <div className="col-span-2">
            <label className="block text-xs font-medium text-foreground mb-1 text-right">مكان العثور</label>
            <select
              value={form.foundLocation}
              onChange={(e) => handleChange('foundLocation', e.target.value)}
              className={inputClass}
            >
              <option value="">اختر المحطة</option>
              {stations.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-foreground mb-1 text-right">التاريخ</label>
            <input
              type="date"
              value={form.date}
              onChange={(e) => handleChange('date', e.target.value)}
              className={inputClass}
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-foreground mb-1 text-right">الوقت</label>
            <input
              type="time"
              value={form.time}
              onChange={(e) => handleChange('time', e.target.value)}
              className={inputClass}
            />
          </div>
        </div>

        <button
          onClick={handleSubmit}
          disabled={!isValid}
          className="w-full mt-4 bg-primary text-primary-foreground py-2.5 rounded-xl font-bold text-sm hover:opacity-90 transition-opacity disabled:opacity-40"
        >
          إضافة الغرض
        </button>
      </div>
    </div>
  );
};

export default AddFoundItemModal;
