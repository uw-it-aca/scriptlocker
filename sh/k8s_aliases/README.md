# .k8s_aliases

    Small set of aliases for convenient kubectl interaction and
    visible context in the command prompt. Copy this file to
    your home directory and add the line ". .k8s_aliases" to
    the .bash_aliases file also in your home directory.

    Most aliases support typing the name alone query your current
    index which can be used to reference the resources in subesequent
    commands.

    * `kh` - this help text

    * `k` - kubectl <arg list>
    * `kd` - kubectl describe <arg lists>
    * `kex` - kubectl explain <arg list>
    * `kg` - kubectl get <arg lists>
    * `kgp` - kubectl get pod [ <arg> ]
              where <arg> is pod id or index of listed pods
    * `ksh` - kubectl exec -it [ <arg> ]
              where <arg> is pod id string or index
    * `kl` - kubectl logs [ <arg list> ]
             where <arg_list> is pod or app label or index
             example:  kl -l app.kubernetes.io/name=infohub-prod-test -f
    * `kcfg` - kubectl config [use,get]-contexts <args>
               where <args> is context name or index of listed contexts

    There are also some Docker convenience aliases

    * `dps` - docker ps
    * `dls` - docker image ls
    * `dk` - docker kill <arg>
    * `dsh` - docker exec -it <arg> bash

    Other helpful commands:

    * kubectl logs -f -l name=flux -c flux -n mci-shared"
