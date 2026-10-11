---
name: mybatis-sql
description: 写或改 MyBatis / MyBatis-Plus Mapper、XML 里的 SQL、分页查询、批量操作、建表和加索引时使用，避免 SQL 注入、慢 SQL、深分页和 N+1 查询。Use when writing MyBatis mappers, SQL, pagination, batch inserts or MySQL indexes in a Java backend.
---

# MyBatis 与 SQL：别让 Agent 写出慢 SQL

写 Mapper 或 SQL 之前和之后，都按下面检查。目标是：**安全、走索引、量大了也不崩**。

## 1. 参数一律用 `#{}`

- `#{}` 是预编译参数，`${}` 是字符串拼接。**用户输入进 `${}` 就是 SQL 注入。**
- 只有表名、排序字段这种无法预编译的地方才用 `${}`，而且必须先用白名单校验：

```java
private static final Set<String> SORTABLE = Set.of("created_at", "amount");

String orderBy = SORTABLE.contains(req.getSort()) ? req.getSort() : "created_at";
```

- `LIKE` 模糊查询写成 `LIKE CONCAT('%', #{keyword}, '%')`，不要写 `'%${keyword}%'`。

## 2. 不写 `SELECT *`

- 只查需要的列。多查的列浪费网络和内存，也让覆盖索引失效。
- 表加字段后，`SELECT *` 还可能让旧的 ResultMap 映射出错。

## 3. 查询要能走索引

写完 WHERE 条件后，确认以下几点：

- 条件列上有索引，联合索引遵守最左前缀；
- 不在索引列上套函数或做运算：`WHERE DATE(created_at) = ?` 改成 `WHERE created_at >= ? AND created_at < ?`；
- 不发生隐式类型转换：`varchar` 列要用字符串比较，`WHERE phone = 13800000000` 会导致全表扫描；
- `OR` 两边的列都要有索引，否则改写成 `UNION ALL`；
- 左模糊 `LIKE '%xx'` 用不上索引，数据量大时换搜索引擎。

不确定时，把 SQL 放到测试库跑一次 `EXPLAIN`，看 `type` 不是 `ALL`、`rows` 合理、`Extra` 里没有 `Using filesort` 和 `Using temporary`。

## 4. 分页避开深分页

`LIMIT 100000, 20` 会先扫描 100020 行再丢掉前面的。数据量大时：

```sql
-- 游标分页：用上一页最后一条的 id
SELECT id, order_no, amount FROM t_order
WHERE id > #{lastId}
ORDER BY id
LIMIT 20;

-- 或者先查 id 再回表
SELECT o.id, o.order_no, o.amount FROM t_order o
JOIN (SELECT id FROM t_order WHERE user_id = #{userId} ORDER BY id LIMIT #{offset}, 20) t
ON o.id = t.id;
```

用 PageHelper / MyBatis-Plus 分页插件时，记得 count 查询也会全表算一遍，大表考虑关闭 count 或单独缓存总数。

## 5. 避免 N+1 和循环里查库

- 不要在 `for` 循环里调用 Mapper。先收集 id，一次 `WHERE id IN (...)` 查出来，再在内存里组装。
- `IN` 列表控制在 1000 个以内，超了就分批。
- 批量插入用 `<foreach>` 拼成一条多值 `INSERT`，每批 500 到 1000 行；或者用 `ExecutorType.BATCH`。不要一条一条插。

## 6. 写操作要有边界

- `UPDATE` 和 `DELETE` 必须带 WHERE 条件，动态 SQL 里要防止所有条件都为空时变成全表更新：

```xml
<update id="updateStatus">
  UPDATE t_order SET status = #{status}
  <where>
    <if test="ids != null and ids.size() > 0">
      id IN <foreach collection="ids" item="id" open="(" separator="," close=")">#{id}</foreach>
    </if>
  </where>
</update>
```

  上面这段在 `ids` 为空时会变成全表更新。正确做法是在 Java 里先判断空集合直接返回，不发 SQL。

- 大批量更新或删除要分批执行，每批之间短暂停顿，避免长事务和主从延迟。

## 7. 建表和加索引

- 每张表有主键，推荐自增 `bigint` 或有序的分布式 id；不要用随机 UUID 做主键。
- 金额用 `decimal`，不用 `float` / `double`。
- 加 `created_at` / `updated_at`，状态字段用 `tinyint` 并在注释里写明取值。
- 唯一性靠唯一索引保证，不要只靠代码里"先查后插"。

## 写完自查

- [ ] 没有用户输入进入 `${}`
- [ ] 没有 `SELECT *`
- [ ] WHERE 条件能走索引，没有函数和隐式转换
- [ ] 大表分页没有深 offset
- [ ] 循环里没有查库或写库
- [ ] `UPDATE` / `DELETE` 在条件为空时不会变成全表操作
