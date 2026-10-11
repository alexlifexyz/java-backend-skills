---
name: api-idempotency
description: 写下单、支付、扣库存、发券、回调通知、MQ 消费等"重复执行会出事"的接口或消费者时使用，设计幂等、防重复提交和安全重试。Use when building Java endpoints, payment callbacks or MQ consumers that must not double-charge or double-process on retries.
---

# 接口幂等：重复请求不能重复扣钱

网络超时重试、用户连点、MQ 重复投递、第三方回调重发，都会让同一个请求到达不止一次。写下面这类代码时，**默认它会被执行两次**：

- 创建订单、支付、退款、扣库存、发券、加积分
- 第三方支付或物流的回调
- MQ 消费者、定时任务

## 1. 先找到"幂等键"

幂等键是能唯一标识"同一件事"的值，必须由**调用方**提供或从业务中自然得出：

| 场景 | 幂等键 |
|---|---|
| 前端提交订单 | 进入下单页时服务端发放的 token，或客户端生成的请求 id |
| 支付回调 | 第三方的交易流水号 |
| MQ 消费 | 业务 id（订单号等），不要用 MQ 的 messageId，重发时它可能变 |
| 内部服务调用 | 调用方传入的 requestId |

不要用"当前时间"或服务端随机数做幂等键，那样每次重试都是新键。

## 2. 选一种实现方式

按可靠程度从高到低：

**方式一：唯一索引（首选）**

```sql
ALTER TABLE t_order ADD UNIQUE KEY uk_request_id (request_id);
```

```java
try {
    orderMapper.insert(order);
} catch (DuplicateKeyException e) {
    // 已经处理过，返回第一次的结果，而不是报错
    return orderMapper.selectByRequestId(order.getRequestId());
}
```

数据库保证唯一，不怕并发。

**方式二：状态机 + 条件更新**

```sql
UPDATE t_order SET status = 'PAID', paid_at = NOW()
WHERE order_no = #{orderNo} AND status = 'UNPAID';
```

影响行数为 0，说明已经处理过或状态不对，直接返回当前状态。适合支付回调、状态流转。

**方式三：防重表 / Redis 记录**

处理前写入幂等键，写入失败说明正在处理或已处理：

```java
Boolean first = redis.opsForValue().setIfAbsent("idem:" + key, "PROCESSING", Duration.ofHours(24));
if (!Boolean.TRUE.equals(first)) {
    return queryPreviousResult(key);
}
```

注意：Redis 记录和业务写库不在一个事务里。业务失败时要删除记录，允许重试；过期时间要长于调用方的最大重试窗口。对资金类操作，Redis 只能做第一道拦截，最终仍要靠方式一或方式二兜底。

## 3. 常见错误

- **先查后插**：`if (selectByRequestId(id) == null) insert(...)`。两个并发请求会同时查到"不存在"，然后都插入。必须配合唯一索引。
- **重复请求返回报错**：调用方会以为失败而再次重试。第二次请求应该返回和第一次**相同的结果**。
- **分布式锁代替幂等**：锁只能防止"同时"执行，不能防止"先后"执行两次。锁可以减少并发冲突，但幂等仍要靠唯一键或状态判断。
- **只在接口层做幂等**：消费者、定时任务、回调处理同样需要。

## 4. 前端防重只是体验优化

按钮置灰、防抖能减少重复点击，但挡不住网络重试和脚本调用。服务端必须自己保证幂等。

## 写完自查

- [ ] 明确了幂等键，且来自调用方或业务本身
- [ ] 有唯一索引或条件更新兜底，不只靠"先查后插"
- [ ] 重复请求返回第一次的结果，而不是报错
- [ ] MQ 消费者和回调也做了幂等
- [ ] 用 Redis 防重时，业务失败会清理记录
