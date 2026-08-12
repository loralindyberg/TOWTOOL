import os
import numpy as np
import pandas as pd
import xarray as xr

# 1. Authentication setup
headers_auth = {
    "storage_options": {
        "headers": {
            "Authorization": "Bearer ### PASTE CDSAPI KEY###"
        }
    }
}

# Define urls do download data
sfc_url = "https://arco.datastores.ecmwf.int/cadl-arco-geo-002/arco/reanalysis_era5_single_levels/sfc/geoChunked.zarr"
wav_url = "https://arco.datastores.ecmwf.int/cadl-arco-geo-003/arco/reanalysis_era5_single_levels/wav/geoChunked.zarr"

print("Connecting to ECMWF Surface and Wave Zarr stores...")
ds_sfc = xr.open_zarr(sfc_url, consolidated=True, **headers_auth)
ds_wav = xr.open_zarr(wav_url, consolidated=True, **headers_auth)

# 2. Slice both datasets chronologically
time_slice = slice("1940-01-01T00:00:00", "2025-12-31T23:00:00")
ds_sfc_sub = ds_sfc.sel(time=time_slice)
ds_wav_sub = ds_wav.sel(time=time_slice)

# 3. Define variables in dataset variables
ds_wind = ds_sfc_sub[["u10", "v10"]]
ds_wave = ds_wav_sub[["swh", "mwd", "mwp"]]

# 4. Define lat/lon of interest. Will automatically take closest point
target_lat = 47.3
target_lon = -3.6

print(f"Extracting point data for Lat: {target_lat}, Lon: {target_lon}...")
ds_wind_pt = ds_wind.sel(
    latitude=target_lat, longitude=target_lon, method="nearest"
)
ds_wave_pt = ds_wave.sel(
    latitude=target_lat, longitude=target_lon, method="nearest"
)

print("Merging datasets")
# Combine wind and wave points along their identical time coordinate
ds_final = xr.merge([ds_wind_pt, ds_wave_pt], compat="override")

# 5. Compute from Zarr lazy-loading and convert to Pandas DataFrame
df = ds_final.compute().to_dataframe().reset_index()

print("Calculating wind direction")
# Wind Speed: sqrt(u10^2 + v10^2)
df["wind_speed"] = np.sqrt(df["u10"] ** 2 + df["v10"] ** 2)

# Wind Direction: Mathematical u/v to meteorological degrees (0-360)
df["wind_direction"] = (180 + np.degrees(np.arctan2(df["u10"], df["v10"]))) % 360

# 6. Organize into csv outputs
final_columns = {
    "time": "t",
    "swh": "Significant Wave Height (m)",
    "mwp": "Peak Wave Period (s)",
    "mwd": "Wave Direction (deg)",
    "wind_speed": "Wind Speed (m/s)",
    "wind_direction": "Wind Direction (deg)",
}

# Filter and rename the columns simultaneously
output_df = df[list(final_columns.keys())].rename(columns=final_columns)

# 7. Save to a single output file
output_csv = "era5_combined_wind_wave.csv"
output_df.to_csv(output_csv, index=False)

print(f"Success! Your combined data has been saved to: {output_csv}")
print(output_df.head())
