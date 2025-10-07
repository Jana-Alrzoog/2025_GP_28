
````md
# Step 01 — Seeds & Config (v1.0)
**Date:** 2025-10-07 • **Owner:** Jana • **Timezone:** Asia/Riyadh

## Objective
Establish a single source of truth for the simulation by locking down:
1) the **seed files** (stations, events, holidays, weather), and  
2) the **global configuration** used by all subsequent steps.

## Seeds Inventory
- `data/seeds/stations.json`  
  Expected fields: `station_id, name, line_id, description, latitude, longitude`
- `data/seeds/calendar_events.csv`  
  Fields: `event_name, start_date, end_date, location, crowd_factor, special_event_type`
- `data/seeds/holidays.csv`  
  Fields: `holiday_name, start_date, end_date`
- `data/seeds/weather_patterns.json`  
  Fields: `condition, impact_factor`  
  Canonical values: `Sunny=1.00, Cloudy=0.95, Dusty=0.85, Rainy=0.70`

## Config Snapshot (`sims/00_config.yaml`)
```yaml
start_date: 2025-10-05
tz: Asia/Riyadh
minute_resolution: 1

date_range:
  start: 2025-10-05
  end:   2025-12-31

output_partitioning: monthly
random_seed: 20251007

operation:
  start_hour: 6
  hours_per_day: 18

peaks:
  - {hour: 8,  sigma_hours: 0.75}
  - {hour: 18, sigma_hours: 0.85}

headway:
  peak_pattern:    [7, 7, 6, 8]
  offpeak_pattern: [11, 10, 12, 11]

capacity:
  carriage_count: 4
  cabin_capacity_total: 557
  vip_cabin_capacity: 40
  vip_share_min: 0.02
  vip_share_max: 0.08

multipliers:
  weekend: 0.90
  holiday: 0.80
  weather: { Sunny: 1.00, Cloudy: 0.95, Dusty: 0.85, Rainy: 0.70 }
  events:  { Concert: 1.5, Sports: 1.4, Expo: 1.3, Other: 1.1, CityWideBackground: 1.05 }

quality_checks:
  crowd_pct_range: [0, 100]
  occupancy_pct_range: [0, 100]
  non_negative_counts: true
````

## Rationale (Why these choices)

* **4 carriages fixed** → fewer moving parts, easier validation.
* **Train capacity** fixed at **557** (standard) + VIP **40** → clean occupancy math.
* **Deterministic headway patterns** → realistic but reproducible flows.
* **Monthly partitioning** → manageable file sizes and easier analysis.

## Assumptions

* Weekend is **Friday/Saturday**.
* Events boost demand at matching locations; city-wide background factor = **1.05**.
* VIP share = **2–8%** of total demand at a timestamp.


```
