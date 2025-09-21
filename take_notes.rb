# Insert 1 record
# User.create(email1: 'email1', email2: 'email2', name1: 'name1', name2: 'name2', sex1: true, sex2: false, age1: 18, age2: 19)
# arr = Array.new(1000) do |i|
#   {
#     email1: "email_1_#{i}@example.com", email2: "email_2_#{i}@example.com",
#     name1: "name_1_#{i}", name2: "name_2_#{i}",
#     sex1: true, sex2: false,
#     age1: 18, age2: 19,
#   }
# end

# 0. USE sqlite3:
# NO INDEX
# User.where(email2: 'user_2_1000@example.com').explain
# User Load (0.4ms)  SELECT "users".* FROM "users" WHERE "users"."email2" = ?  [["email2", "user_2_1000@example.com"]]
# EXPLAIN for: SELECT "users".* FROM "users" WHERE "users"."email2" = ? [["email2", "user_2_1000@example.com"]]
# 2|0|216|SCAN users
# ==> O(n) – tuyến tính theo số record

# HAS INDEX
# User.where(email1: 'user_2_1000@example.com').explain
# User Load (0.2ms)  SELECT "users".* FROM "users" WHERE "users"."email1" = ?  [["email1", "user_2_1000@example.com"]]
# # EXPLAIN for: SELECT "users".* FROM "users" WHERE "users"."email1" = ? [["email1", "user_2_1000@example.com"]]
# 3|0|61|SEARCH users USING INDEX index_users_on_email1 (email1=?)
# ==> O(log n) – logarithmic (tăng ít khi data phình to)


# INSERT 1K RECORDS:
now = Time.current
rows = Array.new(1000) do |i|
  {
    email1: "user_1_#{i+1}@example.com", email2: "user_2_#{i+1}@example.com",
    name1: "User 1 #{i+1}", name2: "User 2 #{i+1}",
    age1: 18, age2: 19, sex1: true, sex2: false, created_at: now, updated_at: now
  }
end
User.insert_all(rows)


# 1. NO index:
User.where(email2: 'user_2_1000@example.com').explain
User Load (1.9ms)  SELECT "users".* FROM "users" WHERE "users"."email2" = $1  [["email2", "user_2_1000@example.com"]]
--------------------------------------------------------------
Seq Scan on users  (cost=0.00..29.50 rows=1 width=98)
 Filter: ((email2)::text = 'user_2_1000@example.com'::text)
==>
- Seq Scan = sequential scan (quét tuần tự)
- cost: 0.00 --> startup cost (chi phí bắt đầu đọc index).
- cost: 29.50 --> total cost ước lượng để đọc hết bảng (tổng chi phí ước lượng để tìm xong kết quả)
- rows=1 --> return 1 result
- width=98 --> số byte trung bình mỗi row return
- Filter: --> sau khi quét bảng, Postgres áp dụng filter này


# 2. HAS index:
User.where(email1: 'user_1_1000@example.com').explain
User Load (0.5ms)  SELECT "users".* FROM "users" WHERE "users"."email1" = $1  [["email1", "user_1_1000@example.com"]]
------------------------------------------------------------------------------------
Index Scan using index_users_on_email1 on users  (cost=0.28..8.29 rows=1 width=98)
 Index Cond: ((email1)::text = 'user_1_1000@example.com'::text)
==>
- Index Scan (thay vì dùng seq scan). Use index đã tạo: index_users_on_email1. DB sẽ vào B-Tree index --> tìm nhanh vị trí row phù hợp --> get data from table.
- cost: 0.28 --> startup cost (chi phí bắt đầu đọc index).
- cost: 8.29 --> total costs estimate (tổng chi phí ước lượng để tìm xong kết quả)
- rows=1 --> return 1 result
- width=98 --> số byte trung bình mỗi row return
- Index Cond  = index condition --> là condition dùng direct trong INDEX LOOKUP (index condition)


# 3. COMPARE:
email2 (NO index) --> seq scan, scan all table, cost 29.5
==> O(n)
email1 (HAS index) --> index scan, vào B-tree index to find, cost 8.29
==> O(log n)


# 4. Explain with ANALYZE and BUFFERS:
User.where(email1: 'user_1_1000@example.com').explain(:analyze, :buffers)
User Load (1.1ms)  SELECT "users".* FROM "users" WHERE "users"."email1" = $1  [["email1", "user_1_1000@example.com"]]
------------------------------------------------------------------------------------------------------------------------------
Index Scan using index_users_on_email1 on users  (cost=0.28..8.29 rows=1 width=98) (actual time=0.031..0.032 rows=1 loops=1)
 Index Cond: ((email1)::text = 'user_1_1000@example.com'::text)
 Buffers: shared hit=3
Planning Time: 0.080 ms
Execution Time: 0.056 ms
==>
- Index Scan using index_users_on_email1 --> Use B-Tree index để tìm nhanh record
- (cost=0.28..8.29 rows=1 width=98) --> Planner estimate (before execute)
- (actual time=0.031..0.032 rows=1 loops=1) --> data reality
+ 0.031 ms --> time start return first row
+ 0.032 ms --> time completed scan (<0.1ms là rất nhanh)
+ rows=1 --> thực sự return 1 row (match estimate)
+ loops=1 --> Node này chạy 1 lần (nếu trong join/subquery, có thể loop nhiều lần)
- Index Cond: ((email1)::text = 'user_1_1000@example.com'::text) --> condition đc apply trong index lookup (index condition)
- Buffers: shared hit=3 --> info about I/O buffer (hit = RAM, read = DISK)x
+ shared hit=3 --> đọc 3 page (block 8KB) từ shared buffer cache (meaning data already in RAM, NO read from DISK)
+ If has "shared read=N" --> meaning read N page from DISK --> chậm hơn
+ Với small table, hầu hết là HIT, còn bảng lớn thì có READ
- Planning Time: 0.080 ms --> time to Planner analyze query --> select 'EXECUTE PLAN'
- Execution Time: 0.056 ms --> total time execute query (include scan index, fetch row)


NO INDEX: --> exe/plan (150-200/100%) --> time exe > hơn estimate
Planning Time: 0.063 ms
Execution Time: 0.128 ms
Planning Time: 0.174 ms
Execution Time: 0.306 ms
Planning Time: 0.179 ms
Execution Time: 0.285 ms
Planning Time: 0.136 ms
Execution Time: 0.154 ms
Planning Time: 0.174 ms
Execution Time: 0.299 ms

INDEX: --> exe/plan (50-70/100%) --> time exe < hơn estimate
Planning Time: 0.100 ms
Execution Time: 0.078 ms
Planning Time: 0.156 ms
Execution Time: 0.096 ms
Planning Time: 0.210 ms
Execution Time: 0.093 ms