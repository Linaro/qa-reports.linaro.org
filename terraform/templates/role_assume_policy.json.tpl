{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${openid_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${openid_provider_url}:sub": "system:serviceaccount:qareports-${environment}:qareports-serviceaccount"
        }
      }
    }
  ]
}
