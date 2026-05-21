import { useEffect, useMemo, useState } from "react";
import {
  collection,
  collectionGroup,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  Timestamp,
  where,
  DocumentReference,
  QueryDocumentSnapshot,
} from "firebase/firestore";
import { db } from "@/lib/firebase";

interface UpcomingTrainsSectionProps {
  stationId: string | null;
  stationName: string;
}

type CrowdLevel = "low" | "medium" | "high" | "extreme";

interface CarriageItem {
  number: number;
  className: string;
  crowdingPercent: number;
  crowdingLevel: CrowdLevel;
}

interface TrainRowItem {
  tripId: string;
  destination: string;
  lineId: string;
  lineColor: string;
  lineNumber: number;
  arrivalText: string;
  arrivalDate: Date | null;
  crowdPercent: number | null;
  carriages: CarriageItem[];
  isTerminalHere: boolean;
}

const stationIdMap: Record<string, string> = {
  S1: "KAFD/المركز المالي",
  S2: "stc/STC",
  S3: "Qasr Al Hokm/قصر الحكم",
  S4: "National Museum/المتحف الوطني",
  S5: "Airport T1-2/AIRP_T12/الصالة 1-2",
  S6: "First Industrial City/المدينة الصناعية الأولى",
};

const lineIdToNumber: Record<string, number> = {
  blue: 1,
  red: 2,
  orange: 3,
  yellow: 4,
  green: 5,
  purple: 6,
};

const lineIdToColor: Record<string, string> = {
  blue: "#00ADE5",
  red: "#D12027",
  orange: "#F68D39",
  yellow: "#FFC107",
  green: "#43B649",
  purple: "#984C9D",
};

const tripEndCandidates = [
  "end_station_code",
  "endStationCode",
  "end_station",
  "destination",
  "dest",
  "dest_code",
  "end_code",
];

function normalizeText(value: string) {
  return value
    .toLowerCase()
    .trim()
    .replace(/[أإآ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه");
}

function resolveEndName(code?: string | null) {
  if (!code || !code.trim()) return "وجهة غير معروفة";
  const target = code.trim().toUpperCase();

  for (const entry of Object.values(stationIdMap)) {
    const variants = entry
      .split("/")
      .map((v) => v.trim())
      .filter(Boolean);

    for (const v of variants) {
      const vv = v.toUpperCase();
      if (vv === target || vv.includes(target) || target.includes(vv)) {
        const arabic = variants.find((p) => /[\u0600-\u06FF]/.test(p));
        return arabic || variants[0];
      }
    }
  }

  return code;
}

function isTerminalHere(params: {
  destCode?: string | null;
  destName?: string | null;
  stationId: string;
  stationName: string;
}) {
  const { destCode, destName, stationId, stationName } = params;
  const currentId = stationId.trim().toUpperCase();

  if (destCode && destCode.trim().toUpperCase() === currentId) {
    return true;
  }

  const mapping = stationIdMap[currentId];
  if (mapping && destName) {
    const nd = normalizeText(destName);
    for (const v of mapping.split("/")) {
      const vv = v.trim();
      if (!vv) continue;
      if (normalizeText(vv) === nd) return true;
    }
  }

  if (destName && normalizeText(destName) === normalizeText(stationName)) {
    return true;
  }

  return false;
}

function formatFromTimestamp(date: Date) {
  let hour24 = date.getHours();
  const minute = String(date.getMinutes()).padStart(2, "0");
  const isPM = hour24 >= 12;
  let hour12 = hour24 % 12;
  if (hour12 === 0) hour12 = 12;
  const hh = String(hour12).padStart(2, "0");
  return `${hh}:${minute}${isPM ? "PM" : "AM"}`;
}

function formatArrivalTime(time: string) {
  try {
    const parts = time.split(":");
    if (parts.length >= 2) {
      let hour24 = parseInt(parts[0], 10);
      const minute = parts[1].padStart(2, "0");
      const isPM = hour24 >= 12;
      let hour12 = hour24 % 12;
      if (hour12 === 0) hour12 = 12;
      const hh = String(hour12).padStart(2, "0");
      return `${hh}:${minute}${isPM ? "PM" : "AM"}`;
    }
  } catch {
    return time;
  }
  return time;
}

function getCrowdingLevel(percent: number): CrowdLevel {
  if (percent >= 80) return "extreme";
  if (percent >= 60) return "high";
  if (percent >= 40) return "medium";
  return "low";
}

function crowdLevelLabel(level: CrowdLevel) {
  if (level === "low") return "منخفض";
  if (level === "medium") return "متوسط";
  if (level === "high") return "مزدحم";
  return "شديد";
}

function crowdLevelColor(level: CrowdLevel) {
  if (level === "low") return "#22c55e";
  if (level === "medium") return "#eab308";
  if (level === "high") return "#ef4444";
  return "#7f1d1d";
}

function percentColor(percent: number | null) {
  if (percent === null) return "#9ca3af";
  return crowdLevelColor(getCrowdingLevel(percent));
}

function mapClassName(rawType?: string | null) {
  const t = (rawType || "").toLowerCase().trim();
  if (t === "vip") return "الدرجة الأولى";
  if (t === "families") return "العوائل";
  if (t === "individuals") return "الأفراد";
  if (rawType && rawType.trim()) return rawType;
  return "العامة";
}

function getStopSequence(
  stopDoc: QueryDocumentSnapshot,
  stopData: Record<string, any>
) {
  const raw = stopData.stop_sequence;
  if (typeof raw === "number") return raw;
  if (typeof raw === "string") return parseInt(raw, 10) || 0;
  return parseInt(stopDoc.id, 10) || 0;
}

export default function UpcomingTrainsSection({
  stationId,
  stationName,
}: UpcomingTrainsSectionProps) {
  const [rows, setRows] = useState<TrainRowItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedTripId, setSelectedTripId] = useState<string | null>(null);

  useEffect(() => {
    const fetchUpcomingTrains = async () => {
      if (!stationId) {
        setRows([]);
        setSelectedTripId(null);
        return;
      }

      try {
        setLoading(true);
        setRows([]);
        setSelectedTripId(null);

        const now = new Date();
        const end = new Date(now.getTime() + 30 * 60 * 1000);

        const stopsQuery = query(
          collectionGroup(db, "stops"),
          where("station_id", "==", stationId),
          where("arrival_timestamp", ">=", Timestamp.fromDate(now)),
          where("arrival_timestamp", "<", Timestamp.fromDate(end)),
          orderBy("arrival_timestamp"),
          limit(20)
        );

        const upcomingStopsSnap = await getDocs(stopsQuery);
        const result: TrainRowItem[] = [];

        for (const stopDoc of upcomingStopsSnap.docs) {
          const stopData = stopDoc.data() as Record<string, any>;
          const tripRef = stopDoc.ref.parent.parent as DocumentReference | null;
          const tripId = tripRef?.id ?? "";

          if (!tripId || !tripRef) continue;

          const lineId = String(stopData.line_id ?? "").toLowerCase();
          const lineColor = lineIdToColor[lineId] ?? "#9ca3af";
          const lineNumber = lineIdToNumber[lineId] ?? 0;

          let arrivalText = "--";
          let arrivalDate: Date | null = null;

          if (
            typeof stopData.arrival_time === "string" &&
            stopData.arrival_time.trim()
          ) {
            arrivalText = formatArrivalTime(stopData.arrival_time);
          } else if (stopData.arrival_timestamp?.toDate) {
            arrivalDate = stopData.arrival_timestamp.toDate();
            arrivalText = formatFromTimestamp(arrivalDate);
          }

          if (!arrivalDate && stopData.arrival_timestamp?.toDate) {
            arrivalDate = stopData.arrival_timestamp.toDate();
          }

          let endCode =
            typeof stopData.end_station_code === "string" &&
            stopData.end_station_code.trim()
              ? stopData.end_station_code.trim()
              : "";

          if (!endCode) {
            const tripSnap = await getDoc(tripRef);
            const tripData = tripSnap.data() as Record<string, any> | undefined;

            if (tripData) {
              for (const key of tripEndCandidates) {
                const val =
                  typeof tripData[key] === "string" ? tripData[key].trim() : "";
                if (val) {
                  endCode = val;
                  break;
                }
              }
            }
          }

          const destination = resolveEndName(endCode);
          const terminalHere = isTerminalHere({
            destCode: endCode,
            destName: destination,
            stationId,
            stationName,
          });

          const tripStopsSnap = await getDocs(collection(tripRef, "stops"));
          if (tripStopsSnap.empty) continue;

          const currentSeq = getStopSequence(stopDoc, stopData);

          const stopsMeta: {
            ref: DocumentReference;
            seq: number;
            arrTs: Date | null;
            depTs: Date | null;
          }[] = [];

          for (const d of tripStopsSnap.docs) {
            const dData = d.data() as Record<string, any>;
            const seq = getStopSequence(d, dData);
            if (!seq) continue;

            const arrTs = dData.arrival_timestamp?.toDate
              ? dData.arrival_timestamp.toDate()
              : null;

            const depTs = dData.departure_timestamp?.toDate
              ? dData.departure_timestamp.toDate()
              : null;

            stopsMeta.push({
              ref: d.ref,
              seq,
              arrTs,
              depTs,
            });
          }

          if (stopsMeta.length === 0) continue;

          const firstSeq = Math.min(...stopsMeta.map((s) => s.seq));

          // لا نعرض الرحلات الطالعة من نفس المحطة
          // إذا كانت هذه المحطة هي أول محطة في الرحلة، فهي نقطة انطلاق الرحلة
          if (currentSeq === firstSeq) {
            continue;
          }

          // نبحث عن آخر محطة غادرها القطار قبل وصوله للمحطة الحالية
          const nowTime = Date.now();
          let lastDeparted: {
            ref: DocumentReference;
            seq: number;
            arrTs: Date | null;
            depTs: Date | null;
          } | null = null;

          for (const item of stopsMeta) {
            if (item.seq >= currentSeq) continue;
            if (!item.depTs) continue;
            if (item.depTs.getTime() > nowTime) continue;

            if (!lastDeparted) {
              lastDeparted = item;
            } else if (
              item.depTs.getTime() > (lastDeparted.depTs?.getTime() ?? 0)
            ) {
              lastDeparted = item;
            }
          }

          // إذا الرحلة لم تنطلق بعد، لا نعرض لها ازدحام
          const carriageSourceRef = lastDeparted?.ref ?? null;

          let carriages: CarriageItem[] = [];

          if (carriageSourceRef) {
            const carSnap = await getDocs(
              query(
                collection(carriageSourceRef, "carriages"),
                orderBy("carriage_no")
              )
            );

            carriages = carSnap.docs.map((carDoc) => {
              const carData = carDoc.data() as Record<string, any>;

              const numberRaw = carData.carriage_no;
              const occRaw = carData.occupancy_pct;
              const typeRaw = carData.carriage_type as string | undefined;

              const number =
                typeof numberRaw === "number"
                  ? numberRaw
                  : parseInt(String(numberRaw ?? 1), 10) || 1;

              const crowdingPercent =
                typeof occRaw === "number" ? occRaw : Number(occRaw ?? 0);

              const crowdingLevel = getCrowdingLevel(crowdingPercent);

              return {
                number,
                className: mapClassName(typeRaw),
                crowdingPercent,
                crowdingLevel,
              };
            });
          }

          const crowdPercent =
            carriages.length > 0
              ? carriages.reduce((sum, c) => sum + c.crowdingPercent, 0) /
                carriages.length
              : null;

          result.push({
            tripId,
            destination,
            lineId,
            lineColor,
            lineNumber,
            arrivalText,
            arrivalDate,
            crowdPercent,
            carriages,
            isTerminalHere: terminalHere,
          });
        }

        result.sort((a, b) => {
          const at = a.arrivalDate?.getTime() ?? 0;
          const bt = b.arrivalDate?.getTime() ?? 0;
          return at - bt;
        });

        setRows(result);

        if (result.length > 0) {
          setSelectedTripId(result[0].tripId);
        }
      } catch (error) {
        console.error("Error fetching upcoming trains:", error);
        setRows([]);
        setSelectedTripId(null);
      } finally {
        setLoading(false);
      }
    };

    fetchUpcomingTrains();
  }, [stationId, stationName]);

  const selectedTrain = useMemo(
    () => rows.find((row) => row.tripId === selectedTripId) ?? null,
    [rows, selectedTripId]
  );

  return (
    <div className="dashboard-card p-6">
      <div className="text-right mb-4">
        <h3 className="text-base font-bold text-foreground">
          القطارات القادمة خلال 30 دقيقة
        </h3>
        <p className="text-xs text-muted-foreground">
          اختر رحلة لعرض تفاصيل المقطورات
        </p>
      </div>

      {!stationId ? (
        <div className="text-center text-sm text-muted-foreground py-6">
          اختاري محطة من الخريطة أولاً
        </div>
      ) : loading ? (
        <div className="text-center text-sm text-muted-foreground py-6">
          جاري تحميل الرحلات القادمة...
        </div>
      ) : rows.length === 0 ? (
        <div className="text-center text-sm text-muted-foreground py-6">
          لا توجد رحلات قادمة خلال 30 دقيقة لهذه المحطة
        </div>
      ) : (
        <>
          <div className="overflow-hidden rounded-2xl border border-border">
            <div className="grid grid-cols-4 bg-muted/70 dark:bg-zinc-900/70 px-4 py-3 text-xs font-bold text-foreground">
              <div className="text-right">الاتجاه</div>
              <div className="text-center">المسار</div>
              <div className="text-center">الازدحام</div>
              <div className="text-left">الوصول</div>
            </div>

            {rows.map((row, index) => {
              const active = row.tripId === selectedTripId;
              const pillColor = percentColor(row.crowdPercent);

              return (
                <button
                  key={`${row.tripId}-${index}`}
                  type="button"
                  onClick={() => setSelectedTripId(row.tripId)}
                  className={`grid w-full grid-cols-4 items-center px-4 py-3 text-sm transition-colors border-t border-border first:border-t-0 ${
                    active ? "bg-primary/10 dark:bg-white/10" : "bg-background dark:bg-zinc-950/30 hover:bg-muted/30 dark:hover:bg-white/5"
                  }`}
                >
                  <div className="text-right font-semibold text-foreground">
                    <div>{row.destination}</div>
                    {row.isTerminalHere && (
                      <div className="text-[11px] text-muted-foreground mt-1">
                        محطة نهائية
                      </div>
                    )}
                  </div>

                  <div className="flex justify-center">
                    <span
                      className="inline-flex min-w-9 items-center justify-center rounded-full px-3 py-1 text-xs font-bold text-white"
                      style={{ backgroundColor: row.lineColor }}
                    >
                      {row.lineNumber || "-"}
                    </span>
                  </div>

                  <div className="flex justify-center">
                    <span
                      className="inline-flex items-center gap-2 rounded-full px-3 py-1 text-xs font-bold"
                      style={{
                        color: pillColor,
                        backgroundColor: `${pillColor}18`,
                      }}
                    >
                      <span
                        className="inline-block h-2.5 w-2.5 rounded-full"
                        style={{ backgroundColor: pillColor }}
                      />
                      {row.crowdPercent !== null
                        ? `${Math.round(row.crowdPercent)}%`
                        : "غير متاح"}
                    </span>
                  </div>

                  <div className="text-left font-semibold text-foreground">
                    {row.arrivalText}
                  </div>
                </button>
              );
            })}
          </div>

          {selectedTrain && (
            <div className="mt-6">
              <div className="text-right mb-3">
                <h4 className="text-sm font-bold text-foreground">
                  معدل ازدحام المقطورات
                </h4>
                <p className="text-xs text-muted-foreground">
                  {selectedTrain.destination} · {selectedTrain.arrivalText}
                </p>
              </div>

              {selectedTrain.carriages.length === 0 ? (
                <div className="rounded-2xl border border-dashed border-border py-6 text-center text-sm text-muted-foreground">
                  لا توجد بيانات متاحة للمقطورات لهذه الرحلة حالياً
                </div>
              ) : (
                <div>
                  {/* Legend */}
                  <div className="flex items-center justify-center gap-6 mb-5 text-xs font-bold">
                    {(["extreme", "high", "medium", "low"] as CrowdLevel[]).map(
                      (lvl) => (
                        <div key={lvl} className="flex items-center gap-1.5">
                          <span
                            className="inline-block w-2.5 h-2.5 rounded-full"
                            style={{ backgroundColor: crowdLevelColor(lvl) }}
                          />
                          <span className="text-foreground">
                            {crowdLevelLabel(lvl)}
                          </span>
                        </div>
                      )
                    )}
                  </div>

                  {/* Train layout: info cards (right) — arrows — vertical train (left) */}
                  <div className="flex justify-center gap-4 py-2" dir="rtl">
                    {/* Info cards column */}
                    <div className="flex flex-col gap-3">
                      {selectedTrain.carriages.map((carriage) => {
                        const color = crowdLevelColor(carriage.crowdingLevel);
                        return (
                          <div
                            key={`info-${carriage.number}`}
                            className="flex flex-col items-center justify-center rounded-2xl bg-background px-5 py-3 min-w-[130px] h-[88px]"
                            style={{ border: `2px solid ${color}` }}
                          >
                            <div className="text-sm font-bold text-foreground">
                              {carriage.className}
                            </div>
                            <span
                              className="inline-block w-2 h-2 rounded-full my-1.5"
                              style={{ backgroundColor: color }}
                            />
                            <div
                              className="text-xs font-bold"
                              style={{ color }}
                            >
                              {crowdLevelLabel(carriage.crowdingLevel)}
                            </div>
                          </div>
                        );
                      })}
                    </div>

                    {/* Arrows column */}
                    <div className="flex flex-col gap-3">
                      {selectedTrain.carriages.map((carriage) => (
                        <div
                          key={`arr-${carriage.number}`}
                          className="flex items-center justify-center h-[88px] text-muted-foreground/60 text-lg"
                        >
                          ◄ - - -
                        </div>
                      ))}
                    </div>

                    {/* Vertical train */}
                    <div className="flex flex-col items-center">
                      {/* Front (locomotive head) */}
                      <div className="w-[110px] h-6 rounded-t-[28px] bg-foreground" />
                      {selectedTrain.carriages.map((carriage, idx) => {
                        const color = crowdLevelColor(carriage.crowdingLevel);
                        const isLast =
                          idx === selectedTrain.carriages.length - 1;
                        return (
                          <div
                            key={`car-${carriage.number}`}
                            className="flex flex-col items-center"
                          >
                            {/* Carriage body */}
                            <div
                              className="w-[110px] h-[88px] flex flex-col items-center justify-center gap-1.5 px-3"
                              style={{ backgroundColor: color }}
                            >
                              {[0, 1, 2].map((w) => (
                                <div
                                  key={w}
                                  className="w-full h-3 rounded-sm bg-white/85"
                                />
                              ))}
                            </div>
                            {/* Connector */}
                            {!isLast && (
                              <div className="w-8 h-2 my-0.5 bg-muted-foreground/40 rounded-sm" />
                            )}
                          </div>
                        );
                      })}
                      {/* Rear */}
                      <div className="w-[110px] h-6 rounded-b-[28px] bg-foreground" />
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}
        </>
      )}
    </div>
  );
}