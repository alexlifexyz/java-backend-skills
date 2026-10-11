---
name: alibaba-java-guidelines
description: 写、改或审查 Java 代码时使用，让代码符合阿里巴巴 Java 开发手册（p3c）的常见要求，并在写完后用 p3c 规则做一次确定性检查，而不是只靠记忆。Use when writing or reviewing Java code that should follow the Alibaba Java Coding Guidelines (p3c); runs the real p3c rules afterwards.
---

# 阿里 Java 规约：写的时候注意，写完用规则查

这个 Skill 分两步：写代码时先避开最常见、最容易出事的问题；写完后**运行 p3c 规则检查**，用结果说话。只读规约容易漏，规则检查每次结果都一样。

完整规约以官方手册为准：<https://github.com/alibaba/p3c>。下面是用自己的话整理的高频要点，不是手册原文。

## 1. 写的时候优先注意这些

**并发**
- 线程池用 `new ThreadPoolExecutor(...)` 显式指定核心线程数、最大线程数、**有界队列**和拒绝策略，不用 `Executors` 的快捷方法（它们的队列或线程数是无界的）。
- 线程和线程池要有带业务含义的名字，出问题时 `jstack` 才看得懂。
- `SimpleDateFormat` 不是线程安全的，不要做成静态共享变量；新代码用 `DateTimeFormatter`。
- `ThreadLocal` 用完在 `finally` 里 `remove()`，线程池复用线程时会串数据。
- `lock()` 之后紧跟 `try`，`unlock()` 放 `finally`。

**比较和集合**
- 包装类型（`Integer`、`Long` 等）比较用 `Objects.equals(a, b)`，不要用 `==`，小数值时碰巧相等，大了就不等。
- 浮点数不用 `==` 比较；金额用 `BigDecimal`，并用 `compareTo` 比较大小。
- `foreach` 循环里不要增删集合元素，用 `Iterator.remove()` 或 `removeIf`。
- `Arrays.asList` 返回的列表不能增删；`subList` 是原列表的视图，原列表改了它就失效。
- 知道大小时，初始化集合时指定容量。

**异常和日志**
- 不要捕获异常后什么都不做；要么处理，要么带上原异常重新抛出。
- `finally` 里不要 `return`，会吞掉 `try` 里的返回值和异常。
- 日志用 SLF4J 门面和占位符：`log.info("order {} paid", orderNo)`，不要字符串拼接。异常要作为最后一个参数传进去，保留堆栈。

**命名和代码风格**
- 类名大驼峰，方法和变量小驼峰，常量全大写下划线分隔。
- 布尔类型的 POJO 字段不要加 `is` 前缀，部分序列化框架会解析错字段名。
- POJO 类属性用包装类型，避免数据库的 `null` 被默认成 `0`。
- 不要在代码里直接写没有含义的数字或字符串（魔法值），提成常量。

## 2. 写完运行规则检查

本 Skill 自带脚本，用 p3c 规则（PMD 实现）检查文件或目录。需要 JDK 21 以上和 `curl`，第一次运行会从 Maven Central 下载约 13 MB 的规则包（带 SHA-256 校验），之后走缓存。

```bash
# 检查改动过的文件
sh <本 Skill 目录>/scripts/p3c-check.sh src/main/java/com/example/OrderService.java

# 检查整个目录
sh <本 Skill 目录>/scripts/p3c-check.sh src/main/java
```

- 退出码 `0`：没有问题；`4`：发现违规，每行格式是 `文件:行号: 规则名: 说明`。
- 默认只报第 1、2 级（严重）问题。要连魔法值、缺 `@author` 等第 3 级一起查：`P3C_PRIORITY=3 sh .../p3c-check.sh ...`。

拿到结果后：

1. 只修**这次改动引入的**问题。文件里原有的历史违规，除非用户要求，不要顺手改，以免把改动范围变大。
2. 修完再跑一次，直到这次改动不再新增违规。
3. 如果某条规则和项目自身约定冲突，以项目约定为准，并告诉用户。

没有 JDK 21 或无法联网时，说明检查没有运行，不要声称代码已通过检查。

## 3. 想要每次写入都自动拦截

在 Claude Code 里，可以安装配套的 Mod [p3c-guard](https://github.com/alexlifexyz/p3c-guard)：Agent 每次写 `.java` 文件之前自动检查，新增违规的写入会被直接拒绝，不需要记得去跑脚本。

## 写完自查

- [ ] 运行了 `p3c-check.sh`，这次改动没有新增第 1、2 级违规
- [ ] 线程池、包装类比较、`SimpleDateFormat`、`ThreadLocal` 没有踩坑
- [ ] 没有吞异常，日志用了占位符
- [ ] 检查没能运行时，已如实告诉用户
