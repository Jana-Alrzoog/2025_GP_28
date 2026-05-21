import { useEffect, useState } from 'react';
import {
  Users,
  Bell,
  AlertTriangle,
  Info,
  XCircle,
  ArrowRight,
  TrainFront
} from 'lucide-react';
import { Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Area, AreaChart } from 'recharts';
import UpcomingTrainsSection from "@/components/UpcomingTrainsSection";
import MetroGoogleMap, { MetroStation } from '@/components/MetroGoogleMap';
import { collection, getDocs } from "firebase/firestore";
import { db } from "@/lib/firebase";
import Lottie from "lottie-react";
import loadingAnimation from "@/data/loading.json";
import { useSmartAlerts } from "@/hooks/Usesmartalerts";

const MASAR_API_BASE_URL = 'https://masar-sim.onrender.com';
interface Predict30MinResponse {
  station_id?: string;
  station_id_ml?: number;
  timestamp_now?: string;
  current_occupancy?: number;
  predicted_occupancy_30min?: number;
  capacity_station?: number;
  utilization_ratio?: number;
  crowd_level_30min?: string;
  crowd_level_30min_code?: number;
}

const defaultStats = {
  passengers: '',
  passengersSubtitle: '',
  predictedPassengers: '',
  predictedPassengersSubtitle: '',
  stationName: '',
};

function getStationStats(
  station: MetroStation | null,
  liveCurrentPassengers: number | null,
  livePredictedPassengers: number | null
) {
  if (!station) return defaultStats;

  return {
    passengers: (liveCurrentPassengers ?? "-").toLocaleString(),
    passengersSubtitle: 'راكب نشط حالياً',

    predictedPassengers: (livePredictedPassengers ?? "-").toLocaleString(),
    predictedPassengersSubtitle: 'متوقع بعد 30 دقيقة',

    stationName: station.nameAr,
  };
}

const mapCrowdLevelToCongestion = (
  level?: string
): 'normal' | 'medium' | 'crowded' | 'very_crowded' => {
  const value = (level || '').toLowerCase().trim();

  if (value === 'low') return 'normal';
  if (value === 'medium') return 'medium';
  if (value === 'high') return 'crowded';
  if (value === 'extreme') return 'very_crowded';
  if (value === 'very high') return 'very_crowded';

  return 'normal';
};

const mapCurrentOccupancyToCongestion = (
  currentOccupancy?: number,
  capacityStation?: number
): 'normal' | 'medium' | 'crowded' | 'very_crowded' => {
  if (!capacityStation || capacityStation <= 0) return 'normal';

  const ratio = (currentOccupancy ?? 0) / capacityStation;

  if (ratio < 0.4) return 'normal';
  if (ratio < 0.7) return 'medium';
  if (ratio < 0.9) return 'crowded';
  return 'very_crowded';
};

const getCongestionLabelAr = (
  level?: 'normal' | 'medium' | 'crowded' | 'very_crowded' | null
) => {
  if (level === 'normal') return 'طبيعي';
  if (level === 'medium') return 'متوسط';
  if (level === 'crowded') return 'مزدحم';
  if (level === 'very_crowded') return 'مزدحم جداً';
  return '';
};



const iconMap = { critical: XCircle, warning: AlertTriangle, info: Info };
const alertColorClass = {
  critical: 'text-destructive',
  warning: 'text-[hsl(var(--status-searching))]',
  info: 'text-primary'
};
const alertBgClass = {
  critical: 'bg-[hsl(var(--status-closed-bg))]',
  warning: 'bg-[hsl(var(--status-searching-bg))]',
  info: 'bg-[hsl(var(--status-matched-bg))]'
};
const alertBadgeBg = {
  critical: 'bg-destructive',
  warning: 'bg-[hsl(var(--status-searching))]',
  info: 'bg-primary'
};

const congestionColors: Record<string, string> = {
  normal: 'hsl(142, 71%, 45%)',
  medium: 'hsl(49, 89%, 58%)',
  crowded: 'hsl(0, 75%, 51%)',
  very_crowded: 'hsl(0, 73%, 25%)',
};

const stationNameToId: Record<string, string> = {
  "KAFD": "S1",
  "stc": "S2",
  "Qasr Al Hokm": "S3",
  "National Museum": "S4",
  "Airport T1-2": "S5",
  "First Industrial City": "S6",

  "المركز المالي": "S1",
  "قصر الحكم": "S3",
  "المتحف الوطني": "S4",
  "الصالة 1-2": "S5",
  "المدينة الصناعية الأولى": "S6",
};

function parseTickIdToDate(tickId: string): Date | null {
  if (!/^\d{12}$/.test(tickId)) return null;

  const year = Number(tickId.slice(0, 4));
  const month = Number(tickId.slice(4, 6)) - 1;
  const day = Number(tickId.slice(6, 8));
  const hour = Number(tickId.slice(8, 10));
  const minute = Number(tickId.slice(10, 12));

  return new Date(year, month, day, hour, minute);
}

const Dashboard = () => {
  const [chartData, setChartData] = useState<{ time: string; actual: number }[]>([]);
  const [selectedStation, setSelectedStation] = useState<MetroStation | null>(null);
  const [loadingChart, setLoadingChart] = useState(false);
  const { alerts, loading: loadingAlerts } = useSmartAlerts(selectedStation);

  useEffect(() => {
    const fetchSelectedStationChart = async () => {
      try {
        setLoadingChart(true);

        if (!selectedStation) {
          setChartData([]);
          return;
        }

        const stationId = stationNameToId[selectedStation.name];

        if (!stationId) {
          console.log("No stationId found for:", selectedStation.name);
          setChartData([]);
          return;
        }

        const q = collection(db, "live", stationId, "ticks");
        const snapshot = await getDocs(q);

        const rows: { ts: Date; total: number }[] = [];

        snapshot.forEach((doc) => {
          const data = doc.data();

          const ts = parseTickIdToDate(doc.id);
          const total = Number(
            data.events?.station_total ??
            data.station_total ??
            data.events?.stationTotal ??
            0
          );

          if (!ts) return;

          rows.push({ ts, total });
        });

        if (rows.length === 0) {
          console.log("No rows for station:", stationId);
          setChartData([]);
          return;
        }

        rows.sort((a, b) => a.ts.getTime() - b.ts.getTime());

        const latestTime = rows[rows.length - 1].ts;
        const startTime = new Date(latestTime.getTime() - 12 * 60 * 60 * 1000);

        const hourTotals: Record<string, number> = {};
        for (let i = 11; i >= 0; i--) {
          const d = new Date(latestTime.getTime() - i * 60 * 60 * 1000);
          const hourLabel = `${String(d.getHours()).padStart(2, "0")}:00`;
          hourTotals[hourLabel] = 0;
        }

        const latestPerHour: Record<string, { ts: number; total: number }> = {};

        rows.forEach((item) => {
          if (item.ts < startTime) return;

          const hourLabel = `${String(item.ts.getHours()).padStart(2, "0")}:00`;
          const current = latestPerHour[hourLabel];

          if (!current || item.ts.getTime() > current.ts) {
            latestPerHour[hourLabel] = {
              ts: item.ts.getTime(),
              total: item.total,
            };
          }
        });

        Object.entries(latestPerHour).forEach(([hour, value]) => {
          if (hourTotals[hour] !== undefined) {
            hourTotals[hour] = value.total;
          }
        });

        const finalChartData = Object.entries(hourTotals).map(([time, actual]) => ({
          time,
          actual,
        }));

        setChartData(finalChartData);
      } catch (error) {
        console.error("Error fetching selected station chart:", error);
        setChartData([]);
      } finally {
        setLoadingChart(false);
      }
    };

    fetchSelectedStationChart();
  }, [selectedStation]);

  const [isFlipped, setIsFlipped] = useState(false);

  const [liveCurrentPassengers, setLiveCurrentPassengers] = useState<number | null>(null);
  const [livePredictedPassengers, setLivePredictedPassengers] = useState<number | null>(null);

  const [liveCurrentCongestion, setLiveCurrentCongestion] = useState<
    'normal' | 'medium' | 'crowded' | 'very_crowded' | null
  >(null);

  const [livePredictedCongestion, setLivePredictedCongestion] = useState<
    'normal' | 'medium' | 'crowded' | 'very_crowded' | null
  >(null);

  const [loadingPassengerStats, setLoadingPassengerStats] = useState(false);

  const stats = getStationStats(
    selectedStation,
    liveCurrentPassengers,
    livePredictedPassengers
  );

  const handleStationSelect = (station: MetroStation) => {
    setSelectedStation(station);
    setIsFlipped(true);
  };

  const handleBackToMap = () => {
    setIsFlipped(false);
  };

  const fetchPassengerStats = async (station: MetroStation) => {
    try {
      setLoadingPassengerStats(true);

      const stationId = station.id.toUpperCase().startsWith('S')
        ? station.id.toUpperCase()
        : `S${station.id}`;

      const res = await fetch(
        `${MASAR_API_BASE_URL}/predict_30min_live/${stationId}`
      );

      if (!res.ok) {
        throw new Error('Failed to fetch passenger stats');
      }

      const data: Predict30MinResponse = await res.json();

      const currentPassengers = Math.round(data.current_occupancy ?? 0);
      const predictedPassengers = Math.round(data.predicted_occupancy_30min ?? 0);

      const currentCongestion = mapCurrentOccupancyToCongestion(
        data.current_occupancy,
        data.capacity_station
      );

      const predictedCongestion = mapCrowdLevelToCongestion(
        data.crowd_level_30min
      );

      setLiveCurrentPassengers(currentPassengers);
      setLivePredictedPassengers(predictedPassengers);
      setLiveCurrentCongestion(currentCongestion);
      setLivePredictedCongestion(predictedCongestion);
    } catch (error) {
      console.error('Error fetching passenger stats:', error);
      setLiveCurrentPassengers(null);
      setLivePredictedPassengers(null);
      setLiveCurrentCongestion(null);
      setLivePredictedCongestion(null);
    } finally {
      setLoadingPassengerStats(false);
    }
  };

  useEffect(() => {
    if (!selectedStation) {
      setLiveCurrentPassengers(null);
      setLivePredictedPassengers(null);
      setLiveCurrentCongestion(null);
      setLivePredictedCongestion(null);
      return;
    }

    fetchPassengerStats(selectedStation);
  }, [selectedStation]);

  const hasSelectedStation = !!selectedStation;

const statCards = [
  {
    title: 'عدد الركاب الحالي',
    value: !hasSelectedStation
      ? ''
      : loadingPassengerStats
      ? '...'
      : stats.passengers,
    subtitle: hasSelectedStation ? stats.passengersSubtitle : '',
    icon: Users,
    color: '#0ea5e9',
    bg: '#0ea5e915',
  },
  {
    title: 'مستوى الزحمة الحالي',
    value: !hasSelectedStation
      ? ''
      : loadingPassengerStats
      ? '...'
      : getCongestionLabelAr(liveCurrentCongestion),
    subtitle: hasSelectedStation ? 'الحالة الحالية للمحطة' : '',
    icon: AlertTriangle,
    color: '#f59e0b',
    bg: '#f59e0b15',
  },
  {
    title: 'عدد الركاب المتوقع بعد 30 دقيقة',
    value: !hasSelectedStation
      ? ''
      : loadingPassengerStats
      ? '...'
      : stats.predictedPassengers,
    subtitle: hasSelectedStation ? stats.predictedPassengersSubtitle : '',
    icon: Users,
    color: '#ef4444',
    bg: '#ef444415',
  },
  {
    title: 'مستوى الزحمة المتوقع بعد 30 دقيقة',
    value: !hasSelectedStation
      ? ''
      : loadingPassengerStats
      ? '...'
      : getCongestionLabelAr(livePredictedCongestion),
    subtitle: hasSelectedStation ? 'التوقع القادم للمحطة' : '',
    icon: AlertTriangle,
    color: '#4d2594',
    bg: '#7c3aed15',
  },
];
  const detailsCongestionColor =
    congestionColors[liveCurrentCongestion ?? selectedStation?.congestion ?? 'normal'];

  return (
    <div className="min-h-screen">
      <div className="wave-bg" />

<div className="max-w-[1400px] mx-auto px-6 py-2 pt-28"><div className="text-right mb-6">
  <h4
    className="text-2xl md:text-3xl font-black flex items-center justify-start gap-3"
    style={{ fontFamily: "'Tajawal', sans-serif" }}
  >
    <span className="text-foreground">
      لوحة التحكم
    </span>

    {selectedStation && (
      <>
        <span className="text-muted-foreground">—</span>

        <span className="text-primary flex items-center gap-2">
          {selectedStation.nameAr}
          <TrainFront className="w-6 h-6" />
        </span>
      </>
    )}
  </h4>
</div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
          <div className="lg:col-span-2" style={{ perspective: '1200px' }}>
            <div
              className="relative w-full transition-transform duration-700"
              style={{
                transformStyle: 'preserve-3d',
                transform: isFlipped ? 'rotateY(180deg)' : 'rotateY(0deg)',
                minHeight: '400px',
              }}
            >
              <div
                className="absolute inset-0 dashboard-card p-5"
                style={{ backfaceVisibility: 'hidden' }}
              >
<div className="flex flex-row-reverse items-center justify-between mb-3">

  <div className="time-map-pill text-xs font-bold px-3 py-1 rounded-xl shadow-sm backdrop-blur-md">
    {new Date().toLocaleDateString('ar-SA', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    })}
    {' • '}
    {new Date().toLocaleTimeString('ar-SA', {
      hour: '2-digit',
      minute: '2-digit',
    })}
  </div>

  <h3 className="text-base font-bold text-foreground">
    خريطة الازدحام المباشرة
  </h3>

</div>
                <div className="w-full h-[340px]">
                  <MetroGoogleMap
                    onStationSelect={handleStationSelect}
                    selectedStationId={selectedStation?.id ?? null}
                  />
                </div>
              </div>

              <div
                className="absolute inset-0 dashboard-card p-5 flex flex-col items-center justify-center overflow-hidden"
                style={{
                  backfaceVisibility: 'hidden',
                  transform: 'rotateY(180deg)',
                }}
              >
                {selectedStation && (
                  <>
                    <div className="absolute inset-0 flex items-center justify-center pointer-events-none select-none">
                      <span
                        className="text-[5rem] md:text-[7rem] font-black opacity-[0.06] leading-none text-center px-4"
                        style={{ color: detailsCongestionColor }}
                      >
                        {selectedStation.nameAr}
                      </span>
                    </div>

                    <div className="relative z-10 text-center space-y-4">
                      <div
                        className="w-16 h-16 rounded-full mx-auto flex items-center justify-center shadow-lg"
                        style={{ backgroundColor: detailsCongestionColor }}
                      >
                        <div className="w-7 h-7 rounded-full bg-white" />
                      </div>

                      <h2 className="text-2xl font-extrabold text-foreground">
                        {selectedStation.nameAr}
                      </h2>

                      <p className="text-sm text-muted-foreground">
                        الركاب الحاليون:{' '}
                        <span className="font-bold text-foreground">
                          {loadingPassengerStats
                            ? '...'
                            : (liveCurrentPassengers ?? selectedStation.passengers).toLocaleString()}
                        </span>
                        {' · '}
                        المتوقع بعد 30 دقيقة:{' '}
                        <span className="font-bold text-foreground">
                          {loadingPassengerStats
                            ? '...'
                            : (livePredictedPassengers ?? 0).toLocaleString()}
                        </span>
  
                      </p>
                    </div>

                    <button
                      onClick={handleBackToMap}
                      className="absolute top-4 right-4 z-20 flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-secondary hover:bg-secondary/80 text-sm font-bold text-foreground transition-colors"
                    >
                      <ArrowRight className="h-4 w-4" />
                      العودة للخريطة
                    </button>
                  </>
                )}
              </div>
            </div>
          </div>

          <div className="dashboard-card p-5">
<div className="flex flex-row-reverse items-center gap-2 justify-end mb-4">
                  <h3 className="text-base font-bold text-foreground">تنبيهات مباشرة</h3>
              <Bell className="h-4 w-4 text-primary" />
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-destructive opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-destructive" />
              </span>
            </div>

            <div className="space-y-3 max-h-[320px] overflow-y-auto pr-1 scrollbar-thin scrollbar-thumb-border scrollbar-track-transparent">
{loadingAlerts ? (
  <p className="text-sm text-muted-foreground text-center py-6">
    جاري تحميل التنبيهات...
  </p>
) : (
  alerts.map((alert, i) => {
    const Icon = iconMap[alert.type];

    return (
      <div
        key={alert.id ?? i}
        className={`rounded-xl p-3 flex items-start gap-2 justify-end ${alertBgClass[alert.type]}`}
      >
        <div className="text-right flex-1">
          
          <div className="flex items-center gap-2 justify-end">
            <span
              className={`text-[10px] px-2 py-0.5 rounded-full font-bold text-white ${alertBadgeBg[alert.type]}`}
            >
              {alert.badge}
            </span>
          </div>

          <p className="text-sm font-medium text-foreground mt-1">
            {alert.title}
          </p>

          {alert.message && (
            <p className="text-[11px] text-muted-foreground mt-1">
              {alert.message}
            </p>
          )}

          <p className="text-[11px] text-muted-foreground mt-0.5">
            {alert.time}
          </p>

        </div>

        <Icon
          className={`h-4 w-4 mt-1 shrink-0 ${alertColorClass[alert.type]}`}
        />
      </div>
    );
  })
)}
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {statCards.map((card) => {
            const Icon = card.icon;
            return (
              <div
                key={card.title}
                className="dashboard-card p-5 text-center transition-all duration-300 hover:-translate-y-1"
              >
                <div
                  className="w-12 h-12 rounded-xl mx-auto mb-3 flex items-center justify-center"
                  style={{ backgroundColor: card.bg }}
                >
                  <Icon
                    className="h-6 w-6"
                    style={{ color: card.color }}
                  />
                </div>
                <p className="text-xs text-muted-foreground mb-1">{card.title}</p>
{card.value && (
  <p
    className="text-3xl font-extrabold"
    style={{ color: card.color }}
  >
    {card.value}
  </p>
)}

{card.subtitle && (
  <p className="text-[11px] text-muted-foreground mt-2">
    {card.subtitle}
  </p>
)}
              </div>
            );
          })}
        </div>
        
{selectedStation && (
  <div className="mb-6">
    <UpcomingTrainsSection
      stationId={
        selectedStation.id.toUpperCase().startsWith("S")
          ? selectedStation.id.toUpperCase()
          : `S${selectedStation.id}`
      }
      stationName={selectedStation.nameAr}
    />
  </div>
)}

        <div className="dashboard-card p-6">
          <div className="text-right mb-4">
            <h3 className="text-base font-bold text-foreground">تدفق الركاب - آخر 12 ساعة</h3>
          </div>

          <div className="flex items-center gap-4 justify-end mb-4">
            <div className="flex items-center gap-1.5">
              <div
                className="w-3 h-3 rounded-full"
                style={{ backgroundColor: "hsl(25, 95%, 53%)" }}
              />
              <span className="text-xs text-muted-foreground">الفعلي</span>
            </div>
            <div className="flex items-center gap-1.5">
              
            </div>
          </div>

          <div className="h-[280px] w-full" dir="ltr">
            {loadingChart ? (
              <div className="h-full flex flex-col items-center justify-center">
                <Lottie
                  animationData={loadingAnimation}
                  style={{ width: 120, height: 120 }}
                />
                <p className="text-xs text-gray-500 -mt-2">
                  جاري تحميل بيانات المحطة...
                </p>
              </div>
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={chartData} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
                  <defs>
                    <linearGradient id="colorActual" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="hsl(25, 95%, 53%)" stopOpacity={0.15} />
                      <stop offset="95%" stopColor="hsl(25, 95%, 53%)" stopOpacity={0} />
                    </linearGradient>
                  </defs>

                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(220, 15%, 93%)" />
                  <XAxis dataKey="time" tick={{ fontSize: 11, fill: "hsl(220, 10%, 50%)" }} />
                  <YAxis tick={{ fontSize: 11, fill: "hsl(220, 10%, 50%)" }} />
                  <Tooltip
                    contentStyle={{
                      borderRadius: "10px",
                      border: "1px solid hsl(220, 15%, 90%)",
                      fontSize: "12px",
                      direction: "rtl",
                    }}
                  />
                  <Area
                    type="monotone"
                    dataKey="actual"
                    stroke="hsl(25, 95%, 53%)"
                    strokeWidth={2.5}
                    fill="url(#colorActual)"
                    name="الفعلي"
                  />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>

        <footer className="text-center py-8 mt-8 text-xs text-muted-foreground flex items-center justify-center gap-2">
          
          <span>|</span>
          <img src="/images/masar-logo.png" alt="مسار" className="h-5 opacity-50 dark:invert" />
          <span>© جميع الحقوق محفوظة 2026 - مسار</span>
        </footer>
      </div>
    </div>
  );
};

export default Dashboard;