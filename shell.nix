{
  system ? builtins.currentSystem,
}:
let
  pins = import ./npins { };
  pkgs = import pins.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    # Core Infrastructure Tools
    terraform                  # >= 1.14.2 - Infrastructure as Code
    packer                     # ~> 1.14.3 - Image building
    xorriso                    # ISO creation for Packer Windows builds
    ansible                    # >= 2.17.0 - Configuration management
    python3                    # >= 3.9 - Required for Ansible
    sshpass                    # SSH password authentication for Ansible

    # Secrets Management
    sops                       # Secrets encryption
    age                        # Encryption tool for SOPS

    # Talos & Kubernetes Tools
    talosctl                   # Talos Linux CLI
    kubectl                    # Kubernetes CLI
    kubecolor                  # Colorize kubectl output
    kubernetes-helm            # Helm package manager
    fluxcd                     # GitOps tool

    # Linters & Security Scanners
    tflint                     # Terraform linter
    terraform-docs             # Terraform documentation generator
    trivy                      # Security scanner
    ansible-lint               # Ansible linter
    yamllint                   # YAML linter

    # Automation
    pre-commit                 # Git hooks framework

    # Additional Utilities
    jq                         # JSON processor (useful for API interactions)
    yq-go                      # YAML processor
    openssl                    # Cryptographic toolkit (key/cert generation)
  ];
}
