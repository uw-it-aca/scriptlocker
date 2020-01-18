# Useful Shell Scripts

## .k8s_aliases

    Small set of aliases for convenient kubectl interaction and
    visible context in the command prompt.  For most, type the 
    alias alone for a list of relevant items that you can reference
    in followup commands by index.  K8s names and kubectl command
    line options should work as you expect as well.

    * `kcfg` - kubectl config
    * `kg` - kubectl get
    * `kgp` - kubectl get pod[s]
    * `ksh` - kubectl exec
    * `kl` - kubectl logs

    A few docker aliases are thrown in as well, but they don't offer
    object lists by default yet

    * `dps` - docker ps
    * `dls` - docker image ls
    * `dkill` - docker kill
    * `drmi` - docker rmi
