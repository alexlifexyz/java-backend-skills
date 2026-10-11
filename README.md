# java-backend-skills

**中文 Java 后端 Agent Skills 合集。** 把 Java 后端里最常踩、最贵的坑写成 Agent 能照着做的 Skill：事务不生效、慢 SQL、线上排障、重复扣款、违反阿里规约。

[English](README.en.md)

![演示：写下单接口时，spring-transaction Skill 被自动触发，Agent 把 HTTP 扣库存和发 MQ 移出了事务](docs/demo.gif)

上图是一次真实的 Claude Code 会话（未剪辑，只压缩了等待时间）：只说了一句"写下单接口"，Skill 就自动加载，Agent 没有把 HTTP 调用和 MQ 放进 `@Transactional`，并说明了扣库存失败、消息丢失时怎么兜底。

SKILL.md 是通用格式，Claude Code、Codex、Cursor 等支持 Agent Skills 的工具都能用。

## 收录的 Skill

| Skill | 什么时候触发 | 解决什么 |
|---|---|---|
| [spring-transaction](skills/spring-transaction/SKILL.md) | 写 `@Transactional`、事务没回滚 | 自调用失效、受检异常不回滚、事务里调远程接口和发消息 |
| [mybatis-sql](skills/mybatis-sql/SKILL.md) | 写 Mapper、SQL、分页、批量操作、建表 | `${}` 注入、`SELECT *`、索引失效、深分页、N+1、空条件全表更新 |
| [arthas-troubleshooting](skills/arthas-troubleshooting/SKILL.md) | 线上 CPU 高、接口慢、死锁、内存涨 | 用 Arthas 按症状定位；每条命令都能自己结束，改动操作先问你 |
| [api-idempotency](skills/api-idempotency/SKILL.md) | 下单、支付、回调、MQ 消费 | 幂等键怎么选、唯一索引和状态机兜底、先查后插的并发坑 |
| [alibaba-java-guidelines](skills/alibaba-java-guidelines/SKILL.md) | 写或审查任何 Java 代码 | 高频规约要点 + **写完用真实 p3c 规则检查**，不靠模型记忆 |

每个 Skill 末尾都有一份"写完自查"清单，Agent 交付前会逐条对照。

## 安装

**Claude Code**

```
/plugin install java-backend-skills --marketplace alexlifexyz/java-backend-skills
```

**其他工具**：把 `skills/` 下需要的目录复制到对应工具的 Skills 目录即可，每个目录都是独立的。

## 和普通"规约 Skill"有什么不同

只把规约写给模型读，模型记得时有用，忘了就漏。`alibaba-java-guidelines` 自带一个检查脚本，写完代码后运行真实的 p3c 规则（PMD 实现），结果是确定的：同样的代码每次检查结果都一样。需要 JDK 21 以上。

在 Claude Code 里还可以再装配套的 [p3c-guard](https://github.com/alexlifexyz/p3c-guard)：每次写入 `.java` 文件前自动检查，新增违规的写入直接被拒绝。

## 写法约定

- 中文优先，面向国内 Java 后端的真实场景。
- 每条建议都要能落到代码上：给出改法或示例，不写空话。
- 会改变线上状态、不能撤回的操作，Skill 里写明"先问用户"。
- 不复制《阿里巴巴 Java 开发手册》原文，只用自己的话总结并链接官方来源。

欢迎提 issue 和 PR：你踩过的坑、想要的新 Skill、Skill 触发不准的例子都可以。

## 许可

MIT，见 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。
