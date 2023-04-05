with base as (
    select *
    from {{ ref('int_recharge__customer_daily_rollup') }}

), billing as (
    select *
    from {{ ref('recharge__billing_history') }}

), customers as (
    select 
        customer_id,
        created_at
    from {{ ref('recharge__customer_details') }}

), aggs as (
    select
        base.customer_id,
        base.date_day,
        base.date_week,
        base.date_month,
        base.date_year,

        count(billing.order_id) as no_of_orders,
        count(case when lower(billing.order_type) = 'recurring' then 1 else null end) as subscription_orders,
        count(case when lower(billing.order_type) = 'checkout' then 1 else null end) as one_time_orders,
        coalesce(sum(billing.total_price), 0) as total_charges,

        {% set cols = ['total_discounts', 'total_tax', 'total_price', 'total_refunds', 'order_value', 'order_item_quantity'] %}
        {% for col_name in cols %}
            round(sum(case when lower(billing.order_status) not in ('error', 'skipped', 'queued') 
                then billing.{{col_name}} else 0 end), 2)
                as {{col_name}}_realized
            {{ ',' if not loop.last -}}
        {% endfor %}

    from base
    left join billing
        on cast({{ dbt.date_trunc('day','billing.created_at') }} as date) = base.date_day
        and billing.customer_id = base.customer_id

    {{ dbt_utils.group_by(5) }}

), active_months as (
    select
        aggs.*,
        round({{ dbt.datediff("customers.created_at", "aggs.date_day", "day") }} / 30, 2)
            as active_months_to_date

    from aggs
    left join customers
        on customers.customer_id = aggs.customer_id

)

select * 
from active_months