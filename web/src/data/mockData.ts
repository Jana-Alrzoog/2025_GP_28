export type ReportStatus = 'searching' | 'matched' | 'awaiting' | 'collected' | 'closed';

export interface PassengerReport {
  id: string;
  itemType: string;
  description: string;
  color: string;
  lostLocation: string;
  date: string;
  time: string;
  status: ReportStatus;
  passengerPhone: string;
  imageUrl?: string;
}

export interface FoundItem {
  id: string;
  itemType: string;
  description: string;
  color: string;
  foundLocation: string;
  date: string;
  time: string;
  foundBy: string;
  imageUrl?: string;
}

export interface SimilarityMatch {
  foundItem: FoundItem;
  overallScore: number;
  descriptionMatch: number;
  colorMatch: number;
  locationMatch: number;
  ruleScore: number;
  semanticScore: number;
  finalScore: number;
  confidence: 'high' | 'medium' | 'low';
}

export interface Alert {
  id: string;
  type: 'critical' | 'warning' | 'info';
  title: string;
  message: string;
  time: string;
}

export const statusLabels: Record<ReportStatus, string> = {
  searching: 'جاري البحث',
  matched: 'تم العثور على تطابق محتمل',
  awaiting: 'بانتظار الاستلام',
  collected: 'تم الاستلام',
  closed: 'مغلق',
};

export const passengerReports: PassengerReport[] = [
  {
    id: '1123245553',
    itemType: 'حقيبة سوداء',
    description: 'هاتف آيفون أسود في محطة قصر الحكم شركة أبل يوم الأحد صباحاً',
    color: 'أسود',
    lostLocation: 'محطة العليا',
    date: '2026/6/31',
    time: '08:30',
    status: 'searching',
    passengerPhone: '+966501234567',
  },
  {
    id: '1123245554',
    itemType: 'هاتف محمول',
    description: 'هاتف آيفون أسود في محطة قصر الحكم شركة أبل يوم الأحد صباحاً',
    color: 'رمادي',
    lostLocation: 'محطة الملك عبدالله',
    date: '2026/6/31',
    time: '14:15',
    status: 'matched',
    passengerPhone: '+966509876543',
  },
  {
    id: '1123245555',
    itemType: 'محفظة',
    description: 'محفظة جلد بني تحتوي على بطاقات',
    color: 'بني',
    lostLocation: 'محطة قصر الحكم',
    date: '2026/6/30',
    time: '18:45',
    status: 'awaiting',
    passengerPhone: '+966505551234',
  },
  {
    id: '1123245556',
    itemType: 'نظارات شمسية',
    description: 'نظارات ريبان أسود',
    color: 'أسود',
    lostLocation: 'محطة البطحاء',
    date: '2026/6/29',
    time: '10:00',
    status: 'collected',
    passengerPhone: '+966507778899',
  },
  {
    id: '1123245557',
    itemType: 'حقيبة يد',
    description: 'حقيبة يد نسائية بيضاء',
    color: 'أبيض',
    lostLocation: 'محطة الملك فهد',
    date: '2026/6/28',
    time: '09:20',
    status: 'closed',
    passengerPhone: '+966502223344',
  },
  {
    id: '1123245558',
    itemType: 'مفاتيح سيارة',
    description: 'مفاتيح تويوتا مع ميدالية زرقاء',
    color: 'فضي',
    lostLocation: 'محطة العليا',
    date: '2026/6/31',
    time: '16:30',
    status: 'searching',
    passengerPhone: '+966508889900',
  },
  {
    id: '1123245559',
    itemType: 'ساعة يد',
    description: 'ساعة كاسيو فضية',
    color: 'فضي',
    lostLocation: 'محطة السليمانية',
    date: '2026/6/27',
    time: '12:00',
    status: 'searching',
    passengerPhone: '+966501112233',
  },
  {
    id: '1123245560',
    itemType: 'سماعات',
    description: 'سماعات آبل إيربودز برو',
    color: 'أبيض',
    lostLocation: 'محطة المروج',
    date: '2026/6/26',
    time: '07:45',
    status: 'searching',
    passengerPhone: '+966504445566',
  },
];

export const foundItems: FoundItem[] = [
  {
    id: 'FI-501',
    itemType: 'حقيبة ظهر',
    description: 'حقيبة ظهر سوداء كبيرة بها أجهزة إلكترونية',
    color: 'أسود',
    foundLocation: 'محطة العليا',
    date: '2026/6/31',
    time: '09:00',
    foundBy: 'أحمد محمد',
  },
  {
    id: 'FI-502',
    itemType: 'حقيبة',
    description: 'حقيبة سوداء صغيرة',
    color: 'أسود',
    foundLocation: 'محطة الملك عبدالله',
    date: '2026/6/31',
    time: '09:30',
    foundBy: 'خالد علي',
  },
  {
    id: 'FI-503',
    itemType: 'حقيبة ظهر',
    description: 'حقيبة ظهر داكنة بها كتب',
    color: 'أسود غامق',
    foundLocation: 'محطة قصر الحكم',
    date: '2026/6/30',
    time: '11:00',
    foundBy: 'سعد العتيبي',
  },
];

// Similarity calculation functions
function calculateColorMatch(color1: string, color2: string): number {
  if (color1 === color2) return 100;
  const c1 = color1.toLowerCase();
  const c2 = color2.toLowerCase();
  if (c1.includes(c2) || c2.includes(c1)) return 80;
  return 20;
}

function calculateLocationMatch(loc1: string, loc2: string): number {
  return loc1 === loc2 ? 100 : 0;
}

function calculateDescriptionMatch(desc1: string, desc2: string): number {
  const words1 = new Set(desc1.split(/\s+/).filter(w => w.length > 2));
  const words2 = new Set(desc2.split(/\s+/).filter(w => w.length > 2));
  if (words1.size === 0 || words2.size === 0) return 0;
  let overlap = 0;
  words1.forEach(w => { if (words2.has(w)) overlap++; });
  return Math.round((overlap / Math.max(words1.size, words2.size)) * 100);
}

function mockSemanticScore(desc1: string, desc2: string): number {
  // Mock semantic similarity - in production would use embeddings
  const base = calculateDescriptionMatch(desc1, desc2);
  const jitter = Math.floor(Math.random() * 15) - 5;
  return Math.max(10, Math.min(100, base + jitter + 15));
}

function getConfidence(score: number): 'high' | 'medium' | 'low' {
  if (score >= 75) return 'high';
  if (score >= 50) return 'medium';
  return 'low';
}

export function calculateSimilarity(report: PassengerReport, items: FoundItem[]): SimilarityMatch[] {
  const matches = items.map(item => {
    const descriptionMatch = calculateDescriptionMatch(report.description, item.description);
    const colorMatch = calculateColorMatch(report.color, item.color);
    const locationMatch = calculateLocationMatch(report.lostLocation, item.foundLocation);

    // Method A: Rule-Based
    const ruleScore = Math.round(descriptionMatch * 0.4 + colorMatch * 0.3 + locationMatch * 0.3);

    // Method B: Semantic (mocked)
    const semanticScore = mockSemanticScore(report.description, item.description);

    // Hybrid
    const finalScore = Math.round(semanticScore * 0.6 + ruleScore * 0.4);
    const overallScore = finalScore;

    return {
      foundItem: item,
      overallScore,
      descriptionMatch,
      colorMatch,
      locationMatch,
      ruleScore,
      semanticScore,
      finalScore,
      confidence: getConfidence(finalScore),
    };
  });

  return matches.sort((a, b) => b.finalScore - a.finalScore).slice(0, 3);
}

export const alerts: Alert[] = [
  {
    id: 'A-1',
    type: 'critical',
    title: 'تقرير منتهي الصلاحية',
    message: 'التقرير 1123245557 لم يتم استلامه خلال 7 أيام',
    time: 'منذ 5 دقائق',
  },
  {
    id: 'A-2',
    type: 'warning',
    title: 'تطابق عالي',
    message: 'تم العثور على تطابق 92% للتقرير 1123245553',
    time: 'منذ 15 دقيقة',
  },
  {
    id: 'A-3',
    type: 'info',
    title: 'تقرير جديد',
    message: 'تم إضافة بلاغ جديد من محطة العليا',
    time: 'منذ 30 دقيقة',
  },
  {
    id: 'A-4',
    type: 'warning',
    title: 'بلاغ قارب الانتهاء',
    message: 'التقرير 1123245555 سينتهي خلال 24 ساعة',
    time: 'منذ ساعة',
  },
];
