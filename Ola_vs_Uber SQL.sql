/*******************************************************************************
  PROJECT: Ola vs Uber Data Analysis
  AUTHOR: Ananya Kastiya
  DATABASE ENGINE: MySQL Workbench 8.0
  THEME: Ride Fare Optimization & Surge Price Analysis
*******************************************************************************/

-- ==========================================
-- STEP 1: DATABASE & TABLE INFRASTRUCTURE
-- ==========================================

CREATE DATABASE IF NOT EXISTS transportation_analytics;
USE transportation_analytics;

DROP TABLE IF EXISTS rides_data;

CREATE TABLE rides_data (
    Booking_Date DATE,
    Booking_Time TIME,
    Booking_ID VARCHAR(50) PRIMARY KEY,
    Booking_Status VARCHAR(50),
    Customer_ID VARCHAR(50),
    Vehicle_Type VARCHAR(50),
    Pickup_Location VARCHAR(100),
    Drop_Location VARCHAR(100),
    Avg_VTAT DECIMAL(5,2) NULL,         
    Avg_CTAT DECIMAL(5,2) NULL,         
    Booking_Value DECIMAL(10,2) NULL,   
    Payment_Method VARCHAR(50) NULL,
    Ride_Distance DECIMAL(5,2) NULL,    
    Driver_Ratings DECIMAL(3,1) NULL,   
    Customer_Rating DECIMAL(3,1) NULL,  
    Company VARCHAR(30),
    Ride_outcome VARCHAR(50),
    Hour INT,
    Time_bucket VARCHAR(50),
    Day_of_Week VARCHAR(50),
    Day_Type VARCHAR(50),
    Vehicle_Category VARCHAR(50),
    Fare_per_KM DECIMAL(10,2) NULL     
);

-- ==========================================
-- STEP 2: HIGH-SPEED DATA PIPELINE IMPORT
-- ==========================================

TRUNCATE TABLE rides_data;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Total_Data_Ola&Uber.csv' 
IGNORE INTO TABLE rides_data
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
 Booking_Date, 
 Booking_Time, 
 Booking_ID, 
 Booking_Status, 
 Customer_ID, 
 Vehicle_Type, 
 Pickup_Location, 
 Drop_Location, 
 @vAvg_VTAT, 
 @vAvg_CTAT, 
 @vBooking_Value, 
 @vPayment_Method, 
 @vRide_Distance, 
 @vDriver_Ratings, 
 @vCustomer_Rating, 
 Company, 
 Ride_outcome, 
 Hour, 
 Time_bucket, 
 Day_of_Week, 
 Day_Type, 
 Vehicle_Category, 
 @vFare_per_KM
)
SET 
    Avg_VTAT = IF(@vAvg_VTAT = '', NULL, @vAvg_VTAT),
    Avg_CTAT = IF(@vAvg_CTAT = '', NULL, @vAvg_CTAT),
    Booking_Value = IF(@vBooking_Value = '', NULL, @vBooking_Value),
    Payment_Method = IF(@vPayment_Method = '', NULL, @vPayment_Method),
    Ride_Distance = IF(@vRide_Distance = '', NULL, @vRide_Distance),
    Driver_Ratings = IF(@vDriver_Ratings = '', NULL, @vDriver_Ratings),
    Customer_Rating = IF(@vCustomer_Rating = '', NULL, @vCustomer_Rating),
    Fare_per_KM = IF(@vFare_per_KM = '', NULL, @vFare_per_KM);


-- ==========================================
-- STEP 3: MASTER OPERATIONAL QUERIES
-- ==========================================

-- -----------------------------------------------------------------------------
-- PILLAR A: FUNNEL CONVERSION & ATTRITION RATES
-- -----------------------------------------------------------------------------

-- Q1: Overall Funnel Success Rate — What percentage of total bookings end up as completed rides?
-- Problem Solved: Benchmarks baseline fulfillment capability relative to each app's incoming demand volume.
SELECT 
    Company,
    ROUND((SUM(CASE WHEN Ride_outcome = 'Success' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS Fulfillment_Success_Rate_Pct,
    ROUND((SUM(CASE WHEN Ride_outcome = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS Attrition_Cancellation_Rate_Pct,
    ROUND((SUM(CASE WHEN Ride_outcome = 'Incomplete' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS Incomplete_Ride_Rate_Pct
FROM rides_data 
GROUP BY Company;


-- Q2: Internal Cancellation Accountability Share — Of the cancelled sessions, who drops the ride?
-- Problem Solved: Scales accountability internal to each brand's ecosystem, revealing whether drivers or customers drive cancellations.
SELECT 
    Company, 
    Booking_Status,
    ROUND((COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY Company)) * 100, 2) AS Internal_Cancellation_Share_Pct
FROM rides_data 
WHERE Ride_outcome = 'Cancelled'
GROUP BY Company, Booking_Status 
ORDER BY Company, Internal_Cancellation_Share_Pct DESC;


-- Q3: Hourly Conversion Volatility — Which operational hours suffer the lowest ride success rates?
-- Problem Solved: Maps the temporal capacity resilience of both platforms to find identical supply crunches.
SELECT 
    Company, 
    Time_bucket, 
    ROUND((SUM(CASE WHEN Ride_outcome = 'Success' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS Success_Rate_Pct
FROM rides_data 
GROUP BY Company, Time_bucket
ORDER BY Company, Success_Rate_Pct ASC;


-- Q4: Weekend Supply Elasticity — Does fulfillment change between working weekdays and leisure weekends?
-- Problem Solved: Tests if weekend driver churn drops overall completion rates compared to weekday baselines.
SELECT 
    Company, 
    Day_Type,
    ROUND((SUM(CASE WHEN Ride_outcome = 'Success' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS Conversion_Rate_Pct
FROM rides_data 
GROUP BY Company, Day_Type 
ORDER BY Company, Day_Type;


-- -----------------------------------------------------------------------------
-- PILLAR B: FLEET SPEED & ALLOCATION LAGS
-- -----------------------------------------------------------------------------

-- Q5: Algorithmic Allocation Velocity (VTAT) — How long does the engine take to match a driver?
-- Problem Solved: Measures core database geometric pairing speeds across competing vehicle classes.
SELECT 
    Company, 
    Vehicle_Category, 
    ROUND(AVG(Avg_VTAT), 2) AS Avg_Driver_Match_Minutes
FROM rides_data 
WHERE Ride_outcome = 'Success' 
GROUP BY Company, Vehicle_Category
ORDER BY Vehicle_Category, Company;


-- Q6: Physical Pickup Delay Latency (CTAT) — How long must customers wait until wheels arrive?
-- Problem Solved: Measures actual dispatch efficiency. High CTAT exposes long travel delays or distant fleet distribution.
SELECT 
    Company, 
    Vehicle_Category, 
    ROUND(AVG(Avg_CTAT), 2) AS Avg_Customer_Pickup_Delay_Minutes
FROM rides_data 
WHERE Ride_outcome = 'Success' 
GROUP BY Company, Vehicle_Category
ORDER BY Vehicle_Category, Company;


-- Q7: En-Route Disparity Index — What is the average transit lag gap between driver matching and arrival?
-- Problem Solved: Evaluates real-world routing lag (CTAT - VTAT) to uncover system tracking gaps or fleet layout flaws.
SELECT 
    Company, 
    ROUND(AVG(Avg_CTAT - Avg_VTAT), 2) AS Mean_En_Route_Arrival_Lag_Min
FROM rides_data 
WHERE Ride_outcome = 'Success' 
GROUP BY Company;


-- Q8: Temporal Speed Strain — How do pickup delays fluctuate across specific shifts?
-- Problem Solved: Identifies what periods (e.g., Night, Morning Rush) suffer from severe vehicle pickup delays on both networks.
SELECT 
    Company, 
    Time_bucket, 
    ROUND(AVG(Avg_CTAT), 2) AS Shift_Wait_Time_Min
FROM rides_data 
WHERE Ride_outcome = 'Success' 
GROUP BY Company, Time_bucket
ORDER BY Company, Shift_Wait_Time_Min DESC;


-- -----------------------------------------------------------------------------
-- PILLAR C: PRICING ECONOMICS & ASSET MONETIZATION
-- -----------------------------------------------------------------------------

-- Q9: Average Ticket Value Structure (AOV) — What is the mean ticket size for completed trips?
-- Problem Solved: Shows single-user monetization without being swayed by total raw market scale.
SELECT 
    Company, 
    Vehicle_Category, 
    ROUND(AVG(Booking_Value), 2) AS Average_Order_Value
FROM rides_data 
WHERE Ride_outcome = 'Success' 
GROUP BY Company, Vehicle_Category
ORDER BY Vehicle_Category, Company;


-- Q10: Distance Profile Calibration — What is the mean distance covered per single successful booking?
-- Problem Solved: Evaluates core ride properties—are users selecting a specific brand for short trips vs long hauls?
SELECT 
    Company, 
    ROUND(AVG(Ride_Distance), 2) AS Avg_Completed_Distance_KM
FROM rides_data 
WHERE Ride_outcome = 'Success' 
GROUP BY Company;


-- Q11: Revenue Realization Yield — How much monetary value is extracted per physical kilometer driven?
-- Problem Solved: Measures financial return rates per unit of distance to track vehicle optimization.
SELECT 
    Company, 
    ROUND(AVG(Booking_Value / NULLIF(Ride_Distance, 0)), 2) AS Financial_Yield_Per_KM
FROM rides_data 
WHERE Ride_outcome = 'Success' 
GROUP BY Company;


-- Q12: Dynamic Pricing Volatility (Variance) — How erratic are the pricing algorithms?
-- Problem Solved: Measures the intensity of surge swings. High variance proves unpredictable pricing rules.
SELECT 
    Company, 
    ROUND(VARIANCE(Fare_per_KM), 2) AS Pricing_Volatility_Variance
FROM rides_data 
WHERE Ride_outcome = 'Success' 
GROUP BY Company;


-- -----------------------------------------------------------------------------
-- PILLAR D: CONSUMER PROFILE & RETENTION METRICS
-- -----------------------------------------------------------------------------

-- Q13: Checkout Digital Footprint — What are the digital vs cash settlement distribution styles?
-- Problem Solved: Measures ecosystem financial preferences by analyzing share of payment methods within completed rides.
SELECT 
    Company, 
    Payment_Method,
    ROUND((COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY Company)) * 100, 2) AS Checkout_Preference_Pct
FROM rides_data 
WHERE Ride_outcome = 'Success'
GROUP BY Company, Payment_Method;


-- Q14: Experience Sentiment Scores — What are the cross-tier customer and driver feedback ratings?
-- Problem Solved: Compares user experiences across different car categories to flag qualitative drops.
SELECT 
    Company, 
    Vehicle_Category,
    ROUND(AVG(Customer_Rating), 2) AS Avg_Passenger_Rating,
    ROUND(AVG(Driver_Ratings), 2) AS Avg_Driver_Rating
FROM rides_data 
WHERE Ride_outcome = 'Success' 
GROUP BY Company, Vehicle_Category
ORDER BY Vehicle_Category, Company;


-- Q15: Inter-Vehicle Friction Scale — What is the direct feedback gap within the cabin?
-- Problem Solved: Measures psychological conflict between users. A large rating gap signals service quality tension.
SELECT 
    Company,
    ROUND(AVG(Customer_Rating - Driver_Ratings), 2) AS Mutual_Friction_Gap
FROM rides_data 
WHERE Ride_outcome = 'Success' 
GROUP BY Company;


-- Q16: Normalized Cohort Spend Tracking — What is the average commitment footprint per active rider?
-- Problem Solved: Evaluates real user retention and cumulative customer spend metrics safely scaled per rider.
SELECT 
    Company,
    ROUND(AVG(Rider_Volume), 1) AS Avg_Trips_Per_Customer,
    ROUND(AVG(Rider_Gross_Spend), 2) AS Avg_Lifetime_Value_Per_Customer
FROM (
    SELECT Customer_ID, Company, COUNT(*) AS Rider_Volume, SUM(Booking_Value) AS Rider_Gross_Spend
    FROM rides_data WHERE Ride_outcome = 'Success' GROUP BY Customer_ID, Company
) AS Cohort_Table 
GROUP BY Company;

/*******************************************************************************
                     END OF OPERATIONAL ENGINE SCRIPT
*******************************************************************************/