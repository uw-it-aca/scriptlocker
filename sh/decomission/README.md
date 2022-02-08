## decommision.sh

Produced a recipe for decomissioning an AXDD application.

Usage: <code>decommision *helm-values-yaml-file*</code>

When run from the root of the cloned app reposository and provided
an application's helm values, produces instructions for removing
kubernetes resources associated with the application as well as
pointers to external dependencies and resources.

NOTE, this script only examines application configuration and context
and provides steps neccessary for decommisioning.  It does not remove
or modify any resources, repositories or dependencies.

However, the script output is suitable for piping into bash which will
result in the deletion of all resources associated 

Dependencies are that suitable credentials configured for the various
pieces of application infrastructure and that the current kubernetes
context matches the deployment context expressed by the provided helm
values file.  Oh, and the script also requires that yq is installed.
