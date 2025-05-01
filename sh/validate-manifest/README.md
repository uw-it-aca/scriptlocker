## validate-manifest.sh

A simple script to locally generate and validate a k8s manifest that would
otherwise be created in the UW-IT SETS Engineering Group typical CICD pipeline.

The generated manifest is writen to a file for inspection which would otherwise be difficult within the CICD pipeline.

The script requires <code>docker</code> and <code>git</code> be installed locally.

The script is intended to run in the root directory of a typical SETS Engineering Group application.  By default, it looks for "test" instance helm values in <code>./docker/test-values.yml</code>.  Production values can be applied using the <code>-i prod</code> command line option.

In addition, it will look for helm templating in <code>../django-production-chart</code>, but failing that it will export a copy of the <code>django-production-chart</code> repo for templating reference.  The local template reference is useful for testing templating changes.
