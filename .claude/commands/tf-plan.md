---
name: tf-plan
description: Run Terraform plan with proper workflow
---

Run Terraform plan for: $ARGUMENTS

If no directory specified, default to `terraform/talos`.

## Workflow

1. **Verify directory**
   ```bash
   ls -la {directory}/*.tf
   ```

2. **Check git status**
   ```bash
   git status {directory}/
   ```

3. **Initialize**
   ```bash
   cd {directory} && terraform init -upgrade
   ```

4. **Validate**
   ```bash
   cd {directory} && terraform validate
   ```

5. **Plan with output file**
   ```bash
   cd {directory} && terraform plan -out=tfplan
   ```

## Output

After running the plan, provide:

1. **Summary**: X to add, Y to change, Z to destroy
2. **Additions**: List any new resources being created
3. **Changes**: List resources being modified and what's changing
4. **Destructions**: **HIGHLIGHT** any resources being destroyed
5. **Next Steps**:
   - If changes look good: "Run /tf-apply to apply these changes"
   - If destruction involved: "Review carefully before applying"
   - If no changes: "Infrastructure is up to date"
