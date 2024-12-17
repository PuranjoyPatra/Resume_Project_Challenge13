# Business Requests:

-- 1) City-Level Fare and Trip Summary Report
/* Generate a report that displays the total trips, average fare per km, average fare per trip, and the percentage contribution of each city's trips to the overall trips. This report will help in assessing 
trip volume, pricing efficiency, and each city's contribution to the overall trip count.

Fields: city_name, total_trips, avg_fare_per_km, avg_fare_per_trip, %_contribution_to_total_trips */
 
SELECT
	c.city_name,
	count(trip_id) as total_trips,
    round(sum(fare_amount)/sum(distance_travelled_km),2) as avg_fare_per_km,
    round(sum(fare_amount)/count(trip_id),2) as avg_fare_per_trip,
    (count(trip_id)/ (select count(trip_id) from fact_trips))*100 as pct_contribution_to_total_trips
FROM fact_trips ft
join dim_city c
on ft.city_id = c.city_id
group by city_name;

-- 2) Monthly City-Level Trips Target Performance Report
/* Generate a report that evaluates the target performance for trips at the monthly and city level. For each city and month, compare the actual total trips with the target trips and categorise 
the performance as follows:
	If actual trips are greater than target trips, mark it as "Above Target".
	If actual trips are less than or equal to target trips, mark it as "Below Target".
    
Additionally, calculate the % difference between actual and target trips to quantify the performance gap.
Fields: City_name, month name, actual_trips, target_trips, performance_status, % difference */

with actual_trip as(
SELECT city_id, start_of_month, month_name, count(trip_id) as actual_trips FROM fact_trips ft
join dim_date d
on ft.date = d.date
group by city_id, start_of_month, month_name
)
select 
	city_name,
    month_name,
    actual_trips,
    total_target_trips as target_trips,
    case
		when actual_trips > total_target_trips then "Above"
        when actual_trips <= total_target_trips then "Below"
	end as performance_status,
    round(((actual_trips - total_target_trips)/total_target_trips)*100,2) as difference_pct
from actual_trip atr
join dim_city c
on atr.city_id = c.city_id
join targets_db.monthly_target_trips tt
on atr.city_id = tt.city_id and atr.start_of_month = tt.month;

-- 3) City-Level Repeat Passenger Trip Frequency Report
/* Generate a report that shows the percentage distribution of repeat passengers by the number of trips they have taken in each city. Calculate the percentage of repeat passengers who took 2 trips, 3 trips, and so on, up to 10 trips.
Each column should represent a trip count category, displaying the percentage of repeat passengers who fall into that category out of the total repeat passengers for that city.
This report will help identify cities with high repeat trip frequency, which can indicate strong customer loyalty or frequent usage patterns.

Fields: city_name, 2-Trips, 3-Trips, 4-Trips, 5-Trips, 6-Trips, 7-Trips, 8-Trips, 9-Trips, 10-Trips */

with city_wise_total_repeat_passenger as (
select
	city_id, 
    sum(repeat_passenger_count) as repeat_passenger
from dim_repeat_trip_distribution
group by city_id
),

city_trip_frequency as (
select 
	rtd.city_id,
    trip_count,
    round((sum(repeat_passenger_count)/repeat_passenger)*100,2) as repeat_passenger_pct
from dim_repeat_trip_distribution rtd
join city_wise_total_repeat_passenger crp
on rtd.city_id = crp.city_id
group by rtd.city_id, trip_count
)

select 
	city_name,
    max(case when trip_count = '2-Trips' then repeat_passenger_pct else 0 end) as 2_Trips,
    max(case when trip_count = '3-Trips' then repeat_passenger_pct else 0 end) as 3_Trips,
    max(case when trip_count = '4-Trips' then repeat_passenger_pct else 0 end) as 4_Trips,
    max(case when trip_count = '5-Trips' then repeat_passenger_pct else 0 end) as 5_Trips,
    max(case when trip_count = '6-Trips' then repeat_passenger_pct else 0 end) as 6_Trips,
    max(case when trip_count = '7-Trips' then repeat_passenger_pct else 0 end) as 7_Trips,
    max(case when trip_count = '8-Trips' then repeat_passenger_pct else 0 end) as 8_Trips,
    max(case when trip_count = '9-Trips' then repeat_passenger_pct else 0 end) as 9_Trips,
    max(case when trip_count = '10-Trips' then repeat_passenger_pct else 0 end) as 10_Trips
    
from city_trip_frequency ctf
join dim_city c
on ctf.city_id = c.city_id
group by city_name;

-- 4) Identify Cities with Highest and Lowest Total New Passengers
/* Generate a report that calculates the total new passengers for each city and ranks them based on this value. Identify the top 3 cities with the highest number of new passengers as well as the bottom 3 cities 
with the lowest number of new passengers, categorising them as "Top 3" or "Bottom 3" accordingly.

FieldS: city_name, total new_passengers, city_category ("Top 3" or "Bottom 3") */

with top_bottom_3_citties as (

select 
	city_name,
    sum(new_passengers) as total_new_passengers,
    dense_rank() over (order by sum(new_passengers) desc) as rank_order
from fact_passenger_summary ps
join dim_city c
on ps.city_id = c.city_id
group by city_name
)

select
 city_name,
 total_new_passengers,
 case
	when rank_order in (1, 2, 3) then "Top 3"
    when rank_order in (8,9, 10) then "Bottom 3"
end as city_category
from top_bottom_3_citties
where rank_order <= 3 or rank_order>=8;

-- 5) Identify Month with Highest Revenue for Each City
/* Generate a report that identifies the month with the highest revenue for each city. For each city, display the month_name, the revenue amount for that month, and the percentage contribution of 
that month's revenue to the city's total revenue.

Fields: city_name, highest_revenue month, revenue, percentage_contribution (%) */

with city_wise_revenue as (
SELECT 
	city_id,
    sum(fare_amount) as city_revenue
FROM fact_trips
group by city_id
),

highest_revenue_month as (
select
	ft.city_id,
    month_name,
    round(sum(fare_amount)/1000000,2) as revenue_in_mln,
    dense_rank() over (partition by ft.city_id order by sum(fare_amount) desc) as month_rank,
    round((sum(fare_amount)/city_revenue)*100,2) as pct_contribution
from fact_trips ft
join city_wise_revenue cwr
on ft.city_id = cwr.city_id
join dim_date d
on ft.date = d.date
group by ft.city_id, month_name
)

select 
	city_name,
    month_name as highest_revenue_month,
    revenue_in_mln,
    pct_contribution
from highest_revenue_month hrm
join dim_city c
on hrm.city_id = c.city_id
where month_rank = 1;

-- 6) Repeat Passenger Rate Analysis
/* Generate a report that calculates two metrics:
1.	Monthly Repeat Passenger Rate: Calculate the repeat passenger rate for each city and month by comparing the number of repeat passengers to the total passengers.
2.	City-wide Repeat Passenger Rate: Calculate the overall repeat passenger rate for each city, considering all passengers across months.

These metrics will provide insights into monthly repeat trends as well as the overall repeat behaviour for each city.

Fields: city_name, month, total_passengers, repeat_passengers, monthly_repeat_passenger_rate (%): Repeat passenger rate at the city and month level, 
city_repeat_passenger_rate (%): Overall repeat passenger rate for each city aggregated across months */

with monthly_rpr as (
SELECT 
	city_id,
    month_name,
    total_passengers,
    repeat_passengers,
    round((sum(repeat_passengers)/sum(total_passengers))*100,2) as monthly_rpr
FROM fact_passenger_summary fps
join dim_date d
on fps.month = d.start_of_month
group by city_id, month_name, total_passengers,repeat_passengers
),

overall_city_wise_rpr as (
select
	city_id,
    round((sum(repeat_passengers)/sum(total_passengers))*100,2) as overall_rpr
from fact_passenger_summary
group by city_id
)

select
	city_name,
    month_name,
    total_passengers,
    repeat_passengers,
    monthly_rpr,
    overall_rpr
from monthly_rpr mr
join overall_city_wise_rpr ocr
on mr.city_id = ocr.city_id
join dim_city c
on mr.city_id = c.city_id;



	



