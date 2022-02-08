## .k8s_aliases

Small set of aliases for convenient kubectl interaction and
visible context in the command prompt. Copy this file to
your home directory and add the line ". .k8s_aliases" to
the .bash_aliases file also in your home directory.

Most aliases support typing the name alone query your current
index which can be used to reference the resources in subesequent
commands.

| Alias | Result |
| --- | --- |
| <code>kh</code> | help text |
| <code>k [ *arg* ... ]</code> | <code> kubectl [ *arg* ... ]</code> |
| <code>kd [ *arg* ... ]<code> | <code>kubectl describe [ *arg* ... ]<code> |
| <code>kex [ *arg* ... ]<code> | <code>kubectl explain [ *arg* ... ]<code> |
| <code>kg [ *arg* ... ]<code> | <code>kubectl get [ *arg* ... ]<code> |
| <code>kgp *arg*<code> | <code>kubectl get pod *arg*]<code><br>where *arg* is pod id or index of listed pods |
| <code>ksh *arg*<code> | <code>kubectl exec -it *arg* bash]<code><br>where *arg* is pod id or index of listed pods|
| <code>kl [ *arg* ... ]<code> | <code>kubectl logs [ *arg* ... ]<code>  example  <codekl -l app.kubernetes.io/name=infohub-prod-test -f</code>|
| <code>kl *arg*<code> | <code>kubectl config [use,get]-contexts *arg* bash]<code><br>where *arg* is context name or index of listed contexts |

There are also some Docker convenience aliases

| Alias | Docker Command |
| --- | --- |
| <code>dps [ *arg* ... ]]</code> | <code>docker ps [ *arg* ... ]</code> |
| <code>dls</code> | <code>docker image ls</code> |
| <code>dk [ *arg* ... ]</code> | <code>docker kill [ *arg* ... ]</code> |
| <code>dsh *arg*</code> | <code>docker exec -it *arg* -- bash</code> |

    Other helpful commands:

```
kl -f -l name=flux -c flux -n mci-shared
```
