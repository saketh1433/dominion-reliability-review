# What the numbers mean

## The three basic reliability measures

| Measure | Plain-English meaning | Calculation |
| --- | --- | --- |
| **SAIDI** | Average outage minutes per customer | Total customer-outage minutes ÷ customers |
| **SAIFI** | Average number of interruptions per customer | Total customer-interruptions ÷ customers |
| **CAIDI** | Average duration per customer-interruption | Total customer-outage minutes ÷ customer-interruptions |

**SAIDI = SAIFI × CAIDI.** This is why I looked at frequency and duration separately rather than just reporting total outage minutes.

A *customer-interruption* counts every affected customer. One equipment failure can interrupt many customers.

## Key Dominion results

| Finding | Figure | What to know |
| --- | --- | --- |
| Three-year average SAIDI ending 2024 | **130.2 minutes** | Average of 2022, 2023 and 2024 |
| Three-year average SAIDI ending 2025 | **133.0 minutes** | Average of 2023, 2024 and 2025; a **rolling** comparison |
| 2025 annual SAIDI, excluding major event days | **144.4 minutes** | Different from the three-year figure |
| 2025 SAIFI, excluding major event days | **1.32** | Interruptions per customer |
| 2025 CAIDI, excluding major event days | **109.4 minutes** | Duration per customer-interruption |
| 2025 SAIDI, including all events | **306.7 minutes** | About 52.9% of these minutes fall in the difference between the all-event and ex-MED measures |

From **2023 to 2025**, SAIDI increased about **17%**, SAIFI about **13%**, and CAIDI about **3%**. The recent increase in outage minutes is therefore associated **more with interruption frequency** than duration.

The difference between the two EIA major-event measures is a **reporting classification**, not an independent measurement of NOAA storm-caused outages.

## Weather analysis

I matched NOAA storm reports to Dominion's 104 Virginia service-area counties and counted each county/date once if a relevant event occurred.

- **2024:** 465 storm county-days; **2025:** 796.
- Correlation with annual SAIDI, **2015–2024:** about **0.70** (R² about **0.48**).
- Simple regression: predicted SAIDI ≈ **104.4 + 0.0514 × annual storm county-days**.
- Using 2025's 796 county-days, predicted SAIDI was **145.3 minutes**, versus **144.4 actual**.

I also calculated an exploratory **weather-adjusted 2025 SAIDI of 133.1 minutes**, by subtracting the regression prediction from actual SAIDI and adding back the 2015–2024 mean. This is **not** an observed reliability measure or proof that weather caused the change. The model has only ten training years and leaves out maintenance, assets and other factors. Its historical prediction errors are materially larger than the unusually close 2025 result.

## Electricity demand

For the broader **PJM DOM subregion**, EIA-930 shows these changes between 2019 and 2025:

- Highest hourly demand: **19,803 → 24,957 MW** (**+26%**).
- Lowest hourly demand: **7,167 → 10,903 MW** (**+52%**).
- Average demand at around 4 AM rose about **41%**, versus about **27%** at 4 PM.

These figures describe the **shape of electricity demand**, not the cause of distribution outages.

The full calculation definitions are in [`sql/`](../sql/) and [`powerbi/measures.dax`](../powerbi/measures.dax).
