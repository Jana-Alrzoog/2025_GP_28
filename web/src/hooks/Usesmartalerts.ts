import { useState, useEffect, useCallback, useRef } from 'react'
import { collection, getDocs, limit, orderBy, query } from 'firebase/firestore'
import { db } from '@/lib/firebase'

/* ── Types ── */
export interface SmartAlert {
  id: string
  type: 'critical' | 'warning' | 'info'
  title: string
  message: string
  time: string
  badge: string
  stationId?: string
  stationName?: string
}

/* ── Constants ── */
const MASAR_API_BASE_URL = 'https://masar-sim.onrender.com'
const ALL_STATIONS = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6']

const STATION_NAMES: Record<string, string> = {
  S1: 'المركز المالي',
  S2: 'stc',
  S3: 'قصر الحكم',
  S4: 'المتحف الوطني',
  S5: 'الصالة 1-2',
  S6: 'المدينة الصناعية الأولى',
}

/* ── إشعارات ثابتة لكل محطة Demo ── */
const STATION_STATIC_ALERTS: Record<string, SmartAlert[]> = {
  S1: [
    {
      id: 's1-1',
      type: 'warning',
      badge: 'تحذير',
      title: 'مصعد رقم 2 خارج الخدمة مؤقتاً',
      message: 'يرجى استخدام المصعد رقم 1 أو السلالم المتحركة',
      time: 'منذ ساعتين',
    },
    {
      id: 's1-2',
      type: 'info',
      badge: 'معلومة',
      title: 'صيانة مجدولة للبوابات',
      message: 'الجمعة القادمة من 2 - 6 صباحاً',
      time: 'مجدول',
    },
  ],
  S2: [
    {
      id: 's2-1',
      type: 'info',
      badge: 'معلومة',
      title: 'جميع الأجهزة تعمل بشكل طبيعي',
      message: 'لا توجد أعطال مسجلة في المحطة',
      time: 'محدّث',
    },
  ],
  S3: [
    {
      id: 's3-1',
      type: 'warning',
      badge: 'تحذير',
      title: 'أعمال صيانة في المخرج الشمالي',
      message: 'يرجى التوجه عبر المخرج الجنوبي',
      time: 'جاري الآن',
    },
    {
      id: 's3-2',
      type: 'info',
      badge: 'معلومة',
      title: 'تحويل مسار مؤقت',
      message: 'المخرج الشمالي مغلق حتى إشعار آخر',
      time: 'جاري الآن',
    },
  ],
  S4: [
    {
      id: 's4-1',
      type: 'warning',
      badge: 'تحذير',
      title: 'شاشات المعلومات تعمل بشكل جزئي',
      message: 'الشاشات في الرصيف B متوقفة مؤقتاً',
      time: 'منذ 3 ساعات',
    },
  ],
  S5: [
    {
      id: 's5-1',
      type: 'info',
      badge: 'معلومة',
      title: 'ازدحام متوقع أوقات الرحلات',
      message: 'يُنصح بالحضور مبكراً خلال أوقات الذروة',
      time: 'تنبيه دوري',
    },
    {
      id: 's5-2',
      type: 'info',
      badge: 'معلومة',
      title: 'جميع البوابات تعمل بشكل طبيعي',
      message: 'لا توجد أعطال في بوابات الدخول والخروج',
      time: 'محدّث',
    },
  ],
  S6: [
    {
      id: 's6-1',
      type: 'info',
      badge: 'معلومة',
      title: 'جميع الأجهزة تعمل بشكل طبيعي',
      message: 'لا توجد أعطال مسجلة في المحطة',
      time: 'محدّث',
    },
  ],
}

/* ── جلب آخر tick فقط لمحطة ── */
async function getLatestTick(stationId: string) {
  try {
    const ticksRef = collection(db, 'live', stationId, 'ticks')

    const q = query(
      ticksRef,
      orderBy('timestamp', 'desc'),
      limit(1)
    )

    const snapshot = await getDocs(q)

    if (snapshot.empty) return null

    const d = snapshot.docs[0].data()

    const capacityStation = Number(
      d.capacity_station ??
        d.events?.capacity_station ??
        4800
    )

    const stationTotal = Number(
      d.events?.station_total ??
        d.station_total ??
        0
    )

    const loadRatio = Number(
      d.load_ratio ??
        d.events?.load_ratio ??
        (capacityStation > 0 ? stationTotal / capacityStation : 0)
    )

    const crowdLevel = String(
      d.crowd_level ??
        d.events?.crowd_level ??
        'Low'
    )

    return {
      stationId,
      stationNameAr: STATION_NAMES[stationId] || stationId,
      crowdLevel,
      loadRatio,
      stationTotal,
      capacityStation,
    }
  } catch {
    return null
  }
}

/* ── القواعد: بدون محطة ── */
function applyGeneralRules(
  ticks: NonNullable<Awaited<ReturnType<typeof getLatestTick>>>[]
): SmartAlert[] {
  const alerts: SmartAlert[] = []

  ticks.forEach((t, i) => {
    if (
      !t.stationTotal ||
      t.stationTotal === 0 ||
      !t.capacityStation ||
      isNaN(t.loadRatio) ||
      t.loadRatio <= 0
    ) {
      return
    }

    const level = t.crowdLevel.toLowerCase()

    if (
      t.loadRatio > 0.85 &&
      ['high', 'extreme', 'very high'].includes(level)
    ) {
      alerts.push({
        id: `g-critical-${i}`,
        type: 'critical',
        badge: 'حرج',
        title: `اكتظاظ حرج — ${t.stationNameAr}`,
        message: `نسبة الامتلاء ${(t.loadRatio * 100).toFixed(0)}% (${t.stationTotal} راكب من ${t.capacityStation})`,
        time: 'الآن',
        stationId: t.stationId,
        stationName: t.stationNameAr,
      })
    } else if (
      t.loadRatio > 0.65 &&
      ['medium', 'high'].includes(level)
    ) {
      alerts.push({
        id: `g-warning-${i}`,
        type: 'warning',
        badge: 'تحذير',
        title: `ازدحام مرتفع — ${t.stationNameAr}`,
        message: `نسبة الامتلاء ${(t.loadRatio * 100).toFixed(0)}% (${t.stationTotal} راكب)`,
        time: 'الآن',
        stationId: t.stationId,
        stationName: t.stationNameAr,
      })
    }
  })

  return alerts
}

/* ── القواعد: محطة محددة ── */
function applyStationRules(
  tick: NonNullable<Awaited<ReturnType<typeof getLatestTick>>>,
  predict?: {
    predicted_occupancy_30min?: number
    crowd_level_30min?: string
  } | null
): SmartAlert[] {
  const alerts: SmartAlert[] = []

  if (
    !tick.stationTotal ||
    tick.stationTotal === 0 ||
    isNaN(tick.loadRatio) ||
    tick.loadRatio <= 0
  ) {
    return alerts
  }

  const pct = (tick.loadRatio * 100).toFixed(0)
  const predOcc = Math.round(predict?.predicted_occupancy_30min ?? 0)
  const predLvl = (predict?.crowd_level_30min ?? '').toLowerCase()
  const currentLevel = tick.crowdLevel.toLowerCase()

  if (
    tick.loadRatio > 0.85 &&
    ['high', 'extreme', 'very high'].includes(currentLevel)
  ) {
    alerts.push({
      id: 'st-critical',
      type: 'critical',
      badge: 'حرج',
      title: 'اكتظاظ حرج في المحطة',
      message: `${tick.stationTotal} راكب حالياً — الطاقة الاستيعابية ${pct}%`,
      time: 'الآن',
    })
  } else if (
    tick.loadRatio > 0.65 &&
    ['medium', 'high'].includes(currentLevel)
  ) {
    alerts.push({
      id: 'st-warning',
      type: 'warning',
      badge: 'تحذير',
      title: 'ازدحام مرتفع في المحطة',
      message: `${tick.stationTotal} راكب حالياً — الطاقة الاستيعابية ${pct}%`,
      time: 'الآن',
    })
  } else if (tick.loadRatio < 0.30) {
    alerts.push({
      id: 'st-info-quiet',
      type: 'info',
      badge: 'معلومة',
      title: 'المحطة هادئة حالياً',
      message: `${tick.stationTotal} راكب فقط — الطاقة الاستيعابية ${pct}%`,
      time: 'الآن',
    })
  }

  if (predict) {
    if (predLvl === 'high' || predLvl === 'extreme' || predLvl === 'very high') {
      alerts.push({
        id: 'st-predict-high',
        type: 'warning',
        badge: 'تحذير',
        title: 'يُتوقع ازدحام خلال 30 دقيقة',
        message: `العدد المتوقع ${predOcc} راكب — مستوى: ${predict.crowd_level_30min}`,
        time: 'توقع',
      })
    } else if (predOcc > 0 && tick.stationTotal > 0) {
      const diff = predOcc - tick.stationTotal
      const diffPct = Math.abs((diff / tick.stationTotal) * 100)

      if (diff > 0 && diffPct > 20) {
        alerts.push({
          id: 'st-predict-worse',
          type: 'warning',
          badge: 'تحذير',
          title: 'الوضع سيزداد خلال 30 دقيقة',
          message: `متوقع ارتفاع إلى ${predOcc} راكب (+${diffPct.toFixed(0)}%)`,
          time: 'توقع',
        })
      } else if (diff < 0 && diffPct > 20) {
        alerts.push({
          id: 'st-predict-better',
          type: 'info',
          badge: 'معلومة',
          title: 'الوضع سيتحسن خلال 30 دقيقة',
          message: `متوقع انخفاض إلى ${predOcc} راكب (-${diffPct.toFixed(0)}%)`,
          time: 'توقع',
        })
      }
    }
  }

  return alerts
}

/* ══════════════════════════════════════
   useSmartAlerts — سريع وخفيف
   ══════════════════════════════════════ */
export function useSmartAlerts(
  selectedStation: { id: string; nameAr: string; name: string } | null
) {
  const [alerts, setAlerts] = useState<SmartAlert[]>([])
  const [loading, setLoading] = useState(false)
  const prevStationId = useRef<string | null>(null)

  const fetchGeneralAlerts = useCallback(async () => {
    setLoading(true)

    try {
      const ticks = await Promise.all(
        ALL_STATIONS.map((id) => getLatestTick(id))
      )

      const valid = ticks.filter(Boolean) as NonNullable<
        Awaited<ReturnType<typeof getLatestTick>>
      >[]

      const dynamicAlerts = applyGeneralRules(valid)

      setAlerts(
        dynamicAlerts.length > 0
          ? dynamicAlerts
          : [
              {
                id: 'g-info-normal',
                type: 'info',
                badge: 'معلومة',
                title: 'لا توجد تنبيهات حرجة حالياً',
                message: 'جميع المحطات ضمن المستوى الطبيعي أو المتوسط',
                time: 'الآن',
              },
            ]
      )
    } finally {
      setLoading(false)
    }
  }, [])

  const fetchStationAlerts = useCallback(
    async (station: { id: string; nameAr: string }) => {
      setLoading(true)

      try {
        const stationId = station.id.toUpperCase().startsWith('S')
          ? station.id.toUpperCase()
          : `S${station.id}`

        const [tick, predictRes] = await Promise.allSettled([
          getLatestTick(stationId),
          fetch(`${MASAR_API_BASE_URL}/predict_30min_live/${stationId}`),
        ])

        const tickData = tick.status === 'fulfilled' ? tick.value : null

        if (!tickData) {
          setAlerts(STATION_STATIC_ALERTS[stationId] || [])
          return
        }

        let predict = null

        if (predictRes.status === 'fulfilled' && predictRes.value.ok) {
          try {
            predict = await predictRes.value.json()
          } catch {
            predict = null
          }
        }

        const dynamicAlerts = applyStationRules(tickData, predict)
        const staticAlerts = STATION_STATIC_ALERTS[stationId] || []

        setAlerts([...dynamicAlerts, ...staticAlerts])
      } finally {
        setLoading(false)
      }
    },
    []
  )

  useEffect(() => {
    const currentId = selectedStation?.id ?? null

    if (currentId === prevStationId.current) return

    prevStationId.current = currentId

    if (selectedStation) {
      fetchStationAlerts(selectedStation)
    } else {
      fetchGeneralAlerts()
    }
  }, [selectedStation?.id, selectedStation, fetchStationAlerts, fetchGeneralAlerts])

  const refresh = useCallback(() => {
    if (selectedStation) {
      fetchStationAlerts(selectedStation)
    } else {
      fetchGeneralAlerts()
    }
  }, [selectedStation, fetchStationAlerts, fetchGeneralAlerts])

  return { alerts, loading, refresh }
}