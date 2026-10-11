---
name: spring-transaction
description: 写或改 Spring / Spring Boot 中带数据库写操作的代码时使用：@Transactional 放在哪、为什么没生效、回滚规则、事务里能不能调远程接口或发消息、事务提交后再做的事。Use when writing or reviewing Spring @Transactional code, or when a transaction did not roll back.
---

# Spring 事务：写对 @Transactional

写 Service 层的数据库写操作时，按下面的顺序检查。每一条都对应线上真实出过的事故。

## 1. 先确认事务会生效

`@Transactional` 靠 Spring AOP 代理生效。以下几种情况，注解写了也**不会**开事务：

| 情况 | 为什么 | 改法 |
|---|---|---|
| 同一个类里，A 方法调用带注解的 B 方法（`this.b()`） | 调用没经过代理 | 把 B 挪到另一个 Bean；或注入自身代理再调用 |
| 注解在 `private`、`final`、`static` 方法上 | 代理无法覆盖这些方法 | 改成 `public` 非 final 方法 |
| 类没被 Spring 管理（自己 `new` 出来的） | 根本没有代理 | 交给容器注入 |
| 方法里自己 `try/catch` 把异常吞了 | 代理看不到异常，照常提交 | 处理后重新抛出，或调用 `TransactionAspectSupport.currentTransactionStatus().setRollbackOnly()` |

写完后自问一句：**调用这个方法的地方，是不是从别的 Bean 进来的？**

## 2. 回滚规则要写明

- 默认只在 `RuntimeException` 和 `Error` 时回滚，**受检异常（如 `IOException`）不回滚**。
- 项目里只要有方法会抛受检异常，就写 `@Transactional(rollbackFor = Exception.class)`，不要依赖默认值。

## 3. 事务里不要做"慢"和"不能撤回"的事

事务开着的时候，数据库连接和行锁一直被占着。不要在事务方法里：

- 调用 HTTP / RPC 远程接口（对方慢，你的连接池就被拖满）；
- 发 MQ 消息、发短信、发邮件（事务回滚了，消息却已经发出去了）；
- 做大文件读写、大循环计算。

需要在提交成功后再做的事，用以下任一方式：

```java
// 方式一：事务提交后回调
TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
    @Override
    public void afterCommit() {
        orderEventPublisher.publish(orderId);
    }
});

// 方式二：Spring 事件 + 提交后监听
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
public void onOrderCreated(OrderCreatedEvent event) { ... }
```

要求"本地写库"和"发消息"必须同时成功时，用本地消息表或事务消息，不要指望一个 `@Transactional` 搞定。

## 4. 事务范围尽量小

- 注解放在 Service 方法上，不放在 Controller 上，也不要整个类一把梭。
- 只读查询不需要事务；需要一致性读时用 `@Transactional(readOnly = true)`。
- 一个方法里前半段在查、算、调外部接口，后半段才写库：把写库部分抽成单独的事务方法（注意第 1 条，要跨 Bean 调用）。

## 5. 传播行为只在需要时改

- 默认 `REQUIRED` 能覆盖绝大多数场景。
- `REQUIRES_NEW`：用于"不管外层成败都要记下来"的操作，比如操作日志、失败记录。它会再占一个连接，循环里调用会很快耗尽连接池。
- 不确定时不要改传播行为，在代码注释里写清楚为什么改。

## 写完自查

- [ ] 事务方法是 `public` 的，并且是从别的 Bean 调进来的
- [ ] 写了 `rollbackFor = Exception.class`（或确认不会抛受检异常）
- [ ] 事务里没有远程调用、发消息
- [ ] 没有 `catch` 后不抛出的异常
- [ ] 改了传播行为的地方有注释说明原因
