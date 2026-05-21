import { useState, useEffect } from 'react';
import { X, Plus } from 'lucide-react';
import type { FoundItem } from '@/data/mockData';
import ImageUpload from './ImageUpload';
import Lottie from "lottie-react";
import loadingAnimation from "../data/loading.json";
import { auth, db } from '@/lib/firebase';
import {
  collection,
  getDocs,
  limit,
  query,
  where,
} from 'firebase/firestore';
interface Props {
  open: boolean;
  onClose: () => void;
  onAdd: (item: FoundItem) => void;
}

const STATION_OPTIONS = [
  { id: 'kafd', label: 'كافد' },
  { id: 'stc_olaya', label: 'محطة STC ' },
  { id: 'qasr_alhokm', label: 'قصر الحكم' },
  { id: 'national_museum', label: 'المتحف الوطني' },
  { id: 'airport_t1_t2', label: 'المطار (1-2)' },
  { id: 'first_industrial', label: 'المدينة الصناعية الاولى' },
];

const initialForm = {
  itemType: '',
  description: '',
  brand: '',
  color: '',
  station_id: '',
  foundLocation: '',
  imageUrl: undefined as string | undefined,
};

const AddFoundItemModal = ({ open, onClose, onAdd }: Props) => {
  const [form, setForm] = useState(initialForm);
  const [adminName, setAdminName] = useState('');
  const [isLoadingAI, setIsLoadingAI] = useState(false);
 useEffect(() => {
  if (open) {
    setForm(initialForm);
    fetchAdminName();
  }
}, [open]);

const fetchAdminName = async () => {
  try {
    const user = auth.currentUser;

    if (!user?.email) {
      setAdminName('');
      return;
    }

    const q = query(
      collection(db, 'staff'),
      where('email', '==', user.email),
      where('active', '==', true),
      limit(1)
    );

    const snapshot = await getDocs(q);

    if (!snapshot.empty) {
      const staffData = snapshot.docs[0].data();
      setAdminName(staffData.name || '');
    } else {
      setAdminName('');
    }
  } catch (error) {
    console.error('Error fetching admin name:', error);
    setAdminName('');
  }
};

  const handleChange = (field: string, value: string) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const requiredFields = ['itemType', 'description', 'color', 'station_id'];
  const isValid = requiredFields.every((f) => (form as any)[f]?.trim() !== '');

  const handleSubmit = () => {
    if (!isValid) return;

    const now = new Date();

    const autoDate = now.toISOString().split('T')[0];

    const autoTime = now.toLocaleTimeString('en-GB', {
      hour: '2-digit',
      minute: '2-digit',
    });

    const selectedStation = STATION_OPTIONS.find(
      (station) => station.id === form.station_id
    );
    const count = Date.now().toString().slice(-3);
    const newItem: FoundItem = {
      id: ``,
      item_id: `FI-${count}`,
      itemType: form.itemType.trim(),
      description: form.description.trim(),
      brand: form.brand.trim() || null,
      color: form.color.trim(),
      station_id: form.station_id,
      foundLocation: selectedStation?.label || '',
      lost_report_id: null,
      match_status: 'pending',
      date: autoDate,
      time: autoTime,
      foundBy: adminName,
      imageUrl: form.imageUrl,
    };

    onAdd(newItem);
    onClose();
  };

  if (!open) return null;

  const inputClass =
    "w-full px-3 py-2 rounded-xl border border-border bg-card text-foreground text-sm text-right outline-none focus:border-primary focus:ring-1 focus:ring-primary/20 transition-all";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-foreground/40 backdrop-blur-sm animate-fade-in">
      <div className="dashboard-card p-5 w-full max-w-2xl mx-4 animate-scale-in relative">
        <button
          onClick={onClose}
          className="absolute top-3 left-3 p-1 rounded hover:bg-secondary transition-colors"
        >
          <X className="h-5 w-5 text-muted-foreground" />
        </button>

        <div className="text-center mb-4">
          <div className="bg-primary/10 p-2.5 rounded-xl inline-block mb-2">
            <Plus className="h-5 w-5 text-primary" />
          </div>

          <h3 className="text-lg font-bold text-foreground">
            إضافة غرض تم العثور عليه
          </h3>

          <p className="text-xs text-muted-foreground">
            أدخل بيانات الغرض الذي تم العثور عليه
          </p>
        </div>

        <div className="grid grid-cols-2 gap-x-4 gap-y-3">
            <div className="col-span-2">
<ImageUpload
  value={form.imageUrl}
onChange={async (url) => {
  setForm((prev) => ({ ...prev, imageUrl: url }));

  setIsLoadingAI(true); 

  try {
    const res = await fetch(
      "https://us-central1-masarapp-b9521.cloudfunctions.net/analyzeImage",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ imageUrl: url }),
      }
    );

    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.details || data.error || "AI request failed");
    }

    const cleaned = (data.raw || "")
      .replace(/```json/g, "")
      .replace(/```/g, "")
      .trim();

    const parsed = JSON.parse(cleaned);

    setForm((prev) => ({
      ...prev,
      itemType: parsed.itemType || prev.itemType,
      color: parsed.color || prev.color,
      brand: parsed.brand || prev.brand,
      description: parsed.description || prev.description,
    }));
  } catch (error) {
    console.error("AI error:", error);
  } finally {
    setIsLoadingAI(false); 
  }
}}
/>
{isLoadingAI && (
  <div className="absolute inset-0 z-50 flex flex-col items-center justify-center bg-white/20 backdrop-blur-sm rounded-xl">
    <Lottie
      animationData={loadingAnimation}
      style={{ width: 120, height: 120 }}
    />
    <p className="text-xs text-gray-700 mt-1 font-medium">
      جاري تحليل البيانات...
    </p>
  </div>
)}
          </div>

          <div>
            <label className="block text-xs font-medium text-foreground mb-1 text-right">
              نوع الغرض
            </label>

            <input
              type="text"
              value={form.itemType}
              onChange={(e) => handleChange('itemType', e.target.value)}
              placeholder="مثال: حقيبة ظهر"
              className={inputClass}
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-foreground mb-1 text-right">
              الماركة (اختياري)
            </label>

            <input
              type="text"
              value={form.brand}
              onChange={(e) => handleChange('brand', e.target.value)}
              placeholder="مثال: آبل"
              className={inputClass}
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-foreground mb-1 text-right">
              اللون
            </label>

            <input
              type="text"
              value={form.color}
              onChange={(e) => handleChange('color', e.target.value)}
              placeholder="مثال: أسود"
              className={inputClass}
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-foreground mb-1 text-right">
              المحطة
            </label>

            <select
              value={form.station_id}
              onChange={(e) => handleChange('station_id', e.target.value)}
              className={inputClass}
            >
              <option value="">اختر المحطة</option>

              {STATION_OPTIONS.map((station) => (
                <option key={station.id} value={station.id}>
                  {station.label}
                </option>
              ))}
            </select>
          </div>

          <div className="col-span-2">
            <label className="block text-xs font-medium text-foreground mb-1 text-right">
              الوصف
            </label>

            <input
              type="text"
              value={form.description}
              onChange={(e) => handleChange('description', e.target.value)}
              placeholder="وصف تفصيلي للغرض..."
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