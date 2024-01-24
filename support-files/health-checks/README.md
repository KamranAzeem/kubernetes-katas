# About
This repository contains support files to demonstrate how Kubernetes probes work. It uses a container image named `wbitt/k8s-probes-demo`. This container image can be used as a simple container running NGINX web server on port 80, and the same can be used to run in "troublemaker" mode, as side-car, which tries to disrupt the readiness probes being run in the main container.

* The readiness probe is assumed to be "GET /readinesscheck.txt" .
* The livenesss probe is assumed to be "GET /livenesscheck.txt" .
* The startup probe is assumed to be "GET /startupcheck.txt" .


## How to use this:
If you run this image without any ENV variables, it will simply start a NGINX web-server on port 80, with a simple/custom/one-liner web page. If you set `START_DELAY` to some number of seconds, the container simply starts the web service *after* those number of seconds have passed. This is to mimic a slow starting container, such as Apache Tomcat, Atlassian Jira/Confluence, etc.

You can then use "readiness probes" in the related kubernetes deployment file to check if the container is considered ready for service.

This container image can also run in a "TROUBLEMAKER" role. In that role, it keeps messing up with the readiness and liveness probes; the effects of which can then be observed for learning purpose. The image runs in this "TROUBLEMAKER" role, when a environment variable name "ROLE" is set to "TROUBLEMAKER". You will need to set the kubernetes `command` to `["/troublemaker.sh"]` and set the kubernetes `args` to  `["nginx", "-g", "daemon off;"]`.

**Remember:**
* `ENTRYPOINT` in Docker = `command` in kubernetes
* `CMD` in Docker = `args` in kubernetes 
* If you provide a `command` (e.g. set to `/some-entrypoint.sh`), then you also need to provide `args`.
    As, for some silly reason the `CMD`  defined in the `Dockerfile` is ignored,
    when kubernetes `command` is specified manually.

For TROUBLEMAKER to be able to mess with the readiness probe, it needs to randomly delete and create the `/readinesscheck.txt` file. It does that by running two shell processes, which fire up at random intervals. One of them creates the `/readinesscheck.txt` file, and the other deletes the file at another random interval.

For TROUBLEMAKER to be able to mess with the liveness probe, it needs to randomly delete and create the `/livenesscheck.txt` file. It does that by running two shell processes, which fire up at random intervals. One of them creates the `/livenesscheck.txt` file, and the other deletes the file at another random interval.

To be able to do these, the `DocumentRoot` directory of the main web container is mounted as a shared volume between the main container and the side-car. On the main container, it is mounted at the `/usr/share/nginx/html` mount-point. However, on the TROUBLEMAKER side-car, it is mounted on `/shared`. The troublemaker container knows that the `readinesscheck.txt` file is found/accessible as `/shared/readinesscheck.txt`, and the `livenesscheck.txt` file is found/accessible as `/shared/livenesscheck.txt`.

You can of-course run this in plain docker, or docker-compose, for very basic testing. However, the real behavior is observed in Kubernetes, and for that, some `deployment-*.yaml` files are provided.


**Note:** Readiness and Liveness probes can be completely different. I chose both to be HTTP, as they are easier to see in action / easier to study.
