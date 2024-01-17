package main

import (
    "fmt"
    "net/http"
    "os"
)

func main() {
    http.HandleFunc("/", HelloServer)

    server_port := ":4444"

    http.ListenAndServe(server_port, nil)
}

func HelloServer(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, os.Getenv("GREETING") + " world - We like: Light-Green . ")
}
