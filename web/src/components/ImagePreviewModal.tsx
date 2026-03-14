import { X, ImageIcon } from 'lucide-react';

interface Props {
  open: boolean;
  imageUrl: string | null;
  onClose: () => void;
}

const ImagePreviewModal = ({ open, imageUrl, onClose }: Props) => {
  if (!open || !imageUrl) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-foreground/50 backdrop-blur-sm animate-fade-in" onClick={onClose}>
      <div className="relative max-w-2xl max-h-[80vh] mx-4" onClick={(e) => e.stopPropagation()}>
        <button
          onClick={onClose}
          className="absolute -top-3 -left-3 z-10 bg-card p-1.5 rounded-full shadow-lg hover:bg-secondary transition-colors"
        >
          <X className="h-4 w-4 text-foreground" />
        </button>
        <img
          src={imageUrl}
          alt="معاينة الصورة"
          className="rounded-2xl shadow-2xl max-h-[80vh] object-contain bg-card"
        />
      </div>
    </div>
  );
};

export const ItemThumbnail = ({
  imageUrl,
  onClick,
  size = 'md',
}: {
  imageUrl?: string;
  onClick?: () => void;
  size?: 'sm' | 'md' | 'lg';
}) => {
  const sizeClasses = {
    sm: 'w-16 h-16',
    md: 'w-20 h-20',
    lg: 'w-24 h-24',
  };

  return (
    <button
      onClick={onClick}
      className={`${sizeClasses[size]} rounded-xl overflow-hidden bg-muted border border-border flex items-center justify-center shrink-0 hover:ring-2 hover:ring-primary/30 transition-all cursor-pointer`}
    >
      {imageUrl ? (
        <img src={imageUrl} alt="صورة الغرض" className="w-full h-full object-cover" />
      ) : (
        <div className="flex flex-col items-center gap-1 text-muted-foreground">
          <ImageIcon className="h-6 w-6 opacity-40" />
          <span className="text-[9px]">لا توجد صورة</span>
        </div>
      )}
    </button>
  );
};

export default ImagePreviewModal;
