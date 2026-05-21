import { useEffect, useRef, useCallback, useState } from 'react';
import rawStations from '../data/metroStations.json';
import { db } from '../lib/firebase';
import {
  collection,
  limit,
  orderBy,
  query,
  onSnapshot,
} from 'firebase/firestore';

export interface MetroStation {
  id: string;
  name: string;
  nameAr: string;
  lat: number;
  lng: number;
  line: string;
  lineAr: string;
  stationCode: string;
  stationType: string;
  stationTypeAr: string;
  stationTypeCode: number;
  comments: string | null;
  commentsAr: string | null;
  stationSeq: number;
  congestion: 'normal' | 'medium' | 'crowded' | 'very_crowded';
  passengers: number;
  congestionPercent: number;
  peakMinutes: number;
  accuracy: number;
  activeTrips: number;
  passengersPerCar: number;
  nextTrain: string;
}

const congestionColors: Record<string, string> = {
  normal: '#22c55e',
  medium: '#eab308',
  crowded: '#d6312b',
  very_crowded: '#741313',
};

const congestionLabels: Record<string, string> = {
  normal: 'طبيعي',
  medium: 'متوسط',
  crowded: 'مزدحم',
  very_crowded: 'مزدحم جداً',
};

const mapCrowdLevelToCongestion = (
  crowdLevel?: string
): MetroStation['congestion'] => {
  const value = (crowdLevel || '').toLowerCase().trim();

  if (value === 'low') return 'normal';
  if (value === 'medium') return 'medium';
  if (value === 'high') return 'crowded';
  if (value === 'extreme') return 'very_crowded';

  return 'normal';
};

const statsByStationId: Record<
  string,
  {
    passengers: number;
    congestionPercent: number;
    peakMinutes: number;
    accuracy: number;
    activeTrips: number;
    passengersPerCar: number;
    nextTrain: string;
  }
> = {
  S1: {
    passengers: 3200,
    congestionPercent: 92,
    peakMinutes: 8,
    accuracy: 97.1,
    activeTrips: 12,
    passengersPerCar: 48,
    nextTrain: '2 د',
  },
  S2: {
    passengers: 2800,
    congestionPercent: 78,
    peakMinutes: 15,
    accuracy: 95.8,
    activeTrips: 9,
    passengersPerCar: 42,
    nextTrain: '4 د',
  },
  S3: {
    passengers: 1500,
    congestionPercent: 55,
    peakMinutes: 25,
    accuracy: 96.4,
    activeTrips: 6,
    passengersPerCar: 30,
    nextTrain: '6 د',
  },
  S4: {
    passengers: 1200,
    congestionPercent: 48,
    peakMinutes: 30,
    accuracy: 96.7,
    activeTrips: 5,
    passengersPerCar: 24,
    nextTrain: '7 د',
  },
  S5: {
    passengers: 2500,
    congestionPercent: 75,
    peakMinutes: 12,
    accuracy: 94.5,
    activeTrips: 10,
    passengersPerCar: 40,
    nextTrain: '3 د',
  },
  S6: {
    passengers: 800,
    congestionPercent: 30,
    peakMinutes: 40,
    accuracy: 98.2,
    activeTrips: 4,
    passengersPerCar: 18,
    nextTrain: '8 د',
  },
};

export const metroStations: MetroStation[] = rawStations.map((station: any) => ({
  id: station.id,
  name: station.metrostationname,
  nameAr: station.metrostationnamear,
  lat: station.geo_point_2d.lat,
  lng: station.geo_point_2d.lon,
  line: station.metrolinename,
  lineAr: station.metrolinenamear,
  stationCode: station.metrostationcode,
  stationType: station.mstationtypename,
  stationTypeAr: station.mstationtypenamear,
  stationTypeCode: station.mstationtypecode,
  comments: station.comments,
  commentsAr: station.commentsar,
  stationSeq: station.stationseq,
  congestion: 'normal',
  ...(statsByStationId[station.id] ?? {
    passengers: 0,
    congestionPercent: 0,
    peakMinutes: 0,
    accuracy: 0,
    activeTrips: 0,
    passengersPerCar: 0,
    nextTrain: '-',
  }),
}));

interface Props {
  onStationSelect: (station: MetroStation) => void;
  selectedStationId: string | null;
}

declare global {
  interface Window {
    google: any;
  }
}

const MetroGoogleMap = ({ onStationSelect, selectedStationId }: Props) => {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<any>(null);
  const markersRef = useRef<any[]>([]);
  const [liveCongestionByStationId, setLiveCongestionByStationId] = useState<
    Record<string, MetroStation['congestion']>
  >({});

  const createMarkerIcon = useCallback((color: string, isSelected: boolean) => {
    const outerSize = isSelected ? 36 : 28;
    const innerSize = isSelected ? 16 : 12;
    const strokeWidth = isSelected ? 3 : 0;
    const outerOffset = outerSize / 2;
    const innerOffset = outerSize / 2;

    const svg = `
      <svg xmlns="http://www.w3.org/2000/svg" width="${outerSize}" height="${outerSize}" viewBox="0 0 ${outerSize} ${outerSize}">
        <circle cx="${outerOffset}" cy="${outerOffset}" r="${outerSize / 2 - 1}" fill="${color}" opacity="${isSelected ? 1 : 0.9}" />
        ${isSelected ? `<circle cx="${outerOffset}" cy="${outerOffset}" r="${outerSize / 2 - 1}" fill="none" stroke="#1e3a5f" stroke-width="${strokeWidth}" />` : ''}
        <circle cx="${innerOffset}" cy="${innerOffset}" r="${innerSize / 2}" fill="white" />
      </svg>
    `;

    return {
      url: 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg),
      scaledSize: new window.google.maps.Size(outerSize, outerSize),
      anchor: new window.google.maps.Point(outerOffset, outerOffset),
    };
  }, []);

  const subscribeToLiveCongestion = useCallback(() => {
    const unsubscribes: (() => void)[] = [];

    metroStations.forEach((station) => {
      const ticksRef = collection(db, 'live', station.id, 'ticks');
      const q = query(ticksRef, orderBy('timestamp', 'desc'), limit(1));

      const unsubscribe = onSnapshot(q, (snapshot) => {
        if (!snapshot.empty) {
          const data = snapshot.docs[0].data();
          const crowdLevel = data?.crowd_level;

          setLiveCongestionByStationId((prev) => ({
            ...prev,
            [station.id]: mapCrowdLevelToCongestion(crowdLevel),
          }));
        }
      });

      unsubscribes.push(unsubscribe);
    });

    return () => {
      unsubscribes.forEach((unsub) => unsub());
    };
  }, []);

  const initMap = useCallback(() => {
    if (!mapRef.current || !window.google) return;

    const map = new window.google.maps.Map(mapRef.current, {
      center: { lat: 24.69, lng: 46.69 },
      zoom: 11,
      disableDefaultUI: true,
      zoomControl: true,
      styles: [
        { elementType: 'geometry', stylers: [{ color: '#ffffff' }] },
        { elementType: 'labels.text.fill', stylers: [{ color: '#6b7280' }] },
        { elementType: 'labels.text.stroke', stylers: [{ color: '#ffffff' }] },
        { featureType: 'road', elementType: 'geometry', stylers: [{ color: '#f8fafc' }] },
        { featureType: 'water', elementType: 'geometry', stylers: [{ color: '#eef2f7' }] },
        { featureType: 'poi', stylers: [{ visibility: 'off' }] },
        { featureType: 'transit', stylers: [{ visibility: 'off' }] },
      ],
    });

    mapInstanceRef.current = map;

    markersRef.current.forEach((m) => m.setMap(null));
    markersRef.current = [];

    metroStations.forEach((station) => {
      const isSelected = station.id === selectedStationId;
      const currentCongestion =
        liveCongestionByStationId[station.id] ?? station.congestion;
      const color = congestionColors[currentCongestion];

      const marker = new window.google.maps.Marker({
        position: { lat: station.lat, lng: station.lng },
        map,
        title: station.nameAr,
        icon: createMarkerIcon(color, isSelected),
        zIndex: isSelected ? 999 : 1,
      });

      const infoWindow = new window.google.maps.InfoWindow({
        content: `
          <div style="background:white;padding:8px 10px;border-radius:8px;font-size:12px;min-width:120px">
            <div style="font-weight:700;color:#111827;margin-bottom:4px">${station.nameAr}</div>
            <div style="color:${color};font-weight:600">${congestionLabels[currentCongestion]}</div>
          </div>
        `,
      });

      marker.addListener('click', () => {
        onStationSelect(station);
        infoWindow.open(map, marker);
      });

      markersRef.current.push(marker);
    });
  }, [onStationSelect, selectedStationId, createMarkerIcon, liveCongestionByStationId]);

  useEffect(() => {
    const unsubscribe = subscribeToLiveCongestion();
    return unsubscribe;
  }, [subscribeToLiveCongestion]);

  useEffect(() => {
    if (window.google?.maps) {
      initMap();
      return;
    }

    const interval = setInterval(() => {
      if (window.google?.maps) {
        clearInterval(interval);
        initMap();
      }
    }, 200);

    return () => clearInterval(interval);
  }, [initMap]);



  return (
    <div className="w-full h-full relative">
      <div ref={mapRef} className="w-full h-full rounded-xl" />



      <div className="absolute bottom-3 left-3 bg-white/90 backdrop-blur-sm rounded-xl p-2.5 shadow-md border flex gap-3 text-[11px]">
        {Object.entries(congestionLabels).map(([key, label]) => (
          <div key={key} className="flex items-center gap-1.5">
            <div
              className="w-3 h-3 rounded-full"
              style={{ backgroundColor: congestionColors[key] }}
            />
            <span className="text-gray-700">{label}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

export default MetroGoogleMap;