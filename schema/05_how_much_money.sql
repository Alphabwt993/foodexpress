create or replace
view how_much_money as
with recursive bounds as (
select
	min(date_trunc('month', order_timestamp))::date as start_month,
	max(date_trunc('month', order_timestamp))::date as end_month
from
	"order"
where
	status = 'доставлен'
),
months as (
select
	start_month as month_start
from
	bounds
union all
select
	(month_start + interval '1 month')::date
from
	months
where
	month_start + interval '1 month' <= (
	select
		end_month
	from
		bounds)
),
order_agg as (
select
	date_trunc('month', order_timestamp)::date as month_start,
	sum(order_amount) as sum_no_commission,
	sum(total_amount) as sum_with_commission,
	sum(commission) as commission
from
	"order"
where
	status = 'доставлен'
group by
	date_trunc('month', order_timestamp)::date
),
courier_pay_agg as (
select
	make_date(year, month, 1) as month_start,
	sum(amount) as courier_pay
from
	courier_pay
group by
	make_date(year, month, 1)
),
combined as (
select
	m.month_start,
	coalesce(o.sum_no_commission, 0) as sum_no_commission,
	coalesce(o.sum_with_commission, 0) as sum_with_commission,
	coalesce(o.commission, 0) as commission,
	coalesce(cp.courier_pay, 0) as courier_pay
from
	months m
left join order_agg o on
	m.month_start = o.month_start
left join courier_pay_agg cp on
	m.month_start = cp.month_start
)
select
	to_char(month_start, 'yyyy-mm') as year_month,
	sum_no_commission,
	sum_with_commission,
	commission,
	lag(commission) over (
	order by month_start) as prev_commission,
	commission - lag(commission) over (
	order by month_start) as commission_diff,
	courier_pay,
	commission - courier_pay as net_profit
from
	combined
order by
	month_start;
