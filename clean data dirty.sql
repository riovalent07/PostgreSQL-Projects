SELECT*
FROM dirty_shipments;


SELECT
	shipment_id,
	INITCAP(TRIM(origin_warehouse)) origin_warehouse,
	COALESCE(INITCAP(TRIM(destination_city)), 'unknown') destination_city,
	UPPER(TRIM(destination_state)) destination_state,
	INITCAP(TRIM(carrier)) carrier,
	INITCAP(TRIM(shipment_status)) shipment_status,
	COALESCE(delivery_date, 'Not Yet Delivered') destination_date,
	CASE
		WHEN damage_reported = 'NULL' THEN NULL
			ELSE INITCAP(TRIM(damage_reported))
	END AS damage_reported
FROM dirty_shipments;




WITH Ranked AS(
SELECT*,
	ROW_NUMBER() OVER (
	PARTITION BY 
		origin_warehouse,
		destination_city,
		carrier,
		ship_date,
		CAST(weight_kg AS VARCHAR),
		CAST(freight_cost AS VARCHAR)
		ORDER BY shipment_id
	) AS row_num
FROM dirty_shipments
)
SELECT*
FROM Ranked
WHERE row_num = 1;




SELECT shipment_id,
	CASE
		WHEN weight_kg < 0 THEN ABS(weight_kg)
		WHEN weight_kg = 0 THEN NULL
			ELSE weight_kg 
	END AS weight_kg_clean
FROM dirty_shipments;

WITH cleanned_dates AS(
SELECT
	shipment_id,
	ship_date,
	delivery_date,
	CASE
		WHEN delivery_date ~ '^\d{4}-\d{2}-\d{2}'
			THEN TO_DATE (delivery_date, 'YYYY-MM-DD')
		ELSE NULL
	END AS clean_delivery_date,
	CASE	
		WHEN ship_date ~ '^\d{4}-\d{2}-\d{2}'
			THEN TO_DATE (ship_date, 'YYYY-MM-DD')
		ELSE NULL
	END AS clean_ship_date
	FROM dirty_shipments)
SELECT
	shipment_id,
	ship_date,
	delivery_date,
	(clean_delivery_date - clean_ship_date) transit_data,
	CASE
		WHEN clean_delivery_date < clean_ship_date 
			THEN 'Invalid'
		WHEN clean_delivery_date = clean_ship_date
			THEN 'Same_Day Delivery'
		ELSE 'Valid'
	END AS data_quality_flag
FROM cleanned_dates;




WITH stats AS(
	SELECT
		PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY freight_cost) AS q1,
		PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY freight_cost) AS q3
	FROM dirty_shipments
	WHERE freight_cost > 0
),

bounds AS(
	SELECT
		q1 - 1.5 * (q3 - q1) AS lower_bounds,
		q3 + 1.5 * (q3 - q1) AS upper_bounds
	FROM stats 
)

SELECT 
	shipment_id,
	freight_cost AS original_cost,
	CASE
		WHEN freight_cost > upper_bounds 
			THEN upper_bounds
		WHEN freight_cost < lower_bounds
			THEN lower_bounds
		ELSE freight_cost
	END AS clean_cost,
	CASE
		WHEN freight_cost > upper_bounds OR freight_cost < lower_bounds
			THEN TRUE
		ELSE FALSE
	END AS was_outlier
FROM dirty_shipments
CROSS JOIN bounds;

