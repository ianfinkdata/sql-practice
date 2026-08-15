# Demographic & Geographic Analysis Template (North American Footprint)

This template provides a standardized Power BI Enhanced Report (PBIR) page layout for customer demographic segmentation and geographic footprint analysis across **North America (United States, Canada, and Mexico)**.

---

## 🗺️ 1. North American Geographic Hierarchy

The visuals in this template are structured around a unified North American geographic hierarchy:

```
North America (NA)
├── 🇺🇸 United States (USA / US)
│   └── 50 States + District of Columbia (AL, AK, AZ ... WY, DC)
├── 🇨🇦 Canada (CAN / CA)
│   └── 10 Provinces + 3 Territories (ON, QC, BC, AB, MB, SK, NS, NB, NL, PE, NT, YT, NU)
└── 🇲🇽 Mexico (MEX / MX)
    └── 31 States + Mexico City (CDMX, JAL, NL, MEX, PUE, GUA ...)
```

---

## 📊 2. Included Visual Containers

1. **`customer_segment_donut.json`**:
   - Donut chart displaying revenue and customer share by segment (`Retail`, `Wholesale`, `VIP`).
2. **`na_country_revenue_bar.json`**:
   - Clustered bar chart comparing top-line revenue and order count across `USA`, `Canada`, and `Mexico`.
3. **`na_state_province_table.json`**:
   - High-density tabular drilldown reporting `State/Province`, `Country`, `Customer Count`, and `Net Revenue ($)`.
4. **`azure_map_placeholder.json`**:
   - Pre-configured map container wired to `Country` and `State/Province` location fields with `Net Sales ($)` sizing.

---

## 🛠️ 3. How to Activate Azure Maps or Standard Maps

Because Azure Maps visual availability depends on Power BI tenant settings and administrator policies, this template ships with a **safe, non-breaking fallback configuration**.

### Activating Azure Maps (Desktop / Service)
1. In Power BI Desktop, navigate to **File > Options and settings > Options > Security**.
2. Ensure **"Use Azure Maps visual"** is checked.
3. If your Power BI tenant policy permits Azure Maps, select the map container (`azure_map_placeholder.json`) on the report canvas.
4. In the **Visualizations** pane, click the **Azure Map** icon (or change `"visualType": "azureMap"` in `visual.json`).
5. Confirm that `Country` and `State/Province` are mapped to the **Location** field well and `Net Sales` is mapped to **Size**.

### Alternative Fallback: Standard Shape Map / Filled Map
If Azure Maps is restricted in your environment:
1. In the Visualizations pane, click the **Shape Map** or **Filled Map** icon.
2. Under Visual Settings > Map settings, select standard North American projection maps (e.g. US States, Canadian Provinces, or Mexico States).
3. The underlying data model bindings (`dim_customer.state`, `Country`, `net_amount`) require zero modifications.
