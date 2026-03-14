import { useState, useRef } from 'react';
import { Upload, X, ImageIcon } from 'lucide-react';

interface Props {
  value?: string;
  onChange: (dataUrl: string | undefined) => void;
}

const ImageUpload = ({ value, onChange }: Props) => {
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith('image/')) return;
    
    const reader = new FileReader();
    reader.onload = () => {
      onChange(reader.result as string);
    };
    reader.readAsDataURL(file);
  };

  return (
    <div>
      <label className="block text-sm font-medium text-foreground mb-1 text-right">صورة الغرض</label>
      {value ? (
        <div className="relative inline-block">
          <img src={value} alt="Preview" className="w-24 h-24 rounded-xl object-cover border border-border" />
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
          onClick={() => inputRef.current?.click()}
          className="w-full h-24 rounded-xl border-2 border-dashed border-border hover:border-primary/50 bg-muted/50 flex flex-col items-center justify-center gap-2 text-muted-foreground transition-colors"
        >
          <Upload className="h-5 w-5" />
          <span className="text-xs">اضغط لرفع صورة (JPG/PNG)</span>
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
