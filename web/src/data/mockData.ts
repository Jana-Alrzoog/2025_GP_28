export type ReportStatus = 'open' | 'matched' | 'awaiting' | 'collected' | 'closed'

// Passenger lost report (from Firebase: lost_found_reports)
export interface PassengerReport {
  id: string
  ticket_id?: string
  name?: string
  user_id?: string
  passenger_id?: string
  item_type?: string
  itemType?: string
  description: string
  brand?: string | null
  color: string
  station_id?: string
  station_name?: string
  lostLocation?: string
  lost_datetime?: string
  date?: string
  time?: string
  phone?: string
  passengerPhone?: string
  photo_url?: string | null
  imageUrl?: string
  status: ReportStatus
  created_at?: any
}

// Staff found report (from Firebase: found_reports)
export interface FoundItem {
  id: string
  item_id?: string
  itemType?: string
  item_type?: string
  description: string
  brand?: string | null
  color: string
  station_id?: string
  foundLocation?: string
  lost_report_id?: string | null
  match_status?: string
  date?: string
  time?: string
  foundBy?: string
  imageUrl?: string
  status?: string
  created_at?: any
}

export interface SimilarityMatch {
  foundItem: FoundItem
  overallScore: number
  descriptionMatch: number
  colorMatch: number
  locationMatch: number
  ruleScore: number
  semanticScore: number
  finalScore: number
  confidence: 'high' | 'medium' | 'low'
}

export interface Alert {
  id: string
  type: 'critical' | 'warning' | 'info'
  title: string
  message: string
  time: string
}

export const statusLabels: Record<ReportStatus, string> = {
  open:      'جاري البحث',
  matched:   'تم العثور على تطابق',
  awaiting:  'بانتظار الاستلام',
  collected: 'تم الاستلام',
  closed:    'مغلق',
}

// No mock data - all data comes from Firebase
export const passengerReports: PassengerReport[] = []
export const foundItems: FoundItem[] = []

// Rule-based similarity functions (fallback)
function calculateColorMatch(color1: string, color2: string): number {
  if (!color1 || !color2) return 0
  if (color1 === color2) return 100
  const c1 = color1.toLowerCase()
  const c2 = color2.toLowerCase()
  if (c1.includes(c2) || c2.includes(c1)) return 80
  return 20
}

function calculateLocationMatch(loc1: string, loc2: string): number {
  if (!loc1 || !loc2) return 0
  return loc1 === loc2 ? 100 : 0
}

function calculateDescriptionMatch(desc1: string, desc2: string): number {
  if (!desc1 || !desc2) return 0
  const words1 = new Set(desc1.split(/\s+/).filter(w => w.length > 2))
  const words2 = new Set(desc2.split(/\s+/).filter(w => w.length > 2))
  if (words1.size === 0 || words2.size === 0) return 0
  let overlap = 0
  words1.forEach(w => { if (words2.has(w)) overlap++ })
  return Math.round((overlap / Math.max(words1.size, words2.size)) * 100)
}

function mockSemanticScore(desc1: string, desc2: string): number {
  if (!desc1 || !desc2) return 0
  const base = calculateDescriptionMatch(desc1, desc2)
  const jitter = Math.floor(Math.random() * 15) - 5
  return Math.max(10, Math.min(100, base + jitter + 15))
}

function getConfidence(score: number): 'high' | 'medium' | 'low' {
  if (score >= 75) return 'high'
  if (score >= 50) return 'medium'
  return 'low'
}

export function calculateSimilarity(report: PassengerReport, items: FoundItem[]): SimilarityMatch[] {
  const matches = items.map(item => {
    const descriptionMatch = calculateDescriptionMatch(
      report.description || '',
      item.description || ''
    )
    const colorMatch = calculateColorMatch(
      report.color || '',
      item.color || ''
    )
    const locationMatch = calculateLocationMatch(
      report.station_id || report.station_name || '',
      item.station_id || item.foundLocation || ''
    )

    const ruleScore = Math.round(descriptionMatch * 0.4 + colorMatch * 0.3 + locationMatch * 0.3)
    const semanticScore = mockSemanticScore(
      report.description || '',
      item.description || ''
    )
    const finalScore = Math.round(semanticScore * 0.6 + ruleScore * 0.4)

    return {
      foundItem: item,
      overallScore: finalScore,
      descriptionMatch,
      colorMatch,
      locationMatch,
      ruleScore,
      semanticScore,
      finalScore,
      confidence: getConfidence(finalScore),
    }
  })

  return matches.sort((a, b) => b.finalScore - a.finalScore).slice(0, 3)
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
]