import numpy as np

def gaussian(x, mu, sigma_h):
    sigma = sigma_h * 60.0
    return np.exp(-0.5 * ((x - mu) / sigma) ** 2)

def base_demand_curve(minute_of_day, config):
    peaks = config["peaks"]
    base = 0.05
    demand = base
    for p in peaks:
        demand += gaussian(minute_of_day, p["hour"]*60, p["sigma_hours"])
    return demand
