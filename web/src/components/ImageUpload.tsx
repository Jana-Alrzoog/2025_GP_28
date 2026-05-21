import { useRef, useState } from 'react';
import { Upload, X, Loader2 } from 'lucide-react';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { storage } from '@/lib/firebase';

interface Props {
  value?: string;
  onChange: (url: string | undefined) => void;
}

const ImageUpload = ({ value, onChange }: Props) => {
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);

  const handleFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith('image/')) return;

    setUploading(true);
    try {
      const fileName = `found_items/${Date.now()}_${file.name}`;
      const storageRef = ref(storage, fileName);
      await uploadBytes(storageRef, file);
      const downloadURL = await getDownloadURL(storageRef);
      onChange(downloadURL);
    } catch (error) {
      console.error('Upload error:', error);
      alert('فشل رفع الصورة. تحقق من Firebase Storage Rules.');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div>
      <label className="block text-sm font-medium text-foreground mb-1 text-right">
        صورة الغرض
      </label>
      {value ? (
        <div className="relative inline-block">
          <img
            src={value}
            alt="Preview"
            className="w-24 h-24 rounded-xl object-cover border border-border"
          />
          <button
            type="button"
            onClick={() => onChange(undefined)}
            className="absolute -top-2 -left-2 bg-destructive text-destructive-foreground p-1 rounded-full"
          >
            <X className="h-3 w-3" />
          </button>
        </div>
      ) : (
        <button
          type="button"
          onClick={() => !uploading && inputRef.current?.click()}
          className="w-full h-24 rounded-xl border-2 border-dashed border-border hover:border-primary/50 bg-muted/50 flex flex-col items-center justify-center gap-2 text-muted-foreground transition-colors"
        >
          {uploading ? (
            <>
              <Loader2 className="h-5 w-5 animate-spin" />
              <span className="text-xs">جاري الرفع...</span>
            </>
          ) : (
            <>
              <Upload className="h-5 w-5" />
              <span className="text-xs">اضغط لرفع صورة (JPG/PNG)</span>
            </>
          )}
        </button>
      )}
      <input
        ref={inputRef}
        type="file"
        accept="image/jpeg,image/png"
        onChange={handleFile}
        className="hidden"
      />
    </div>
  );
};

export default ImageUpload;