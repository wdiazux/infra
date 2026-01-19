---
name: tf-apply
description: Apply Terraform changes safely
---

Apply Terraform changes for: $ARGUMENTS

If no directory specified, default to `terraform/talos`.

## Pre-flight Checks

1. **Check for plan file**
   ```bash
   ls -la {directory}/tfplan 2>/dev/null
   ```

   If no plan file exists:
   - Tell the user: "No plan file found. Run /tf-plan first to review changes."
   - Do NOT proceed with apply

2. **Show plan summary**
   ```bash
   cd {directory} && terraform show tfplan
   ```

3. **Ask for confirmation**
   Before applying, explicitly ask: "Do you want to apply these changes? (yes/no)"

## Apply (only after confirmation)

4. **Apply the plan**
   ```bash
   cd {directory} && terraform apply tfplan
   ```

5. **Verify success**
   ```bash
   cd {directory} && terraform output
   ```

6. **Cleanup**
   ```bash
   rm {directory}/tfplan
   ```

## Output

After applying:
- Confirm success or report any errors
- Show relevant outputs
- Suggest verification steps (e.g., check kubectl, test connectivity)
