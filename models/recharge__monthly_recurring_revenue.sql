with customers as (
    select 
        distinct date_month,
        customer_id
    from {{ ref('recharge__customer_daily_rollup') }}

), billing as (
    select *
    from {{ ref('recharge__billing_history') }}

), aggs as (
    select 
        customers.date_month,
        customers.customer_id,
        round(sum(case when lower(billing.order_type) = 'recurring' then billing.total_price else 0 end), 2) as current_mrr,
        lag(current_mrr, 1) over(partition by customers.customer_id order by customers.date_month asc) as previous_mrr,
        round(sum(current_mrr) over( partition by customers.customer_id order by customers.date_month asc), 2) as current_mrr_running_total,
        round(sum(case when lower(billing.order_type) = 'checkout' then billing.total_price else 0 end), 2) as current_non_mrr,
        lag(current_non_mrr, 1) over(partition by customers.customer_id order by customers.date_month asc) as previous_non_mrr,
        round(sum(current_non_mrr) over( partition by  customers.customer_id order by customers.date_month asc), 2) as current_non_mrr_running_total

    from customers
    left join billing
        on cast({{ dbt.date_trunc('month','billing.created_at') }} as date) = customers.date_month
        and billing.customer_id = customers.customer_id
    where lower(billing.order_status) not in ('error', 'skipped')
    group by 1,2

)

select *
from aggs