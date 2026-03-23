# Maths_for_ML_Summative

## Mission
My mission is to build a climate-focused machine learning solution that estimates vehicle CO2 emissions from fuel consumption and engine-related features.
The goal is to support better awareness of how vehicle characteristics affect carbon emissions.
This project helps identify emission patterns that can inform cleaner transport choices.

## Description and Source of Data
This project uses the FuelConsumptionCo2 dataset, which contains fuel consumption ratings and estimated carbon dioxide emissions for new light-duty vehicles sold in Canada. The dataset includes features such as engine size, cylinders, fuel type, and fuel consumption measures, with CO2 emissions as the prediction target.

Source: Government of Canada open data, provided in the IBM Machine Learning course lab dataset:
http://open.canada.ca/data/en/dataset/98f1a129-f628-4ce4-b24d-6f16bf24dd64

## API Endpoint
The CO2 emission prediction model is deployed as a RESTful API. You can test predictions using the Swagger UI:

**Public API Endpoint:** [https://linear-regression-summative-9xn9.onrender.com/docs](https://linear-regression-summative-9xn9.onrender.com/docs)

To make predictions, provide the following input features:
- Engine Size (L)
- Cylinders
- Fuel Consumption City (L/100km)
- Fuel Consumption Highway (L/100km)
- Fuel Consumption Combined (L/100km)
- Fuel Consumption Combined MPG

## Demo Video
Click on the following link to Watch the demo-video of the project:

**Video Demo:** [Demostartion video](https://drive.google.com/file/d/1iciAOdewETPMWfhFBSwwW1SohdPRgZGk/view?usp=sharing)

## Running the Mobile App

### Prerequisites
- Flutter SDK installed ([https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install))
- Android Studio/Xcode for emulator or physical device

### Steps to Run

1. **Start the API server locally:**
   ```bash
   python .\API\prediction.py
   ```
   The API server will start on `http://localhost:8000`. You can access the Swagger UI at `http://localhost:8000/docs`.

2. **Navigate to the Flutter app directory:**
   ```bash
   cd summative/flutter_app
   ```

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

5. **On Chrome (Web):**
   ```bash
   flutter run -d chrome
   ```

### Features
- Input 6 vehicle characteristics
- Get real-time CO2 emission predictions from the deployed API
- View validation feedback for out-of-range inputs
- Responsive UI with gradient design for optimal user experience

### Supported Platforms
- Android
- iOS
- Web (Chrome)

## AUthor
Gaddiel Irakoze