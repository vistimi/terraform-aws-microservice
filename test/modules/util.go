package module

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"testing"
)

func ExtractFromState(t *testing.T, microservicePath, statePath string) any {
	stateFields := strings.Split(statePath, ".")
	if len(stateFields) == 0 {
		return nil
	}
	jsonFile, err := os.Open(fmt.Sprintf("%s/terraform.tfstate", microservicePath))
	if err != nil {
		t.Fatal(err)
	}
	defer jsonFile.Close()
	byteValue, _ := io.ReadAll(jsonFile)
	var result map[string]any
	json.Unmarshal([]byte(byteValue), &result)
	result = result["outputs"].(map[string]any)[stateFields[0]].(map[string]any)["value"].(map[string]any)

	for _, stateField := range stateFields[1:] {
		result = result[stateField].(map[string]any)
	}
	return result
}
