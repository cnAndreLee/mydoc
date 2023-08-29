

## mysql存储引擎选择
*  innoDB 默认引擎，支持事务外键，在并发条件下可做到数据一致性好
*  MyISAM 以读操作和插入操作为主，适合足迹类功能，不支持事务。建议用MongoDB代替
*  MEMORY 内存缓存，建议用redis替代
