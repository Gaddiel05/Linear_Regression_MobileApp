import io
import os
from contextlib import asynccontextmanager
from pathlib import Path
from typing import List

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler


FEATURE_COLUMNS = [
	"ENGINESIZE",
	"CYLINDERS",
	"FUELCONSUMPTION_CITY",
	"FUELCONSUMPTION_HWY",
	"FUELCONSUMPTION_COMB",
	"FUELCONSUMPTION_COMB_MPG",
]
TARGET_COLUMN = "CO2EMISSIONS"
SOURCE_DATASET_URL = (
	"https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/"
	"IBMDeveloperSkillsNetwork-ML0101EN-SkillsNetwork/labs/Module%202/data/FuelConsumptionCo2.csv"
)

API_DIR = Path(__file__).resolve().parent
MODEL_PATH = (API_DIR / "../linear_regression/model/random_forest_least_loss.pkl").resolve()
SCALER_PATH = (API_DIR / "../linear_regression/model/random_forest_scaler.pkl").resolve()


class PredictionRequest(BaseModel):
	model_config = ConfigDict(extra="forbid")

	enginesize: float = Field(gt=0.5, le=10.0, description="Engine size in liters")
	cylinders: int = Field(ge=2, le=16, description="Engine cylinder count")
	fuelconsumption_city: float = Field(
		gt=1.0,
		le=40.0,
		description="City fuel consumption (L/100km)",
	)
	fuelconsumption_hwy: float = Field(
		gt=1.0,
		le=35.0,
		description="Highway fuel consumption (L/100km)",
	)
	fuelconsumption_comb: float = Field(
		gt=1.0,
		le=40.0,
		description="Combined fuel consumption (L/100km)",
	)
	fuelconsumption_comb_mpg: int = Field(
		ge=5,
		le=100,
		description="Combined fuel consumption (MPG)",
	)


class RetrainDataPoint(PredictionRequest):
	co2emissions: float = Field(
		ge=50.0,
		le=700.0,
		description="Observed CO2 emissions to use as retraining target",
	)


class RetrainRequest(BaseModel):
	model_config = ConfigDict(extra="forbid")
	new_data: List[RetrainDataPoint] = Field(min_length=1)


app = FastAPI(
	title="Fuel CO2 Emissions Prediction API",
	description="Predict CO2 emissions and retrain the model when new data arrives.",
	version="1.0.0",
)

# Explicitly constrained CORS configuration (no wildcard).
allowed_origins = [
	"http://localhost:3000",
	"http://localhost:5173",
	"http://localhost:8080",
	"http://127.0.0.1:3000",
	"http://127.0.0.1:5173",
	"http://127.0.0.1:8080",
]

app.add_middleware(
	CORSMiddleware,
	allow_origins=allowed_origins,
	allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
	allow_credentials=True,
	allow_methods=["GET", "POST", "OPTIONS"],
	allow_headers=["Authorization", "Content-Type", "Accept", "Origin", "X-Requested-With"],
)


model = None
scaler = None


def _build_features_dataframe(rows: List[PredictionRequest]) -> pd.DataFrame:
	return pd.DataFrame(
		[
			{
				"ENGINESIZE": row.enginesize,
				"CYLINDERS": row.cylinders,
				"FUELCONSUMPTION_CITY": row.fuelconsumption_city,
				"FUELCONSUMPTION_HWY": row.fuelconsumption_hwy,
				"FUELCONSUMPTION_COMB": row.fuelconsumption_comb,
				"FUELCONSUMPTION_COMB_MPG": row.fuelconsumption_comb_mpg,
			}
			for row in rows
		]
	)


def _load_base_dataset() -> pd.DataFrame:
	df = pd.read_csv(SOURCE_DATASET_URL)
	required_columns = FEATURE_COLUMNS + [TARGET_COLUMN]
	missing = [col for col in required_columns if col not in df.columns]
	if missing:
		raise RuntimeError(f"Dataset is missing required columns: {missing}")
	return df[required_columns].copy()


def _fit_scaler_from_df(df: pd.DataFrame) -> StandardScaler:
	X = df[FEATURE_COLUMNS]
	y = df[TARGET_COLUMN]
	X_train, _, _, _ = train_test_split(X, y, test_size=0.20, random_state=101)
	local_scaler = StandardScaler()
	local_scaler.fit(X_train)
	return local_scaler


def _train_model_and_scaler(df: pd.DataFrame) -> tuple[RandomForestRegressor, StandardScaler]:
	X = df[FEATURE_COLUMNS]
	y = df[TARGET_COLUMN]
	X_train, _, y_train, _ = train_test_split(X, y, test_size=0.20, random_state=101)
	local_scaler = StandardScaler()
	X_train_scaled = local_scaler.fit_transform(X_train)
	local_model = RandomForestRegressor(random_state=101)
	local_model.fit(X_train_scaled, y_train)
	return local_model, local_scaler


def _ensure_model_and_scaler_loaded() -> None:
	global model, scaler

	if model is not None and scaler is not None:
		return

	base_df = _load_base_dataset()

	try:
		if model is None:
			if not MODEL_PATH.exists():
				raise FileNotFoundError(f"Model file not found at {MODEL_PATH}")
			model = joblib.load(MODEL_PATH)

		if scaler is None:
			if SCALER_PATH.exists():
				scaler = joblib.load(SCALER_PATH)
			else:
				scaler = _fit_scaler_from_df(base_df)
				joblib.dump(scaler, SCALER_PATH)
	except Exception:
		# Rebuild artifacts if serialized files are missing, corrupted, or incompatible.
		model, scaler = _train_model_and_scaler(base_df)
		joblib.dump(model, MODEL_PATH)
		joblib.dump(scaler, SCALER_PATH)


@asynccontextmanager
async def lifespan(_: FastAPI):
	_ensure_model_and_scaler_loaded()
	yield


app.router.lifespan_context = lifespan


@app.get("/")
def root() -> dict:
	return {
		"message": "API is running",
		"docs": "/docs",
		"prediction_endpoint": "/predict",
		"retrain_endpoint_json": "/retrain",
		"retrain_endpoint_csv": "/retrain/upload-csv",
	}


@app.post("/predict")
def predict(payload: PredictionRequest) -> dict:
	try:
		_ensure_model_and_scaler_loaded()
		input_df = _build_features_dataframe([payload])
		input_scaled = scaler.transform(input_df)
		prediction = float(model.predict(input_scaled)[0])
		return {"predicted_co2emissions": round(prediction, 4)}
	except Exception as exc:
		raise HTTPException(status_code=500, detail=f"Prediction failed: {exc}") from exc


def _retrain_and_save(df_full: pd.DataFrame) -> dict:
	global model, scaler

	X = df_full[FEATURE_COLUMNS]
	y = df_full[TARGET_COLUMN]

	X_train, _, y_train, _ = train_test_split(X, y, test_size=0.20, random_state=101)
	scaler = StandardScaler()
	X_train_scaled = scaler.fit_transform(X_train)

	model = RandomForestRegressor(random_state=101)
	model.fit(X_train_scaled, y_train)

	joblib.dump(model, MODEL_PATH)
	joblib.dump(scaler, SCALER_PATH)

	return {
		"message": "Model retrained and saved successfully",
		"model_path": str(MODEL_PATH),
		"scaler_path": str(SCALER_PATH),
		"training_rows_used": int(len(df_full)),
	}


@app.post("/retrain")
def retrain_with_json(payload: RetrainRequest) -> dict:
	try:
		base_df = _load_base_dataset()
		new_rows_df = _build_features_dataframe(payload.new_data)
		new_rows_df[TARGET_COLUMN] = [item.co2emissions for item in payload.new_data]
		combined_df = pd.concat([base_df, new_rows_df], ignore_index=True)
		return _retrain_and_save(combined_df)
	except Exception as exc:
		raise HTTPException(status_code=500, detail=f"Retraining failed: {exc}") from exc


@app.post("/retrain/upload-csv")
async def retrain_with_csv(file: UploadFile = File(...)) -> dict:
	if not file.filename.lower().endswith(".csv"):
		raise HTTPException(status_code=400, detail="Only CSV files are allowed.")

	try:
		content = await file.read()
		new_df = pd.read_csv(io.StringIO(content.decode("utf-8")))
		required_columns = FEATURE_COLUMNS + [TARGET_COLUMN]
		missing = [col for col in required_columns if col not in new_df.columns]
		if missing:
			raise HTTPException(
				status_code=400,
				detail=f"Uploaded CSV is missing required columns: {missing}",
			)

		base_df = _load_base_dataset()
		combined_df = pd.concat([base_df, new_df[required_columns]], ignore_index=True)
		return _retrain_and_save(combined_df)
	except HTTPException:
		raise
	except Exception as exc:
		raise HTTPException(status_code=500, detail=f"CSV retraining failed: {exc}") from exc


if __name__ == "__main__":
	import uvicorn

	host = os.getenv("HOST", "0.0.0.0")
	port = int(os.getenv("PORT", "8000"))
	print(f"Open Swagger UI locally: http://127.0.0.1:{port}/docs")
	uvicorn.run(app, host=host, port=port)

