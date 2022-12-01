##########################################################################
##########################################################################
#--------------- This file contains all the IAM resources ---------------#
##########################################################################
##########################################################################

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "role-ecs-${local.prefix}"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": [
         "ecs-tasks.amazonaws.com",
         "ssm.amazonaws.com",
         "mediastore.amazonaws.com",
         "appmesh.amazonaws.com"
         ]
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ssm-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cloud-watch-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "envoy-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess"
}

resource "aws_iam_role_policy" "app_mesh_policy" {
  name = "policy-appmesh-${local.prefix}"
  role = aws_iam_role.ecs_task_execution_role.name
  policy = data.aws_iam_policy_document.appmesh_role_policy.json
}

resource "aws_iam_role_policy" "datadog_policy" {
  name = "datadog-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "ecs:ListClusters",
          "ecs:ListContainerInstances",
          "ecs:DescribeContainerInstances"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]
  })
}