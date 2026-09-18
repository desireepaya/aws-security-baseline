data "aws_iam_user" "break_glass" {
  user_name = "break-glass"
}

resource "aws_iam_role" "break_glass_admin_role" {
  name        = "break_glass_admin_role"
  description = "Emergency access role for admin access when IDC is unavailable"
  assume_role_policy = templatefile("${path.module}/policies/break_glass_trust_policy.json.tpl", {
    break_glass_arn = data.aws_iam_user.break_glass.arn
  })
}

resource "aws_iam_role_policy_attachment" "break_glass_role_attachment" {
  role       = aws_iam_role.break_glass_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}







