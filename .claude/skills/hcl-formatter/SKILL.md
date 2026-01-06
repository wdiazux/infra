# HCL Formatter Skill

Formats all HCL files (Packer and Terraform) in the project using official HashiCorp formatting tools.

## Purpose

This skill ensures all HCL code follows the official HashiCorp Style Guide for consistent, readable infrastructure code.

## When to Use

Invoke this skill when:
- Formatting Packer template files (`*.pkr.hcl`)
- Formatting Terraform configuration files (`*.tf`)
- Cleaning up HCL code style before committing
- After manual edits or refactoring
- Running `/fmt-hcl` command

## What This Skill Does

1. **Packer Formatting**
   - Formats all Packer templates in `packer/` subdirectories
   - Validates syntax after formatting

2. **Terraform Formatting**
   - Recursively formats all Terraform files
   - Validates configurations after formatting

3. **Reporting**
   - Lists all modified files
   - Reports any validation errors

## Instructions

When formatting HCL files, execute these commands:

### Format Packer Templates

```bash
cd /home/wdiaz/devland/infra/packer

# Format each OS template
for dir in talos ubuntu debian arch nixos windows; do
  if [ -d "$dir" ]; then
    echo "Formatting packer/$dir..."
    packer fmt "$dir/"
  fi
done
```

### Format Terraform Files

```bash
cd /home/wdiaz/devland/infra/terraform
echo "Formatting terraform/..."
terraform fmt -recursive
```

### Validate After Formatting

```bash
cd /home/wdiaz/devland/infra/packer

# Validate each template
for dir in talos ubuntu debian arch nixos windows; do
  if [ -d "$dir" ] && ls "$dir"/*.pkr.hcl 1>/dev/null 2>&1; then
    echo "Validating packer/$dir..."
    (cd "$dir" && packer validate .) || echo "Warning: $dir validation failed"
  fi
done

# Validate Terraform
cd /home/wdiaz/devland/infra/terraform
terraform validate
```

## Output

Report:
- Number of files formatted
- Any validation warnings or errors
- Confirmation of completion
