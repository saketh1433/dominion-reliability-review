# How a source file becomes a chart

I used SQL to make different files consistent before calculating the numbers shown in Power BI. The steps were:

**Original file → clean fields → match the right records → calculate an annual measure → show the result.**

Here are three examples from the actual data.

## Example 1: Dominion's annual outage minutes

EIA-861's 2025 record identifies Dominion Virginia as utility **19876**, with **2,675,735 customers** and **144.4 outage minutes per customer**, excluding major event days.

- The raw EIA record contains some numbers as text, such as `"2,675,735"`.
- SQL removes commas, converts the values to numbers, and keeps the right set of reliability fields.
- Historical EIA-861 records from PUDL (2013–2024) use a different layout. SQL puts them into the same format and **appends** 2025 using `UNION ALL`.
- Records are checked so each utility, state and year contributes once.

That gives one annual series. From it, the rolling three-year SAIDI average is:

- **2022–2024:** (136.047 + 123.322 + 131.300) / 3 = **130.2 minutes**.
- **2023–2025:** (123.322 + 131.300 + 144.400) / 3 = **133.0 minutes**.

This explains the headline increase in Dominion's reported three-year average.

## Example 2: NOAA storms versus outage minutes

NOAA may record several events in one county on the same day. For example, multiple thunderstorm-wind records from **Chesterfield County on July 18, 2025** all map to county code **51041**. Rather than counting each report as a separate bad-weather day, SQL counts **one county-day** for that date and county.

I used EIA service-territory data and an NWS zone-to-county lookup to restrict the weather data to Dominion's **104 Virginia counties and independent cities**. The annual results were **465 county-days in 2024** and **796 in 2025**.

Joining the annual storm counts to Dominion's annual SAIDI let me compare the two trends. A simple regression trained on **2015–2024** showed a correlation near **0.70** and predicted **145.3 minutes** for 2025, compared with **144.4 minutes** reported.

**Interpretation:** Stormier years were generally associated with higher SAIDI in the small training sample. The analysis does **not** establish causality or identify which assets were damaged.

## Example 3: Hourly demand becomes an annual trend

One EIA-930 record for the **PJM DOM subregion** shows **24,957 MW at the hour ending 8 AM on January 23, 2025**.

- SQL filters EIA-930's many regions to `PJM` and `DOM`.
- It converts the date and hourly demand to usable values and uses UTC to avoid repeated local clock times.
- Two clearly implausible readings over a billion MW are excluded from the cleaned calculation but kept for review.
- SQL calculates annual maximum, minimum and average demand.

The result: the highest hourly demand rose from **19,803 MW in 2019** to **24,957 MW in 2025** (+26%), while the lowest hourly demand rose from **7,167** to **10,903 MW** (+52%).

**Interpretation:** The region's load profile changed substantially. This is not direct evidence that load growth caused customer outages.

## Where the work happens

- [SQL data cleaning](../sql/01_raw_staging.sql) and [reliability calculations](../sql/02_mart.sql)
- [NOAA matching and storm counts](../sql/05_noaa_storms.sql)
- [EIA-930 hourly demand](../sql/06_eia930_demand.sql)
- [Weather regression](../sql/07_weather_adjusted_and_profile.sql)
- [Data-quality checks](03_data_quality.md)

The original data are available in [`data/`](../data/). The large raw NOAA and EIA-930 downloads are retrieved separately using scripts. The documentation is a guide to the calculations; the SQL contains the executable logic.
