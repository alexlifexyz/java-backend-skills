# java-backend-skills

**Agent skills for Java backend work, written Chinese-first.** Each skill turns a costly, common backend mistake into steps an agent can follow: transactions that silently do nothing, slow SQL, live JVM troubleshooting, double charges on retries, and Alibaba Java Coding Guidelines (p3c) violations.

[中文](README.md)

![Demo: asked to write an order endpoint, Claude loads spring-transaction and keeps the HTTP call and MQ send out of the transaction](docs/demo.gif)

SKILL.md is a shared format, so the skills work in Claude Code, Codex, Cursor and other tools that support Agent Skills.

| Skill | Use it when |
|---|---|
| [spring-transaction](skills/spring-transaction/SKILL.md) | Writing `@Transactional` code, or a transaction did not roll back |
| [mybatis-sql](skills/mybatis-sql/SKILL.md) | Writing MyBatis mappers, SQL, pagination, batch writes or tables |
| [arthas-troubleshooting](skills/arthas-troubleshooting/SKILL.md) | Diagnosing a live JVM with Arthas: high CPU, slow methods, deadlocks, memory growth |
| [api-idempotency](skills/api-idempotency/SKILL.md) | Building orders, payments, callbacks or MQ consumers that must survive retries |
| [alibaba-java-guidelines](skills/alibaba-java-guidelines/SKILL.md) | Writing or reviewing Java; runs the real p3c rules afterwards (JDK 21+) |

## Install

Claude Code:

```
/plugin install java-backend-skills --marketplace alexlifexyz/java-backend-skills
```

Other tools: copy the folders you want from `skills/` into the tool's skills directory.

For enforcement on every write in Claude Code, see the companion mod [p3c-guard](https://github.com/alexlifexyz/p3c-guard).

Not affiliated with or endorsed by Alibaba Group. MIT licensed.
