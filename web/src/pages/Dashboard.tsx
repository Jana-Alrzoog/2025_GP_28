import { useState } from 'react';
import { Users, TrainFront, Clock, PersonStanding, Bell, AlertTriangle, Info, XCircle, ArrowRight } from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Area, AreaChart } from 'recharts';
import Navbar from '@/components/Navbar';
import MetroGoogleMap, { MetroStation, metroStations } from '@/components/MetroGoogleMap';

const defaultStats = {
  passengers: '14,250',
  passengersSubtitle: 'راكب نشط حالياً',
  activeTrips: '38',
  activeTripsSubtitle: 'رحلة نشطة على الشبكة',
  passengersPerCar: '32',
  passengersPerCarSubtitle: 'متوسط عدد الركاب لكل مقطورة',
  nextTrain: '5 د',
  nextTrainSubtitle: 'القطار القادم المتوقع',
  stationName: '',
};

function getStationStats(station: MetroStation | null) {
  if (!station) return defaultStats;
  return {
    passengers: station.passengers.toLocaleString(),
    passengersSubtitle: `راكب في ${station.name}`,
    activeTrips: `${station.activeTrips}`,
    activeTripsSubtitle: `رحلة نشطة من ${station.name}`,
    passengersPerCar: `${station.passengersPerCar}`,
    passengersPerCarSubtitle: `راكب لكل مقطورة`,
    nextTrain: station.nextTrain,
    nextTrainSubtitle: `الوصول إلى ${station.name}`,
    stationName: station.name,
  };
}

const alerts = [
  { type: 'critical' as const, title: 'تأخير في خط الشرق/الغرب (١)', time: 'الآن', badge: 'حرج' },
  { type: 'warning' as const, title: 'ازدحام شديد في محطة الملك عبدالله', time: 'منذ 5 د', badge: 'تحذير' },
  { type: 'info' as const, title: 'تم فتح بوابة دخول جديدة في محطة العليا', time: 'منذ 15 د', badge: 'معلومة' },
  { type: 'warning' as const, title: 'انقطاع الحركة في جميع الخطوط الغربية', time: 'منذ 20 د', badge: 'تحذير' },
  { type: 'info' as const, title: 'تحديث جدول انطلاق عند الساعة 3 صباحاً', time: 'منذ 1 s', badge: 'معلومة' },
];

const chartData = [
  { time: '08:00', actual: 200, predicted: 180 },
  { time: '09:00', actual: 350, predicted: 320 },
  { time: '10:00', actual: 480, predicted: 450 },
  { time: '11:00', actual: 520, predicted: 500 },
  { time: '12:00', actual: 600, predicted: 580 },
  { time: '13:00', actual: 750, predicted: 700 },
  { time: '14:00', actual: 900, predicted: 850 },
  { time: '15:00', actual: 1000, predicted: 950 },
  { time: '16:00', actual: 850, predicted: 880 },
  { time: '17:00', actual: 700, predicted: 720 },
  { time: '18:00', actual: 550, predicted: 580 },
  { time: '19:00', actual: 400, predicted: 420 },
  { time: '20:00', actual: 300, predicted: 310 },
];

const iconMap = { critical: XCircle, warning: AlertTriangle, info: Info };
const alertColorMap = { critical: 'hsl(0, 72%, 51%)', warning: 'hsl(45, 93%, 47%)', info: 'hsl(210, 70%, 50%)' };
const alertBgMap = { critical: 'hsl(0, 72%, 96%)', warning: 'hsl(45, 93%, 96%)', info: 'hsl(210, 70%, 96%)' };

const congestionColors: Record<string, string> = {
  normal: 'hsl(142, 71%, 45%)',
  medium: 'hsl(45, 93%, 47%)',
  crowded: 'hsl(25, 95%, 53%)',
  very_crowded: 'hsl(0, 72%, 51%)',
};

const Dashboard = () => {
  const [selectedStation, setSelectedStation] = useState<MetroStation | null>(null);
  const [isFlipped, setIsFlipped] = useState(false);
  const stats = getStationStats(selectedStation);

  const handleStationSelect = (station: MetroStation) => {
    setSelectedStation(station);
    setIsFlipped(true);
  };

  const handleBackToMap = () => {
    setIsFlipped(false);
  };

  const statCards = [
    {
      title: 'عدد الركاب الحالي',
      value: stats.passengers,
      subtitle: stats.passengersSubtitle,
      icon: Users,
      color: 'hsl(210, 70%, 50%)',
      bg: 'hsl(210, 70%, 95%)',
    },
    {
      title: 'عدد الرحلات النشطة',
      value: stats.activeTrips,
      subtitle: stats.activeTripsSubtitle,
      icon: TrainFront,
      color: 'hsl(25, 95%, 53%)',
      bg: 'hsl(25, 95%, 95%)',
    },
    {
      title: 'ركاب كل مقطورة',
      value: stats.passengersPerCar,
      subtitle: stats.passengersPerCarSubtitle,
      icon: PersonStanding,
      color: 'hsl(142, 71%, 45%)',
      bg: 'hsl(142, 71%, 95%)',
    },
    {
      title: 'القطار القادم',
      value: stats.nextTrain,
      subtitle: stats.nextTrainSubtitle,
      icon: Clock,
      color: 'hsl(0, 72%, 51%)',
      bg: 'hsl(0, 72%, 95%)',
    },
  ];

  return (
    <div className="min-h-screen">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 py-8 pt-24">
        <h1 className="text-3xl font-extrabold text-foreground text-center mb-2">لوحة التحكم</h1>
        {stats.stationName && (
          <p className="text-center text-sm text-primary font-bold mb-6">
            📍 {stats.stationName}
          </p>
        )}
        {!stats.stationName && <div className="mb-6" />}

        {/* Top section: Map + Alerts */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
          {/* Map with flip */}
          <div className="lg:col-span-2" style={{ perspective: '1200px' }}>
            <div
              className="relative w-full transition-transform duration-700"
              style={{
                transformStyle: 'preserve-3d',
                transform: isFlipped ? 'rotateY(180deg)' : 'rotateY(0deg)',
                minHeight: '400px',
              }}
            >
              {/* Front - Map */}
              <div
                className="absolute inset-0 dashboard-card p-5"
                style={{ backfaceVisibility: 'hidden' }}
              >
                <h3 className="text-base font-bold text-foreground mb-3 text-right">خريطة الازدحام المباشرة</h3>
                <div className="w-full h-[340px]">
                  <MetroGoogleMap
                    onStationSelect={handleStationSelect}
                    selectedStationId={selectedStation?.id ?? null}
                  />
                </div>
              </div>

              {/* Back - Station Info */}
              <div
                className="absolute inset-0 dashboard-card p-5 flex flex-col items-center justify-center overflow-hidden"
                style={{
                  backfaceVisibility: 'hidden',
                  transform: 'rotateY(180deg)',
                }}
              >
                {selectedStation && (
                  <>
                    {/* Large background station name */}
                    <div className="absolute inset-0 flex items-center justify-center pointer-events-none select-none">
                      <span
                        className="text-[5rem] md:text-[7rem] font-black opacity-[0.06] leading-none text-center px-4"
                        style={{ color: congestionColors[selectedStation.congestion] }}
                      >
                        {selectedStation.name}
                      </span>
                    </div>

                    {/* Content */}
                    <div className="relative z-10 text-center space-y-4">
                      <div
                        className="w-16 h-16 rounded-full mx-auto flex items-center justify-center shadow-lg"
                        style={{ backgroundColor: congestionColors[selectedStation.congestion] }}
                      >
                        <div className="w-7 h-7 rounded-full bg-white" />
                      </div>
                      <h2 className="text-2xl font-extrabold text-foreground">{selectedStation.name}</h2>
                      <p className="text-sm text-muted-foreground">
                        الركاب: <span className="font-bold text-foreground">{selectedStation.passengers.toLocaleString()}</span>
                        {' · '}
                        الرحلات: <span className="font-bold text-foreground">{selectedStation.activeTrips}</span>
                        {' · '}
                        القطار القادم: <span className="font-bold text-foreground">{selectedStation.nextTrain}</span>
                      </p>
                    </div>

                    {/* Back button */}
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

          {/* Alerts */}
          <div className="dashboard-card p-5">
            <div className="flex items-center gap-2 justify-end mb-4">
              <h3 className="text-base font-bold text-foreground">تنبيهات مباشرة</h3>
              <Bell className="h-4 w-4 text-primary" />
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-destructive opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-destructive" />
              </span>
            </div>
            <div className="space-y-3 max-h-[320px] overflow-y-auto pr-1 scrollbar-thin scrollbar-thumb-border scrollbar-track-transparent">
              {alerts.map((alert, i) => {
                const Icon = iconMap[alert.type];
                return (
                  <div
                    key={i}
                    className="rounded-xl p-3 flex items-start gap-2 justify-end"
                    style={{ backgroundColor: alertBgMap[alert.type] }}
                  >
                    <div className="text-right flex-1">
                      <div className="flex items-center gap-2 justify-end">
                        <span
                          className="text-[10px] px-2 py-0.5 rounded-full font-bold"
                          style={{ backgroundColor: alertColorMap[alert.type], color: 'white' }}
                        >
                          {alert.badge}
                        </span>
                      </div>
                      <p className="text-sm font-medium text-foreground mt-1">{alert.title}</p>
                      <p className="text-[11px] text-muted-foreground mt-0.5">{alert.time}</p>
                    </div>
                    <Icon className="h-4 w-4 mt-1 shrink-0" style={{ color: alertColorMap[alert.type] }} />
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* 4 Stat Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {statCards.map((card) => {
            const Icon = card.icon;
            return (
              <div key={card.title} className="dashboard-card p-5 text-center transition-all duration-300">
                <div className="w-12 h-12 rounded-xl mx-auto mb-3 flex items-center justify-center" style={{ backgroundColor: card.bg }}>
                  <Icon className="h-6 w-6" style={{ color: card.color }} />
                </div>
                <p className="text-xs text-muted-foreground mb-1">{card.title}</p>
                <p className="text-3xl font-extrabold" style={{ color: card.color }}>{card.value}</p>
                <p className="text-[11px] text-muted-foreground mt-2">{card.subtitle}</p>
              </div>
            );
          })}
        </div>

        {/* Passenger Flow Chart */}
        <div className="dashboard-card p-6">
          <div className="text-right mb-4">
            <h3 className="text-base font-bold text-foreground">تدفق الركاب - آخر 12 ساعة</h3>
            <p className="text-xs text-muted-foreground">مقارنة بين الركاب الفعليين والمتوقعين</p>
          </div>
          <div className="flex items-center gap-4 justify-end mb-4">
            <div className="flex items-center gap-1.5">
              <div className="w-3 h-3 rounded-full" style={{ backgroundColor: 'hsl(25, 95%, 53%)' }} />
              <span className="text-xs text-muted-foreground">المتوقع</span>
            </div>
            <div className="flex items-center gap-1.5">
              <div className="w-3 h-3 rounded-full" style={{ backgroundColor: 'hsl(220, 10%, 75%)' }} />
              <span className="text-xs text-muted-foreground">الفعلي</span>
            </div>
          </div>
          <div className="h-[280px] w-full" dir="ltr">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
                <defs>
                  <linearGradient id="colorActual" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="hsl(25, 95%, 53%)" stopOpacity={0.15} />
                    <stop offset="95%" stopColor="hsl(25, 95%, 53%)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(220, 15%, 93%)" />
                <XAxis dataKey="time" tick={{ fontSize: 11, fill: 'hsl(220, 10%, 50%)' }} />
                <YAxis tick={{ fontSize: 11, fill: 'hsl(220, 10%, 50%)' }} />
                <Tooltip
                  contentStyle={{
                    borderRadius: '10px',
                    border: '1px solid hsl(220, 15%, 90%)',
                    fontSize: '12px',
                    direction: 'rtl',
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
                <Line
                  type="monotone"
                  dataKey="predicted"
                  stroke="hsl(220, 10%, 78%)"
                  strokeWidth={2}
                  strokeDasharray="5 5"
                  dot={false}
                  name="المتوقع"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Footer */}
        <footer className="text-center py-8 mt-8 text-xs text-muted-foreground flex items-center justify-center gap-2">
          <span>من بواسطة الذكاء الاصطناعي لمستقبل أذكى</span>
          <span>|</span>
          <img src="/images/masar-logo.png" alt="مسار" className="h-5 opacity-50" />
          <span>© جميع الحقوق محفوظة 2026 - مسار</span>
        </footer>
      </div>
    </div>
  );
};

export default Dashboard;
