# 05. Metrics and measures

Definitions of the reliability indices and the calculation behind each figure on the report. DAX for all measures is in `powerbi/measures.dax`.

## Reliability indices

Each index is derived from two annual totals reported by the utility, customer-interruptions and customer-minutes of interruption, divided by customers served.

| Index | Name used on the report | Formula | Unit | Measures |
|---|---|---|---|---|
| SAIFI | Outages per customer | customer-interruptions / customers | interruptions per customer per year | Frequency of interruption |
| SAIDI | Outage minutes per customer | customer-minutes / customers | minutes per customer per year | Total interruption time per customer |
| CAIDI | Minutes to restore each outage | SAIDI / SAIFI | minutes per interruption | Average duration of an interruption |

SAIDI = SAIFI x CAIDI by definition (test T2 checks the identity in the data). A change in SAIDI therefore decomposes into a frequency component and a duration component:

ln(SAIDI2 / SAIDI1) = ln(SAIFI2 / SAIFI1) + ln(CAIDI2 / CAIDI1)

The share of a SAIDI change attributable to frequency is ln(SAIFI ratio) / ln(SAIDI ratio). This is `V_TREND.frequency_share_of_change` and the `Frequency share` measures.

## Major event days

Each index is reported in two forms:

- All events.
- Excluding major event days (ex-MED): days classified as major events are removed. Regulatory reporting and the annual report use this form.

IEEE Standard 1366 defines a major event day statistically (a day whose SAIDI exceeds a threshold derived from the previous five years, the 2.5 beta method). Dominion, Alabama Power and some other utilities apply their own definition and file under EIA's "Other" standard. The report shows the method beside each peer figure.

Storm share = (SAIDI all - SAIDI ex-MED) / SAIDI all. For Dominion in 2025: (306.7 - 144.4) / 306.7 = 53%.

## Aggregation rule

Ratios are not averaged. Numerators and denominators are summed separately and divided once.

| Not used | Used |
|---|---|
| `AVERAGE(saidi_ex_med)` across utilities | `SUM(cust_minutes_ex_med) / SUM(customers)` |
| `AVERAGE(saidi_ex_med)` across years for one utility | `AVERAGEX(VALUES(year), [SAIDI ex MED])`: the customer-weighted value for each year, then the mean of the years |

## Report figures

### Scorecard

| Card | Value | Measure | Calculation |
|---|---|---|---|
| Outage minutes per customer, 3-year average 2023 to 2025 | 133.0 | `SAIDI 3yr ending 2025` | Customer-weighted SAIDI ex-MED for each of 2023, 2024, 2025, then the mean. Annual report page 10: 133 |
| 3-year average 2022 to 2024 | 130.2 | `SAIDI 3yr ending 2024` | Same for 2022 to 2024. Report: 130 |
| Customers served, 2025 | 2,675,735 | `Total Customers` filtered to 2025 | EIA `oth_customers`. Virginia only. The annual report's 2,809k includes North Carolina |
| Outages per customer, 2025 | 1.32 | `SAIFI ex MED` | 2025 row |
| Minutes to restore each outage, 2025 | 109.4 | `CAIDI ex MED` | SAIDI / SAIFI |
| Including major storms, 2025 | 306.7 | `SAIDI all events` | 2025 row |
| Storm share, 2025 | 53% | `Storm share` | (306.7 - 144.4) / 306.7 |

### What moved

| Figure | Value | Calculation |
|---|---|---|
| SAIFI 2019 -> 2025 | 1.24 -> 1.32, about +6% | `SAIFI change 2019 to 2025` |
| CAIDI 2019 -> 2025 | 120.5 -> 109.4, -9% | `CAIDI change 2019 to 2025` |
| SAIDI 2019 -> 2023 | -17.7%, 34% of it from frequency, 66% from duration | `SAIDI change 2019 to 2023`, `Frequency share 2019 to 2023` |
| SAIDI 2023 -> 2025 | +17.1%, 79% from frequency | same pair for 2023 to 2025 |
| Dashed lines at 2015 and 2020 | | 2015: outages recorded automatically from this year. 2020: lines up to 46 kV included from this year. Both are changes in what is counted |

### Weather

| Figure | Value | Calculation |
|---|---|---|
| Storm county-days, 2025 | 796 | `STORM_INDEX`. Second-highest in the record; 2019 was 851 |
| Correlation, storm days vs SAIDI ex-MED, 2015 to 2024 | 0.70 | `CORR()` in `05_noaa_storms.sql` Q6b. With SAIFI: 0.41. With major-storm minutes: 0.47 |
| Predicted from weather, 2025 | 145.3 | `REGR_INTERCEPT + REGR_SLOPE x 796`, fitted 2015 to 2024 |
| Actual 2025 | 144.4 | EIA |
| Weather-adjusted SAIDI | 2015: 122, 2019: 136, 2025: 133 | actual - predicted + mean(2015 to 2024) |
| Ten-year average line | 134 | mean of actual SAIDI ex-MED, 2015 to 2024 |
| Co-op index 2025 | 137 | all Virginia co-ops, customer-weighted SAIFI ex-MED, / 2015 value x 100 |
| Dominion index 2025 | 114 | same for Dominion VA |

### Fair comparison

| Figure | Calculation |
|---|---|
| Minutes 2015 to 17, Minutes 2023 to 25 | `SAIDI 2015 to 2017`, `SAIDI 2023 to 2025`: three-year customer-weighted averages per utility |
| Change | Minutes 2023 to 25 / Minutes 2015 to 17 - 1 |
| Outages per customer 2021 to 25, Minutes per outage 2021 to 25 | `SAIFI 5yr`, `CAIDI 5yr`: five-year averages |
| Quadrant lines | medians of the twelve peers: SAIFI 0.96, CAIDI 105 |
| Major-storm rule | `IEEE 1366`, `Own rule` (EIA "Other"), `Changed` (filed under both across years) |

### Growth

| Figure | Value | Calculation |
|---|---|---|
| Base load, 2019 to 2025 | +52% | min hour of 2025 (10,903 MW) / min hour of 2019 (7,167) - 1 |
| Peak load, 2019 to 2025 | +26% | max hour 24,957 / 19,803 - 1 |
| Top-50 load hours in 2025 | 47 | `DOM_TOP50_HOURS` where `rank_end_2025 <= 50` and year = 2025 |
| Growth by hour of day | 4am +41%, 4pm +27% | `DOM_LOAD_PROFILE`: mean MW in that hour, 2025 / 2019 - 1 |
| Winter and summer peaks | 2025: 24,957 (23 Jan, 8am) vs 23,905 | `DOM_LOAD_ANNUAL` |
| Commercial sales index 2025 | 165 (2013 = 100) | `STG.SALES`, Dominion VA, commercial class, `sales_mwh` / 2013 value |
| Commercial customers index | 108 | same with `customers` |
| Smart meters installed | 100% | `STG.AMI`, `ami_share` |
| On a time-varying rate | about 1% | EIA-861 Dynamic Pricing, time-based rate customers / customers |

## Measure naming

Measures use the metric name (`SAIDI ex MED`, `CAIDI 5yr`). Plain-language names are used in visual titles. Columns keep their Snowflake names, so each card can be traced to a column in `docs/02_data_dictionary.md`.

Formatting measures (`Bar colour`, `Dot colour`, `Row colour`, `SAIFI label`, `CAIDI label`, `Index label`, `Adjusted label`, `Hour colour`, `Change colour`) return colour strings or conditional labels and are listed at the end of `powerbi/measures.dax`.
