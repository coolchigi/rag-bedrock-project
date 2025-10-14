# Contributing to RAG Bedrock Project

Thank you for your interest in contributing to this project! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected behavior**
- **Actual behavior**
- **Environment details** (Terraform version, AWS region, etc.)
- **Error messages** or logs
- **Screenshots** if applicable

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- **Clear description** of the proposed feature
- **Use cases** and benefits
- **Potential implementation approach**
- **Any alternatives** you've considered

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Make your changes** following the coding standards below
3. **Test your changes** thoroughly
4. **Update documentation** as needed
5. **Submit a pull request** with a clear description

## Development Setup

### Prerequisites

- Terraform >= 1.0
- AWS CLI configured with credentials
- Git

### Getting Started

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/rag-bedrock-project.git
cd rag-bedrock-project

# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes
# ...

# Test your changes
terraform init
terraform validate
terraform fmt -check

# Commit and push
git add .
git commit -m "Description of your changes"
git push origin feature/your-feature-name
```

## Coding Standards

### Terraform

1. **Format code** using `terraform fmt`
   ```bash
   terraform fmt -recursive
   ```

2. **Validate configuration**
   ```bash
   terraform validate
   ```

3. **Use meaningful names** for resources
   - Resource names: lowercase with underscores (`aws_s3_bucket.knowledge_base_bucket`)
   - Variable names: lowercase with underscores (`s3_bucket_name`)

4. **Add descriptions** to all variables and outputs

5. **Use tags** consistently on all resources:
   ```hcl
   tags = {
     Name        = "Resource Name"
     Environment = var.environment
     Project     = "RAG-Bedrock"
   }
   ```

6. **Document resources** with comments for complex configurations

7. **Use variables** for configurable values, not hardcoded strings

### Shell Scripts

1. **Include shebang**: `#!/bin/bash`
2. **Exit on error**: `set -e`
3. **Quote variables**: `"$VARIABLE"`
4. **Add error messages** for user-facing scripts
5. **Include usage examples** in comments or help text

### Python

1. **Follow PEP 8** style guide
2. **Add docstrings** to functions and modules
3. **Handle exceptions** appropriately
4. **Include type hints** where helpful

### Documentation

1. **Use clear language** and proper grammar
2. **Include code examples** where applicable
3. **Keep README updated** with new features
4. **Add comments** for complex code sections
5. **Update TROUBLESHOOTING.md** for new issues discovered

## Testing

Before submitting a pull request:

1. **Terraform validation**:
   ```bash
   terraform init
   terraform validate
   terraform fmt -check
   ```

2. **Test deployment** (if possible):
   ```bash
   terraform plan
   # Optionally: terraform apply in a test AWS account
   ```

3. **Test scripts**:
   ```bash
   chmod +x scripts/*.sh
   # Verify scripts run without errors (syntax check)
   bash -n scripts/*.sh
   ```

4. **Documentation review**:
   - Check for broken links
   - Verify code examples work
   - Ensure formatting is correct

## Project Structure

```
rag-bedrock-project/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example variables file
├── deploy.sh                  # Deployment script
├── README.md                  # Main documentation
├── ARCHITECTURE.md            # Architecture overview
├── TROUBLESHOOTING.md         # Troubleshooting guide
├── CONTRIBUTING.md            # This file
├── LICENSE                    # License information
├── scripts/                   # Helper scripts
│   ├── upload-to-s3.sh
│   ├── sync-knowledge-base.sh
│   └── query-knowledge-base.sh
└── examples/                  # Example code
    ├── query_kb.py
    └── README.md
```

## What to Contribute

### High-Priority Areas

- [ ] Automated testing framework
- [ ] CloudWatch dashboards for monitoring
- [ ] Lambda function for automatic S3 sync
- [ ] API Gateway integration
- [ ] Web UI example
- [ ] Additional programming language examples (Node.js, Go, Java)
- [ ] Performance optimization tips
- [ ] Cost optimization strategies

### Medium-Priority Areas

- [ ] Support for additional vector databases (Pinecone, Weaviate)
- [ ] Multi-region deployment
- [ ] Backup and disaster recovery procedures
- [ ] CI/CD pipeline examples
- [ ] Docker containers for deployment
- [ ] Kubernetes deployment manifests

### Documentation Improvements

- [ ] Video tutorials
- [ ] Architecture diagrams (visual)
- [ ] Blog post tutorials
- [ ] Real-world use case examples
- [ ] FAQ section
- [ ] Comparison with other RAG solutions

## Commit Message Guidelines

Use clear, descriptive commit messages:

```
feat: Add support for Pinecone vector database
fix: Correct IAM policy for S3 bucket access
docs: Update README with deployment examples
refactor: Simplify OpenSearch configuration
test: Add validation for Terraform modules
chore: Update Terraform provider version
```

Prefixes:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

## Review Process

1. **Automated checks** run on all pull requests
2. **Manual review** by maintainers
3. **Feedback and iteration** as needed
4. **Merge** once approved

## Release Process

This project follows semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

## Questions?

- **Open an issue** for questions about contributing
- **Discussion forum** for general questions about usage
- **Email maintainers** for sensitive topics

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

## Recognition

Contributors will be recognized in:
- GitHub contributors list
- Release notes
- README acknowledgments section (for significant contributions)

Thank you for contributing to make this project better! 🎉
