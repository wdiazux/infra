---
name: deploy-service
description: Deploy a new service to the Kubernetes cluster
---

Deploy new service: $ARGUMENTS

Use the **service-deployer** sub-agent to guide through the complete deployment workflow.

```
Use the service-deployer agent to deploy: $ARGUMENTS

The agent will walk through each step of the deployment checklist:
1. Planning (namespace, IP allocation, requirements)
2. Creating manifests (deployment, service, configmap, secrets)
3. Integration (kustomization, CLAUDE.md, homepage)
4. Deployment (commit, flux reconcile, verification)

Follow the agent's guidance and confirm each step.
```

If the user hasn't specified what service to deploy, ask them:
- What service/application do you want to deploy?
- Do you have a container image in mind?
- What namespace should it be in?
