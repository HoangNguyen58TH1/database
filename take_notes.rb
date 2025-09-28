# SHOW ALL COLUMNS OF MODEL: User.columns_hash
{
  "id"=>
  #<ActiveRecord::ConnectionAdapters::PostgreSQL::Column:0x00000001152bf050
   @collation=nil,
   @comment=nil,
   @default=nil,
   @default_function="nextval('users_id_seq'::regclass)",
   @generated="",
   @identity=nil,
   @name="id",
   @null=false,
   @serial=true,
   @sql_type_metadata=#<ActiveRecord::ConnectionAdapters::SqlTypeMetadata:0x00000001152b4330 @limit=8, @precision=nil, @scale=nil, @sql_type="bigint", @type=:integer>>,
 "email1"=>
 "name1"=>
 "sex1"=>
 "age1"=>
 "created_at"=>
 "updated_at"=>
}

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

a. INDEX:
# Planning Time: 0.100 ms, Execution Time: 0.078 ms
# Planning Time: 0.156 ms, Execution Time: 0.096 ms
# Planning Time: 0.210 ms, Execution Time: 0.093 ms
==> exe/plan (50-70/100'%') --> TIME EXE < TIME ESTIMATE --> exe/est gấp 0.6 lần
b. NO INDEX:
# Planning Time: 0.063 ms, Execution Time: 0.128 ms
# Planning Time: 0.174 ms, Execution Time: 0.306 ms
# Planning Time: 0.174 ms, Execution Time: 0.299 ms
==> exe/plan (150-200/100'%') --> TIME EXE > TIME ESTIMATE --> exe/est gấp 2 lần


# 21/09/2025 --------------------------------------------------------------------------------
# 1. Destroy all data
User.destroy_all

# 2. INSERT 10K RECORDS:
now = Time.current
rows = Array.new(10000) do |i|
  {
    email1: "email_1_#{i+1}@example.com", email2: "email_2_#{i+1}@example.com",
    name1: "User 1 #{i+1}", name2: "User 2 #{i+1}",
    age1: 18, age2: 19, sex1: true, sex2: false, created_at: now, updated_at: now
  }
end
User.insert_all(rows)

# 3. Test filter
a. Has index:
User.where(email1: 'email_1_9999@example.com').explain(:analyze, :buffers)
==> exe/plan (60-80/100'%') --> TIME EXE < TIME ESTIMATE --> exe/est gấp 0.7 lần
b. No index:
User.where(email2: 'email_2_9999@example.com').explain(:analyze, :buffers)
==> exe/plan (1500-2200/100'%') --> TIME EXE > TIME ESTIMATE --> exe/est gấp 20 lần


# 26/09/2025 --------------------------------------------------------------------------------
# 2. INSERT 100K RECORDS:
now = Time.current
rows = Array.new(90000) do |i|
  {
    email1: "email_1_#{i+10000}@example.com", email2: "email_2_#{i+10000}@example.com",
    name1: "User 1 #{i+10000}", name2: "User 2 #{i+10000}",
    age1: 18, age2: 19, sex1: true, sex2: false, created_at: now, updated_at: now
  }
end
User.insert_all(rows)

# 3. Test filter
a. Has index:
User.where(email1: 'email_1_99999@example.com').explain(:analyze, :buffers)
==> exe/plan (75-100/100'%') --> TIME EXE < TIME ESTIMATE --> exe/est gấp 0.8 lần

b. No index:
User.where(email2: 'email_2_99999@example.com').explain(:analyze, :buffers)
==> exe/plan (10000-15549/100'%') --> TIME EXE > TIME ESTIMATE --> exe/est gấp 125 lần


# 27/09/2025 --------------------------------------------------------------------------------
# 2. INSERT 1M RECORDS:
now = Time.current
rows = Array.new(900000) do |i|
  {
    email1: "email_1_#{i+100000}@example.com", email2: "email_2_#{i+100000}@example.com",
    name1: "User 1 #{i+100000}", name2: "User 2 #{i+100000}",
    age1: 18, age2: 19, sex1: true, sex2: false, created_at: now, updated_at: now
  }
end
User.insert_all(rows)

# 3. Test filter
a. Has index:
User.where(email1: 'email_1_999999@example.com').explain(:analyze, :buffers)
==> exe/plan (60-90/100'%') --> TIME EXE < TIME ESTIMATE --> exe/est gấp 0.7 lần

b. No index:
User.where(email2: 'email_2_999999@example.com').explain(:analyze, :buffers)
==> exe/plan (64000/100'%') --> TIME EXE > TIME ESTIMATE --> exe/est gấp 640 lần


# CALCULATE BYTE SIZE: ----------------------------------------------------------------------
# CALCULATE BYTE SIZE OF 1 ROW:
size = ActiveRecord::Base.connection.execute("
  SELECT pg_column_size(t) 
  FROM users t 
  WHERE id = 999999
").first["pg_column_size"]
==> 120 / 144 bytes

# CALCULATE BYTE SIZE AVERAGE OF ALL ROWS IN A TABLE:
avg_size = ActiveRecord::Base.connection.execute("
  SELECT pg_relation_size('users') / COUNT(*) AS avg_row_bytes
  FROM users
").first["avg_row_bytes"]
==> 148 bytes


# CALCULATE BYTE SIZE DATA + INDEX OF TABLE USER:
sizes = ActiveRecord::Base.connection.execute("
  SELECT 
    pg_size_pretty(pg_relation_size('users')) AS table_data,
    pg_size_pretty(pg_indexes_size('users')) AS table_indexes,
    pg_size_pretty(pg_total_relation_size('users')) AS total_size
").first
=> {"table_data"=>"141 MB", "table_indexes"=>"197 MB", "total_size"=>"339 MB"}

Check dung lượng của Disk: tăng từ 424.06 GB --> 425.09 GB (it mean created 1M records ~ 1.3 GB)
Calculate byte size of table User: 148*1000000/1024/1024/1024.to_f = 141 MB = 0.13 GB
Calculate byte size data + index of table User: 141 MB + 197 MB = 339 MB = 0.33 GB
Vậy thì 0.13 GB - 0.33 GB = 0.97 GB là storage cái gì?
==> Overhead hệ thống + WAL log (Postgres ghi mọi thay đổi vào WAL trước → thường lớn hơn data gốc)

# 28/09/2025 --------------------------------------------------------------------------------
# CHECK TABLE SIZE OF column email1:
result = ActiveRecord::Base.connection.execute("
  SELECT 
    SUM(pg_column_size(email1)) AS total_bytes,
    AVG(pg_column_size(email1)) AS avg_bytes
  FROM users
").first
puts "Average size per row: #{result['avg_bytes']} bytes"
puts "Total size of email1: #{result['total_bytes']} bytes"
# ==>
# Average size per row: 26.888894 bytes
# Total size of email1: 26888894 bytes = 26888894/1024/1024.to_f = 25.6 MB = 0.024 GB


# CHECK TABLE SIZE OF ALL COLUMNS:
result = ActiveRecord::Base.connection.execute("
  SELECT 
    SUM(pg_column_size(email1)) AS email1_total,
    SUM(pg_column_size(email2)) AS email2_total,
    SUM(pg_column_size(name1))  AS name1_total,
    SUM(pg_column_size(name2))  AS name2_total,
    SUM(pg_column_size(sex1))   AS sex1_total,
    SUM(pg_column_size(sex2))   AS sex2_total,
    SUM(pg_column_size(age1))   AS age1_total,
    SUM(pg_column_size(age2))   AS age2_total
  FROM users
").first
result.each do |col, size|
  puts "#{col}: #{size/1024/1024.to_f} MB"
end
# ==> {
#   email1_total: 25.6 MB
#   email2_total: 25.6 MB
#   name1_total: 13.2 MB
#   name2_total: 13.2 MB
#   sex1_total: 0.9 MB
#   sex2_total: 0.9 MB
#   age1_total: 3.8 MB
#   age2_total: 3.8 MB
# }


# CHECK INDEX SIZE OF ALL COLUMNS:
result = ActiveRecord::Base.connection.execute("
  SELECT 
      indexrelid::regclass AS index_name,
      pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
  FROM pg_index
  WHERE indrelid = 'users'::regclass;
")
result.each do |row|
  puts "#{row['index_name']} => #{row['index_size']}"
end
# ==> 
# users_pkey => 21 MB
# index_users_on_email1 => 84 MB
# index_users_on_name1 => 51 MB
# index_users_on_sex1 => 20 MB
# index_users_on_age1 => 20 MB
