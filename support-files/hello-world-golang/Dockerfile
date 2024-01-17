FROM docker.io/library/golang AS BUILDER
WORKDIR /app

COPY src/ /app

# Below 'CGO_ENABLED=0' enables statically linked binaries 
#   to make the application more portable. 
#   It allows you to use the binary with source images that don't 
#   support shared libraries when building your container image.
# Without this, the binary file will not run on scratch or alpine.

RUN CGO_ENABLED=0 go build hello-world.go


# FROM docker.io/library/alpine
FROM scratch
WORKDIR /app
COPY --from=BUILDER    /app    /app
CMD ["/app/hello-world"]
EXPOSE 4444


# -------------------------------------------------------------
#
# docker build -t local/hello-world-golang
# docker run -p 8080 -d local/hello-world-golang 
# podman run --publish 8080 --detached local/hello-world-golang 
