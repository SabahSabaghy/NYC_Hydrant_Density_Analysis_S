-- =============================================================================
-- NYC Hydrant Density Analysis. analysis.sql
-- Portfolio Project 2, Modern GIS Accelerator
--
-- Five progressive PostGIS queries that build up to a normalized density
-- analysis and a 100-meter coverage analysis.
--
-- Assumes:
--   - Database "nyc" with PostGIS extension enabled
--   - Tables loaded:
--       nyc_neighborhoods (polygon, EPSG:4326, geom column called "geom",
--                          attributes including "neighborhood" and "borough")
--       nyc_hydrants      (point,   EPSG:4326, geom column called "geom",
--                          attributes including "hydrant_id")
--   - Spatial indexes on both geom columns (CREATE INDEX ... USING GIST (geom))
--
-- Run all queries:
--   psql -h localhost -U gisuser -d nyc -f analysis.sql
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Query 1: Filter
--
-- Goal: Sanity check that the data loaded. Pull all neighborhoods in Manhattan.
-- Expected output: ~37 rows (Manhattan neighborhoods).
-- -----------------------------------------------------------------------------

SELECT ntaname, boroname
FROM "Spatial_lab".nyc_neighborhoods
WHERE boroname = 'Manhattan'
ORDER BY ntaname;


-- -----------------------------------------------------------------------------
-- Query 2: Spatial join
--
-- Goal: Match each hydrant to the neighborhood that contains it, using
-- ST_Contains.
-- Expected output: one row per hydrant (~109,725) with the neighborhood name.
-- -----------------------------------------------------------------------------

SELECT
    h.id,
    n.ntaname,
    n.boroname
FROM "Spatial_lab".nyc_hydrants h
JOIN "Spatial_lab".nyc_neighborhoods n
    ON ST_Contains(n.geom, h.geom)
LIMIT 10;


-- -----------------------------------------------------------------------------
-- Query 3: Aggregate
--
-- Goal: Count hydrants per neighborhood.
-- Expected output: 262 rows (one per neighborhood) with a hydrant_count.
-- -----------------------------------------------------------------------------

SELECT
    n.ntaname,
    n.boroname,
    COUNT(h.*) AS hydrant_count
FROM "Spatial_lab".nyc_hydrants h
JOIN "Spatial_lab".nyc_neighborhoods n
    ON ST_Contains(n.geom, h.geom)
GROUP BY
    n.ntaname,
    n.boroname
ORDER BY hydrant_count DESC;


-- -----------------------------------------------------------------------------
-- Query 4: Normalize (this is your headline result)
--
-- Goal: Compute density per square kilometer. Reproject to EPSG:2263
-- (NY State Plane Long Island, feet) before computing area, then convert
-- square feet to square kilometers.
-- Expected output: 262 rows with hydrant_count, area_km2, density_per_km2.
-- -----------------------------------------------------------------------------

WITH neighborhood_stats AS (
    SELECT
        n.ntaname,
        n.boroname,
        COUNT(h.*) AS hydrant_count,
        ST_Area(ST_Transform(n.geom, 2263)) / 10763910.42 AS area_km2
    FROM "Spatial_lab".nyc_hydrants h
    JOIN "Spatial_lab".nyc_neighborhoods n
        ON ST_Contains(n.geom, h.geom)
    GROUP BY
        n.ntaname,
        n.boroname,
        n.geom
)

SELECT
    ntaname,
    boroname,
    hydrant_count,
    ROUND(area_km2::numeric, 2) AS area_km2,
    ROUND((hydrant_count / area_km2)::numeric, 2) AS density_per_km2
FROM neighborhood_stats
ORDER BY density_per_km2 DESC;

-- -----------------------------------------------------------------------------
-- Query 5: Buffer + Union + Intersection (coverage analysis)
--
-- Goal: For each neighborhood, what percent of its area is within 100 meters
-- of a hydrant? This is the deeper finding.
-- Expected output: 262 rows with neighborhood, area_km2, covered_pct.
-- -----------------------------------------------------------------------------

WITH hydrant_coverage AS (
    SELECT
        ST_Union(
            ST_Buffer(
                ST_Transform(geom, 2263),
                328.084 -- 100 m converted to feet
            )
        ) AS coverage_geom
    FROM "Spatial_lab".nyc_hydrants
)


SELECT
    n.ntaname,
    n.boroname,

    ROUND(
        (
            ST_Area(ST_Transform(n.geom, 2263))
            / 10763910.42 
        )::numeric,
        2
    ) AS area_km2,

    ROUND(
        (
            100.0 *
            ST_Area(
                ST_Intersection(
                    ST_Transform(n.geom, 2263),
                    hc.coverage_geom
                )
            )
            /
            ST_Area(ST_Transform(n.geom, 2263))
        )::numeric,
        2
    ) AS covered_pct

FROM "Spatial_lab".nyc_neighborhoods n
CROSS JOIN hydrant_coverage hc

ORDER BY covered_pct DESC;


-- -----------------------------------------------------------------------------
-- Query 6: Median Hydrant Density
--
-- Goal: Calculate the median number of hydrants per square kilometre across
-- all NYC neighbourhoods. Hydrant density is calculated by counting hydrants
-- within each neighbourhood and normalising by neighbourhood area.
--
-- Expected output: One row with median_density_per_km2.
-- -----------------------------------------------------------------------------

WITH density_stats AS (
    SELECT
        n.ntaname,
        COUNT(h.*) AS hydrant_count,
        ST_Area(ST_Transform(n.geom, 2263)) / 10763910.42 AS area_km2,
        COUNT(h.*) /
        (ST_Area(ST_Transform(n.geom, 2263)) / 10763910.42)
        AS density_per_km2
    FROM "Spatial_lab".nyc_hydrants h
    JOIN "Spatial_lab".nyc_neighborhoods n
        ON ST_Contains(n.geom, h.geom)
    GROUP BY n.ntaname, n.geom
)

SELECT
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY density_per_km2)::numeric,
        2
    ) AS median_density_per_km2
FROM density_stats;


-- -----------------------------------------------------------------------------
-- Query 7: Average Hydrant Coverage
--
-- Goal: Calculate the average percentage of neighbourhood area located within
-- 100 metres of a hydrant across all NYC neighbourhoods. This provides a
-- city-wide summary of hydrant accessibility and complements the
-- neighbourhood-level coverage analysis in Query 5.
--
-- Method:
--   1. Create a 100 m buffer around each hydrant. Since EPSG:2263 uses
--      US survey feet, 100 metres is converted to 328.084 feet.
--   2. Merge all hydrant buffers into a single coverage geometry using
--      ST_Union().
--   3. For each neighbourhood, calculate the proportion of its area that
--      overlaps the hydrant coverage geometry.
--   4. Compute the average coverage percentage across all neighbourhoods.
--
-- Expected output: One row containing avg_coverage_pct.
-- -----------------------------------------------------------------------------

WITH hydrant_coverage AS (
    SELECT
        ST_Union(
            ST_Buffer(
                ST_Transform(geom, 2263),
                328.084
            )
        ) AS coverage_geom
    FROM "Spatial_lab".nyc_hydrants
),

coverage_stats AS (
    SELECT
        n.ntaname,

        100.0 *
        ST_Area(
            ST_Intersection(
                ST_Transform(n.geom, 2263),
                hc.coverage_geom
            )
        )
        /
        ST_Area(ST_Transform(n.geom, 2263))
        AS covered_pct

    FROM "Spatial_lab".nyc_neighborhoods n
    CROSS JOIN hydrant_coverage hc
)

SELECT
    ROUND(AVG(covered_pct)::numeric, 2) AS avg_coverage_pct
FROM coverage_stats;

-- =============================================================================
-- Notes for your README
--
-- - Query 1 is your sanity check. Don't skip it.
-- - Query 4 is your headline. Identify the top 5 and bottom 5 neighborhoods.
-- - Query 5 is the deeper insight. Look at the median covered_pct. That number
--   is your case-study finding.
-- =============================================================================
