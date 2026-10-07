# Feature 4.2 - Rail Capacity Allocation & Spillover
Owner: Kethmika K.A.D.Y (Group 20, CS3043)

Run order (after 00_master_init.sql has created the base schema):

| File | What it adds |
|------|--------------|
| 01_trip_constraints.sql | CHECKs on TRAIN_TRIP |
| 02_allocation_constraints.sql | CHECKs on RAIL_ALLOCATION |
| 03_indexes.sql | indexes for trip search / capacity SUM |
| 04_fn_order_item_space.sql | fn_order_item_space |
| 05_fn_trip_remaining_capacity.sql | fn_trip_remaining_capacity |
| 06_trg_capacity_check.sql | capacity triggers on RAIL_ALLOCATION |
| 07_trg_trip_capacity_shrink.sql | trigger: capacity cannot drop below booked |
| 08_sp_schedule_train_order.sql | sp_schedule_train_order (transaction + row locks) |
| 09_v_trip_capacity_usage.sql | view for API / UI |
| 10_demo_data.sql, 11_viva_demo.sql | viva demo |
| 12_concurrency_test_4_2.py | two simultaneous requests test |

Result codes: SUCCESS_SINGLE_TRIP, SUCCESS_MULTI_TRIP_SPILLOVER, INSUFFICIENT_RAIL_CAPACITY,
INVALID_ORDER_STATUS, ORDER_NOT_FOUND, DESTINATION_HUB_NOT_RESOLVED, ORDER_HAS_NO_ITEMS,
INVALID_PRODUCT_SPACE_RATE, DEADLOCK_RETRY, ERROR_TRANSACTION_FAILED.