## .docker_aliases

To install, copy this file to your home directory and add the line ". .k8s_aliases" to the .bash_aliases file also in your home directory.

| Alias | Result | Explanation/Example |
| --- | --- | --- |
| <code>dcu</code> | <code>docker-compose up --build</code> | |
| <code>dr</code> | <code>docker-compose down && docker-compose up --build</code> | Restarts docker container |
| <code>dx</code> | <code>docker exec -ti</code> | |
| <code>dxm</code> | <code>docker exec -ti</code> container <code>bin/python manage.py</code> ... | <code>dxm spotseeker-server shell</code> instead of <code>docker exec -ti spotseeker-server bin/python manage.py shell</code> |

