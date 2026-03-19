// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"context"
	"log"
	"os"

	"github.com/gin-gonic/gin"

	vault "github.com/hashicorp/vault/api"
	auth "github.com/hashicorp/vault/api/auth/kubernetes"
)

func main() {
	config := vault.DefaultConfig()
	token_location := "token"

	// initialize Vault client
	client, err := vault.NewClient(config)
	if err != nil {
		log.Printf("unable to initialize Vault client: %v", err)
		os.Exit(1)
	}

	// determine where the application is running and set the
	// Vault address and token accordingly
	if _, exists := os.LookupEnv("KUBERNETES_SERVICE_HOST"); exists {
		log.Println("Application is running inside a Kubernetes cluster.")
		config.Address = os.Getenv("VAULT_ADDR")
		token_location = "/var/run/secrets/kubernetes.io/serviceaccount/token"
	} else if _, err := os.Stat("/.dockerenv"); err == nil {
		log.Println("Application is running inside a Docker container.")
		config.Address = "http://host.docker.internal:8200"
		log.Printf("Vault address: %s", config.Address)
	} else {
		log.Println("Application is not running inside a container.")
		config.Address = os.Getenv("VAULT_ADDR")
		client.SetToken(os.Getenv("VAULT_TOKEN"))
		log.Printf("Vault address: %s Vault Token: %s", config.Address, os.Getenv("VAULT_TOKEN"))
	}

	// The service-account token will be read from the path where the token's
	// Kubernetes Secret is mounted. By default, Kubernetes will mount it to
	// /var/run/secrets/kubernetes.io/serviceaccount/token.
	k8sAuth, err := auth.NewKubernetesAuth(
		"vault-kube-auth-role",
		auth.WithServiceAccountTokenPath(token_location),
	)
	if err != nil {
		log.Printf("unable to initialize Kubernetes auth method: %v", err)
		os.Exit(1)
	}
	log.Printf("%#v\n", k8sAuth)

	authInfo, err := client.Auth().Login(context.Background(), k8sAuth)
	if err != nil {
		log.Printf("unable to log in with Kubernetes auth!: %v", err)
		os.Exit(1)
	}
	if authInfo == nil {
		log.Printf("no auth info was returned after login")
		os.Exit(1)
	}

	// set up router
	router := gin.Default()

	// using the token returned from Vault get secret from the default
	// mount path for KV v2 "secret"
	secret, err := client.KVv2("secret").Get(context.Background(), "myapp/api-key")
	if err != nil {
		log.Printf("unable to read secret: %v", err)
		os.Exit(1)
	}

	// log.Printf("%#v\n", secret)

	// data map can contain more than one key-value pair,
	// in this case we're just grabbing one of them
	value, ok := secret.Data["access_key"].(string)
	if !ok {
		log.Printf("value type assertion failed: %T %#v", secret.Data["access_key"], secret.Data["access_key"])
		os.Exit(1)
	}

	pass, ok := secret.Data["secret_access_key"].(string)
	if !ok {
		log.Printf("value type assertion failed: %T %#v", secret.Data["secret_access_key"], secret.Data["secret_access_key"])
		os.Exit(1)
	}

	log.Println("Access granted!")
	log.Printf("Retrieved secret value: %s, %s", value, pass)

	router.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": value,
		})
	})

	router.Run()
}
