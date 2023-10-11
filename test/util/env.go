package util

import (
	"fmt"
	"os"
)

// GetEnvVariable use godot package to load/read the .env file and return the value of the key
func GetEnvVariable(key string) string {
	varEnv := os.Getenv(key)
	if varEnv == "" {
		panic(fmt.Sprintf("env variable empty: %s", key))
	}
	return varEnv
}
