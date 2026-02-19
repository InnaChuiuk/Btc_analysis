-- Огляд сирих даних 
-- Вибірка всіх запитів для перевірки структури таблиці та наявності даних

select *
from dbo.btc_analysis

-- Аналіз середньої ціни за настроями 
-- Розрахунок середньої ціни закриття (Close) для кожної емоційної фази

select
	value_classification,
	avg([close]) as mean_close
from dbo.btc_analysis
group by value_classification
order by mean_close asc

-- Перевірка діапазону індексу

select
	value_classification,
	min([value]) as min_value,
	max([value]) as max_value,
	count(*) as count_days
from dbo.btc_analysis
group by value_classification
order by min_value


-- Екстремальні ціни за класифікацією
-- Аналіз історичних максимумів та мінімумів ціни біткоїна для кожного стану ринку

select
	value_classification,
	min([close]) as min_value,
	max([close]) as max_value,
	count(*) as count_days
from dbo.btc_analysis
group by value_classification
order by max_value desc


-- Средній/Мін/Макс діапазон зміни ціни за 7 днів для кожного стану

with pricechange7 as (
	select
		value_classification,
		[close] as current_price,
		lead([close], 7) over (order by [timestamp]) as price_7d
	from dbo.btc_analysis
)
select
	value_classification,
	avg((price_7d - current_price) / current_price) * 100 as percent_7d,
	min((price_7d - current_price) / current_price) * 100 as max_loss_percent,
	max((price_7d - current_price) / current_price) * 100 as max_profit_percent
from pricechange7 
group by value_classification
order by percent_7d desc


-- Порівняльний аналіз очікуваного прибутку через 1, 7, 30 днів

with pricechange as (
	select
		value_classification,
		[close] as current_price,
		lead([close], 1) over (order by [timestamp]) as price_1d,
		lead([close], 7) over (order by [timestamp]) as price_7d,
		lead([close], 30) over (order by [timestamp]) as price_30d
	from dbo.btc_analysis
)
select
	value_classification,
	avg((price_1d - current_price) / current_price) * 100 as percent_1d,
	avg((price_7d - current_price) / current_price) * 100 as percent_7d,
	avg((price_30d - current_price) / current_price) * 100 as percent_30d,
	count(price_1d) as count_1d,
	count(price_7d) as count_7d,
	count(price_30d) as count_30d
from pricechange 
group by value_classification
order by percent_30d desc


-- Якого саме дня був найбільший обвал ціни у -45% у стані fear

with pricechange as(
	select
		[timestamp],
		[value] as fear_index,
		value_classification,
		[close] as start_price,
		lead([close], 7) over (order by [timestamp]) as price_7d,
		volume
	from dbo.btc_analysis
)
select top 10
	[timestamp],
	fear_index,
	value_classification,
	start_price,
	price_7d,
	((price_7d - start_price) / start_price) * 100 as weekly_percent,
	volume
from pricechange
where price_7d is not null
order by weekly_percent asc


-- Розрахунок середньої прибутковості 30-денного утримання активу за роками

with pricechange as(
	select
		year([timestamp]) as year_time,
		[close] as current_price,
		lead([close], 30) over (order by [timestamp]) as price_30d
	from dbo.btc_analysis
)
select
	year_time,
	count(*) days_count,
	avg((price_30d - current_price) / current_price) * 100 as percent_30d
from pricechange
where price_30d is not null
group by year_time
order by year_time


-- Розрахунок прибудковості окремо для негативного та позитивного росту цін (7, 30 днів)

;with price_30 as(
	select
		value_classification,
		[timestamp],
		[close] as current_price,
		lead([close], 30) over(order by [timestamp]) as price_30d
	from dbo.btc_analysis
), bool_exp as(
	select
		value_classification,
		((price_30d - current_price) / current_price) * 100 as change_percent,
		case
			when price_30d > current_price then 1
			else 0
		end as price_dynamic
	from price_30
)
select
	value_classification,
	count(*) as total_days,
	sum(price_dynamic) as positive_dynamic_count,
	round(avg(cast(price_dynamic as float)) * 100, 2) as win_percentage,
	round(avg(case when change_percent > 0 then change_percent end), 2) as avg_positive_percent_change,
	round(avg(case when change_percent < 0 then change_percent end), 2) as avg_negative_percent_change
from bool_exp
group by value_classification
order by win_percentage desc;
;with price_7 as(
	select
		value_classification,
		[timestamp],
		[close] as current_price,
		lead([close], 7) over(order by [timestamp]) as price_7d
	from dbo.btc_analysis
), bool_exp as(
	select
		value_classification,
		((price_7d - current_price) / current_price) * 100 as change_percent,
		case
			when price_7d > current_price then 1
			else 0
		end as price_dynamic
	from price_7
)
select
	value_classification,
	count(*) as total_days,
	sum(price_dynamic) as positive_dynamic_count,
	round(avg(cast(price_dynamic as float)) * 100, 2) as win_percentage,
	round(avg(case when change_percent > 0 then change_percent end), 2) as avg_positive_percent_change,
	round(avg(case when change_percent < 0 then change_percent end), 2) as avg_negative_percent_change
from bool_exp
group by value_classification
order by win_percentage desc;




-- Створення view для візуалізації

-- Середній розмір пибутку загалом

create view price_change as
with pricechange as (
	select
		cast([timestamp] as date) as [date],
		value_classification,
		[close] as current_price,
		lead([close], 1) over (order by [timestamp]) as price_1d,
		lead([close], 7) over (order by [timestamp]) as price_7d,
		lead([close], 30) over (order by [timestamp]) as price_30d
	from dbo.btc_analysis
)
select
	[date],
	value_classification,
	((price_1d - current_price) / current_price) * 100 as percent_1d,
	((price_7d - current_price) / current_price) * 100 as percent_7d,
	((price_30d - current_price) / current_price) * 100 as percent_30d
from pricechange 


--  Змінення цін у розрізі часу

create view time_change as
select
	cast([timestamp] as date) as [date],
	value_classification,
	[value] as fear_greed_index,
	[close] as btc_price,
	[volume] as volume
from dbo.btc_analysis


-- Результати 7-денного та 30-денного утримання активу для позитивного та негативного приросту цін

create view price_move as
with both_prices as(
	select
		value_classification,
		[timestamp],
		[close] as current_price,
		lead([close], 30) over(order by [timestamp]) as price_30d,
		lead([close], 7) over(order by [timestamp]) as price_7d
	from dbo.btc_analysis
), price_30 as(
	select
		value_classification,
		30 as period_d,
		((price_30d - current_price) / current_price) * 100 as change_percent,
		case
			when price_30d > current_price then 1
			else 0
		end as price_dynamic
	from both_prices
), price_7 as(
	select
		value_classification,
		7 as period_d,
		((price_7d - current_price) / current_price) * 100 as change_percent,
		case
			when price_7d > current_price then 1
			else 0
		end as price_dynamic
	from both_prices
), combined as(
select * from price_30
union all
select * from price_7
)
select
	value_classification,
	period_d,
	count(*) as total_days,
	sum(price_dynamic) as positive_dynamic_count,
	round(avg(cast(price_dynamic as float)) * 100, 2) as win_percentage,
	round(avg(case when change_percent > 0 then change_percent end), 2) as avg_positive_percent_change,
	round(avg(case when change_percent < 0 then change_percent end), 2) as avg_negative_percent_change
from combined
group by value_classification, period_d