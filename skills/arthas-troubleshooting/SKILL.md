---
name: arthas-troubleshooting
description: Java 服务线上出问题时使用：CPU 飙高、接口变慢、请求卡住或死锁、内存持续上涨、频繁 GC、怀疑线上代码版本不对、想看某个方法的入参和返回值。用阿里 Arthas 在不重启、不改代码的情况下定位，也适用于只问排查步骤的情况。Use when a live Java service has high CPU, slow endpoints, deadlocks or memory growth, including when only asked how to investigate.
---

# 用 Arthas 排查线上 Java 问题

Arthas 能在不重启、不改代码的情况下，查看正在运行的 JVM。Agent 使用时有两条硬要求：

1. **每条命令都要能自己结束。** Agent 没法按 Ctrl+C，所以 `watch`、`trace`、`monitor`、`dashboard` 都必须带 `-n` 次数限制。
2. **先只读，后改动。** `retransform`、`redefine`、`ognl` 修改状态、`vmtool` 强制 GC 这类会改变进程的命令，必须先问用户。

## 0. 连上目标进程

```bash
# 找进程
jps -l

# 下载并以非交互方式执行一条命令（-c 执行命令后退出）
curl -sSLO https://arthas.aliyun.com/arthas-boot.jar
java -jar arthas-boot.jar <pid> -c "dashboard -n 1"
```

- 必须用和目标进程**相同的用户**启动，否则连不上。
- 容器里先 `kubectl exec` / `docker exec` 进入容器再执行。
- 多条命令用分号连接：`-c "thread -n 3; memory"`。

## 1. 按症状选命令

| 症状 | 先跑 | 再看 |
|---|---|---|
| CPU 飙高 | `thread -n 3`（最忙的 3 个线程和它们的栈） | 栈顶在业务代码就看那段逻辑；在 GC 线程就转去查内存 |
| 线程卡住、请求不返回 | `thread -b`（找出持有锁、阻塞其他线程的线程） | `thread --state BLOCKED` 看还有谁在等 |
| 某个接口慢 | `trace com.example.OrderService create -n 5 '#cost > 200'` | 按耗时最长的子调用继续往下 `trace` |
| 想看入参、返回值、异常 | `watch com.example.OrderService create '{params, returnObj, throwExp}' -x 2 -n 5` | 只看异常时加 `-e` |
| 方法调用量和失败率 | `monitor -c 10 -n 6 com.example.OrderService create` | 每 10 秒输出一次，共 6 次 |
| 内存一直涨 | `memory`，再 `dashboard -n 1` 看 GC 次数 | 需要堆转储时先问用户（见第 3 节） |
| 怀疑线上跑的不是最新代码 | `jad com.example.OrderService` 反编译看实际代码 | `sc -d com.example.OrderService` 看是哪个 jar 加载的 |
| 想临时调日志级别 | `logger` 查看，`logger --name com.example --level debug` 修改 | 修改属于改动操作，先问用户，查完改回去 |

类名不确定时，先用 `sc *OrderService*` 搜索，`sm com.example.OrderService` 列出方法。

## 2. 读结果的要点

- `thread -n` 里的 CPU 占比是采样区间内的值，可以连续跑两三次确认是不是同一个线程。
- `trace` 只显示被增强的那一层调用，耗时大头在哪个子方法，就对那个方法再 `trace` 一次，逐层往下找。
- `watch` 的 `-x 2` 是对象展开深度，对象很大时调小，避免输出刷屏。
- `#cost > 200` 这类条件表达式能过滤掉正常请求，只留下慢的那几次。

## 3. 需要先问用户的操作

- `heapdump /tmp/heap.hprof`：会触发 Full GC 并暂停进程，堆越大停得越久，还会占用和堆差不多大的磁盘空间。
- `profiler start` / `profiler stop`：采样期间有额外开销，生成火焰图前说明采样时长。
- `retransform`、`redefine`：热替换线上代码，只能临时救急，重启后失效，还可能和其他增强冲突。
- `ognl` 调用会改变状态的方法。

## 4. 收尾

- 排查结束执行 `reset`，撤销所有类增强；再执行 `stop` 退出 Arthas。
- 把结论写清楚：现象、用了哪几条命令、关键输出、根因、建议怎么改代码。不要只贴一大段命令输出。

## 排查自查

- [ ] 每条 `watch` / `trace` / `monitor` 都带了 `-n`
- [ ] 改变进程状态的命令都先问过用户
- [ ] 结束时执行了 `reset` 和 `stop`
- [ ] 结论里有根因和修改建议，不只是现象
