import pandas as pd
import numpy as np

from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import GridSearchCV

import coremltools as ct

#######################################
# 1. Define a parser for cells with R/L
#######################################
def parse_rl(value):
    """
    Converts a string like:
      '10 L'   -> 10.0
      '15.5 R' -> -15.5
      '176'    -> 176.0
    """
    s = str(value).strip()
    if not s:
        # If it's empty or invalid, return NaN or 0
        return float("nan")
    
    parts = s.split()  # splits on whitespace
    num_str = parts[0] # numeric part
    
    try:
        val = float(num_str)
    except ValueError:
        # if the numeric part isn't parseable, set it to NaN
        return float("nan")
    
    # If there's a second part, check if it's 'R' or 'L'
    if len(parts) > 1:
        direction = parts[1].upper()
        if direction == "R":
            val = -val
        # 'L' means do nothing (val stays positive)

    return val

#######################################
# 2. Load and parse the CSV
#######################################
df = pd.read_csv("trajectory-data.csv")

# Apply parse_rl to every column you care about.
# If you know exactly which columns may contain R/L, you can limit to those.
for col in df.columns:
    df[col] = df[col].apply(parse_rl)

#######################################
# 3. Add two new columns:
#   lateral_hla_yd = sin(launch_h_deg) * carry
#   lateral_spin_yd = lateral_yd - lateral_hla_yd
#######################################
# Make sure you have a column named "Launch H (deg)" or similar in the CSV
# so we can compute sin(launch_h_deg).
# Also ensure "Carry (yd)" and "Lateral (yd)" exist.

# For clarity, rename columns first (removing parentheses/spaces):
df.rename(
    columns={
        "Carry (yd)": "carry_yd",
        "Ball (mph)": "ball_mph",
        "Spin (rpm)": "spin_rpm",
        "Spin Axis (deg)": "spin_axis_deg",
        "Launch V (deg)": "launch_v_deg",
        "Launch H (deg)": "launch_h_deg",
        "Roll (yd)": "roll_yd",
        "Height (ft)": "height_ft",
        "Lateral (yd)": "lateral_yd"
    },
    inplace=True,
    errors="ignore"  # In case some columns don't exist
)

# Only proceed if "launch_h_deg" is still present in the DataFrame
if "launch_h_deg" in df.columns:
    # lateral_hla_yd
    df["lateral_hla_yd"] = np.sin(np.deg2rad(df["launch_h_deg"])) * df["carry_yd"]
else:
    df["lateral_hla_yd"] = 0.0  # or raise an error if you must have it

# If "lateral_yd" is missing, create or raise an error
if "lateral_yd" not in df.columns:
    # Possibly raise an error or skip
    df["lateral_yd"] = 0.0

# lateral_spin_yd
df["lateral_spin_yd"] = df["lateral_yd"] - df["lateral_hla_yd"]

#######################################
# 4. Train separate models using only:
#   ["carry_yd", "ball_mph", "spin_rpm", "spin_axis_deg", "launch_v_deg"]
#   for each target:
#     - roll_yd
#     - height_ft
#     - lateral_spin_yd
#######################################
feature_cols = ["carry_yd", "ball_mph", "spin_rpm", "spin_axis_deg", "launch_v_deg"]

# Set up targets dict: model_name -> column_name
targets = {
    "roll_yd": "roll_yd",
    "height_ft": "height_ft",
    "lateral_spin_yd": "lateral_spin_yd"
}

# Param grid for each model
param_grid = {
    "regressor__n_estimators": [50, 100, 200],
    "regressor__max_depth": [None, 5, 10],
    "regressor__min_samples_leaf": [1, 2, 5]
}

from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error

best_pipelines = {}

for model_name, target_col in targets.items():
    # Drop rows with NaNs in features or target
    df_sub = df[feature_cols + [target_col]].dropna()

    X = df_sub[feature_cols]
    y = df_sub[target_col]
    
    # If you want a test split to check final MSE
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    # Define pipeline
    from sklearn.pipeline import Pipeline
    pipeline = Pipeline([
        ("scaler", StandardScaler()),
        ("regressor", RandomForestRegressor(random_state=42))
    ])
    
    # Use GridSearchCV to find best hyperparams
    from sklearn.model_selection import GridSearchCV
    grid_search = GridSearchCV(
        pipeline,
        param_grid,
        cv=3,
        scoring='neg_mean_squared_error',
        n_jobs=-1,
        verbose=1
    )
    grid_search.fit(X_train, y_train)
    
    # Print the best params
    print(f"\n=== Best params for {model_name} ===")
    print(grid_search.best_params_)
    
    best_pipeline = grid_search.best_estimator_
    
    # Evaluate on the hold-out test set
    y_pred = best_pipeline.predict(X_test)
    mse = mean_squared_error(y_test, y_pred)
    print(f"Test MSE for {model_name}: {mse:.2f}")
    
    # Store the pipeline
    best_pipelines[model_name] = best_pipeline


#######################################
# 5. Convert each model to Core ML
#######################################
for model_name, pipeline in best_pipelines.items():
    # You can name the output feature same as model_name or something else
    coreml_model = ct.converters.sklearn.convert(
        pipeline,
        input_features=feature_cols,
        output_feature_names=model_name
    )
    
    # Save as e.g. "GolfTrajectoryModel_roll_yd.mlmodel", etc.
    mlmodel_filename = f"trajectory_model_{model_name}.mlmodel"
    coreml_model.save(mlmodel_filename)
    print(f"Saved {mlmodel_filename}")
