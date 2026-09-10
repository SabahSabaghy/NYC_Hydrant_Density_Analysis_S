# NYC Hydrant Density Analysis

This project demonstrates a complete spatial analysis workflow in PostgreSQL/PostGIS using New York City fire hydrant and neighbourhood datasets.

The analysis progresses from basic data validation and spatial joins through to advanced geospatial analytics, including:

- Attribute filtering
- Point-in-polygon spatial joins
- Spatial aggregation
- Density normalisation by area
- Buffer and coverage analysis
- Median hydrant density calculation
- City-wide hydrant accessibility metrics

The workflow uses PostGIS spatial functions such as:

- ST_Contains
- ST_Transform
- ST_Area
- ST_Buffer
- ST_Union
- ST_Intersection

Key Outputs
- Hydrant counts for every NYC neighbourhood
- Hydrant density per km²
- Top and bottom ranked neighbourhoods by hydrant density
- Percentage of neighbourhood area within 100 m of a hydrant
- Median hydrant density across NYC
- Average hydrant coverage across NYC neighbourhoods


## The question

Where is hydrant coverage densest in NYC, and which neighborhoods are underserved relative to their area?

## The data

- **NYC Neighborhoods.** 262 polygons (Source: [NYC Open Data](https://opendata.cityofnewyork.us))
- **NYC Fire Hydrants.** 109,725 points (Source: [NYC Open Data](https://opendata.cityofnewyork.us))
- License: NYC Open Data Terms of Use
- All data in EPSG:4326

## Methodology

Built the same analysis twice:

- **SQL (PostGIS).** Five progressive queries in `analysis.sql`, going from simple filter to spatial join to area-normalized density to 100m-buffer coverage analysis.
- **Python (GeoPandas).** Equivalent pipeline in `analysis.ipynb`, with a static choropleth and interactive `.explore()` map. Final output exported to GeoParquet.

Both pipelines produce the same density values to within rounding. The Python version produces the visualization. The SQL version runs against a database at scale.

## Findings

- Top 5 neighborhoods by hydrant density (per km²):

Hydrant density was calculated by dividing the number of hydrants within each neighbourhood by the neighbourhood area (km²). Areas were calculated in EPSG:2263 and converted from square feet to square kilometres.

| Neighbourhood | Borough | Hydrant Count | Area (km²) | Density (Hydrants/km²) |
|--------------|----------|--------------:|-----------:|-----------------------:|
| Gramercy | Manhattan | 269 | 0.70 | 384.73 |
| SoHo-Little Italy-Hudson Square | Manhattan | 432 | 1.20 | 360.00 |
| Tribeca-Civic Center | Manhattan | 433 | 1.26 | 343.25 |
| West Village | Manhattan | 447 | 1.34 | 333.74 |
| Financial District-Battery Park City | Manhattan | 570 | 1.79 | 319.11 |
  
- Bottom 5 neighborhoods (least coverage):

The lowest hydrant densities were observed in large open-space and specialised land-use areas, including parks, recreational reserves, military facilities, and airport infrastructure. These locations typically contain fewer roads and buildings than residential or commercial neighbourhoods, resulting in a lower concentration of fire hydrants.

| Neighbourhood | Borough | Hydrant Count | Area (km²) | Density (Hydrants/km²) |
|--------------|----------|--------------:|-----------:|-----------------------:|
| Fort Wadsworth | Staten Island | 1 | 0.92 | 1.09 |
| Shirley Chisholm State Park | Brooklyn | 2 | 1.70 | 1.18 |
| Rockaway Community Park | Queens | 1 | 0.83 | 1.21 |
| John F. Kennedy International Airport | Queens | 36 | 18.32 | 1.97 |
| McGuire Fields | Brooklyn | 2 | 0.98 | 2.03 |

### Key Findings

The lowest hydrant densities were concentrated in areas dominated by open space or specialised infrastructure rather than dense urban development. Fort Wadsworth, Shirley Chisholm State Park, and Rockaway Community Park each contained only one or two hydrants across relatively large areas, resulting in densities close to 1 hydrant per km².

John F. Kennedy International Airport presents an interesting case. Although it contains 36 hydrants, its large geographic extent (18.32 km²) results in a density of only 1.97 hydrants per km². This highlights the importance of normalising counts by area, as raw hydrant totals alone can be misleading when comparing neighbourhoods of different sizes.

Comparing the highest- and lowest-density neighbourhoods revealed more than a two-order-of-magnitude difference in hydrant density. For example, Gramercy recorded 384.73 hydrants/km², while Fort Wadsworth recorded only 1.09 hydrants/km². This pattern reflects the contrast between dense urban environments in Manhattan and large open-space or infrastructure-dominated areas in the outer boroughs.  

- Median neighborhood has 166.57 hydrants per km².
- 79.45% of every neighborhood is within 100m of a hydrant.

![NYC hydrant density choropleth](https://github.com/SabahSabaghy/hydrant_coverage_NYC/blob/main/Figures/density_choropleth.png)

## How to run it

#Ensure PostgreSQL and PostGIS are installed and running locally + Python 3.11+ with GeoPandas.

```bash
git clone https://github.com/{your-username}/nyc-hydrant-analysis.git
cd nyc-hydrant-analysis


# Create the database (if required)
createdb nyc
psql -d nyc -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# Load NYC Open Data into PostGIS (your script of choice)
# Then run the SQL pipeline
psql -h localhost -U gisuser -d nyc -f analysis.sql

# Then the Python pipeline
jupyter lab analysis.ipynb
```

## What I learned

Reproducing the workflow in both PostGIS and Python reinforced my understanding that the same GIS principles apply across different technologies, while highlighting the strengths of each approach. The most challenging step was implementing the 100 m coverage analysis in GeoPandas, which required careful management of spatial indexes, dataframe relationships, and polygon intersections compared to the more streamlined PostGIS workflow. If I were to do the project again, I would build a fully parameterised and reusable pipeline from the start and add automated validation checks to compare Python and PostGIS outputs throughout the analysis.

## Stack

- PostgreSQL 16+ with PostGIS enabled
- GeoPandas + SQLAlchemy + matplotlib
- Jupyter Lab
- GeoParquet
