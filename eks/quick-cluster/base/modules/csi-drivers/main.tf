################################################################################
# FSx for Lustre CSI Driver (Helm)
# EBS and EFS CSI are handled via EKS managed addons in the root module
################################################################################

locals {
  oidc_issuer = replace(var.oidc_provider_url, "https://", "")
}

resource "aws_iam_role" "fsx_csi" {
  count = var.enable_fsx ? 1 : 0
  name  = "${var.cluster_name}-fsx-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:sub" = "system:serviceaccount:kube-system:fsx-csi-controller-sa"
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fsx_csi" {
  count      = var.enable_fsx ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonFSxFullAccess"
  role       = aws_iam_role.fsx_csi[0].name
}

resource "helm_release" "fsx_csi" {
  count = var.enable_fsx ? 1 : 0

  name       = "aws-fsx-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-fsx-csi-driver"
  chart      = "aws-fsx-csi-driver"
  namespace  = "kube-system"
  timeout    = 300
  wait       = true

  set = [
    {
      name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.fsx_csi[0].arn
    },
  ]
}
