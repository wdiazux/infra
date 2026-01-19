---
name: debug
description: Systematic troubleshooting for Kubernetes issues
---

Debug issue: $ARGUMENTS

Use the **k8s-debugger** sub-agent for systematic troubleshooting.

```
Use the k8s-debugger agent to investigate: $ARGUMENTS

The agent will follow a structured debugging workflow:
1. Initial assessment (cluster overview, problematic pods)
2. Identify the specific problem
3. Describe failing resources
4. Check logs (current and previous)
5. Check events
6. Check networking (services, endpoints)
7. Check storage (if applicable)
8. Summarize root cause and solution

Follow the agent's systematic approach.
```

If the user hasn't specified what to debug, ask them:
- What's the symptom? (pod not starting, service unreachable, etc.)
- Which namespace/service is affected?
- When did this start happening?
- Any recent changes?
