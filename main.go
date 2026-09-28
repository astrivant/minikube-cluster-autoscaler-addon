package main

import (
	"log"

	"github.com/astrivant/minikube-cluster-autoscaler-addon/pkg/addon"
)

// Release builds stamp these values without changing the checked-in source.
var version = "dev"
var commit = "unknown"
var buildDate = "unknown"

func main() {
	if err := addon.Execute(version, commit, buildDate); err != nil {
		log.Fatal(err)
	}
}
