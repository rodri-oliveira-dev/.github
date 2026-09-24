# Sonar Quality Issues project sync

This automation keeps open issues labeled `Sonar Quality Issues` from repositories owned by `rodri-oliveira-dev` in personal Project #1.

## Behavior

The workflow:

1. Resolves personal Project #1.
2. Creates the `Sonar Quality Issues` table view when it does not exist.
3. Keeps that view filtered by:
   `is:issue is:open label:"Sonar Quality Issues"`
4. Searches all repositories owned by the account with:
   `is:issue is:open user:rodri-oliveira-dev label:"Sonar Quality Issues"`
5. Adds only issues that are not already present in the Project.
6. Runs daily at 06:00 America/Sao_Paulo and can also be started manually.

Closed issues remain in the Project history but disappear from the dedicated view because the view is filtered with `is:open`.

## Authentication

Create a repository secret named `PROJECTS_TOKEN` in `rodri-oliveira-dev/.github`.

Use a **classic personal access token** with the `project` scope. The current GitHub API for user-owned Projects does not support fine-grained personal access tokens or GitHub App tokens for these operations.

If private repositories should also participate in the global search, grant the classic token the additional repository access required for those repositories.

Do not store the token in the repository, workflow file, variables, logs, or documentation.

## Manual execution

Open **Actions > Sync Sonar issues to project > Run workflow**.

The run summary reports the Project and view links, number of matching issues, newly added issues, already-present issues, and failures.
