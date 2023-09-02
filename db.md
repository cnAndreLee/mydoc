# mysql

## mysql存储引擎选择
*  innoDB 默认引擎，支持事务外键，在并发条件下可做到数据一致性好
*  MyISAM 以读操作和插入操作为主，适合足迹类功能，不支持事务。建议用MongoDB代替
*  MEMORY 内存缓存，建议用redis替代

## 索引语法
### 创建索引
```sql
CREATE [ UNIQUE|FULLTEXT ] INDEX index_name ON table_name ( index_col_name,...);
```
### 查看索引
```sql
SHOW INDEX FROM table_name;
```
### 删除索引
```sql
DROP INDEX index_name ON table_name;
```
## mysql性能优化
### 查看执行频次
SHOW [GLOBAL|SESSION] STATUS LIKE `Com_______`;
### 查看慢查询日志开关
```sql
show variables like 'slow_query_log';
```
如果需要开启，需要配置/etc/my.cnf
```
# 开启慢查询日志开关
slow_query_log=1
# 设置日志查询时间为2秒，sql语句执行时间超过2秒，就会被记录
long_query_time=2
```

