def _match_station(sta, key):
    k = str(key).upper()
    return str(sta.get("station_id","")).upper() == k or str(sta.get("code","")).upper() == k

def _get_station(seeds, key):
    for s in seeds["stations"]:
        if _match_station(s, key):
            return s
    raise ValueError(f"Station not found: {key}")

def _station_scale_from_capacity(stations, rec):
    caps = [r.get("capacity_platform") for r in stations if isinstance(r.get("capacity_platform"), (int,float))]
    mean_cap = (sum(caps)/len(caps)) if caps else 1500.0
    return float(rec.get("capacity_platform", mean_cap))/float(mean_cap) if mean_cap>0 else 1.0

def compute_demand_modifier(ts, station_key, seeds, config):
    date_str = ts.date().isoformat()
    weekday  = ts.weekday()
    st = _get_station(seeds, station_key)
    station_scale = _station_scale_from_capacity(seeds["stations"], st)

    weekend_mult = float(config["multipliers"]["weekend"]) if weekday in [4,5] else 1.0

    w = seeds["weather"].get(date_str, {"condition":"Sunny"})
    weather_cond = w["condition"] if isinstance(w, dict) else str(w)
    weather_mult = float(config["multipliers"]["weather"].get(weather_cond, 1.0))

    sid = str(st.get("station_id","")).upper()
    scode = str(st.get("code","")).upper()
    event_mult = 1.0
    for ev in seeds["events"]:
        ev_station = str(ev.get("station_id") or ev.get("station") or ev.get("station_code") or "").upper()
        if ev.get("date")==date_str and ev_station in {sid, scode}:
            et = ev.get("event_type","Other")
            event_mult = max(event_mult, float(config["events"].get(et, 1.0)))

    holiday_mult = float(config["multipliers"]["holiday"])
    for hol in seeds["holidays"]:
        if hol.get("date")==date_str:
            try: holiday_mult = float(hol.get("demand_modifier", holiday_mult))
            except: pass

    final = station_scale * weekend_mult * weather_mult * event_mult * holiday_mult
    return {"station": scode or sid, "date": date_str, "weather": weather_cond,
            "station_scale": station_scale, "weekend_mult": weekend_mult,
            "weather_mult": weather_mult, "event_mult": event_mult,
            "holiday_mult": holiday_mult, "final_demand_modifier": final}
