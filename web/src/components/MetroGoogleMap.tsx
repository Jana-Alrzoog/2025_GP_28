import { useEffect, useRef, useState, useCallback } from 'react';

export interface MetroStation {
  id: string;
  name: string;
  lat: number;
  lng: number;
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
  crowded: '#f97316',
  very_crowded: '#ef4444',
};

const congestionLabels: Record<string, string> = {
  normal: 'طبيعي',
  medium: 'متوسط',
  crowded: 'مزدحم',
  very_crowded: 'مزدحم جداً',
};

export const metroStations: MetroStation[] = [
  { id: 's1', name: 'محطة العليا', lat: 24.6900, lng: 46.6850, congestion: 'very_crowded', passengers: 3200, congestionPercent: 92, peakMinutes: 8, accuracy: 97.1, activeTrips: 12, passengersPerCar: 48, nextTrain: '2 د' },
  { id: 's2', name: 'محطة الملك عبدالله', lat: 24.7100, lng: 46.6750, congestion: 'crowded', passengers: 2800, congestionPercent: 78, peakMinutes: 15, accuracy: 95.8, activeTrips: 9, passengersPerCar: 42, nextTrain: '4 د' },
  { id: 's3', name: 'محطة قصر الحكم', lat: 24.6310, lng: 46.7130, congestion: 'medium', passengers: 1500, congestionPercent: 55, peakMinutes: 25, accuracy: 96.4, activeTrips: 6, passengersPerCar: 30, nextTrain: '6 د' },
  { id: 's4', name: 'محطة البطحاء', lat: 24.6350, lng: 46.7250, congestion: 'normal', passengers: 800, congestionPercent: 30, peakMinutes: 40, accuracy: 98.2, activeTrips: 4, passengersPerCar: 18, nextTrain: '8 د' },
  { id: 's5', name: 'محطة الملك فهد', lat: 24.6880, lng: 46.7220, congestion: 'crowded', passengers: 2500, congestionPercent: 75, peakMinutes: 12, accuracy: 94.5, activeTrips: 10, passengersPerCar: 40, nextTrain: '3 د' },
  { id: 's6', name: 'محطة السليمانية', lat: 24.6650, lng: 46.6950, congestion: 'normal', passengers: 600, congestionPercent: 22, peakMinutes: 50, accuracy: 97.9, activeTrips: 3, passengersPerCar: 12, nextTrain: '10 د' },
  { id: 's7', name: 'محطة المروج', lat: 24.7200, lng: 46.7100, congestion: 'medium', passengers: 1800, congestionPercent: 60, peakMinutes: 20, accuracy: 96.0, activeTrips: 7, passengersPerCar: 34, nextTrain: '5 د' },
  { id: 's8', name: 'محطة الورود', lat: 24.7050, lng: 46.7000, congestion: 'very_crowded', passengers: 3500, congestionPercent: 95, peakMinutes: 5, accuracy: 93.2, activeTrips: 14, passengersPerCar: 52, nextTrain: '1 د' },
  { id: 's9', name: 'محطة الربيع', lat: 24.7300, lng: 46.6800, congestion: 'normal', passengers: 450, congestionPercent: 18, peakMinutes: 60, accuracy: 99.1, activeTrips: 2, passengersPerCar: 10, nextTrain: '12 د' },
  { id: 's10', name: 'محطة النخيل', lat: 24.7450, lng: 46.6650, congestion: 'medium', passengers: 1200, congestionPercent: 48, peakMinutes: 30, accuracy: 96.7, activeTrips: 5, passengersPerCar: 24, nextTrain: '7 د' },
];

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

  const initMap = useCallback(() => {
    if (!mapRef.current || !window.google) return;

    const map = new window.google.maps.Map(mapRef.current, {
      center: { lat: 24.69, lng: 46.69 },
      zoom: 13,
      styles: [
        { elementType: 'geometry', stylers: [{ color: '#f5f5f5' }] },
        { elementType: 'labels.text.fill', stylers: [{ color: '#616161' }] },
        { featureType: 'road', elementType: 'geometry', stylers: [{ color: '#ffffff' }] },
        { featureType: 'water', elementType: 'geometry', stylers: [{ color: '#c9c9c9' }] },
        { featureType: 'poi', stylers: [{ visibility: 'off' }] },
      ],
      disableDefaultUI: true,
      zoomControl: true,
      mapTypeControl: false,
      streetViewControl: false,
      fullscreenControl: false,
    });

    mapInstanceRef.current = map;

    markersRef.current.forEach(m => m.setMap(null));
    markersRef.current = [];

    metroStations.forEach((station) => {
      const isSelected = station.id === selectedStationId;
      const color = congestionColors[station.congestion];

      const marker = new window.google.maps.Marker({
        position: { lat: station.lat, lng: station.lng },
        map,
        title: station.name,
        icon: createMarkerIcon(color, isSelected),
        zIndex: isSelected ? 999 : 1,
      });

      const infoWindow = new window.google.maps.InfoWindow({
        content: `
          <div style="direction:rtl;text-align:right;padding:4px;font-family:Tajawal,sans-serif">
            <strong style="font-size:14px">${station.name}</strong><br/>
            <span style="color:${color};font-weight:700">${congestionLabels[station.congestion]}</span><br/>
            <span style="font-size:12px;color:#666">الركاب: ${station.passengers.toLocaleString()}</span>
          </div>
        `,
      });

      marker.addListener('click', () => {
        onStationSelect(station);
        infoWindow.open(map, marker);
      });

      markersRef.current.push(marker);
    });
  }, [onStationSelect, selectedStationId, createMarkerIcon]);

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
      {/* Legend */}
      <div className="absolute bottom-3 left-3 bg-card/95 backdrop-blur-sm rounded-xl p-2.5 shadow-lg border border-border/50 flex gap-3 text-[11px]">
        {Object.entries(congestionLabels).map(([key, label]) => (
          <div key={key} className="flex items-center gap-1.5">
            <div className="w-3 h-3 rounded-full" style={{ backgroundColor: congestionColors[key] }} />
            <span className="text-muted-foreground">{label}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

export default MetroGoogleMap;
