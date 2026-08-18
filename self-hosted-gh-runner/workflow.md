1. create a gihub pat access to access the repository and manage runners. You can create a personal access token (PAT) by following these steps:

   - Go to your GitHub account settings.
   - Navigate to "Developer settings" and then "Personal access tokens."
   - Click on "Generate new token."
   - Select the necessary scopes for your token, such as `repo` for repository access and `admin:repo_hook` for managing webhooks.
   - Click "Generate token" and copy the token to a secure location.
   CMD:
    aws secretsmanager create-secret \
  --name "github/runner-pat" \
  --secret-string "github_pat_11AAA..." \
  --region ap-south-1

  {
    "ARN": "arn:aws:secretsmanager:ap-south-1:889867978066:secret:github/runner-pat-jVcp7l",
    "Name": "github/runner-pat",
    "VersionId": "9689fd0b-f42d-4003-ac1a-6c18b055ed66"
}
