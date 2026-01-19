# TFLint configuration
# See: https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/config.md

config {
  # Enable module inspection
  call_module_type = "local"

  # Force to return error code when issues found
  force = false
}

# Enable the Terraform ruleset
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Naming conventions
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Documented variables
rule "terraform_documented_variables" {
  enabled = true
}

# Documented outputs
rule "terraform_documented_outputs" {
  enabled = true
}

# Standard module structure
rule "terraform_standard_module_structure" {
  enabled = true
}

# Require version constraints for providers
rule "terraform_required_providers" {
  enabled = true
}

# Unused declarations
rule "terraform_unused_declarations" {
  enabled = true
}

# Workspace naming
rule "terraform_workspace_remote" {
  enabled = false  # Not using Terraform Cloud
}
